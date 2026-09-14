#!/usr/bin/env python3
"""Delete the ASCII spaces this repo's importer wedged between two
punctuation marks in 和合本雅偉版.

2026-09-14. Found while applying the 和合本 character verdicts: three
of them could not be applied because the verse was skipped, and the
verse was skipped because this edition's own two scripts disagreed on
length by exactly one character. The character was a space.

**Neither the publisher's text nor the sibling app has a single one.**
SeekSparks' copy of the same two assets: 0 in each. The publisher's
database: 0. This repo: 57 in the Simplified, 2 in the Traditional.
Deleting the space makes 41 of the 57 verses byte-for-byte identical to
SeekSparks', which is the check that says these are an import artefact
rather than anything the editor typed.

Every one of them sits between two non-Han characters — `。 ’`,
`’ ”`, `” 他`, `！ ’` — i.e. in the seam where the importer joined a
closing quotation to what follows. The rule below is deliberately
narrower than "strip spaces": a space is removed only when BOTH
neighbours are CJK text or CJK punctuation, so a space separating Latin
words or digits could never be touched. Notes are left alone entirely —
`<note: …>` markup contains spaces on purpose.

WHAT IT UNBLOCKS. `derive_tagged_traditional.py` reads the Traditional
character standing at each position of the Simplified tagged layer, so
it can only work where the two scripts are the same length; 60 verses
were skipped, and their names — 哈該書 2:3, 撒迦利亞書 1:4, 1:6 … — are
this list. The same length check is what the character-verdict applier
uses, which is how these surfaced at all.

Usage:
    tools/repair_cuv_stray_spaces.py [--write] [--repo <path>]
"""
import json
import os
import re
import sys

NOTE = re.compile(r'<note:[^>]*>')
ASSETS = ('cuvs-yhwh.json', 'cuvs-yhwh-tr.json')


def cjk(ch):
    """Han, or CJK punctuation — never Latin, never a digit."""
    o = ord(ch)
    return (0x4E00 <= o <= 0x9FFF or 0x3400 <= o <= 0x4DBF
            or 0x3000 <= o <= 0x303F        # 、。〔〕《》
            or 0xFF00 <= o <= 0xFFEF        # ，！？：；（）
            or ch in '‘’“”')


def strip_seam_spaces(text):
    """Remove ` ` between two CJK characters, outside `<note: …>`."""
    out = []
    i = 0
    removed = 0
    while i < len(text):
        m = NOTE.match(text, i)
        if m:
            out.append(m.group(0))
            i = m.end()
            continue
        ch = text[i]
        if (ch == ' ' and out and out[-1] and cjk(out[-1][-1])
                and i + 1 < len(text) and cjk(text[i + 1])):
            removed += 1
            i += 1
            continue
        out.append(ch)
        i += 1
    return ''.join(out), removed


def main():
    write = '--write' in sys.argv
    repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if '--repo' in sys.argv:
        repo = os.path.abspath(sys.argv[sys.argv.index('--repo') + 1])

    total = 0
    for name in ASSETS:
        path = os.path.join(repo, 'assets', name)
        rows = json.load(open(path, encoding='utf-8'))
        moved = 0
        verses = []
        for r in rows:
            fixed, n = strip_seam_spaces(r['text'])
            if n:
                r['text'] = fixed
                moved += n
                verses.append(r['id'])
        print('%-20s %3d spaces in %d verses' % (name, moved, len(verses)))
        if verses[:6]:
            print('    e.g. %s' % ', '.join(verses[:6]))
        total += moved
        if write and moved:
            with open(path, 'w', encoding='utf-8') as f:
                json.dump(rows, f, ensure_ascii=False, indent=2)
                f.write('\n')
            print('    WROTE %s' % path)
    if not write:
        print('(dry run; pass --write)')
    return 0 if total or not write else 0


if __name__ == '__main__':
    sys.exit(main())
