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


def fetch(lang: str, abbr: str) -> list[dict]:
    """Return parsed source data for `lang-abbr`. Caches in /tmp."""
    fname = f'{lang}-{abbr}.json'
    cached = os.path.join(CACHE_DIR, fname)
    if not os.path.exists(cached):
        os.makedirs(CACHE_DIR, exist_ok=True)
        url = f'{SRC_BASE}/{fname}'
        print(f'  fetch {url}')
        with urllib.request.urlopen(url, timeout=30) as r:
            data = r.read()
        with open(cached, 'wb') as f:
            f.write(data)
    with open(cached, encoding='utf-8') as f:
        return json.load(f)


# ── HTML → plain text helpers ────────────────────────────────────────

_CITE_RE = re.compile(r'<cite>(.*?)</cite>', re.S)
_HEBREW_RE = re.compile(r'<mark[^>]*class="hebrew"[^>]*>(.*?)</mark>', re.S)
_ANY_TAG_RE = re.compile(r'<[^>]+>')
_WHITESPACE_LINES = re.compile(r'\s*\n\s*')


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


def build_book_verses(book_data: list[dict], book_id: int,
                      book_name_cn: str, book_name_tr: str,
                      use_tr: bool) -> list[dict]:
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
        for n in ch_data.get('nodeData', []):
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
    cn_all: list[dict] = []
    tr_all: list[dict] = []
    for abbr, en, cn, tr, bid in BOOKS:
        cn_data = fetch('cn', abbr)
        tr_data = fetch('tw', abbr)
        cn_all.extend(build_book_verses(cn_data, bid, cn, tr, use_tr=False))
        tr_all.extend(build_book_verses(tr_data, bid, cn, tr, use_tr=True))

    cn_path = os.path.join(REPO_ROOT, 'assets', 'biblexg-v2.json')
    tr_path = os.path.join(REPO_ROOT, 'assets', 'biblexg-v2-tr.json')
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


if __name__ == '__main__':
    main()
