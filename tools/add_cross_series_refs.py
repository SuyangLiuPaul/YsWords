#!/usr/bin/env python3
"""Give each 在十字架下 episode the scripture it is built on.

    python3 tools/add_cross_series_refs.py --check
    python3 tools/add_cross_series_refs.py

Re-runnable and idempotent. Every reference is checked against
`assets/cuvs-yhwh.json` before it is written, and the script exits
non-zero if one does not resolve.

WHY THE VERIFICATION IS NOT CEREMONY
------------------------------------
The queue's instruction was "transcribe them from the page and verify
each against our own text before shipping — a citation that opens the
wrong passage is P0, and this is the exact shape of that defect."

**The source page has one.** `yahwehdehua.net/assets/page/easter/`
prints, in the Chinese block of episode 9:

    "我渴了 !"  (约 19:28)
    "成了 !"    (约 19:28)     ← wrong

Checked against our own text: 约 19:28 is 「我渴了」 and 约 19:30 is
「成了！」. The English block of the same episode has it right — Jn 19:28
then Jn 19:30. Transcribed faithfully, tapping 「成了！」 would have opened
"I thirst". The list below carries 19:30, and that is the one deliberate
departure from the page.

Two smaller things, both checked rather than assumed:

* Episode 8's Chinese block cites `Mk 15:34` — an English abbreviation
  sitting in a Chinese block. It points at the right verse, so it is
  transcribed as Mark 15:34 and nothing is "fixed".
* Episode 10 appeared to carry `Lk 9:22-23` and `Acts 5:30-31`. It does
  not — a first extraction ran past the end of the block into the song
  lyrics further down the page. Episode 10 cites Luke 23:46 alone.
* Episode 1 cites nothing at all, on either language's block.

Book names are stored in English and localised at render time by the
app's existing `localeAwareBookName`, so this file does not have to
carry three spellings of every book.
"""
import argparse
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VIDEOS = os.path.join(ROOT, 'assets/videos.json')
BIBLE = os.path.join(ROOT, 'assets/cuvs-yhwh.json')

EN_TO_ZH = {
    'Matthew': '马太福音', 'Mark': '马可福音', 'Luke': '路加福音',
    'John': '约翰福音', 'Psalms': '诗篇', 'Acts': '使徒行传',
}

# Episode number -> references, in the order the page presents them.
REFS = {
    1: [],
    2: [('Luke', 23, 34)],
    3: [('Mark', 15, 30), ('Matthew', 27, 42)],
    4: [('Matthew', 27, 40), ('Mark', 15, 32),
        ('Luke', 23, 35), ('Luke', 23, 37), ('Luke', 23, 39)],
    5: [('Luke', 23, 42), ('Luke', 23, 43)],
    6: [('Psalms', 22, 8)],
    7: [('John', 19, 26), ('John', 19, 27)],
    8: [('Mark', 15, 34)],
    # 19:30, NOT the 19:28 the page's Chinese block repeats. See above.
    9: [('John', 19, 28), ('John', 19, 30)],
    10: [('Luke', 23, 46)],
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--check', action='store_true')
    args = ap.parse_args()

    with open(BIBLE, encoding='utf-8') as fh:
        verses = json.load(fh)
    present = {(v['book'], str(v['chapter']), str(v['verse'])) for v in verses}

    bad = []
    for n, refs in REFS.items():
        for book, ch, vs in refs:
            zh = EN_TO_ZH.get(book)
            if zh is None or (zh, str(ch), str(vs)) not in present:
                bad.append(f'episode {n}: {book} {ch}:{vs}')
    if bad:
        print('REFUSE: these do not resolve in assets/cuvs-yhwh.json:')
        for b in bad:
            print('   ', b)
        sys.exit(1)
    total = sum(len(r) for r in REFS.values())
    print(f'{total} references, all resolve against our own text')

    with open(VIDEOS, encoding='utf-8') as fh:
        doc = json.load(fh)
    series = next((s for s in doc['series'] if s['id'] == 'cross'), None)
    if series is None:
        sys.exit('REFUSE: no "cross" series in videos.json')
    if len(series['episodes']) != 10:
        sys.exit(f'REFUSE: cross has {len(series["episodes"])} episodes, '
                 'expected 10')

    changed = 0
    for ep in series['episodes']:
        want = [{'book': b, 'chapter': c, 'verse': v}
                for b, c, v in REFS.get(ep['number'], [])]
        if ep.get('refs') != want:
            changed += 1
            if not args.check:
                ep['refs'] = want
    print(f'episodes needing a change: {changed}')

    if args.check:
        print('--check: nothing written.')
        return
    if changed:
        with open(VIDEOS, 'w', encoding='utf-8') as fh:
            json.dump(doc, fh, ensure_ascii=False, indent=2)
            fh.write('\n')
        print(f'wrote {VIDEOS}')
    else:
        print('nothing to do.')


if __name__ == '__main__':
    main()
