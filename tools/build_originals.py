#!/usr/bin/env python3
"""Build the bundled original-language assets.

Outputs (relative to repo root):
  assets/strongs/greek.json    — Strong's Greek dictionary (~5,500 entries)
  assets/strongs/hebrew.json   — Strong's Hebrew dictionary (~8,700 entries)
  assets/originals/<book>.json — per-book Hebrew OT or Greek NT tagged with Strong's

Sources (all public domain or CC):
  - openscriptures/strongs           Strong's lexicons (JS object literal export)
  - openscriptures/morphhb           Westminster Leningrad Codex with Strong's + morph
  - eliranwong/OpenGNT               Berean Greek NT with Strong's (CSV)

Run from the repo root:
    python3 tools/build_originals.py
or with --skip-greek / --skip-hebrew to iterate on one half.

The script downloads sources to a sibling cache directory (`.cache/originals/`)
so re-runs are quick. Delete the cache to force a fresh fetch.
"""

from __future__ import annotations

import argparse
import csv
import io
import json
import os
import re
import sys
import urllib.request
import zipfile
from xml.etree import ElementTree as ET

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS_DIR = os.path.join(REPO_ROOT, 'assets')
STRONGS_DIR = os.path.join(ASSETS_DIR, 'strongs')
ORIGINALS_DIR = os.path.join(ASSETS_DIR, 'originals')
CACHE_DIR = os.path.join(REPO_ROOT, '.cache', 'originals')

UA = {'User-Agent': 'YsWords originals build script'}

# ── Sources ────────────────────────────────────────────────────────────

STRONGS_HEBREW_URL = (
    'https://raw.githubusercontent.com/openscriptures/strongs/master/'
    'hebrew/strongs-hebrew-dictionary.js'
)
STRONGS_GREEK_URL = (
    'https://raw.githubusercontent.com/openscriptures/strongs/master/'
    'greek/strongs-greek-dictionary.js'
)

# CBOL Chinese Strong's lexicon (ier1990 mirror).
# License: CC-BY-NC-SA 4.0 — original from CBOL project (bible.fhl.net).
# We bundle both the Hebrew and Greek "merged" files; entries have a
# Strong's number padded to 5 digits as the key (e.g. "02316" / "00430").
ZH_STRONGS_HEBREW_URL = (
    'https://raw.githubusercontent.com/'
    'ier1990/samekhi_china_strongs-master/master/zhrcn/zh-rcn/words/'
    'hebrew.json'
)
ZH_STRONGS_GREEK_URL = (
    'https://raw.githubusercontent.com/'
    'ier1990/samekhi_china_strongs-master/master/zhrcn/zh-rcn/words/'
    'greek.json'
)

MORPHHB_BOOKS_URL = (
    'https://raw.githubusercontent.com/openscriptures/morphhb/master/'
    'wlc/{osis}.xml'
)

# OpenGNT base text — one row per word, tab-delimited with grouped
# fields wrapped in 〔...〕 and separated by ｜. Distributed as a zip.
OPENGNT_ZIP_URL = (
    'https://github.com/eliranwong/OpenGNT/raw/master/'
    'OpenGNT_BASE_TEXT.zip'
)
OPENGNT_CSV_NAME = 'OpenGNT_version3_3.csv'

# OSIS book id → English name (matches lib/services/fetch_books.dart
# `standardBookOrder` so OriginalsService._slug() finds the file).
OSIS_HEBREW = [
    ('Gen', 'Genesis'), ('Exod', 'Exodus'), ('Lev', 'Leviticus'),
    ('Num', 'Numbers'), ('Deut', 'Deuteronomy'), ('Josh', 'Joshua'),
    ('Judg', 'Judges'), ('Ruth', 'Ruth'),
    ('1Sam', '1 Samuel'), ('2Sam', '2 Samuel'),
    ('1Kgs', '1 Kings'), ('2Kgs', '2 Kings'),
    ('1Chr', '1 Chronicles'), ('2Chr', '2 Chronicles'),
    ('Ezra', 'Ezra'), ('Neh', 'Nehemiah'), ('Esth', 'Esther'),
    ('Job', 'Job'), ('Ps', 'Psalms'), ('Prov', 'Proverbs'),
    ('Eccl', 'Ecclesiastes'), ('Song', 'Song of Solomon'),
    ('Isa', 'Isaiah'), ('Jer', 'Jeremiah'), ('Lam', 'Lamentations'),
    ('Ezek', 'Ezekiel'), ('Dan', 'Daniel'),
    ('Hos', 'Hosea'), ('Joel', 'Joel'), ('Amos', 'Amos'),
    ('Obad', 'Obadiah'), ('Jonah', 'Jonah'), ('Mic', 'Micah'),
    ('Nah', 'Nahum'), ('Hab', 'Habakkuk'), ('Zeph', 'Zephaniah'),
    ('Hag', 'Haggai'), ('Zech', 'Zechariah'), ('Mal', 'Malachi'),
]

# Mapping for OpenGNT's "Book" column → English book name.
OPENGNT_BOOK = {
    40: 'Matthew', 41: 'Mark', 42: 'Luke', 43: 'John', 44: 'Acts',
    45: 'Romans', 46: '1 Corinthians', 47: '2 Corinthians',
    48: 'Galatians', 49: 'Ephesians', 50: 'Philippians', 51: 'Colossians',
    52: '1 Thessalonians', 53: '2 Thessalonians',
    54: '1 Timothy', 55: '2 Timothy', 56: 'Titus', 57: 'Philemon',
    58: 'Hebrews', 59: 'James', 60: '1 Peter', 61: '2 Peter',
    62: '1 John', 63: '2 John', 64: '3 John', 65: 'Jude',
    66: 'Revelation',
}

NS_OSIS = '{http://www.bibletechnologies.net/2003/OSIS/namespace}'


# ── HTTP cache ─────────────────────────────────────────────────────────


def _cache_path(name: str) -> str:
    os.makedirs(CACHE_DIR, exist_ok=True)
    return os.path.join(CACHE_DIR, name)


def fetch(url: str, cache_name: str) -> bytes:
    cp = _cache_path(cache_name)
    if os.path.exists(cp):
        with open(cp, 'rb') as f:
            return f.read()
    print(f'  GET {url}')
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=60) as resp:
        data = resp.read()
    with open(cp, 'wb') as f:
        f.write(data)
    return data


# ── Strong's lexicons ──────────────────────────────────────────────────


def _parse_strongs_js(js_text: str) -> dict:
    """OpenScriptures distributes Strong's as a JSDoc comment block
    followed by `var X = {...};` and a trailing `module.exports = ...`.
    Find the object literal and parse the leading JSON, ignoring the
    trailing JS statements via raw_decode."""
    m = re.search(r'var\s+\w+\s*=\s*(\{)', js_text)
    if not m:
        raise ValueError('Could not find object literal in Strong\'s JS')
    body = js_text[m.start(1):]
    obj, _ = json.JSONDecoder().raw_decode(body)
    return obj


def _normalize_strongs_entry(num: str, raw: dict) -> dict:
    """Project openscriptures fields onto our compact shape.

    OpenScriptures splits the lexicon entry across `derivation`,
    `strongs_def`, and `kjv_def`. Greek uses `derivation` for the core
    sense; Hebrew tends to put it in `strongs_def`. We merge them so the
    UI doesn't have to know the difference.
    """
    lemma = (raw.get('lemma') or '').strip()
    translit = (raw.get('xlit') or raw.get('translit') or '').strip()
    pron = (raw.get('pron') or raw.get('pronunciation') or '').strip()

    derivation = (raw.get('derivation') or '').strip()
    strongs_def = (raw.get('strongs_def') or '').strip()
    kjv_def = (raw.get('kjv_def') or '').strip()

    # OpenScriptures splits meaning across fields with different
    # conventions per language:
    #   Greek:  derivation = "<etymology>; <core meaning>"
    #           strongs_def = figurative addition
    #   Hebrew: strongs_def = "<core meaning>"
    #           derivation = etymology only
    is_greek = num.startswith('G')
    gloss = ''
    if is_greek and ';' in derivation:
        # Greek convention: meaning lives after the first semicolon of
        # derivation (etymology before, sense after). When the trailing
        # part is empty, fall through to strongs_def.
        after = derivation.split(';', 1)[1].strip()
        if after:
            gloss = after
    if not gloss:
        gloss = strongs_def or derivation
    # Trim long glosses to the first clause for headline display.
    short = re.split(r'(?<!,) ?[;.]', gloss, maxsplit=1)[0].strip()
    if short:
        gloss = short

    parts = []
    if derivation:
        parts.append(derivation)
    if strongs_def and strongs_def != derivation:
        parts.append(strongs_def)
    if kjv_def:
        parts.append('KJV: ' + kjv_def)
    definition = ' '.join(parts).strip()

    out: dict = {'lemma': lemma, 'translit': translit, 'pron': pron,
                 'gloss': gloss, 'def': definition}
    if derivation:
        out['deriv'] = derivation
    return out


def _parse_zh_strongs_body(raw: str) -> tuple[str, str]:
    """Extract a (gloss_zh, def_zh) pair from a CBOL Chinese Strong's
    body. The body's shape is roughly:

        <num> <translit> {<pron>}
        <blank>
        <etymology>; <part of speech>; <TWOT/TDNT refs>
        <blank>
        钦定本 - <KJV usage>; <count>
        <blank>
        1) <main definition>
           1a) <sub-definition>
           ...
        2) <main definition>
           ...

    For `def_zh` we keep everything from the first numbered line to the
    end. For `gloss_zh` we take the first "1)" line — short but
    accurate; the user can read the full body for nuance.
    """
    if not raw:
        return ('', '')
    lines = raw.split('\n')
    def_start = None
    for i, ln in enumerate(lines):
        # `\s*` instead of `\s` so we catch both `1) text` and `1)text`.
        if re.match(r'^\s*\d+\)\s*\S', ln):
            def_start = i
            break
    if def_start is None:
        return ('', raw.strip())
    body = '\n'.join(lines[def_start:]).rstrip()
    # CBOL is inconsistent about the space between `1)` and the text
    # (e.g. G25 has `1)珍爱`, while G2316 has `1) 神或女神`). Accept
    # either form. Also fall back to "2)..." when "1)" is missing.
    m = re.search(r'^\s*1\)\s*(.+?)\s*$', body, re.MULTILINE)
    if not m:
        m = re.search(r'^\s*\d+\)\s*(.+?)\s*$', body, re.MULTILINE)
    gloss = m.group(1).strip() if m else ''
    return (gloss, body.strip())


def _load_zh_strongs(url: str, cache_name: str, prefix: str) -> dict[str, tuple[str, str]]:
    """Fetch a CBOL Chinese Strong's JSON file (a list of single-pair
    objects keyed by zero-padded numbers like "02316" or "07225") and
    return `{ "G2316": (gloss_zh, def_zh), ... }` keyed in our format.
    """
    raw = fetch(url, cache_name).decode('utf-8', errors='replace')
    items = json.loads(raw)
    out: dict[str, tuple[str, str]] = {}
    for entry in items:
        for key, body in entry.items():
            if not body:
                continue
            # CBOL uses 5-digit zero padding plus optional a/b suffix
            # variants. We don't differentiate variants: the leading
            # numeric portion is the canonical Strong's number.
            m = re.match(r'^0*(\d+)', key)
            if not m:
                continue
            our_key = f'{prefix}{m.group(1)}'
            # If a variant collides with the base number, prefer the
            # first non-empty body (canonical form).
            if our_key in out:
                continue
            gloss, full = _parse_zh_strongs_body(body)
            if not gloss and not full:
                continue
            out[our_key] = (gloss, full)
    return out


def build_strongs() -> None:
    print('Strong\'s lexicons:')
    he_js = fetch(STRONGS_HEBREW_URL, 'strongs-hebrew.js').decode('utf-8')
    gr_js = fetch(STRONGS_GREEK_URL, 'strongs-greek.js').decode('utf-8')
    he = _parse_strongs_js(he_js)
    gr = _parse_strongs_js(gr_js)
    out_he = {k: _normalize_strongs_entry(k, v) for k, v in he.items()}
    out_gr = {k: _normalize_strongs_entry(k, v) for k, v in gr.items()}

    # Merge in CBOL Chinese definitions where available. Keys missing
    # from the Chinese source keep only English fields, so the UI's
    # locale-fallback logic handles partial coverage gracefully.
    print('  + CBOL Chinese (CC-BY-NC-SA)')
    zh_he = _load_zh_strongs(ZH_STRONGS_HEBREW_URL, 'cbol-hebrew.json', 'H')
    zh_gr = _load_zh_strongs(ZH_STRONGS_GREEK_URL, 'cbol-greek.json', 'G')
    he_matched = 0
    for k, (gloss_zh, def_zh) in zh_he.items():
        if k in out_he:
            out_he[k]['glossZh'] = gloss_zh
            out_he[k]['defZh'] = def_zh
            he_matched += 1
    gr_matched = 0
    for k, (gloss_zh, def_zh) in zh_gr.items():
        if k in out_gr:
            out_gr[k]['glossZh'] = gloss_zh
            out_gr[k]['defZh'] = def_zh
            gr_matched += 1
    print(f'    matched {he_matched} Hebrew + {gr_matched} Greek')

    os.makedirs(STRONGS_DIR, exist_ok=True)
    with open(os.path.join(STRONGS_DIR, 'hebrew.json'), 'w',
              encoding='utf-8') as f:
        json.dump(out_he, f, ensure_ascii=False, separators=(',', ':'))
    with open(os.path.join(STRONGS_DIR, 'greek.json'), 'w',
              encoding='utf-8') as f:
        json.dump(out_gr, f, ensure_ascii=False, separators=(',', ':'))
    print(f'  wrote {len(out_he)} Hebrew + {len(out_gr)} Greek entries')


# ── Hebrew OT (morphhb / WLC) ──────────────────────────────────────────


def _hebrew_strongs(s_attr: str) -> str:
    """morphhb's @lemma can be like '7225 a' (Strong's number plus a sub
    letter, sometimes with prefix codes joined by '/'). Normalize to the
    rightmost numeric token, prefixed with H."""
    if not s_attr:
        return ''
    # Strip prefix codes joined by '/': '7225/853'
    parts = re.split(r'[\s/]+', s_attr.strip())
    for p in reversed(parts):
        m = re.match(r'(\d+)', p)
        if m:
            return 'H' + m.group(1)
    return ''


def parse_morphhb_book(osis: str) -> dict:
    raw = fetch(MORPHHB_BOOKS_URL.format(osis=osis), f'morphhb-{osis}.xml')
    root = ET.fromstring(raw)
    out: dict[str, list] = {}
    # Each <verse osisID="Gen.1.1">
    for verse in root.iter(f'{NS_OSIS}verse'):
        osis_id = verse.get('osisID') or verse.get('sID')
        if not osis_id or 'sID' in (verse.attrib or {}) and verse.get('eID'):
            # Skip milestone close tags — they only appear with eID
            pass
        if not osis_id:
            continue
        m = re.match(r'^[^.]+\.(\d+)\.(\d+)$', osis_id)
        if not m:
            continue
        ch, vs = int(m.group(1)), int(m.group(2))
        words: list[dict] = []
        for w in verse.iter(f'{NS_OSIS}w'):
            text = ''.join(w.itertext()).strip()
            if not text:
                continue
            # morphhb encodes prefix/root boundaries with `/` (e.g.
            # "בְּ/רֵאשִׁית"). Strip them so the surface form matches
            # the way the word reads in a Hebrew Bible.
            text = text.replace('/', '')
            s = _hebrew_strongs(w.get('lemma', ''))
            if not s:
                continue
            words.append({'w': text, 's': s})
        if words:
            out[f'{ch}:{vs}'] = words
    return out


def build_hebrew_ot() -> None:
    print('Hebrew OT (morphhb):')
    os.makedirs(ORIGINALS_DIR, exist_ok=True)
    for osis, english in OSIS_HEBREW:
        try:
            book_data = parse_morphhb_book(osis)
        except Exception as e:
            print(f'  skip {english} ({osis}): {e}')
            continue
        slug = english.lower().replace(' ', '_')
        path = os.path.join(ORIGINALS_DIR, f'{slug}.json')
        with open(path, 'w', encoding='utf-8') as f:
            json.dump(book_data, f, ensure_ascii=False, separators=(',', ':'))
        print(f'  wrote {english}: {len(book_data)} verses')


# ── Greek NT (OpenGNT CSV) ─────────────────────────────────────────────


def _split_grouped(field: str) -> list[str]:
    """OpenGNT groups multiple sub-fields like 〔a｜b｜c〕. Strip the
    bracket pair and split on the full-width pipe."""
    s = field.strip()
    if s.startswith('〔') and s.endswith('〕'):
        s = s[1:-1]
    return s.split('｜')


def parse_opengnt() -> dict[str, dict[str, list]]:
    """Returns {english_book: {"chap:verse": [{w,s,t}, ...]}}.

    OpenGNT v3.3 schema (tab-delimited, header row first):
      col 6  〔Book｜Chapter｜Verse〕                e.g. 〔43｜3｜16〕
      col 7  〔OGNTk｜OGNTu｜OGNTa｜lexeme｜rmac｜sn〕  accented form + Strong's
      col 9  〔transSBLcap｜transSBL｜modernGreek｜Fon〕

    We pull the accented surface form, the Strong's number, and the
    SBL transliteration.
    """
    zdata = fetch(OPENGNT_ZIP_URL, 'opengnt.zip')
    with zipfile.ZipFile(io.BytesIO(zdata)) as zf:
        with zf.open(OPENGNT_CSV_NAME) as f:
            raw = f.read().decode('utf-8', errors='replace')

    by_book: dict[str, dict[str, list]] = {}
    reader = csv.reader(io.StringIO(raw), delimiter='\t')
    header = next(reader, None)
    if not header:
        return by_book

    def _idx(want_subs: list[str]) -> int:
        for i, h in enumerate(header):
            low = h.lower()
            if all(s in low for s in want_subs):
                return i
        raise SystemExit(
            f'OpenGNT header missing column: {want_subs}; got {header}')

    bcv_col = _idx(['book', 'chapter', 'verse'])
    word_col = _idx(['ogntk', 'ogntu', 'ognta'])
    translit_col = _idx(['transsblcap', 'transsbl'])

    for row in reader:
        if not row or len(row) <= max(bcv_col, word_col, translit_col):
            continue
        bcv_parts = _split_grouped(row[bcv_col])
        if len(bcv_parts) < 3:
            continue
        try:
            book_n = int(bcv_parts[0])
            ch = int(bcv_parts[1])
            vs = int(bcv_parts[2])
        except ValueError:
            continue
        english = OPENGNT_BOOK.get(book_n)
        if not english:
            continue

        word_parts = _split_grouped(row[word_col])
        # OGNTa (accented) is index 2; sn (Strong's) is index 5.
        if len(word_parts) < 6:
            continue
        word = word_parts[2].strip()
        strongs_field = word_parts[5].strip()
        if not word:
            continue
        m = re.search(r'(\d+)', strongs_field)
        if not m:
            continue
        s_num = 'G' + m.group(1)

        translit_parts = _split_grouped(row[translit_col])
        # transSBL is index 1.
        translit = translit_parts[1].strip() if len(translit_parts) > 1 else ''

        bk = by_book.setdefault(english, {})
        verses = bk.setdefault(f'{ch}:{vs}', [])
        entry = {'w': word, 's': s_num}
        if translit:
            entry['t'] = translit
        verses.append(entry)
    return by_book


def build_greek_nt() -> None:
    print('Greek NT (OpenGNT):')
    os.makedirs(ORIGINALS_DIR, exist_ok=True)
    by_book = parse_opengnt()
    for english, book_data in by_book.items():
        slug = english.lower().replace(' ', '_')
        path = os.path.join(ORIGINALS_DIR, f'{slug}.json')
        with open(path, 'w', encoding='utf-8') as f:
            json.dump(book_data, f, ensure_ascii=False, separators=(',', ':'))
        print(f'  wrote {english}: {len(book_data)} verses')


# ── Concordance (inverted index over the bundled originals) ────────────

# Cap on how many references we keep per Strong's number. Common words
# like the Greek definite article G3588 appear ~20k times; storing every
# occurrence would balloon the bundle and overwhelm the UI. The total
# count is preserved separately so the UI can show "Used N times" even
# when only the first MAX_REFS are listed. 500 covers ~99% of Strong's
# words completely; only ~50 ultra-common particles/articles are capped.
MAX_REFS_PER_STRONGS = 500

# Canonical book ordering used to sort references within a Strong's
# entry. Matches lib/services/fetch_books.dart `standardBookOrder`.
CANONICAL_ORDER = [
    'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy',
    'Joshua', 'Judges', 'Ruth',
    '1 Samuel', '2 Samuel', '1 Kings', '2 Kings',
    '1 Chronicles', '2 Chronicles', 'Ezra', 'Nehemiah', 'Esther',
    'Job', 'Psalms', 'Proverbs', 'Ecclesiastes', 'Song of Solomon',
    'Isaiah', 'Jeremiah', 'Lamentations', 'Ezekiel', 'Daniel',
    'Hosea', 'Joel', 'Amos', 'Obadiah', 'Jonah', 'Micah',
    'Nahum', 'Habakkuk', 'Zephaniah', 'Haggai', 'Zechariah', 'Malachi',
    'Matthew', 'Mark', 'Luke', 'John', 'Acts',
    'Romans', '1 Corinthians', '2 Corinthians', 'Galatians', 'Ephesians',
    'Philippians', 'Colossians', '1 Thessalonians', '2 Thessalonians',
    '1 Timothy', '2 Timothy', 'Titus', 'Philemon',
    'Hebrews', 'James', '1 Peter', '2 Peter',
    '1 John', '2 John', '3 John', 'Jude', 'Revelation',
]
_BOOK_INDEX = {b: i for i, b in enumerate(CANONICAL_ORDER)}


def build_concordance() -> None:
    """Walk every per-book file in assets/originals/ and emit an inverted
    index keyed by Strong's number. Output: assets/strongs/concordance.json
    shaped as:
        { "G2316": {
            "n": 1320,                       # absolute count
            "r": ["Matt 1:23", ...],         # capped reference list
            "b": {"Matthew": 51, ... }       # per-book counts (uncapped)
          }, ... }

    `n` is the absolute count; `r` is the canonical-order list capped at
    MAX_REFS_PER_STRONGS. `b` lets the runtime render statistical
    distribution panels (Pauline / Johannine / per-book) without having
    to parse every ref string.
    """
    print('Concordance (inverted index):')
    if not os.path.isdir(ORIGINALS_DIR):
        print('  no originals/ directory, skipping')
        return

    counts: dict[str, int] = {}
    refs: dict[str, list[tuple[int, int, int, str]]] = {}
    # Per-Strong's per-book absolute counts: { strongs: { english_book: n } }
    by_book: dict[str, dict[str, int]] = {}

    for fname in sorted(os.listdir(ORIGINALS_DIR)):
        if not fname.endswith('.json'):
            continue
        with open(os.path.join(ORIGINALS_DIR, fname), 'r',
                  encoding='utf-8') as f:
            book_data = json.load(f)
        # Recover canonical English name from the file slug. Build a
        # reverse map once.
        slug = fname[:-5]
        # Pre-compute slug → english name for canonical ordering.
        english = next((b for b in CANONICAL_ORDER if
                        b.lower().replace(' ', '_') == slug), None)
        if not english:
            continue
        book_idx = _BOOK_INDEX[english]
        for cv, words in book_data.items():
            try:
                ch, vs = (int(p) for p in cv.split(':'))
            except ValueError:
                continue
            ref_str = f'{english} {ch}:{vs}'
            seen_in_verse: set[str] = set()
            for w in words:
                s = w.get('s')
                if not s:
                    continue
                counts[s] = counts.get(s, 0) + 1
                bbook = by_book.setdefault(s, {})
                bbook[english] = bbook.get(english, 0) + 1
                # De-dup within a single verse so the same ref doesn't
                # appear twice when a word recurs (very common for the
                # Hebrew direct-object marker H853 and Greek article).
                if s in seen_in_verse:
                    continue
                seen_in_verse.add(s)
                refs.setdefault(s, []).append((book_idx, ch, vs, ref_str))

    out: dict[str, dict] = {}
    for s, occurrences in refs.items():
        occurrences.sort()
        capped = [r[3] for r in occurrences[:MAX_REFS_PER_STRONGS]]
        out[s] = {
            'n': counts[s],
            'r': capped,
            'b': by_book.get(s, {}),
        }

    os.makedirs(STRONGS_DIR, exist_ok=True)
    path = os.path.join(STRONGS_DIR, 'concordance.json')
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(out, f, ensure_ascii=False, separators=(',', ':'))
    total_refs = sum(len(v['r']) for v in out.values())
    print(f'  wrote {len(out)} Strong\'s with {total_refs} verse refs '
          f'(capped at {MAX_REFS_PER_STRONGS} per entry) + per-book counts')


# ── CLI ────────────────────────────────────────────────────────────────


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--skip-strongs', action='store_true')
    parser.add_argument('--skip-hebrew', action='store_true')
    parser.add_argument('--skip-greek', action='store_true')
    parser.add_argument('--skip-concordance', action='store_true',
                        help='Skip rebuilding the inverted-index file.')
    args = parser.parse_args()

    if not args.skip_strongs:
        build_strongs()
    if not args.skip_hebrew:
        build_hebrew_ot()
    if not args.skip_greek:
        build_greek_nt()
    # Concordance reads from the per-book files written above, so it
    # must run last. Skip it explicitly when iterating only on a single
    # half (the existing index will be left in place).
    if not args.skip_concordance:
        build_concordance()
    print('done.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
