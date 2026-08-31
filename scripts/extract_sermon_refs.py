#!/usr/bin/env python3
"""
Extract Bible references from each sermon body and emit a reverse
index for the app's bidirectional linking.

Reads:
  assets/sermons/index.json
  assets/sermons/{en,zh-CN,zh-TW}/<id>.txt

Writes:
  assets/sermons/refs.json
    {
      "byVerse": {
        "Luke 4:5":   ["004", "005"],
        "Romans 8:1": ["..."]
      },
      "bySermon": {
        "004": ["Luke 4:5", "Luke 4:6", "Luke 4:13", "Matthew 2:2",
                "1 John 3:8", "John 12:31", "John 14:30", "John 16:11"]
      }
    }

The English book name is canonical (used by the Flutter
`resolveAndPrepareJump` which looks up `verses.firstWhere(book == X)`
post-`translateBookName`). Chinese references in zh-CN / zh-TW bodies
are mapped through the same alias index `parseReference` uses.

Run from repo root:
    python3 scripts/extract_sermon_refs.py
"""
from __future__ import annotations

import json
import re
import sys
from collections import defaultdict
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SERMONS = REPO / "assets" / "sermons"
INDEX_JSON = SERMONS / "index.json"
REFS_OUT = SERMONS / "refs.json"

# ────────────────────────────────────────────────────────────────────
# Book-name alias index. Mirrors the dart-side
# `lib/utils/reference_parser.dart` lookups so Python-extracted refs
# resolve to the same canonical English book names the app uses.
# ────────────────────────────────────────────────────────────────────

CANONICAL_BOOKS = [
    "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy",
    "Joshua", "Judges", "Ruth", "1 Samuel", "2 Samuel",
    "1 Kings", "2 Kings", "1 Chronicles", "2 Chronicles",
    "Ezra", "Nehemiah", "Esther", "Job", "Psalms", "Proverbs",
    "Ecclesiastes", "Song of Solomon", "Isaiah", "Jeremiah",
    "Lamentations", "Ezekiel", "Daniel", "Hosea", "Joel", "Amos",
    "Obadiah", "Jonah", "Micah", "Nahum", "Habakkuk",
    "Zephaniah", "Haggai", "Zechariah", "Malachi",
    "Matthew", "Mark", "Luke", "John", "Acts", "Romans",
    "1 Corinthians", "2 Corinthians", "Galatians", "Ephesians",
    "Philippians", "Colossians", "1 Thessalonians", "2 Thessalonians",
    "1 Timothy", "2 Timothy", "Titus", "Philemon", "Hebrews",
    "James", "1 Peter", "2 Peter", "1 John", "2 John", "3 John",
    "Jude", "Revelation",
]

ENGLISH_ALIASES = {
    "Genesis": ["Gen", "Gn"],
    "Exodus": ["Exo", "Exod", "Ex"],
    "Leviticus": ["Lev", "Lv"],
    "Numbers": ["Num", "Nm", "Nu"],
    "Deuteronomy": ["Deu", "Deut", "Dt"],
    "Joshua": ["Jos", "Josh", "Jsh"],
    "Judges": ["Jdg", "Judg", "Jg"],
    "Ruth": ["Rut", "Ru"],
    "1 Samuel": ["1Sam", "1 Sam", "1Sa", "1 Sa", "I Sam", "ISam"],
    "2 Samuel": ["2Sam", "2 Sam", "2Sa", "2 Sa", "II Sam", "IISam"],
    "1 Kings": ["1Kgs", "1 Kgs", "1Ki", "1 Ki", "I Kings", "IKings"],
    "2 Kings": ["2Kgs", "2 Kgs", "2Ki", "2 Ki", "II Kings", "IIKings"],
    "1 Chronicles": ["1Chr", "1 Chr", "1Ch", "1 Ch", "I Chr", "IChr"],
    "2 Chronicles": ["2Chr", "2 Chr", "2Ch", "2 Ch", "II Chr", "IIChr"],
    "Ezra": ["Ezr", "Ez"],
    "Nehemiah": ["Neh", "Ne"],
    "Esther": ["Est", "Esth"],
    "Job": ["Jb"],
    "Psalms": ["Ps", "Psa", "Psalm"],
    "Proverbs": ["Prv", "Prov", "Pr"],
    "Ecclesiastes": ["Ecc", "Eccl", "Ec"],
    "Song of Solomon": ["Song", "SoS", "Sg", "Cant", "Canticles", "Song of Songs"],
    "Isaiah": ["Isa", "Is"],
    "Jeremiah": ["Jer", "Je"],
    "Lamentations": ["Lam", "La"],
    "Ezekiel": ["Eze", "Ezk", "Ezek"],
    "Daniel": ["Dan", "Dn"],
    "Hosea": ["Hos", "Ho"],
    "Joel": ["Jl"],
    "Amos": ["Am"],
    "Obadiah": ["Oba", "Obd", "Ob"],
    "Jonah": ["Jon", "Jnh"],
    "Micah": ["Mic", "Mc"],
    "Nahum": ["Nah", "Na"],
    "Habakkuk": ["Hab", "Hk"],
    "Zephaniah": ["Zep", "Zeph"],
    "Haggai": ["Hag", "Hg"],
    "Zechariah": ["Zec", "Zech"],
    "Malachi": ["Mal"],
    "Matthew": ["Mat", "Matt", "Mt"],
    "Mark": ["Mar", "Mrk", "Mk"],
    "Luke": ["Luk", "Lk"],
    "John": ["Joh", "Jhn", "Jn"],
    "Acts": ["Act", "Ac"],
    "Romans": ["Rom", "Ro"],
    "1 Corinthians": ["1Cor", "1 Cor", "1Co", "1 Co", "I Cor", "ICor", "1 Corinth"],
    "2 Corinthians": ["2Cor", "2 Cor", "2Co", "2 Co", "II Cor", "IICor", "2 Corinth"],
    "Galatians": ["Gal", "Ga"],
    "Ephesians": ["Eph", "Ep"],
    "Philippians": ["Phil", "Php", "Pp"],
    "Colossians": ["Col", "Cl"],
    "1 Thessalonians": ["1Thess", "1 Thess", "1Th", "1 Th", "I Thes", "IThess"],
    "2 Thessalonians": ["2Thess", "2 Thess", "2Th", "2 Th", "II Thes", "IIThess"],
    "1 Timothy": ["1Tim", "1 Tim", "1Ti", "1 Ti", "I Tim", "ITim"],
    "2 Timothy": ["2Tim", "2 Tim", "2Ti", "2 Ti", "II Tim", "IITim"],
    "Titus": ["Tit", "Ti"],
    "Philemon": ["Phlm", "Phm", "Phn"],
    "Hebrews": ["Heb", "He"],
    "James": ["Jas", "Jam", "Jm"],
    "1 Peter": ["1Pet", "1 Pet", "1Pe", "1 Pe", "I Pet", "IPet"],
    "2 Peter": ["2Pet", "2 Pet", "2Pe", "2 Pe", "II Pet", "IIPet"],
    "1 John": ["1John", "1 Jn", "1Jn", "I John", "IJn", "1 Jo"],
    "2 John": ["2John", "2 Jn", "2Jn", "II John", "IIJn", "2 Jo"],
    "3 John": ["3John", "3 Jn", "3Jn", "III John", "IIIJn", "3 Jo"],
    "Jude": ["Jud", "Jde"],
    "Revelation": ["Rev", "Rv", "Revelations", "Apoc", "Apocalypse"],
}

CHINESE_ALIASES = {
    # Simplified short
    "创": "Genesis", "出": "Exodus", "利": "Leviticus",
    "民": "Numbers", "申": "Deuteronomy",
    "书": "Joshua", "士": "Judges", "得": "Ruth",
    "撒上": "1 Samuel", "撒下": "2 Samuel",
    "王上": "1 Kings", "王下": "2 Kings",
    "代上": "1 Chronicles", "代下": "2 Chronicles",
    "拉": "Ezra", "尼": "Nehemiah", "斯": "Esther",
    "伯": "Job", "诗": "Psalms", "诗篇": "Psalms", "箴": "Proverbs",
    "传": "Ecclesiastes", "歌": "Song of Solomon", "雅歌": "Song of Solomon",
    "赛": "Isaiah", "耶": "Jeremiah", "哀": "Lamentations",
    "结": "Ezekiel", "但": "Daniel",
    "何": "Hosea", "珥": "Joel", "摩": "Amos",
    "俄": "Obadiah", "拿": "Jonah", "弥": "Micah",
    "鸿": "Nahum", "哈": "Habakkuk", "番": "Zephaniah",
    "该": "Haggai", "亚": "Zechariah", "玛": "Malachi",
    "太": "Matthew", "可": "Mark", "路": "Luke", "约": "John",
    "徒": "Acts", "罗": "Romans",
    "林前": "1 Corinthians", "林后": "2 Corinthians",
    "加": "Galatians", "弗": "Ephesians", "腓": "Philippians", "西": "Colossians",
    "帖前": "1 Thessalonians", "帖后": "2 Thessalonians",
    "提前": "1 Timothy", "提后": "2 Timothy",
    "多": "Titus", "门": "Philemon", "来": "Hebrews",
    "雅": "James",
    "彼前": "1 Peter", "彼后": "2 Peter",
    "约一": "1 John", "约二": "2 John", "约三": "3 John",
    "犹": "Jude", "启": "Revelation",
    # Traditional variants
    "書": "Joshua", "師": "Judges",
    "詩": "Psalms", "詩篇": "Psalms",
    "賽": "Isaiah", "結": "Ezekiel",
    "彌": "Micah", "鴻": "Nahum", "該": "Haggai",
    "亞": "Zechariah", "瑪": "Malachi",
    "羅": "Romans",
    "門": "Philemon", "來": "Hebrews",
    "猶": "Jude", "啟": "Revelation",
}


# The full Chinese book names are NOT listed here. They are read out of
# the app's own `_zhAliasToEn`, which is the table the reader already
# resolves a tapped 中文 book name through. Keeping a second hand-typed
# copy is what left 90 of the app's 130 spellings — 申命记, 以赛亚书,
# 加拉太书, every 提摩太 / 帖撒罗尼迦 name — invisible to this script
# while the app understood them perfectly well.
BOOK_NAME_MAPPING_DART = REPO / "lib" / "constants" / "book_name_mapping.dart"


def load_dart_chinese_aliases() -> dict[str, str]:
    src = BOOK_NAME_MAPPING_DART.read_text(encoding="utf-8")
    block = re.search(r"const _zhAliasToEn = \{(.*?)\n\};", src, re.S)
    if not block:
        raise SystemExit(
            f"ERROR: could not find `_zhAliasToEn` in {BOOK_NAME_MAPPING_DART}"
        )
    aliases = {
        alias: canon
        for alias, canon in re.findall(
            r"'([^']+)'\s*:\s*'([^']+)'", block.group(1)
        )
    }
    unknown = sorted({c for c in aliases.values() if c not in CANONICAL_BOOKS})
    if unknown:
        raise SystemExit(
            f"ERROR: _zhAliasToEn maps to non-canonical books: {unknown}"
        )
    missing = [b for b in CANONICAL_BOOKS if b not in set(aliases.values())]
    if missing:
        raise SystemExit(
            f"ERROR: _zhAliasToEn covers only {66 - len(missing)}/66 books; "
            f"missing {missing}"
        )
    return aliases


for _alias, _canon in load_dart_chinese_aliases().items():
    _clash = CHINESE_ALIASES.get(_alias)
    if _clash is not None and _clash != _canon:
        raise SystemExit(
            f"ERROR: {_alias!r} is {_clash} here and {_canon} in "
            f"{BOOK_NAME_MAPPING_DART.name}"
        )
    CHINESE_ALIASES[_alias] = _canon


def build_alias_index() -> dict[str, str]:
    """Lowercased, dot-stripped, internal-whitespace-collapsed alias →
    canonical English book name."""
    idx: dict[str, str] = {}
    def add(alias: str, canonical: str):
        key = re.sub(r"[\s\.　]+", "", alias.lower())
        if key:
            idx[key] = canonical
    for b in CANONICAL_BOOKS:
        add(b, b)
    for canon, aliases in ENGLISH_ALIASES.items():
        for a in aliases:
            add(a, canon)
    for alias, canon in CHINESE_ALIASES.items():
        add(alias, canon)
    return idx


ALIAS = build_alias_index()


# Build an alternation regex of all known book aliases, ordered by
# length descending so "1 Corinthians" beats "Corinth" beats "Cor".
def build_book_pattern() -> str:
    aliases = set()
    for b in CANONICAL_BOOKS:
        aliases.add(b)
    for canon, lst in ENGLISH_ALIASES.items():
        aliases.update(lst)
    aliases.update(CHINESE_ALIASES.keys())
    # Longest first so partial matches don't shadow longer ones.
    sorted_aliases = sorted(aliases, key=lambda s: (-len(s), s))
    escaped = [re.escape(a) for a in sorted_aliases]
    return r"(?:" + "|".join(escaped) + r")"


BOOK_RE = build_book_pattern()


# The aliases that may be preceded directly by a Chinese character.
#
# `\b` is inert against Chinese — every CJK ideograph is a word
# character to Python's `re`, so there is no boundary between 「在」 and
# 「马」 and 「在马太福音2:13，12:14，21:41」 (144) never matched at all.
# The whole citation was invisible, not just its list tail.
#
# Dropping the boundary outright is far worse than the defect. Measured
# over all 867 transcripts: a plain `(?<![0-9A-Za-z_])` adds 742
# (sermon, key) pairs, 616 of them Joshua, because 「书」 is the
# standalone alias for Joshua AND the last character of 腓立比书,
# 以弗所书, 歌罗西书, 罗马书, 以赛亚书 and every other Chinese epistle
# name. 1,906 of the match sites the drop opens up are 书/書 ones, and
# nearly all of them are a longer book name's tail that the boundary
# was the only thing refusing.
#
# A length minimum is what excludes that, and it does not take three
# characters to do it: 书, 書, 传, 歌 are all ONE character, so any
# minimum of two or more keeps them out. Do not read the 3 below as the
# thing holding Joshua back — any minimum above one does that.
#
# Two characters was the queued proposal and it was measured and turned
# down on 2026-08-26. A flat `len(a) >= 2` gains three pairs and costs
# one — but the one it costs is not the whole cost. The twenty
# two-character aliases split cleanly in two: seventeen are
# ABBREVIATIONS whose second character is a positional or ordinal marker
# (提前 撒下 王上 林后 约一 …) and three are complete book names
# (诗篇 詩篇 雅歌). Most of the abbreviations are also everyday words, and
# 提前 ("in advance") is one of the commonest in the language —
# 「我们提前3天到达了会场」 indexes as 1 Timothy 3 the moment they are
# admitted, which is why `test/sermon_ref_extraction_test.dart` has
# pinned that sentence since the minimum was first set.
#
# The queued proposal said this costs nothing because "the corpus has 16
# sites of 提前 mid-sentence and none is followed by a number". Measured,
# that is wrong twice over, and the truth argues the other way. 提前
# occurs 88 times and TWELVE are followed directly by a number — 032
# 「提前八个月」, 365 「提前三天」, EC015 「提前一个月」, 393 「提前一两天」
# and their zh-TW twins. What keeps all twelve out is neither the length
# rule nor luck: it is the bare Chinese-numeral refusal further down,
# which will not read a lone numeral as a chapter without a 第, a 章 or a
# verse. Zero of the 88 use an ASCII DIGIT, and the digit form is exactly
# what walks past that refusal. So the sentence shape is already in the
# corpus twelve times, and all that stands between it and a wrong entry
# is how the transcriber happened to spell the number. That is a thinner
# thing to rest on than the base rate of zero it was sold as (trap 56).
#
# So the second character is admitted only for a complete name. That is
# +2 −0: 092 「诗篇第23篇都知道的」 → Psalms 23 and 344 「诗篇48篇1和8节」
# → Psalms 48. It gives up 423 「林后第五章第十六十七节」 → 2 Corinthians
# 5, and giving that up is a gain rather than a loss — see below.
#
# Honest about what the two keys are worth. Only 092 → Psalms 23 is a
# NEW reach, and it is a clean one: 092 held no Psalms 23 key of any
# kind (its English says "the 23rd Psalm", which the extractor does not
# read), and 「雅伟是我的牧者」 is what its sentence is citing.
#
# 344 → Psalms 48 is a BARE chapter key and it is over-broad. A bare
# chapter key is not a weaker verse key: `passage_filter.dart` treats a
# colon-less key as matching every verse in the chapter, so filtering
# the Sermons page on Psalms 48:3 now returns 344, which cites only
# verses 1 and 8. An earlier draft of this comment called that key
# invisible. It is not — it is invisible only to `sermonsForVerse`,
# which already counted 344 a chapter hit through Psalms 48:1, and the
# two readers do not agree (trap 57).
#
# It is admitted anyway because it is not a new KIND of wrongness.
# 「<章/篇>N和M节」 parses no verse at all — the verse group at the foot
# of REF_RE wants its number flush against 節/节, and 和 breaks that —
# so the corpus already carried SEVENTEEN such bare chapter keys before
# this change (324 Romans 12, 353 Matthew 5, EC010 Revelation 13, …).
# This makes eighteen, and eighteen want one repair, not a special case
# for the newest. The obvious repair is a trap and was measured: letting
# 和 close the verse group is −18 +0, because every FIRST verse of every
# pair is already indexed by some other site, and it strands seven
# SECOND verses that nothing else reaches (239 loses 1 John 2:22, 325
# Hebrews 9:26, 331 Hebrews 5:14 / John 4:34 / Revelation 3:10, 344
# Exodus 14:25 / Psalms 48:8). The repair has to emit BOTH verses, and
# the 第-marked spelling 「第1和2节」 loses its second verse the same way.
# Queued rather than smuggled in here.
#
# Giving up 423 「林后第五章第十六十七节」 → 2 Corinthians 5 is a gain on
# the same reasoning: it is the identical bare-chapter over-breadth, but
# with no class to be repaired alongside it and with the 提前 hazard
# riding in beside it.
#
# 2026-08-30: an evidence-gated relaxation was measured and rejected —
# admit an abbreviation mid-sentence only when a 第, a 章/篇-marked
# number, or an explicit verse colon follows it directly, rather than
# excluding the whole class. Built as `CJK_INFIX_ABBREV_RE` + an
# evidence lookahead folded into `BOOK_START_RE`, in an untracked
# scratch copy, and run over the full 867-transcript corpus. Whole-
# corpus effect: +1 −0 pairs, exhaustively measured (not a sample) and
# independently re-confirmed. The +1 is exactly 423 above —「林后第五章」
# satisfies the evidence gate (第 follows immediately), reopening the
# bare-chapter key this comment just called a gain to give up, and
# duplicating the `2 Corinthians 5:16` / `5:17` 423 already holds by the
# full name. The relaxation's motivating case (156's 「與帖前四章」) is a
# no-op under it: 156 already holds `1 Thessalonians 4` via the full
# name earlier in the same sentence, so the gate reaches no new key
# there, nor at 374's 提后一章十六节 (already holds `2 Timothy 1:16` the
# same way). An evidence gate sounds like it should discriminate, but
# 「第」 is not scoped to a citation — it also introduces the noun that
# follows a chapter number in restated prose, which is exactly the 423
# shape. Net: one known-bad key reopened, zero real gain. Not shipped.
#
# 诗篇 is itself an ordinary word ("psalm"), and 009's 「同一诗篇」 is
# exactly that usage. What handles it is not the length rule but the
# 「第N和第M节」 refusal in `extract_refs`, which is load-bearing here:
# remove it and 009 files `Psalms 9`.
#
# 雅歌 is admitted by the same principle and yields nothing. Do not read
# 721's `Song of Solomon 1:2` as evidence that it works: that line is
# 「# 雅歌一章二节」 at the start of a line, so the ordinary boundary
# already matched it and the infix rule never saw it. The two genuinely
# infix 雅歌 sites are 721 「讲雅歌的哪一部分」 and 327 「雅歌中经常提到
# 的花」, both followed by 的/中 rather than a number.
#
# A "not a proper suffix of any other alias" condition was written first
# and removed: it was inert code whose comment claimed it was what kept
# 书 out. Re-checked while admitting the full names — it admits and
# excludes exactly the same 40 — so it is still inert.
#
# Effect on the corpus when the boundary was first relaxed: +97 (sermon,
# key) pairs of 5,209, −0. The relaxation on its own reached 102; the
# refusals below — every one of them written because it reached them —
# take out seven wrong keys and give back two chapters whose verse was
# refused rather than the whole match, which is the difference.
#
# The second character of every two-character ABBREVIATION, and of no
# complete book name.
_ABBREV_TAIL = "前后後上下一二三"


def build_cjk_infix_book_pattern() -> str:
    def is_cjk(a: str) -> bool:
        return any("一" <= c <= "鿿" for c in a)

    admitted = {a for a in ALIAS if is_cjk(a)
                and (len(a) >= 3
                     or (len(a) == 2 and a[1] not in _ABBREV_TAIL))}
    ordered = sorted(admitted, key=lambda s: (-len(s), s))
    return r"(?:" + "|".join(re.escape(a) for a in ordered) + r")"


CJK_INFIX_BOOK_RE = build_cjk_infix_book_pattern()

# Either a real word boundary, or a Chinese book name whose own spelling
# is proof enough that it is not the tail of a longer word. The
# lookahead only decides admission; `BOOK_RE` still does the capturing,
# so the longest-alias-wins ordering is unchanged. `infix` is an empty
# group that is set only on the second branch, so `extract_refs` can
# tell a citation that had a boundary in front of it from one that did
# not — see the bare-numeral refusal there.
BOOK_START_RE = (rf"(?:\b|(?<=[一-鿿])(?={CJK_INFIX_BOOK_RE})(?P<infix>))")


def build_numbered_tail_pattern() -> str:
    """The word half of every numbered book — John, Peter, Corinthians …
    — so that a chapter number can be refused when it is really the
    ordinal of the book that follows it."""
    tails = {b.split(" ", 1)[1] for b in CANONICAL_BOOKS
             if b[0].isdigit() and " " in b}
    return r"(?:" + "|".join(re.escape(t) for t in sorted(tails)) + r")"


NUMBERED_TAIL_RE = build_numbered_tail_pattern()

# Chinese numeral chapters — 「雅歌一章二節」 is a citation, and the
# sermon titles use this form in preference to digits.
_CN_DIGIT = {"一": 1, "二": 2, "三": 3, "四": 4, "五": 5,
             "六": 6, "七": 7, "八": 8, "九": 9}
_CN_NUM_RE = r"[〇零一二三四五六七八九十百]+"

# Structural rather than accumulating, so that a run which merely
# CONTAINS numeral characters is rejected instead of yielding a
# plausible number: 十十 accumulates to 20 and is not a numeral at all.
_CN_NUM_SHAPE = re.compile(
    r"^(?:(?P<h>[一二三四五六七八九])百)?"
    r"(?:(?P<t>[一二三四五六七八九])?(?P<ten>十))?"
    r"(?:[〇零]?(?P<u>[一二三四五六七八九]))?$")


def cn_number(s: str) -> int | None:
    """Parse 一 / 十二 / 二十三 / 一百一十九 to an int in 1..199, or None
    when [s] is not a well-formed numeral."""
    m = _CN_NUM_SHAPE.fullmatch(s)
    if not m:
        return None
    n = 0
    if m.group("h"):
        n += _CN_DIGIT[m.group("h")] * 100
    if m.group("ten"):
        n += (_CN_DIGIT[m.group("t")] if m.group("t") else 1) * 10
    if m.group("u"):
        n += _CN_DIGIT[m.group("u")]
    return n if 0 < n < 200 else None


# 和 joining a bare number to a number that carries 節/节 — 「第九和第十
# 节」. Applied against the text after a chapter number by `extract_refs`;
# the reasoning is there.
_CN_VERSE_PAIR_RE = re.compile(
    rf"\s*[和与與及]\s*第?\s*(?:\d+|{_CN_NUM_RE})\s*[節节]")


# 「<章/篇>N和M节」 — two verses of the chapter the mark just closed.
# Applied against the text after the chapter mark by `extract_refs`; the
# reasoning is there. Both numbers are endpoints, never a span.
_CN_CHAPTER_VERSE_PAIR_RE = re.compile(
    rf"\s*第?\s*(?:(?P<p1>\d+)|(?P<p1cn>{_CN_NUM_RE}))"
    rf"\s*[和与與及]\s*第?\s*"
    rf"(?:(?P<p2>\d+)|(?P<p2cn>{_CN_NUM_RE}))\s*[節节]")


# A number that belongs to the following unit, not to scripture:
# "Deuteronomy 43 times", "Is 50% enough?". Shared by `_UNIT_AFTER`
# below and by the bare-comma verse guard inside REF_RE, so the two
# cannot drift apart.
_UNIT_WORDS = (r"(?:times?|years?|days?|hours?|minutes?|weeks?|months?|"
               r"words?|percent)\b|%")

# A full reference. Beyond `<book> <chapter>:<verse>` this also reads the
# spelled-out prose these transcripts actually use — "Ezekiel chapter 13
# verses 10 and 16", 「以西結書第13章10節」, 「雅歌一章二節」 — because a
# preacher dictating a reference says it in words far more often than he
# says it in punctuation.
REF_RE = re.compile(
    rf"{BOOK_START_RE}(?P<book>{BOOK_RE})"
    rf"\.?\s*"
    # "2 Kings, chapter 13" — the comma is admitted only when a chapter
    # WORD follows, so a bare "Romans, 5" stays prose.
    rf"(?:[,，]\s*(?P<chcomma>chapters?|ch\.)\s*"
    rf"|(?P<chword>chapters?|ch\.|第)\s*)?"
    # "…the letters of John. 1 John 2 and verse 18" — the 1 is the
    # ordinal of the NEXT book, not a chapter of this one. Refusing it
    # here rather than after the match matters: a post-hoc skip would
    # leave the 1 consumed and the scan would resume mid-name and read
    # the Gospel. Failing in the pattern makes the engine retry from the
    # 1 and find 1 John.
    rf"(?![1-3]\s+{NUMBERED_TAIL_RE}\b)"
    rf"(?:(?P<ch>\d+)|(?P<chcn>{_CN_NUM_RE}))"
    rf"(?P<chmark>\s*[章篇])?"
    rf"(?:"
    # An explicit separator carries the verse: "17:3", "chapter 10,
    # verse 19", 「第13章第10節」.
    rf"(?:\s*[,，、]?\s*(?:and\s+)?"
    rf"(?:[:：.]|verses?\s+|vv?\.\s*|第\s*)\s*"
    # …or nothing but a comma and a space. "Romans 13, 9, when speaking
    # about the central issue of the law" (C174) and "Romans 8, 3, says
    # what?" (C175) are how this preacher restates a reference he has
    # just read out, and both reached only their chapter. The space is
    # load-bearing: it is what tells a verse from a thousands separator,
    # so "the Apostle John 2,000 years ago" (EC010) cannot become a
    # citation. ASCII comma only, because every one of the 19 sites of
    # this shape in the corpus is in an English transcript and a
    # fullwidth comma with a space after it is not how the Chinese ones
    # are written — an unmeasured miss is preferred to an invention.
    # A spelled-out chapter word ahead of the number is what makes a
    # following bare number readable as ANOTHER CHAPTER: "John chapters
    # 12, 14 and 16" (004) is a list of three chapters and became John
    # 12:14, a verse that exists and that the sermon never opens. The
    # pattern therefore admits the form and `extract_refs` decides it,
    # because the deciding fact is the canon and no regex can see it —
    # a far number BEYOND the book's chapter count cannot be a chapter,
    # so the ambiguity that forces the refusal simply is not there.
    # Restricting it to the plural was tried instead and is not
    # defensible: "Romans chapter 8, 1 and 2" (356) is singular with a
    # far number that IS a plausible chapter of Romans.
    # "as we saw in Genesis 1, 2 Peter tells us…" — the 2 is the ordinal
    # of the NEXT book. Same lookahead the chapter position already uses, for
    # the same reason: refuse in the pattern so the engine retries from
    # the 2 and finds 2 Peter, rather than consuming it as a verse.
    rf"|(?P<vbare>,\s+(?![1-3]\s+{NUMBERED_TAIL_RE}\b)(?=\d))"
    rf")"
    rf"(?:(?P<v>\d+)|(?P<vcn>{_CN_NUM_RE}))"
    # A verse number may not give up a digit to make the guards below
    # pass. 385 stutters — 「在哥林多後書第12章，第12章第10節」 — and
    # the `(?!\s*[章篇])` guard three lines down was defeated exactly
    # that way: `\d+` handed back the 2, the lookahead then saw "2章"
    # rather than "章", and the sermon was filed under 2 Corinthians
    # 12:1 instead of the 12:10 it goes on to read. Same failure the
    # bare-comma form already documents below, so it is hoisted out of
    # that conditional and applied to every form. Two sites, both this
    # sentence in its zh-CN and zh-TW bodies. It is also what makes the
    # refusal on the next line safe: without it, 「羅馬書8:28次」 hands
    # back the 8 and files 8:2 instead of declining to guess.
    rf"(?!\d)"
    # 「第二次」 is "a second TIME", not verse 2. The English unit-word
    # guard has no Chinese half, so 「一次在哥林多前書第9章，第二次在加
    # 拉太書」 (077) became 1 Corinthians 9:2 and 「正如启示录20章第二次
    # 复活所描述的」 (136) became Revelation 20:2 — the binding of Satan,
    # which neither sermon opens. Refusing the verse rather than the
    # whole match leaves the chapter, which is what was actually cited.
    #
    # 136 is quoted from its zh-CN body on purpose: its zh-TW twin writes
    # 啓示錄 with the 啓 variant, which is not in the alias table, so that
    # body never matched at all. That gap is queued — it is 96 sites.
    #
    # 次 alone, and that is minimality rather than caution. The first
    # draft listed thirteen measure words (次 回 个 個 点 點 条 條 位 格
    # 句 段 天); guarding all thirteen instead of 次 moves the index by
    # +0 −0, because the other twelve never follow a verse number here.
    # They are free, then — but free is not a reason to carry them, and
    # each one begins some of the commonest words in the language (回答,
    # 個人, 點明, 條件, 位格), so the day one of them does follow a verse
    # number it is as likely to be prose as a measure word. Only 次 has
    # evidence: 3 sites, all three of them 「第二次」.
    rf"(?!次)"
    # Two guards that apply only to the bare-comma form, because it is
    # the only one with no word in it saying "this is a verse".
    #
    # A third comma-separated number makes the whole thing a list of
    # CHAPTERS: "Matthew 23, 24, 25. They are one unit of the Lord's
    # teaching" (247) and "in Romans 6, 7, and 8, we have three distinct
    # categories" (356). Both would otherwise have been indexed as
    # Matthew 23:24 and Romans 6:7 — verses that exist, so the canon
    # check cannot catch them. "2 Peter 2, 7 and 8" (009) keeps its
    # range because there is no comma before the `and`.
    #
    # And a unit word after the number means it was never scripture.
    #
    # `(?!\d)` is not decoration: without it `\d+` backtracks and the
    # guard is worthless. "Matthew 23, 24, 25" gave up its second digit
    # and matched the verse as `2`, whose lookahead then saw "4, 25"
    # and passed — Matthew 23:2, from a sentence naming three chapters.
    rf"(?(vbare)(?!\d)(?!\s*,\s*(?:and\s+)?\d)(?!\s*(?i:{_UNIT_WORDS})))"
    # "verses 20 and 21" is a two-verse RANGE, but "verses 12, 14 and 15"
    # is a list and walking it would invent verse 13. `vand` marks the
    # `and` so extract_refs can demand the two be adjacent, which is the
    # one case where a two-item list and a two-verse range are the same
    # set. The lookahead refuses the ordinal of a following book, so
    # "Romans 8:1 and 2 Corinthians 5:17" cannot become Romans 8:1-2 —
    # and it is BOOK_RE rather than the NUMBERED_TAIL_RE used for the
    # chapter position, because that one is built from full names only:
    # "Psalm 23:1 and 2 Sam 7:14" walks past it and both invents
    # Psalms 23:2 and loses 2 Samuel 7:14.
    rf"(?:\s*(?:[-–—]\s*|(?:to|through)\s+"
    # …and a number carrying a verse of its own is a second citation,
    # not a far end: "Matthew 14:14 and 15:32" names two feedings. This
    # has to REFUSE rather than match-then-discard, or the 15 is
    # consumed and 15:32 never reaches the index — and where the two
    # happen to be adjacent (14→15) discarding would invent 14:15.
    rf"|\b(?P<vand>and)\s+(?!{BOOK_RE})(?!\d+\s*[:：]\s*\d)|[至到]\s*)"
    rf"(?:(?P<vend>\d+)|(?P<vendcn>{_CN_NUM_RE}))"
    # 「馬太福音11:30-12:1-8」 — the number past the dash carries a verse
    # of its own, which makes it the far CHAPTER and the whole thing one
    # passage crossing a chapter boundary. Never after `and`: that reads
    # a sentence stop as a separator, so "verses 7 and 8. 2 Peter 2"
    # swallowed the next citation's ordinal and lost it (trap 50).
    rf"(?:(?(vand)(?!))\s*[:：.]\s*(?P<echv>\d+)"
    rf"(?:\s*[-–—]\s*(?P<echv2>\d+))?)?)?"
    # A number that carries its own 章 is a chapter restated, not a
    # verse: 「馬可福音第九章，第九章的最後部分」 would otherwise read
    # the second 第九 as Mark 9:9.
    rf"(?!\s*[章篇])"
    rf"|"
    # 「八章五節」 — Chinese puts nothing between the chapter mark and
    # the verse, so the separator is the 章 behind and the 節 ahead.
    # The trailing 節 is what does the work: the lookbehind is flush
    # against 章 but the `\s*` after it still admits a space, so
    # 「二十四章 1948年」 reaches the number and is turned away only
    # because 年 is not 節.
    rf"(?<=[章篇])\s*第?\s*"
    rf"(?:(?P<v2>\d+)|(?P<vcn2>{_CN_NUM_RE}))"
    rf"(?:\s*[-–—至到]\s*"
    rf"(?:(?P<vend2>\d+)|(?P<vendcn2>{_CN_NUM_RE})))?\s*[節节]"
    rf")?",
)


def normalize_alias(s: str) -> str:
    return re.sub(r"[\s\.　]+", "", s.lower())


# Books of a single chapter: a bare number after them is a VERSE.
# 2026-08-23: "Jude 6 confirms this" was indexed as Jude chapter 6 and
# the sermon became unreachable by that reference — Jude has no
# chapter 6 to navigate to. Same for 2 John 7/10.
ONE_CHAPTER = {"Obadiah", "Philemon", "2 John", "3 John", "Jude"}

# An English number that belongs to the following unit, not the book:
# "the word occurs in Deuteronomy 43 times" indexed Deuteronomy 43,
# a chapter that does not exist.
#
# `verse(s)` was in this list until 2026-08-25 and did the opposite of
# its job: "Jeremiah 12 verse 2" is the most explicit citation English
# has, and the guard threw all 17 such references away. The verse word
# is now a SEPARATOR in REF_RE, so a unit-word match cannot reach it.
# `%` sits outside the `\b`: a per-cent sign is not a word character, so
# `%\b` only matches when a LETTER follows it, and "Is 50% enough?" —
# sermon 424, the verb `is` plus a percentage — reached the index as
# Isaiah 50.
_UNIT_AFTER = re.compile(rf"\s*(?:{_UNIT_WORDS})", re.IGNORECASE)

_CJK = re.compile(r"[\u4e00-\u9fff]")

# Immediately before a book alias, and only ever consulted for John.
_EPISTLE_OF = re.compile(
    r"(?:letters?|epistles?)\s+of\s+(?:the\s+)?$", re.IGNORECASE)


def _load_canon() -> dict[str, dict[int, set[int]]]:
    """book \u2192 chapter \u2192 verses, from KJV, whose book names are the same
    canonical English strings this script emits."""
    out: dict[str, dict[int, set[int]]] = {}
    for row in json.loads((REPO / "assets" / "kjv.json")
                          .read_text(encoding="utf-8")):
        out.setdefault(row["book"], {}).setdefault(
            int(row["chapter"]), set()).add(int(row["verse"]))
    return out


CANON = _load_canon()


def exists(book: str, ch: int, verse: int | None) -> bool:
    """A reference nobody can navigate to must not enter the index \u2014
    the sermon would be filed under a passage that does not exist.
    These are transcription slips, not citation styles: sermon CP37
    says \u300c\u555f\u793a\u9304\u4e09\u5341\u4e03\u7ae0\u5341\u4e03\u7bc0\u300d two sentences after \u300c\u555f\u793a\u9304\u7b2c\u4e09\u7ae0\u300d,
    quoting Laodicea, so the chapter is 3 and the \u5341\u4e03 is the verse."""
    chapters = CANON.get(book)
    if chapters is None or ch not in chapters:
        return False
    return verse is None or verse in chapters[ch]


def _int(digits: str | None, numeral: str | None) -> int | None:
    """A number written either way, or None when neither is present and
    when a Chinese numeral turns out to be malformed."""
    if digits is not None:
        return int(digits)
    return cn_number(numeral) if numeral is not None else None


# All that may stand between two citations for the second to be the far
# end of the first: "Matthew 24, verse 45, right up to Matthew 25,
# verse 30" is one passage, and REF_RE can only ever see two.
_RANGE_LINK = re.compile(
    r"\s*[,，、]?\s*(?:right\s+)?(?:up\s+|through\s+|clear\s+)?"
    r"(?:to|through|thru|until|一直到|直到|至|到)\s*[,，、]?\s*",
    re.IGNORECASE)


# "Matthew 14:14 and 15:32 for the feedings of the five and four
# thousand" (101) names two passages, and the second has no book in
# front of it — REF_RE refuses it as a range end (correctly: the verses
# between were never named) and then nothing picks it up, because a bare
# "15:32" is not a citation on its own. The book name carries across the
# `and`, so the fragment is re-read with the book spliced back in.
# A chapter of its own is what distinguishes this from "verses 20 and
# 21": that is a range and REF_RE already walks it.
#
# A comma or semicolon does the same job as the `and`, and runs on:
# "Jeremiah 4:7, 7:11, 7:34, 22:5, 32:4, 51:6, 51:22" (143) is seven
# citations of one book, and "馬太福音16:21；17:9；17:23；20:19；26:32"
# (207) is the same sentence in Chinese. So the fragment is consumed in
# a LOOP, each item resolved on its own with a fresh `prev` — two
# endpoints per item, never a span between items, because the verses
# between were never named.
#
# What stops it running away is that every item must carry its own
# colon. A bare number after a comma is not admitted here at all, so a
# sentence's worth of numerals cannot join the index; only a `C:V` can,
# and a `C:V` sitting immediately after a citation in a list is a
# citation. Measured over the whole corpus: 28 sites match, and every
# consumed item is a real reference — no time of day, no ratio, no
# score.
#
# The range tail is admitted only UNSPACED and only with a hyphen or an
# en-dash. This is narrower than the `to`/`through`/spaced-dash tail
# that was tried and removed here on 2026-08-25 — that one handed
# REF_RE a far number with no unit-word guard in front of it, so "Mark
# 6:34 and 8:1 to 4000 people" would have filed the sermon under
# thirty-eight verses of Mark 8. `to` is still refused. The unspaced
# form cannot be that: all 1,202 occurrences of `C:V[-–]N` in the
# corpus are genuine ranges, none is spaced, and the em-dash this
# preacher's prose actually uses (` — `, `——`) is excluded twice over.
# Without it 057's "Isaiah 29:18–20, 35:5–6, and 61:1" stops dead at
# the dash and loses 61:1 as well as 35:6.
_AND_SECOND_REF = re.compile(
    r"\s*(?:[,;，；]\s*(?:and\s+)?|and\s+)"
    r"(\d+\s*[:：]\s*\d+(?:[-–]\d+)?)", re.IGNORECASE)


def _walk(book: str, c1: int, v1: int, c2: int, v2: int):
    """Every verse from [book] c1:v1 through c2:v2 inclusive, skipping
    any the canon does not have."""
    for c in range(c1, c2 + 1):
        verses = CANON.get(book, {}).get(c)
        if not verses:
            continue
        lo = v1 if c == c1 else min(verses)
        hi = v2 if c == c2 else max(verses)
        for v in range(lo, hi + 1):
            if v in verses:
                yield c, v


def extract_refs(text: str) -> list[str]:
    """Return canonical "Book chapter:verse" strings (deduped, in
    order of first appearance) found in [text]."""
    seen: set[str] = set()
    out: list[str] = []
    prev: tuple[str, int, int, int] | None = None
    for m in REF_RE.finditer(text):
        alias_raw = m.group("book")
        canon = ALIAS.get(normalize_alias(alias_raw))
        if not canon:
            continue
        if m.group("ch") is not None:
            ch = int(m.group("ch"))
        else:
            ch = cn_number(m.group("chcn"))
            if ch is None:
                continue
        pair_verses = False
        verse = _int(m.group("v") or m.group("v2"),
                     m.group("vcn") or m.group("vcn2"))
        last = _int(m.group("vend") or m.group("vend2"),
                    m.group("vendcn") or m.group("vendcn2"))
        # `and` is only a range separator between adjacent verses. Any
        # other pair is a list — "verses 12 and 15" names two verses and
        # walking it would file the sermon under 13 and 14 as well.
        if m.group("vand") is not None and last != (verse or 0) + 1:
            last = None
        # A spelled-out marker — "chapter 13", 「第13章」 — is proof the
        # number is a chapter, so the prose guards below cannot apply.
        marked = (m.group("chword") is not None
                  or m.group("chcomma") is not None
                  or m.group("chmark") is not None)
        # A book name found mid-sentence, with no boundary in front of
        # it, needs the citation itself to say it is one. A lone Chinese
        # numeral does not: 「启示录一段经文」 is "a passage of
        # Revelation", 「从创世记一直绕到启示录」 is "all the way from
        # Genesis", 「亚伯拉罕在创世记一开始就被提到」 is "at the very
        # beginning of Genesis" — 一段 / 一直 / 一开始 are ordinary
        # words whose first character is also the numeral one. Those
        # three are the only sites the relaxed boundary reaches this way,
        # and all three are false. A digit chapter, a 第 or 章, or a
        # verse is enough; the boundary form keeps its existing (weaker)
        # behaviour, because the boundary is itself the evidence this
        # branch has given up.
        if (m.group("infix") is not None
                and m.group("chcn") is not None
                and not marked
                and m.group("v") is None and m.group("vcn") is None
                and m.group("v2") is None and m.group("vcn2") is None):
            continue
        # 「你看，在馬太福音第十八節」 (016) — 節 says the number is a
        # VERSE, so it is not the chapter, and the chapter is nowhere in
        # the sentence. The paragraph is expounding Matthew 15, but that
        # has to be read to know it, so nothing is filed rather than
        # guessed. One-chapter books are exempt because the rule above
        # has already turned their bare number into a verse, which is
        # how 023's 「以猶大書第七節」 and 012's 「約翰二書第三節」 are
        # right.
        #
        # 2026-08-31: generalised from the infix branch to the boundary
        # form too, after reading all 8 paragraphs this shape reaches in
        # the corpus — 010, 106, 150 and 247, each in both zh-CN and
        # zh-TW. 010's 「詩篇第二十七節」 belongs to Psalm 37 — the
        # paragraph names it three sentences earlier — and 27 is the
        # VERSE quoted right after, so the old infix-only guard let
        # "Psalms 27" through. 247's 「啟示錄12節」 has its chapter (19)
        # three words earlier and is really Revelation 19:12; no
        # same-sentence reach-back exists yet to recover it, so nothing
        # is filed for that clause, but 247 loses no Revelation 12
        # entry — two other, chapter-marked citations of it survive
        # elsewhere in the same file. 106 and 150's 「但第11/30節」 (但 =
        # "but", read as Daniel) never reached this guard either way:
        # the single-CJK-character abbreviation rule below already
        # refuses them for lack of a verse or 章.
        if not m.group("chmark"):
            ch_end = m.end("ch") if m.group("ch") else m.end("chcn")
            if (text[ch_end:ch_end + 1] in ("节", "節")
                    and len(CANON.get(canon, {1: 0})) > 1):
                continue
        # 「同一诗篇第九和第十节」 (009) — 和 joins two things of the same
        # kind, and the 节 on the second says both of them are VERSES, so
        # the first is not the chapter and the chapter is nowhere in the
        # sentence. 「同一诗篇」 is "the SAME psalm": 009 names 诗篇第四十二
        # 篇 three times in the paragraph before and the words quoted here
        # are CUV Psalm 42:9-10 verbatim. Recovering that needs the
        # paragraph read, so nothing is filed rather than a plausible
        # `Psalms 9`.
        #
        # A 章/篇 mark on the first number is proof it really is the
        # chapter — 149's 「罗马书第12章第1和第2节」 — so the mark exempts
        # it. What is left was measured rather than assumed, because a
        # base rate of zero is not what licenses a rule (trap 56): the
        # whole corpus holds SIX sites where a book alias is followed by a
        # chapter number carrying no 章/篇 and then 和. Four of them are
        # 357's 「哥林多後書第11和12章」 and 219's 「哥林多前書第二和第三
        # 章」 in both Chinese bodies — real chapter pairs that ship today
        # as `2 Corinthians 11` and `1 Corinthians 2` — and the unit word
        # is the only thing standing between them and this rule. 章 keeps
        # them; 节 refuses 009's two.
        if not m.group("chmark"):
            ch_end = m.end("ch") if m.group("ch") else m.end("chcn")
            if _CN_VERSE_PAIR_RE.match(text, ch_end):
                continue
        # "John chapters 12, 14 and 16" is a list of CHAPTERS, and a
        # spelled-out chapter word ahead of the number is what makes the
        # bare number after the comma readable that way. The one shape
        # where that reading is impossible is a number past the end of
        # the book: Hebrews has 13 chapters, so "Hebrews chapter 2, 14
        # and 15" (848) can only be verses. Everything else keeps the
        # chapter and drops the number — which is what the pattern used
        # to do by refusing to match it at all.
        if (m.group("vbare") is not None
                and (m.group("chword") is not None
                     or m.group("chcomma") is not None)
                and verse is not None
                and verse <= max(CANON.get(canon, {0}))):
            verse = last = None
        # The same list, one separator further out. REF_RE's chapter-list
        # refusal looks for a second COMMA, so a list whose second
        # separator is a bare `and` walks past it — and the adjacency
        # rule above then turns the pair into a range. "Matthew 5, 6 and
        # 7 are the Sermon on the Mount" would be filed under Matthew 5:6
        # and 5:7, verses the sentence never opens.
        #
        # What separates the two readings is that a chapter list COUNTS
        # ON from the chapter it started at: 5, 6, 7. The canon alone
        # cannot do it. Refusing whenever both numbers are plausible
        # chapters was tried first and is indefensible — it would lose
        # "Matthew 28, 19 and 20", "Romans 12, 1 and 2" and "Genesis 1,
        # 26 and 27", and this preacher demonstrably restates a reference
        # in the bare form in the same breath as the explicit one: 009,
        # 327 and 353 all do.
        #
        # Measured over the whole corpus: of the 148 adjacent `and` verse
        # pairs, in every separator form, NOT ONE counts on from its
        # chapter. That is a measured base rate and not a structural
        # impossibility — v == ch+1 holds for 2.9% of verse-bearing
        # matches, so a genuine "Book C, C+1 and C+2" would be reduced to
        # its chapter. The trade is deliberate: what it refuses is an
        # invention, what it risks is a miss, and on a study interface an
        # invented verse is the expensive one.
        #
        # Scoped to `and`, which is how a list is spoken. `to`, `through`
        # and a dash are range words and are left alone, so 015's
        # "Matthew 5, 10 to 12" and 089's "Luke 14, 7 to 14" keep their
        # verses.
        if (m.group("vbare") is not None
                and m.group("vand") is not None
                and verse == ch + 1 and last == verse + 1
                and last <= max(CANON.get(canon, {0}))):
            verse = last = None
        # 「<章/篇>N和M节」 — 344's 「诗篇48篇1和8节」, 149's 「罗马书第12章
        # 第1和第2节」. REF_RE's verse group wants its number flush against
        # 節/节 and 和 breaks that, so the whole optional group fails and
        # the match degrades to a bare chapter key — which is not a weaker
        # verse key but a WIDER one, matching every verse of the chapter
        # in passage_filter.dart. Recovered here rather than in the
        # pattern because the two spellings land in different branches:
        # 「篇1和8节」 fails the Chinese branch outright, while 「章第1和第2
        # 节」 matches the explicit-separator branch, keeps verse 1 and
        # drops verse 2 silently. One rule anchored on the chapter mark
        # covers both.
        #
        # Two ENDPOINTS, never a span. 「第1和8节」 names verses 1 and 8;
        # walking them would file the sermon under six verses nobody
        # mentioned. That is also why the obvious repair — letting 和
        # close REF_RE's verse group — is worse than nothing: measured, it
        # is −18 +0, because every first verse of every pair is already
        # indexed elsewhere and the second verses are what is missing.
        #
        # The 章/篇 mark is the whole of the evidence, and it has to be:
        # without it 「哥林多後書第11和12章」 (357) is a CHAPTER pair, and
        # 009's 「同一诗篇第九和第十节」 is two verses of a psalm whose
        # number is nowhere in the sentence. Both are handled above and
        # neither reaches here, because neither carries a mark on the
        # number this rule reads as the chapter.
        #
        # It runs last, after every guard that nulls a verse, and cannot
        # undo one. Not because those guards test the mark — the `vand`
        # and `vbare` guards do not — but because their separators are
        # disjoint from this one's: `vbare` needs an ASCII comma and a
        # space where this needs 第 or a digit flush against the mark,
        # and `vand` needs the English word. Measured: of the 142
        # firings, none has `vand` or `vbare` set. The first draft of
        # this comment claimed the mark was what kept them apart, which
        # was a comfortable reason rather than the true one.
        pair = (_CN_CHAPTER_VERSE_PAIR_RE.match(text, m.end("chmark"))
                if m.group("chmark") is not None else None)
        if pair is not None:
            first = _int(pair.group("p1"), pair.group("p1cn"))
            second = _int(pair.group("p2"), pair.group("p2cn"))
            if first is not None and second is not None:
                verse, last, pair_verses = first, second, True
        if ch <= 0 or ch > 200:
            continue
        # "the first letter of John, chapter 2" is 1 John, and the bare
        # alias resolves to the Gospel. Which of the three letters it is
        # cannot be recovered from this phrase, so index nothing rather
        # than the wrong book. Only John is ambiguous this way: every
        # other "letter of X" names a book with no gospel to be confused
        # with, and "book of X" / "Gospel of X" are left alone because
        # all thirteen in this corpus are correct.
        if canon == "John" and _EPISTLE_OF.search(text[:m.start()]):
            continue
        # "Deuteronomy 43 times" — the number is a count, not a chapter.
        if not verse and not marked and _UNIT_AFTER.match(text, m.end()):
            continue
        # Single-CJK-character abbreviations are ordinary words far more
        # often than they are book names: 但20分钟 is "but 20 minutes",
        # 约20人 is "about 20 people", 传 is to pass on, 该 is should.
        # A real citation in that compressed style carries a verse
        # (但3:16) or the word 章 right after the number; without either,
        # the match is prose. Two-character aliases (撒上, 林前…) have
        # no such second life and pass as before.
        if (_CJK.match(alias_raw) and len(alias_raw) == 1 and not verse
                and m.group("chmark") is None):
            continue
        if canon in ONE_CHAPTER:
            # Jude 6 means Jude 1:6. A chapter other than 1 with an
            # explicit verse cannot exist in these books — drop it
            # rather than index the unreachable.
            if verse and ch != 1:
                continue
            if not verse:
                verse, ch = ch, 1
        if not exists(canon, ch, verse):
            continue
        # "Matthew 25 verses 31 to 46" is sixteen verses, and only the 31
        # used to reach the index — harmless while the same match also
        # left a bare "Matthew 25" behind, fatal once it stopped.
        # passage_filter.dart has always described the index as one key
        # per verse; this is the extractor finally writing that.
        span = [(ch, verse)]
        if pair_verses:
            if last != verse and exists(canon, ch, last):
                span.append((ch, last))
        else:
            # 200 verses is more than any real citation and stops a
            # misread pair of numbers from filing a sermon under half a
            # book.
            far_ch, far_v = ch, last
            if m.group("echv") is not None and last is not None:
                far_ch = last
                far_v = int(m.group("echv2") or m.group("echv"))
            if (verse is not None and far_v is not None
                    and (far_ch, far_v) > (ch, verse)):
                walked = list(_walk(canon, ch, verse, far_ch, far_v))
                if len(walked) <= 200:
                    span = walked
        # A range the preacher stated as two whole citations.
        if (prev is not None and prev[0] == canon and verse is not None
                and (ch, verse) > (prev[1], prev[2])
                and _RANGE_LINK.fullmatch(text[prev[3]:m.start()])):
            walked = list(_walk(canon, prev[1], prev[2], ch, verse))
            if len(walked) <= 200:
                span = sorted(set(span) | set(walked))
        if verse is not None:
            prev = (canon, ch, verse, m.end())
        for (c, v) in span:
            key = f"{canon} {c}:{v}" if v else f"{canon} {c}"
            if key not in seen:
                seen.add(key)
                out.append(key)
        # The rest of "Book C:V and C2:V2" / "Book C:V, C2:V2, C3:V3".
        # Each fragment is bounded to the citation itself rather than the
        # rest of the text, so the recursion cannot re-read the whole
        # sermon out of order, and it starts with a fresh `prev`, so two
        # citations cannot be walked into one span. The loop ends the
        # moment the text stops looking like another `C:V` in the list —
        # "Matthew 3:11, 21:9, John 11:27" (143) hands 21:9 over and then
        # stops, leaving John 11:27 to REF_RE's own scan.
        pos = m.end()
        while True:
            tail = _AND_SECOND_REF.match(text, pos)
            if tail is None:
                break
            for key in extract_refs(f"{canon} {tail.group(1)}"):
                if key not in seen:
                    seen.add(key)
                    out.append(key)
            pos = tail.end()
    return out


def main() -> int:
    if not INDEX_JSON.exists():
        print(f"ERROR: {INDEX_JSON} missing — run ingest_sermons.py first",
              file=sys.stderr)
        return 1
    sermons = json.loads(INDEX_JSON.read_text(encoding="utf-8"))
    by_sermon: dict[str, list[str]] = {}
    by_verse: dict[str, list[str]] = defaultdict(list)
    total_refs = 0

    for sermon in sermons:
        sid = sermon["id"]
        # Aggregate refs from all available languages — Chinese bodies
        # often pick up references missed by the English (and vice
        # versa) because the prose is independently structured.
        merged: list[str] = []
        seen: set[str] = set()
        # Always seed from the index "passage" hint if present so the
        # canonical sermon passage links even if it never appears in
        # body prose.
        passage_hint = sermon.get("passage", "")
        if passage_hint:
            for r in extract_refs(passage_hint):
                if r not in seen:
                    seen.add(r); merged.append(r)
        for lang in ("en", "zh-CN", "zh-TW"):
            body_path = SERMONS / lang / f"{sid}.txt"
            if not body_path.exists():
                continue
            for r in extract_refs(body_path.read_text(encoding="utf-8")):
                if r not in seen:
                    seen.add(r); merged.append(r)
        if merged:
            by_sermon[sid] = merged
            for ref in merged:
                by_verse[ref].append(sid)
            total_refs += len(merged)

    # Sort byVerse keys + ids for deterministic output.
    sorted_by_verse = {
        k: sorted(set(v)) for k, v in sorted(by_verse.items())
    }

    REFS_OUT.write_text(
        json.dumps(
            {"byVerse": sorted_by_verse, "bySermon": by_sermon},
            ensure_ascii=False,
            separators=(",", ":"),
        ),
        encoding="utf-8",
    )

    size_kb = REFS_OUT.stat().st_size / 1024
    print(f"Wrote {REFS_OUT.relative_to(REPO)}")
    print(f"  Sermons with at least 1 ref : {len(by_sermon)} / {len(sermons)}")
    print(f"  Unique verses cited         : {len(sorted_by_verse)}")
    print(f"  Total ref occurrences       : {total_refs}")
    print(f"  refs.json size              : {size_kb:.1f} KB")
    # Quick sanity: top-10 most-cited verses.
    top = sorted(sorted_by_verse.items(), key=lambda x: -len(x[1]))[:10]
    print("\nTop 10 most-cited verses:")
    for ref, sids in top:
        print(f"  {ref:30s} {len(sids):3d} sermons")
    return 0


if __name__ == "__main__":
    sys.exit(main())
