#!/usr/bin/env python3
"""Put the 和合本雅偉版 繁體 on Hong Kong forms.

2026-09-14, at the owner's ruling 「按照香港和合本的繁体字吧」.

WHY. The publisher's own conversion README says it, from the church:
「**Hong Kong**, at the church's request: 裏, 牀, 着 — not Taiwan's 裡,
床, 著」. Their pipeline runs OpenCC's HKVariants; this repo's Traditional
was produced down the Taiwan path and carries TWVariants forms
everywhere except 裏, which it already had.

THE PAIRS, and how each was established. Not from a table anyone typed:
the same Simplified characters were run through the installed `opencc`
under both profiles and the two outputs compared —

    printf '说着卫脱群户悦卧床钩税温启兑峰叙锐葱' | opencc -c s2hk
    説着衞脱羣户悦卧牀鈎税温啓兑峯敍鋭葱
    printf '说着卫脱群户悦卧床钩税温启兑峰叙锐葱' | opencc -c s2tw
    說著衛脫群戶悅臥床鉤稅溫啟兌峰敘銳蔥

Four candidates were DROPPED because both profiles produce the same
character, which makes them word choices rather than regional forms:
梁/樑 (樑 is a beam, 梁 a name), 痴/癡, 灶/竈, 麵/麪.

WHAT THIS IS NOT. It is not a re-conversion. Running `opencc -c s2hk`
over the whole file would also undo this repo's own repairs — 乾瘦 at
創世記 41, 准許, 指證, and the five over-conversions fixed against the
published 和合本 earlier today. Only the eighteen variant characters
move, one for one, and every other decision in the file stands.

Usage:
    tools/apply_hk_variants_to_cuv_tr.py [--write] [--repo <path>]
"""
import json
import os
import sys

# Taiwan form -> Hong Kong form.
PAIRS = {
    '說': '説', '著': '着', '衛': '衞', '脫': '脱', '群': '羣',
    '戶': '户', '悅': '悦', '臥': '卧', '床': '牀', '鉤': '鈎',
    '稅': '税', '溫': '温', '啟': '啓', '兌': '兑', '峰': '峯',
    '敘': '敍', '銳': '鋭', '蔥': '葱',
}


def main():
    write = '--write' in sys.argv
    repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if '--repo' in sys.argv:
        repo = os.path.abspath(sys.argv[sys.argv.index('--repo') + 1])
    asset = os.path.join(repo, 'assets', 'cuvs-yhwh-tr.json')
    rows = json.load(open(asset, encoding='utf-8'))

    moved = {k: 0 for k in PAIRS}
    for r in rows:
        t = r['text']
        if not any(k in t for k in PAIRS):
            continue
        for tw, hk in PAIRS.items():
            n = t.count(tw)
            if n:
                moved[tw] += n
                t = t.replace(tw, hk)
        r['text'] = t

    total = sum(moved.values())
    for tw, n in sorted(moved.items(), key=lambda kv: -kv[1]):
        if n:
            print('  %s -> %s  %6d' % (tw, PAIRS[tw], n))
    print('total: %d characters' % total)

    if write and total:
        with open(asset, 'w', encoding='utf-8') as f:
            json.dump(rows, f, ensure_ascii=False, indent=2)
            f.write('\n')
        print('WROTE %s' % asset)
    elif not write:
        print('(dry run; pass --write)')


if __name__ == '__main__':
    main()
