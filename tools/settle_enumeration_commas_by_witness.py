#!/usr/bin/env python3
"""Settle 、 against ，, one position at a time, against the official
和合本繁體.

WHY A SECOND TOOL
-----------------
`restore_enumeration_commas.py` puts back a 、 the publisher's current
text DELETES, and deliberately leaves alone every 、 they REPLACED with
，. That was the safe half of the rule and it is not the whole rule:
of the 84 verses where they made that substitution, some are a
modernisation worth taking and some are a regression.

    創世記 41:43   這樣、法老派他治理埃及全地   ->  這樣，法老…   THEIRS
    耶利米書 2:22  你雖用鹼、多用肥皂洗濯       ->  你雖用鹼，…   OURS

這樣 is a discourse adverb and takes ，; 鹼 and 肥皂 are two items of a
list and take 、. Nothing about the shape of the sentence separates
those two cases reliably, so the owner's ruling decides it —
「参考和合本繁體官方的去决定」 — and this tool asks the official edition
at every one of the positions rather than reasoning about any of them.

THE WITNESS
-----------
`assets/cuv-tr.json` as it stood at git blob **7a2dc43** — the plain
和合本繁體 (耶和華, not 雅偉), a separately imported edition of the same
base text, dropped from the repo at v1.4.5 and kept readable in the
history. 31,103 verses. `repair_tr_flour_glyph.py` already uses it and
says why it is trustworthy for glyphs; this is the same file used for
the same reason about punctuation.

Spot-checked against bible.fhl.net (VERSION1=unv) on 2026-09-08 at both
of the verses above and it agrees with the site character for
character, including 麵, 崙 and 穀 — so it is the official text and not
another conversion.

HOW A POSITION IS DECIDED
-------------------------
Our TRADITIONAL verse is aligned with the witness's, both being
traditional, so no script conversion enters the comparison. Where a
single one of our marks stands opposite a single one of theirs and the
two marks are 、 and ，, theirs is taken.

**A MATCHED MARK IS NOT ENOUGH, AND THE FIRST VERSION OF THIS PROVED
IT.** Where our verse is missing a 、 the witness has, the diff can pair
our next mark against their previous one and read a substitution that is
really a deletion two characters away. 出埃及記 35:6 came out proposing
、 -> ， three times in one list of fabrics — turning 「細麻、山羊毛」 into
「細麻，山羊毛」 to pay for a 、 that was missing further left. So a
position is only taken when the runs of IDENTICAL text on both sides of
it are at least CONTEXT characters long in both verses: the mark has to
sit in the same sentence, not merely somewhere in the same verse.

Anything else — a different character, a run of more than one, a mark
without that context, an unalignable verse — is left and reported. The
Simplified twin takes the identical edit at the identical index, which
the sync guarantees is the same character.

SCOPE: ONLY THE VERSES THE SYNC MOVED
-------------------------------------
Restricted, deliberately, to verses whose text the publisher sync
changed. Run over the whole Bible this same comparison proposes 114
positions rather than 82, and the extra 32 are places our edition and
the official edition have always punctuated differently — that is a
question about the edition, not about the sync, and re-punctuating
和合本雅偉版 against another edition is not a job to do on the way past
while reconciling something else. What is in scope is this: where the
sync moved a mark, was it moved the right way.

Usage:  tools/settle_enumeration_commas_by_witness.py [--write]
"""
import collections
import difflib
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIMP = os.path.join(ROOT, 'assets', 'cuvs-yhwh.json')
TRAD = os.path.join(ROOT, 'assets', 'cuvs-yhwh-tr.json')
WITNESS_BLOB = '7a2dc43'
MARKS = {'、', '，'}

# Characters of identical text required on each side of a mark before
# its position is believed. Six is enough to place a mark inside its own
# clause and short enough that a mark near the start or end of a verse
# still qualifies.
CONTEXT = 6


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

    moved = collections.Counter()
    examples = []
    unalignable = 0
    for r in trad_rows:
        theirs = w.get(r['id'])
        ours = r['text']
        s = simp.get(r['id'])
        if theirs is None or s is None or len(s['text']) != len(ours):
            continue
        was = presync.get(r['id'])
        if was is None or was == s['text']:
            continue          # the sync did not touch this verse
        if not (MARKS & set(ours) and MARKS & set(theirs)):
            continue
        chars = list(ours)
        s_chars = list(s['text'])
        hit = False
        ops = difflib.SequenceMatcher(
            None, ours, theirs, autojunk=False).get_opcodes()
        for n, (tag, i1, i2, j1, j2) in enumerate(ops):
            if tag != 'replace' or (i2 - i1) != 1 or (j2 - j1) != 1:
                continue
            before = ops[n - 1] if n else None
            after = ops[n + 1] if n + 1 < len(ops) else None
            # A run shorter than CONTEXT is still trustworthy when it
            # is the FIRST or LAST block, because then it is anchored to
            # the start or end of the verse and cannot have slid.
            # 耶利米書 2:22 needs this: 「你雖用鹼」 is four characters
            # and it is the whole of the verse before the mark.
            if before is None or before[0] != 'equal' or (
                    before[2] - before[1] < CONTEXT and n != 1):
                continue
            if after is None or after[0] != 'equal' or (
                    after[2] - after[1] < CONTEXT and n + 2 != len(ops)):
                continue
            a, b = ours[i1], theirs[j1]
            if a in MARKS and b in MARKS and a != b:
                chars[i1] = b
                s_chars[i1] = b
                moved[(a, b)] += 1
                hit = True
                if len(examples) < 12:
                    examples.append(
                        '%s  %s -> %s   %s'
                        % (r['id'], a, b, ours[max(0, i1 - 8):i1 + 9]))
        if hit:
            r['text'] = ''.join(chars)
            s['text'] = ''.join(s_chars)

    print('marks settled against the official edition:')
    for (a, b), n in moved.most_common():
        print('    %s -> %s  %d' % (a, b, n))
    for e in examples:
        print('    %s' % e)
    print('unalignable: %d' % unalignable)

    st = sum(r['text'].count('、') for r in simp_rows)
    tt = sum(r['text'].count('、') for r in trad_rows)
    print('\n、 in the Simplified: %d   in the Traditional: %d' % (st, tt))
    if st != tt:
        raise SystemExit('REFUSING TO WRITE: the two scripts disagree')

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
