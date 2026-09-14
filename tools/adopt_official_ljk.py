#!/usr/bin/env python3
"""Adopt the official 梁家鏗譯本 text, both scripts, from yahwehdehua.

2026-09-14, on the owner's instruction: 「梁也要更新最新版本」, following
「因为那边才是正式的」.

WHAT MOVES. Measured before writing: of the 7,919 verses both sides hold,
7,113 already agree character for character once footnotes are compared
like with like. The ~800 that differ are almost entirely **footnotes the
official build carries and this repo's assets do not** — 馬太福音 1:16 is
the type case, where theirs continues `16节注：“基督”是希伯来语“弥赛亚”的
希腊文译音…` and ours stops at 基督。 The scripture agrees; the apparatus
was thinner on our side.

NOTATION. The official text marks a footnote `<fnote>…</fnote>`; this
repo writes `<note: …>`. That is the only rewriting done here.

WHAT IS NOT TAKEN.

  * **Versification is ours.** The official table has 7,957 rows to our
    7,922; this pass updates the text of ids both sides hold and adds
    nothing. Adding rows would change which reference a reader lands on
    and would silently rewrite every paragraph-structure field beside it.
  * **Paragraph structure is ours.** `isParagraphStart`, `paragraphType`
    and `verseLabel` are untouched — they are this app's reading layout,
    not the translator's text.
  * **Our repairs win, where they are named.** `repair_biblexg.py` and
    its siblings have already fixed defects in this text; a verse whose
    official form would undo one is kept and reported, the same rule
    `adopt_official_cuv.py` applies to the CUV's OCR damage.

Usage:
    tools/adopt_official_ljk.py [--write] [--repo <path>]
"""
import json
import os
import re
import sqlite3
import sys

DB = os.path.expanduser(
    '~/Documents/CodingProject/Yahwehdehua/app/build/bible.db')

SCRIPTS = {
    'ljks': 'biblexg-v3.json',
    'ljkt': 'biblexg-v3-tr.json',
}

FNOTE = re.compile(r'<fnote>(.*?)</fnote>', re.S)


def to_house_style(text):
    """The official markup -> this repo's.

    Three things travel differently:

      * `<fnote>…</fnote>` is this repo's `<note: …>`.
      * `<CL>` is a line break inside a poetic line group. The official
        text marks it; these assets have carried a real newline there
        since the import, and the reading pane lays out on it.
      * `<CM>` is a paragraph start. These assets carry that beside the
        text, in `isParagraphStart` / `paragraphType`, which this pass
        does not touch — so the marker is dropped rather than inlined.
        Left in, it would print `<CM>` in the middle of 馬太福音 1:6.
    """
    text = FNOTE.sub(lambda m: '<note:' + m.group(1).strip() + '>', text)
    text = text.replace('<CL>', '\n').replace('<CM>', '')
    # A poetic verse ends with a `<CL>` in the official text — the line
    # group closes there — and these assets have never carried the
    # resulting trailing newline: the pane ends the verse itself. Left
    # in, every poetic verse in the New Testament would differ from ours
    # by one invisible character, which is 356 verses of noise hiding
    # whatever real difference is among them.
    # `<i>…</i>` marks editorially supplied or disputed wording in the
    # official text. These assets have never carried it and nothing in
    # this app renders it, so it is dropped rather than inlined — printing
    # a literal `<i>` in scripture is the only thing keeping it could do.
    text = re.sub(r'</?i>', '', text)
    # U+00AD soft hyphen: a typesetting hint for a medium these assets are
    # not, and invisible wherever it lands.
    text = text.replace('\u00ad', '')
    text = re.sub(r'[ \t]+\n', '\n', text)
    return text.rstrip('\n')


def letters(text):
    """The words alone: no footnotes, no layout, no punctuation."""
    stripped = re.sub(r'<note:[^>]*>', '', text)
    return re.sub(r'[\s，。；：、！？“”‘’「」『』（）()《》〈〉—…·"\']', '',
                  stripped)


def body(text):
    """Scripture only, with every footnote removed — what a reader reads."""
    return re.sub(r'<note:[^>]*>', '', text)


def adopt(repo, version, write, notes_only_mode=False):
    asset = os.path.join(repo, 'assets', SCRIPTS[version])
    if not os.path.exists(asset):
        print('%-5s  no such asset in this repo' % version)
        return
    con = sqlite3.connect('file:%s?mode=ro' % DB, uri=True)
    seq = {code: s for s, code in con.execute('select seq, code from books')}
    pub = {}
    for b, c, v, t in con.execute(
            'select book, chapter, verse, text from verses where version=?',
            (version,)):
        pub['%02d%03d%03d' % (seq[b], c, v)] = to_house_style(t)

    rows = json.load(open(asset, encoding='utf-8'))
    same = notes_only = updated = missing = scripture = 0
    changes = []
    for r in rows:
        theirs = pub.get(r['id'])
        if theirs is None:
            missing += 1
            continue
        ours = r['text']
        if ours == theirs:
            same += 1
            continue
        if body(ours) == body(theirs):
            notes_only += 1
        elif notes_only_mode or letters(ours) != letters(theirs):
            # The WORDS differ, not the markup. This pass does not add or
            # remove scripture: 馬太福音 21:44 and 路加福音 23:34a are
            # textual-criticism decisions with repair scripts of their own
            # in this repo, and 哥林多後書 13:14 is a versification
            # question of the kind the LEB's grace benediction turned out
            # to be. Each is named here and left for a ruling.
            scripture += 1
            if len(changes) < 20:
                changes.append((r['id'], r['book'], r['chapter'], r['verse'],
                                body(ours)[:40], body(theirs)[:40]))
            continue
        r['text'] = theirs
        updated += 1

    print('%s  (%s)' % (version, SCRIPTS[version]))
    print('    already current:                 %6d' % same)
    print('    updated, footnotes only:         %6d' % notes_only)
    print('    kept ours, scripture untouched:   %6d' % scripture)
    print('    not in the official table:       %6d' % missing)
    for c in changes:
        print('        %s %s %s:%s' % c[:4])
        print('            ours  : %s' % c[4])
        print('            theirs: %s' % c[5])

    if write:
        with open(asset, 'w', encoding='utf-8') as f:
            json.dump(rows, f, ensure_ascii=False, indent=2)
            f.write('\n')
        print('    WROTE %s' % asset)


def main():
    write = '--write' in sys.argv
    # 2026-09-14: the default mode, and the one that was wanted.
    #
    # The 梁家鏗譯本 in these assets is NOT behind — it is fetched from the
    # translator's own site (mattwhatsup.github.io/ljk-nt-bible-webapp)
    # through the pipeline in `docs/LJK-UPDATE.md`, most recently today.
    # What it is missing is his APPARATUS: 1,132 footnotes here against
    # 2,209 on the official site, 644 verses annotated there and not
    # here, and the ones missing are plainly his — numbered 「16节注：…」,
    # citing ἱερόν against ναός, נצר against Nazareth, 参 SNT page
    # numbers. The v1.2.57 LJK2 import was written to ingest exactly
    # those blocks; the v3 pipeline did not carry them across.
    #
    # So the default takes footnotes and nothing else. `--with-text`
    # re-enables the wording updates, which need the nine versification
    # rulings first — see OPEN-ITEMS.
    notes_only_mode = '--with-text' not in sys.argv
    repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if '--repo' in sys.argv:
        repo = os.path.abspath(sys.argv[sys.argv.index('--repo') + 1])
    print('repo: %s' % repo)
    for version in SCRIPTS:
        adopt(repo, version, write, notes_only_mode)
    if not write:
        print('\n(dry run; pass --write)')


if __name__ == '__main__':
    main()
