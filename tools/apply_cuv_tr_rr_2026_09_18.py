#!/usr/bin/env python3
"""和合本雅偉版 繁體: Pastor Raymond's review of our correction list, applied.

    tools/apply_cuv_tr_rr_2026_09_18.py <sheet.xlsx> [--write] [--assets assets]

THE EIGHTH THAW. `test/cuvs_yhwh_frozen_test.dart` pins both 雅偉版 assets
by hash, because the text is not ours to edit. This is the case it allows:
the publisher side has ruled. On 2026-09-14 we sent Raymond 牧師 the full
list of 17,682 character positions where our 繁體 differs from his
(docs/和合本雅偉版-繁體更正總說明.md in the Sword repo); on 2026-09-18 he
returned it with a yes/no column and remarks, and the owner said to apply
it (「这个也改了」).

WHAT IS APPLIED
  1. Every row: the character at that place becomes 現作 where he wrote
     yes, 原作 where he wrote no.
  2. 戶 臥 稭 淒 by his stated principle, at every row naming them. His
     remarks give the reason (以斯帖記 1:10, 以西結書 4:4, 以賽亞書 5:24,
     以西結書 31:15) and he marked nearly all of those rows no — but 25
     scattered rows yes (one 'm'), including the name 耶户 yes in 王下 9 and
     no elsewhere. The owner's call, 2026-09-18: follow the principle. Every
     row where it overrides his mark is printed.
  3. 著 → 着 everywhere except 傳道書 12:12 「著書多」 (his exception; "the
     rest can change globally").
  4. 什麼 → 甚麼 everywhere (his suggestion; the printed 和合本 has 甚麼).
     什亭 is a place name and is left alone.
  5. 使徒行傳 11:12, both scripts: one full stop too many before the note —
     「不要疑惑。〔或作……〕」 → 「不要疑惑〔或作……〕」.
  6. The last book is 啓示錄, not 啟示錄, in the 繁體.
  7. 秸 → 稭 in the two verses the list never named, 出埃及記 15:7 and
     約書亞記 2:6 — his principle again; the owner, 2026-09-18: 「按照他
     的做」.

HOW A ROW IS FOUND — the same rule as the website's tools/apply-cuvt-rr.py,
so the two come out alike. Notes stripped and both sides normalised
(every character of every pair read as its 現作 form, 「」『』 as “”‘’);
the window is the eleven characters from six before the named one to four
after, so the target is at index 6 unless the verse begins closer. A
window found nowhere, or more than once, is reported and left alone.
"""
import argparse
import json
import re
import sys
from collections import Counter

import openpyxl

PRINCIPLE = {'户': '戶', '戶': '戶', '卧': '臥', '臥': '臥',
             '秸': '稭', '稭': '稭', '悽': '淒', '淒': '淒'}
QUOTES = {'「': '“', '」': '”', '『': '‘', '』': '’'}
NOTE = re.compile(r'<[^>]*>')
MARKER = re.compile(r'\[(?:雅偉|耶穌|基督)\]')
PUNCT = set('，。、；：！？“”‘’「」『』（）〔〕…—· ')


def visible(text):
    """The characters a reader sees, with a map back into `text`."""
    out, idx, i = [], [], 0
    while i < len(text):
        if text[i] == '<':
            j = text.find('>', i)
            if j != -1:
                i = j + 1
                continue
        # The publisher's referent markers 主[雅偉] / 主[耶穌] / 主[基督] are
        # this asset's notation; the list was read without them.
        m = MARKER.match(text, i)
        if m:
            i = m.end()
            continue
        out.append(text[i])
        idx.append(i)
        i += 1
    return ''.join(out), idx


def locate(vis, ctx, orig, now, norm):
    """Where in `vis` the row's character is, or None.

    Exact window first. The window runs six characters before the target
    and four after, cut short where the verse ends, so its position says
    where the target is only when it is not cut at the front; otherwise
    the target is found by its character inside the window. Then, because
    the two apps' copies of this text differ in punctuation here and
    there, the same search with punctuation ignored. Either way it must be
    exactly one place, holding 原作 or 現作.
    """
    target = {norm(orig)}
    for strip in (False, True):
        keep = [i for i, c in enumerate(vis) if not (strip and c in PUNCT)]
        hay = norm(''.join(vis[i] for i in keep))
        w = norm(''.join(c for c in ctx if not (strip and c in PUNCT)))
        hits = [m.start() for m in re.finditer(re.escape(w), hay)]
        if len(hits) != 1:
            continue
        start = hits[0]
        if start > 0 and len(w) >= 7 and hay[start + 6] in target:
            cands = [6]
        else:
            cands = [i for i, c in enumerate(w) if c in target]
            if len(cands) > 1 and 6 in cands:
                cands = [6]
        if len(cands) != 1:
            return None
        pos = keep[start + cands[0]]
        return pos if vis[pos] in (orig, now) else None
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('sheet')
    ap.add_argument('--write', action='store_true')
    ap.add_argument('--assets', default='assets')
    a = ap.parse_args()

    rows = list(openpyxl.load_workbook(a.sheet).worksheets[0]
                .iter_rows(min_row=3, values_only=True))
    to_now = {}
    for r in rows:
        to_now[r[3]] = r[4]
        to_now[r[4]] = r[4]

    def norm(s):
        return ''.join(QUOTES.get(c, to_now.get(c, c)) for c in s)

    path = f'{a.assets}/cuvs-yhwh-tr.json'
    data = json.load(open(path, encoding='utf-8'))
    key = {(v['book'], int(v['chapter']), int(v['verse'])): v for v in data}

    stats, overridden, unmatched = Counter(), [], []
    for r in rows:
        book, ch, vs, orig, now, *_rest = r
        mark = (r[8] or '').strip().lower()
        ctx = r[7]
        want = now if mark == 'yes' else orig
        if orig in PRINCIPLE or now in PRINCIPLE:
            p = PRINCIPLE.get(orig) or PRINCIPLE.get(now)
            if p != want:
                overridden.append(f'{book} {ch}:{vs} {orig}/{now} marked '
                                  f'{mark!r} → {p}  ({ctx})')
            want = p
        # The list spells four books as the printed 和合本 does; this asset
        # carries its own spellings. Names only — the verse is the same.
        book = {'創世記': '創世紀', '約翰壹書': '約翰一書', '約翰貳書': '約翰二書',
                '約翰參書': '約翰三書'}.get(book, book)
        v = key.get((book, ch, vs))
        if v is None:
            unmatched.append(f'{book} {ch}:{vs} no such verse')
            continue
        vis, idx = visible(v['text'])
        pos = locate(vis, ctx, orig, now, norm)
        if pos is None:
            stats['unmatched'] += 1
            unmatched.append(f'{book} {ch}:{vs} {orig}→{now}: {ctx}')
            continue
        if vis[pos] == want:
            stats['already'] += 1
            continue
        t = v['text']
        o = idx[pos]
        v['text'] = t[:o] + want + t[o + 1:]
        stats[f'{vis[pos]}→{want}'] += 1

    # Two verses where the window cannot say WHICH 户 it means — both of
    # them hold two, in names (耶户；耶户, 亞施户生亞户撒) — and his
    # principle is the same for every one, so both are done whole.
    for bk, c_, v_ in (('歷代志上', '2', '38'), ('歷代志上', '4', '6')):
        v = key[(bk, int(c_), int(v_))]
        n = v['text'].count('户')
        if n:
            v['text'] = v['text'].replace('户', '戶')
            stats['户→戶 (whole verse, principle)'] += n

    # 3. 著 → 着 everywhere but 傳道書 12:12
    for v in data:
        if (v['book'], v['chapter'], v['verse']) == ('傳道書', '12', '12'):
            if '着書多' in v['text']:
                v['text'] = v['text'].replace('着書多', '著書多')
                stats['著書多 restored'] += 1
            continue
        n = v['text'].count('著')
        if n:
            v['text'] = v['text'].replace('著', '着')
            stats['著→着 (global)'] += n
    # 4. 什麼 → 甚麼
    for v in data:
        n = v['text'].count('什麼')
        if n:
            v['text'] = v['text'].replace('什麼', '甚麼')
            stats['什麼→甚麼'] += n
    # 6. 啓示錄
    for v in data:
        if v['book'] == '啟示錄':
            v['book'] = '啓示錄'
            stats['book 啟示錄→啓示錄'] += 1

    # 7. the two 秸 outside the list
    for bk, c_, v_ in (('出埃及記', 15, 7), ('約書亞記', 2, 6)):
        v = key[(bk, c_, v_)]
        n = v['text'].count('秸')
        if n:
            v['text'] = v['text'].replace('秸', '稭')
            stats['秸→稭 (outside the list, principle)'] += n

    # 5. 使徒行傳 11:12, both scripts
    acts = re.compile(r'(疑惑)。(<note:)')
    simp_path = f'{a.assets}/cuvs-yhwh.json'
    simp = json.load(open(simp_path, encoding='utf-8'))
    for script, rows_, bk in (('繁', data, '使徒行傳'), ('简', simp, '使徒行传')):
        v = next(x for x in rows_ if x['book'] == bk and x['chapter'] == '11'
                 and x['verse'] == '12')
        new, n = acts.subn(r'\1\2', v['text'])
        if n == 1:
            v['text'] = new
            stats[f'使徒行傳 11:12 full stop ({script})'] += 1
        elif '疑惑<note:' not in v['text']:
            sys.exit(f'REFUSE: 使徒行傳 11:12 ({script}) reads {v["text"][:60]!r}')

    for line in overridden:
        print('principle over mark:', line)
    for line in unmatched:
        print('left alone:', line)
    for k2, n in sorted(stats.items()):
        print(f'  {k2}: {n}')
    if a.write:
        for p, d in ((path, data), (simp_path, simp)):
            # Byte-exact with how these assets are stored (2-space indent,
            # trailing newline), so the diff is the edits and nothing else.
            open(p, 'w', encoding='utf-8').write(
                json.dumps(d, ensure_ascii=False, indent=2) + '\n')
        print('written')
    else:
        print('(dry run — pass --write)')


if __name__ == '__main__':
    main()
