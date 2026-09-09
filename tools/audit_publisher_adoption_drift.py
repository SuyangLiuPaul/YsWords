#!/usr/bin/env python3
"""Classify the verses `audit_dropped_characters.py` / `audit_inserted_
characters.py` flag as new since `50dcc102` (the publisher-text adoption)
into cosmetic footnote-anchor reorders vs genuine word-level drift.

Re-derives, from git + the two audits alone, the split first reported by
hand in the 2026-09-09 06:06 queue entry (bae3e1d8): of the union of fresh
hits from both audits, a verse whose sorted-Han-character multiset is
UNCHANGED between `50dcc102^` and HEAD only had a `<note: ...>` anchor move
relative to the word it annotates — no character was actually added or
removed. A verse whose multiset DIFFERS lost or gained real content.

Run from the repo root:

    python3 tools/audit_dropped_characters.py    # writes nothing; read stdout
    python3 tools/audit_inserted_characters.py   # same
    python3 tools/audit_publisher_adoption_drift.py \
        --dropped /tmp/dropped_audit.txt --inserted /tmp/inserted_audit.txt

The two audits print to stdout, not to a file, so this script takes their
captured output as input rather than re-running them itself (re-running
them here would need opencc and the SeekSparks checkout available, which
this script does not otherwise depend on).
"""
import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
OURS = REPO / "assets/cuvs-yhwh.json"
PRE_ADOPTION_REV = "50dcc102^"

HIT_LINE = re.compile(r"^(\d{9})\s+\S+\s+\d+:\d+")
CJK = re.compile(r"[一-鿿㐀-䶿]")


def han(text):
    """Han ideographs only, matching the two audits' own comparison basis
    (`han()` in audit_dropped_characters.py / audit_inserted_characters.py).
    Excludes note-anchor punctuation and the quotation marks that the two
    documented thaws (2026-09-08) added/moved, which are not word content."""
    return "".join(CJK.findall(text))


def parse_hit_ids(path):
    ids = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            m = HIT_LINE.match(line)
            if m:
                ids.append(m.group(1))
    return ids


def load(path):
    return {r["id"]: r for r in json.loads(Path(path).read_text(encoding="utf-8"))}


def load_from_git(rev, path):
    raw = subprocess.run(
        ["git", "show", f"{rev}:{path}"], cwd=REPO, capture_output=True, check=True
    ).stdout.decode("utf-8")
    return {r["id"]: r for r in json.loads(raw)}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dropped", default="/tmp/dropped_audit.txt")
    ap.add_argument("--inserted", default="/tmp/inserted_audit.txt")
    args = ap.parse_args()

    fresh = sorted(set(parse_hit_ids(args.dropped)) | set(parse_hit_ids(args.inserted)))

    old = load_from_git(PRE_ADOPTION_REV, "assets/cuvs-yhwh.json")
    new = load(OURS)

    reorder, drift, missing = [], [], []
    for vid in fresh:
        if vid not in old or vid not in new:
            missing.append(vid)
            continue
        ot, nt = han(old[vid]["text"]), han(new[vid]["text"])
        if sorted(ot) == sorted(nt):
            reorder.append(vid)
        else:
            drift.append(vid)

    print(f"fresh hits (union of both audits): {len(fresh)}")
    print(f"  cosmetic reorder (multiset unchanged): {len(reorder)}")
    print(f"  genuine drift (multiset changed):      {len(drift)}")
    if missing:
        print(f"  could not classify (missing from old/new): {len(missing)}  {missing}")

    print("\n# genuine drift, verse id + old + new")
    for vid in drift:
        r = new[vid]
        print(f"\n{vid}  {r['book']} {r['chapter']}:{r['verse']}")
        print(f"  old (50dcc102^): {old[vid]['text']}")
        print(f"  new (HEAD)     : {new[vid]['text']}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
