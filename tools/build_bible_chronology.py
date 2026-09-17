#!/usr/bin/env python3
"""Build `assets/bible_chronology.json` — the data behind the
interactive chronology chart on the Bible Timeline page.

Two layers, one axis:

  * LIFELINES, computed from the Masoretic begetting ages Genesis
    states, chapters 5 and 11 for Adam → Abraham, 16 for Ishmael, and
    21, 25 and 35/47 for Isaac and Jacob, and 41, 45, 47 and 50 for
    Joseph (Adam → Joseph, with Ishmael a branch off Abraham). Every
    year traces to a verse — directly, for most; Shem's, Abraham's and
    Joseph's begetting-age figures are each chained together from
    multiple verses instead, since no single verse states outright
    what age their father was (see CHAIN and DERIVED_PEOPLE).
  * EVENTS, read from `assets/bible_timeline.json` and PLACED on the
    same Anno Mundi axis through the 4004 BC anchor, so the chart spans
    Creation → Revelation exactly as the event list on the same page
    does. Nothing is re-dated on the way across; where both files date
    the same event the computed marker governs and the timeline's own
    figure is carried beside it (see DUPLICATES).

Why a separate asset from `assets/family_tree.json`:

  * The family tree answers "who descends from whom". The chart answers
    "who was alive at the same time", which needs a birth AND a death
    year on one internally-consistent scale, plus the chronology scheme
    each year belongs to. `family_tree.json` mixes two scales — Anno
    Mundi for Genesis 5/11, and BC years on a *different* (late-date)
    scheme from Abraham onward — so it cannot be plotted as one axis.
  * Every year here must be traceable to a verse. This file carries the
    citation and the arithmetic alongside each number;
    `test/bible_chronology_test.dart` fails the build if any is missing.

Provenance: names/localisations are lifted from `assets/family_tree.json`
(our own curated data). Years are recomputed here from the begetting
ages Genesis states, chained Adam to Joseph, and checked against
family_tree's AM values.

NOTHING here is transcribed from the reference chart in
`docs/reference/` — that sheet is under copyright and is a reference for
the IDEA (parallel lifelines, descent colouring), not a data source.

Run:  python3 tools/build_bible_chronology.py
"""

import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FAMILY = os.path.join(ROOT, "assets", "family_tree.json")
TIMELINE = os.path.join(ROOT, "assets", "bible_timeline.json")
OUT = os.path.join(ROOT, "assets", "bible_chronology.json")

# ── The AM axis, and how a BC/AD year lands on it ───────────────────
#
# `assets/bible_timeline.json` dates its events in signed BC/AD years.
# The chart's axis is Anno Mundi. Converting between them needs the
# anchor and nothing else, and the anchor is `creationBc` on the active
# scheme — 4004, Ussher. There is NO year zero: 1 BC is followed by
# AD 1, so the two branches below are off by one from each other on
# purpose. Checked at both ends in `test/bible_chronology_test.dart`:
# AD 1 is AM 4004 and AD 95 (Revelation) is AM 4098.
CREATION_BC = 4004


def year_to_am(year):
    if year == 0:
        raise ValueError("there is no year zero")
    if year < 0:
        return CREATION_BC + year          # -4000 BC → AM 4
    return CREATION_BC - 1 + year          # AD 1 → AM 4004


# ── Where the two files describe the SAME event ─────────────────────
#
# Both assets date Creation, Enoch, the Flood, Abram's call and Isaac's
# birth. Showing each of those twice would be a bug; showing them at two
# different years would be worse. So one governs, and it is the
# chronology marker — its year is COMPUTED from the ages Genesis 5 and
# 11 state, whereas the timeline's is a placement. The timeline's figure
# is not thrown away: it is carried on the marker as `placedYear` and
# surfaced in the marker's detail sheet, so a reader sees the size of
# the disagreement rather than being handed the winner silently.
#
# Measured deltas (timeline year → chronology marker, in years):
#   creation      -4000 vs 4004 BC   →  the timeline rounds; 4 years
#   enoch_walks   -3000 vs 3017 BC   →  the timeline rounds; 17 years
#   flood         -2348 vs 2348 BC   →  exact agreement, 0 years
#   abram_called  -2091 vs 1921 BC   →  170 years — a real scheme clash
#   isaac_born    -2066 vs 1896 BC   →  170 years — the same clash
#
# The last two are the late-date scheme `assets/family_tree.json` uses
# for the patriarchs, already documented there as deliberately
# unreconciled. It is not fudged here either: see CONTESTED below.
DUPLICATES = {
    # timeline event id : chronology marker id it duplicates
    "creation": "creation",
    "enoch_walks": "enoch_taken",
    "flood": "flood",
    "abram_called": "abram_call",
    "isaac_born": "isaac_born",
}

# Placed events that earn a "Jump to" chip beside the computed markers.
# Kept short on purpose: the chips wrap, and a phone cannot carry 98 of
# them. Everything else is reachable by tapping its tick.
PINNED_EVENTS = [
    "exodus",
    "temple_built",
    "judah_falls",
    "jesus_born",
    "crucifixion",
    "john_patmos",
]

# Era palette and labels. These MIRROR `_eraColor` / `_eraLabel` in
# `lib/pages/bible_timeline_page.dart` so the two views of the one page
# band the same centuries the same colour; the test file asserts every
# hex below still appears in that source.
ERA_STYLE = {
    "antediluvian": ("#6B5E3F", "Antediluvian (Creation → Flood)",
                     "洪水之前（创世 → 洪水）", "洪水之前（創世 → 洪水）"),
    "patriarchs": ("#8C5A2F", "Patriarchs (Abraham → Joseph)",
                   "列祖时代（亚伯拉罕 → 约瑟）", "列祖時代（亞伯拉罕 → 約瑟）"),
    "mosaic": ("#B42E2E", "Exodus & Wilderness",
               "出埃及与旷野", "出埃及與曠野"),
    "conquest": ("#2F7C5C", "Conquest & Judges",
                 "征服与士师", "征服與士師"),
    "monarchy": ("#2A4FB0", "United & Divided Monarchy",
                 "联合与分裂王国", "聯合與分裂王國"),
    "exile": ("#5F3F86", "Exile & Return", "被掳与回归", "被擄與回歸"),
    "intertestamental": ("#505590", "Inter-Testamental Period",
                         "两约之间", "兩約之間"),
    "nt": ("#B8860B", "New Testament", "新约", "新約"),
}

# ── The begetting-age chain, Adam to Joseph ──────────────────────────
#
# (personId, fatherId, father's age at the son's birth, total lifespan,
#  birth citation, death citation, extra citations)
#
# Adam is year zero by definition — the scale is "years since Creation",
# so his birth needs no begetting age.
CHAIN = [
    # id            father         begat  lived  birth ref(s)                        death ref(s)
    ("adam",        None,          None,  930,   ["Genesis 5:1-2"],                  ["Genesis 5:5"]),
    ("seth",        "adam",        130,   912,   ["Genesis 5:3"],                    ["Genesis 5:8"]),
    ("enosh",       "seth",        105,   905,   ["Genesis 5:6"],                    ["Genesis 5:11"]),
    ("kenan",       "enosh",       90,    910,   ["Genesis 5:9"],                    ["Genesis 5:14"]),
    ("mahalalel",   "kenan",       70,    895,   ["Genesis 5:12"],                   ["Genesis 5:17"]),
    ("jared",       "mahalalel",   65,    962,   ["Genesis 5:15"],                   ["Genesis 5:20"]),
    ("enoch",       "jared",       162,   365,   ["Genesis 5:18"],                   ["Genesis 5:23", "Genesis 5:24"]),
    ("methuselah",  "enoch",       65,    969,   ["Genesis 5:21"],                   ["Genesis 5:27"]),
    ("lamech",      "methuselah",  187,   777,   ["Genesis 5:25"],                   ["Genesis 5:31"]),
    ("noah",        "lamech",      182,   950,   ["Genesis 5:28-29"],                ["Genesis 9:29"]),
    # Noah's age when Shem was born is not Genesis 5:32's 500. That
    # verse names Shem, Ham and Japheth together at Noah's 500th year;
    # Genesis 11:10 states Shem was 100, two years after the Flood,
    # when he begat Arphaxad — so Shem was 98 at the Flood, which
    # Genesis 7:6 puts at Noah's 600th year, making Noah 600 - 98 = 502
    # when Shem was born. See DERIVED_PEOPLE below.
    ("shem",        "noah",        502,   600,   ["Genesis 5:32", "Genesis 7:6",
                                                  "Genesis 11:10"],                 ["Genesis 11:11"]),
    ("arphaxad",    "shem",        100,   438,   ["Genesis 11:10"],                  ["Genesis 11:12", "Genesis 11:13"]),
    ("shelah",      "arphaxad",    35,    433,   ["Genesis 11:12"],                  ["Genesis 11:14", "Genesis 11:15"]),
    ("eber",        "shelah",      30,    464,   ["Genesis 11:14"],                  ["Genesis 11:16", "Genesis 11:17"]),
    ("peleg",       "eber",        34,    239,   ["Genesis 11:16"],                  ["Genesis 11:18", "Genesis 11:19"]),
    ("reu",         "peleg",       30,    239,   ["Genesis 11:18"],                  ["Genesis 11:20", "Genesis 11:21"]),
    ("serug",       "reu",         32,    230,   ["Genesis 11:20"],                  ["Genesis 11:22", "Genesis 11:23"]),
    ("nahor_elder", "serug",       30,    148,   ["Genesis 11:22"],                  ["Genesis 11:24", "Genesis 11:25"]),
    ("terah",       "nahor_elder", 29,    205,   ["Genesis 11:24"],                  ["Genesis 11:32"]),
    # Abram's birth is not Terah's 70th year. Genesis 11:26 names three
    # sons at 70 (the eldest); Genesis 11:32 + 12:4 + Acts 7:4 together
    # put Abram's birth in Terah's 130th year — Terah dies at 205 and
    # Abram leaves Haran at 75.
    ("abraham",     "terah",       130,   175,   ["Genesis 11:26", "Genesis 11:32",
                                                  "Genesis 12:4", "Acts 7:4"],       ["Genesis 25:7"]),
    # Ishmael is the chain's first fork, not its next link: he is
    # Abraham's son, not Isaac's ancestor, so his row shares Abraham's
    # father and does not feed anything after it. Both figures are
    # stated directly, unlike Joseph's, so he takes the generic
    # "X was N when Y was born" phrasing. Placed here, ahead of Isaac,
    # for birth order (AM 2094 vs 2108) — not because anything in CHAIN
    # depends on that order beyond a row needing its father's birth
    # already computed, which Abraham's row above supplies either way.
    ("ishmael",     "abraham",     86,    137,   ["Genesis 16:16"],                 ["Genesis 25:17"]),
    # Genesis states both ages directly, so the chain stays continuous
    # one generation further than Genesis 11 alone — see the module
    # docstring.
    ("isaac",       "abraham",     100,   180,   ["Genesis 21:5"],                  ["Genesis 35:28"]),
    # Esau is CHAIN's second fork: Isaac's son but not Jacob's ancestor,
    # so his row shares Isaac's begetting-age link without feeding
    # anything after it — the same shape Ishmael's row takes off
    # Abraham above. Genesis 25:26 dates both twins in the one verse
    # ("she bare them"), so Esau's begetting age is Jacob's own (60);
    # his own death age is never stated anywhere in Scripture — 25:26
    # gives only the birth, 35:29 buries him alongside Jacob at Isaac's
    # death with no age given, and 36:1-43 is his genealogy, again
    # without one — so this is the chart's first OPEN_ENDED row (see
    # below). Placed here, ahead of Jacob, for birth order (Genesis
    # 25:25: "and after that came his brother out").
    ("esau",        "isaac",       60,    None,  ["Genesis 25:26"],                 []),
    ("jacob",       "isaac",       60,    147,   ["Genesis 25:26"],                 ["Genesis 47:28"]),
    # Jacob's age at Joseph's birth (91) is not stated by any single
    # verse — it is CHAINED: Joseph was 30 before Pharaoh (41:46) + 7
    # years of plenty (41:53) + 2 years of famine already passed when he
    # sent for his family (45:6) = 39, Joseph's age when Jacob entered
    # Egypt; Jacob was 130 at that entry (47:9); 130 - 39 = 91. See
    # DERIVED_PEOPLE below — like Shem's and Abraham's rows above, this
    # is a CHAIN link whose "begat" figure is derived rather than
    # directly stated by a single verse, and its derivation sentence
    # says so instead of using the generic "X was N when Y was born"
    # phrasing the single-verse rows get.
    ("joseph",      "jacob",       91,    110,   ["Genesis 41:46", "Genesis 41:53",
                                                  "Genesis 45:6", "Genesis 47:9"],  ["Genesis 50:22", "Genesis 50:26"]),
]

# People Genesis dates only in relation to a CHILD's birth, not a
# father's begetting age — Sarah's own father Terah is named (Genesis
# 20:12) but no begetting age for her is stated, so she cannot be
# chained from him the way CHAIN's rows are. Genesis 17:17 states her
# age directly, in her own right, so the anchor runs the other way:
# (personId, anchorChildId, her age when that child was born, her
# lifespan, birth ref(s), death ref(s)). Processed after CHAIN, since it
# needs the child's birth year already computed.
CHILD_ANCHORED = [
    ("sarah", "isaac", 90, 127, ["Genesis 17:17", "Genesis 21:5"],
     ["Genesis 23:1"]),
]

# Custom derivation prose for CHILD_ANCHORED rows — never the generic
# "X was N when Y was born" phrasing (wrong direction: it is the CHILD's
# birth that is stated, not a begetting age of the anchor person).
CHILD_ANCHORED_DERIVATION = {
    "sarah": {
        "en": (
            "Genesis 17:17 states two ages in one breath: Abraham \"an "
            "hundred years old\" and Sarah \"ninety years old.\" But "
            "17:1 already puts Abraham at 99 earlier in the same "
            "chapter, and 17:21 promises Isaac \"at this set time in "
            "the next year\"; 21:5 then states Abraham was 100 when "
            "Isaac was born. Both of 17:17's ages look forward a year, "
            "to the birth itself, not to the day of the promise — so "
            "Sarah was %d when Isaac was born (Genesis 17:17, Genesis "
            "21:5), not at the promise a year earlier. Sarah lived %d "
            "years (%s)."
        ),
        "hans": (
            "创世记 17:17 一口气说出两个岁数——亚伯拉罕「一百岁」，撒拉「九十"
            "岁」。但同一章 17:1 已说亚伯拉罕当时 99 岁，17:21 又应许以撒"
            "「到明年这时候」出生；21:5 则说以撒出生时亚伯拉罕正是 100 岁。"
            "可见 17:17 的两个岁数指向的都是一年后的出生那一刻，而非应许"
            "当下——因此撒拉生以撒时是 %d 岁（创世记 17:17、21:5），而非应许"
            "时就已是这个岁数。撒拉共活了 %d 年（%s）。"
        ),
        "hant": (
            "創世記 17:17 一口氣說出兩個歲數——亞伯拉罕「一百歲」，撒拉「九十"
            "歲」。但同一章 17:1 已說亞伯拉罕當時 99 歲，17:21 又應許以撒"
            "「到明年這時候」出生；21:5 則說以撒出生時亞伯拉罕正是 100 歲。"
            "可見 17:17 的兩個歲數指向的都是一年後的出生那一刻，而非應許"
            "當下——因此撒拉生以撒時是 %d 歲（創世記 17:17、21:5），而非應許"
            "時就已是這個歲數。撒拉共活了 %d 年（%s）。"
        ),
    },
}

# CHAIN rows whose "begat" figure is computed from a chain of verses
# rather than stated by a single one. Their derivation sentence must say
# "computed from" and show the chain — never the generic "X was N when Y
# was born" phrasing, which would misattribute the number to one verse.
DERIVED_PEOPLE = {
    "shem": {
        "en": (
            "Genesis 5:32 states Noah was 500 when he begat Shem, Ham "
            "and Japheth together — a birth-order note, not Shem's own "
            "birth year. Noah was 600 at the Flood (Genesis 7:6); Shem "
            "was 100, two years after the Flood, when he begat "
            "Arphaxad (Genesis 11:10), so Shem was 98 at the Flood, "
            "and Noah was 600 − 98 = 502 when Shem was born. Shem "
            "lived %d years (%s)."
        ),
        "hans": (
            "创世记 5:32 说挪亚 500 岁生了闪、含、雅弗三个儿子，说的是出生"
            "次序，不是闪本人的出生年。挪亚在洪水那年是 600 岁（创世记 "
            "7:6）；闪在洪水后两年、100 岁时生了亚法撒（创世记 11:10），"
            "可见闪在洪水那年是 98 岁——600 − 98 = 502，就是挪亚生闪时的"
            "年岁。闪共活了 %d 年（%s）。"
        ),
        "hant": (
            "創世記 5:32 說挪亞 500 歲生了閃、含、雅弗三個兒子，說的是出生"
            "次序，不是閃本人的出生年。挪亞在洪水那年是 600 歲（創世記 "
            "7:6）；閃在洪水後兩年、100 歲時生了亞法撒（創世記 11:10），"
            "可見閃在洪水那年是 98 歲——600 − 98 = 502，就是挪亞生閃時的"
            "年歲。閃共活了 %d 年（%s）。"
        ),
    },
    "abraham": {
        "en": (
            "Genesis 11:26 states Terah was 70 when he begat Abram, "
            "Nahor and Haran together — a birth-order note, not "
            "Abram's own birth year. Terah died at 205 (Genesis "
            "11:32); Abram left Haran at 75, after his father's death "
            "(Genesis 12:4, Acts 7:4), so Terah was 205 − 75 = 130 "
            "when Abraham was born. Abraham lived %d years (%s)."
        ),
        "hans": (
            "创世记 11:26 说他拉 70 岁生了亚伯兰、拿鹤、哈兰三个儿子，说的"
            "是出生次序，不是亚伯兰本人的出生年。他拉死时 205 岁（创世记 "
            "11:32）；亚伯兰离开哈兰时 75 岁，是在父亲死后（创世记 "
            "12:4、使徒行传 7:4）——205 − 75 = 130，就是他拉生亚伯拉罕时"
            "的年岁。亚伯拉罕共活了 %d 年（%s）。"
        ),
        "hant": (
            "創世記 11:26 說他拉 70 歲生了亞伯蘭、拿鶴、哈蘭三個兒子，說的"
            "是出生次序，不是亞伯蘭本人的出生年。他拉死時 205 歲（創世記 "
            "11:32）；亞伯蘭離開哈蘭時 75 歲，是在父親死後（創世記 "
            "12:4、使徒行傳 7:4）——205 − 75 = 130，就是他拉生亞伯拉罕時"
            "的年歲。亞伯拉罕共活了 %d 年（%s）。"
        ),
    },
    "joseph": {
        "en": (
            "Genesis never states Jacob's age when Joseph was born; it "
            "is computed. Joseph was 30 when he stood before Pharaoh "
            "(Genesis 41:46); 7 years of plenty followed (Genesis "
            "41:53); 2 years of famine had passed when he sent for his "
            "family (Genesis 45:6) — Joseph was 39 when Jacob entered "
            "Egypt. Jacob was 130 at that entry (Genesis 47:9), so Jacob "
            "was 130 − 39 = 91 when Joseph was born. Joseph lived "
            "%d years (%s)."
        ),
        "hans": (
            "经文没有哪一节直接说雅各生约瑟时几岁，这是推算所得：约瑟站在"
            "法老面前时 30 岁（创世记 41:46）；接着 7 个丰年过去（41:53）；"
            "约瑟差人去接家人时，饥荒已过了 2 年（45:6）——雅各一家进埃及"
            "时约瑟 39 岁。雅各进埃及时 130 岁（47:9），130 − 39 = 91，"
            "就是雅各生约瑟时的年岁。约瑟共活了 %d 年（%s）。"
        ),
        "hant": (
            "經文沒有哪一節直接說雅各生約瑟時幾歲，這是推算所得：約瑟站在"
            "法老面前時 30 歲（創世記 41:46）；接著 7 個豐年過去（41:53）；"
            "約瑟差人去接家人時，饑荒已過了 2 年（45:6）——雅各一家進埃及"
            "時約瑟 39 歲。雅各進埃及時 130 歲（47:9），130 − 39 = 91，"
            "就是雅各生約瑟時的年歲。約瑟共活了 %d 年（%s）。"
        ),
    },
}

# Custom derivation prose for CHAIN rows whose death age Scripture never
# gives (see OPEN_ENDED below) — never the generic "X lived N years"
# phrasing the `else` branch below uses, which unconditionally formats
# `lived` with %d and would crash on a None. The opening clause keeps
# the same "X was N when Y was born" shape the generic branch and
# DERIVED_PEOPLE both use, so `derivationAgeDefects` in
# test/bible_chronology_test.dart — which greps that exact shape for
# the begetting age — still finds the number; only the closing sentence
# changes, to state plainly that the death year is not given rather
# than naming one.
OPEN_ENDED_DERIVATION = {
    "esau": {
        "en": (
            "%s was %d when %s was born (%s) — the same verse also "
            "dates Jacob's birth, since they were twins. Scripture "
            "never records %s's death age, so this bar is drawn "
            "open-ended: the chart is saying it does not know, not "
            "that he never died."
        ),
        "hans": (
            "%s %d 岁生%s（%s）——同一节经文也是雅各的出生年，因为他们是"
            "双生子。经文没有记载%s哪年去世，因此这根横条画成开放式："
            "本图是在说它不知道，不是说他从未离世。"
        ),
        "hant": (
            "%s %d 歲生%s（%s）——同一節經文也是雅各的出生年，因為他們是"
            "雙生子。經文沒有記載%s哪年去世，因此這根橫條畫成開放式："
            "本圖是在說它不知道，不是說他從未離世。"
        ),
    },
}

# Which descent band each lifeline is drawn in.
LINE_OF = {
    "adam": "sethite", "seth": "sethite", "enosh": "sethite",
    "kenan": "sethite", "mahalalel": "sethite", "jared": "sethite",
    "enoch": "sethite", "methuselah": "sethite", "lamech": "sethite",
    "noah": "sethite",
    "shem": "shemite", "arphaxad": "shemite", "shelah": "shemite",
    "eber": "shemite", "peleg": "shemite", "reu": "shemite",
    "serug": "shemite", "nahor_elder": "shemite", "terah": "shemite",
    "abraham": "shemite",
    # Isaac and Jacob are Shem's descendants too, but not named in
    # Genesis 11 — reusing "shemite" would put them under a legend
    # label ("Shem's line (Genesis 11)") that overclaims where their
    # ages actually come from. See LINES below.
    "isaac": "isaac_jacob", "jacob": "isaac_jacob", "joseph": "isaac_jacob",
    # Ishmael is Abraham's son too, but not Isaac's line — the same
    # overclaim reusing "isaac_jacob" would make in the other direction.
    "ishmael": "ishmaelite",
    # Esau is Isaac's son too, but not Jacob's line — the same overclaim
    # reusing "isaac_jacob" would make for Esau that it already avoids
    # for Ishmael, in the same direction. Genesis 36:1,8 states outright
    # "Esau, who is Edom," so the line takes his descendants' own name
    # rather than an inferred one.
    "esau": "edomite",
    # Sarah is not a further link in anyone's begetting chain — see
    # CHILD_ANCHORED — so none of the descent-line labels above fit her
    # either.
    "sarah": "matriarchs",
}

# People whose BIRTH Scripture states but whose death year it never
# gives are drawn open-ended, not guessed at. That needs a stated
# birth — it is not the same gap as Ham and Japheth (see UNDRAWN
# below), whom Scripture never ages at all, so there is nothing to
# plot for them even open-ended. Esau is the first and, for now, only
# member: Genesis 25:26 states his birth (twin to Jacob's — see CHAIN);
# 35:29 and 36:1-43 record his life and lineage without ever giving a
# death age.
OPEN_ENDED = {"esau"}

# Chinese book names used when phrasing the derivation sentences.
BOOK_ZH = {
    "Genesis": ("创世记", "創世記"),
    "Acts": ("使徒行传", "使徒行傳"),
    "Hebrews": ("希伯来书", "希伯來書"),
}


def zh_ref(ref, trad):
    """`Genesis 5:6` → `创世记 5:6` / `創世記 5:6`."""
    book, _, tail = ref.partition(" ")
    names = BOOK_ZH.get(book)
    if not names:
        return ref
    return "%s %s" % (names[1] if trad else names[0], tail)


def zh_refs(refs, trad):
    return "、".join(zh_ref(r, trad) for r in refs)


SCHEMES = [
    {
        "id": "masoretic-ussher",
        "supported": True,
        "creationBc": 4004,
        "nameEn": "Masoretic text (Ussher anchor)",
        "nameZhHans": "马所拉文本（乌雪锚点）",
        "nameZhHant": "馬所拉文本（烏雪錨點）",
        "noteEn": (
            "Every year on this chart is counted in Anno Mundi — years "
            "since Creation — using the ages the Masoretic (Hebrew) text "
            "gives in Genesis 5 and 11. Those intervals are what Scripture "
            "states; the BC labels are not. They come from anchoring AM 0 "
            "at 4004 BC, which is Ussher's date and the one the reference "
            "chart uses. Read the AM column as the sourced figure and the "
            "BC column as one scholar's placement of it."
        ),
        "noteZhHans": (
            "本图的年份以「创世纪元」（AM，自创造起算的年数）计算，取自马所拉"
            "（希伯来）文本创世记第 5、11 章所记的岁数。经文陈述的是这些间隔，"
            "而非公元前年份；公元前标签来自把 AM 0 锚定在公元前 4004 年，那是"
            "乌雪的定年，也是参考图所用的。请把 AM 一栏视为有经文出处的数字，"
            "把公元前一栏视为某一位学者对它的定位。"
        ),
        "noteZhHant": (
            "本圖的年份以「創世紀元」（AM，自創造起算的年數）計算，取自馬所拉"
            "（希伯來）文本創世記第 5、11 章所記的歲數。經文陳述的是這些間隔，"
            "而非公元前年份；公元前標籤來自把 AM 0 錨定在公元前 4004 年，那是"
            "烏雪的定年，也是參考圖所用的。請把 AM 一欄視為有經文出處的數字，"
            "把公元前一欄視為某一位學者對它的定位。"
        ),
    },
    {
        "id": "septuagint",
        "supported": False,
        "creationBc": 5500,
        "nameEn": "Septuagint (LXX)",
        "nameZhHans": "七十士译本",
        "nameZhHant": "七十士譯本",
        "noteEn": (
            "The Greek Septuagint gives most of the Genesis 5 and 11 "
            "fathers a begetting age 100 years higher, and adds a second "
            "Cainan in Genesis 11 — the one Luke 3:36 also names. Its "
            "Creation falls near 5500 BC, roughly 1,500 years earlier. "
            "Not plotted yet: doing it honestly means carrying its own "
            "ages, not shifting this chart's anchor."
        ),
        "noteZhHans": (
            "希腊文七十士译本给创世记 5、11 章多数先祖的生子年龄高出 100 年，"
            "并在创世记 11 章多出一位该南——路加福音 3:36 也提到他。其创造年代"
            "约在公元前 5500 年，比上者早约 1500 年。本次尚未绘出：要诚实呈现"
            "就得录入它自己的岁数，而不是挪动本图的锚点。"
        ),
        "noteZhHant": (
            "希臘文七十士譯本給創世記 5、11 章多數先祖的生子年齡高出 100 年，"
            "並在創世記 11 章多出一位該南——路加福音 3:36 也提到他。其創造年代"
            "約在公元前 5500 年，比上者早約 1500 年。本次尚未繪出：要誠實呈現"
            "就得錄入它自己的歲數，而不是挪動本圖的錨點。"
        ),
    },
    {
        "id": "samaritan",
        "supported": False,
        "creationBc": 4700,
        "nameEn": "Samaritan Pentateuch",
        "nameZhHans": "撒玛利亚五经",
        "nameZhHant": "撒瑪利亞五經",
        "noteEn": (
            "The Samaritan Pentateuch differs from both — shorter "
            "lifespans before the Flood, longer begetting ages after it — "
            "putting Creation near 4700 BC. The three witnesses disagree "
            "by around 1,500 years in total. That is a genuine textual "
            "division, not an error with a right answer."
        ),
        "noteZhHans": (
            "撒玛利亚五经与前两者都不同——洪水前寿数较短，洪水后生子年龄较长"
            "——创造年代约在公元前 4700 年。三个文本证据之间相差合计约 1500 年。"
            "这是真实的抄本分歧，不是有标准答案的错误。"
        ),
        "noteZhHant": (
            "撒瑪利亞五經與前兩者都不同——洪水前壽數較短，洪水後生子年齡較長"
            "——創造年代約在公元前 4700 年。三個文本證據之間相差合計約 1500 年。"
            "這是真實的抄本分歧，不是有標準答案的錯誤。"
        ),
    },
]

LINES = [
    {
        "id": "sethite",
        "colorHex": "#6B5E3F",
        "nameEn": "Seth's line (Genesis 5)",
        "nameZhHans": "塞特的家系（创世记 5）",
        "nameZhHant": "塞特的家系（創世記 5）",
    },
    {
        "id": "shemite",
        "colorHex": "#8C5A2F",
        "nameEn": "Shem's line (Genesis 11)",
        "nameZhHans": "闪的家系（创世记 11）",
        "nameZhHant": "閃的家系（創世記 11）",
    },
    # Both browns above are used, so this needed a hue that reads as
    # distinct from them and from the eight ERA_STYLE colours at both
    # brightnesses `_readable()` produces (chronology_chart.dart) — a
    # teal, where none of the browns/red/green/blue/purples/gold sit.
    {
        "id": "isaac_jacob",
        "colorHex": "#1E7A8C",
        "nameEn": "Isaac, Jacob and Joseph",
        "nameZhHans": "以撒、雅各与约瑟",
        "nameZhHant": "以撒、雅各與約瑟",
    },
    # The chart's first fork: Ishmael branches off Abraham rather than
    # continuing toward Isaac, so neither "shemite" nor "isaac_jacob"
    # names who this line actually holds. Rose/plum — distinct from the
    # three colours above and from all eight ERA_STYLE hues, checked at
    # both the light-theme value and the `_readable()` dark-theme lerp
    # toward white (chronology_chart.dart); its nearest neighbour either
    # way is "mosaic" red, ~40 in RGB-distance terms.
    {
        "id": "ishmaelite",
        "colorHex": "#A63A6B",
        "nameEn": "Ishmael's line",
        "nameZhHans": "以实玛利的家系",
        "nameZhHant": "以實瑪利的家系",
    },
    # The chart's second fork: Esau branches off Isaac rather than
    # continuing toward Jacob, the same shape Ishmael's fork off Abraham
    # takes above. Genesis 36:1,8 names the line outright — "Esau, who
    # is Edom" — so it is not an inferred label. A muted olive-green,
    # checked by RGB distance against all four colours above AND the
    # eight ERA_STYLE hues at both the light-theme value and the
    # `_readable()` dark-theme lerp toward white (chronology_chart.dart):
    # nearest neighbour either way is "sethite" (#6B5E3F, which the
    # antediluvian era band also uses) — ~68 in RGB-distance terms in
    # light mode, ~41 in dark mode's 40%-toward-white lerp, the same
    # ~0.6 scaling the ishmaelite and matriarchs comments document.
    {
        "id": "edomite",
        "colorHex": "#7A9E2D",
        "nameEn": "Esau's line (Edom)",
        "nameZhHans": "以扫的家系（以东）",
        "nameZhHant": "以掃的家系（以東）",
    },
    # Sarah is not a line of descent at all — a single bar, anchored on
    # her son's birth rather than a father's begetting age (see
    # CHILD_ANCHORED). A violet hue, checked by RGB distance against all
    # five lines above AND the eight ERA_STYLE hues at both brightnesses
    # `_readable()` produces (chronology_chart.dart): nearest neighbour
    # either way is "exile" purple (#5F3F86) — ~74 in RGB-distance terms
    # in light mode, where `_readable()` leaves colours untouched; dark
    # mode's 40%-toward-white lerp scales every distance down by the
    # same 0.6 factor, to ~44, still past the ~40 the ishmaelite comment
    # above treats as sufficient, but only just. Plural id/name because
    # a later pass may add Rebekah or Rachel to the same anchor kind.
    {
        "id": "matriarchs",
        "colorHex": "#9650B4",
        "nameEn": "Matriarchs (dated by a child's birth)",
        "nameZhHans": "女先祖（以子女出生定年）",
        "nameZhHant": "女先祖（以子女出生定年）",
    },
]

# Lines the reference chart draws in full and this one deliberately does
# not, because Scripture gives no ages for them.
UNDRAWN = {
    "en": (
        "Cain's line (Genesis 4), Ham's and Japheth's (Genesis 10) are "
        "not drawn. Scripture names them but gives no ages, so there is "
        "nothing to plot without inventing it."
    ),
    "zh-Hans": (
        "该隐的家系（创世记 4）与含、雅弗的家系（创世记 10）未绘出。经文有名"
        "字却没有岁数，不杜撰就无从落笔。"
    ),
    "zh-Hant": (
        "該隱的家系（創世記 4）與含、雅弗的家系（創世記 10）未繪出。經文有名"
        "字卻沒有歲數，不杜撰就無從落筆。"
    ),
}

# A third, distinct class from UNDRAWN above: these are not nameless or
# ageless. Scripture states each lifespan plainly — the gap is that no
# verse states the father's age at the birth, so there is no year to
# anchor the bar's left edge on. Six lifespans, verified individually
# against assets/kjv.json rather than assumed from the pattern.
UNANCHORED = {
    "en": (
        "Exodus 6:16 gives Levi's 137 years, Exodus 6:18 his son "
        "Kohath's 133, and Exodus 6:20 Kohath's son Amram's 137 — "
        "three more lifespans in the same passage. Three more follow "
        "the same pattern: Moses died at 120 (Deuteronomy 34:7), Aaron "
        "at 123 (Numbers 33:39), Joshua at 110 (Joshua 24:29). None of "
        "the six is drawn here. The reason is not that Scripture is "
        "silent on their years — it plainly is not — but that no "
        "verse states how old their father was when they were born; "
        "Amram's age at Moses' birth, for instance, is never given, "
        "so there is no birth year to anchor a bar on."
    ),
    "zh-Hans": (
        "出埃及记 6:16 说利未活了 137 年，6:18 说他的儿子哥辖活了 133 年，"
        "6:20 说哥辖的儿子暗兰活了 137 年，同一段经文又列出三笔岁数；后面"
        "还有三位同样留下了岁数：摩西死时 120 岁（申命记 34:7）、亚伦死时 "
        "123 岁（民数记 33:39）、约书亚死时 110 岁（约书亚记 24:29）。这"
        "六位都没有画在图上。原因不是经文没提他们的岁数——分明是提了——而"
        "是没有一节经文说他们出生时父亲几岁；譬如暗兰生摩西时几岁，经文"
        "从未交代，因此没有出生年可供横条起点。"
    ),
    "zh-Hant": (
        "出埃及記 6:16 說利未活了 137 年，6:18 說他的兒子哥轄活了 133 年，"
        "6:20 說哥轄的兒子暗蘭活了 137 年，同一段經文又列出三筆歲數；後面"
        "還有三位同樣留下了歲數：摩西死時 120 歲（申命記 34:7）、亞倫死時 "
        "123 歲（民數記 33:39）、約書亞死時 110 歲（約書亞記 24:29）。這"
        "六位都沒有畫在圖上。原因不是經文沒提他們的歲數——分明是提了——而"
        "是沒有一節經文說他們出生時父親幾歲；譬如暗蘭生摩西時幾歲，經文"
        "從未交代，因此沒有出生年可供橫條起點。"
    ),
}


def marker(mid, am, era, refs, en, hans, hant):
    return {
        "id": mid, "am": am, "era": era, "refs": refs,
        # Every marker's year comes out of the Genesis 5/11 arithmetic
        # above. The flag is stored rather than inferred so the chart
        # never has to guess which layer a tick belongs to.
        "amBasis": "computed",
        "pin": True,
        "titleEn": en, "titleZhHans": hans, "titleZhHant": hant,
    }


# Trilingual copy for the two things the extended span forces the chart
# to say out loud. Kept in the generator, next to the arithmetic that
# makes them true, rather than in the widget.
COMPUTED_NOTE = {
    "en": (
        "Left of this line every year is COMPUTED: it is the ages "
        "Scripture states, chained together — directly, for most; "
        "Shem's, Abraham's and Joseph's are each chained together from "
        "multiple verses instead — and each bar carries the "
        "arithmetic. Right of it "
        "Scripture stops giving a continuous chain of ages, so there are "
        "no lifelines to draw — only events, PLACED on the BC/AD years "
        "of assets/bible_timeline.json. The ground fades out there for "
        "the same reason a bar with no stated death year fades out: the "
        "chart is saying it does not know."
    ),
    "zh-Hans": (
        "此线以左，每一个年份都是「推算」出来的：把经文所记的岁数逐代相连而"
        "得——大多直接见于经文，闪、亚伯拉罕、约瑟三代则各自把多处经文串联"
        "推得——每根横条都附着算式。此线以右，经文不再给出连续的年岁链条，因此没有"
        "生平横条可画——只有事件，按 assets/bible_timeline.json 的公元前后"
        "年份「定位」。那一段的底色会淡出，理由和没有记载卒年的横条淡出是同"
        "一个：本图在说它不知道。"
    ),
    "zh-Hant": (
        "此線以左，每一個年份都是「推算」出來的：把經文所記的歲數逐代相連而"
        "得——大多直接見於經文，閃、亞伯拉罕、約瑟三代則各自把多處經文串聯"
        "推得——每根橫條都附著算式。此線以右，經文不再給出連續的年歲鏈條，因此沒有"
        "生平橫條可畫——只有事件，按 assets/bible_timeline.json 的公元前後"
        "年份「定位」。那一段的底色會淡出，理由和沒有記載卒年的橫條淡出是同"
        "一個：本圖在說它不知道。"
    ),
}

CONTESTED_NOTE = {
    "en": (
        "Inside this band the two scales disagree by about 170 years. "
        "The lifelines put Abram's birth at AM 2008 (1996 BC on this "
        "anchor); assets/bible_timeline.json places his call at 2091 BC "
        "on the late-date scheme, which is earlier than the lifelines "
        "have him born. Both are shown where their own source puts "
        "them. Neither has been shifted to make the picture tidy."
    ),
    "zh-Hans": (
        "在这一带，两套刻度相差约 170 年。生平横条把亚伯兰的出生定在创世纪元 "
        "2008 年（本锚点下为公元前 1996 年）；assets/bible_timeline.json 依晚期"
        "定年方案把他蒙召定在公元前 2091 年，比横条所记的出生还早。两者都按各自"
        "来源的位置照实画出，没有为了图面好看而挪动任何一方。"
    ),
    "zh-Hant": (
        "在這一帶，兩套刻度相差約 170 年。生平橫條把亞伯蘭的出生定在創世紀元 "
        "2008 年（本錨點下為公元前 1996 年）；assets/bible_timeline.json 依晚期"
        "定年方案把他蒙召定在公元前 2091 年，比橫條所記的出生還早。兩者都按各自"
        "來源的位置照實畫出，沒有為了圖面好看而挪動任何一方。"
    ),
}


def two_scale_note(person, birth, death):
    """The family_tree.json-vs-Anno-Mundi caveat block shared by every
    patriarch entry (and Sarah, whose AM year is computed via
    CHILD_ANCHORED rather than CHAIN, but carries the same late-date-BC
    mismatch — see CHILD_ANCHORED)."""
    fam_birth_bc = -person["birthYear"]
    fam_death_bc = -person["deathYear"]
    am_birth_bc = CREATION_BC - birth
    am_death_bc = CREATION_BC - death
    return {
        "noteEn": (
            "assets/family_tree.json dates %s %d-%d BC, a late-date "
            "scheme that does not join up with the Anno Mundi count "
            "used here (AM %d-%d is %d-%d BC on the 4004 BC anchor). "
            "Reconciling the two scales for the patriarchs is "
            "deliberately left to a later pass rather than fudged."
            % (person["name"], fam_birth_bc, fam_death_bc, birth,
               death, am_birth_bc, am_death_bc)),
        "noteZhHans": (
            "assets/family_tree.json 把%s定在公元前 %d-%d 年，属于晚期定年"
            "方案，与本图所用的创世纪元并不衔接（AM %d-%d 在 4004 锚点下为"
            "公元前 %d-%d 年）。列祖世系两套刻度的调和刻意留待后续，不作"
            "勉强弥合。"
            % (person["nameZhHans"], fam_birth_bc, fam_death_bc, birth,
               death, am_birth_bc, am_death_bc)),
        "noteZhHant": (
            "assets/family_tree.json 把%s定在公元前 %d-%d 年，屬於晚期定年"
            "方案，與本圖所用的創世紀元並不銜接（AM %d-%d 在 4004 錨點下為"
            "公元前 %d-%d 年）。列祖世系兩套刻度的調和刻意留待後續，不作"
            "勉強彌合。"
            % (person["nameZhHant"], fam_birth_bc, fam_death_bc, birth,
               death, am_birth_bc, am_death_bc)),
    }


def build():
    fam = json.load(open(FAMILY, encoding="utf-8"))
    people = {p["id"]: p for p in fam["people"]}

    lifelines = []
    birth_of = {}
    problems = []

    for pid, father, begat, lived, bref, dref in CHAIN:
        person = people.get(pid)
        if person is None:
            problems.append("%s is not in family_tree.json" % pid)
            continue

        if father is None:
            birth = 0
        else:
            if father not in birth_of:
                problems.append("%s precedes its father %s" % (pid, father))
                continue
            birth = birth_of[father] + begat
        birth_of[pid] = birth
        death = None if pid in OPEN_ENDED else birth + lived

        # Cross-check against the independently curated family tree.
        if person.get("yearSystem") == "am":
            if person.get("birthYear") != birth:
                problems.append(
                    "%s birth %s != family_tree %s"
                    % (pid, birth, person.get("birthYear")))
            if death is not None and person.get("deathYear") != death:
                problems.append(
                    "%s death %s != family_tree %s"
                    % (pid, death, person.get("deathYear")))

        fname = people[father]["name"] if father else None
        fzh = people[father]["nameZhHans"] if father else None
        fzt = people[father]["nameZhHant"] if father else None

        if father is None:
            der_en = ("Year zero of the scale: the count runs from "
                      "Creation. %s lived %d years (%s)."
                      % (person["name"], lived, ", ".join(dref)))
            der_hans = ("本刻度的零年：年数自创造起算。%s共活了 %d 年（%s）。"
                        % (person["nameZhHans"], lived, zh_refs(dref, False)))
            der_hant = ("本刻度的零年：年數自創造起算。%s共活了 %d 年（%s）。"
                        % (person["nameZhHant"], lived, zh_refs(dref, True)))
        elif pid in DERIVED_PEOPLE:
            tpl = DERIVED_PEOPLE[pid]
            der_en = tpl["en"] % (lived, ", ".join(dref))
            der_hans = tpl["hans"] % (lived, zh_refs(dref, False))
            der_hant = tpl["hant"] % (lived, zh_refs(dref, True))
        elif pid in OPEN_ENDED_DERIVATION:
            tpl = OPEN_ENDED_DERIVATION[pid]
            der_en = tpl["en"] % (fname, begat, person["name"],
                                   ", ".join(bref), person["name"])
            der_hans = tpl["hans"] % (fzh, begat, person["nameZhHans"],
                                       zh_refs(bref, False),
                                       person["nameZhHans"])
            der_hant = tpl["hant"] % (fzt, begat, person["nameZhHant"],
                                       zh_refs(bref, True),
                                       person["nameZhHant"])
        else:
            der_en = ("%s was %d when %s was born (%s); %s lived %d years "
                      "(%s)." % (fname, begat, person["name"],
                                 ", ".join(bref), person["name"], lived,
                                 ", ".join(dref)))
            der_hans = ("%s %d 岁生%s（%s）；%s共活了 %d 年（%s）。"
                        % (fzh, begat, person["nameZhHans"],
                           zh_refs(bref, False), person["nameZhHans"],
                           lived, zh_refs(dref, False)))
            der_hant = ("%s %d 歲生%s（%s）；%s共活了 %d 年（%s）。"
                        % (fzt, begat, person["nameZhHant"],
                           zh_refs(bref, True), person["nameZhHant"],
                           lived, zh_refs(dref, True)))

        entry = {
            "personId": pid,
            "lineId": LINE_OF[pid],
            "scheme": "masoretic-ussher",
            "nameEn": person["name"],
            "nameZhHans": person["nameZhHans"],
            "nameZhHant": person["nameZhHant"],
            "fatherId": father,
            "birthAm": birth,
            "deathAm": death,
            "lifespan": lived,
            "refs": bref + [r for r in dref if r not in bref],
            "derivationEn": der_en,
            "derivationZhHans": der_hans,
            "derivationZhHant": der_hant,
        }

        if pid in ("abraham", "ishmael", "isaac", "jacob", "joseph"):
            # Numbers are derived here, not transcribed, so the note
            # can't drift from the arithmetic that produced the bar.
            # family_tree.json's BC range and the derived-from-AM BC
            # range are both computed the same way for all these people
            # (the gap is a constant ~170 years, the same anchor
            # mismatch propagated down one chain — see CONTESTED_NOTE
            # for where it first shows). Sarah gets the identical note
            # below, once her CHILD_ANCHORED birth year is computed.
            # Esau is deliberately NOT in this tuple: `two_scale_note`
            # subtracts `person["deathYear"]`, and family_tree.json's
            # esau record has no such key — it would raise, not silently
            # fudge, which is the point. Skipping the note is the honest
            # option per OPEN_ENDED_DERIVATION's own close; his birth
            # carries the same ~170-year mismatch as Jacob's, but there
            # is no death figure on either scale to contrast it with.
            entry.update(two_scale_note(person, birth, death))

        lifelines.append(entry)

    # ── The child-anchored rows ──────────────────────────────────────
    #
    # Processed after CHAIN because each needs its anchor child's birth
    # year already computed. See CHILD_ANCHORED for why Sarah cannot be
    # a CHAIN row: Genesis 20:12 names her father but states no
    # begetting age, so there is no age to chain her birth from his.
    for pid, anchor_child, age_at_birth, lived, bref, dref in CHILD_ANCHORED:
        person = people.get(pid)
        if person is None:
            problems.append("%s is not in family_tree.json" % pid)
            continue
        if anchor_child not in birth_of:
            problems.append(
                "%s anchors on child %s, not yet computed" % (pid, anchor_child))
            continue

        birth = birth_of[anchor_child] - age_at_birth
        birth_of[pid] = birth
        death = birth + lived

        tpl = CHILD_ANCHORED_DERIVATION[pid]
        der_en = tpl["en"] % (age_at_birth, lived, ", ".join(dref))
        der_hans = tpl["hans"] % (age_at_birth, lived, zh_refs(dref, False))
        der_hant = tpl["hant"] % (age_at_birth, lived, zh_refs(dref, True))

        entry = {
            "personId": pid,
            "lineId": LINE_OF[pid],
            "scheme": "masoretic-ussher",
            "nameEn": person["name"],
            "nameZhHans": person["nameZhHans"],
            "nameZhHant": person["nameZhHant"],
            # Not chained from a father — see CHILD_ANCHORED.
            "fatherId": None,
            "anchorChildId": anchor_child,
            "birthAm": birth,
            "deathAm": death,
            "lifespan": lived,
            "refs": bref + [r for r in dref if r not in bref],
            "derivationEn": der_en,
            "derivationZhHans": der_hans,
            "derivationZhHant": der_hant,
        }
        entry.update(two_scale_note(person, birth, death))
        lifelines.append(entry)

    flood = birth_of["noah"] + 600
    markers = [
        marker("creation", 0, "antediluvian",
               ["Genesis 1:1", "Genesis 1:31"],
               "Creation", "创造", "創造"),
        marker("enoch_taken", birth_of["enoch"] + 365, "antediluvian",
               ["Genesis 5:24", "Hebrews 11:5"],
               "Enoch is taken", "以诺被接去", "以諾被接去"),
        marker("flood", flood, "antediluvian",
               ["Genesis 7:6", "Genesis 7:11"],
               "The Flood (Noah's 600th year)", "洪水（挪亚 600 岁）",
               "洪水（挪亞 600 歲）"),
        marker("abram_born", birth_of["abraham"], "patriarchs",
               ["Genesis 11:26", "Genesis 11:32", "Acts 7:4"],
               "Abram is born", "亚伯兰出生", "亞伯蘭出生"),
        marker("abram_call", birth_of["abraham"] + 75, "patriarchs",
               ["Genesis 12:1-4"],
               "Abram leaves Haran, aged 75", "亚伯兰 75 岁离开哈兰",
               "亞伯蘭 75 歲離開哈蘭"),
        marker("isaac_born", birth_of["abraham"] + 100, "patriarchs",
               ["Genesis 21:5"],
               "Isaac is born, Abraham aged 100",
               "以撒出生，亚伯拉罕 100 岁", "以撒出生，亞伯拉罕 100 歲"),
        marker("abraham_dies", birth_of["abraham"] + 175, "patriarchs",
               ["Genesis 25:7", "Genesis 25:8"],
               "Abraham dies, aged 175", "亚伯拉罕去世，享年 175 岁",
               "亞伯拉罕去世，享年 175 歲"),
    ]

    # Methuselah's death lands in the Flood year. If a future edit breaks
    # that, the arithmetic has drifted.
    meth = next(x for x in lifelines if x["personId"] == "methuselah")
    if meth["deathAm"] != flood:
        problems.append(
            "Methuselah dies AM %s but the Flood is AM %s"
            % (meth["deathAm"], flood))

    # ── The placed-event layer ──────────────────────────────────────
    #
    # The complaint this pass answers: the chart stopped at Abraham
    # while the event list on the SAME page ran to Revelation, so
    # scrolling right never arrived anywhere. Genesis states Isaac's
    # and Jacob's ages directly (21:5, 25:26, 35:28, 47:28), and gives
    # Joseph's via a four-verse chain (41:46, 41:53, 45:6, 47:9) rather
    # than a single stated age, so their lifelines are drawn too. Past
    # Joseph, Scripture stops giving a continuous chain of ages
    # altogether — direct or chained — so no further lifelines are
    # invented; what extends past that is the span and the events.
    timeline = json.load(open(TIMELINE, encoding="utf-8"))
    by_marker = {m["id"]: m for m in markers}
    events = []
    seen_ids = set()
    for seq, e in enumerate(timeline["events"]):
        eid = e["id"]
        if eid in seen_ids:
            problems.append("duplicate timeline event id %s" % eid)
            continue
        seen_ids.add(eid)
        am = year_to_am(e["year"])
        dup = DUPLICATES.get(eid)
        if dup is not None:
            m = by_marker.get(dup)
            if m is None:
                problems.append(
                    "%s claims to duplicate unknown marker %s" % (eid, dup))
                continue
            # The computed marker governs; the timeline's own figure is
            # carried alongside so the gap is visible, not hidden.
            m["placedEventId"] = eid
            m["placedYear"] = e["year"]
            m["placedDeltaYears"] = am - m["am"]
            continue
        if e["era"] not in ERA_STYLE:
            problems.append("%s is in unknown era %s" % (eid, e["era"]))
            continue
        events.append({
            "id": eid,
            "am": am,
            "seq": seq,
            "year": e["year"],
            "era": e["era"],
            "amBasis": "placed",
            "pin": eid in PINNED_EVENTS,
            "refs": list(e.get("refs") or []),
            "titleEn": e["titleEn"],
            "titleZhHans": e["titleZhHans"],
            "titleZhHant": e["titleZhHant"],
        })
    # Tie-break by source order, not id: same-year events are narrative
    # sequence in bible_timeline.json (e.g. AM 4036's Passion week), and
    # sorting by id alphabetises that back into nonsense.
    events.sort(key=lambda x: (x["am"], x["seq"]))

    for pid in PINNED_EVENTS:
        if not any(x["id"] == pid for x in events):
            problems.append("pinned event %s is not in the timeline" % pid)

    if problems:
        for p in problems:
            sys.stderr.write("FAIL: %s\n" % p)
        raise SystemExit(1)

    # Where the computed chain runs out. NOT Abraham's death — Eber,
    # Isaac, Jacob and now Joseph all outlive him on the Masoretic
    # count, Joseph latest of them all (his derived-not-stated bar
    # still ends later than everyone else's stated one) — so it is
    # read off the bars rather than assumed.
    computed_end = max(
        x["deathAm"] for x in lifelines if x["deathAm"] is not None)
    span_end = max([computed_end] + [x["am"] for x in events])

    # Era bands, for background orientation across 4,100 years. Each
    # band starts at its era's first dated thing and runs to the next
    # era's, so the bands tile the axis without gaps. Two eras genuinely
    # overlap in the sources (Moses dies and Jordan is crossed in the
    # same year), so a band is an ORIENTATION device — the precise claim
    # is the tick, which carries its own era colour.
    era_order = []
    for e in timeline["events"]:
        if e["era"] not in era_order:
            era_order.append(e["era"])
    first_am = {}
    for x in events + markers:
        era = x["era"]
        if era not in first_am or x["am"] < first_am[era]:
            first_am[era] = x["am"]
    eras = []
    for i, era in enumerate(era_order):
        style = ERA_STYLE[era]
        start = 0 if i == 0 else first_am[era]
        end = first_am[era_order[i + 1]] if i + 1 < len(era_order) else span_end
        eras.append({
            "id": era,
            "startAm": start,
            "endAm": end,
            "colorHex": style[0],
            "nameEn": style[1],
            "nameZhHans": style[2],
            "nameZhHant": style[3],
        })

    # The stretch where the computed count and the placed events are
    # both present and provably disagree.
    #
    # The test for "provably" is ordering, not a hand-picked list: an
    # event placed EARLIER than the first computed event of its own era
    # is in the wrong order however you read it — Ishmael cannot be born
    # before Abram is. Those are exactly the patriarchal events dated on
    # family_tree.json's late-date scheme, ~170 years adrift of the AM
    # count. Nothing is moved to fix it; the band is drawn and named.
    first_computed_in_era = {}
    for m in markers:
        era = m["era"]
        if era not in first_computed_in_era or m["am"] < first_computed_in_era[era]:
            first_computed_in_era[era] = m["am"]
    misordered = [
        x for x in events
        if x["era"] in first_computed_in_era
        and x["am"] < first_computed_in_era[x["era"]]
    ]
    contested = None
    if misordered:
        contested = {
            "startAm": min(x["am"] for x in misordered),
            "endAm": computed_end,
            "eventCount": len(misordered),
            "note": CONTESTED_NOTE,
        }

    doc = {
        "_meta": {
            "version": 2,
            "generated": "2026-09-04",
            "generator": "tools/build_bible_chronology.py",
            "defaultScheme": "masoretic-ussher",
            "spanStartAm": 0,
            "spanEndAm": span_end,
            # Left of this the years are computed from stated ages;
            # right of it there is only the placed-event layer.
            "computedEndAm": computed_end,
            "count": len(lifelines),
            "eventCount": len(events),
            "description": (
                "Two layers on one Anno Mundi axis. (1) LIFELINES — the "
                "begetting ages Genesis states, chained from Adam to "
                "Joseph: directly, for most; Shem's, Abraham's and "
                "Joseph's are each chained together from multiple "
                "verses instead, since no single verse states outright "
                "what age their father was (see CHAIN in this file). "
                "Names from "
                "assets/family_tree.json, years recomputed from the "
                "Masoretic ages and cross-checked against it. "
                "(2) EVENTS — the same %d events the event list on this "
                "page shows, from assets/bible_timeline.json, placed on "
                "the AM axis by their stated BC/AD year through the "
                "4004 BC anchor, so both views of the page span "
                "Creation to Revelation. The two layers are drawn "
                "differently and labelled, because a placed year is not "
                "a computed one. No data is taken from the copyrighted "
                "reference sheet in docs/reference/."
            ) % len(events),
            "computedNote": COMPUTED_NOTE,
            "undrawnLines": UNDRAWN,
            "unanchoredLifespans": UNANCHORED,
        },
        "schemes": SCHEMES,
        "lines": LINES,
        "eras": eras,
        "lifelines": lifelines,
        "markers": markers,
        "events": events,
        "contested": contested,
    }

    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(doc, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print("wrote %s — %d lifelines, %d computed markers, %d placed "
          "events, span AM 0-%d (computed to AM %d)"
          % (OUT, len(lifelines), len(markers), len(events), span_end,
             computed_end))


if __name__ == "__main__":
    build()
