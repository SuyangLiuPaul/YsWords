#!/usr/bin/env python3
"""Spell out the two divine-name markers `bsb-yhwh` shipped raw.

WHAT WAS WRONG
--------------
和合本雅伟版 marks three referents on 主 and this app renders all three
in brackets: `主[雅伟]`, `主[基督]`, `主[耶稣]`. The publisher's English
edition uses the SAME three markers with the same meanings, and our
import expanded only the first of them:

    Matthew 22:44   ‘The Lord [Yahweh] said to my Lord#, "Sit at My …
    路加福音 6:46    你们为什么称呼我'主[耶稣]啊，主[耶稣]啊，'

`[Yahweh]` 199 times, and `*` and `#` left as printer's marks — so an
English reader read "the Lord's# Supper" and `"Lord*,"` while a Chinese
reader of the same verse read 主[基督] and 主[耶稣]. One verse showing
both conventions at once (Acts 2:34, Matthew 22:44) is the whole
argument: these are the same annotation, and one of them was expanded.

WHY THE MEANINGS ARE NOT GUESSED
--------------------------------
`import_ydh_texts.py` used to say `Lord*` marked "a Kyrios the edition
read as Adonai rather than YHWH". That was wrong, and the evidence
against it is the publisher's own Chinese edition at the same verse
ids: of the 111 verses carrying `Lord*`, **108 read 主[耶稣]** in
和合本雅伟版, and of the 16 carrying `Lord#`, **15 read 主[基督]**. A
marker that meant "Adonai, not YHWH" could not land on 主[耶稣] 108
times out of 111.

WHY THE MARKER IS NOT MOVED
---------------------------
`the Lord's#` becomes `the Lord's [Christ]`, not `the Lord [Christ]'s`,
even though the Chinese writes 主[基督]的. Where the annotation attaches
in an English possessive is an editorial question and this script is a
notation change; it expands in place and re-decides nothing.

WHAT THIS UNBLOCKS, AND WHY THAT IS A SIDE EFFECT
-------------------------------------------------
`TaggedTextService.carriesImporterMarkup` drops any verse whose tagged
run holds `#` — a guard against leftover `<WH7931s>` reaching a reader
as scripture. It was firing on all 16 `Lord#` verses, costing them the
word-tap line. Those verses come back, but the guard is NOT the reason
to do this and is not relaxed: the 111 `Lord*` verses never tripped it
and were showing the reader a stray asterisk just the same.

Usage:  tools/expand_bsb_yhwh_markers.py [--write]
"""
import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSET = os.path.join(ROOT, 'assets', 'bsb-yhwh.json')
TAGGED = os.path.join(ROOT, 'assets', 'tagged', 'bsb-yhwh')

# Anchored on the word the marker annotates rather than on the bare
# character: an unanchored `[*#]` would also rewrite a genuine asterisk
# if the edition ever grows one. Every one of the 139 occurrences in
# both apps' copies is one of these.
MARKER = re.compile(r'(Lord’s|Lord|LORD|Sir)([*#])')
NAMES = {'*': 'Jesus', '#': 'Christ'}


def expand(text):
    return MARKER.sub(lambda m: '%s [%s]' % (m.group(1), NAMES[m.group(2)]),
                      text)


def main():
    write = '--write' in sys.argv
    rows = json.load(open(ASSET, encoding='utf-8'))
    touched = 0
    for r in rows:
        new = expand(r['text'])
        if new != r['text']:
            r['text'] = new
            touched += 1
    print('reading asset: %d verses expanded' % touched)

    left = [r['id'] for r in rows if '*' in r['text'] or '#' in r['text']]
    print('reading asset: %d verses still carry * or #' % len(left))
    for vid in left[:10]:
        print('    %s' % vid)

    files = sorted(glob.glob(os.path.join(TAGGED, '*.json')))
    tagged_verses = tagged_runs = 0
    tagged_left = []
    out_files = []
    for path in files:
        book = json.load(open(path, encoding='utf-8'))
        changed = False
        for vid, runs in book.items():
            hit = False
            for run in runs:
                w = run.get('w')
                if not isinstance(w, str):
                    continue
                new = expand(w)
                if new != w:
                    run['w'] = new
                    tagged_runs += 1
                    hit = True
                if '*' in run.get('w', '') or '#' in run.get('w', ''):
                    tagged_left.append('%s %s' % (os.path.basename(path), vid))
            if hit:
                tagged_verses += 1
                changed = True
        if changed:
            out_files.append((path, book))
    print('tagged layer:  %d verses, %d runs expanded, in %d files'
          % (tagged_verses, tagged_runs, len(out_files)))
    print('tagged layer:  %d runs still carry * or #' % len(tagged_left))
    for s in tagged_left[:10]:
        print('    %s' % s)

    if left or tagged_left:
        raise SystemExit('REFUSING TO WRITE: a marker was left unexpanded; '
                         'widen MARKER rather than loosening the check')

    if not write:
        print('(dry run; pass --write)')
        return
    with open(ASSET, 'w', encoding='utf-8') as f:
        json.dump(rows, f, ensure_ascii=False, separators=(',', ':'))
    for path, book in out_files:
        with open(path, 'w', encoding='utf-8') as f:
            json.dump(book, f, ensure_ascii=False, separators=(',', ':'))
    print('WROTE %s and %d tagged file(s)' % (ASSET, len(out_files)))


if __name__ == '__main__':
    main()
