#!/usr/bin/env python3
"""Verses where the word-tap sheet PRINTS MORE than this edition's scripture.

The Originals sheet renders `assets/tagged/cuvs-yhwh/` **verbatim in place of**
the reader's verse whenever `TaggedTextService.coversVerse` passes
(`lib/widgets/originals_sheet.dart`). `coversVerse` asks only whether the
reader's ideographs survive as a SUBSEQUENCE of the tagged line, so it catches a
tagged line that has LOST a word and is blind to one that has GAINED junk. This
audit is the missing half: it enumerates the verses that pass the guard while
reading long, and splits them into note formatting and real insertions.

WHICH INPUT THIS MEASURES, because it is not production's and the difference is
large. `originals_sheet.dart:709` passes `sanitizeForSearch(vo.verse.text)`, so
production compares against a verse whose `<note: …>` has already been stripped
while the tagged line still carries the note inlined as `〔…〕`. On that input
the class is **1,160 verses**, almost all of it note asymmetry. This file
compares RAW against RAW instead, which makes the two sides express notes the
same way and yields **113** — a strict subset of the 1,160, verified. That is
deliberate: the raw census is the conservative one, and every verse it reports
is reported by the production census too. Use the Dart test for the production
figure and this for triage.

`audit_tagged_running_text.py` covers the same two files but answers a different
question — it strips notes from both sides first and asks whether OUR text lost
a character. Its EXPLAINED table therefore dismisses the tagged corpus's own
duplication artifacts with "ours is right, do not repair towards the tagged
copy", which is true of the reading text and says nothing about what the sheet
prints. Seven of those dismissed artifacts were on screen.

WHAT COMES OUT, over 31,102 verses:

    270  hidden by the guard, sheet falls back to the reader's verse
 30,730  tagged line matches ideograph for ideograph
    102  PASS the guard and read long   <- this file

and the 102 split:

     89  note formatting only — identical once notes are stripped from both
         sides. This edition writes a translator note as `<note: …>` in the
         reading asset and inlines it as `〔…〕` in the tagged corpus, and the
         two imports word them differently.
     13  still read long, of which
          6  divine-name or cross-reference NOTE WORDING
          6  the 〔有古卷在此有…〕 textual-variant convention, where the
             reading asset opens the bracket at the end of the PREVIOUS verse
             and closes it at the end of this one while the tagged corpus
             inlines the whole bracket into this verse alone
          1  馬太福音 17:21, which LOOKS like the six and is not — checked
             individually after a refuter broke the assumption. 太 17:20 does
             not open a bracket, and the print sets 17:21 as plain text with a
             footnote, so the tagged corpus's 「有古卷在此有21節：」 is an
             editorial claim neither this edition nor the print makes there.
             Still queued for the publisher — see the note on EXPLAINED below.

and two classes that USED to be here and are not any more, both kept in tables
so a re-import that brings one back is reported as a REGRESSION:

      7  DUPLICATION — a character of scripture printed twice. Repaired
         2026-08-24, `repair_tagged_rendered_duplication.py`.
      4  words the tagged import SUPPLIED that this edition does not print.
         Repaired 2026-09-03, `repair_tagged_supplied_words.py`, after four
         witness lines were read for each and the Hebrew was found to be
         carried independently by `assets/originals/` — so deleting the word
         from the sheet costs the app no Strong's number. See that file.
"""
import json
import re
import sys
from difflib import SequenceMatcher
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
OURS = REPO / "assets/cuvs-yhwh.json"
TAGGED = REPO / "assets/tagged/cuvs-yhwh"

# `<note: …>` on the reading side; `〔…〕` and `（…）` on the tagged side.
OUR_NOTE = re.compile(r"<note:[^>]*>")
TAGGED_NOTE = re.compile(r"〔[^〕]*〕|（[^）]*）")

BOOKS = """genesis exodus leviticus numbers deuteronomy joshua judges ruth
1_samuel 2_samuel 1_kings 2_kings 1_chronicles 2_chronicles ezra nehemiah
esther job psalms proverbs ecclesiastes song_of_solomon isaiah jeremiah
lamentations ezekiel daniel hosea joel amos obadiah jonah micah nahum
habakkuk zephaniah haggai zechariah malachi matthew mark luke john acts
romans 1_corinthians 2_corinthians galatians ephesians philippians
colossians 1_thessalonians 2_thessalonians 1_timothy 2_timothy titus
philemon hebrews james 1_peter 2_peter 1_john 2_john 3_john jude
revelation""".split()

# The seven duplications, repaired 2026-08-24. Kept here rather than deleted so
# a re-import that reintroduces one is reported as a REGRESSION, not as a new
# unexamined hit. The printed 1919 confirms the reading text in all seven.
REPAIRED_DUPLICATION = {
    "003005007": "tagged read 力量若若不够",
    "009020037": "tagged read 说：“箭箭不是在你前头吗",
    "011019018": "tagged read 屈膝的，未未曾与巴力亲嘴",
    "012010005": "tagged read 说：“我们我们是你的仆人",
    "018031036": "tagged read 愿那敌我敌者",
    "026036001": "tagged read 你要要对以色列山发预言",
    "040009028": "tagged read 耶稣说说：",
}

# Reads long, read individually, and NOT a scripture defect.
EXPLAINED = {
    # Note wording. The tagged import spells the divine-name gloss out in full
    # (〔"我"原文是"雅伟"〕 for our <note: 原文是"雅伟">) and repeats it where
    # the reading asset writes the gloss once and marks the second place [雅伟].
    "001018019": "note wording; tagged repeats the 原文是雅伟 gloss",
    "002024001": "note wording; ours marks the second place [雅伟]",
    "014029006": "note wording; ours marks the second place [雅伟]",
    "038006014": "note wording; tagged quotes the name inside the note",
    "038008014": "note wording; tagged reads 万军之雅伟说的 for 说",
    "038010012": "note wording; tagged quotes the pronoun inside the note",
    # The 〔有古卷在此有…〕 convention. The bracket opens at the end of the
    # PREVIOUS verse in the reading asset and closes at the end of this one, so
    # the reading verse carries only its half; the tagged corpus inlines the
    # whole apparatus into this verse. Nothing is missing on either side.
    # NOT one of the six below, though it reads like one. 太 17:20 ends
    # 「…沒有一件不能做的事了。」 and opens no bracket, and the printed 1919
    # sets 17:21 as plain text with a footnote. The tagged corpus supplies the
    # whole 「有古卷在此有21節：」 apparatus by itself.
    #
    # 2026-09-03, a THIRD line of evidence, structural and from inside the
    # frozen asset itself: the reading asset's 太 17:20 ends 「…不能做的事了。」
    # with its quotation still OPEN, and closes it at the end of 17:21
    # (「…不能趕它出來>。”」). This edition can only be reading 17:21 as
    # scripture inside the speech opened at 17:20 — an apparatus bracket would
    # not close a quotation. Blob `7a2dc43` does exactly the same thing, AND
    # sets （有古卷加：…） across 18:10/18:11 where the convention does apply.
    # So it is two independent lines against the tagged import, not the
    # symmetric standoff this entry used to describe.
    #
    # STILL not deleted, and the reason is now the only one left: what would be
    # deleted is an instance of the publisher's OWN apparatus notation, which
    # is the exact class docs/cuv-yhwh-publisher-notes.md was written about
    # after this repo removed the publisher's notation three times. Undoing it
    # also needs a SECOND edit — the tagged 17:20's `”`, which the frozen asset
    # does not carry — or 17:21's closer would be left orphaned. Both edits are
    # ready and neither touches a Strong's number (the tagged 17:21 is one
    # untagged run); they need the publisher's word, not a script's.
    "040017021": "tagged supplies a 有古卷在此有21節 apparatus 太 17:20 does not open",
    "040018011": "有古卷在此有 bracket; opener is on 太 18:10",
    "040023014": "有古卷在此有 bracket; opener is on 太 23:13",
    "041015028": "有古卷在此有 bracket; opener is on 可 15:27",
    "042023017": "有古卷在此有 bracket; opener is on 路 23:16",
    "043005004": "有古卷在此有 bracket; opener and 等候水动 are on 约 5:3",
    "044024007": "有古卷在此有 bracket; opener and 要按我们的律法审问 are on 徒 24:6",
}

# The four supplied words, repaired 2026-09-03. Kept here rather than deleted
# so a re-import that reintroduces one is reported as a REGRESSION, not as a
# new unexamined hit.
#
# They were held for four months on the argument that three of them render
# something the Hebrew really has (我請求 = H4994 נָא, 葡萄園 = H3754 כֶּרֶם,
# 現在 = H6258 עַתָּה) and that deleting them would cost the app its account of
# the Hebrew. It does not: the word-chip row under the verse is built from
# `assets/originals/`, where all four words already sit with their own chip and
# lexicon entry. `repair_tagged_supplied_words.py` carries the four witness
# lines and the rest of the reasoning.
REPAIRED_SUPPLIED = {
    "007015002": "tagged supplied 我请求; print reads 你可以娶來代替他罷",
    "007015005": "tagged supplied 葡萄园; print reads 並橄欖園盡都燒了",
    "007015018": "tagged supplied 现在; print reads 豈可任我渴死",
    "010021002": "tagged read 大发热心; print reads 卻爲以色列人和猶大人發熱心",
}


def load_tagged():
    out = {}
    for n, slug in enumerate(BOOKS, 1):
        book = json.loads((TAGGED / f"{slug}.json").read_text(encoding="utf-8"))
        for key, runs in book.items():
            chapter, verse = key.split(":")
            out[f"{n:03d}{int(chapter):03d}{int(verse):03d}"] = "".join(
                r.get("w", "") for r in runs
            )
    return out


def ideographs(text):
    """The same code units `TaggedTextService._ideographs` keeps."""
    return "".join(c for c in text if 0x3400 <= ord(c) <= 0x9FFF)


def covers(tagged, verse):
    """`TaggedTextService.coversVerse`, on ideographs of the RAW text."""
    if not verse:
        return True
    i = 0
    for unit in tagged:
        if unit == verse[i]:
            i += 1
            if i == len(verse):
                return True
    return False


def main():
    ours = json.loads(OURS.read_text(encoding="utf-8"))
    tagged = load_tagged()

    hidden = exact = 0
    long_hits = []
    for row in ours:
        vid = row["id"]
        if vid not in tagged:
            continue
        verse = ideographs(row["text"])
        line = ideographs(tagged[vid])
        if not covers(line, verse):
            hidden += 1
        elif line == verse:
            exact += 1
        else:
            long_hits.append((vid, row, tagged[vid]))

    note_only = []
    real = []
    for vid, row, line in long_hits:
        stripped_ours = ideographs(OUR_NOTE.sub("", row["text"]))
        stripped_tagged = ideographs(TAGGED_NOTE.sub("", line))
        (note_only if stripped_ours == stripped_tagged else real).append(
            (vid, row, line)
        )

    print(f"hidden by coversVerse : {hidden}")
    print(f"matches exactly       : {exact}")
    print(f"passes and reads long : {len(long_hits)}")
    print(f"  note formatting only: {len(note_only)}")
    print(f"  reads long on scripture: {len(real)}")

    repaired = {**REPAIRED_DUPLICATION, **REPAIRED_SUPPLIED}
    known = repaired.keys() | EXPLAINED.keys()
    regressed = [h for h in real if h[0] in repaired]
    fresh = [h for h in real if h[0] not in known]

    for vid, row, line in regressed:
        print(f"\nREGRESSION {vid}  {row['book']} {row['chapter']}:{row['verse']}"
              f"  — {repaired[vid]} is back")
    for vid, row, line in fresh:
        extra = "".join(
            ideographs(line)[j1:j2]
            for tag, i1, i2, j1, j2 in SequenceMatcher(
                None, ideographs(row["text"]), ideographs(line), autojunk=False
            ).get_opcodes()
            if tag in ("insert", "replace")
        )
        print(f"\nNEW {vid}  {row['book']} {row['chapter']}:{row['verse']}"
              f"  tagged adds {extra!r}")
        print(f"  ours  : {row['text']}")
        print(f"  tagged: {line}")

    # A triage note whose verse stopped reading long is drift too: a stale
    # entry can go on to swallow a real hit at the same id.
    gone = sorted(EXPLAINED.keys() - {vid for vid, _, _ in real})
    for vid in gone:
        print(f"\n{vid} no longer reads long — update the tables: "
              f"{EXPLAINED[vid]}")

    return 1 if regressed or fresh or gone else 0


if __name__ == "__main__":
    sys.exit(main())
