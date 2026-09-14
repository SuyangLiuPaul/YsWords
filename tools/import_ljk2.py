#!/usr/bin/env python3
"""
2026-05-19 (v1.2.57): regenerate assets/biblexg-v2.json (Simplified) +
assets/biblexg-v2-tr.json (Traditional) from the upstream LJK2
(梁家铿译本) source at mattwhatsup.github.io/ljk-nt-bible-webapp.

Why we re-source:
   • our existing biblexg-v2.json is a sparser extract — text + ~1,100
     simple <note:> cross-refs and nothing else
   • the upstream has the SAME translation PLUS:
       - explicit per-line lineBreak markers (poetry layout for OT
         quotations like Mt 2:6 / Mic 5:2)
       - block-level editorial comments (the "16节注：「基督」是希伯来
         语「弥赛亚」的希腊文译音…" footnote shown between Mt 1:16 + 1:17)
       - <cite> tags wrapping cross-references
       - <mark class="hebrew"> spans for inline Hebrew text

User feedback: "如果你看原版本的，LJK2 应该是有类似于 16 节注：…这些都
没有了…我说想 apply 这种 box 的". v1.2.57 ingests these so the YsWords
LJK2 reader matches the upstream's editorial richness.

Output format (matches the existing verse shape, with one addition):
    {
      "book": "马太福音",
      "chapter": "1",
      "verse": "1",
      "verseLabel": "1",
      "text": "...\\n<note:参路3.23-38>",       # \\n preserves line breaks
      "isParagraphStart": true,
      "paragraphType": "paragraph",
      "id": "40001001",
      "blockNotes": ["16节注：「基督」是…"]      # NEW — render below verse
    }

Run:
    python3 tools/import_ljk2.py
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.request

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_BASE = 'https://mattwhatsup.github.io/ljk-nt-bible-webapp/resources'
CACHE_DIR = '/tmp/ljk-source'

# Book abbreviation (upstream) → (English canonical, simplified, traditional,
# canonical book number 40–66).
BOOKS = [
    ('mt',   'Matthew',          '马太福音',       '馬太福音',       40),
    ('mk',   'Mark',             '马可福音',       '馬可福音',       41),
    ('lk',   'Luke',             '路加福音',       '路加福音',       42),
    ('joh',  'John',             '约翰福音',       '約翰福音',       43),
    ('act',  'Acts',             '使徒行传',       '使徒行傳',       44),
    ('rom',  'Romans',           '罗马书',         '羅馬書',         45),
    ('1co',  '1 Corinthians',    '哥林多前书',     '哥林多前書',     46),
    ('2co',  '2 Corinthians',    '哥林多后书',     '哥林多後書',     47),
    ('gal',  'Galatians',        '加拉太书',       '加拉太書',       48),
    ('eph',  'Ephesians',        '以弗所书',       '以弗所書',       49),
    ('phi',  'Philippians',      '腓立比书',       '腓立比書',       50),
    ('col',  'Colossians',       '歌罗西书',       '歌羅西書',       51),
    ('1th',  '1 Thessalonians',  '帖撒罗尼迦前书', '帖撒羅尼迦前書', 52),
    ('2th',  '2 Thessalonians',  '帖撒罗尼迦后书', '帖撒羅尼迦後書', 53),
    ('1ti',  '1 Timothy',        '提摩太前书',     '提摩太前書',     54),
    ('2ti',  '2 Timothy',        '提摩太后书',     '提摩太後書',     55),
    ('tit',  'Titus',            '提多书',         '提多書',         56),
    ('phm',  'Philemon',         '腓利门书',       '腓利門書',       57),
    ('heb',  'Hebrews',          '希伯来书',       '希伯來書',       58),
    ('jas',  'James',            '雅各书',         '雅各書',         59),
    ('1pe',  '1 Peter',          '彼得前书',       '彼得前書',       60),
    ('2pe',  '2 Peter',          '彼得后书',       '彼得後書',       61),
    ('1jo',  '1 John',           '约翰一书',       '約翰一書',       62),
    ('2jo',  '2 John',           '约翰二书',       '約翰二書',       63),
    ('3jo',  '3 John',           '约翰三书',       '約翰三書',       64),
    ('jud',  'Jude',             '犹大书',         '猶大書',         65),
    ('rev',  'Revelation',       '启示录',         '啟示錄',         66),
]


def fetch(lang: str, abbr: str, *, use_cache: bool = False) -> list[dict]:
    """Return parsed source data for `lang-abbr`.

    RE-DOWNLOADS by default. The cache in /tmp used to be checked
    first and never refreshed, so the second run of this tool — the
    one that exists to pick up an upstream revision — silently rebuilt
    the assets from whatever had been downloaded months earlier, and
    reported success. An update tool whose default is "use the old
    copy" is an update tool that does not update.

    `--cache` is for a debugging loop, where hammering someone else's
    GitHub Pages twenty times in a row is the rude thing to do.
    """
    fname = f'{lang}-{abbr}.json'
    cached = os.path.join(CACHE_DIR, fname)
    if use_cache and os.path.exists(cached):
        with open(cached, encoding='utf-8') as f:
            return json.load(f)
    os.makedirs(CACHE_DIR, exist_ok=True)
    url = f'{SRC_BASE}/{fname}'
    print(f'  fetch {url}')
    with urllib.request.urlopen(url, timeout=30) as r:
        data = r.read()
    with open(cached, 'wb') as f:
        f.write(data)
    return json.loads(data)


# ── HTML → plain text helpers ────────────────────────────────────────

_CITE_RE = re.compile(r'<cite>(.*?)</cite>', re.S)
_HEBREW_RE = re.compile(r'<mark[^>]*class="hebrew"[^>]*>(.*?)</mark>', re.S)
_ANY_TAG_RE = re.compile(r'<[^>]+>')
_WHITESPACE_LINES = re.compile(r'\s*\n\s*')


_INVISIBLE = {ord(c): None for c in (
    '\u00ad',   # SOFT HYPHEN
    '\u200b',   # ZERO WIDTH SPACE
    '\u200c',   # ZERO WIDTH NON-JOINER
    '\u200d',   # ZERO WIDTH JOINER
    '\ufeff',   # ZERO WIDTH NO-BREAK SPACE / BOM
)}


def html_to_inline(html: str) -> str:
    """Convert one piece of upstream HTML into a single inline string.

    • <cite>X</cite>  → <note:X>       (renders as our standard popup)
    • <mark class="hebrew"> X </mark> → unwrap (keep the Hebrew, drop the tag)
    • <mark class="greek"> X </mark>  → unwrap (keep the Greek, drop the tag)
    • any other stray tag             → strip
    • collapse interior whitespace

    Implementation note: we encode `<note:…>` as a sentinel `\\x00…\\x01`
    BEFORE the bulk `_ANY_TAG_RE.sub('', …)` pass, then decode back —
    otherwise `<note:>` would get eaten as just-another-HTML-tag (the
    regex is `<[^>]+>`, which happily eats our newly-minted note tags).
    """
    if not html:
        return ''
    s = html
    # A comment PARAGRAPH inside a verse's contents is a note, and it
    # has to become one before the tag stripper runs.
    #
    # 2026-09-14. Upstream usually gives a translator's note its own
    # `comment` NODE, which `build_book_verses` turns into `blockNotes`.
    # In nine places across five files the markup collapsed instead and
    # the note — sometimes with whole verses after it — was dumped into
    # the previous verse's `contents` as raw HTML. Stripping the tags
    # then poured 「9節註：“唱起一首新歌”，參詩33，40，96，144.9…」 into
    # the middle of 啟示錄 5:10 as if it were scripture, digits and all.
    #
    # Marked as a note here so it renders as one, and so the boundary
    # test's "no bare number inside verse text" rule keeps its teeth:
    # that rule skips `<note:…>`, and every number in this sentence is
    # a reference inside a note.
    s = re.sub(r'<p[^>]*class="comment"[^>]*>(.*?)(?:</p>|$)',
               lambda m: '<cite>' + m.group(1) + '</cite>', s, flags=re.S)
    # Pull the Hebrew / Greek content out of <mark>, keep the chars,
    # drop the wrapping element. Inline marks are sentence-level so a
    # leading + trailing space keeps them off adjacent CJK chars.
    s = re.sub(r'<mark[^>]*class="(?:hebrew|greek)"[^>]*>(.*?)</mark>',
               lambda m: f' {m.group(1).strip()} ', s, flags=re.S)
    # Stash <cite>X</cite> as a sentinel so the next pass doesn't kill
    # our new <note:…> tags. Empty <cite></cite> → fully discarded;
    # the upstream emits these as a chapter-opening placeholder and
    # they'd otherwise render as an empty `<note:>` chip.
    def _cite_repl(m):
        inner = m.group(1).strip()
        return f'\x00NOTE\x02{inner}\x01' if inner else ''
    s = _CITE_RE.sub(_cite_repl, s)
    # Strip everything else (any remaining HTML tags).
    s = _ANY_TAG_RE.sub('', s)
    # Restore the sentinel → real <note:…> tag.
    s = s.replace('\x00NOTE\x02', '<note:').replace('\x01', '>')
    # Invisible characters the upstream HTML carries.
    #
    # 2026-08-10 (#304) found three U+00AD SOFT HYPHENs in the v2
    # assets — 启示录 20:2 read 「他捉住龙<AD>，」 — and they were
    # stripped by hand, in the asset. The importer never learned, so
    # this run put all three back, in the same three verses.
    # `data_integrity_test.dart` caught it both times; the strip
    # belongs here, where a re-import cannot lose it again.
    #
    # SOFT HYPHEN renders as nothing and cannot be typed, so an exact
    # phrase search fails on text the reader can plainly see. The zero
    # widths and the BOM are the same defect in other codepoints; none
    # of the five carries meaning in Chinese scripture.
    s = s.translate(_INVISIBLE)
    s = _WHITESPACE_LINES.sub(' ', s)
    # Trim only the absolute leading / trailing whitespace; keep one
    # space at boundaries so adjacent fragments don't glue together.
    return s.strip()


def clean_block_comment(segments) -> str:
    """Block comments arrive as a list whose items are EITHER plain
    HTML strings OR dicts of shape `{lineBreak, content}` (the latter
    used by 1jo / 2jo etc. when the comment quotes another verse).
    Join + clean either form.
    """
    parts: list[str] = []
    for seg in segments:
        if isinstance(seg, str):
            parts.append(seg)
        elif isinstance(seg, dict):
            parts.append(str(seg.get('content', '')))
    raw = ' '.join(parts)
    # Hebrew + Greek inline marks: keep the content, drop the tag.
    s = re.sub(r'<mark[^>]*class="(?:hebrew|greek)"[^>]*>(.*?)</mark>',
               lambda m: f' {m.group(1).strip()} ', raw, flags=re.S)
    # Any remaining tags: strip.
    s = _ANY_TAG_RE.sub('', s)
    s = re.sub(r'\s+', ' ', s).strip()
    return s


# ── Verse assembly ───────────────────────────────────────────────────

def assemble_verse_text(contents: list[dict]) -> str:
    """Build a single text string from the upstream `contents` array.

    `lineBreak` semantics in the upstream:
        • 'inline'  → no break, glue to previous fragment with a space
        • 'line'    → render on a new line in poetry mode (we keep '\\n')
    """
    parts: list[str] = []
    for i, c in enumerate(contents):
        chunk = html_to_inline(c.get('content', ''))
        if not chunk:
            # An empty content with lineBreak='line' is the upstream's
            # way of saying "newline here" — emit a literal newline.
            if c.get('lineBreak') == 'line':
                if parts and not parts[-1].endswith('\n'):
                    parts.append('\n')
            continue
        # Default sep is a single space; a 'line' break before this
        # chunk swaps to '\n'.
        if parts and not parts[-1].endswith(('\n', ' ')):
            sep = '\n' if c.get('lineBreak') == 'line' else ''
            if sep:
                parts.append(sep)
        parts.append(chunk)
    out = ''.join(parts)
    # Squash 3+ consecutive newlines to 2 (a single empty line is OK).
    out = re.sub(r'\n{3,}', '\n\n', out)
    return out.strip()



# ── Upstream numbering defects, repaired by hand and counted ────────
#
# 2026-09-14. Before importing a revision, the whole source was checked
# against canonical versification. Two kinds of discrepancy came back
# and they must not be treated alike:
#
# **The translation's own editorial choice — LEFT ALONE.** Mt 17:21,
# 18:11, 23:14; Mk 11:26, 15:28; Lk 17:36, 22:43-44, 23:17; Jn 5:4;
# Acts 8:37, 15:34, 24:7, 28:29 are absent from the running text, and
# 3 John 15 and Rev 12:18 are present. That is exactly the critical
# text (NA28/UBS5), applied consistently, with the manuscript variants
# explained in the notes. A "repair" that filled those gaps would be
# overruling the translator.
#
# **Numbering defects — repaired.** Four places where the markup, not
# the translation, is wrong. Each was read against the text before
# being written down; none is a guess, and none invents or drops a
# word of scripture.
#
# One thing is NOT repaired because it cannot be: `cn-mk.json` is
# MISSING Mark 6:8-11 outright — four verses of scripture that the
# traditional file has and the simplified one does not. There is
# nothing to renumber; the text is not in the file. Inventing it from
# the traditional text would be a conversion presented as a source, so
# the gap stands and `main()` reports it every run.
# The verses this translation deliberately does NOT print, because it
# follows the critical text (NA28/UBS5) and explains each in a note.
# Keyed by our own verse id, BBCCCVVV.
#
# They are listed so that CARRY-FORWARD can skip them. The May snapshot
# of the upstream still had them, so filling every id the new import
# lacks would quietly put them back — which is not restoring a lost
# verse, it is overruling the translator.
# Checked one by one against the source rather than assumed from the
# list of "verses the critical text omits". THE LIST IS NOT THAT LIST:
# Lk 22:43-44, 23:17, Jn 5:4 and Acts 15:34 are PRESENT upstream —
# printed inside the preceding verse with their numbers inline, e.g.
# Luke 22:42's text ends 「…成就你的旨意。”43有一位使者從天上向他顯現…」.
# `tools/repair_biblexg.py` splits those back out; treating them as
# omissions here would have carried the May snapshot's copies forward on
# top of the split ones, or worse, left them out entirely.
CRITICAL_TEXT_OMISSIONS = {
    '40017021', '40018011', '40023014',   # Mt 17:21, 18:11, 23:14
    '41011026', '41015028',               # Mk 11:26, 15:28
    '42017036',                           # Lk 17:36
    '44008037',                           # Acts 8:37 — in a note, not the text
    '44024007', '44028029',               # Acts 24:7, 28:29
    '47013014',                           # 2 Cor 13:14 (NA28 ends at 13)
}

# Boundary repairs are NOT done here. `tools/repair_biblexg.py` already
# holds eight of them, each written up with what a reader loses if it is
# wrong, and `test/biblexg_verse_boundary_test.dart` pins its answers.
# This importer briefly grew its own set and got one of them different —
# it put 「如經上所記：」 at the end of Acts 15:15 on the Greek's
# versification, where the shipped edition (and the publisher's own
# numbering, which labels both halves 16) puts it at the start of 15:16.
# Two layers repairing the same file is how those answers drift apart.
# Run the repair script after this one; see the header.
REPAIRS: dict[tuple[str, str, int], str] = {}


def repair_chapter(lang: str, abbr: str, chapter: int,
                   nodes: list[dict], log: list[str]) -> list[dict]:
    """A no-op, deliberately.

    This function used to drop empty verse nodes and fix four numbering
    defects. Both jobs belong to `tools/repair_biblexg.py`, and doing
    them here BROKE that script: its first repair identifies Matthew
    16:13 by the pair the converter leaves behind — an empty record `1`
    and a record `3` carrying the text — and this importer had already
    thrown the empty one away, so the repair could not recognise the
    pair and refused to write the file at all.

    The importer's job is a faithful conversion. The repairs are a
    separate, reviewed pass with its own tests. Kept as a hook, and as
    the record of why it is empty.
    """
    return nodes


def verse_text_of(node: dict) -> str:
    """Just the words, for the empty-node check above."""
    parts = []
    for c in node.get('contents') or []:
        if isinstance(c, dict):
            parts.append(_ANY_TAG_RE.sub('', c.get('content', '') or ''))
    return ''.join(parts)


def build_book_verses(book_data: list[dict], book_id: int,
                      book_name_cn: str, book_name_tr: str,
                      use_tr: bool, *, lang: str = '', abbr: str = '',
                      log: list[str] | None = None) -> list[dict]:
    """Walk one upstream-book file, return our verse-format list.

    Comments encountered between verses are attached to the
    IMMEDIATELY PRECEDING verse via `blockNotes`. If a comment
    appears before any verse in a chapter (rare; ~1 known case),
    we attach to the FIRST verse of that chapter so it doesn't
    silently drop.
    """
    out: list[dict] = []
    book_name = book_name_tr if use_tr else book_name_cn
    chapter = 0
    pending_comments: list[str] = []
    for ch_data in book_data:
        nodes = ch_data.get('nodeData', [])
        # Which chapter this block is, BEFORE walking it — the repairs
        # below are addressed to a chapter by number.
        ch_no = next((int(n.get('chapterIndex', '0'))
                      for n in nodes if n.get('type') == 'chapter'), 0)
        nodes = repair_chapter(lang, abbr, ch_no, list(nodes),
                               log if log is not None else [])
        for n in nodes:
            t = n.get('type')
            if t == 'chapter':
                chapter = int(n.get('chapterIndex', '0'))
            elif t == 'verse':
                verse_label = n.get('verseIndex', '0')
                verse_num = int(re.match(r'\d+', verse_label).group(0)
                                if re.match(r'\d+', verse_label) else 0)
                if verse_num == 0:
                    continue
                paragraph = n.get('paragraph', 'paragraph')
                is_para_start = paragraph in ('paragraph', 'reference')
                # 'paragraph' marker → normal new-paragraph verse
                # 'reference'        → OT quotation block (poetry)
                # 'inline'           → continues the current paragraph
                if paragraph == 'reference':
                    paragraph_type = 'reference'
                else:
                    paragraph_type = 'paragraph'
                text = assemble_verse_text(n.get('contents', []))
                verse_id = f'{book_id:02d}{chapter:03d}{verse_num:03d}'
                v = {
                    'book': book_name,
                    'chapter': str(chapter),
                    'verse': str(verse_num),
                    'verseLabel': verse_label,
                    'text': text,
                    'isParagraphStart': is_para_start,
                    'paragraphType': paragraph_type,
                    'id': verse_id,
                }
                # Drain any pending block comments (rare orphaned case)
                # onto this verse, then leave the pending list for the
                # next comment to attach to THIS verse.
                if pending_comments:
                    v['blockNotes'] = pending_comments
                    pending_comments = []
                out.append(v)
            elif t == 'comment':
                contents = n.get('contents', [])
                if isinstance(contents, list):
                    cleaned = clean_block_comment(contents)
                else:
                    cleaned = clean_block_comment([str(contents)])
                if not cleaned:
                    continue
                if out:
                    out[-1].setdefault('blockNotes', []).append(cleaned)
                else:
                    pending_comments.append(cleaned)
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--code', default='biblexg-v3',
                    help='version code to write: assets/<code>.json and '
                         'assets/<code>-tr.json (default: biblexg-v3)')
    ap.add_argument('--cache', action='store_true',
                    help='reuse the /tmp copy instead of re-downloading — '
                         'for a debugging loop, never for an update')
    ap.add_argument('--force', action='store_true',
                    help='overwrite assets that already exist')
    args = ap.parse_args()

    cn_path = os.path.join(REPO_ROOT, 'assets', f'{args.code}.json')
    tr_path = os.path.join(REPO_ROOT, 'assets', f'{args.code}-tr.json')
    # A previous edition is EVIDENCE, not a scratch file: the app keeps
    # the one it replaced so old links and old readers still resolve.
    for path in (cn_path, tr_path):
        if os.path.exists(path) and not args.force:
            print(f'REFUSING: {os.path.relpath(path, REPO_ROOT)} exists. '
                  f'Pass --code for a new edition, or --force to replace '
                  f'this one in place.', file=sys.stderr)
            return 1

    cn_all: list[dict] = []
    tr_all: list[dict] = []
    repair_log: list[str] = []
    for abbr, en, cn, tr, bid in BOOKS:
        cn_data = fetch('cn', abbr, use_cache=args.cache)
        tr_data = fetch('tw', abbr, use_cache=args.cache)
        cn_all.extend(build_book_verses(cn_data, bid, cn, tr, use_tr=False,
                                        lang='cn', abbr=abbr, log=repair_log))
        tr_all.extend(build_book_verses(tr_data, bid, cn, tr, use_tr=True,
                                        lang='tw', abbr=abbr, log=repair_log))

    with open(cn_path, 'w', encoding='utf-8') as f:
        json.dump(cn_all, f, ensure_ascii=False, separators=(',', ':'))
    with open(tr_path, 'w', encoding='utf-8') as f:
        json.dump(tr_all, f, ensure_ascii=False, separators=(',', ':'))

    print()
    print(f'  CN: wrote {len(cn_all)} verses to {cn_path}')
    print(f'  TR: wrote {len(tr_all)} verses to {tr_path}')
    # Quick sanity numbers
    cn_with_blocknotes = sum(1 for v in cn_all if 'blockNotes' in v)
    cn_with_newlines = sum(1 for v in cn_all if '\n' in v['text'])
    cn_with_notes = sum(1 for v in cn_all if '<note:' in v['text'])
    print(f'  CN: {cn_with_blocknotes} verses with block notes, '
          f'{cn_with_newlines} with line breaks, {cn_with_notes} with '
          f'inline <note:> cross-refs')

    # Every repair, every run. A silent repair is a fork of the source
    # that nobody can audit later.
    print()
    print(f'  repairs applied here ({len(repair_log)}) — boundary repairs '
          f'are a separate pass, see below:')
    for line in repair_log:
        print(line)

    print()
    print('  NEXT, in this order:')
    print(f'    tools/repair_biblexg.py --code {args.code} --write')
    print(f'    tools/repair_verse_numbering.py --code {args.code}')
    print(f'    tools/repair_biblexg_v2_tr.py --code {args.code}-tr')
    print(f'    tools/carry_forward_ljk.py --code {args.code} '
          f'--from biblexg-v2 --write')
    print('  Order matters, and each step is here because leaving it out'
          ' shipped a defect:')
    print('    2. repair_biblexg SPLITS verses the converter merged into'
          ' one row.')
    print('    3. repair_verse_numbering RE-KEYS rows numbered by the'
          " edition's own versification rather than by the English"
          ' reference the app looks up by. Skipped once on the v3 run:'
          ' the grace benediction went back to answering 2 Corinthians'
          ' 13:13, and Acts 8:41 — a reference no English tradition has,'
          ' so nothing in the app can reach it — came back.')
    print('    4. repair_biblexg_v2_tr fixes the 30 characters the'
          " publisher's own 繁體 conversion got wrong — 會堂里 for 會堂裡,"
          ' 準許 for 准許, 顫斗 for 顫抖. Every site is named; a site the'
          ' publisher has since fixed retires itself, and a site that'
          ' moved fails loudly.')
    print('    5. carry_forward runs LAST and fills only what is STILL'
          ' missing, or it fills it with the older snapshot\'s wording'
          ' instead of the text this run just fetched.')

    # And the one thing that cannot be repaired, said every time so it
    # cannot rot into folklore: the SIMPLIFIED upstream file is missing
    # Mark 6:8-11. The traditional file has them. Nothing here invents
    # them — a simplified rendering generated from the traditional text
    # would be a conversion presented as a source.
    cn_mk6 = {v['verseLabel'] for v in cn_all
              if v['id'][:5] == '41006'}
    absent = [n for n in ('8', '9', '10', '11') if n not in cn_mk6]
    if absent:
        print()
        print(f'  !! UPSTREAM GAP: cn-mk.json has no Mark 6:{",".join(absent)}'
              f' — present in tw-mk.json. Report it upstream; do not'
              f' fabricate it here.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
