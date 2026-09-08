#!/usr/bin/env python3
"""Put back the comma that went with the reverent space.

THE CONVENTION, AND THE BUG IN IT
---------------------------------
The 和合本 prints a reverent space before 神 — 「起初，　神創造天地。」
— and this edition does not: 和合本雅偉版 drops U+3000 throughout, which
is the publisher's own house style and not ours to restore.

Dropping it took a comma with it in **16 verses**. The official edition
(git blob 7a2dc43, the plain 耶和華 text) writes 「，　神」 in 180 verses;
164 of ours keep the comma and drop only the space, which is the
convention working. These 16 dropped both, and 創世記 1:1 now opens

    起初神创造天地。

against the official's 起初，　神創造天地。 That is not a house style, it
is a clause that lost its break — and the 164 against 16 is what says
so, because a convention applied 180 times does not change its mind
sixteen of them.

HOW A POSITION IS FOUND
-----------------------
Aligned against the witness. Where the witness has 「，　」 immediately
before 神 and our verse has NEITHER character at that position, the
comma is restored and the space is not. Anything else — the comma
already there, the space present, a verse that will not align — is left
alone and counted.

Both scripts take the edit at the same index; the sync guarantees they
are the same length, and a verse where they are not is skipped.

Usage:  tools/restore_comma_before_the_name.py [--write]
"""
import difflib
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIMP = os.path.join(ROOT, 'assets', 'cuvs-yhwh.json')
TRAD = os.path.join(ROOT, 'assets', 'cuvs-yhwh-tr.json')
WITNESS_BLOB = '7a2dc43'
LOST = '，　'


def witness():
    return {r['id']: r['text'] for r in json.loads(subprocess.check_output(
        ['git', 'cat-file', '-p', WITNESS_BLOB], cwd=ROOT).decode('utf-8'))}


def main():
    write = '--write' in sys.argv
    w = witness()
    simp_rows = json.load(open(SIMP, encoding='utf-8'))
    trad_rows = json.load(open(TRAD, encoding='utf-8'))
    simp = {r['id']: r for r in simp_rows}

    before_space = (sum(r['text'].count('　') for r in simp_rows),
                    sum(r['text'].count('　') for r in trad_rows))
    restored = 0
    kept = 0
    examples = []
    for r in trad_rows:
        theirs = w.get(r['id'])
        s = simp.get(r['id'])
        if theirs is None or s is None or len(s['text']) != len(r['text']):
            continue
        if LOST not in theirs:
            continue
        ours = r['text']
        out_t, out_s = [], []
        hit = False
        for tag, i1, i2, j1, j2 in difflib.SequenceMatcher(
                None, ours, theirs, autojunk=False).get_opcodes():
            if tag == 'equal' or tag == 'replace':
                out_t.append(ours[i1:i2])
                out_s.append(s['text'][i1:i2])
            elif tag == 'delete':
                out_t.append(ours[i1:i2])
                out_s.append(s['text'][i1:i2])
            elif tag == 'insert':
                gained = theirs[j1:j2]
                # The whole of what is missing here is 「，　」 and the
                # next character in their text is 神. Restore the comma
                # only: the space is this edition's to drop.
                if gained == LOST and theirs[j2:j2 + 1] == '神':
                    out_t.append('，')
                    out_s.append('，')
                    hit = True
                elif gained == LOST:
                    kept += 1
        if hit:
            r['text'] = ''.join(out_t)
            s['text'] = ''.join(out_s)
            restored += 1
            if len(examples) < 20:
                examples.append('%s  %s' % (r['id'], s['text'][:34]))

    print('verses given their comma back: %d' % restored)
    print('「，　」 the witness has and we drop for other reasons: %d' % kept)
    for e in examples:
        print('    %s' % e)

    # The space itself must NOT have arrived. Compared against the count
    # this run started with rather than against zero: the Simplified
    # already holds one U+3000, in 詩篇 76:1's psalm heading, which has
    # nothing to do with the reverent space and is not this tool's to
    # remove.
    for rows, name, was in ((simp_rows, 'Simplified', before_space[0]),
                            (trad_rows, 'Traditional', before_space[1])):
        n = sum(r['text'].count('　') for r in rows)
        print('U+3000 in the %s: %d (was %d)' % (name, n, was))
        if n != was:
            raise SystemExit('REFUSING TO WRITE: the reverent space is not '
                             'this edition\'s and must not be restored')

    if not write:
        print('(dry run; pass --write)')
        return
    for path, rows in ((SIMP, simp_rows), (TRAD, trad_rows)):
        with open(path, 'w', encoding='utf-8') as f:
            json.dump(rows, f, ensure_ascii=False, indent=2)
            f.write('\n')
        print('WROTE %s' % path)


if __name__ == '__main__':
    main()
