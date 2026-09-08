#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Re-derive the three script tables in `lib/constants/search_synonyms.dart`.

    python3 tools/derive_cuv_script_tables.py            # measure only
    python3 tools/derive_cuv_script_tables.py --write    # rewrite the constants

WHY THIS EXISTS
---------------
`kCuvSimplifiedChars`, `kCuvTraditionalChars` and `kCuvCommonHanChars` are
DERIVED from `assets/cuvs-yhwh.json` and `assets/cuvs-yhwh-tr.json`, and
`test/search_synonyms_test.dart` re-derives all three on every run and fails
if the constants have drifted from what the shipped scripture says. Until
2026-09-09 there was no generator: the file said "derived", the test proved
it, and the only way to MOVE the tables after an asset sync was to hand-edit
a 1,114-character string literal. This is that generator, so the claim and
the mechanism finally agree.

It writes `lib/` only. **Neither asset is opened for writing** — see
`docs/cuv-yhwh-publisher-notes.md` before going near those.

THE DERIVATION, WHICH IS THE SAME ONE THE TEST PERFORMS
-------------------------------------------------------
ASCII spaces are removed from both sides first, and then the two editions
are compared position by position over UTF-16 code units. That alignment is
not a convenience: 60 verse pairs differ in nothing but a stray space beside
a `<note:>` or a closing quote, so a raw length comparison throws them away.
Every position where the two editions differ AND both sides are Han
contributes one Simplified->Traditional observation; the forms are then
ordered by how often they occur, commoner first, which is what makes
`simplifiedToTraditional` deterministic for the Simplified characters that
stand opposite two Traditional ones.

`kCuvCommonHanChars` is the same walk one step simpler: the Han characters
occurring in more than a fifth of the Simplified edition's verses, in
descending order of how many verses hold them.

`isHanChar` is reimplemented here rather than imported, because it lives in
Dart. The three ranges below are the three that file names, and
`test/chinese_segmentation_test.dart` is what holds them to each other.
"""
import argparse
import collections
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)
SIMPLIFIED = os.path.join(PROJECT, 'assets', 'cuvs-yhwh.json')
TRADITIONAL = os.path.join(PROJECT, 'assets', 'cuvs-yhwh-tr.json')
TARGET = os.path.join(PROJECT, 'lib', 'constants', 'search_synonyms.dart')

CHUNK = 100
COMMON_THRESHOLD = 0.20


def is_han(unit):
    return (0x4E00 <= unit <= 0x9FFF or
            0x3400 <= unit <= 0x4DBF or
            0xF900 <= unit <= 0xFAFF)


def utf16_units(text):
    raw = text.encode('utf-16-le')
    return [raw[i] | (raw[i + 1] << 8) for i in range(0, len(raw), 2)]


def load(path):
    with open(path, encoding='utf-8') as handle:
        return json.load(handle)


def derive():
    s_verses = load(SIMPLIFIED)
    t_verses = load(TRADITIONAL)
    if len(s_verses) != len(t_verses):
        sys.exit('the two editions hold a different number of verses')
    for a, b in zip(s_verses, t_verses):
        if a['id'] != b['id']:
            sys.exit('the two editions do not align at %s / %s'
                     % (a['id'], b['id']))

    raw_differs = sum(
        1 for a, b in zip(s_verses, t_verses)
        if len(utf16_units(a['text'])) != len(utf16_units(b['text'])))

    simplified = [v['text'].replace(' ', '') for v in s_verses]
    traditional = [v['text'].replace(' ', '') for v in t_verses]

    counts = collections.defaultdict(collections.Counter)
    unaligned = []
    for verse, a, b in zip(s_verses, simplified, traditional):
        ua, ub = utf16_units(a), utf16_units(b)
        if len(ua) != len(ub):
            unaligned.append(verse['id'])
            continue
        for x, y in zip(ua, ub):
            if x == y or not is_han(x) or not is_han(y):
                continue
            counts[chr(x)][chr(y)] += 1

    pairs_s, pairs_t = [], []
    for src in sorted(counts):
        # Commoner Traditional form first; ties broken by code point,
        # descending, which is the order the test re-derives.
        forms = sorted(counts[src].items(),
                       key=lambda kv: (-kv[1], [-ord(c) for c in kv[0]]))
        for form, _ in forms:
            pairs_s.append(src)
            pairs_t.append(form)

    frequency = collections.Counter()
    for text in simplified:
        for char in set(text):
            if len(char) == 1 and is_han(ord(char)):
                frequency[char] += 1
    threshold = int(len(simplified) * COMMON_THRESHOLD)
    common = [c for c, n in sorted(frequency.items(), key=lambda e: -e[1])
              if n > threshold]

    return {
        'simplified': ''.join(pairs_s),
        'traditional': ''.join(pairs_t),
        'common': ''.join(common),
        'distinct': len(counts),
        'multiform': {k: dict(v) for k, v in counts.items() if len(v) > 1},
        'raw_differs': raw_differs,
        'unaligned': unaligned,
        'threshold': threshold,
        'verses': len(simplified),
        'frequency': frequency,
    }


def rewrite(source, name, value):
    start = source.index('const String %s =' % name)
    end = source.index(';', start)
    head = 'const String %s =' % name
    one_line = "%s '%s'" % (head, value)
    if len(one_line) <= 80:
        # What `dart format` would produce, so a short table does not
        # come back as a re-wrapped diff on the next run.
        replacement = one_line
    else:
        chunks = [value[i:i + CHUNK] for i in range(0, len(value), CHUNK)]
        replacement = '%s\n%s' % (
            head, '\n'.join("    '%s'" % chunk for chunk in chunks))
    return source[:start] + replacement + source[end:]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--write', action='store_true',
                    help='rewrite lib/constants/search_synonyms.dart; '
                         'without it nothing is written')
    args = ap.parse_args()

    table = derive()
    print('verses                     %d' % table['verses'])
    print('raw length differences     %d (recovered by the space strip)'
          % table['raw_differs'])
    print('unaligned after the strip  %d' % len(table['unaligned']))
    print('pairs                      %d' % len(table['simplified']))
    print('distinct Simplified        %d' % table['distinct'])
    print('two Traditional forms      %s' % table['multiform'])
    print('common threshold           %d verses' % table['threshold'])
    print('common characters          %s (%d)'
          % (table['common'], len(table['common'])))
    for char in table['common']:
        print('    %s %d' % (char, table['frequency'][char]))

    if table['unaligned']:
        sys.exit('%d verse pairs are not the same length once the spaces come '
                 'out; the derivation has no positional correspondence for '
                 'them and will not guess one: %s'
                 % (len(table['unaligned']), table['unaligned'][:10]))

    with open(TARGET, encoding='utf-8') as handle:
        source = handle.read()
    updated = rewrite(source, 'kCuvSimplifiedChars', table['simplified'])
    updated = rewrite(updated, 'kCuvTraditionalChars', table['traditional'])
    updated = rewrite(updated, 'kCuvCommonHanChars', table['common'])

    if updated == source:
        print('\nthe shipped constants already say this; nothing to write')
        return
    if not args.write:
        print('\nthe shipped constants DIFFER from the text. '
              'Re-run with --write to move them.')
        return
    with open(TARGET, 'w', encoding='utf-8') as handle:
        handle.write(updated)
    print('\nwrote %s' % os.path.relpath(TARGET, PROJECT))


if __name__ == '__main__':
    main()
