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
    # Common full Chinese names
    "创世记": "Genesis", "創世記": "Genesis",
    "出埃及记": "Exodus", "出埃及記": "Exodus",
    "马太福音": "Matthew", "馬太福音": "Matthew",
    "马可福音": "Mark", "馬可福音": "Mark",
    "路加福音": "Luke",
    "约翰福音": "John", "約翰福音": "John",
    "使徒行传": "Acts", "使徒行傳": "Acts",
    "罗马书": "Romans", "羅馬書": "Romans",
    "哥林多前书": "1 Corinthians", "哥林多前書": "1 Corinthians",
    "哥林多后书": "2 Corinthians", "哥林多後書": "2 Corinthians",
    "希伯来书": "Hebrews", "希伯來書": "Hebrews",
    "雅各书": "James", "雅各書": "James",
    "彼得前书": "1 Peter", "彼得前書": "1 Peter",
    "彼得后书": "2 Peter", "彼得後書": "2 Peter",
    "约翰一书": "1 John", "約翰一書": "1 John",
    "约翰二书": "2 John", "約翰二書": "2 John",
    "约翰三书": "3 John", "約翰三書": "3 John",
    "犹大书": "Jude", "猶大書": "Jude",
    "启示录": "Revelation", "啟示錄": "Revelation",
}


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

# A full reference: <book><opt-space><chapter>(:|.|：<verse>(-<verse>)?)?
# Stops at sensible boundaries to avoid eating prose.
REF_RE = re.compile(
    rf"\b({BOOK_RE})"
    rf"\.?\s*"
    rf"(\d+)"
    rf"(?:\s*[:：.]\s*(\d+)(?:\s*[-–—]\s*\d+)?)?",
)


def normalize_alias(s: str) -> str:
    return re.sub(r"[\s\.　]+", "", s.lower())


def extract_refs(text: str) -> list[str]:
    """Return canonical "Book chapter:verse" strings (deduped, in
    order of first appearance) found in [text]."""
    seen: set[str] = set()
    out: list[str] = []
    for m in REF_RE.finditer(text):
        alias_raw, chapter, verse = m.group(1), m.group(2), m.group(3)
        canon = ALIAS.get(normalize_alias(alias_raw))
        if not canon:
            continue
        try:
            ch = int(chapter)
        except ValueError:
            continue
        if ch <= 0 or ch > 200:
            continue
        if verse:
            try:
                v = int(verse)
            except ValueError:
                v = None
            key = f"{canon} {ch}:{v}" if v else f"{canon} {ch}"
        else:
            key = f"{canon} {ch}"
        if key not in seen:
            seen.add(key)
            out.append(key)
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
