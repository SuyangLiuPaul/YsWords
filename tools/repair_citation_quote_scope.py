#!/usr/bin/env python3
"""Move three opening quotation marks that sit INSIDE the citation they open.

馬太福音 1:23, 馬太福音 16:14 and 羅馬書 8:36 each introduce quoted material
with a colon — 說：/如經上所記： — and then place the opening 「 not there but
after a `；` in the middle of the quotation. The first half of the quoted
scripture therefore reads as the narrator's own words:

    如經上所記：我們為你的緣故終日被殺；「人看我們如將宰的羊。」

Both halves are 詩篇 44:22. On screen today the verse says only the second
half is what is written; that is a false statement about scripture, which is
why this is P0 rather than typography.

Every repair MOVES one existing mark. No character is added, deleted or
otherwise reordered, and the closing mark is not touched — the tool asserts
that the repaired text is a permutation of the original with the quote
relocated and nothing else changed.

**The class is bounded and fully enumerated, so this is not a sweep.** The
Traditional text holds `；「`/`；『` at exactly 7 positions in 5 verses. Three
are these; the other two are CORRECT and are pinned by the test so no later
pass takes them:
  * 哥林多前書 1:12 `「我是屬保羅的」；「我是屬亞波羅的」…` — the `；` follows a
    CLOSING mark, so each quote opens where it should. Byte-identical to the
    witness.
  * 哥林多前書 15:33 `你們不要自欺；「濫交是敗壞善行。」` — a proverb quoted
    after a semicolon with no introducing colon, so there is nowhere to move
    the mark to. 梁家鏗 quotes the same words and only those words.

Four lines of evidence, and deliberately not the same line three times:

1. **The witness settles 馬太福音 16:14 outright.** `git cat-file -p 7a2dc43`
   (assets/cuv-tr.json, the plain 和合本 Traditional dropped at v1.4.5 — a
   separate transcription line, 那裡/甚麼 against our 那裏/什麽) reads
   他們說：「有人說是施洗的約翰；…一位。」 It holds `；「` at ONE position in
   all 31,102 verses, 哥林多前書 1:12, and is byte-identical to us there.

2. **Our own tagged corpus settles 馬太福音 1:23 — and it is independent on
   this mark, because it DISAGREES with our reading text.** It joins to
   说：“必有童女怀孕生子；人要称他的名为以马内利。” — already the proposed
   position, with no quote before 人要称. Same file shares our defect at
   馬太福音 16:14 and 羅馬書 8:36, so it is not a blanket normaliser.

3. **羅馬書 8:36 rests on internal evidence, and it is strong.** Our own
   詩篇 44:22 reads 我們為你的緣故終日被殺；人看我們如將宰的羊。 — the two
   halves as one sentence, so the citation begins at 我們. And of the 20
   `所記：` in our Traditional text, 18 are immediately followed by 「; the
   only other exception, 哥林多前書 1:31, carries no quotation marks at all.
   羅馬書 8:36 is the single place where 所記： is followed by unquoted text
   that then opens a quote later in the same citation.

4. **梁家鏗's independent NT corroborates the unit boundary at all three.**
   `assets/biblexg-v2-tr.json` reads 他們說：“有的說是洗者約翰，…” at
   馬太福音 16:14; at 馬太福音 1:23 and 羅馬書 8:36 it sets the whole citation
   as one unbroken block. It cannot say which mark this edition should use,
   but it says where the quoted material starts.

**Why MOVE and not DELETE.** The two external witnesses have no quotation
marks in the clause at all at 馬太福音 1:23 and 羅馬書 8:36, so deletion is a
literal reading of them. It is rejected because this edition quotes its
citations (18 of 20 `所記：「`) and deleting would discard information the
edition chose to carry; moving keeps the convention and fixes only the scope.
Nothing in the two witnesses argues the marks should not exist — they simply
predate the convention.

Re-runnable and idempotent; refuses rather than guessing if the data moved.
"""

import json
import pathlib
import sys
from collections import Counter

ROOT = pathlib.Path(__file__).resolve().parent.parent

BIBLES = ['assets/cuvs-yhwh.json', 'assets/cuvs-yhwh-tr.json']
TAGGED_DIR = ROOT / 'assets/tagged/cuvs-yhwh'

# id -> (label, the colon the quote belongs after). The colon phrase is spelt
# out per verse rather than "the first ：" so the tool can never relocate a
# mark to a colon it was not told about.
VERSES = {
    '040001023': ('馬太福音 1:23', ('說：', '说：')),
    '040016014': ('馬太福音 16:14', ('說：', '说：')),
    '045008036': ('羅馬書 8:36', ('所記：', '所记：')),
}

OPENERS = ('「', '“')

# The tagged Strong's corpus renders the word-tap sheet from its own copy of
# the verse. It shares the defect at two of the three; 馬太福音 1:23 is
# already correct there and is deliberately absent.
TAGGED = {
    ('matthew', '16:14'): '说：',
    ('romans', '8:36'): '经上所记：',
}


def fail(msg):
    print(f'REFUSING: {msg}', file=sys.stderr)
    sys.exit(1)


def move_quote(where, text, colons):
    """Move the single `；<opener>` mark to directly after the colon phrase."""
    colon = next((c for c in colons if c in text), None)
    if colon is None:
        fail(f'{where}: none of {colons} found')
    if text.count(colon) != 1:
        fail(f'{where}: {colon!r} occurs {text.count(colon)}x, expected 1')
    hits = [f'；{o}' for o in OPENERS if f'；{o}' in text]
    if not hits:
        return None  # already repaired
    if len(hits) != 1 or text.count(hits[0]) != 1:
        fail(f'{where}: expected exactly one ；<opener>, found {hits}')
    pair = hits[0]
    opener = pair[1]
    if text.index(colon) > text.index(pair):
        fail(f'{where}: {colon!r} comes after the quote, not before it')
    fixed = text.replace(pair, '；', 1).replace(colon, colon + opener, 1)
    if Counter(fixed) != Counter(text):
        fail(f'{where}: repair changed the characters, not just their order')
    if fixed.replace(opener, '') != text.replace(opener, ''):
        fail(f'{where}: repair moved something other than the quote mark')
    return fixed


def repair_bible(rel):
    path = ROOT / rel
    verses = json.loads(path.read_text(encoding='utf-8'))
    seen, fixed = set(), 0
    for v in verses:
        if v['id'] not in VERSES:
            continue
        label, colons = VERSES[v['id']]
        seen.add(v['id'])
        out = move_quote(f'{rel} {label}', v['text'], colons)
        if out is not None:
            v['text'] = out
            fixed += 1
    missing = set(VERSES) - seen
    if missing:
        fail(f'{rel}: verses not found: {sorted(missing)}')
    path.write_text(
        json.dumps(verses, ensure_ascii=False, indent=2) + '\n',
        encoding='utf-8')
    return fixed


def repair_tagged():
    fixed = 0
    for (book, ref), colon in sorted(TAGGED.items()):
        path = TAGGED_DIR / f'{book}.json'
        data = json.loads(path.read_text(encoding='utf-8'))
        runs = data.get(ref)
        if runs is None:
            fail(f'{path}: {ref} not found')
        where = f'{book} {ref}'
        before = ''.join(r['w'] for r in runs)
        holders = [r for r in runs if r['w'].endswith('；“')]
        if not holders:
            continue  # already repaired
        if len(holders) != 1:
            fail(f'{where}: {len(holders)} runs end ；“, expected 1')
        targets = [r for r in runs if r['w'].endswith(colon)]
        if len(targets) != 1:
            fail(f'{where}: {len(targets)} runs end {colon!r}, expected 1')
        if runs.index(targets[0]) > runs.index(holders[0]):
            fail(f'{where}: the colon run comes after the quote run')
        holders[0]['w'] = holders[0]['w'][:-1]
        targets[0]['w'] += '“'
        after = ''.join(r['w'] for r in runs)
        if Counter(after) != Counter(before):
            fail(f'{where}: repair changed the characters of the verse')
        path.write_text(
            json.dumps(data, ensure_ascii=False, separators=(',', ':')),
            encoding='utf-8')
        fixed += 1
    return fixed


def main():
    total = 0
    for rel in BIBLES:
        n = repair_bible(rel)
        print(f'{rel}: {n} quotation marks moved to the citation opening')
        total += n
    n = repair_tagged()
    print(f'assets/tagged/cuvs-yhwh: {n} moved')
    print(f'total: {total + n}')


if __name__ == '__main__':
    main()
