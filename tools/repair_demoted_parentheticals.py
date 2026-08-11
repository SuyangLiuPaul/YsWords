#!/usr/bin/env python3
"""Restore CUV parenthetical verses that the importer filed as footnotes.

The CUV sets some verses entirely in parentheses — 約書亞記 2:6,
撒母耳記上 5:5, 以賽亞書 23:13 and others are narrative asides, printed
「（先是女人領二人上了房頂……）」. Our importer turned every parenthesis
into a `<note: …>` span, and the reader never sees a note: the reading
pane renders it as a book icon you have to tap, and every sanitised
path (search, copy, share, the Originals sheet's verse line) drops it
outright.

For a verse whose parenthesis covers the WHOLE verse that means the
verse renders as a number and an icon with **no scripture at all**.
Isaiah 23:13 is a real verse of the Bible and this app showed nothing
where it should be.

**Which notes are scripture is decided by evidence, not by reading the
Chinese.** `assets/tagged/cuvs-yhwh/` is a separate import of the same
edition (Eagle's View, imported by `tools/import_eaglesview.py`) and it
keeps the distinction our importer lost:

    （…）  parenthetical scripture   — 以賽亞書 23:13
    〔…〕  editorial / variant note  — 馬可福音 7:16「有古卷在此有…」

Measured over the whole corpus: of 1,290 `<note:>` spans, that witness
brackets 1,134 as editorial and carries 104 as scripture, and 52 do not
appear in it at all. So the vast majority of our notes ARE notes; this
tool touches only the ones the witness contradicts, and only where the
note is the entire verse. The 90 partial-verse ones are left for a
separate pass — the harm there is a lost clause, not a lost verse.

A second, independently sourced CUV (SeekSparks' `cuvs-plus.json`)
agrees on every one of them, parenthesising exactly these verses.

Nothing is written from another edition: the restored text is our own
note body, moved out of the note and back into the verse inside the
parentheses the CUV prints. The one exception is named in EXPECTED
below, where both witnesses show our asset dropped a character.

Usage:
    python3 tools/repair_demoted_parentheticals.py [--apply]
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
EDITIONS = ("cuvs-yhwh", "cuvs-yhwh-tr")
TAGGED = ROOT / "assets" / "tagged" / "cuvs-yhwh"
BOOK_NAMES = ROOT / "lib" / "constants" / "book_names.dart"

NOTE = re.compile(r"<note:([^>]*)>")
WHOLE_NOTE = re.compile(r"^\s*<note:([^>]*)>\s*$")
PUNCT = re.compile(
    r"[\s，。、；：？！“”‘’（）()《》〈〉…—－─\-·「」『』〔〕\.,;:!\?\"'0-9a-zA-Z]"
)

# 約書亞記 2:6 — our asset reads 所擺的麻中, and BOTH witnesses read
# 所擺的麻秸中: the Eagle's View tagging and SeekSparks' separately
# sourced cuvs-plus. 麻秸 (flax stalks) is what the CUV prints. One
# character, restored from two independent copies of the same verse,
# never typed from memory.
EXPECTED = {
    ("Joshua", "2", "6"): ("麻中", "麻秸中"),
}


def load(path: pathlib.Path):
    return json.loads(path.read_text(encoding="utf-8"))


def book_map() -> dict[str, str]:
    pairs = re.findall(r"'([^']+)'\s*:\s*'([^']+)'",
                       BOOK_NAMES.read_text(encoding="utf-8"))
    return {chinese: english for chinese, english in pairs}


def bare(s: str) -> str:
    return PUNCT.sub("", s)


def witness(english_book: str, chapter: str, verse: str) -> str | None:
    """The independent import's text for one verse, brackets included."""
    path = TAGGED / f"{english_book.lower().replace(' ', '_')}.json"
    if not path.exists():
        return None
    runs = load(path).get(f"{chapter}:{verse}")
    if not runs:
        return None
    return "".join(r.get("w", "") for r in runs)


def editorial(text: str) -> bool:
    """Whether the witness brackets this verse as an editorial note."""
    return text.lstrip().startswith("〔")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    args = ap.parse_args()

    names = book_map()

    # The reference list is settled on the SIMPLIFIED side, because the
    # witness is Simplified. The Traditional edition is then repaired at
    # those same references using its own characters.
    settled: dict[tuple[str, str, str], str] = {}
    left_alone: list[str] = []
    rows = load(ROOT / "assets" / f"{EDITIONS[0]}.json")
    for row in rows:
        m = WHOLE_NOTE.match(row["text"])
        if not m:
            continue
        english = names.get(row["book"])
        if english is None:
            sys.exit(f"unmapped book name: {row['book']}")
        ref = (english, row["chapter"], row["verse"])
        w = witness(*ref)
        label = f"{row['book']} {row['chapter']}:{row['verse']}"
        if w is None or editorial(w):
            left_alone.append(f"{label}  {m.group(1).strip()[:38]}")
            continue
        body = m.group(1).strip()
        wrong, right = EXPECTED.get(ref, (None, None))
        if wrong is not None and wrong in body:
            body = body.replace(wrong, right)
        if bare(body) != bare(w):
            sys.exit(
                f"{label}: the witness does not match our note body, so "
                f"this verse is not repairable from evidence.\n"
                f"  ours   : {body}\n  witness: {w}"
            )
        settled[ref] = body

    print(f"whole-verse notes the witness carries as scripture: {len(settled)}")
    print(f"whole-verse notes the witness also brackets 〔〕 — left alone: "
          f"{len(left_alone)}")
    for line in left_alone:
        print(f"   {line}")

    for edition in EDITIONS:
        path = ROOT / "assets" / f"{edition}.json"
        rows = load(path)
        changed = 0
        for row in rows:
            english = names.get(row["book"])
            ref = (english, row["chapter"], row["verse"])
            if ref not in settled:
                continue
            m = WHOLE_NOTE.match(row["text"])
            if m is None:
                sys.exit(f"{edition} {ref}: expected a whole-verse note, "
                         f"found {row['text'][:60]!r}")
            body = m.group(1).strip()
            wrong, right = EXPECTED.get(ref, (None, None))
            if wrong is not None and wrong in body:
                body = body.replace(wrong, right)
            row["text"] = f"（{body}）"
            changed += 1
        if changed != len(settled):
            sys.exit(f"{edition}: repaired {changed} of {len(settled)}")
        print(f"{edition}: {changed} verses restored to the verse body")
        if args.apply:
            # indent=2 + trailing newline reproduces the shipped format
            # byte for byte, so the diff is the 15 verses and nothing else.
            path.write_text(
                json.dumps(rows, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )

    if not args.apply:
        print("\ndry run — pass --apply to write")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
