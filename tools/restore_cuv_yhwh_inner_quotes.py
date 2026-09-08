#!/usr/bin/env python3
"""Put back the quotation marks our importer stripped out of
`assets/cuvs-yhwh.json`.

WHAT IS WRONG
-------------
The publisher writes quotes inside their own editorial notes and inside
quoted speech: 〔就是"得"的意思〕, 〔"我"原文是"雅伟"〕. Our import
dropped them, so the app renders `<note: 就是得的意思>` -- which reads as
a different sentence, not as a lighter one. 2,068 marks in all.

SeekSparks imported the same edition and kept them, which is the first
sign this is ours rather than the publisher's; the publisher's own
database is the second.

WHY THIS IS NOT AN EMENDATION
-----------------------------
和合本雅偉版 is frozen (`test/cuvs_yhwh_frozen_test.dart`) and is not
ours to edit. This script does not decide a reading. It re-inserts a
character the publisher wrote and we lost, and it does so ONLY where the
publisher's current text -- read out of Yahwehdehua's
`app/build/bible.db`, built from `bsapp_bible_cuvs`, the table the
edition is maintained in -- is character-for-character identical to ours
apart from those quotes.

That gate matters more here than it would elsewhere, because our copy is
roughly one editorial generation behind the publisher's: their edit log
(`bsapp_bible_cuvs_edits`) records a pre-edit state for all 31,102
verses, ours matches that pre-edit state in 23,400 of them and the
current text in 21,953. So the two texts differ for reasons that are
the publisher's business -- 哪/那, 啊/阿, 掰/擘, 吗/么, 他/她/它 --
and none of that may ride in on the back of a punctuation repair. A
verse with any other difference is skipped and reported.

BEFORE RUNNING THIS, read `docs/cuv-yhwh-publisher-notes.md`. It exists
because reasoning from the assets alone got this edition wrong twice,
confidently, with measurements.

The three markers on 主 are preserved, not normalised: our `主[基督]` /
`主[耶稣]` renderings of the publisher's `主#` / `主*` are this app's,
restored on the user's instruction on 2026-09-02, and the comparison
folds them rather than overwriting them. 使徒行傳 9:29 in particular
must not gain a marker here -- the publisher notes record that the two
sources disagree at source and that it is a question, not a repair.

Usage:  tools/restore_cuv_yhwh_inner_quotes.py [--write]
"""
import difflib
import json
import os
import re
import sqlite3
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSET = os.path.join(ROOT, 'assets', 'cuvs-yhwh.json')
DB = os.path.expanduser(
    '~/Documents/CodingProject/Yahwehdehua/app/build/bible.db')

# The only difference this pass may repair: a quotation mark the
# publisher has and we do not.
ALLOWED = {('"', ''), ('"', ''), ('"', '')}


def fold(text):
    text = re.sub(r'<note:\s*([^>]*)>',
                  lambda m: '〔' + m.group(1).strip() + '〕', text)
    return text.replace('主[耶稣]', '主*').replace('主[基督]', '主#')


def unfold(text, keep_brackets=False):
    text = text.replace('主*', '主[耶稣]').replace('主#', '主[基督]')
    if keep_brackets:
        # 路加福音 8:45 is the one verse whose 〔…〕 was never converted to
        # our note markup, and `test/ascii_punctuation_test.dart` pins
        # it that way -- `endsWith('〕')`, from the 2026-08-23 pass that
        # repaired a `)` into 〕 there. Converting it would be a second
        # change riding along on a punctuation repair, which is exactly
        # what this script is built not to do. Quotes go in; the
        # brackets stay.
        return text
    return re.sub(r'〔([^〕]*)〕',
                  lambda m: '<note: ' + m.group(1) + '>', text)


def main():
    write = '--write' in sys.argv
    con = sqlite3.connect(DB)
    seq = {code: s for s, code in con.execute('select seq, code from books')}
    pub = {'%03d%03d%03d' % (seq[b], c, v): p
           for b, c, v, p in con.execute(
               "select book, chapter, verse, plain from verses "
               "where version='cuvs'")}

    # The Traditional edition has to take the identical repair at the
    # identical positions (see mirror_inner_quotes_to_tr.py), and
    # `search_synonyms_test` requires the two scripts to stay the same
    # length verse for verse. Two verses -- 士師記 1:16 and 4:11 -- are
    # not character-aligned between the scripts, so the mirror cannot
    # place a mark in them. Repairing those in the Simplified alone
    # would leave the pair one character apart and the Traditional
    # reader without the quotes; so they are skipped in BOTH.
    trad = {r['id']: r['text'] for r in json.load(
        open(os.path.join(ROOT, 'assets', 'cuvs-yhwh-tr.json'),
             encoding='utf-8'))}

    rows = json.load(open(ASSET, encoding='utf-8'))
    repaired = marks = 0
    other = unmirrorable = 0
    for r in rows:
        theirs = pub.get(r['id'])
        if theirs is None:
            continue
        ours = fold(r['text'])
        if ours == theirs:
            continue
        deltas = [(theirs[i1:i2], ours[j1:j2]) for tag, i1, i2, j1, j2
                  in difflib.SequenceMatcher(None, theirs, ours,
                                             autojunk=False).get_opcodes()
                  if tag != 'equal']
        if deltas and all(d in ALLOWED for d in deltas):
            if len(trad.get(r['id'], '')) != len(r['text']):
                unmirrorable += 1
                print('  skipped, the two scripts are not aligned here: %s'
                      % r['id'])
                continue
            r['text'] = unfold(theirs, keep_brackets='〔' in r['text'])
            repaired += 1
            marks += sum(len(d[0]) for d in deltas)
        else:
            other += 1

    print('verses repaired: %d   quotation marks restored: %d' %
          (repaired, marks))
    print('verses left alone (they differ for other reasons too): %d' % other)
    print('verses skipped because the Traditional cannot take the same '
          'repair: %d' % unmirrorable)
    text = ''.join(r['text'] for r in rows)
    for marker in ('主[雅伟]', '主[基督]', '主[耶稣]'):
        print('  %s %d' % (marker, text.count(marker)))
    print('  verses %d' % len(rows))
    if write:
        # 2-space indent and a trailing newline: verified to round-trip
        # the untouched file byte for byte, so the diff shows the
        # repaired verses and nothing else.
        with open(ASSET, 'w', encoding='utf-8') as f:
            json.dump(rows, f, ensure_ascii=False, indent=2)
            f.write('\n')
        print('WROTE %s -- now update the pin in '
              'test/cuvs_yhwh_frozen_test.dart, and say why in the commit'
              % ASSET)
    else:
        print('(dry run; pass --write)')


if __name__ == '__main__':
    main()
