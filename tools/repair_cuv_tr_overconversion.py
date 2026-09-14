#!/usr/bin/env python3
"""Undo five over-conversions in 和合本雅偉版 繁體, against the published CUV.

2026-09-14, at the owner's instruction 「你可以参考网上繁体字和合本来改」.

WHY THIS IS CHECKABLE. 和合本雅偉版 is the 和合本 with the divine name
restored; the surrounding words are the 和合本's. So where this repo's
Traditional conversion disagrees with the published Traditional 和合本,
the published text settles it — it is the same sentence.

Each pair below was looked up at 信望愛 (bible.fhl.net, `VERSION4=unv`,
the Traditional 和合本) at the reference named, and each is a case where
this repo converted a character the 和合本 leaves alone:

    我們        和合本        出處
    藉什麽      借甚麼        出埃及記 22:14   — the law about BORROWING
    占蔔        占卜          創世記 44:5      — 蔔 is the radish of 蘿蔔
    製伏        制伏          創世記 4:7       — 製 is to manufacture
    沈睡        沉睡          創世記 2:21      — 沈 is a surname
    淩辱        凌辱          士師記 19:25

POSITIONAL, NOT A SWEEP. 藉 is a real word (藉著) and 製 is a real word
(製造); only the positions where our own SIMPLIFIED text has the other
character are wrong. So each repair is made where the Simplified verse
disagrees with the Traditional one at that position, and nowhere else.
`repair_biblexg_v2_tr.py` states the rule this follows.

NOT DONE HERE, deliberately: 裏 → 裡. This repo writes 裏 4,792 times and
裡 never; the published 和合本 writes 裡 (創世記 28:11 「在那裡躺臥睡了」),
and so does the official side's own conversion profile — its `tc/README`
picks `s2tw` precisely because "s2t gives 裏 and 麪 where Taiwan writes 裡
and 麵" — yet its shipped text has 裏 as well. Both forms are the same
word and the choice is about which readership the edition is set for,
which is the owner's to make and not a defect to repair.

Usage:
    tools/repair_cuv_tr_overconversion.py [--write] [--repo <path>]
"""
import json
import os
import sys

# ours -> the 和合本's, with the verse each was checked at.
PAIRS = [
    ('藉', '借', '出埃及記 22:14'),
    ('蔔', '卜', '創世記 44:5'),
    ('製', '制', '創世記 4:7'),
    ('沈', '沉', '創世記 2:21'),
    ('淩', '凌', '士師記 19:25'),
]


def main():
    write = '--write' in sys.argv
    repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if '--repo' in sys.argv:
        repo = os.path.abspath(sys.argv[sys.argv.index('--repo') + 1])
    A = lambda n: os.path.join(repo, 'assets', n)

    import re
    import sqlite3
    DB = os.path.expanduser(
        '~/Documents/CodingProject/Yahwehdehua/app/build/bible.db')
    con = sqlite3.connect('file:%s?mode=ro' % DB, uri=True)
    seq = {c: q for q, c in con.execute('select seq, code from books')}
    official = {}
    for b, c, v, plain in con.execute(
            "select book, chapter, verse, plain from verses "
            "where version='cuvt'"):
        official['%03d%03d%03d' % (seq[b], c, v)] = plain

    NOTE_APP = re.compile(r'<note:[^>]*>')
    NOTE_DB = re.compile(r'〔[^〕]*〕')
    MARK = re.compile(r'主\[(?:雅伟|雅偉|基督|耶稣|耶穌)\]')

    def clean(text, from_db):
        return MARK.sub('主', (NOTE_DB if from_db else NOTE_APP).sub('', text))

    simplified = {r['id']: r['text']
                  for r in json.load(open(A('cuvs-yhwh.json'), encoding='utf-8'))}
    rows = json.load(open(A('cuvs-yhwh-tr.json'), encoding='utf-8'))

    fixed = {p[0]: 0 for p in PAIRS}
    unaligned = 0
    wanted = {(o, t) for o, t, _ in PAIRS}
    for r in rows:
        s = simplified.get(r['id'])
        t = r['text']
        o = official.get(r['id'])
        if s is None or o is None:
            unaligned += 1
            continue
        cs, ct, co = clean(s, False), clean(t, False), clean(o, True)
        if not (len(cs) == len(ct) == len(co)):
            unaligned += 1
            continue
        # Three witnesses, and all three have to agree before a character
        # moves: our Simplified (what both sides converted FROM), the
        # official Traditional (which did not convert it), and this
        # file's own list of pairs checked against the published 和合本.
        #
        # That third condition is what keeps 製造 and 藉著 — the official
        # text converts those too, so they never match. A rule written on
        # our two files alone reverted all 157 製 including 製造, which is
        # correct Traditional for 制造.
        moves = {}
        for i, (a, b, c) in enumerate(zip(cs, ct, co)):
            if b != c and (b, a) in wanted and c == a:
                moves[i] = c
                fixed[b] += 1
        if not moves:
            continue
        # Applied back on the ORIGINAL string, whose notes and markers
        # `clean` removed: walk both and map the cleaned index home.
        out, j = list(r['text']), 0
        cleaned_positions = []
        raw = r['text']
        stripped = clean(raw, False)
        k = 0
        for idx, ch in enumerate(raw):
            if k < len(stripped) and ch == stripped[k]:
                cleaned_positions.append(idx)
                k += 1
        for i, ch in moves.items():
            if i < len(cleaned_positions):
                out[cleaned_positions[i]] = ch
        r['text'] = ''.join(out)

    for ours, theirs, ref in PAIRS:
        print('  %s -> %s  %5d   (%s)' % (ours, theirs, fixed[ours], ref))
    print('verses with no positional alignment, skipped: %d' % unaligned)

    if write and any(fixed.values()):
        with open(A('cuvs-yhwh-tr.json'), 'w', encoding='utf-8') as f:
            json.dump(rows, f, ensure_ascii=False, indent=2)
            f.write('\n')
        print('WROTE %s' % A('cuvs-yhwh-tr.json'))
    elif not write:
        print('(dry run; pass --write)')


if __name__ == '__main__':
    main()
