#!/usr/bin/env python3
"""Mirror the Simplified quote restoration into the Traditional edition
at the same character positions.

`restore_cuv_yhwh_inner_quotes.py` put back 1,144 quotation marks the
importer had dropped from `assets/cuvs-yhwh.json`. The Traditional file
lost the same marks in the same places -- both were imported by the same
code from the same edition -- and repairing one alone would leave a
reader who switches script losing the quotes again, and
`test/ascii_punctuation_test.dart` counting two different numbers for
what it calls one convention.

This asks no witness. The two files are one edition in two scripts, so a
missing quote at index 37 of the Simplified verse is the same missing
quote at index 37 of the Traditional one; the correspondence IS the
evidence. It replays the exact edit script -- computed by diffing the
pre-repair Simplified out of git against the repaired one -- onto the
Traditional text, and refuses any verse where the two are not actually
the same length, rather than guessing. 495 of the 497 align; the two
that do not are reported and left alone.

Usage:  tools/mirror_inner_quotes_to_tr.py [--write]
"""
import difflib
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIMP = os.path.join(ROOT, 'assets', 'cuvs-yhwh.json')
TRAD = os.path.join(ROOT, 'assets', 'cuvs-yhwh-tr.json')


def main():
    write = '--write' in sys.argv
    before = {r['id']: r['text'] for r in json.loads(subprocess.check_output(
        ['git', 'show', 'HEAD:assets/cuvs-yhwh.json'], cwd=ROOT
    ).decode('utf-8'))}
    after = {r['id']: r['text']
             for r in json.load(open(SIMP, encoding='utf-8'))}

    rows = json.load(open(TRAD, encoding='utf-8'))
    mirrored = misaligned = marks = 0
    for r in rows:
        old, new = before.get(r['id']), after.get(r['id'])
        if old is None or new is None or old == new:
            continue
        trad = r['text']
        if len(trad) != len(old):
            misaligned += 1
            print('  NOT ALIGNED %s  simplified %d chars, traditional %d'
                  % (r['id'], len(old), len(trad)))
            continue
        out = []
        for tag, i1, i2, j1, j2 in difflib.SequenceMatcher(
                None, old, new, autojunk=False).get_opcodes():
            if tag == 'equal':
                out.append(trad[i1:i2])
            elif tag == 'delete':
                pass
            else:
                # insert / replace: the marks are script-neutral, so the
                # Simplified's new text is also the Traditional's.
                out.append(new[j1:j2])
                marks += len(new[j1:j2])
        r['text'] = ''.join(out)
        mirrored += 1

    print('verses mirrored: %d   marks: %d' % (mirrored, marks))
    print('verses skipped, not character-aligned: %d' % misaligned)
    if write:
        with open(TRAD, 'w', encoding='utf-8') as f:
            json.dump(rows, f, ensure_ascii=False, indent=2)
            f.write('\n')
        print('WROTE %s -- re-pin the hash in cuvs_yhwh_frozen_test.dart'
              % TRAD)
    else:
        print('(dry run; pass --write)')


if __name__ == '__main__':
    main()
