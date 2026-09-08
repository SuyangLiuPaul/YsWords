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

**A raw count of (2) is worthless and the first version of this tool
published one.** It reported 24,983 runs "carrying a number that is not
in that verse's original", which reads like 24,983 defects and is not:

  * The two verse numberings differ, so 14,670 of them were comparing
    the wrong two verses. Both maps are applied here now.
  * The two datasets use different Strong's CONVENTIONS. The tagger
    numbers the inflected form (G2076 ἐστί, G2258 ἦν, G5213 ὑμῖν) where
    the originals number the lemma (G1510 εἰμί, G5210 ὑμεῖς). Every one
    of those resolves to the right lexicon entry, so "fixing" them would
    make the app less accurate, not more.

So the convention difference is factored out by the lexicon's own
derivation field — never by a table typed in here — and what is left is
reported as the tail worth reading. Run with --tail to see it.

Usage:
    python3 tools/audit_strongs_tagging.py [--version cuvs-yhwh]
                                           [--verbose] [--tail N]
                                           [--no-versification]
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys
import unicodedata
from collections import Counter

ROOT = pathlib.Path(__file__).resolve().parent.parent
TAGGED = ROOT / "assets" / "tagged"
ORIGINALS = ROOT / "assets" / "originals"
STRONGS = ROOT / "assets" / "strongs"
VERSIFICATION = ROOT / "assets" / "originals_versification.json"
MERGED = ROOT / "assets" / "originals_versification_merged.json"

# Wording in Strong's own derivation notes that marks an INFLECTED FORM
# of another entry rather than a different word. "a derivative of" and
# "from" are deliberately absent: G697 Ἄρειος Πάγος derives from G4078
# πήγνυμι and is not the same word.
INFLECTION = re.compile(
    r"(person (singular|plural)|case of|\bplural of\b"
    r"|(imperfect|future|aorist|perfect|present)\b"
    r"|\b(shorter|simpler|prolonged|contracted|emphatic|intensive"
    r"|alternate|alternative)\b.{0,20}form of|participle|infinitive)",
    re.I)
NUMBER = re.compile(r"\b([GH]\d+)\b")


def load(path: pathlib.Path) -> dict:
    with path.open(encoding="utf-8") as fh:
        return json.load(fh)


def lexicon() -> dict:
    entries: dict = {}
    for name in ("greek.json", "hebrew.json"):
        entries.update(load(STRONGS / name))
    return entries


def inflection_roots(lex: dict) -> dict[str, str]:
    """number → the number it is an inflected form of, per the lexicon."""
    roots: dict[str, str] = {}
    for key, entry in lex.items():
        deriv = entry.get("deriv") or ""
        if not INFLECTION.search(deriv):
            continue
        found = NUMBER.search(deriv)
        if found:
            roots[key] = found.group(1)
    return roots


def bare(word: str) -> str:
    """A word form with its diacritics removed, for comparison only."""
    return "".join(c for c in unicodedata.normalize("NFD", word)
                   if not unicodedata.combining(c)).lower()


def _compute(version: str, versify: bool, verbose: bool = False) -> dict | None:
    """The counting pass, shared by `audit()` (prints it) and `check()`
    (compares it to the pinned totals below). Returns None if there is
    no tagged corpus for `version`."""
    lex = lexicon()
    roots = inflection_roots(lex)
    books = sorted((TAGGED / version).glob("*.json"))
    if not books:
        return None

    base = load(VERSIFICATION) if versify else {}
    merged = load(MERGED).get(version, {}) if versify else {}

    total_runs = total_tagged = 0
    missing_from_lexicon: Counter[str] = Counter()
    not_in_verse: Counter[str] = Counter()
    explained_inflection: Counter[str] = Counter()
    explained_form: Counter[str] = Counter()
    unexplained: Counter[str] = Counter()
    example: dict[str, str] = {}
    verses_with_orphan = 0
    verses_compared = 0
    verses_no_original = 0
    per_book: list[tuple[str, int, int]] = []

    def rooted_in(number: str, have: set[str]) -> bool:
        """Is this the tagger's inflected number for a word in the verse?"""
        seen = set()
        current = number
        for _ in range(4):
            current = roots.get(current, "")
            if not current or current in seen:
                return False
            seen.add(current)
            if current in have:
                return True
        return False

    def printed_in(number: str, words: list[str]) -> bool:
        """Is the lexicon's own headword one of the verse's word forms?"""
        lemma = bare((lex.get(number) or {}).get("lemma") or "")
        if not lemma:
            return False
        for word in words:
            form = bare(word)
            if form == lemma or form == lemma + "ν" \
                    or form.rstrip("ν") == lemma.rstrip("ν"):
                return True
        return False

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

            refs = merged.get(book, {}).get(ref) \
                or base.get(book, {}).get(ref) or [ref]
            have: set[str] = set()
            words: list[str] = []
            for original_ref in refs:
                for w in originals.get(original_ref, []):
                    have.add(w.get("s", ""))
                    words.append(w.get("w", ""))
            if not have:
                verses_no_original += 1
                continue
            verses_compared += 1
            book_verses += 1
            orphans = [n for n in nums if n not in have]
            if orphans:
                verses_with_orphan += 1
                book_orphans += 1
                for n in orphans:
                    not_in_verse[n] += 1
                    if rooted_in(n, have):
                        explained_inflection[n] += 1
                    elif printed_in(n, words):
                        explained_form[n] += 1
                    else:
                        unexplained[n] += 1
                        example.setdefault(n, f"{book} {ref}")
                if verbose:
                    print(f"  {book} {ref}: {sorted(set(orphans))}")

        per_book.append((book, book_verses, book_orphans))

    return {
        "lex": lex,
        "books": len(books),
        "total_runs": total_runs,
        "total_tagged": total_tagged,
        "verses_compared": verses_compared,
        "verses_no_original": verses_no_original,
        "missing_from_lexicon": missing_from_lexicon,
        "verses_with_orphan": verses_with_orphan,
        "not_in_verse": not_in_verse,
        "explained_inflection": explained_inflection,
        "explained_form": explained_form,
        "unexplained": unexplained,
        "example": example,
        "per_book": per_book,
    }


def audit(version: str, verbose: bool, tail: int, versify: bool) -> int:
    result = _compute(version, versify, verbose)
    if result is None:
        print(f"no tagged books for {version}", file=sys.stderr)
        return 2
    lex = result["lex"]
    missing_from_lexicon = result["missing_from_lexicon"]
    not_in_verse = result["not_in_verse"]
    unexplained = result["unexplained"]
    example = result["example"]

    print(f"version: {version}"
          f"{'' if versify else '   (versification NOT applied)'}")
    print(f"books: {result['books']}  runs: {result['total_runs']}  "
          f"tagged runs: {result['total_tagged']}")
    print(f"verses compared against originals: {result['verses_compared']}")
    print(f"verses with no original-language counterpart: "
          f"{result['verses_no_original']}")
    print()
    print(f"tagged numbers absent from the lexicon: "
          f"{sum(missing_from_lexicon.values())} occurrences, "
          f"{len(missing_from_lexicon)} distinct")
    for n, c in missing_from_lexicon.most_common(20):
        print(f"    {n}: {c}")
    print()
    print(f"verses where a tagged number is not in that verse's original: "
          f"{result['verses_with_orphan']} / {result['verses_compared']}"
          f" ({100.0 * result['verses_with_orphan'] / max(result['verses_compared'], 1):.1f}%)")
    total_orphans = sum(not_in_verse.values())
    print(f"orphan tag occurrences: {total_orphans}, "
          f"{len(not_in_verse)} distinct numbers")
    print()
    print("of those, accounted for WITHOUT changing any data:")
    print(f"  the tagger's inflected-form number for a lemma the verse "
          f"does have: {sum(result['explained_inflection'].values())}")
    print(f"  the lexicon's headword is printed in the verse verbatim:  "
          f"{sum(result['explained_form'].values())}")
    left = sum(unexplained.values())
    print(f"  LEFT TO READ: {left} "
          f"({100.0 * left / max(result['total_tagged'], 1):.2f}% of tagged runs), "
          f"{len(unexplained)} distinct numbers")
    print()
    for n, c in unexplained.most_common(tail):
        lemma = (lex.get(n) or {}).get("lemma", "NOT IN THE LEXICON")
        print(f"    {n}: {c:5}  {lemma}   e.g. {example[n]}")
    print()
    worst = sorted(result["per_book"], key=lambda t: -t[2])[:10]
    print("worst books by orphan verses:")
    for book, verses, orphans in worst:
        print(f"    {book}: {orphans} / {verses}")
    return 0


# Pinned totals for `--check`, measured at commit 3c68bf5e (2026-09-08).
# This is a RATCHET, the same way test/strongs_alignment_test.dart's
# singleton-pair count is: a legitimate repair can move any of these
# numbers, in EITHER direction, and when one does the fix updates the
# pin in the same commit and explains the delta by naming the commits
# that caused it (see docs/autonomous-queue.md:7553 for the worked
# example) rather than widening the check to tolerate drift. A raw
# total that could silently move is exactly what let this one drift
# unnoticed from the true 2026-08-12 baseline for four weeks.
PINNED = {
    True: {  # versify=True — the figure the queue quotes
        "total_runs": 367572,
        "total_tagged": 360929,
        "left_to_read": 1991,
        "left_to_read_distinct": 682,
        "orphan_occurrences": 9761,
    },
    False: {  # --no-versification — the pre-2026-08 raw figure
        "total_runs": 367572,
        "total_tagged": 360929,
        "orphan_occurrences": 25133,
    },
}


def check() -> int:
    problems = []
    for versify, expected in PINNED.items():
        result = _compute("cuvs-yhwh", versify)
        if result is None:
            problems.append(f"versify={versify}: no tagged corpus found")
            continue
        not_in_verse = result["not_in_verse"]
        unexplained = result["unexplained"]
        actual = {
            "total_runs": result["total_runs"],
            "total_tagged": result["total_tagged"],
            "orphan_occurrences": sum(not_in_verse.values()),
        }
        if versify:
            actual["left_to_read"] = sum(unexplained.values())
            actual["left_to_read_distinct"] = len(unexplained)
        for key, want in expected.items():
            got = actual[key]
            if got != want:
                problems.append(
                    f"versify={versify} {key}: pinned {want}, measured {got} "
                    f"(delta {got - want:+d}) — re-derive and update PINNED, "
                    f"explaining the delta, don't just widen the check")
    if problems:
        print("FAIL:")
        for p in problems:
            print(f"  {p}")
        return 1
    print("OK: all pinned Strong's-tagging totals hold.")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", default="cuvs-yhwh")
    ap.add_argument("--verbose", action="store_true")
    ap.add_argument("--tail", type=int, default=25,
                    help="how many of the unexplained numbers to list")
    ap.add_argument("--no-versification", action="store_true",
                    help="compare verse-for-verse, as the first version of "
                         "this tool did; for reproducing the old figure")
    ap.add_argument("--check", action="store_true",
                    help="assert the PINNED totals hold (cuvs-yhwh only); "
                         "for CI, exits 1 on any drift")
    args = ap.parse_args()
    if args.check:
        return check()
    return audit(args.version, args.verbose, args.tail,
                 not args.no_versification)


if __name__ == "__main__":
    raise SystemExit(main())
