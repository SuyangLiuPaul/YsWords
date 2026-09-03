#!/usr/bin/env python3
"""Build `assets/bible_chronology.json` — the data behind the
interactive chronology chart on the Bible Timeline page.

Two layers, one axis:

  * LIFELINES, computed from the Masoretic begetting ages of Genesis 5
    and 11 (Adam → Abraham). Every year traces to a verse.
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
(our own curated data). Years are recomputed here from the Masoretic
ages of Genesis 5 and 11 and checked against family_tree's AM values.

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

# ── The Masoretic chronology of Genesis 5 and 11 ────────────────────
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
    ("shem",        "noah",        502,   600,   ["Genesis 5:32", "Genesis 11:10"],  ["Genesis 11:11"]),
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
]

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
}

# People whose death year Scripture never gives are drawn open-ended,
# not guessed at. Nobody in CHAIN is in this state today; the flag
# exists so a later iteration can add Ham, Japheth, Isaac, Jacob…
OPEN_ENDED = set()

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
        "Left of this line every year is COMPUTED: it is the sum of the "
        "begetting ages Genesis 5 and 11 state, and each bar carries the "
        "arithmetic. Right of it Scripture stops giving a continuous "
        "chain of ages, so there are no lifelines to draw — only events, "
        "PLACED on the BC/AD years of assets/bible_timeline.json. The "
        "ground fades out there for the same reason a bar with no stated "
        "death year fades out: the chart is saying it does not know."
    ),
    "zh-Hans": (
        "此线以左，每一个年份都是「推算」出来的：把创世记 5、11 章所记的生子"
        "年龄相加而得，每根横条都附着算式。此线以右，经文不再给出连续的年岁"
        "链条，因此没有生平横条可画——只有事件，按 assets/bible_timeline.json "
        "的公元前后年份「定位」。那一段的底色会淡出，理由和没有记载卒年的横条"
        "淡出是同一个：本图在说它不知道。"
    ),
    "zh-Hant": (
        "此線以左，每一個年份都是「推算」出來的：把創世記 5、11 章所記的生子"
        "年齡相加而得，每根橫條都附著算式。此線以右，經文不再給出連續的年歲"
        "鏈條，因此沒有生平橫條可畫——只有事件，按 assets/bible_timeline.json "
        "的公元前後年份「定位」。那一段的底色會淡出，理由和沒有記載卒年的橫條"
        "淡出是同一個：本圖在說它不知道。"
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

        if pid == "abraham":
            entry["noteEn"] = (
                "assets/family_tree.json dates Abraham 2166-1991 BC, a "
                "late-date scheme that does not join up with the Anno "
                "Mundi count used here (AM 2008-2183 is 1996-1821 BC on "
                "the 4004 BC anchor). Reconciling the two scales past "
                "Abraham is deliberately left to a later pass rather "
                "than fudged.")
            entry["noteZhHans"] = (
                "assets/family_tree.json 把亚伯拉罕定在公元前 2166-1991 年，"
                "属于晚期定年方案，与本图所用的创世纪元并不衔接（AM 2008-2183 "
                "在 4004 锚点下为公元前 1996-1821 年）。亚伯拉罕之后两套刻度的"
                "调和刻意留待后续，不作勉强弥合。")
            entry["noteZhHant"] = (
                "assets/family_tree.json 把亞伯拉罕定在公元前 2166-1991 年，"
                "屬於晚期定年方案，與本圖所用的創世紀元並不銜接（AM 2008-2183 "
                "在 4004 錨點下為公元前 1996-1821 年）。亞伯拉罕之後兩套刻度的"
                "調和刻意留待後續，不作勉強彌合。")

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
    # scrolling right never arrived anywhere. Scripture gives no
    # continuous begetting ages past Abraham, so no lifelines are
    # invented — what extends is the span and the events.
    timeline = json.load(open(TIMELINE, encoding="utf-8"))
    by_marker = {m["id"]: m for m in markers}
    events = []
    seen_ids = set()
    for e in timeline["events"]:
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
            "year": e["year"],
            "era": e["era"],
            "amBasis": "placed",
            "pin": eid in PINNED_EVENTS,
            "refs": list(e.get("refs") or []),
            "titleEn": e["titleEn"],
            "titleZhHans": e["titleZhHans"],
            "titleZhHant": e["titleZhHant"],
        })
    events.sort(key=lambda x: (x["am"], x["id"]))

    for pid in PINNED_EVENTS:
        if not any(x["id"] == pid for x in events):
            problems.append("pinned event %s is not in the timeline" % pid)

    if problems:
        for p in problems:
            sys.stderr.write("FAIL: %s\n" % p)
        raise SystemExit(1)

    # Where the computed chain runs out. NOT Abraham's death — Eber
    # outlives him on the Masoretic count — so it is read off the bars
    # rather than assumed.
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
                "Two layers on one Anno Mundi axis. (1) LIFELINES — "
                "Genesis 5 and 11, Adam to Abraham, the only span where "
                "Scripture states a continuous chain of begetting ages; "
                "names from assets/family_tree.json, years recomputed "
                "from the Masoretic ages and cross-checked against it. "
                "(2) EVENTS — the same 98 events the event list on this "
                "page shows, from assets/bible_timeline.json, placed on "
                "the AM axis by their stated BC/AD year through the "
                "4004 BC anchor, so both views of the page span "
                "Creation to Revelation. The two layers are drawn "
                "differently and labelled, because a placed year is not "
                "a computed one. No data is taken from the copyrighted "
                "reference sheet in docs/reference/."
            ),
            "computedNote": COMPUTED_NOTE,
            "undrawnLines": UNDRAWN,
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
