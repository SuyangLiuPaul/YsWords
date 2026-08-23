#!/usr/bin/env python3
"""Repair five verses where a quotation opens with a semicolon.

列王紀上 22:13, 路加福音 13:2, 約翰福音 7:45, 約翰福音 9:9 and 希伯來書 3:11
read 「說；」 at the point where direct speech begins — 耶穌說；「你們以為…」.
The mark that introduces speech in this edition is the full-width colon; a
semicolon joins two independent clauses and cannot open a quotation.

Every repair SUBSTITUTES one punctuation mark. No Chinese character is added,
removed or moved, and no other mark in the verse is touched.

**The corpus holds 15 「說；」 and TEN OF THEM ARE CORRECT**, so this cannot be
a blanket substitution and is written as five pinned verse ids instead.
約伯記 28:27 「而且述說；他堅定」, 士師記 8:8, 加拉太書 2:2 and the rest are a
clause ending in 說 followed by a legitimate semicolon.

Three lines of evidence, and they are deliberately not the same line twice:

1. **The witness.** `git cat-file -p 7a2dc43` (assets/cuv-tr.json, the plain
   和合本 Traditional, 耶和華 rather than this edition's 雅偉, dropped at
   v1.4.5) reads `：` at exactly these five and `；` at the other ten —
   perfect discrimination across all 14 comparable verses. It is a separate
   digital line, not a copy of ours: it sets 那裡/甚麼/毘 where we set
   那裏/什麽/毗, and it is not a blanket "colon after 說" normaliser either,
   carrying 325 `說，` and 91 bare `說「` of its own.

2. **Our own tagged corpus**, which shares the `；` — same lineage, so it is
   NOT independent on the mark — but carries an OPENING quotation mark
   immediately after it at all five, including 列王紀上 22:13 where our
   running text has no quotation marks at all. A semicolon cannot introduce
   direct speech, so whatever stands there is a speech mark. Its Strong's
   tags say the same: 列王紀上 22:13 runs H559 (אָמַר) with H2009+H4994
   (הִנֵּה־נָא, "behold now") opening the quoted words, and 希伯來書 3:11
   runs G1487, the Hebraic oath formula of Psalm 95:11.

3. **Frequency inside our own text**, notes stripped: this edition opens a
   quotation with `：「` 2,689 times and `：『` 547 times. `；「` occurs ten
   times and `；『` once; of those eleven, four are the disputed verses, two
   are legitimate (哥林多前書 1:12 and 15:33, where the `；` closes a
   preceding clause rather than following 說) and three are a separate
   suspected defect left alone here.

**The printed 1919 does NOT arbitrate this and was not used as if it did.**
Its punctuation is only `、` and `．`; it has no `：` and no quotation marks
anywhere, and it sets `、` after 說 at three of the TEN legitimate verses
(列王紀上 2:19, 約伯記 33:33, 約伯記 37:19). It can say a quotation begins;
it cannot say which modern mark belongs there.

Two things deliberately left, both filed in docs/autonomous-queue.md:
約翰福音 9:9's other half — ours reads 「是他；」 where the witness reads
「是他」；, which MOVES a mark rather than substituting one — and the wider
class of 說 followed by `，` or by nothing before an opening quote (20 and 59
positions), most of which are legitimate embedded quotations such as
馬太福音 21:25 「我們若說『從天上來』」.

Re-runnable, and refuses rather than guessing if the data has moved.
"""

import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

BIBLES = ['assets/cuvs-yhwh.json', 'assets/cuvs-yhwh-tr.json']
TAGGED_DIR = ROOT / 'assets/tagged/cuvs-yhwh'

# The five verses. The pattern is 說 plus the mark, which is enough on its own:
# each of these verses contains 說； exactly once, and the count is asserted
# before anything is written. Both script forms are listed so one table serves
# the Simplified and the Traditional file.
SPEECH = {
    '011022013': '列王紀上 22:13',
    '042013002': '路加福音 13:2',
    '043007045': '約翰福音 7:45',
    '043009009': '約翰福音 9:9',
    '058003011': '希伯來書 3:11',
}

FORMS = [('說；', '說：'), ('说；', '说：')]

# The same five inside the tagged Strong's corpus, which renders the word-tap
# sheet from its own copy of the verse and so shows the defect on screen too.
TAGGED = {
    ('1_kings', '22:13'),
    ('luke', '13:2'),
    ('john', '7:45'),
    ('john', '9:9'),
    ('hebrews', '3:11'),
}


def fail(msg):
    print(f'REFUSING: {msg}', file=sys.stderr)
    sys.exit(1)


def repair_bible(rel):
    path = ROOT / rel
    verses = json.loads(path.read_text(encoding='utf-8'))
    seen = set()
    fixed = 0
    for v in verses:
        if v['id'] not in SPEECH:
            continue
        seen.add(v['id'])
        text = v['text']
        matches = [(p, r) for p, r in FORMS if p in text]
        if not matches:
            continue  # already repaired
        if len(matches) != 1:
            fail(f'{rel} {v["id"]}: both script forms present')
        pattern, replacement = matches[0]
        if text.count(pattern) != 1:
            fail(f'{rel} {v["id"]}: {pattern!r} occurs '
                 f'{text.count(pattern)}x, expected exactly 1')
        v['text'] = text.replace(pattern, replacement)
        fixed += 1
    missing = set(SPEECH) - seen
    if missing:
        fail(f'{rel}: verses not found: {sorted(missing)}')
    # Matches the file's existing formatting byte for byte, so the diff shows
    # only the repaired marks.
    path.write_text(
        json.dumps(verses, ensure_ascii=False, indent=2) + '\n',
        encoding='utf-8')
    return fixed


def repair_tagged():
    fixed = 0
    for book, ref in sorted(TAGGED):
        path = TAGGED_DIR / f'{book}.json'
        data = json.loads(path.read_text(encoding='utf-8'))
        runs = data.get(ref)
        if runs is None:
            fail(f'{path}: {ref} not found')
        hits = [r for r in runs if '说；' in r['w']]
        if not hits:
            continue  # already repaired
        if len(hits) != 1 or hits[0]['w'].count('说；') != 1:
            fail(f'{path}: {ref} 说； is not unique')
        hits[0]['w'] = hits[0]['w'].replace('说；', '说：')
        path.write_text(
            json.dumps(data, ensure_ascii=False, separators=(',', ':')),
            encoding='utf-8')
        fixed += 1
    return fixed


def main():
    total = 0
    for rel in BIBLES:
        n = repair_bible(rel)
        print(f'{rel}: {n} 說；→ 說：')
        total += n
    n = repair_tagged()
    print(f'assets/tagged/cuvs-yhwh: {n} 说；→ 说：')
    print(f'total: {total + n} quotation openings repaired')


if __name__ == '__main__':
    main()
