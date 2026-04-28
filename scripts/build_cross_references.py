#!/usr/bin/env python3
"""
Convert openbible.info's CC-BY cross-references TSV into the
compact JSON format YsWords' CrossReferenceService expects.

Source:  https://a.openbible.info/data/cross-references.zip
         (340K weighted cross-references, public-domain Treasury of
         Scripture Knowledge merged with OpenBible community votes.)

Output:  assets/cross_references.json
         {
           "_meta": { ... license, schema_version, source_count ... },
           "Genesis 1:1": ["John 1:1-3", "Hebrews 11:3", ...],
           "Genesis 1:2": [...],
           ...
         }

Strategy
- Group rows by source verse.
- Sort each group by `votes` descending.
- Keep at most TOP_N per source verse, plus a `votes` floor so we
  don't include weak/disputed references.
- Convert OSIS-like book abbreviations (`Gen`, `1Cor`, `Rev`) to the
  canonical English names YsWords uses everywhere else
  ("Genesis", "1 Corinthians", "Revelation").
- Collapse from-side ranges ("Gen.1.1-Gen.1.2") to the start verse,
  so a single source key gathers everything.
- Preserve to-side ranges ("John.1.1-John.1.3") so the user sees
  the full range hint.

Run:
    python3 scripts/build_cross_references.py

Re-run any time the upstream TSV is updated.
"""

import json
import os
import re
import sys
from collections import defaultdict

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = "/tmp/cross_references.txt"
OUT = os.path.join(REPO_ROOT, "assets", "cross_references.json")

# Per-source-verse cap. 12 is a good balance: Treasury of Scripture
# Knowledge entries average ~10 refs per verse; OpenBible's voted
# subset for the busiest verses (e.g. John 3:16) has 60+ candidates.
TOP_N = 12
# Minimum vote threshold. Votes are 0-100ish. 1 keeps the long tail
# (anything at least one community member endorsed); 0 would keep
# the raw TSK bulk too aggressively.
MIN_VOTES = 1

OSIS_TO_NAME = {
    "Gen": "Genesis",
    "Exod": "Exodus",
    "Lev": "Leviticus",
    "Num": "Numbers",
    "Deut": "Deuteronomy",
    "Josh": "Joshua",
    "Judg": "Judges",
    "Ruth": "Ruth",
    "1Sam": "1 Samuel",
    "2Sam": "2 Samuel",
    "1Kgs": "1 Kings",
    "2Kgs": "2 Kings",
    "1Chr": "1 Chronicles",
    "2Chr": "2 Chronicles",
    "Ezra": "Ezra",
    "Neh": "Nehemiah",
    "Esth": "Esther",
    "Job": "Job",
    "Ps": "Psalms",
    "Prov": "Proverbs",
    "Eccl": "Ecclesiastes",
    "Song": "Song of Solomon",
    "Isa": "Isaiah",
    "Jer": "Jeremiah",
    "Lam": "Lamentations",
    "Ezek": "Ezekiel",
    "Dan": "Daniel",
    "Hos": "Hosea",
    "Joel": "Joel",
    "Amos": "Amos",
    "Obad": "Obadiah",
    "Jonah": "Jonah",
    "Mic": "Micah",
    "Nah": "Nahum",
    "Hab": "Habakkuk",
    "Zeph": "Zephaniah",
    "Hag": "Haggai",
    "Zech": "Zechariah",
    "Mal": "Malachi",
    "Matt": "Matthew",
    "Mark": "Mark",
    "Luke": "Luke",
    "John": "John",
    "Acts": "Acts",
    "Rom": "Romans",
    "1Cor": "1 Corinthians",
    "2Cor": "2 Corinthians",
    "Gal": "Galatians",
    "Eph": "Ephesians",
    "Phil": "Philippians",
    "Col": "Colossians",
    "1Thess": "1 Thessalonians",
    "2Thess": "2 Thessalonians",
    "1Tim": "1 Timothy",
    "2Tim": "2 Timothy",
    "Titus": "Titus",
    "Phlm": "Philemon",
    "Heb": "Hebrews",
    "Jas": "James",
    "1Pet": "1 Peter",
    "2Pet": "2 Peter",
    "1John": "1 John",
    "2John": "2 John",
    "3John": "3 John",
    "Jude": "Jude",
    "Rev": "Revelation",
}

REF_RE = re.compile(r"^([\w\d]+?)\.(\d+)\.(\d+)$")
RANGE_RE = re.compile(
    r"^([\w\d]+?)\.(\d+)\.(\d+)-(?:[\w\d]+?\.)?(\d+)?\.?(\d+)$"
)


def parse_one(token: str) -> str:
    """Convert "Gen.1.1" → "Genesis 1:1"; raise on unknown book."""
    m = REF_RE.match(token)
    if not m:
        raise ValueError(f"unparseable single ref: {token}")
    book_code, ch, vs = m.group(1), m.group(2), m.group(3)
    name = OSIS_TO_NAME.get(book_code)
    if not name:
        raise ValueError(f"unknown book code: {book_code} in {token}")
    return f"{name} {ch}:{vs}"


def parse_to(token: str) -> str:
    """Convert a to-side ref which may be a single verse or a range.
    Output format MUST be parseable by YsWords' parseReference, which
    accepts only one Book Chapter:Verse(-Verse) per string. So we
    collapse all same-book ranges into the verse-list form:

       "Gen.1.1"           → "Genesis 1:1"
       "Gen.1.1-Gen.1.3"   → "Genesis 1:1-3"     (same-book range
                                                  → verse-only suffix)
       "Gen.1.1-1.3"       → "Genesis 1:1-3"
       "Gen.1.31-Gen.2.3"  → "Genesis 1:31"      (cross-CHAPTER range
                                                  collapsed to start;
                                                  parser can't render
                                                  multi-chapter ranges,
                                                  better to lose the
                                                  span than the ref)
    """
    if "-" not in token:
        return parse_one(token)

    parts = token.split("-")
    head = parse_one(parts[0])
    tail = parts[1]
    # Resolve the head's book name + chapter so we can compare.
    head_match = REF_RE.match(parts[0])
    head_book = head_match.group(1) if head_match else None
    head_ch = head_match.group(2) if head_match else None

    if tail.count(".") == 2:
        # Tail is "Book.ch.vs" — full reference.
        tail_match = REF_RE.match(tail)
        if tail_match:
            tail_book = tail_match.group(1)
            tail_ch = tail_match.group(2)
            tail_vs = tail_match.group(3)
            if tail_book == head_book and tail_ch == head_ch:
                # Same book + chapter → "Book ch:v1-v2"
                return f"{head}-{tail_vs}"
            # Cross-chapter or cross-book — collapse to start verse;
            # the user can navigate from there. Better than producing
            # an unparseable string and losing the cross-ref entirely.
            return head
        return head
    if tail.count(".") == 1:
        # ch.vs only — same chapter? Compare the bare ch portion.
        tail_ch, tail_vs = tail.split(".")
        if tail_ch == head_ch:
            return f"{head}-{tail_vs}"
        return head
    # vs only — same chapter, verse-only span.
    return f"{head}-{tail}"


def from_key(token: str) -> str:
    """Convert a from-side ref (possibly a range) to the START verse,
    used as our source-side dictionary key."""
    if "-" in token:
        token = token.split("-")[0]
    return parse_one(token)


def main() -> int:
    if not os.path.exists(SRC):
        print(f"missing {SRC} — run:")
        print("  curl -sLo /tmp/x.zip https://a.openbible.info/data/cross-references.zip")
        print("  unzip -o /tmp/x.zip -d /tmp")
        return 1

    by_src: dict[str, list[tuple[int, str]]] = defaultdict(list)
    bad = 0
    with open(SRC, "r", encoding="utf-8") as f:
        # Skip header. Some lines may be comments (start with '#').
        next(f)
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            cols = line.split("\t")
            if len(cols) < 3:
                continue
            src_tok, dst_tok, votes_raw = cols[0], cols[1], cols[2]
            try:
                votes = int(votes_raw)
            except ValueError:
                votes = 0
            if votes < MIN_VOTES:
                continue
            try:
                src = from_key(src_tok)
                dst = parse_to(dst_tok)
            except ValueError:
                bad += 1
                continue
            by_src[src].append((votes, dst))

    out: dict = {
        "_meta": {
            "description": "Cross-references for YsWords. Public-domain Treasury "
            "of Scripture Knowledge (TSK) merged with OpenBible.info "
            "community votes; each source verse keeps the top-voted N "
            "to-references.",
            "license": "CC-BY 4.0 — openbible.info",
            "source": "https://www.openbible.info/labs/cross-references/",
            "schema_version": 2,
            "top_per_verse": TOP_N,
            "min_votes": MIN_VOTES,
        }
    }

    total_kept = 0
    for src, votes_dst in sorted(by_src.items()):
        votes_dst.sort(key=lambda t: -t[0])
        kept = [d for _, d in votes_dst[:TOP_N]]
        out[src] = kept
        total_kept += len(kept)

    out["_meta"]["source_verse_count"] = len(by_src)
    out["_meta"]["entry_count"] = total_kept

    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, separators=(",", ":"))

    print(
        f"wrote {OUT}\n"
        f"  source verses: {len(by_src)}\n"
        f"  total entries: {total_kept}\n"
        f"  unparseable (skipped): {bad}\n"
        f"  output bytes: {os.path.getsize(OUT)}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
