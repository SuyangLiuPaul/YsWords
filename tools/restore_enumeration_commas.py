#!/usr/bin/env python3
"""Put back the 、 the publisher's current text drops.

WHAT HAPPENED
-------------
`sync_cuv_yhwh_to_publisher.py` adopted the publisher's newer text,
which is right for words. It is not right for the enumeration comma:
their current text has **107 fewer 、 than our copy did**, and the
losses are not stylistic. 出埃及記 39:24 went from

    用藍色、紫色、朱紅色線，並撚的細麻做石榴

to 「用藍色紫色朱紅色線」, and 創世記 31:3 from 「你祖、你父之地」 to
「你祖你父之地」. The 和合本 prints the 、 in both, our copy had it, and
a list of three colours with no separator is not an edition's decision
about punctuation — it is a list that lost its commas.

WHAT IS NOT PUT BACK
--------------------
A 、 the publisher REPLACED rather than dropped. 創世記 41:43 reads
「這樣、法老派他治理埃及全地」 in our copy and 「這樣，法老…」 in theirs,
and theirs is better: 這樣 is not an item in a list. So this restores
only a **deletion** — a 、 that stands opposite nothing — and leaves
every substitution alone. That distinction is the whole tool; without
it this would be a blanket revert of the sync's punctuation.

The Traditional twin takes the identical edit at the identical
position, because 、 is 、 in both scripts. A verse whose two scripts
are not the same length is skipped, as everywhere else in this pass.

Usage:  tools/restore_enumeration_commas.py [--write]
"""
import difflib
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIMP = os.path.join(ROOT, 'assets', 'cuvs-yhwh.json')
TRAD = os.path.join(ROOT, 'assets', 'cuvs-yhwh-tr.json')


def git_show(rel):
    return {r['id']: r['text'] for r in json.loads(subprocess.check_output(
        ['git', 'show', 'HEAD:' + rel], cwd=ROOT).decode('utf-8'))}


def restore(before, now, twin=None):
    """`now` with the 、 that `before` had and `now` deletes outright.

    `twin` is the other script's copy of the SAME verse, which the sync
    guarantees is the same length as `now` and aligned to it character
    for character. So the diff is computed once, on the Simplified, and
    the output slices are taken from whichever string is being built —
    the same `j1:j2` window means the same characters in both.
    """
    out, out_twin = [], []
    for tag, i1, i2, j1, j2 in difflib.SequenceMatcher(
            None, before, now, autojunk=False).get_opcodes():
        if tag == 'delete' and before[i1:i2].strip('、') == '':
            out.append(before[i1:i2])          # only 、 was removed
            out_twin.append(before[i1:i2])     # 、 is the same in both
        elif tag in ('equal', 'replace', 'insert'):
            out.append(now[j1:j2])
            if twin is not None:
                out_twin.append(twin[j1:j2])
    return ''.join(out), (''.join(out_twin) if twin is not None else None)


def main():
    write = '--write' in sys.argv
    before = git_show('assets/cuvs-yhwh.json')
    simp_rows = json.load(open(SIMP, encoding='utf-8'))
    trad_rows = json.load(open(TRAD, encoding='utf-8'))
    trad = {r['id']: r for r in trad_rows}

    restored = skipped = 0
    examples = []
    for r in simp_rows:
        old = before.get(r['id'])
        if old is None or '、' not in old:
            continue
        t = trad.get(r['id'])
        if t is None or len(t['text']) != len(r['text']):
            new, _ = restore(old, r['text'])
            if new != r['text']:
                skipped += 1
            continue
        new, new_t = restore(old, r['text'], t['text'])
        if new == r['text']:
            continue
        added = new.count('、') - r['text'].count('、')
        if len(examples) < 8:
            examples.append((r['id'], r['text'][:60], new[:60]))
        r['text'] = new
        t['text'] = new_t
        restored += added

    print('enumeration commas restored: %d' % restored)
    print('verses skipped, the two scripts are not aligned: %d' % skipped)
    for vid, a, b in examples:
        print('    %s\n      was %s\n      now %s' % (vid, a, b))

    total = sum(r['text'].count('、') for r in simp_rows)
    total_t = sum(r['text'].count('、') for r in trad_rows)
    print('\n、 in the Simplified: %d   in the Traditional: %d'
          % (total, total_t))
    if total != total_t:
        raise SystemExit('REFUSING TO WRITE: the two scripts disagree about '
                         'how many enumeration commas there are')

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
