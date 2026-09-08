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
same way and yields a much smaller number — a strict subset of the 1,160,
verified. That is deliberate: the raw census is the conservative one, and
every verse it reports is reported by the production census too. Use the Dart
test for the production figure and this for triage.

`audit_tagged_running_text.py` covers the same two files but answers a different
question — it strips notes from both sides first and asks whether OUR text lost
a character. Its EXPLAINED table therefore dismisses the tagged corpus's own
duplication artifacts with "ours is right, do not repair towards the tagged
copy", which is true of the reading text and says nothing about what the sheet
prints. Seven of those dismissed artifacts were on screen.

WHAT COMES OUT, over 31,102 verses (re-measured 2026-09-09, after `50dcc102`
"Adopt the publisher's current text…" replaced 8,566 verses in the reading
asset — see the retirement note below the tables for why these figures moved
so far from what this docstring said the day before):

    386  hidden by the guard, sheet falls back to the reader's verse
 30,698  tagged line matches ideograph for ideograph
     18  PASS the guard and read long   <- this file

and the 18 split:

     10  note formatting only — identical once notes are stripped from both
         sides. This edition writes a translator note as `<note: …>` in the
         reading asset and inlines it as `〔…〕` in the tagged corpus, and the
         two imports word them differently.
      8  still read long, of which
          4  divine-name or cross-reference NOTE WORDING (unchanged by the
             adoption)
          2  a versification / apparatus-placement shift the adoption made TO
             our own reading asset, moving where a sentence or a bracket
             attaches relative to the tagged corpus's placement, with no text
             lost on either side — see EXPLAINED
          2  CANDIDATE — the adoption's own new discrepancies, filed as a P0
             item, not repaired here (the asset is frozen) — see CANDIDATE

and one class that USED to be here and is not any more, kept in a table so a
re-import that brings one back is reported as a REGRESSION:

      7  DUPLICATION — a character of scripture printed twice. Repaired
         2026-08-24, `repair_tagged_rendered_duplication.py`.
      4  words the tagged import SUPPLIED that this edition does not print.
         Repaired 2026-09-03, `repair_tagged_supplied_words.py`, after four
         witness lines were read for each and the Hebrew was found to be
         carried independently by `assets/originals/` — so deleting the word
         from the sheet costs the app no Strong's number. See that file.

RETIRED 2026-09-09: nine entries that used to sit in EXPLAINED — six of the
〔有古卷在此有…〕 split-bracket family (太 18:11, 太 23:14, 可 15:28, 路 23:17,
约 5:4, 徒 24:7), 馬太福音 17:21 (which had its own note, below), and two
divine-name NOTE WORDING entries (亚 6:14, 亚 8:14) — stopped reading long when
`50dcc102` changed the READING asset's own bracket/note convention to match
the tagged corpus at those ids. Not moved into a REGRESSION-style table: the
mechanism was an external text swap by the publisher, not a repair this
script's tooling performed, so there is nothing here for a future re-import to
regress against — a fresh import would show up as new NEW/EXPLAINED work on
its own terms, not as a reappearance of an old one.

馬太福音 17:21 in particular did not just stop reading long — the internal
DISAGREEMENT it was filed over is now gone. Before `50dcc102`, the reading
asset's 17:20 left its quotation OPEN and closed it at the end of 17:21,
treating 17:21 as scripture; the tagged corpus treated all of 17:21 as a
`〔有古卷在此有21節…〕` apparatus. The adopted text now closes the quotation at
the END of 17:20 and renders 17:21 as exactly that apparatus bracket — i.e.
the reading asset switched sides and now agrees with the tagged corpus. What
is left is a NEW disagreement, reading asset vs. the official witness (git
blob `7a2dc43`), which still sets 17:21 as scripture inside the quotation the
way this edition used to. That is a publisher question, not a tagged-corpus
one, and `docs/和合本雅伟版-请教出版方.md` §二 has been rewritten to ask it.
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
    "038010012": "note wording; tagged quotes the pronoun inside the note",
    # 2026-09-09: `50dcc102` ("Adopt the publisher's current text…") replaced
    # most of the reading asset and, at these two ids, changed which verse a
    # sentence or bracket is attached to relative to the tagged corpus's
    # placement. Checked against both the tagged corpus and `50dcc102^`
    # (pre-adoption): the full text is present on both sides once the pair of
    # verses is read together — nothing is missing, only where it is split.
    #
    # 路 20:30/31: the reading asset now ends v30 after 「第二個、」 and opens
    # v31 with 「第三個也娶過她；」; the tagged corpus (unchanged) keeps both
    # clauses in v30 and opens v31 at 「那七個…」.
    "042020030": "versification shift; 第三个也娶过她 moved from v30 to v31",
    # 徒 28:28/29: the reading asset now ends v28 plain and opens v29 with the
    # whole `〔有古卷在此有：…〕` apparatus self-contained; the tagged corpus
    # (unchanged) still opens the bracket at the end of v28 and closes it at
    # the end of v29, the way the OTHER six 有古卷 entries used to before this
    # same adoption made every one of them self-contained too (see the
    # retirement note in the module docstring).
    "044028028": "bracket-convention shift; 有古卷 apparatus is now self-contained on v29",
}

# Genuine candidates, opened 2026-09-09 by the SAME adoption commit
# (`50dcc102`) that retired the entries the module docstring lists above.
# Verified against BOTH the official witness (git blob `7a2dc43`, the plain
# 耶和華 edition the repair layer itself reads) and the independent tagged
# corpus, which agree with each other and disagree with the adopted text —
# see `docs/autonomous-queue.md` for the full three-way witness table. Filed
# as a P0 item, NOT repaired here: `assets/cuvs-yhwh*.json` are frozen
# (`test/cuvs_yhwh_frozen_test.dart`) and only the owner may thaw them for a
# publisher character, in his own commit.
CANDIDATE = {
    "010002023": "撒下 2:23 — ours reads 枪𨱔, witness+tagged agree on 枪鐏",
    "041015012": "可 15:12 — ours reads 那么, witness+tagged agree on 那么样",
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
    known = repaired.keys() | EXPLAINED.keys() | CANDIDATE.keys()
    regressed = [h for h in real if h[0] in repaired]
    candidates_hit = [h for h in real if h[0] in CANDIDATE]
    fresh = [h for h in real if h[0] not in known]

    for vid, row, line in regressed:
        print(f"\nREGRESSION {vid}  {row['book']} {row['chapter']}:{row['verse']}"
              f"  — {repaired[vid]} is back")
    for vid, row, line in candidates_hit:
        print(f"\nCANDIDATE {vid}  {row['book']} {row['chapter']}:{row['verse']}"
              f"  — {CANDIDATE[vid]}"
              f"  (filed in docs/autonomous-queue.md, not repaired: asset frozen)")
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
    gone = sorted((EXPLAINED.keys() | CANDIDATE.keys()) - {vid for vid, _, _ in real})
    for vid in gone:
        table = EXPLAINED if vid in EXPLAINED else CANDIDATE
        print(f"\n{vid} no longer reads long — update the tables: "
              f"{table[vid]}")

    return 1 if regressed or fresh or gone else 0


if __name__ == "__main__":
    sys.exit(main())
