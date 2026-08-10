#!/usr/bin/env python3
"""Audit assets/tagged/ against assets/originals/ and assets/strongs/.

"Tap a word to see the original" answers with the Strong's number in
assets/tagged/<version>/<book>.json. Two ways that answer can be untrue:

  1. The number is not in the lexicon at all, so the sheet has nothing
     to show.
  2. The number is not in the original-language text of that very verse,
     so the app names a word the verse does not contain.

Both are counted here over the whole corpus rather than spot-checked,
because one wrong number looks exactly like a right one on screen.

Usage:
    python3 tools/audit_strongs_tagging.py [--version cuvs-yhwh] [--verbose]
"""

from __future__ import annotations

import argparse
import json
import pathlib
import sys
from collections import Counter

ROOT = pathlib.Path(__file__).resolve().parent.parent
TAGGED = ROOT / "assets" / "tagged"
ORIGINALS = ROOT / "assets" / "originals"
STRONGS = ROOT / "assets" / "strongs"


def load(path: pathlib.Path) -> dict:
    with path.open(encoding="utf-8") as fh:
        return json.load(fh)


def lexicon() -> set[str]:
    keys: set[str] = set()
    for name in ("greek.json", "hebrew.json"):
        keys |= set(load(STRONGS / name).keys())
    return keys


def audit(version: str, verbose: bool) -> int:
    lex = lexicon()
    books = sorted((TAGGED / version).glob("*.json"))
    if not books:
        print(f"no tagged books for {version}", file=sys.stderr)
        return 2

    total_runs = total_tagged = 0
    missing_from_lexicon: Counter[str] = Counter()
    not_in_verse: Counter[str] = Counter()
    verses_with_orphan = 0
    verses_compared = 0
    verses_no_original = 0
    per_book: list[tuple[str, int, int]] = []

    for book_path in books:
        book = book_path.stem
        tagged = load(book_path)
        orig_path = ORIGINALS / f"{book}.json"
        originals = load(orig_path) if orig_path.exists() else {}
        book_orphans = 0
        book_verses = 0

        for ref, runs in tagged.items():
            nums = [r.get("s", "") for r in runs if r.get("s")]
            total_runs += len(runs)
            total_tagged += len(nums)
            for n in nums:
                if n not in lex:
                    missing_from_lexicon[n] += 1

            orig = originals.get(ref)
            if not orig:
                verses_no_original += 1
                continue
            verses_compared += 1
            book_verses += 1
            have = {w.get("s", "") for w in orig}
            orphans = [n for n in nums if n not in have]
            if orphans:
                verses_with_orphan += 1
                book_orphans += 1
                for n in orphans:
                    not_in_verse[n] += 1
                if verbose:
                    print(f"  {book} {ref}: {sorted(set(orphans))}")

        per_book.append((book, book_verses, book_orphans))

    print(f"version: {version}")
    print(f"books: {len(books)}  runs: {total_runs}  tagged runs: {total_tagged}")
    print(f"verses compared against originals: {verses_compared}")
    print(f"verses with no original-language counterpart: {verses_no_original}")
    print()
    print(f"tagged numbers absent from the lexicon: "
          f"{sum(missing_from_lexicon.values())} occurrences, "
          f"{len(missing_from_lexicon)} distinct")
    for n, c in missing_from_lexicon.most_common(20):
        print(f"    {n}: {c}")
    print()
    print(f"verses where a tagged number is not in that verse's original: "
          f"{verses_with_orphan} / {verses_compared}"
          f" ({100.0 * verses_with_orphan / max(verses_compared, 1):.1f}%)")
    print(f"orphan tag occurrences: {sum(not_in_verse.values())}, "
          f"{len(not_in_verse)} distinct numbers")
    for n, c in not_in_verse.most_common(30):
        print(f"    {n}: {c}")
    print()
    worst = sorted(per_book, key=lambda t: -t[2])[:10]
    print("worst books by orphan verses:")
    for book, verses, orphans in worst:
        print(f"    {book}: {orphans} / {verses}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", default="cuvs-yhwh")
    ap.add_argument("--verbose", action="store_true")
    args = ap.parse_args()
    return audit(args.version, args.verbose)


if __name__ == "__main__":
    raise SystemExit(main())
