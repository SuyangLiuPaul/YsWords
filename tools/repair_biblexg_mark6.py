#!/usr/bin/env python3
"""Restore 马可福音 6:8-11 to the Simplified 梁家铿译本.

2026-09-16, reported by the owner: 「简体梁本 MK6 v8-11 减少的」. Mark 6 had
52 verses in `assets/biblexg-v3.json` against 56 in the Traditional file
of the same translation, and verse 7 stopped mid-sentence at 「并授予他们
权能」 where the Traditional reads 「並授予他們權能制服不潔的靈。」

WHERE THE DEFECT WAS. Not in `tools/convert_ljk_v2.js`. The publisher's
own Simplified web-app data went straight from verseIndex 7 to 12, and
its verse 7 was truncated at exactly the same point; the converter
faithfully carried across a gap that was already there. It has since
been filled — 「我以为已经在json那个source已经更新了」, and that is right.

WHERE THE TEXT COMES FROM. The official 梁家鏗譯本 build in
yahwehdehua, which `tools/adopt_official_ljk.py` already treats as
authoritative 「因为那边才是正式的」, and through that script's own
`to_house_style`, so the markup travels exactly as it does in an
adoption. That script cannot do this job itself: it states that
versification is ours and that it updates the text of ids both sides
hold and ADDS NOTHING. Adding four rows is the whole point here, so it
is a named repair instead — the pattern this repo already uses for a
defect it can point at.

WHY NOT CONVERT THE TRADITIONAL FILE. A first attempt did, with a
character map learned from the two files' own aligned verses, and it
produced exactly the text below. It would still have been the wrong
thing to ship: `verse_alignment_test.dart` settled the principle for
腓立比書 1:2 — the two 梁家鏗譯本 scripts were independently revised, so
the sibling file is a witness to STRUCTURE only. Words in a translator's
mouth have to be the translator's. The sibling is used here for exactly
what that rule allows: `isParagraphStart`, `paragraphType` and
`verseLabel`, which are this app's reading layout and not the text.

Nothing is written until the official build and the shipped asset agree
on every verse of Mark 6 they both hold. They disagree on one — verse 7,
the truncated one — and that is the repair. If they ever disagree on
more, this stops: re-fetching an edition is a separate decision (see the
v2/v3 rows in `bible_versions.dart`).

PORTED TO YSWORDS, 2026-09-16. 「words那边简体梁还没有更新是吗」 — no,
and this is the same defect in a separate copy of the same asset: 52
verses against the Traditional file's 56, and verse 7 truncated at the
same point. SeekSparks was forked from this repo, so the file was
already wrong here when it was copied across; fixing the fork first was
the accident of which one the owner was reading.

`biblexg-v2` has the identical gap and is NOT touched: it is the
edition 「现有的也留着但是隐藏」 — kept and hidden — and its Traditional
text agrees with v3's on all four verses, so nothing is lost by leaving
a hidden snapshot as the snapshot it is.

Usage:
    python3 tools/repair_biblexg_mark6.py [--write]

Re-running after a write is a no-op.
"""

import json
import os
import re
import sqlite3
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools'))

DB = os.path.expanduser(
    '~/Documents/CodingProject/Yahwehdehua/app/build/bible.db')
SIMPLE = os.path.join(ROOT, 'assets', 'biblexg-v3.json')
TRAD = os.path.join(ROOT, 'assets', 'biblexg-v3-tr.json')

BOOK = '马可福音'
BOOK_TR = '馬可福音'
CHAPTER = '6'
TRUNCATED = '7'
MISSING = ['8', '9', '10', '11']

# A space between two Chinese characters. The official text marks
# editorially supplied wording `<i> 制服 </i>`, and dropping the tags —
# which is what `to_house_style` does, and right — leaves the spaces it
# was padded with. This edition has exactly zero of them across 7,921
# verses, so keeping them here would make these verses the only ones
# that read differently. Newlines are NOT touched: 70 verses carry them
# to mark the line groups of an Old Testament quotation, and
# `build_verse_content_spans` lays out on them.
CJK_SPACE = re.compile(r'([一-鿿])[ \t]+(?=[一-鿿])')


def official():
    """Mark 6 from the official build, in this repo's markup."""
    from adopt_official_ljk import to_house_style
    con = sqlite3.connect('file:%s?mode=ro' % DB, uri=True)
    rows = con.execute(
        'select verse, text from verses '
        "where version='ljks' and book='Mark' and chapter=6", ())
    return {str(v): CJK_SPACE.sub(r'\1', to_house_style(t)) for v, t in rows}


def main():
    write = '--write' in sys.argv[1:]
    if not os.path.exists(DB):
        sys.exit(f'the official build is not on this machine: {DB}')
    pub = official()
    simple = json.load(open(SIMPLE))
    trad = json.load(open(TRAD))

    here = {r['verse']: r for r in simple
            if r['book'] == BOOK and r['chapter'] == CHAPTER}
    layout = {r['verse']: r for r in trad
              if r['book'] == BOOK_TR and r['chapter'] == CHAPTER}
    if not here or not layout:
        sys.exit('this asset has no Mark 6')

    drifted = sorted((v for v, row in here.items()
                      if v in pub and v != TRUNCATED and pub[v] != row['text']),
                     key=int)
    if drifted:
        sys.exit(f'the official build and this asset disagree on '
                 f'{len(drifted)} verses of Mark 6 besides the gap: '
                 f'{drifted}. That is a re-fetch of the edition, not a '
                 'repair of it.')
    print(f'{len(here)} verses shipped, {len(pub)} official, '
          f'agreeing everywhere but the gap')

    changed = []
    out = []
    for row in simple:
        mine = row['book'] == BOOK and row['chapter'] == CHAPTER
        if mine and row['verse'] == TRUNCATED and pub[TRUNCATED] != row['text']:
            row = dict(row, text=pub[TRUNCATED])
            changed.append(f'{TRUNCATED} completed')
        out.append(row)
        if not (mine and row['verse'] == TRUNCATED):
            continue
        for verse in MISSING:
            if verse in here:
                continue
            if verse not in pub:
                sys.exit(f'the official build is still missing 6:{verse}')
            if verse not in layout:
                sys.exit(f'no layout for 6:{verse} in the Traditional file')
            shape = layout[verse]
            out.append({
                'book': BOOK,
                'chapter': CHAPTER,
                'verse': verse,
                # Layout is ours, and the sibling file already holds it.
                'verseLabel': shape['verseLabel'],
                'text': pub[verse],
                'isParagraphStart': shape['isParagraphStart'],
                'paragraphType': shape['paragraphType'],
                'id': shape['id'],
            })
            changed.append(f'{verse} restored')

    if not changed:
        print('nothing to do')
        return
    print(f'{BOOK} {CHAPTER}: ' + ', '.join(changed))
    for verse in [TRUNCATED] + MISSING:
        print(f'  {verse}: {pub[verse]}')
    if not write:
        print('\n(dry run; pass --write)')
        return
    # The asset's own formatting, so the diff is these verses and
    # nothing else.
    with open(SIMPLE, 'w') as f:
        f.write(json.dumps(out, ensure_ascii=False, indent=2) + '\n')
    print(f'written {SIMPLE} ({os.path.getsize(SIMPLE) / 1024:.0f} KB)')


if __name__ == '__main__':
    main()
