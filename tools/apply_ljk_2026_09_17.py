#!/usr/bin/env python3
"""梁家鏗譯本: the translator's 2026-09-17 revisions and rulings, applied.

    tools/apply_ljk_2026_09_17.py --fresh <dir> [--write]

`<dir>` holds a FRESH run of the pipeline (`import_ljk2.py` … step 5)
as biblexg-v3.json / biblexg-v3-tr.json. The shipped assets in `assets/`
are the base; this script moves across only what the translator changed
or ruled on, verse by verse, each guarded on the text it expects.

WHY NOT SHIP THE FRESH IMPORT DIRECTLY. Measured today: the fresh import
drops the placement of ~720 footnotes per script. His note blocks follow
his page layout, not his verses, and `import_ljk2.py` hangs each on the
verse it happens to sit after; the shipped assets carry each note on the
verse it names (added on 2026-09-14 by `adopt_official_ljk.py`, which
reads the website's database — and that database is now OLDER than his
files, so it cannot be re-run either: it would undo these revisions).
With notes stripped, the fresh import differs from the shipped text in
exactly the verses below. Everything else is identical.

WHAT CHANGES, and on whose authority (his WhatsApp replies to
docs/梁家鏗譯本-請教出版方.md, 2026-09-17, forwarded by the owner):

  his revisions, taken from his files as he now publishes them
    太 13:3, 13:18   撒种 → 播种
    太 21:43         closing quote moved onto 43 (see 21:44)
    路 23:8, 23:10   punctuation
    路 23:34         「父亲啊，赦免他们……」 now opens 23:34 as the
                     translator's supplied words; the sub-verse 34a is
                     gone (ruling 九), and its note is reworded
    提后 3:15        the opening clause (ruling 二)
    约一 5:15        punctuation
    约 12:36 (繁)    隱藏起來了 → 隱藏起來
    徒 8:40          「即向北沿海」 is an inline note (ruling 九); the
                     notes are his single 40节注 — the 41节 / 「另外，
                     旧译本将40、41两节合为一节」 notes he deleted are gone

  his ruling 五 — disputed verses in square brackets, note kept
    太 21:44         ［“那撞击这石头的必垮，被它压着的必粉身碎骨。”］
    约 5:4           a verse of its own, ［…］, from his own note on 5:3

  NOT taken from the fresh import (import defects, not revisions)
    罗 3:10 (简)     the importer drops his poetry node — known defect
    可 10:33 (繁)    將 → 将, a Simplified character in the Traditional
"""
import argparse
import json
import re
import sys

LEFT, RIGHT = '［', '］'


def load(p):
    return json.load(open(p, encoding='utf-8'))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--fresh', required=True)
    ap.add_argument('--write', action='store_true')
    ap.add_argument('--assets', default='assets')
    a = ap.parse_args()

    for script in ('cn', 'tw'):
        name = 'biblexg-v3.json' if script == 'cn' else 'biblexg-v3-tr.json'
        base = load(f'{a.assets}/{name}')
        fresh = {r['id']: r for r in load(f'{a.fresh}/{name}')}
        by = {r['id']: r for r in base}

        def expect(vid, needle):
            if needle not in by[vid]['text']:
                sys.exit(f'REFUSE {name} {vid}: expected {needle!r} in '
                         f'{by[vid]["text"][:120]!r}')

        def take(vid, needle):
            """Adopt the fresh text of `vid`, after checking both sides."""
            expect(vid, needle)
            by[vid]['text'] = fresh[vid]['text']

        zh = script == 'cn'
        # ── his revisions ──────────────────────────────────────────
        take('40013003', '撒种' if zh else '撒種')
        take('40013018', '撒种的农夫' if zh else '撒種的農夫')
        take('40021043', '外族。')
        take('42023008', '就大喜')
        take('42023010', '经学家，' if zh else '經學家，')
        take('62005015', '祈求，')
        if not zh:
            take('43012036', '隱藏起來了')

        # 路 23:34 — the prayer folds in, 34a goes, the note is reworded
        # and hangs on the verse it names.
        expect('42023034', '抓阄' if zh else '抓鬮')
        by['42023034']['text'] = fresh['42023034']['text']
        new34 = [n for n in fresh['42023038'].get('blockNotes', [])
                 if n.startswith('34节注' if zh else '34節註')]
        if len(new34) != 1:
            sys.exit(f'REFUSE {name}: expected one reworded 34 note')
        old38 = by['42023038'].get('blockNotes', [])
        kept = [n for n in old38 if not n.startswith('34节注' if zh else '34節註')]
        if len(kept) != len(old38) - 1:
            sys.exit(f'REFUSE {name}: expected one old 34 note on 23:38')
        by['42023038']['blockNotes'] = kept
        by['42023034']['blockNotes'] = new34
        if '42023033a' in by:
            base = [r for r in base if r['id'] != '42023033a']
            del by['42023033a']

        # 提后 3:15 — the clause, before the text readers already have
        # (the Traditional has always had it).
        clause = '而且你自幼便明白神圣的经典，' if zh else '而且你自幼便明白神聖的經典，'
        if not by['55003015']['text'].startswith(clause):
            if not fresh['55003015']['text'].startswith(clause):
                sys.exit(f'REFUSE {name}: fresh 3:15 lacks the clause')
            by['55003015']['text'] = clause + by['55003015']['text']

        # 徒 8:40 — his text, his one 40节注, inline as these assets
        # carry notes; the deleted 41 / 「另外」 notes go.
        expect('44008040', '亚锁城' if zh else '亞鎖城')
        notes40 = fresh['44008040'].get('blockNotes', [])
        if len(notes40) != 1 or not notes40[0].startswith('40节注' if zh else '40節註'):
            sys.exit(f'REFUSE {name}: expected his single 40 note')
        by['44008040']['text'] = (fresh['44008040']['text']
                                  + f'<note:{notes40[0]}>')
        by['44008040'].pop('blockNotes', None)
        if not zh:
            # his own fix: 耶稣 → 耶穌 inside the 36-38 note
            by['44008039']['blockNotes'] = fresh['44008039']['blockNotes']

        # ── ruling 五: disputed verses in square brackets ──────────
        m = re.fullmatch(r'<note:(.*)>', fresh['40021044']['text'])
        if not m:
            sys.exit(f'REFUSE {name}: 21:44 is no longer a single note')
        by['40021044']['text'] = LEFT + m.group(1).strip() + RIGHT

        note53 = re.search(r'<note:有[较較]后?後?期抄本加插4[节節]：(.*?)>',
                           by['43005003']['text'])
        if not note53:
            sys.exit(f'REFUSE {name}: 5:3 no longer carries the 5:4 note')
        if '43005004' not in by:
            r53 = by['43005003']
            v4 = dict(r53)
            v4.pop('blockNotes', None)
            v4.update({'verse': '4', 'verseLabel': '4', 'id': '43005004',
                       'text': LEFT + note53.group(1).strip() + RIGHT,
                       'isParagraphStart': False})
            base.insert(base.index(r53) + 1, v4)
            by['43005004'] = v4

        out = [by[r['id']] for r in base]
        print(f'{name}: {len(out)} records')
        if a.write:
            open(f'{a.assets}/{name}', 'w', encoding='utf-8').write(
                json.dumps(out, ensure_ascii=False, separators=(',', ':')))
    if not a.write:
        print('(dry run — pass --write)')


if __name__ == '__main__':
    main()
