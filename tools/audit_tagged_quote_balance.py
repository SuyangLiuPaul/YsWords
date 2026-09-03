#!/usr/bin/env python3
"""Where the word-tap corpus opens a quotation and does not close it.

`assets/tagged/cuvs-yhwh/` carries 6,435 `“` against 5,840 `”`. The raw
surplus reads like 595 lost marks; almost none of it is.

THE PREMISE, because five different premises give five different numbers and
the queue entry that opened this item quoted one of them without stating it:

  * `“` and `”` ONLY. `‘`/`’` is this edition's level-2 mark and balances on
    its own books (269 verses, a separate population); `「」`/`『』` do not
    occur in the Simplified corpus at all.
  * `〔…〕` note markup stripped from the tagged line first. The corpus inlines
    a translator note where the reading asset writes `<note: …>`, and one of
    those notes carries a quotation mark of its own (西 1:23).
  * A running stack PER BOOK, verse order. Not per verse — this edition
    routinely opens a quotation in one verse and closes it in another, so a
    per-verse test measures the house style rather than a defect. Not
    corpus-wide either: a corpus-wide stack has 595 unmatched opens sitting on
    it and swallows every orphan closer that follows.

On that premise, over 31,102 verses:

    2,485  verses hold more `“` than `”`
       35  of 66 books never reconcile (unclosed opens, or an orphan closer)
        9  close-before-open events — a `”` arriving with nothing open
      604  opens still on the stack at the end of their book
            (deuteronomy 115, leviticus 90, luke 83, ezekiel 70, exodus 60)

The queue entry said 2,480. It is not reproducible at any commit: the figure
is 2,487 before the three-verse speaker-attribution repair (`d03c81d2`) and
2,485 at every commit since. Its other six figures reproduce exactly.

WHAT THE 2,488 VERSES ACTUALLY ARE. Take every `“` that does not close in its
own verse — 1,884 that close in a LATER verse of the same book, 604 that never
close — and ask what the FROZEN reading asset does at the same reference:

    1,244  the reading asset punctuates the verse identically. This edition's
           own text, in a file this repo is not allowed to edit. Not an import
           artifact of any kind.
    1,243  the reading asset carries no quotation mark in that verse at all.
           The tagged corpus is a separate transcription line and punctuates
           4,043 verses the reading text leaves bare; there is no second
           reading to compare against, so there is nothing to repair towards.
        1  詩篇 11:1 — the ONLY verse in the whole population where the two
           imports punctuate the same verse differently, and it is a
           disagreement about SCOPE rather than a lost mark. The frozen edition
           closes the taunt at the end of 11:1 (`…飛往你的山去。”`); the tagged
           corpus runs it through 11:3 (`…還能做甚麼呢？”`). Both are complete
           quotations; neither has lost anything. Blob `7a2dc43` punctuates
           Psalm 11 not at all, so there is no third line. Left alone under the
           使徒行傳 9:29 rule in docs/cuv-yhwh-publisher-notes.md.

So the 2,480-verse headline is not a defect population at all, and the queue
was right to say "do not sweep it". Half of it is the frozen edition's own
house style, half of it is punctuation only the tagged corpus carries, and the
residue is one verse that needs the publisher rather than a script.

THE TRACTABLE CUT the queue named — the close-before-open events — is real,
and it splits cleanly down the same line. Four of the nine are marks the FROZEN
reading asset carries identically, so repairing them in the corpus alone would
make the word-tap sheet disagree with the pane behind it; five were the tagged
corpus's alone and three verses carried them.

`repair_tagged_orphan_close_quote.py` applies those three. This file refuses
(exit 1) on any orphan closer that is not in EXPLAINED below, so a re-import
that brings one back is reported rather than absorbed.
"""
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
OURS = REPO / "assets/cuvs-yhwh.json"
TAGGED = REPO / "assets/tagged/cuvs-yhwh"

OPEN, CLOSE = "“", "”"
TAGGED_NOTE = re.compile(r"〔[^〕]*〕")
OUR_NOTE = re.compile(r"<note:[^>]*>")

BOOKS = """genesis exodus leviticus numbers deuteronomy joshua judges ruth
1_samuel 2_samuel 1_kings 2_kings 1_chronicles 2_chronicles ezra nehemiah
esther job psalms proverbs ecclesiastes song_of_solomon isaiah jeremiah
lamentations ezekiel daniel hosea joel amos obadiah jonah micah nahum
habakkuk zephaniah haggai zechariah malachi matthew mark luke john acts
romans 1_corinthians 2_corinthians galatians ephesians philippians
colossians 1_thessalonians 2_thessalonians 1_timothy 2_timothy titus
philemon hebrews james 1_peter 2_peter 1_john 2_john 3_john jude
revelation""".split()

# Orphan closers this file has read one at a time. Anything else is a hit.
#
# The four kept ones are all carried IDENTICALLY by the frozen reading asset,
# which is what disqualifies them: the corpus would have to be edited away from
# the edition it is a transcription of. Blob `7a2dc43` (the plain 和合本
# Traditional) shows three of the four are genuine losses in this edition —
# they are the publisher's to fix, not ours.
EXPLAINED = {
    "exodus 3:5": (
        "`神说：不要近前来…是圣地。”` — no opener. The witness reads "
        "`神說：「不要近前來…是聖地」；`, so this edition lost the opening mark. "
        "The FROZEN reading asset reads exactly as the corpus does, so the loss "
        "is upstream of both imports. Publisher."
    ),
    "ruth 1:17": (
        "Ruth's speech closes at the end of 1:16 AND again at the end of 1:17 "
        "without reopening. The frozen reading asset and the witness both do "
        "the same. This edition's own convention for a speech that runs on."
    ),
    "ezekiel 3:9": (
        "REPAIRED — `repair_tagged_orphan_close_quote.py` restores the opener "
        "at 結 3:4. Kept here so a re-import that drops it again is reported."
    ),
    "1_samuel 23:7": (
        "REPAIRED (twice over) — `说：”` at the second speech colon was a "
        "closing mark where an opening one belongs."
    ),
    "amos 9:13": "REPAIRED — the same `说：”` shape.",
    "amos 9:15": "REPAIRED by 9:13's substitution; the closer now has its open.",
    "mark 5:34": (
        "`耶稣对她说：‘女儿…痊愈了。”` — a level-2 opener closed by a level-1 "
        "mark. The witness reads `說：「女兒…痊癒了。」`, so the opener is the "
        "wrong mark, not the closer. Carried identically by the frozen reading "
        "asset. Publisher."
    ),
    "colossians 1:23": (
        "The note itself is mangled: `失去〔原文是“离开〕”福音的盼望` puts the "
        "opener inside the bracket and leaves the closer outside it, where it "
        "prints as scripture. The frozen reading asset carries the same split "
        "(`<note: 原文是“离开>”福音的盼望`) and the witness's note has no "
        "quotation marks at all. Publisher."
    ),
}


def load_tagged():
    out = {}
    for n, slug in enumerate(BOOKS, 1):
        book = json.loads((TAGGED / f"{slug}.json").read_text(encoding="utf-8"))
        rows = []
        for key, runs in book.items():
            chapter, verse = (int(p) for p in key.split(":"))
            rows.append(
                (
                    chapter,
                    verse,
                    key,
                    f"{n:03d}{chapter:03d}{verse:03d}",
                    "".join(r.get("w", "") for r in runs),
                )
            )
        rows.sort(key=lambda r: (r[0], r[1]))
        out[slug] = rows
    return out


def main():
    ours = {row["id"]: row["text"] for row in json.loads(
        OURS.read_text(encoding="utf-8"))}
    tagged = load_tagged()

    events = []
    unclosed = {}
    per_verse_surplus = 0
    opens_closed_later = set()
    opens_never_closed = set()

    for slug, rows in tagged.items():
        stack = []
        for _, _, key, _vid, raw in rows:
            line = TAGGED_NOTE.sub("", raw)
            if line.count(OPEN) > line.count(CLOSE):
                per_verse_surplus += 1
            for ch in line:
                if ch == OPEN:
                    stack.append(key)
                elif ch == CLOSE:
                    if stack:
                        opened = stack.pop()
                        if opened != key:
                            opens_closed_later.add((slug, opened))
                    else:
                        events.append(f"{slug} {key}")
        if stack:
            unclosed[slug] = len(stack)
            for key in stack:
                opens_never_closed.add((slug, key))

    reconciled = sum(
        1
        for slug in BOOKS
        if slug not in unclosed
        and not any(e.startswith(slug + " ") for e in events)
    )

    print(f"verses with more {OPEN} than {CLOSE} : {per_verse_surplus}")
    print(f"books that never reconcile        : {len(BOOKS) - reconciled}"
          f" of {len(BOOKS)}")
    print(f"close-before-open events          : {len(events)}")
    print(f"opens never closed in their book  : {sum(unclosed.values())}")
    top = sorted(unclosed.items(), key=lambda kv: -kv[1])[:5]
    print("    " + ", ".join(f"{slug} {n}" for slug, n in top))

    # What the frozen reading asset says about each verse that carries an open
    # it does not close.
    population = opens_closed_later | opens_never_closed
    agrees = bare = differs = 0
    different = []
    index = {slug: {r[2]: r for r in rows} for slug, rows in tagged.items()}
    for slug, key in sorted(population):
        row = index[slug][key]
        line = TAGGED_NOTE.sub("", row[4])
        theirs = OUR_NOTE.sub("", ours.get(row[3], ""))
        pair_t = (line.count(OPEN), line.count(CLOSE))
        pair_r = (theirs.count(OPEN), theirs.count(CLOSE))
        if pair_t == pair_r:
            agrees += 1
        elif pair_r == (0, 0):
            bare += 1
        else:
            differs += 1
            different.append(f"{slug} {key} tagged={pair_t} reading={pair_r}")

    print()
    print(f"verses carrying an open that closes elsewhere or never: "
          f"{len(population)}")
    print(f"    reading asset punctuates identically : {agrees}")
    print(f"    reading asset has no marks at all    : {bare}")
    print(f"    reading asset punctuates DIFFERENTLY : {differs}")
    for line in different:
        print(f"        {line}")

    print()
    unexplained = [e for e in events if e not in EXPLAINED]
    for event in sorted(set(events)):
        print(f"  {event}: {EXPLAINED.get(event, 'UNEXPLAINED')}")
    if unexplained:
        print()
        print(f"FAIL: {len(unexplained)} orphan closer(s) this file has never "
              f"read: {sorted(set(unexplained))}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
