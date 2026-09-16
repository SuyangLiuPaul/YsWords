#!/usr/bin/env python3
"""Report-only: split `assets/songs.json` sync churn into real content
changes vs timestamp-only re-stamps, per source.

Why this exists: the Songs page's default sort is `'recent'` — newest
`updatedAt` first (`lib/pages/songs_page.dart:131`, `_applySort` at
:600-612) — `_sort` is never persisted and every filter defaults to
`'all'` (:102-125), so a fresh load shows the full 629-song catalogue in
this order. `.github/workflows/sync-songs.yml` runs `chore(songs):
refresh bundled snapshot from yswords-data` roughly daily. Across the 7
most recent daily syncs checked by hand (commits eb59f280 through
413eef71, 2026-09-08 through 2026-09-15), four smaller sources — cgdc
(63/63), cahaya (47/47), ydh (5/5), setapak (2/2), plus 1 of fydt's 213 —
had their `updatedAt` rewritten to that run's `_meta.generatedAt` on
EVERY one of the 7, with the song row otherwise byte-identical to the
previous commit: no title, audio, lyrics, themes or verse changed. The
two largest catalogues, cdc (298) and the rest of fydt (212-213), sat
untouched (fully byte-identical, including `updatedAt`) across the same
7 runs. The one earlier commit checked outside that run, 91eaa742
(2026-09-07), is a mixed day: fydt's 213 rows got real editorial fields
(url, audioUrl, scoreUrl, artworkUrl, …), but setapak's 2 and ydh's 5
rows only had `firstSeenAt` — a bookkeeping timestamp, not editorial
content — rewritten, so they belong with the restamp pattern despite
`split_song_changes()` bucketing them as `content_changed` (it only
excludes `updatedAt`, not `firstSeenAt`). cdc's 206 touched rows and
cgdc's 63 were themselves timestamp-only, same as every other day
checked. So the "wholesale timestamp-only restamp of
cgdc/cahaya/ydh/setapak (+0-1 fydt) on every sync" pattern held for at
least 7 straight days and was also present on the one day outside that
run. Widening past these 8 commits: cgdc and cahaya HAVE had real
content changes before, in August 2026 (cgdc got artworkUrl; cahaya's
source was built out) — so this is a pattern observed in the 8 commits
examined (2026-09-07 through -15), not a claim that these sources are
incapable of real updates.
The result: the default "recent" view is not "songs that actually
changed recently" — it is "songs whose source happens to be rewritten
wholesale on every sync", regardless of whether anything in the row
changed. This script measures that split so the claim is reproducible
instead of asserted from one commit; it does not decide what "recent"
should mean or touch the generator (`scripts/sync_songs.py v2` lives in
yswords-data, not here).

This script does not fix anything and exits 0 unconditionally: no gate,
no CI dependency. It reads the git history of `assets/songs.json` and/or
two already-loaded song lists — never the network.

Usage:
    python3 tools/audit_songs_snapshot_churn.py                 # HEAD vs its parent sync commit
    python3 tools/audit_songs_snapshot_churn.py --history 8      # walk the 8 most recent syncs
    python3 tools/audit_songs_snapshot_churn.py --rev-a X --rev-b Y
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from collections import Counter
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
ASSET_PATH = "assets/songs.json"


def split_song_changes(cur_songs, prev_songs):
    """Pure comparison of two song-row lists (as loaded from `songs.json`'s
    `songs` array). Matches rows by `id`. Returns a dict with per-source
    Counters for added / removed / timestamp_only (row identical except
    `updatedAt`) / content_changed (some other field differs) / unchanged
    (fully byte-identical including `updatedAt`), plus a Counter of which
    non-timestamp fields changed across all content_changed rows."""
    cur_idx = {s["id"]: s for s in cur_songs}
    prev_idx = {s["id"]: s for s in prev_songs}
    common = set(cur_idx) & set(prev_idx)
    added = set(cur_idx) - set(prev_idx)
    removed = set(prev_idx) - set(cur_idx)

    timestamp_only = Counter()
    content_changed = Counter()
    unchanged = Counter()
    fields_changed = Counter()

    for song_id in common:
        cur, prev = cur_idx[song_id], prev_idx[song_id]
        cur_rest = {k: v for k, v in cur.items() if k != "updatedAt"}
        prev_rest = {k: v for k, v in prev.items() if k != "updatedAt"}
        source = cur.get("source", "?")
        if cur_rest == prev_rest:
            if cur.get("updatedAt") != prev.get("updatedAt"):
                timestamp_only[source] += 1
            else:
                unchanged[source] += 1
        else:
            content_changed[source] += 1
            for field in cur_rest:
                if cur_rest.get(field) != prev_rest.get(field):
                    fields_changed[field] += 1

    return {
        "added": Counter(cur_idx[i].get("source", "?") for i in added),
        "removed": Counter(prev_idx[i].get("source", "?") for i in removed),
        "timestamp_only": timestamp_only,
        "content_changed": content_changed,
        "unchanged": unchanged,
        "fields_changed": fields_changed,
    }


def restamped_to_generated_at(songs, generated_at):
    """Per-source count of rows whose `updatedAt` equals the snapshot's
    own `_meta.generatedAt` — i.e. rows this run rewrote (or wrote for
    the first time), whether or not their content actually changed."""
    return Counter(
        s.get("source", "?") for s in songs if s.get("updatedAt") == generated_at
    )


def _load_json(text):
    return json.loads(text)


def _read_worktree(path):
    return _load_json((REPO / path).read_text(encoding="utf-8"))


def _read_git_rev(rev, path):
    proc = subprocess.run(
        ["git", "show", f"{rev}:{path}"], cwd=REPO, capture_output=True, text=True
    )
    if proc.returncode != 0:
        return None
    return _load_json(proc.stdout)


def _sync_commits(limit):
    proc = subprocess.run(
        ["git", "log", f"-n{limit}", "--format=%H", "--", ASSET_PATH],
        cwd=REPO,
        capture_output=True,
        text=True,
        check=True,
    )
    return [line for line in proc.stdout.splitlines() if line]


def _print_split(label, cur_doc, prev_doc):
    cur_songs = cur_doc["songs"]
    prev_songs = prev_doc["songs"]
    split = split_song_changes(cur_songs, prev_songs)
    generated_at = cur_doc.get("_meta", {}).get("generatedAt")
    restamped = restamped_to_generated_at(cur_songs, generated_at)

    print(f"=== {label} ===  generatedAt={generated_at}")
    for key in ("added", "removed", "timestamp_only", "content_changed", "unchanged"):
        counts = split[key]
        total = sum(counts.values())
        print(f"  {key:16s} total={total:<4d} {dict(counts)}")
    if split["fields_changed"]:
        print(f"  fields_changed   {dict(split['fields_changed'].most_common(8))}")
    print(f"  restamped_to_generatedAt (any source rewritten this run):")
    print(f"    {dict(restamped)}")
    print()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--rev-a", help="older revision (default: parent sync commit)")
    ap.add_argument("--rev-b", help="newer revision (default: HEAD)")
    ap.add_argument(
        "--history",
        type=int,
        default=0,
        help="walk this many most-recent commits touching songs.json, "
        "each against its immediate predecessor",
    )
    args = ap.parse_args()

    if args.history:
        commits = _sync_commits(args.history + 1)
        if len(commits) < 2:
            print("not enough history to compare")
            return 0
        for i in range(len(commits) - 1):
            newer, older = commits[i], commits[i + 1]
            cur_doc = _read_git_rev(newer, ASSET_PATH)
            prev_doc = _read_git_rev(older, ASSET_PATH)
            if cur_doc is None or prev_doc is None:
                print(f"=== {newer[:8]} ===  SKIP (missing data)")
                continue
            _print_split(f"{newer[:8]} vs {older[:8]}", cur_doc, prev_doc)
        return 0

    rev_b = args.rev_b or "HEAD"
    cur_doc = _read_worktree(ASSET_PATH) if rev_b == "HEAD" else _read_git_rev(
        rev_b, ASSET_PATH
    )
    if cur_doc is None:
        print(f"could not read {ASSET_PATH} at {rev_b}", file=sys.stderr)
        return 0

    rev_a = args.rev_a
    if rev_a is None:
        commits = _sync_commits(2)
        rev_a = commits[1] if len(commits) > 1 else None
    if rev_a is None:
        print("no prior revision of songs.json to compare against")
        return 0

    prev_doc = _read_git_rev(rev_a, ASSET_PATH)
    if prev_doc is None:
        print(f"could not read {ASSET_PATH} at {rev_a}", file=sys.stderr)
        return 0

    _print_split(f"{rev_b} vs {rev_a[:8]}", cur_doc, prev_doc)
    return 0


if __name__ == "__main__":
    sys.exit(main())
