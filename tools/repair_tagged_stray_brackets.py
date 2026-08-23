#!/usr/bin/env python3
"""Take the ASCII brackets that are not scripture out of the word-tap corpus.

`assets/tagged/cuvs-yhwh/` is what "tap a word to see the original" prints:
`originals_sheet.dart` renders those runs verbatim *instead of* the reader's
verse whenever `TaggedTextService.coversVerse` says the runs lose nothing. So
a stray character in this asset is a stray character in scripture on screen.

Fourteen verses carried one. 詩篇 115:17 printed 「死人不能)讚美雅偉」,
馬可福音 15:13 opened with a bare 「)」, 列王紀上 8:53 read 「主雅偉啊！}你將」,
利未記 11:7 read 「因為{蹄分兩瓣」. Every one of the fourteen passes
`coversVerse` — ASCII is not an ideograph, so the guard that hides a tagged
line which has lost a word cannot see a bracket that was never in the verse —
which means all fourteen were being printed, not hidden.

**The rule is derived, not chosen.** Across 62,204 reading verses
(`assets/cuvs-yhwh.json` and `-tr.json`) the characters `(`, `)`, `{`, `}`
occur **zero** times. Across the tagged corpus they occur 1, 7, 3 and 4 times.
A character the edition never uses, in the second transcription only, is
import damage.

**Three shapes, and the third was nearly got wrong.**

* Seven bare `{`/`}` and five bare `)` have no partner anywhere in the corpus —
  no cross-verse pair exists for any of them, unlike the CUV's own 〔…〕
  variant brackets, which legitimately span two verses eleven times. They are
  deleted.
* 路加福音 8:45 stores `〔有古卷在此有："你還問摸我的是誰嗎？")` — the corpus's
  **only** unmatched `〔` (1290 against 1289 `〕`, and the sole other imbalance
  is the genuine 使徒行傳 28:28/29 pair). The reading asset closes the same
  note with `〕` in the same verse, so the `)` becomes `〕`. The two ASCII `"`
  in that run are deliberately left: the tagged corpus inlines notes as
  `〔或作："亞干井"〕` in 2,710 places, and whether this edition's apparatus
  should be set full-width is an open question held for the user.
* 創世記 48:7 stores `(以法他就是伯利恆)` — the one balanced ASCII pair, and
  the one this tool first proposed to leave alone as a typographic preference
  rather than a defect. A refuter broke that, and then broke the reason given
  for breaking it, so the argument is worth stating exactly.

  Not every witness agrees on the mark: git blob `7a2dc43`, an import
  unrelated to the shipped files, writes `〈以法他就是伯利恆〉`, and the printed
  1919 page brackets nothing at all. So "every witness says full-width" would
  be false. What settles it is narrower and local — this run is printed *in
  place of* `assets/cuvs-yhwh.json`'s line on the same sheet, so the mark it
  has to match is that file's, and both shipped reading assets (`-tr.json`
  too) write `（）` here. The corpus agrees with itself: 351 full-width pairs
  against one ASCII. It is converted, not deleted, because unlike the strays
  it is a real gloss the reader's verse also brackets.

**Nothing is deleted on the strength of the rule alone.** Each verse must
also pass three checks: the reading verse for the same reference carries none
of `(){}` either, the Chinese is conserved character for character, and the
verse does not move away from the reader's verse. A verse failing any of them
is reported and left for a human.

Usage:
    python3 tools/repair_tagged_stray_brackets.py [--write]
"""

from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import repair_tagged_markup as markup  # noqa: E402

TAGGED = markup.TAGGED
ASCII_BRACKETS = "(){}"
CJK = re.compile(markup.CJK)


def chinese(text: str) -> list[str]:
    return sorted(c for c in text if CJK.fullmatch(c))


def repair_verse(runs: list[str]) -> list[str] | None:
    """Rewrite the runs of one verse, or None if no ASCII bracket is in it."""
    verse = "".join(runs)
    if not any(c in verse for c in ASCII_BRACKETS):
        return None

    paired_parens = verse.count("(") == verse.count(")") and "(" in verse
    closes_a_note = (
        verse.count("〔") == verse.count("〕") + 1
        and verse.count(")") == 1
        and "(" not in verse
    )

    out = []
    for run in runs:
        if paired_parens:
            run = run.replace("(", "（").replace(")", "）")
        elif closes_a_note:
            run = run.replace(")", "〕")
        else:
            run = run.replace(")", "")
        out.append(run.replace("{", "").replace("}", ""))
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true")
    args = ap.parse_args()

    reading = markup.reading_index()
    repaired: list[str] = []
    refused: list[str] = []

    for path in sorted(TAGGED.glob("*.json")):
        book = json.loads(path.read_text("utf-8"))
        verses = reading.get(path.stem, {})
        touched = False

        for ref, runs in book.items():
            before = [r.get("w", "") for r in runs]
            after = repair_verse(before)
            if after is None:
                continue
            where = f"{path.stem} {ref}"
            reading_text = verses.get(ref)
            if reading_text is None:
                refused.append(f"{where}: no reading verse to check against")
                continue
            if any(c in reading_text for c in ASCII_BRACKETS):
                refused.append(f"{where}: the reading verse uses ASCII brackets too")
                continue
            if chinese("".join(before)) != chinese("".join(after)):
                refused.append(f"{where}: the Chinese changed")
                continue
            joined_before, joined_after = "".join(before), "".join(after)
            if markup.distance(reading_text, joined_after) > markup.distance(
                reading_text, joined_before
            ):
                refused.append(f"{where}: moves away from the reader's verse")
                continue
            for run, text in zip(runs, after):
                run["w"] = text
            repaired.append(f"{where}: {joined_before}\n      -> {joined_after}")
            touched = True

        if touched and args.write:
            path.write_text(
                json.dumps(book, ensure_ascii=False, separators=(",", ":")), "utf-8"
            )

    print(f"repaired: {len(repaired)} verses")
    for line in repaired:
        print(f"  -- {line}")
    if refused:
        print(f"\nleft for a human: {len(refused)}")
        for line in refused:
            print(f"  -- {line}")
    if not args.write:
        print("\n(dry run — pass --write to apply)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
