#!/usr/bin/env python3
"""Proofread the bundled 梁家鏗譯本 against the publisher's own text.

WHY THIS EXISTS
---------------
biblexg.com links to https://mattwhatsup.github.io/ljk-nt-bible-webapp/
as its reader, and that app precaches its text as `resources/cn-*.json`.
There are 60 such files and **no `tr-*` ones** — the publisher ships
SIMPLIFIED ONLY. Our Traditional edition is therefore a conversion, and
the Simplified is the side that can be checked against an authority.

That ordering matters, and getting it backwards produced a wrong report
once already. 約翰一書 4:16 was written up as "the Simplified is missing
「神就是愛…」" — but the publisher's own text at 4:16 is exactly what our
Simplified has. It is the TRADITIONAL that carries text the translation
does not have there. Check the source before believing a diff.

WHAT IT FOUND (2026-08-10, first run)
-------------------------------------
4,826 comparable verses: 4,731 identical after markup is stripped (98%),
**95 genuinely different in wording** (2%). The differences read as a
later revision by the publisher rather than as damage —
以弗所書 2:4 is "神富有愛憐，出於他愛我們的大愛" upstream against our
"神滿有憐憫，因著他愛我們的大愛". We ship an earlier revision.

USAGE
-----
    python3 tools/proofread_biblexg.py --fetch      # refresh the source
    python3 tools/proofread_biblexg.py              # report differences
    python3 tools/proofread_biblexg.py --book eph   # one book
    python3 tools/proofread_biblexg.py --json out.json

It NEVER writes to assets/. Applying a revision is a separate, reviewed
step — this tool's job is to say precisely what differs.
"""
import argparse
import glob
import json
import os
import re
import sys
import urllib.request

BASE = 'https://mattwhatsup.github.io/ljk-nt-bible-webapp/resources'
CACHE = os.path.expanduser('~/.cache/yswords/ljk-source')

# The publisher's file codes → the book names our assets use.
CODE2BOOK = {
    'mat': '马太福音', 'mar': '马可福音', 'luk': '路加福音', 'joh': '约翰福音',
    'act': '使徒行传', 'rom': '罗马书', '1co': '哥林多前书', '2co': '哥林多后书',
    'gal': '加拉太书', 'eph': '以弗所书', 'php': '腓立比书', 'col': '歌罗西书',
    '1th': '帖撒罗尼迦前书', '2th': '帖撒罗尼迦后书', '1ti': '提摩太前书',
    '2ti': '提摩太后书', 'tit': '提多书', 'phm': '腓利门书', 'heb': '希伯来书',
    'jam': '雅各书', '1pe': '彼得前书', '2pe': '彼得后书', '1jo': '约翰一书',
    '2jo': '约翰二书', '3jo': '约翰三书', 'jud': '犹大书', 'rev': '启示录',
}


def fetch(force=False):
    os.makedirs(CACHE, exist_ok=True)
    for code in CODE2BOOK:
        dest = os.path.join(CACHE, f'cn-{code}.json')
        if os.path.exists(dest) and not force:
            continue
        try:
            with urllib.request.urlopen(f'{BASE}/cn-{code}.json', timeout=45) as r:
                open(dest, 'wb').write(r.read())
            print(f'  fetched {code}', file=sys.stderr)
        except Exception as e:  # a missing book is not fatal
            print(f'  {code}: {e}', file=sys.stderr)


def official():
    """(book, chapter, verse) -> text, from the publisher's files.

    Their verse ids are sometimes RANGES ("20-21") where one record
    covers two verses. Those are keyed on the first number and the
    second is recorded as covered, so a range is never mistaken for a
    missing verse.
    """
    out, covered = {}, set()
    for path in sorted(glob.glob(os.path.join(CACHE, 'cn-*.json'))):
        book = CODE2BOOK.get(os.path.basename(path)[3:-5])
        if not book:
            continue
        for chapter in json.load(open(path, encoding='utf-8')):
            cur = None
            for node in chapter.get('nodeData', []):
                if node.get('type') == 'chapter':
                    cur = str(node.get('chapterIndex'))
                elif node.get('type') == 'verse' and cur:
                    v = str(node.get('verseIndex'))
                    text = ''.join(c.get('content', '')
                                   for c in node.get('contents', []))
                    if '-' in v:
                        first, last = v.split('-', 1)
                        out[(book, cur, first)] = text
                        covered.add((book, cur, last))
                    else:
                        out[(book, cur, v)] = text
    return out, covered


def norm(s):
    """Compare meaning, not markup.

    Our assets annotate with `<note:…>`; the publisher uses `<cite>…`
    and the odd `<span>`. Leaving those in reported 843 differences
    where there were 95 — the first count this tool produced was wrong
    for exactly that reason.
    """
    s = re.sub(r'<note:[^>]*>', '', s)
    s = re.sub(r'<cite>.*?</cite>', '', s, flags=re.S)
    s = re.sub(r'<[^>]+>', '', s)
    return re.sub(r'[\s　]+', '', s)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--fetch', action='store_true', help='refresh the source')
    ap.add_argument('--book', help='one book code, e.g. eph')
    ap.add_argument('--json', help='write the differences to a file')
    ap.add_argument('--assets', default='assets/biblexg-v2.json')
    args = ap.parse_args()

    if args.fetch or not glob.glob(os.path.join(CACHE, 'cn-*.json')):
        fetch(force=args.fetch)

    src, covered = official()
    if args.book:
        want = CODE2BOOK.get(args.book)
        if not want:
            sys.exit(f'unknown book code: {args.book}')
        src = {k: v for k, v in src.items() if k[0] == want}

    ours = {(v['book'], str(v['chapter']), str(v['verse'])): v['text']
            for v in json.load(open(args.assets, encoding='utf-8'))}

    common = [k for k in set(src) & set(ours)]
    diff = [k for k in common if norm(src[k]) != norm(ours[k])]
    missing = [k for k in set(src) - set(ours) if k not in covered]

    print(f'comparable verses : {len(common):,}')
    print(f'identical         : {len(common) - len(diff):,} '
          f'({(len(common)-len(diff))*100//max(len(common),1)}%)')
    print(f'wording differs   : {len(diff):,}')
    print(f'absent from ours  : {len(missing):,}')
    print()
    for k in sorted(diff):
        print(f'{k[0]} {k[1]}:{k[2]}')
        print(f'  publisher: {norm(src[k])}')
        print(f'  ours     : {norm(ours[k])}')
        print()

    if args.json:
        json.dump(
            [{'book': k[0], 'chapter': k[1], 'verse': k[2],
              'publisher': src[k], 'ours': ours[k]} for k in sorted(diff)],
            open(args.json, 'w', encoding='utf-8'),
            ensure_ascii=False, indent=1)
        print(f'wrote {args.json}', file=sys.stderr)

    # Differences are information, not failure — this is a report, and
    # the decision to adopt a revision belongs to a human.
    return 0


if __name__ == '__main__':
    sys.exit(main())
