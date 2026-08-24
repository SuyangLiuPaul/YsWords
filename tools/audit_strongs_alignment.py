#!/usr/bin/env python3
"""Find runs in the word-tap corpus whose Strong's number names the wrong word.

`assets/tagged/cuvs-yhwh/<book>.json` holds runs of Chinese text, each with an
`s` — the Strong's number the app shows when a reader taps that text. A run can
carry a perfectly real number and still be wrong, because it names a DIFFERENT
word from the one its Chinese renders. 民數記 11:8 tags 百姓 ("the people") with
H8081, שֶׁמֶן, *oil*; 使徒行傳 12:24 tags 神 with G3588, the definite article.
Both read as scholarship and both are false.

`audit_strongs_tagging.py` mostly cannot see this class, because it asks whether
a number is absent from the verse's original and here it is usually present —
though 7 of the hits below turn out to be absent after all, so the two audits
overlap and neither is contained in the other.

TWO PREMISES WERE TRIED AND THE FIRST ONE WAS WRONG. Recording both, because
the wrong one looked right and produced a number 6x too small.

  1. REJECTED — "the word the run should name is UNCLAIMED", where a run claims
     its `s` and everything in its `i`. That found 11. It is the wrong question
     because **`i` is inert on screen**: `tagged_text_service.dart` parses it
     into `TaggedRun.implied` and no widget ever reads it. So a verse where
     θεός sits in some run's `i` still never shows θεός to anybody, and
     counting `i` as coverage measures the data rather than the reader. It hid
     約翰福音 3:5, 馬太福音 22:37 and 民數記 32:11, which are the same defect.

  2. USED — "the word the run should name is present in the verse's original
     and is no run's `s`". That is exactly the reader's question: is the true
     word reachable by any tap in this verse at all?

Ground truth for "should name" is the corpus's own internal consistency, not an
outside alignment, because no word-level alignment of CUV to the originals
exists here. A run text is admitted only if it occurs >= 20 times with one
number covering >= 95% of them; below that a single stray cannot be told from
polysemy. Hebrew and Greek are pooled separately so 亞倫 = H175 in the OT and
G2 in Hebrews is not counted as disagreement.

**THE TOTAL IS NOT A DEFECT COUNT, AND REPORTING IT AS ONE WAS THE FIRST DRAFT
OF THIS FILE.** The hits fall into three overlapping kinds and only the last is
71 independent mistakes' worth of wrong:

  * `spans-the-word` (53) — the number this run SHOULD show is already in that
    same run's own `i`. The importer did cover the word; it put `s` on a
    particle or prefix inside the span and the head into `i`. Six recurring
    shapes account for nearly all of them (G3588, H3605, H4480, H1121, H5921,
    H853), so this is a handful of importer conventions, not 53 separate
    slips — and it is still wrong on screen, because `i` is inert.
  * `tagged-number-absent` (7, four of which are also spans) — the number the
    app displays is not in this verse's original at all. That is
    `audit_strongs_tagging.py`'s class, reached from the other side.
  * `points-elsewhere` (15) — neither: the run names a different word that
    really is in the verse. 民 11:8 百姓 = "oil" is one of these. This is the
    verified core, and even here a few are defensible readings where a Chinese
    function word maps to a closed Hebrew class (出 16:23 and 何 12:8's 所,
    士 9:48's 我所, and 民 33:39's 歲 for the בֶּן … שָׁנָה age idiom), which is
    exactly where this method is weakest.

It is also a FLOOR. The detector is blind to any run text too rare to establish
a dominant number (耶利米書 35:18's 他的一切 is a known miss), and it
deliberately does not flag a verse where the true word is absent from the
original — the six 神 = G3588 runs at 提後 1:9, 弗 3:20, 羅 16:25, 羅 4:24,
來 1:7 and 徒 7:44 are correctly NOT flagged, because θεός is not in the Greek
there and the article is SUBSTANTIVAL (Ὁ ποιῶν, Τῷ δυναμένῳ): CUV renders the
whole phrase with 神. Saying CUV "supplies" the word there is wrong, and it was
wrong in this docstring for one draft.

Usage:
    python3 tools/audit_strongs_alignment.py [--version cuvs-yhwh]
                                             [--min 20] [--dominance 0.95]
                                             [--json]
"""

from __future__ import annotations

import argparse
import collections
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
TAGGED = ROOT / "assets" / "tagged"
ORIGINALS = ROOT / "assets" / "originals"
STRONGS = ROOT / "assets" / "strongs"
VERSIFICATION = ROOT / "assets" / "originals_versification.json"
MERGED = ROOT / "assets" / "originals_versification_merged.json"

NOT_CJK = re.compile(r"[^一-鿿]")

# H0 is the corpus's marker for a word this translation supplies with no
# original behind it. It is a separate open question and never a dominant
# number, so it is dropped before the distribution is built.
SUPPLIED = "H0"


def load(path: pathlib.Path) -> dict:
    with path.open(encoding="utf-8") as fh:
        return json.load(fh)


def lexicon() -> dict:
    entries: dict = {}
    for name in ("greek.json", "hebrew.json"):
        entries.update(load(STRONGS / name))
    return entries


def dominant_numbers(books: dict, minimum: int,
                     dominance: float) -> dict[tuple[str, str], tuple[str, int, int]]:
    """(run text, language) -> (number, occurrences, occurrences with it).

    Only groups that disagree with themselves at all are returned; a run text
    always tagged the same way cannot produce a hit and is dropped here so the
    caller's inner loop stays cheap.
    """
    seen: dict = collections.defaultdict(
        lambda: collections.defaultdict(collections.Counter))
    for tagged in books.values():
        for runs in tagged.values():
            for run in runs:
                text = NOT_CJK.sub("", run.get("w") or "")
                number = run.get("s") or ""
                if not text or not number or number == SUPPLIED:
                    continue
                seen[text][number[0]][number] += 1

    out: dict = {}
    for text, languages in seen.items():
        for language, counts in languages.items():
            total = sum(counts.values())
            top, top_count = counts.most_common(1)[0]
            if total >= minimum and len(counts) > 1 \
                    and top_count / total >= dominance:
                out[(text, language)] = (top, total, top_count)
    return out


def audit(version: str, minimum: int, dominance: float,
          as_json: bool) -> int:
    paths = sorted((TAGGED / version).glob("*.json"))
    if not paths:
        print(f"no tagged books for {version}", file=sys.stderr)
        return 2
    books = {p.stem: load(p) for p in paths}
    lex = lexicon()
    dominant = dominant_numbers(books, minimum, dominance)
    base = load(VERSIFICATION)
    merged = load(MERGED).get(version, {})

    hits = []
    for book, tagged in books.items():
        original_path = ORIGINALS / f"{book}.json"
        if not original_path.exists():
            continue
        originals = load(original_path)
        for ref, runs in tagged.items():
            refs = merged.get(book, {}).get(ref) \
                or base.get(book, {}).get(ref) or [ref]
            present: set[str] = set()
            for original_ref in refs:
                present.update(w.get("s", "")
                               for w in originals.get(original_ref, []))
            if not present:
                continue
            shown = {r["s"] for r in runs if r.get("s")}
            for run in runs:
                text = NOT_CJK.sub("", run.get("w") or "")
                number = run.get("s") or ""
                if not text or not number:
                    continue
                group = dominant.get((text, number[0]))
                if not group or group[0] == number:
                    continue
                expected = group[0]
                if expected in present and expected not in shown:
                    hits.append({
                        "book": book,
                        "ref": ref,
                        "text": run.get("w"),
                        "tagged": number,
                        "tagged_lemma": (lex.get(number) or {}).get("lemma", "?"),
                        "expected": expected,
                        "expected_lemma": (lex.get(expected) or {}).get("lemma", "?"),
                        "support": f"{group[2]}/{group[1]}",
                        "spans_the_word": expected in (run.get("i") or []),
                        "tagged_number_absent": number not in present,
                    })

    hits.sort(key=lambda h: (h["book"], h["ref"], h["text"]))
    if as_json:
        print(json.dumps(hits, ensure_ascii=False, indent=2))
        return 0

    print(f"version: {version}   admitted run texts: {len(dominant)} "
          f"(>= {minimum} occurrences, >= {dominance:.0%} dominant)")
    print(f"runs displaying a number that names another word, where the right "
          f"word is no run's `s`: {len(hits)}")
    spans = sum(1 for h in hits if h["spans_the_word"])
    absent = sum(1 for h in hits if h["tagged_number_absent"])
    core = [h for h in hits
            if not h["spans_the_word"] and not h["tagged_number_absent"]]
    print(f"  spans-the-word (right number sits in this run's inert `i`): {spans}")
    print(f"  tagged number absent from the verse's original: {absent}")
    print(f"  points elsewhere in the verse (the verified core): {len(core)}")
    print()
    for h in hits:
        kind = "span  " if h["spans_the_word"] else \
               "absent" if h["tagged_number_absent"] else "CORE  "
        print(f"  {kind} {h['book']:15} {h['ref']:8} {h['text']!r:14} "
              f"{h['tagged']} {h['tagged_lemma']} -> "
              f"{h['expected']} {h['expected_lemma']}   [{h['support']}]")
    print()
    worst = collections.Counter(h["tagged"] for h in hits)
    print("the numbers most often wrongly displayed:")
    for number, count in worst.most_common(8):
        print(f"    {number} {(lex.get(number) or {}).get('lemma','?')}: {count}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", default="cuvs-yhwh")
    ap.add_argument("--min", type=int, default=20)
    ap.add_argument("--dominance", type=float, default=0.95)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()
    return audit(args.version, args.min, args.dominance, args.json)


if __name__ == "__main__":
    raise SystemExit(main())
