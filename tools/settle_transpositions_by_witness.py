#!/usr/bin/env python3
"""Undo the character transpositions the publisher's newer text carries.

WHAT WAS FOUND
--------------
Scanning every verse the publisher sync changed for a PURE transposition
— our span and the official edition's span holding the identical
characters in a different order — turns up **25 verses**, on top of the
two `repair_transposed_characters.py` already knew about. 詩篇 24:4 reads
心清 for 清心, 羅馬書 12:3 們各人 for 各人們, 列王紀上 14:5 告她訴 for
告訴她.

They are not this sync's doing. Sampled straight out of the publisher's
own `bsapp_bible_cuvs` rows, they are there too — 列王紀上 14:5 is worse
in the database than in our asset (「你當此此如此告她訴。」). So this is a
defect in their data that we inherited by adopting their text, and the
owner's ruling settles it: 「参考和合本繁體官方的去决定」.

WHY A TOOL AND NOT TWENTY-FIVE HAND-WRITTEN ENTRIES
---------------------------------------------------
Because the finding is a CLASS, and a class that a hand-written list
cannot keep up with: the next sync will bring more. This detects them
the same way they were found, and it can be re-run.

WHAT COUNTS AS ONE, AND WHAT IS REFUSED
---------------------------------------
Our TRADITIONAL verse is aligned against the witness — both traditional,
so no script conversion enters the comparison — and a transposition
shows up in the diff not as one block but as an INSERT of a character in
one place and a DELETE of the same character in another, with untouched
text between. 詩篇 24:4 is `insert 心` then `delete 心`; 羅馬書 12:3 is
`insert 們` then `delete 們`.

So a verse is taken only when

  * the multiset of everything INSERTED equals the multiset of
    everything DELETED, so nothing is added or dropped — only moved,
  * every character that moves is a Han ideograph, and
  * at most MAX_MOVED characters move, and
  * `replace` blocks are ignored in that accounting and left untouched,
    because that is where the editions legitimately differ (雅偉 against
    耶和華, ， against ；).

**Punctuation is excluded on purpose, and that is not timidity.** The
same scan without the Han test finds 94 verses instead of 25, and the
extra 69 are all a mark sitting on the other side of a quotation —
「拉比」，便與他親嘴 against 「拉比，」便與他親嘴, 就砍下來，丟在火裏
against 就砍下來丟在火裏，. Which side of a closing quote a comma falls
on is a house style two editions may hold differently, and moving 69 of
them to match another edition is re-punctuating 和合本雅偉版 rather than
repairing it. A displaced 心 in 清心 is not that.

Anything else is left and counted. A verse that gains or loses a
character is NOT this tool's business — `repair_dropped_characters.py`
and `repair_by_official_cuv.py` handle those, having read the verse.

The Simplified twin moves the SAME character rather than copying the
witness's, which is traditional: what moves is ours, only where it moves
to comes from the official edition.

Usage:  tools/settle_transpositions_by_witness.py [--write]
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
MAX_MOVED = 4


def is_han(ch):
    o = ord(ch)
    return 0x4E00 <= o <= 0x9FFF or 0x3400 <= o <= 0x4DBF


def witness():
    return {r['id']: r['text'] for r in json.loads(subprocess.check_output(
        ['git', 'cat-file', '-p', WITNESS_BLOB], cwd=ROOT).decode('utf-8'))}


def main():
    write = '--write' in sys.argv
    w = witness()
    presync = {r['id']: r['text'] for r in json.loads(subprocess.check_output(
        ['git', 'show', 'HEAD:assets/cuvs-yhwh.json'],
        cwd=ROOT).decode('utf-8'))}
    simp_rows = json.load(open(SIMP, encoding='utf-8'))
    trad_rows = json.load(open(TRAD, encoding='utf-8'))
    simp = {r['id']: r for r in simp_rows}

    fixed = []
    refused = 0
    punctuation_only = 0
    for r in trad_rows:
        theirs = w.get(r['id'])
        s = simp.get(r['id'])
        if theirs is None or s is None or len(s['text']) != len(r['text']):
            continue
        was = presync.get(r['id'])
        if was is None or was == s['text']:
            continue          # the sync did not touch this verse
        ours = r['text']
        ops = difflib.SequenceMatcher(
            None, ours, theirs, autojunk=False).get_opcodes()
        inserted = [(j1, theirs[j1:j2])
                    for tag, i1, i2, j1, j2 in ops if tag == 'insert']
        deleted = [(i1, ours[i1:i2])
                   for tag, i1, i2, j1, j2 in ops if tag == 'delete']
        ins_chars = sorted(''.join(t for _, t in inserted))
        del_chars = sorted(''.join(t for _, t in deleted))
        if not ins_chars or ins_chars != del_chars:
            continue
        if len(ins_chars) > MAX_MOVED:
            refused += 1
            continue
        if not all(is_han(ch) for ch in ins_chars):
            punctuation_only += 1
            continue

        # Where each deleted character sits, so the Simplified can move
        # its own copy rather than the witness's.
        pool = []
        for i1, text in deleted:
            for k, ch in enumerate(text):
                pool.append((ch, s['text'][i1 + k], ours[i1 + k]))

        out_s, out_t = [], []
        ok = True
        for tag, i1, i2, j1, j2 in ops:
            if tag in ('equal', 'replace'):
                out_s.append(s['text'][i1:i2])
                out_t.append(ours[i1:i2])
            elif tag == 'delete':
                continue
            else:                                   # insert
                for ch in theirs[j1:j2]:
                    for n, (want, sc, tc) in enumerate(pool):
                        if want == ch:
                            out_s.append(sc)
                            out_t.append(tc)
                            pool.pop(n)
                            break
                    else:
                        ok = False
        if not ok or pool:
            refused += 1
            continue
        new_s, new_t = ''.join(out_s), ''.join(out_t)
        if len(new_s) != len(new_t):
            refused += 1
            continue
        fixed.append((r['id'], ours, new_t))
        r['text'] = new_t
        s['text'] = new_s

    print('verses whose transposition was undone: %d' % len(fixed))
    for vid, a, b in fixed:
        import difflib as _d
        for tag, i1, i2, j1, j2 in _d.SequenceMatcher(
                None, a, b, autojunk=False).get_opcodes():
            if tag != 'equal':
                print('    %s  %r -> %r   …%s…'
                      % (vid, a[i1:i2], b[j1:j2], b[max(0, j1 - 8):j2 + 8]))
    print('spans refused (ambiguity): %d' % refused)
    print('verses left alone because only punctuation moved: %d'
          % punctuation_only)

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
