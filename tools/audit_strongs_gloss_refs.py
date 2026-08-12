#!/usr/bin/env python3
"""Check that each Chinese lexicon gloss belongs to the number it is filed under.

The Chinese glosses in ``assets/strongs/{hebrew,greek}.json`` come from CBOL
(bible.fhl.net) and were merged onto Strong's numbers by an earlier import.
Nothing had ever verified that merge, and a gloss under the wrong number is the
same class of error as a wrong verse: the Originals sheet prints it as the
meaning of the word the reader tapped.

The check does not read the Chinese.  4,853 Hebrew and 3,744 Greek entries end
their ``defZh`` with CBOL's own citations, e.g. H3 ``(#伯 8:12; 歌 6:11|)``.
That is a falsifiable claim about the text: the word numbered H3 must stand in
Job 8:12.  So every citation is resolved against ``assets/originals/`` -- an
independently sourced dataset (OSHB / OpenGNT) that the glosses were never
derived from -- and an entry is only reported when NOT ONE of its citations
finds its own number.

Verse numbering is CBOL's (i.e. the reading text's), so
``assets/originals_versification.json`` is applied before looking a verse up;
without it Psalms alone contributes hundreds of spurious misses.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ORIGINALS = ROOT / "assets" / "originals"

# Simplified-Chinese CUV abbreviations as CBOL prints them.  Longest match wins,
# so 约壹 is never read as 约.
BOOKS = {
    "创": "genesis", "出": "exodus", "利": "leviticus", "民": "numbers",
    "申": "deuteronomy", "书": "joshua", "士": "judges", "得": "ruth",
    "撒上": "1_samuel", "撒下": "2_samuel", "王上": "1_kings", "王下": "2_kings",
    "代上": "1_chronicles", "代下": "2_chronicles", "拉": "ezra",
    "尼": "nehemiah", "斯": "esther", "伯": "job", "诗": "psalms",
    "箴": "proverbs", "传": "ecclesiastes", "歌": "song_of_solomon",
    "赛": "isaiah", "耶": "jeremiah", "哀": "lamentations", "结": "ezekiel",
    "但": "daniel", "何": "hosea", "珥": "joel", "摩": "amos",
    "俄": "obadiah", "拿": "jonah", "弥": "micah", "弥迦书": "micah",
    "鸿": "nahum", "哈": "habakkuk", "番": "zephaniah", "该": "haggai",
    "亚": "zechariah", "玛": "malachi",
    "太": "matthew", "可": "mark", "路": "luke", "约": "john", "徒": "acts",
    "罗": "romans", "林前": "1_corinthians", "林后": "2_corinthians",
    "加": "galatians", "弗": "ephesians", "腓": "philippians",
    "西": "colossians", "帖前": "1_thessalonians", "帖后": "2_thessalonians",
    "提前": "1_timothy", "提后": "2_timothy", "多": "titus",
    "门": "philemon", "来": "hebrews", "雅": "james", "彼前": "1_peter",
    "彼后": "2_peter", "约壹": "1_john", "约一": "1_john",
    "约贰": "2_john", "约二": "2_john", "约叁": "3_john", "约三": "3_john",
    "犹": "jude", "启": "revelation",
}
BOOK_RE = re.compile("|".join(sorted(map(re.escape, BOOKS), key=len, reverse=True)))

CITATION_BLOCK = re.compile(r"#([^|#]*)\|")
# 创 1:1  /  提前1:9  /  民 24:20,24  /  路 14:19-30
REFERENCE = re.compile(
    r"(?:(" + BOOK_RE.pattern + r")\s*)?(\d+)\s*[:.]\s*(\d+(?:\s*[-,、]\s*\d+)*)"
)


def load_originals() -> dict[str, dict]:
    return {p.stem: json.loads(p.read_text()) for p in sorted(ORIGINALS.glob("*.json"))}


def load_versification() -> dict[str, dict[str, list[str]]]:
    path = ROOT / "assets" / "originals_versification.json"
    return json.loads(path.read_text()) if path.exists() else {}


def parse_citations(text: str) -> list[tuple[str, int, int]]:
    """Every (book, chapter, verse) a gloss claims, ranges expanded."""
    out: list[tuple[str, int, int]] = []
    for block in CITATION_BLOCK.findall(text):
        book: str | None = None
        for m in REFERENCE.finditer(block):
            if m.group(1):
                book = BOOKS[m.group(1)]
            if book is None:
                continue
            chapter = int(m.group(2))
            verses = m.group(3)
            for part in re.split(r"[,、]", verses):
                part = part.strip()
                if "-" in part:
                    lo, hi = part.split("-", 1)
                    lo, hi = int(lo), int(hi)
                    if 0 < hi - lo <= 40:
                        out.extend((book, chapter, v) for v in range(lo, hi + 1))
                    else:
                        out.append((book, chapter, lo))
                elif part:
                    out.append((book, chapter, int(part)))
    return out


def original_keys(book: str, chapter: int, verse: int, vers: dict) -> list[str]:
    """The originals key(s) for a reference given in the reading text's numbering."""
    key = f"{chapter}:{verse}"
    mapped = vers.get(book, {}).get(key)
    return list(mapped) if mapped else [key]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--show", type=int, default=25, help="how many failures to print")
    ap.add_argument("--max-orphans", type=int, default=None,
                    help="exit non-zero if more entries than this fail every citation")
    args = ap.parse_args()

    originals = load_originals()
    vers = load_versification()
    numbers_by_verse: dict[tuple[str, str], set[str]] = {
        (book, ref): {t["s"] for t in tokens if t.get("s")}
        for book, verses in originals.items()
        for ref, tokens in verses.items()
    }

    totals = dict(entries=0, cited=0, citations=0, hits=0, unresolvable=0)
    orphans: list[tuple[str, str, list[tuple[str, int, int]]]] = []

    for corpus in ("hebrew", "greek"):
        lex = json.loads((ROOT / "assets" / "strongs" / f"{corpus}.json").read_text())
        for number, entry in sorted(lex.items(), key=lambda kv: int(kv[0][1:])):
            totals["entries"] += 1
            citations = parse_citations(entry.get("defZh") or "")
            if not citations:
                continue
            totals["cited"] += 1
            hits = 0
            for book, chapter, verse in citations:
                totals["citations"] += 1
                keys = original_keys(book, chapter, verse, vers)
                found = any(number in numbers_by_verse.get((book, k), ()) for k in keys)
                if found:
                    hits += 1
                    totals["hits"] += 1
            if hits == 0:
                totals["unresolvable"] += 1
                orphans.append((number, entry.get("lemma", ""), citations))

    print(f"lexicon entries            {totals['entries']:>7,}")
    print(f"  carrying a citation      {totals['cited']:>7,}")
    print(f"citations resolved         {totals['citations']:>7,}")
    print(f"  number found in verse    {totals['hits']:>7,} "
          f"({100 * totals['hits'] / max(totals['citations'], 1):.1f}%)")
    print(f"entries where NO citation finds their own number "
          f"{totals['unresolvable']:>5,} "
          f"({100 * totals['unresolvable'] / max(totals['cited'], 1):.2f}%)")

    for number, lemma, citations in orphans[: args.show]:
        shown = ", ".join(f"{b} {c}:{v}" for b, c, v in citations[:4])
        print(f"  {number:<7} {lemma:<18} {shown}")
    if len(orphans) > args.show:
        print(f"  … {len(orphans) - args.show:,} more")

    if args.max_orphans is not None and totals["unresolvable"] > args.max_orphans:
        print(f"FAIL: {totals['unresolvable']} > {args.max_orphans}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
