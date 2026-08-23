#!/usr/bin/env python3
"""Repair stray punctuation in the CUV assets.

Two defects, both present *identically* in the Simplified and the Traditional
edition — which is what says they are upstream of the script conversion rather
than caused by it:

1. `丶` (U+4E36, the CJK stroke radical — a dictionary head component, not a
   punctuation mark) stands in for the enumeration comma `、` in 53 places.
   出埃及記 15:4 reads 「法老的車輛丶軍兵」.

2. Nine verses carry an orphaned punctuation mark: 出埃及記 25:35
   「接連一塊，，。」, 民數記 26:32 「希弗族；。」, 耶利米哀歌 4:15
   「喊著說：！不潔淨的」, 撒迦利亞書 3:8 「作預兆的）。，我必使」,
   阿摩司書 6:10 「又說：，不要作聲」 and 6:14 「神說：，以色列家啊」,
   希伯來書 13:3 「同受捆綁；，也要」, 創世紀 21:7 「一個兒子。「」」
   (an empty quote pair), and 路加福音 17:36, which needed its own reading.

路加福音 17:36 is one of six verses the CUV records but does not print: its
whole text is a `<note: 有古卷在此有…>`, which the reader sees as a tappable
book icon and nothing else. It alone of the six carries a character after the
closing `>` — a `」`, `”` in the Simplified — so the reader gets an icon
followed by a bare closing bracket.

WHICH of two marks to delete was the whole question, because 17:35 also ends
`。」` and between them Jesus' discourse closes once too often. Three lines put
the close at 17:35 and nothing after the note at 17:36: our own tagged Strong's
corpus, a separate transcription line, whose 17:36 is
`〔有古卷在此有36节："…"〕` with nothing following the `〕`; 梁家鏗's
independent NT, which omits 17:36 entirely and ends 17:35 `。”`; and the five
other note-only verses, none of which carries anything after its `>`. The
printed 1919 page has no quotation marks anywhere in it, so it testifies only
to the structure — its v35 carries the 「有古卷在此有」 marker and its v36 is
wholly a note, as ours are.

Blob `7a2dc43` is the one witness that could be read the other way, and it is
worth naming rather than omitting. It keeps the variant INLINE in parentheses
across both verses — `（有古卷加：` … `）」` — and so closes after it, with no
`」` at 17:35 at all. That is a different structure, not a dissenting opinion
about ours, and it is the likeliest ORIGIN of the mark: a survivor of that
older layout, left behind when the variant was demoted into a note. Calling it
invented would overstate what is known.

Every repair is a **deletion**. Nothing is written into scripture: the witness
`git cat-file -p 7a2dc43` (assets/cuv-tr.json, the plain 和合本 Traditional,
dropped at v1.4.5) reads the text without the offending mark at all 53 + 8
positions.

The sweep behind this covers CJK punctuation only. A separate class of 72
half-width and stray ASCII marks was found alongside it and is NOT repaired
here — see docs/autonomous-queue.md; one of its members may be lost text
rather than a stray, so it needs its own reading.

Re-runnable, and refuses rather than guessing if the data has moved.
"""

import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

BIBLES = ['assets/cuvs-yhwh.json', 'assets/cuvs-yhwh-tr.json']
TAGGED_DIR = ROOT / 'assets/tagged/cuvs-yhwh'

# Verse id -> (pattern, replacement). The pattern is punctuation only, so the
# same entry serves both editions; 創世紀 21:7 is the exception because the two
# editions use different quote glyphs.
ORPHANS = {
    '002025035': [('，，。', '。')],           # 出埃及記 25:35
    '004026032': [('；。', '。')],             # 民數記 26:32
    '025004015': [('：！', '：')],             # 耶利米哀歌 4:15
    '038003008': [('。，', '。')],             # 撒迦利亞書 3:8
    '030006010': [('：，', '：')],             # 阿摩司書 6:10
    '030006014': [('：，', '：')],             # 阿摩司書 6:14
    '058013003': [('；，', '；')],             # 希伯來書 13:3
    '001021007': [('。「」', '。」'), ('。“”', '。”')],  # 創世紀 21:7
    # 路加福音 17:36 — anchored on the `>` so it can only ever strip a mark
    # standing outside the note, never one inside it.
    '042017036': [('>」', '>'), ('>”', '>')],
}

# The same orphans inside the tagged Strong's corpus, which renders the
# interlinear. 阿摩司書 6:10 and 撒迦利亞書 3:8 are already clean there.
TAGGED_ORPHANS = {
    ('exodus', '25:35'): ('，，。', '。'),
    ('numbers', '26:32'): ('；。', '。'),
    ('hebrews', '13:3'): ('；，', '；'),
    ('genesis', '21:7'): ('。“”', '。”'),
    ('lamentations', '4:15'): ('：“！', '：“'),
}


def fail(msg):
    print(f'REFUSING: {msg}', file=sys.stderr)
    sys.exit(1)


def repair_bible(rel):
    path = ROOT / rel
    verses = json.loads(path.read_text(encoding='utf-8'))
    strokes = 0
    orphans = 0
    for v in verses:
        text = v['text']
        strokes += text.count('丶')
        text = text.replace('丶', '、')
        for pattern, replacement in ORPHANS.get(v['id'], []):
            n = text.count(pattern)
            if n == 0:
                continue
            if n != 1:
                fail(f'{rel} {v["id"]}: {pattern!r} occurs {n}x, expected 1')
            text = text.replace(pattern, replacement)
            orphans += 1
        v['text'] = text
    # Matches the file's existing formatting byte for byte, so the diff shows
    # only the repaired characters.
    path.write_text(
        json.dumps(verses, ensure_ascii=False, indent=2) + '\n',
        encoding='utf-8')
    return strokes, orphans


def repair_tagged():
    strokes = 0
    orphans = 0
    for path in sorted(TAGGED_DIR.glob('*.json')):
        book = path.stem
        data = json.loads(path.read_text(encoding='utf-8'))
        touched = False
        for ref, runs in data.items():
            for run in runs:
                word = run.get('w')
                if word is None or '丶' not in word:
                    continue
                strokes += word.count('丶')
                run['w'] = word.replace('丶', '、')
                touched = True
            entry = TAGGED_ORPHANS.get((book, ref))
            if entry is None:
                continue
            pattern, replacement = entry
            hits = [r for r in runs if pattern in r.get('w', '')]
            if not hits:
                continue
            if len(hits) != 1 or hits[0]['w'].count(pattern) != 1:
                fail(f'{path}: {ref} {pattern!r} is not unique')
            hits[0]['w'] = hits[0]['w'].replace(pattern, replacement)
            if not hits[0]['w']:
                fail(f'{path}: {ref} deletion emptied a tagged run')
            orphans += 1
            touched = True
        if touched:
            path.write_text(
                json.dumps(data, ensure_ascii=False, separators=(',', ':')),
                encoding='utf-8')
    return strokes, orphans


def main():
    total_strokes = 0
    total_orphans = 0
    for rel in BIBLES:
        strokes, orphans = repair_bible(rel)
        print(f'{rel}: {strokes} 丶→、, {orphans} orphaned marks removed')
        total_strokes += strokes
        total_orphans += orphans
    strokes, orphans = repair_tagged()
    print(f'assets/tagged/cuvs-yhwh: {strokes} 丶→、, '
          f'{orphans} orphaned marks removed')
    total_strokes += strokes
    total_orphans += orphans
    print(f'total: {total_strokes} 丶→、, {total_orphans} orphaned marks')


if __name__ == '__main__':
    main()
