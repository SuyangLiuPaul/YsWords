#!/usr/bin/env python3
"""Turn the git history into the changelog the app ships.

WHY THIS EXISTS. On 2026-09-09 the owner asked for release notes in
the app — 「也要有历史的release note但是不要全部的」. The finding was
that there were none to show: all 270 GitHub Releases carry the same
body, `Automated Linux x64 build. Download the tarball...`, written by
the Linux job of `release-android.yml`. That is build instructions for
one platform, not a note, and it is identical on every release.

The notes were in the commit subjects the whole time. This app writes
them as sentences — "A retired edition is announced once, not on every
launch", "versions: plain BSB comes off the interface, and the English
default with it" — which is already a changelog, so nothing here
rewrites them. It selects.

WHAT IS DROPPED, and why each one is bookkeeping rather than a change
the reader can see:

  * `release: vX.Y.Z to dev + prod` — the mechanics of shipping. There
    is one per version, so leaving them in would make the changelog
    half release lines.
  * `PROJECT_STATE: …` and `docs: …` — this repository's own record.
    Real work, none of it visible in the app.
  * `chore:` / `ci:` / `test:` — the same, one level down.

WHY THE SPINE IS THE `release:` COMMITS AND NOT THE TAGS. Tags were
the obvious choice and are wrong here: `tag_release.sh` only started
pushing them on 2026-09-08, so the repository holds **12** tags for
270 versions. Built on tags, the oldest entry swallowed the entire
history back to the initial commit — 719 notes in one row, 51 KB.
Every released version does have a `release: vX.Y.Z …` commit (older
ones read `chore(release): vX.Y.Z`), all the way back, so those are
the anchors.

WHY IT IS A BUNDLED ASSET rather than fetched. The GitHub bodies for
every EXISTING release are the boilerplate above, so an app that read
them would show an empty history until enough new releases accumulated
— the reader would ask for the changelog and be told there isn't one,
which is worse than not offering it. Generating from git gives a full
history on the first build, and gives it offline, which matters for a
Bible app used on a tablet with no SIM.

HOW MANY, and why the first two answers were both wrong. The owner's
constraint was 「不要全部的而是足够的不然太多」. The first guess was 20
versions; measured, this app ships **29 versions in three days**, so 20
is a day and a half and reads as a broken page. The second guess was 30
"because that is three to six weeks" — measured, it is three days.

The measurement that settled it: **120 versions is 115 entries, 250
notes, 25 KB, and one month** (2026-08-11 → 2026-09-09) spread over 17
days. Size was never the constraint — 25 KB is nothing to bundle. The
constraint is the reader's scroll, and the thing that makes a changelog
here unreadable is not the notes, it is **115 version numbers**. So the
notes are all kept and the page groups them BY DAY: seventeen headings
instead of a hundred and fifteen rows. Throwing away history would have
been solving the wrong half.

Versions whose every commit was filtered out are dropped rather than
shown empty. Everything older than the window stays on GitHub, which
the page links to.

Usage:
  tools/build_changelog.py            # write assets/changelog.json
  tools/build_changelog.py --check    # print, write nothing
"""

import argparse
import json
import pathlib
import re
import subprocess
import sys

PROJECT = pathlib.Path(__file__).resolve().parent.parent
OUT = PROJECT / 'assets' / 'changelog.json'

# How many versions-with-something-to-say to keep. Measured at this
# repo's rate: about one month, 250 notes, 25 KB. See "HOW MANY" above
# for the two smaller numbers that were tried and why they were wrong.
DEFAULT_MAX_ENTRIES = 120

# A released version, in either convention this repo has used.
ANCHOR = re.compile(
    r'^(?:release|chore\(release\)):\s*v?(\d+\.\d+\.\d+)\b',
    re.IGNORECASE,
)

# `type` or `type(scope)` — the scoped form is why `chore(release):`
# survived the first draft of this filter and put twelve release lines
# into the notes.
DROP = re.compile(
    r'^(?:'
    r'(?:release|docs?|chore|ci|test|build|style|refactor)'
    r'(?:\([^)]*\))?:'
    r'|PROJECT_STATE\b'
    r'|Merge (?:branch|pull request)\b'
    r')',
    re.IGNORECASE,
)

# No single version may fill the whole page. Nothing in this repo's
# history comes near it; it is here so that a first release, or a
# long-lived branch landing at once, degrades into "a lot happened"
# rather than into a wall.
MAX_NOTES_PER_VERSION = 12


def git(*args: str) -> str:
    return subprocess.run(
        ['git', *args], cwd=PROJECT, capture_output=True, text=True, check=True
    ).stdout.strip()


def released_versions(limit: int) -> list[tuple[str, str, str]]:
    """`(version, sha, date)` for the newest [limit] release commits.

    Walked newest-first and stopped at [limit], so the initial commit
    is never reached and no entry can absorb the whole history — the
    exact failure the tag-based first draft had.
    """
    out = git(
        'log', '--format=%H\x1f%cs\x1f%s', '--no-merges', '--all',
    ).splitlines()
    found: list[tuple[str, str, str]] = []
    seen: set[str] = set()
    for line in out:
        sha, date, subject = line.split('\x1f', 2)
        m = ANCHOR.match(subject)
        if not m:
            continue
        version = m.group(1)
        # A version re-cut (dev, then dev + prod) has two release
        # commits. The FIRST one seen walking backwards is the newest,
        # which is the one whose date the reader should be shown.
        if version in seen:
            continue
        seen.add(version)
        found.append((version, sha, date))
        if len(found) > limit:
            break
    return found


def notes_between(older_sha: str | None, newer_sha: str) -> list[str]:
    span = f'{older_sha}..{newer_sha}' if older_sha else newer_sha
    subjects = git('log', '--no-merges', '--format=%s', span).splitlines()
    kept: list[str] = []
    for s in subjects:
        s = s.strip()
        if not s or DROP.match(s):
            continue
        if s not in kept:  # a cherry-pick should not read as two changes
            kept.append(s)
    return kept


def build(max_entries: int) -> dict:
    # One extra, so the oldest kept entry still has a predecessor to
    # measure against rather than reaching back to the initial commit.
    versions = released_versions(max_entries)
    entries = []
    for i, (version, sha, date) in enumerate(versions):
        if len(entries) >= max_entries:
            break
        older = versions[i + 1][1] if i + 1 < len(versions) else None
        if older is None:
            # No predecessor in the window: rather than walk to the
            # beginning of the repository, stop. The page links to
            # GitHub for everything older, which is where it is.
            break
        notes = notes_between(older, sha)
        if not notes:
            # A version whose every commit was bookkeeping. Dropping it
            # rather than showing an empty row is the difference between
            # a changelog and a list of version numbers.
            continue
        entries.append({
            'version': version,
            'date': date,
            'notes': notes[:MAX_NOTES_PER_VERSION],
        })
    return {'entries': entries}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--check', action='store_true')
    ap.add_argument('--max-entries', type=int, default=DEFAULT_MAX_ENTRIES)
    args = ap.parse_args()

    data = build(args.max_entries)
    if not data['entries']:
        print('refusing to write an empty changelog', file=sys.stderr)
        return 1

    text = json.dumps(data, ensure_ascii=False, separators=(',', ':'))
    if args.check:
        print(json.dumps(data, ensure_ascii=False, indent=2))
        print(
            f'\n{len(data["entries"])} versions, '
            f'{sum(len(e["notes"]) for e in data["entries"])} notes, '
            f'{len(text.encode())} bytes',
            file=sys.stderr,
        )
        return 0

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(text, encoding='utf-8')
    print(f'{OUT.relative_to(PROJECT)}: {len(data["entries"])} versions, '
          f'{len(text.encode())} bytes')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
