#!/usr/bin/env python3
"""Re-read the five over-conversion pairs at every position, and repair 藉.

2026-09-14. `repair_cuv_tr_overconversion.py` reverted five pairs as a
CLASS, each justified by one verse:

    藉 → 借   出埃及記 22:14
    蔔 → 卜   創世記 44:5
    製 → 制   創世記 4:7
    沈 → 沉   創世記 2:21
    淩 → 凌   士師記 19:25

出埃及記 22:14 is the law about BORROWING, where 借 is right — and the
sweep then applied that answer to a sense the 和合本 spells differently.
「耶和華藉摩西吩咐」 became 「雅偉借摩西吩咐」, 151 times over.

Four independent readings of the published 和合本 (信望愛, `VERSION4=unv`),
381 chapters, all 638 positions of all five pairs:

    對 486   錯 152   都不是 0   找不到 0

**151 of the 152 are 借 where the 和合本 prints 藉**, and the 152nd is the
edition's single 沈 (馬太福音 14:30, 將要沉下去). The other four pairs are
correct at every one of their 486 positions — 出埃及記 22:14's answer was
right, for the sense it was read at.

WHY THIS IS STILL NOT A CLASS VERDICT. The 和合本 itself prints 借 in the
instrumental sense twice — 撒母耳記下 12:9 「你借亞捫人的刀殺害…」 and
約伯記 34:20 「有權力的被奪去非借人手」 — and this edition already prints
借 at both. A sweep of 借 → 藉 would have broken them, and a sweep the
other way is what caused this. Each row below is one position.

Usage:
    tools/apply_cuv_tr_overconversion_reaudit.py --verdicts <merged.tsv>
        [--write] [--repo <path>]
"""
import csv
import json
import os
import re
import sqlite3
import sys
from collections import Counter, defaultdict

DB = os.path.expanduser(
    '~/Documents/CodingProject/Yahwehdehua/app/build/bible.db')
NOTE = re.compile(r'<note:[^>]*>')
MARK = re.compile(r'主\[(?:雅伟|雅偉|基督|耶稣|耶穌)\]')
PAIRS = [('藉', '借'), ('蔔', '卜'), ('製', '制'), ('沈', '沉'), ('淩', '凌')]
CHARS = {c for pair in PAIRS for c in pair}


def clean(text):
    return MARK.sub('主', NOTE.sub('', text))


def main():
    if '--verdicts' not in sys.argv:
        sys.exit(__doc__)
    verdicts_path = sys.argv[sys.argv.index('--verdicts') + 1]
    write = '--write' in sys.argv
    repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if '--repo' in sys.argv:
        repo = os.path.abspath(sys.argv[sys.argv.index('--repo') + 1])

    con = sqlite3.connect('file:%s?mode=ro' % DB, uri=True)
    seq = {c: s for s, c in con.execute('select seq, code from books')}
    zh = {c: n for c, n in con.execute('select code, name_zh_tw from books')}
    vid_of = {}
    for b, c, v in con.execute(
            "select book, chapter, verse from verses where version='cuvt'"):
        vid_of[(zh[b], c, v)] = '%03d%03d%03d' % (seq[b], c, v)

    rows = defaultdict(list)
    with open(verdicts_path, encoding='utf-8') as f:
        reader = csv.reader(f, delimiter='\t')
        header = next(reader)
        if header[:6] != ['書', '章', '節', '我們', '和合本', '裁決']:
            sys.exit('unexpected header %r' % header)
        for r in reader:
            if len(r) < 6:
                continue
            rows[(r[0], int(r[1]), int(r[2]))].append(r)

    asset = os.path.join(repo, 'assets', 'cuvs-yhwh-tr.json')
    data = json.load(open(asset, encoding='utf-8'))
    by_id = {r['id']: r for r in data}

    changed = Counter()
    skipped, missing = [], []
    for key, verse_rows in sorted(rows.items()):
        vid = vid_of.get(key)
        row = by_id.get(vid) if vid else None
        if row is None:
            missing.append(key)
            continue
        text = clean(row['text'])
        spots = [i for i, ch in enumerate(text) if ch in CHARS]
        if len(spots) != len(verse_rows):
            # This edition differs from the one the work list was built
            # from — two repos share these verdicts and have separate
            # repair histories. Never guess which position is which.
            skipped.append((key, len(verse_rows), len(spots)))
            continue
        edits = []
        for i, r in zip(spots, verse_rows):
            ours, hehe, verdict = r[3], r[4], r[5]
            if text[i] != ours:
                edits = None
                skipped.append((key, ours, text[i]))
                break
            if verdict != '錯' or hehe == ours:
                continue
            edits.append((i, hehe))
        if not edits:
            continue
        # Map cleaned indices home: notes and 主 markers occupy stored
        # positions the cleaned string collapses.
        stored = row['text']
        mapping = []
        i = 0
        while i < len(stored):
            m = NOTE.match(stored, i)
            if m:
                i = m.end()
                continue
            m = MARK.match(stored, i)
            if m:
                mapping.append(i)
                i = m.end()
                continue
            mapping.append(i)
            i += 1
        out = list(stored)
        for ci, want in edits:
            out[mapping[ci]] = want
            changed[(text[ci], want)] += 1
        row['text'] = ''.join(out)
        after = clean(row['text'])
        if len(after) != len(text):
            sys.exit('%s changed length' % vid)
        for ci, want in edits:
            if after[ci] != want:
                sys.exit('%s position %d did not take %r' % (vid, ci, want))

    for key in missing:
        print('  no such verse: %r' % (key,))
    for s in skipped:
        print('  SKIPPED %r — this edition does not match the work list' % (s,))

    total = sum(changed.values())
    print('%d characters over %d classes' % (total, len(changed)))
    for (a, b), n in changed.most_common():
        print('  %s -> %s  %5d' % (a, b, n))

    if write and total:
        with open(asset, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write('\n')
        print('WROTE %s' % asset)
    elif not write:
        print('(dry run; pass --write)')


if __name__ == '__main__':
    main()
