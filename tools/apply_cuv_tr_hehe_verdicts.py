#!/usr/bin/env python3
"""Apply the 和合本 verdicts on 和合本雅偉版 繁體, one occurrence at a time.

2026-09-14. This settles the 128 character classes that
`audit_cuv_tr_against_official.py` left open — the ones where our
conversion and the publisher's conversion of the same Simplified verse
disagree, and neither side's count of itself settles anything.

**The authority is the published 和合本**, read verse by verse at 信望愛
(bible.fhl.net, `VERSION4=unv`). 和合本雅偉版 is the 和合本 with the
divine name restored, so where the two conversions disagree at a
character the printed 和合本 has already answered the question.

**Per occurrence, never per class.** 和合本 is not internally consistent:
出埃及記 25:13 writes 槓 and 27:10 writes 杆 for the same poles; 以西結書
23:44 prints 茍合 and then 苟合 *in one verse*. 19 further pairs are split
across the first half of the canon alone. A class-level verdict would
therefore corrupt every minority occurrence, which is why the verdict
files carry one row per position and this script locates positions
rather than running `str.replace`.

**How a position is located.** Exactly as the audit found it: the
Simplified verse, our Traditional verse and the publisher's Traditional
verse are compared index by index, and only where all three have equal
length after notes and 主 markers are stripped. That is the same
alignment that produced the work list, so the positions this script
visits are the positions that were adjudicated — `--worklist` asserts
that and refuses to write if the two sets differ. That check only holds
against an unrepaired edition: once the verdicts are in, a repaired
position no longer disagrees and has nothing left to find. Re-running
with the verdict file alone is the idempotence check, and reports zero.

Verdicts: `我們錯` writes the 和合本 character, `他們錯` leaves ours
alone, `都不是` and `找不到` are recorded and skipped.

Usage:
    tools/apply_cuv_tr_hehe_verdicts.py --verdicts <a.tsv> [<b.tsv> ...]
        [--worklist <positions.tsv>] [--write] [--repo <path>]
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
NOTE_APP = re.compile(r'<note:[^>]*>')
NOTE_DB = re.compile(r'〔[^〕]*〕')
MARK = re.compile(r'主\[(?:雅伟|雅偉|基督|耶稣|耶穌)\]')

# The only position in the Bible where 和合本 prints two different forms
# of one pair inside a single verse, so the verdict rows for it cannot be
# told apart by their key. 以西結書 23:44 reads 「他們就是這樣與那二淫婦
# 茍合，好像與妓女苟合」 — verified from the raw 信望愛 bytes. Listed in
# text order; the length must match the number of positions found.
SPLIT = {
    ('以西結書', 23, 44, '苟', '茍', '苟'): ['茍', '苟'],
}


def clean(text, from_db):
    return MARK.sub('主', (NOTE_DB if from_db else NOTE_APP).sub('', text))


def han(ch):
    return '㐀' <= ch <= '鿿'


def load_verdicts(paths):
    """(book, chapter, verse, simplified, ours, theirs) -> {和合本: 裁決}."""
    out = defaultdict(dict)
    rows = 0
    for path in paths:
        with open(path, encoding='utf-8') as f:
            reader = csv.reader(f, delimiter='\t')
            header = next(reader)
            if header[:8] != ['書', '章', '節', '簡體', '我們', '他們',
                              '和合本', '裁決']:
                sys.exit('%s: unexpected header %r' % (path, header))
            for row in reader:
                if len(row) < 8:
                    continue
                key = (row[0], int(row[1]), int(row[2]),
                       row[3], row[4], row[5])
                out[key][row[6]] = row[7]
                rows += 1
    print('%d verdict rows over %d positions' % (rows, len(out)))
    return out


def main():
    if '--verdicts' not in sys.argv:
        sys.exit(__doc__)
    args = sys.argv[sys.argv.index('--verdicts') + 1:]
    verdict_paths = []
    for a in args:
        if a.startswith('--'):
            break
        verdict_paths.append(a)
    write = '--write' in sys.argv
    repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if '--repo' in sys.argv:
        repo = os.path.abspath(sys.argv[sys.argv.index('--repo') + 1])
    worklist = None
    if '--worklist' in sys.argv:
        worklist = sys.argv[sys.argv.index('--worklist') + 1]

    verdicts = load_verdicts(verdict_paths)

    con = sqlite3.connect('file:%s?mode=ro' % DB, uri=True)
    seq = {c: s for s, c in con.execute('select seq, code from books')}
    zh = {c: n for c, n in con.execute('select code, name_zh_tw from books')}
    official = {}
    for b, c, v, p in con.execute(
            "select book, chapter, verse, plain from verses "
            "where version='cuvt'"):
        official['%03d%03d%03d' % (seq[b], c, v)] = (p, zh[b], c, v)

    asset = os.path.join(repo, 'assets', 'cuvs-yhwh-tr.json')
    rows_t = json.load(open(asset, encoding='utf-8'))
    ours_t = {r['id']: r for r in rows_t}
    ours_s = {r['id']: r['text'] for r in json.load(
        open(os.path.join(repo, 'assets', 'cuvs-yhwh.json'), encoding='utf-8'))}

    # Walk every adjudicable position, grouped by verse and key.
    found = defaultdict(list)          # key -> [(vid, index), ...]
    seen_positions = set()
    for vid, row in ours_t.items():
        rec = official.get(vid)
        if rec is None:
            continue
        theirs, book, ch, vs = rec
        a = clean(row['text'], False)
        t = clean(theirs, True)
        s = clean(ours_s.get(vid, ''), False)
        if not (len(a) == len(t) == len(s)):
            continue
        for i, (x, y, z) in enumerate(zip(a, t, s)):
            if x == y or not (han(x) and han(y)):
                continue
            key = (book, ch, vs, z, x, y)
            found[key].append((vid, i))
            seen_positions.add((book, ch, vs, z, x, y, i))

    n_found = sum(len(v) for v in found.values())
    print('%d positions found in the assets, over %d keys'
          % (n_found, len(found)))

    if worklist:
        want = Counter()
        with open(worklist, encoding='utf-8') as f:
            reader = csv.reader(f, delimiter='\t')
            next(reader)
            for row in reader:
                if len(row) < 6:
                    continue
                want[(row[0], int(row[1]), int(row[2]),
                      row[3], row[4], row[5])] += 1
        have = Counter({k: len(v) for k, v in found.items()})
        if want != have:
            for k in set(want) | set(have):
                if want[k] != have[k]:
                    print('  WORKLIST MISMATCH %r  list=%d assets=%d'
                          % (k, want[k], have[k]))
            sys.exit('the positions on disk are not the positions that were '
                     'adjudicated; refusing to write')
        print('worklist agrees with the assets at every position')

    # Apply.
    changed = Counter()
    unsettled, missing, split_bad = [], [], []
    edits = defaultdict(list)          # vid -> [(index, char)]
    for key, places in sorted(found.items()):
        book, ch, vs, z, x, y = key
        rules = verdicts.get(key)
        if not rules:
            missing.append(key)
            continue
        if key in SPLIT:
            # Locate every occurrence of the pair in the verse, not only
            # the positions that still disagree, so the rule reads the
            # same before and after it has been applied.
            want = SPLIT[key]
            vid = places[0][0]
            text = clean(ours_t[vid]['text'], False)
            spots = [i for i, c in enumerate(text) if c in (x, y)]
            if len(want) != len(spots) or set(want) != set(rules):
                split_bad.append(key)
                continue
            for i, ch_want in zip(spots, want):
                if text[i] != ch_want:
                    edits[vid].append((i, ch_want))
                    changed[(text[i], ch_want)] += 1
            continue
        if len(rules) > 1:
            split_bad.append(key)
            continue
        hehe, verdict = next(iter(rules.items()))
        if verdict in ('都不是', '找不到'):
            unsettled.append((key, hehe, verdict))
            continue
        if verdict == '他們錯':
            continue
        if verdict != '我們錯':
            unsettled.append((key, hehe, verdict))
            continue
        if hehe == x:
            continue                    # already the 和合本 form
        for vid, i in places:
            edits[vid].append((i, hehe))
            changed[(x, hehe)] += 1

    for key in missing:
        print('  no verdict for %r' % (key,))
    for key in split_bad:
        print('  SPLIT key without an ordered rule: %r -> %r'
              % (key, sorted(verdicts.get(key, {}))))
    for key, hehe, verdict in unsettled:
        print('  %s %d:%d %s — %s (和合本 %s), left alone'
              % (key[0], key[1], key[2], key[4], verdict, hehe))

    if split_bad:
        sys.exit('an unordered split key would be applied blind; refusing')

    # Write the edits back at cleaned-index positions, which means mapping
    # each cleaned index to its index in the stored text (notes and 主
    # markers occupy stored positions that the cleaned string collapses).
    def apply_edits(stored, places):
        out = list(stored)
        # Build cleaned-index -> stored-index by replaying the same strip.
        mapping = []
        i = 0
        while i < len(stored):
            m = NOTE_APP.match(stored, i)
            if m:
                i = m.end()
                continue
            m = MARK.match(stored, i)
            if m:
                mapping.append(i)       # the 主 the marker collapses to
                i = m.end()
                continue
            mapping.append(i)
            i += 1
        for ci, ch_want in places:
            si = mapping[ci]
            out[si] = ch_want
        return ''.join(out)

    for vid, places in edits.items():
        row = ours_t[vid]
        before = clean(row['text'], False)
        row['text'] = apply_edits(row['text'], places)
        after = clean(row['text'], False)
        if len(before) != len(after):
            sys.exit('%s changed length; aborting' % vid)
        for ci, ch_want in places:
            if after[ci] != ch_want:
                sys.exit('%s position %d did not take %r' % (vid, ci, ch_want))

    total = sum(changed.values())
    print('\n%d characters in %d verses, over %d classes'
          % (total, len(edits), len(changed)))
    for (x, y), n in changed.most_common():
        print('  %s -> %s  %5d' % (x, y, n))

    if write and total:
        with open(asset, 'w', encoding='utf-8') as f:
            json.dump(rows_t, f, ensure_ascii=False, indent=2)
            f.write('\n')
        print('WROTE %s' % asset)
    elif not write:
        print('(dry run; pass --write)')


if __name__ == '__main__':
    main()
