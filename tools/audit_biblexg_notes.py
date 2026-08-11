#!/usr/bin/env python3
"""Check every editorial note in 梁家鏗譯本 against the publisher's own JSON.

Why this exists
---------------
The queue carried an item reading "18 verses set an editor's gloss as
scripture in the Traditional", on the evidence that our Traditional
prints 「即葡萄酒，」 inside 馬太福音 26:29 while our Simplified marks the
same words as a note. That is the same shape as 羅馬書 16:24, where an
editor's manuscript note really had been flattened into the verse, so it
was filed as a scripture-accuracy defect.

It is not one. A diff of our two editions cannot tell "our importer lost
the markup" from "the publisher's two editions differ", and those need
opposite responses: the first is ours to fix, the second is ours to ask
about and otherwise leave alone. Only the publisher's own file can tell
them apart, because only it says whether the gloss sits in a `<cite>`.

The printed 註釋本 cannot settle it either — `pdftotext` renders a
footnote inline, indistinguishable from body text, so the extracted
volumes agree with whatever you already believed.

What it compares
----------------
For each of the 7,919/7,920 verses, the count of `<cite>` elements in the
publisher's `tw-*.json` / `cn-*.json` against the count of `<note:…>`
markers in our shipped `assets/biblexg-v2-tr.json` / `biblexg-v2.json`.

  ours < publisher  → we dropped an editorial note, and if the note was
                      inline its words are now sitting in the verse as
                      scripture. This is the defect worth finding.
  ours > publisher  → we invented one.

Result as of 2026-08-11 — 0 of either that is not accounted for below.

Known non-defects, all verified individually rather than waved through:

  • An empty `<cite></cite>`. The upstream emits these as a chapter
    placeholder; `import_ljk2.py` discards them deliberately. 4 verses.
  • A publisher node that packs several verses into one `verseIndex`
    with `<sup>n</sup>` affixes (彼得前書 3:10 holds 10-12, 以弗所書 3:15
    holds 15-16). Our importer splits them, so the note lands on the
    verse it belongs to and this tool, which keys on the publisher's
    label, looks for it on the wrong one. Checked by hand: every such
    note is present on the right verse.
  • Upstream revision since our import. The publisher has revised ~136
    verse texts, and some of those moved a cross-reference with them —
    哥林多前書 15:11, 馬太福音 7:11 / 路加福音 11:9. Adopting them is the
    open question in §四之二 of the publisher letter, not a repair.

Usage:  python3 tools/audit_biblexg_notes.py [--refresh]

Read-only. Never writes to assets/.
"""

import json
import os
import re
import sys
import urllib.request

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_BASE = 'https://mattwhatsup.github.io/ljk-nt-bible-webapp/resources'
CACHE_DIR = os.path.expanduser('~/.cache/yswords/ljk-source')

# (upstream abbreviation, simplified book name, traditional book name)
BOOKS = [
    ('mt', '马太福音', '馬太福音'),
    ('mk', '马可福音', '馬可福音'),
    ('lk', '路加福音', '路加福音'),
    ('joh', '约翰福音', '約翰福音'),
    ('act', '使徒行传', '使徒行傳'),
    ('rom', '罗马书', '羅馬書'),
    ('1co', '哥林多前书', '哥林多前書'),
    ('2co', '哥林多后书', '哥林多後書'),
    ('gal', '加拉太书', '加拉太書'),
    ('eph', '以弗所书', '以弗所書'),
    ('phi', '腓立比书', '腓立比書'),
    ('col', '歌罗西书', '歌羅西書'),
    ('1th', '帖撒罗尼迦前书', '帖撒羅尼迦前書'),
    ('2th', '帖撒罗尼迦后书', '帖撒羅尼迦後書'),
    ('1ti', '提摩太前书', '提摩太前書'),
    ('2ti', '提摩太后书', '提摩太後書'),
    ('tit', '提多书', '提多書'),
    ('phm', '腓利门书', '腓利門書'),
    ('heb', '希伯来书', '希伯來書'),
    ('jas', '雅各书', '雅各書'),
    ('1pe', '彼得前书', '彼得前書'),
    ('2pe', '彼得后书', '彼得後書'),
    ('1jo', '约翰一书', '約翰一書'),
    ('2jo', '约翰二书', '約翰二書'),
    ('3jo', '约翰三书', '約翰三書'),
    ('jud', '犹大书', '猶大書'),
    ('rev', '启示录', '啟示錄'),
]

CITE = re.compile(r'<cite>(.*?)</cite>', re.S)
NOTE = re.compile(r'<note:(.*?)>', re.S)

# Verses where our note count legitimately differs from the publisher's,
# each with the reason established by reading the node. Keyed by the
# publisher's own label, which for a packed node is not the verse the
# note ends up on.
ACCOUNTED_FOR = {
    ('tw', '哥林多前書 15:11'): 'upstream revision — adds the gloss 「福音」',
    ('tw', '彼得前書 3:10'): 'publisher packs 3:10-12 in one node; the '
                            '詩34.12-16 citation is on our 3:12',
    ('tw', '以弗所書 3:15'): 'publisher packs 3:15-16 in one node; the '
                            '參2.18註 citation is on our 3:16',
    ('tw', '馬太福音 16:3'): 'upstream labels 16:13 as verseIndex 3; the '
                            '參可8.27 citation is on our 16:13',
    ('cn', '哥林多前书 15:11'): 'upstream revision — adds the gloss 「福音」',
    ('cn', '马太福音 7:11'): 'upstream revision moved 參路11.9-13 here; ours '
                            'still carries it on 路加福音 11:9',
    ('cn', '路加福音 11:9'): 'upstream revision moved 參太7.7-8 to 馬太福音 '
                            '7:11; ours predates it',
    ('cn', '马太福音 1:16'): 'empty <cite></cite>, discarded on purpose',
    ('cn', '马太福音 23:36'): 'empty <cite></cite>, discarded on purpose',
    ('cn', '马太福音 27:50'): 'empty <cite></cite>, discarded on purpose',
    ('cn', '提摩太后书 3:3'): 'empty <cite></cite>, discarded on purpose',
}


def fetch(lang: str, abbr: str, refresh: bool) -> list:
    fname = f'{lang}-{abbr}.json'
    cached = os.path.join(CACHE_DIR, fname)
    if refresh or not os.path.exists(cached):
        os.makedirs(CACHE_DIR, exist_ok=True)
        with urllib.request.urlopen(f'{SRC_BASE}/{fname}', timeout=30) as r:
            data = r.read()
        # Netlify-style hosts answer a missing file with a 200 and HTML.
        if not data.lstrip().startswith(b'['):
            raise SystemExit(f'{fname}: not JSON — upstream served HTML?')
        with open(cached, 'wb') as f:
            f.write(data)
    with open(cached, encoding='utf-8') as f:
        return json.load(f)


def publisher_cites(chapters: list) -> dict:
    """{(chapter, verseIndex): [cite, …]} from one publisher book file."""
    out = {}
    for chap in chapters:
        chapter = None
        for node in chap.get('nodeData', []):
            if node.get('type') == 'chapter':
                chapter = str(node['chapterIndex'])
            if node.get('type') != 'verse':
                continue
            label = str(node.get('verseIndex', '')).strip()
            if not label:
                continue
            text = ''.join(
                c['content'] if isinstance(c, dict) else str(c)
                for c in node.get('contents', []))
            out.setdefault((chapter, label), []).extend(
                m.strip() for m in CITE.findall(text))
    return out


def ours(path: str) -> dict:
    with open(os.path.join(REPO_ROOT, path), encoding='utf-8') as f:
        rows = json.load(f)
    out = {}
    for row in rows:
        key = (row['book'], row['chapter'], row['verseLabel'])
        out.setdefault(key, []).extend(NOTE.findall(row.get('text', '')))
    return out


def audit(lang: str, asset: str, book_index: int, refresh: bool) -> int:
    shipped = ours(asset)
    unexplained = 0
    fewer = more = 0
    for row in BOOKS:
        abbr, name = row[0], row[book_index]
        cites = publisher_cites(fetch(lang, abbr, refresh))
        for (chapter, label), theirs in cites.items():
            mine = shipped.get((name, chapter, label))
            if mine is None:
                print(f'  MISSING VERSE  {name} {chapter}:{label}')
                unexplained += 1
                continue
            if len(mine) == len(theirs):
                continue
            ref = f'{name} {chapter}:{label}'
            reason = ACCOUNTED_FOR.get((lang, ref))
            direction = 'FEWER' if len(mine) < len(theirs) else 'MORE'
            if len(mine) < len(theirs):
                fewer += 1
            else:
                more += 1
            if reason:
                print(f'  ok  {ref}: {direction} '
                      f'({len(mine)} vs {len(theirs)}) — {reason}')
            else:
                unexplained += 1
                print(f'  ** {ref}: we have {direction} notes than the '
                      f'publisher ({len(mine)} vs {len(theirs)})')
                print(f'       publisher: {theirs}')
                print(f'       ours     : {mine}')
    print(f'  {lang}: {fewer} verses with fewer notes, {more} with more, '
          f'{unexplained} unexplained')
    return unexplained


def main() -> int:
    refresh = '--refresh' in sys.argv
    total = 0
    print('Traditional (tw-*.json → assets/biblexg-v2-tr.json)')
    total += audit('tw', 'assets/biblexg-v2-tr.json', 2, refresh)
    print()
    print('Simplified (cn-*.json → assets/biblexg-v2.json)')
    total += audit('cn', 'assets/biblexg-v2.json', 1, refresh)
    print()
    if total:
        print(f'FAIL — {total} verses where our editorial notes do not '
              f'match the publisher and no reason is on record.')
        print('An inline note we dropped is now printed as scripture. '
              'Read the publisher node before changing anything.')
        return 1
    print('OK — every editorial note in both editions matches the '
          "publisher's own file.")
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
