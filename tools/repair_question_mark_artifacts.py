#!/usr/bin/env python3
"""Remove the ASCII question marks wedged into running scripture in the CUV.

Nine marks in five verses, present *identically* in the Simplified and the
Traditional asset — which is what says they are upstream of the script
conversion rather than caused by it. They have been there since the very first
import of the asset (commit 3757063):

  士師記 6:33   在耶斯列??平原安營
  列王紀上 2:5  將這血染了??腰間束的帶
  以西結書 16:4  也沒有??用布裹你
  以西結書 16:43 向我發烈怒??，所以
  以西結書 20:9  在他們所住?的列國人眼前

WHY THIS IS A DELETION AND NOT A RESTORATION
  `??` is the classic mojibake signature of a lost double-byte character, and
  the queue held this item back for exactly that reason: deleting a mark that
  stands in for a dropped word would silently conceal a textual loss, which is
  the worst failure this corpus can have. So every slot was read against
  witnesses before anything was touched, and the finding is the opposite —
  nothing is missing:

  * The plain Traditional 和合本 (git blob 7a2dc43, dropped at v1.4.5) reads
    all five verses exactly as ours reads with the marks removed. Four match
    character for character; 列王紀上 2:5 differs only elsewhere in the verse
    (益帖兒子 / 益帖的兒子).
  * An independently imported Simplified 和合本 outside this repo agrees, and
    is demonstrably a different digitisation — it disagrees with the first
    witness in thousands of verses on 約旦/約但, 甚麼/什麼, 毘/毗.
  * **Our own tagged Strong's corpus is a third witness, and it is the same
    雅偉 edition** — `assets/tagged/cuvs-yhwh` carries 士 6:33, 王上 2:5,
    結 16:4 and 結 20:9 with no character at the slot at all. So the publisher's
    own text has nothing there; this is not a place where our edition departs
    from the CUV.
  * The Hebrew leaves no room for a word: 士 6:33 בְּעֵמֶק יִזְרְעֶאל,
    結 16:4 וְהָחְתֵּל לֹא חֻתָּלְתְּ, 結 16:43 וַתִּרְגְּזִי בְּכָל אֵלֶּה,
    結 20:9 אֲשֶׁר הֵמָּה בְתוֹכָם, 王上 2:5 בַּחֲגֹרָתוֹ אֲשֶׁר בְּמָתְנָיו.
  * An encoding failure yields `?` only for characters missing from the
    charset, i.e. rare ones. Every slot here sits inside an ordinary CUV
    sentence that is already complete, and 結 20:9 carries an ODD number of
    marks, which no double-byte pairing produces.

  Characters really are dropped elsewhere in this corpus — 士師記 12:13 reads
  「作以色的士師」 for 以色列 — but those losses leave no marker at all. It is a
  different defect, queued separately.

THE TWO SUBSTITUTIONS IN THE TAGGED CORPUS
  約伯記 15:12 and 15:16 end with a half-width `?` in the tagged corpus where
  the mark is not a question at all. Our own main asset, both witnesses and the
  sense of the passage agree on what belongs there: 15:12 「冒出火星，」 runs on
  into v.13, and 15:16 「的世人呢！」 closes an exclamation. Three witnesses at
  one position each, so these are read rather than ruled.

Re-runnable, and refuses rather than guessing if the data has moved.
"""

import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

BIBLES = ['assets/cuvs-yhwh.json', 'assets/cuvs-yhwh-tr.json']
TAGGED_DIR = ROOT / 'assets/tagged/cuvs-yhwh'

# Verse id -> how many marks that verse must carry. The count is part of the
# check: a verse that has grown or lost one since this was measured means the
# asset moved under the tool and it should refuse rather than sweep.
STRAYS = {
    '007006033': 2,   # 士師記 6:33
    '011002005': 2,   # 列王紀上 2:5
    '026016004': 2,   # 以西結書 16:4
    '026016043': 2,   # 以西結書 16:43
    '026020009': 1,   # 以西結書 20:9
}

TAGGED_STRAYS = {('ezekiel', '16:43'): ('??', '')}

TAGGED_MARKS = {
    ('job', '15:12'): ('冒出火星?', '冒出火星，'),
    ('job', '15:16'): ('呢?', '呢！'),
}


def fail(msg):
    print(f'REFUSING: {msg}', file=sys.stderr)
    sys.exit(1)


def repair_bible(rel):
    path = ROOT / rel
    verses = json.loads(path.read_text(encoding='utf-8'))
    seen = {}
    removed = 0
    for v in verses:
        text = v['text']
        if '?' not in text:
            continue
        seen[v['id']] = seen.get(v['id'], 0) + text.count('?')
        if v['id'] not in STRAYS:
            fail(f'{rel} {v["id"]}: an unlisted verse carries "?"')
        removed += text.count('?')
        v['text'] = text.replace('?', '')
    if seen != STRAYS:
        fail(f'{rel}: expected {STRAYS}, found {seen}')
    # Matches the file's existing formatting byte for byte, so the diff shows
    # only the repaired verses.
    path.write_text(
        json.dumps(verses, ensure_ascii=False, indent=2) + '\n',
        encoding='utf-8')
    return removed


def repair_tagged():
    removed = 0
    substituted = 0
    for path in sorted(TAGGED_DIR.glob('*.json')):
        book = path.stem
        data = json.loads(path.read_text(encoding='utf-8'))
        touched = False
        for ref, runs in data.items():
            entry = TAGGED_STRAYS.get((book, ref)) or TAGGED_MARKS.get(
                (book, ref))
            if entry is None:
                if any('?' in r.get('w', '') for r in runs):
                    fail(f'{path}: {ref} carries an unlisted "?"')
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
            if replacement:
                substituted += 1
            else:
                removed += len(pattern)
            touched = True
        if touched:
            path.write_text(
                json.dumps(data, ensure_ascii=False, separators=(',', ':')),
                encoding='utf-8')
    return removed, substituted


def main():
    total = 0
    for rel in BIBLES:
        removed = repair_bible(rel)
        print(f'{rel}: {removed} stray "?" removed')
        total += removed
    removed, substituted = repair_tagged()
    print(f'assets/tagged/cuvs-yhwh: {removed} stray "?" removed, '
          f'{substituted} half-width marks corrected')
    total += removed
    print(f'total: {total} stray "?" removed, {substituted} marks corrected')


if __name__ == '__main__':
    main()
