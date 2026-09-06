#!/usr/bin/env python3
"""Fetch the mp3s for the sermon-library records that have audio but no body.

2026-09-06. Sixteen of Pastor Eric Chang's 198 records in
`assets/sermon_library/index.json` have `hasBody` false and a non-empty
`audioUrls`. Nothing else in the repo has a body for them and none of the
sixteen has a `transcriptDocUrls` entry either, so the audio is the only
copy of these sermons that exists here. The target set is derived in
`scripts/transcribe_targets.py` on the SAME single predicate
`merge_sermon_library.py` excludes them by — see that module for why it
also has to survive the seam being closed.

Be gentle with the origin. `.github/workflows/sync-songs.yml` records that
this project once took fydt.org down by doubling its traffic, and
`scripts/sync_sermon_library.py` paces its own crawl for exactly that
reason. This script is stricter than that one has to be, because its
objects are 20-40 MB each rather than a few KB of JSON:

  * ONE request at a time, never concurrent.
  * A fixed gap between requests (--gap, default 5s), measured from the
    END of the previous transfer, so a slow download does not turn into
    a burst the moment it finishes.
  * A single-slot rate limiter on retries, with the server's own
    `Retry-After` preferred over our backoff.
  * RESUME, not restart: a partial file is continued with a Range
    request. A re-run over a complete cache makes ZERO requests.

The cache lives under `assets/sermon_library/audio/`, which `.gitignore`
already excludes wholesale ("assets/sermon_library/"). Nothing here can
reach `assets/sermons/`.

Usage
-----
    python3 scripts/transcribe_fetch_audio.py            # fetch what is missing
    python3 scripts/transcribe_fetch_audio.py --dry-run  # list, fetch nothing
    python3 scripts/transcribe_fetch_audio.py --gap 10   # be even gentler

Exit codes
----------
    0  every target is present and complete on disk
    3  TRANSIENT — could not reach or read the server; retry later.
       Whatever arrived is kept as a `.part` and the next run resumes it.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / "scripts"))

from transcribe_targets import (  # noqa: E402
    AUDIO_DIR, INDEX_JSON, TARGET_AUTHOR, audio_path, load_index, targets,
)

USER_AGENT = "YsWordsSermonSyncBot/1.0 (+https://yswords.netlify.app)"
RETRY_SLEEPS = (5, 20, 60)
TRANSIENT = 3


class Transient(Exception):
    pass


def _retry_after(headers) -> int | None:
    raw = (headers or {}).get("Retry-After")
    try:
        return max(1, min(300, int(str(raw).strip())))
    except (TypeError, ValueError):
        return None


def fetch_one(url: str, dest: Path, gap: float, log=print) -> tuple[bool, int]:
    """Download `url` to `dest`, resuming a `.part` if one is there.

    Returns (made_a_request, bytes_on_disk).
    """
    if dest.exists():
        return False, dest.stat().st_size

    part = dest.with_suffix(dest.suffix + ".part")
    have = part.stat().st_size if part.exists() else 0

    for attempt in range(len(RETRY_SLEEPS) + 1):
        headers = {"User-Agent": USER_AGENT}
        if have:
            headers["Range"] = f"bytes={have}-"
        req = urllib.request.Request(url, headers=headers)
        last = "unknown"
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                status = r.status
                # 200 to a Range request means the server ignored it and
                # is sending the whole object — start over rather than
                # concatenating the file onto its own prefix.
                mode = "ab" if (status == 206 and have) else "wb"
                if mode == "wb":
                    have = 0
                total = int(r.headers.get("Content-Length") or 0) + have
                with open(part, mode) as fh:
                    while True:
                        chunk = r.read(262144)
                        if not chunk:
                            break
                        fh.write(chunk)
                        have += len(chunk)
            if total and have != total:
                raise Transient(f"short read: {have} of {total} bytes")
            os.replace(part, dest)
            return True, have
        except urllib.error.HTTPError as e:
            last = f"HTTP {e.code}"
            # 416 = we already hold the whole object; the range is past
            # the end. Promote the .part rather than re-downloading.
            if e.code == 416 and have:
                os.replace(part, dest)
                return True, have
            if e.code not in (429,) and e.code < 500:
                raise Transient(f"GET {url} returned {last}")
            wait = _retry_after(e.headers) or RETRY_SLEEPS[min(attempt, len(RETRY_SLEEPS) - 1)]
        except Transient:
            raise
        except Exception as e:
            last = f"{type(e).__name__}: {e}"
            wait = RETRY_SLEEPS[min(attempt, len(RETRY_SLEEPS) - 1)]
            have = part.stat().st_size if part.exists() else 0

        if attempt >= len(RETRY_SLEEPS):
            break
        log(f"  ! {last} on {url} — retrying in {wait}s "
            f"({attempt + 1}/{len(RETRY_SLEEPS)})")
        time.sleep(wait)

    raise Transient(f"GET {url} failed after {len(RETRY_SLEEPS) + 1} attempts")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--gap", type=float, default=5.0,
                    help="seconds to wait after each transfer completes "
                         "(default 5)")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--only", default=None,
                    help="comma-separated refcodes, for testing")
    args = ap.parse_args()

    index = load_index()
    recs = targets(index)
    if args.only:
        want = {s.strip() for s in args.only.split(",")}
        recs = [r for r in recs if r["refcode"] in want]

    n_files = sum(len(r["audioUrls"]) for r in recs)
    print(f"{len(recs)} records, {n_files} audio files, "
          f"author={TARGET_AUTHOR}")
    AUDIO_DIR.mkdir(parents=True, exist_ok=True)

    requests_made = 0
    total_bytes = 0
    for rec in recs:
        for i, url in enumerate(rec["audioUrls"]):
            dest = audio_path(rec, i)
            if dest.exists():
                total_bytes += dest.stat().st_size
                print(f"  = {dest.name} ({dest.stat().st_size:,} B, cached)")
                continue
            if args.dry_run:
                print(f"  + would fetch {url}")
                continue
            if requests_made:
                time.sleep(args.gap)
            t0 = time.time()
            try:
                _, size = fetch_one(url, dest, args.gap)
            except Transient as e:
                print(f"TRANSIENT: {e}", file=sys.stderr)
                return TRANSIENT
            requests_made += 1
            total_bytes += size
            print(f"  + {dest.name} ({size:,} B, {time.time() - t0:.1f}s)")

    print(f"requests made: {requests_made}; bytes on disk: {total_bytes:,}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
