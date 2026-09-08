#!/usr/bin/env python3
"""Bring `assets/cuvs-yhwh.json` up to the publisher's current text.

WHY THIS DIRECTION IS THE SAFE ONE
----------------------------------
和合本雅偉版 is frozen because **the publisher declined OUR
corrections** (user, 2026-09-02). This pass does the opposite of what
the freeze was written to stop: it adopts THEIRS.

Our copy is roughly one editorial generation behind. The publisher's
own edit log, `bsapp_bible_cuvs_edits`, keeps a pre-edit `org_text` for
all 31,102 verses. Measured against it:

    ours == their pre-edit state    23,400 verses
    ours == their current text      21,953 verses
    SeekSparks == their current     30,834 verses  (99.1%)

They have edited 14,718 verses since that snapshot, and SeekSparks
already carries the result. 哪/那, 啊/阿, 掰/擘, 吗/么, 他/她/它 are
theirs, not ours to keep or to have changed.

WHAT IS NOT TAKEN, AND WHY
--------------------------
**The three markers on 主 are OURS and win.** `主[雅伟]` / `主[基督]` /
`主[耶稣]` render the publisher's `主[雅伟]` / `主#` / `主*`, and the
`主*` set was restored on 2026-09-02 **from git history, not from this
database** — see `docs/cuv-yhwh-publisher-notes.md`, which also records
that 使徒行傳 9:29 must NOT gain one, because the two sources disagree
at source and it is a question rather than a repair. A wholesale copy
would quietly re-decide all of that: the database has 202 `主[雅伟]`,
120 `主*` and 18 `主#` where we ship 208 / 123 / 17.

So the publisher's WORDS are taken and our MARKERS are re-applied, by
counting 主 occurrences left to right and giving occurrence *n* of the
new verse whatever occurrence *n* of ours carried. A verse whose bare-主
count differs between the two is not a mapping this can make, so it is
skipped and named.

Our house style is likewise preserved rather than overwritten: `〔…〕`
becomes `<note: …>` (except 路加福音 8:45, pinned raw by
`ascii_punctuation_test`).

The Traditional edition is NOT written here; run
`tools/mirror_inner_quotes_to_tr.py` after this, which replays these
same edits at the same character positions rather than converting
anything. But this script already enforces the pairing: a verse whose
two scripts are not the same length has no position for the mirror to
write into, so it is skipped HERE too. Moving one script and not the
other would leave the pair inconsistent and break the correspondence
`search_synonyms_test` derives from it.

Usage:  tools/sync_cuv_yhwh_to_publisher.py [--write]
"""
import json
import os
import re
import sqlite3
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSET = os.path.join(ROOT, 'assets', 'cuvs-yhwh.json')
DB = os.path.expanduser(
    '~/Documents/CodingProject/Yahwehdehua/app/build/bible.db')

MARKED = re.compile(r'主(?:\[(?:雅伟|基督|耶稣)\]|\*|#)?')


def fold(text):
    """Our rendering -> the publisher's own notation."""
    text = re.sub(r'<note:\s*([^>]*)>',
                  lambda m: '〔' + m.group(1).strip() + '〕', text)
    return text.replace('主[耶稣]', '主*').replace('主[基督]', '主#')


def unfold(text, keep_brackets=False):
    text = text.replace('主*', '主[耶稣]').replace('主#', '主[基督]')
    if keep_brackets:
        return text
    # A verse whose brackets NEST cannot be converted by this regex and
    # must not be half-converted by it. 馬太福音 17:21 is the only one:
    # its outer 〔有古卷在此有21節：…〕 contains an inner 〔或作：…〕, the
    # match closed the outer note on the inner 〕, and 。」〕 was left
    # standing outside the note as if it were scripture —
    # `stray_punctuation_test`'s "nothing is left outside a
    # wholly-editorial verse's note" is exactly this. Keeping it raw is
    # what its thirteen unnested siblings already do.
    if re.search(r'〔[^〕]*〔', text):
        return text
    converted = re.sub(r'〔([^〕]*)〕',
                       lambda m: '<note: ' + m.group(1) + '>', text)
    # A verse whose WHOLE body is the note has nothing left to annotate.
    # 84 verses read 〔见上节〕 and nothing else — the publisher's way of
    # saying this verse is covered by the previous one — and converting
    # them left the reader an empty verse behind a footnote icon.
    # `bible_version_integrity_test`'s "shows text for every verse it
    # lists" caught all 84. A footnote needs something to be a footnote
    # TO, so where there is nothing, the brackets stay and the reader
    # sees 〔见上节〕 as the verse, which is what it is.
    if re.sub(r'<note:[^>]*>', '', converted).strip() == '':
        return text
    return converted


def suffixes(text):
    """What follows each 主, in order: '[雅伟]', '*', '#' or ''."""
    return [m.group(0)[1:] for m in MARKED.finditer(text)]


def apply_suffixes(text, want):
    """Rewrite each 主's marker in `text` to the corresponding entry of
    `want`. Caller guarantees the counts match."""
    out, i = [], 0
    pos = 0
    for m in MARKED.finditer(text):
        out.append(text[pos:m.start()])
        out.append('主' + want[i])
        pos = m.end()
        i += 1
    out.append(text[pos:])
    return ''.join(out)


def main():
    write = '--write' in sys.argv
    con = sqlite3.connect(DB)
    seq = {code: s for s, code in con.execute('select seq, code from books')}
    pub = {'%03d%03d%03d' % (seq[b], c, v): p
           for b, c, v, p in con.execute(
               "select book, chapter, verse, plain from verses "
               "where version='cuvs'")}

    # The Traditional twin has to take the identical edit at the
    # identical positions. Where the two scripts are not the same
    # length there is no such position, so neither moves.
    trad = {r['id']: r['text'] for r in json.load(
        open(os.path.join(ROOT, 'assets', 'cuvs-yhwh-tr.json'),
             encoding='utf-8'))}

    rows = json.load(open(ASSET, encoding='utf-8'))
    updated = same = marker_only = skipped = unmirrorable = 0
    skips = []
    for r in rows:
        theirs = pub.get(r['id'])
        if theirs is None:
            continue
        ours = fold(r['text'])
        if ours == theirs:
            same += 1
            continue
        mine, yours = suffixes(ours), suffixes(theirs)
        if len(mine) != len(yours):
            skipped += 1
            skips.append((r['id'], r['book'], r['chapter'], r['verse'],
                          len(mine), len(yours)))
            continue
        if len(trad.get(r['id'], '')) != len(r['text']):
            unmirrorable += 1
            continue
        merged = apply_suffixes(theirs, mine)
        if merged == ours:
            # The only difference WAS the markers, and ours win.
            marker_only += 1
            continue
        r['text'] = unfold(merged, keep_brackets='〔' in r['text'])
        updated += 1

    print('already current:                  %6d' % same)
    print('updated to the publisher\'s text:  %6d' % updated)
    print('differed only in 主 markers, ours kept: %d' % marker_only)
    print('skipped, the 主 count itself differs:   %d' % skipped)
    print('skipped, the Traditional twin is not character-aligned: %d'
          % unmirrorable)
    for s in skips:
        print('    %s %s %s:%s  ours %d 主, theirs %d' % s)

    text = ''.join(r['text'] for r in rows)
    print('\nmarkers after: 主[雅伟] %d  主[基督] %d  主[耶稣] %d   verses %d'
          % (text.count('主[雅伟]'), text.count('主[基督]'),
             text.count('主[耶稣]'), len(rows)))

    if write:
        with open(ASSET, 'w', encoding='utf-8') as f:
            json.dump(rows, f, ensure_ascii=False, indent=2)
            f.write('\n')
        print('WROTE %s -- now run tools/sync_cuv_yhwh_tr.py' % ASSET)
    else:
        print('(dry run; pass --write)')


if __name__ == '__main__':
    main()
