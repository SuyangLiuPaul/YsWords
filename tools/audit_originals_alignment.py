#!/usr/bin/env python3
"""Is assets/originals/ numbered the same way as the translations?

The Originals sheet looks the Hebrew/Greek up by the *same* `chapter:verse`
the reader is on. That is only right if both sides count verses the same
way, and the Hebrew Bible does not: a psalm's superscription is verse 1
there and unnumbered here, so `詩篇 3:1` fetches מִזְמוֹר לְדָוִד while the
reader is looking at 「雅伟啊，我的敌人何其加增」.

Rather than assume where that happens, this measures it. For each chapter
it scores the Strong's-number overlap between the tagged translation verse
and the original verse at offsets -3..+3, and reports every chapter whose
best offset is not 0. Content decides, not a table of expected differences.

The overlap survives the two datasets using different Strong's conventions
(the tagger's inflected G2076/G5213 against the originals' lemma
G1510/G4771) because nouns and verbs still agree; a whole verse of
disagreement is what an offset looks like.

Usage:
    python3 tools/audit_originals_alignment.py [--version cuvs-yhwh]
"""

from __future__ import annotations

import argparse
import json
import pathlib
from collections import Counter, defaultdict

ROOT = pathlib.Path(__file__).resolve().parent.parent
TAGGED = ROOT / "assets" / "tagged"
ORIGINALS = ROOT / "assets" / "originals"

MAX_OFFSET = 3


def load(path: pathlib.Path) -> dict:
    with path.open(encoding="utf-8") as fh:
        return json.load(fh)


def nums(words: list[dict]) -> Counter:
    return Counter(w["s"] for w in words if w.get("s") and w["s"] not in ("H0", "G0"))


def overlap(a: Counter, b: Counter) -> float:
    if not a or not b:
        return 0.0
    shared = sum((a & b).values())
    return shared / max(sum(a.values()), sum(b.values()))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", default="cuvs-yhwh")
    ap.add_argument("--threshold", type=float, default=0.05,
                    help="how much better the winning offset must score")
    ap.add_argument("--map", action="store_true",
                    help="apply assets/originals_versification.json first")
    args = ap.parse_args()

    vmap = {}
    if args.map:
        vmap = load(ROOT / "assets" / "originals_versification.json")

    misaligned: list[tuple[str, int, int, float, float]] = []
    chapters_checked = 0
    verses_misplaced = 0

    for book_path in sorted((TAGGED / args.version).glob("*.json")):
        book = book_path.stem
        orig_path = ORIGINALS / f"{book}.json"
        if not orig_path.exists():
            continue
        tagged = load(book_path)
        originals = load(orig_path)

        by_chapter: dict[int, list[int]] = defaultdict(list)
        for ref in tagged:
            c, _, v = ref.partition(":")
            if v.isdigit():
                by_chapter[int(c)].append(int(v))

        orig_nums = {ref: nums(w) for ref, w in originals.items()}
        tag_nums = {ref: nums(r) for ref, r in tagged.items()}

        # With the map applied the original words for a reading verse
        # are whatever the map points at, so re-key by the reading verse
        # and the offset search should then find nothing left to fix.
        if book in vmap:
            remapped = dict(orig_nums)
            for ref, targets in vmap[book].items():
                merged = Counter()
                for t in targets:
                    merged += orig_nums.get(t, Counter())
                remapped[ref] = merged
            orig_nums = remapped

        for chapter, verses in sorted(by_chapter.items()):
            chapters_checked += 1
            scores = {}
            for d in range(-MAX_OFFSET, MAX_OFFSET + 1):
                total = 0.0
                for v in verses:
                    a = tag_nums.get(f"{chapter}:{v}")
                    b = orig_nums.get(f"{chapter}:{v + d}")
                    if a and b:
                        total += overlap(a, b)
                scores[d] = total / len(verses)
            best = max(scores, key=lambda d: (scores[d], -abs(d)))
            if best != 0 and scores[best] - scores[0] >= args.threshold:
                misaligned.append(
                    (book, chapter, best, scores[0], scores[best]))
                verses_misplaced += len(verses)

    print(f"chapters checked: {chapters_checked}")
    print(f"chapters whose originals are NOT at offset 0: {len(misaligned)}")
    print(f"verses affected: {verses_misplaced}")
    by_book: Counter[str] = Counter(m[0] for m in misaligned)
    print()
    for book, count in by_book.most_common():
        print(f"  {book}: {count} chapters")
    print()
    print("first 40 chapters in detail (book chapter offset score@0 -> score@best):")
    for book, chapter, best, s0, sb in misaligned[:40]:
        print(f"  {book} {chapter}: {best:+d}  {s0:.2f} -> {sb:.2f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
