#!/usr/bin/env python3
"""Three verses where the word-tap corpus closes a quotation it never opened.

`audit_tagged_quote_balance.py` finds nine close-before-open events in
`assets/tagged/cuvs-yhwh/` — a `”` arriving with nothing on a per-book stack.
Four of them the FROZEN reading asset carries identically and are left alone
(出 3:5, 得 1:17, 可 5:34, 西 1:23); repairing those in the corpus alone would
make the word-tap sheet disagree with the pane behind it, and blob `7a2dc43`
shows three of the four are losses this edition made before either import
existed. They belong to the publisher.

The remaining five events live in three verses that the reading asset does not
punctuate at all, so nothing behind the sheet contradicts the repair.

**撒母耳記上 23:7 and 阿摩司書 9:13 — `说：”` where `说：“` belongs.**

    23:7  有人告诉扫罗说：“大卫到了基伊拉。”扫罗说：”他进了有门有闩的城…
     9:13 雅伟说：”日子将到，耕种的必接续收割的…

`：”` occurred exactly TWICE in the whole corpus, against **5,096** `：“`, and
**zero** times in either reading asset. A closing mark cannot stand at a speech
colon in any convention — there is nothing yet open for it to close — so this
is not a preference, it is a mark set the wrong way round. 撒上 23:7 settles
itself inside its own verse: its FIRST `说：` six characters earlier carries
`“`. The witness reads `掃羅說：「他進了有門有閂的城` at exactly that position.

The substitution is what makes both books whole. 撒上 23:7 goes from one open
and three closes to two and two; 阿摩司書's book-long stack goes from 41 opens
against 43 closes to 42 against 42, and the closer at 9:15 — the fifth of the
nine events — acquires the open it was missing. Two characters, two books
reconciled.

**以西結書 3:4 — the opener was lost, not the closer added.**

以西結書 3:9 ends `…也不要因他们的脸色惊惶。”` and no `“` occurs anywhere
earlier in the book. Deleting that closer is the wrong direction, and four
lines say so:

 1. Its presence proves the corpus meant to punctuate this speech. A
    transcription that was not marking Ezekiel would not have closed it.
 2. The corpus's own local convention. Every other divine address in 以西結書
    2–3 is set `说：“` — 2:1, 2:3, 3:1, 3:3, 3:10, 3:12, 3:22, 3:24 — and each
    closes: 2:1 in its own verse, 2:3 at 2:8, 3:10 at 3:11. 3:4 is the only
    `他对我说：` in the chapter with no mark after the colon.
 3. The witness, independently: `7a2dc43` reads
    `他對我說：「人子啊，你往以色列家那裡去` at 3:4 and closes at 3:9, the same
    span, and it marks 2:1/2:3/3:1/3:3/3:10 the same way we do.
 4. Nothing behind the sheet disagrees — the reading asset carries no
    quotation mark anywhere in 以西結書, in either script.

So the mark is APPENDED to the run that already ends `他对我说：`, which is
where all eight neighbours put theirs. No run boundary moves, no Strong's
number moves, and the run keeps its H559 and its H8799.

Nothing here changes a Chinese character: the ideograph stream of all three
verses is byte-identical before and after, which is the invariant that keeps a
punctuation repair from becoming a claim about the text.

Idempotent; refuses on drift rather than guessing.
"""
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
TAGGED = REPO / "assets/tagged/cuvs-yhwh"

# (book file, verse key, run index, text before, text after)
EDITS = [
    ("1_samuel", "23:7", 7, "说：”", "说：“"),
    ("amos", "9:13", 1, "说：”", "说：“"),
    ("ezekiel", "3:4", 0, "他对我说：", "他对我说：“"),
]


def ideographs(text):
    return "".join(c for c in text if 0x3400 <= ord(c) <= 0x9FFF)


def main():
    changed = {}
    edits = 0

    def book_of(slug):
        if slug not in changed:
            changed[slug] = json.loads(
                (TAGGED / f"{slug}.json").read_text(encoding="utf-8"))
        return changed[slug]

    for slug, key, index, before, after in EDITS:
        runs = book_of(slug)[key]
        if index >= len(runs):
            print(f"REFUSING: {slug} {key} has {len(runs)} runs, expected "
                  f"index {index}")
            return 1
        run = runs[index]
        if run["w"] == after:
            continue
        if run["w"] != before:
            print(f"REFUSING: {slug} {key} run {index} reads {run['w']!r}, "
                  f"expected {before!r} or {after!r}")
            return 1
        before_line = "".join(r.get("w", "") for r in runs)
        run["w"] = after
        after_line = "".join(r.get("w", "") for r in runs)
        if ideographs(before_line) != ideographs(after_line):
            print(f"REFUSING: {slug} {key} would change an ideograph")
            return 1
        edits += 1

    if not edits:
        print("nothing to do")
        return 0

    for slug, book in changed.items():
        (TAGGED / f"{slug}.json").write_text(
            json.dumps(book, ensure_ascii=False, separators=(",", ":")),
            encoding="utf-8",
        )
    print(f"{edits} quotation marks repaired across {len(changed)} books")
    return 0


if __name__ == "__main__":
    sys.exit(main())
