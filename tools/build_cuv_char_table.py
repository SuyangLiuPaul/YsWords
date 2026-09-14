#!/usr/bin/env python3
"""Regenerate `kCuvSimplifiedChars` / `kCuvTraditionalChars` in
`lib/constants/search_synonyms.dart` from the two shipped editions.

The table is not a list somebody typed; it is the character
correspondence the 和合本雅偉版 pair actually shows, position by
position, over 31,102 verses. `test/search_synonyms_test.dart`
re-derives it from the assets on every run and demands an exact match,
which is the right check and also means the constant has to be rebuilt
whenever either edition changes. This is that rebuild, so it happens
by generation rather than by hand-patching a 1,100-character literal.

Derivation, identical to the test's: walk each verse pair in lockstep;
where the two scripts differ at a position and both characters are Han,
count the pair. Sort Simplified characters by code point, and each
character's Traditional forms by descending frequency (ties broken by
descending code point), so the commoner form is listed first and
`simplifiedToTraditional` is deterministic.

Usage:  tools/build_cuv_char_table.py [--write]
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DART = os.path.join(ROOT, 'lib', 'constants', 'search_synonyms.dart')
PER_LINE = 50


def is_han(ch):
    o = ord(ch)
    return 0x4E00 <= o <= 0x9FFF or 0x3400 <= o <= 0x4DBF


def load(name):
    path = os.path.join(ROOT, 'assets', name)
    return [r['text'] for r in json.load(open(path, encoding='utf-8'))]


def derive():
    simp, trad = load('cuvs-yhwh.json'), load('cuvs-yhwh-tr.json')
    assert len(simp) == len(trad)
    counts = {}
    for a, b in zip(simp, trad):
        if len(a) != len(b):
            continue
        for x, y in zip(a, b):
            if x == y or not (is_han(x) and is_han(y)):
                continue
            counts.setdefault(x, {})
            counts[x][y] = counts[x].get(y, 0) + 1
    s_out, t_out = [], []
    for s in sorted(counts):
        forms = sorted(counts[s].items(), key=lambda kv: (-kv[1], [-ord(c) for c in kv[0]]))
        for t, _ in forms:
            s_out.append(s)
            t_out.append(t)
    return ''.join(s_out), ''.join(t_out), counts


def literal(s):
    lines = [s[i:i + PER_LINE] for i in range(0, len(s), PER_LINE)]
    return '\n'.join("    '%s'" % ln for ln in lines) + ';'


def main():
    s, t, counts = derive()
    multi = {k: v for k, v in counts.items() if len(v) > 1}
    print('%d pairs, %d Simplified characters with more than one '
          'Traditional form' % (len(s), len(multi)))
    for k in sorted(multi):
        print('    %s -> %s' % (k, ', '.join(
            '%s %d' % (a, b) for a, b in
            sorted(multi[k].items(), key=lambda kv: -kv[1]))))

    if not ('--write' in sys.argv):
        print('(dry run; pass --write)')
        return

    src = open(DART, encoding='utf-8').read()
    for name, value in (('kCuvSimplifiedChars', s),
                        ('kCuvTraditionalChars', t)):
        pattern = re.compile(
            r"(const String %s =\n)(?:    '[^']*'\n)*    '[^']*';" % name)
        if not pattern.search(src):
            raise SystemExit('could not find %s to replace' % name)
        src = pattern.sub(lambda m: m.group(1) + literal(value), src, count=1)
    open(DART, 'w', encoding='utf-8').write(src)
    print('WROTE %s' % DART)


if __name__ == '__main__':
    main()
