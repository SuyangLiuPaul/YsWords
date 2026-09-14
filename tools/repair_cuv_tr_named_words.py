#!/usr/bin/env python3
"""Named word-level repairs to 和合本雅偉版 繁體, each against a verse.

2026-09-14. Separate from `repair_cuv_tr_overconversion.py` because these
are not one character standing for another: they are a word this repo
spells differently from the 和合本, or a word in the wrong place.

Every entry cites the verse it was checked at, at 信望愛 (bible.fhl.net,
`VERSION4=unv`, the Traditional 和合本). 和合本雅偉版 is the 和合本 with
the divine name restored, so the published text settles a disagreement —
it is the same sentence.

**Not a general sweep.** `CHARACTER` entries are applied everywhere only
where the character cannot be right anywhere in this edition; anything
that depends on the sentence goes in `VERSE` and touches one verse.
和合本 is not internally consistent — 出埃及記 25:13 writes 槓 for the
poles and 27:10 writes 杆 for the same object — so a class verdict is not
a licence to replace globally, and the 128 classes still open are open
for exactly that reason.

Usage:
    tools/repair_cuv_tr_named_words.py [--write] [--repo <path>]
"""
import json
import os
import sys

# Characters no path produces in this edition, so wrong wherever they are.
CHARACTER = [
    # 麽 is in neither HKVariants nor TWVariants, and OpenCC's base
    # STCharacters maps 么 → 麼 outright: no profile, Hong Kong or
    # Taiwan, produces 麽. The 和合本 writes 甚麼 (創世記 2:19).
    ('麽', '麼', '創世記 2:19 看他叫甚麼'),
]

# One verse each, where a word sits in the wrong place. The first field
# names the edition, because a displaced word is not a script question
# and the same sentence can be wrong in both files.
VERSE = [
    # 耶利米書 4:22. The 和合本 reads 「我的百姓愚頑，不認識我；他們是
    # 愚昧無知的兒女」 — this file had the 我 one clause late, so the
    # sentence said the people do not know [nothing] and were "my"
    # ignorant children. The publisher's own text has it right; this is
    # ours.
    ('cuvs-yhwh-tr.json', '024004022',
     '我的百姓愚頑，不認識；他們是愚昧無知的我兒女',
     '我的百姓愚頑，不認識我；他們是愚昧無知的兒女',
     '耶利米書 4:22 繁'),
    # And the same displacement in the Simplified file, which is where it
    # came from: the publisher's own 简体 reads 「不认识我；他们是愚昧无知
    # 的儿女」. Found by `test/edition_script_purity_test.dart`, which
    # asks the Traditional edition to convert back to the Simplified one
    # and named this verse the moment only one of the two was repaired.
    ('cuvs-yhwh.json', '024004022',
     '我的百姓愚顽，不认识；他们是愚昧无知的我儿女',
     '我的百姓愚顽，不认识我；他们是愚昧无知的儿女',
     '耶利米書 4:22 简'),
    # 申命記 27:15. The over-conversion repair reverted 製造 to 制造 here
    # and nowhere else — it fires when our Simplified, the official
    # Traditional and this file's pair list all agree, and at this one
    # position the official's own conversion is wrong. The published
    # 和合本 reads 「有人製造耶和華所憎惡的偶像」, and this edition writes
    # 製造 at all 40 other places. Named rather than swept, because the
    # 157 制/製 positions are otherwise correct as they stand.
    ('cuvs-yhwh-tr.json', '005027015',
     '有人制造雅偉所憎惡的偶像',
     '有人製造雅偉所憎惡的偶像',
     '申命記 27:15 繁'),
]


def main():
    write = '--write' in sys.argv
    repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if '--repo' in sys.argv:
        repo = os.path.abspath(sys.argv[sys.argv.index('--repo') + 1])
    editions = {}

    def load(name):
        if name not in editions:
            path = os.path.join(repo, 'assets', name)
            editions[name] = [json.load(open(path, encoding='utf-8')), 0]
        return editions[name]

    rows, _ = load('cuvs-yhwh-tr.json')
    for wrong, right, ref in CHARACTER:
        n = sum(r['text'].count(wrong) for r in rows)
        for r in rows:
            if wrong in r['text']:
                r['text'] = r['text'].replace(wrong, right)
        print('  %s -> %s  %5d   (%s)' % (wrong, right, n, ref))
        editions['cuvs-yhwh-tr.json'][1] += n

    for name, vid, before, after, ref in VERSE:
        entry = load(name)
        hit = next((r for r in entry[0] if r['id'] == vid), None)
        if hit is None:
            print('  %s — no such verse' % ref)
            continue
        if before in hit['text']:
            hit['text'] = hit['text'].replace(before, after)
            print('  %s — repaired' % ref)
            entry[1] += 1
        elif after in hit['text']:
            print('  %s — already right' % ref)
        else:
            print('  %s — REFUSED: the text is neither form' % ref)

    for name, (rows, moved) in sorted(editions.items()):
        if write and moved:
            path = os.path.join(repo, 'assets', name)
            with open(path, 'w', encoding='utf-8') as f:
                json.dump(rows, f, ensure_ascii=False, indent=2)
                f.write('\n')
            print('WROTE %s' % path)
    if not write:
        print('(dry run; pass --write)')


if __name__ == '__main__':
    main()
