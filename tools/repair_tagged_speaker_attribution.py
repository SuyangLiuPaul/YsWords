#!/usr/bin/env python3
"""Close three quotations in the word-tap corpus that swallow the reply.

The 2026-08-24 repair fixed nine verses where one speaker's marks ran on over
another speaker's words. It diffed the READING text against the witness, so it
could only ever find verses the reading text marks up at all — and the tagged
corpus at `assets/tagged/cuvs-yhwh/` is a different transcription line that
carries quotation marks in 4,043 verses where the reading text carries none.
Three of those are the same defect, and no detector had ever looked there:

  撒母耳記上 16:11  說：“你的兒子都在這裏嗎？他回答說：“還有個小的…
  列王紀下 10:13    問他們說：“你們是誰？回答說：“我們是亞哈謝的弟兄…
  撒母耳記下 15:19  說：“你是外邦逃來的人，為什麼“與我們同去呢？

At the first two the questioner's quotation is never closed, so the word-tap
sheet shows Samuel asking whether all Jesse's sons are present and answering
himself, and Jehu asking "who are you" and answering himself. The third is a
stray opening mark mid-clause, with no speech verb anywhere near it.

Each edit is one punctuation character. The witness `7a2dc43` reads
「你的兒子都在這裡嗎？」他回答說, 「你們是誰？」回答說 and — at 撒下 15:19 —
為甚麼與我們同去呢 with no mark at all, so it puts a mark at exactly the two
positions chosen and none at the third.

**That witness CORROBORATES; it is not independent, and saying so matters.**
Its quotation marks sit at the same ideograph offset as this corpus's in 6,461
of the 6,631 verses where both mark — 97.4%. The two descend from one
punctuated 和合本 tradition. That does not weaken the repair, it sharpens it:
when a corpus agrees with its tradition 97% of the time, the handful of places
where it diverges *and* leaves a questioner's quotation open are losses in our
copy rather than editorial variants. The independent lines are the other two —
each verse balances after the edit and did not before, and the reading text
carries no marks here at all, so nothing behind the sheet ever said otherwise.
"""
import json
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TAGGED = os.path.join(REPO, 'assets', 'tagged', 'cuvs-yhwh')
MARKS = '“”‘’'

# (book file, verse key, run index, before, after)
EDITS = (
    ('1_samuel', '16:11', 6, '吗？他回答说：“', '吗？”他回答说：“'),
    ('2_kings', '10:13', 7, '是谁？', '是谁？”'),
    ('2_samuel', '15:19', 8, '为什么“与我们', '为什么与我们'),
)


def verse_text(runs):
    return ''.join(r.get('w', '') for r in runs)


def signature(runs):
    """Everything that must NOT change: run count, per-run Strong's data, and
    the verse text with every quotation mark removed."""
    return (
        len(runs),
        [(r.get('s'), tuple(r.get('i', ())), tuple(r.get('g', ()))) for r in runs],
        ''.join(c for c in verse_text(runs) if c not in MARKS),
    )


def main():
    changed = 0
    for book, key, idx, before, after in EDITS:
        path = os.path.join(TAGGED, book + '.json')
        with open(path, encoding='utf-8') as fh:
            data = json.load(fh)
        runs = data[key]
        got = runs[idx].get('w')
        if got == after:
            print(f'  {book} {key}: already repaired')
            continue
        if got != before:
            sys.exit(f'ABORT {book} {key} run {idx}: expected {before!r}, '
                     f'found {got!r} — the file has drifted, not repairing')
        old = signature(runs)
        runs[idx]['w'] = after
        if signature(runs) != old:
            sys.exit(f'ABORT {book} {key}: the edit changed more than a '
                     f'quotation mark')
        with open(path, 'w', encoding='utf-8') as fh:
            json.dump(data, fh, ensure_ascii=False, separators=(',', ':'))
        print(f'  {book} {key}: {before!r} -> {after!r}')
        changed += 1

    for book, key, _, _, _ in EDITS:
        with open(os.path.join(TAGGED, book + '.json'), encoding='utf-8') as fh:
            text = re.sub(r'〔.*?〕', '', verse_text(json.load(fh)[key]))
        if re.search(r'“[^“”]*“', text):
            sys.exit(f'ABORT {book} {key}: still nests “ inside “')
    print(f'{changed} run(s) changed')
    return 0


if __name__ == '__main__':
    sys.exit(main())
