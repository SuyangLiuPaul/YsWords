#!/usr/bin/env python3
"""Repair the second-level quotation mark in five of Revelation's seven letters.

啟示錄 2:1, 2:8, 2:12, 2:18 and 3:1 read 「你要寫信給…的使者，說：「那…的，說：
— a quotation opening while the quotation it sits inside is still open, written
with the FIRST-level mark. This edition's second-level mark is 『』, which it
uses 660 times, including inside Revelation itself at 18:7
(心裏說：『我坐了皇後的位…』).

FIVE substitutions, 說：「 → 說：『, in all three assets. Nothing is inserted,
nothing is deleted, no Chinese character moves, and in the tagged corpus each
edit falls inside one existing run, so no Strong's number or parsing code is
touched.

**These five are the only ones of their kind, and the scope of that claim
matters.** Counting per VERSE — a 「 that opens while a 「 opened *in the same
verse* is still open — there are exactly five in all 31,102 verses, and they
are these. Counted per CHAPTER the number is 603, but those are a different
thing: this edition reopens 「 at a paragraph break without closing the previous
one (144 verses where the witness simply begins with an ordinary character,
five of them in Revelation: 2:13, 4:11, 18:14, 18:16, 22:14). Within a single
verse there is no paragraph break to explain it, which is why the per-verse
scope is the meaningful one and is stated rather than left implied.

Corroborated by `git cat-file -p 7a2dc43` (assets/cuv-tr.json, the plain
和合本 Traditional dropped at v1.4.5), which reads 『 at all five. It is NOT an
independent line — same punctuated 和合本 tradition, and a more heavily
punctuated recension than ours (5,856 「 to our 3,425) — so it corroborates a
defect found from our own text; it does not decide what this edition should do.
The printed 1919 cannot arbitrate at all: it has no ：and no quotation marks of
any kind. The Greek is a genuine second-level quotation — τῷ ἀγγέλῳ … γράψον·
Τάδε λέγει ὁ κρατῶν, "write: 'These things says the one who holds…'".

**The 『 is left UNCLOSED, and that is deliberate.** An earlier draft of this
repair also inserted 』 before the closing 」 at 2:7, 2:11, 2:17, 2:29 and 3:6.
The refuter broke it: this edition leaves a 說：『 running to the end of its
discourse with no closer at 申命記 32:20, 路加福音 15:17, 使徒行傳 7:6 and
throughout the 申命記 5 Decalogue block — 13 unclosed 『 by a stack over the
whole corpus, 18 by the raw 660/642 difference. So the unclosed shape is this
edition's own, and the five insertions would have been an editorial improvement
rather than a repair.

The substitution is safe precisely because it is independent of that question:
before it, 2:7's single 」 arrives with two 「 open; after it, with a 「 and a 『
open. **It neither creates nor removes an unclosed quotation — it only puts the
right mark on the level that was already nested.** Whether to close them is
filed in docs/autonomous-queue.md with both positions, along with 3:7 / 3:14,
which leave the level-2 speech unmarked altogether: that happens in 331 verses
where the witness marks it, so those two are members of a house-style class
rather than casualties of this repair.

Re-runnable and idempotent; refuses rather than guessing if the data has moved.
"""

import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

BIBLES = ['assets/cuvs-yhwh.json', 'assets/cuvs-yhwh-tr.json']
TAGGED = ROOT / 'assets/tagged/cuvs-yhwh/revelation.json'

# The five letters, by verse id and by the tagged corpus's own reference.
OPENERS = {
    '066002001': '2:1',
    '066002008': '2:8',
    '066002012': '2:12',
    '066002018': '2:18',
    '066003001': '3:1',
}

# One table serves both scripts.
FORMS = [('說：「', '說：『'), ('说：“', '说：‘')]


def fail(msg):
    print(f'REFUSING: {msg}', file=sys.stderr)
    sys.exit(1)


def substitute(where, text):
    """說：「 → 說：『. Returns the new text, or None if already repaired."""
    matches = [(p, r) for p, r in FORMS if p in text]
    if not matches:
        return None
    if len(matches) != 1:
        fail(f'{where}: both script forms present')
    pattern, replacement = matches[0]
    if text.count(pattern) != 1:
        fail(f'{where}: {pattern!r} occurs {text.count(pattern)}x, expected 1')
    return text.replace(pattern, replacement)


def repair_bible(rel):
    path = ROOT / rel
    verses = json.loads(path.read_text(encoding='utf-8'))
    by_id = {}
    for v in verses:
        by_id.setdefault(v['id'], v)
    fixed = 0
    for vid in OPENERS:
        v = by_id.get(vid)
        if v is None:
            fail(f'{rel}: verse {vid} not found')
        new = substitute(f'{rel} {vid}', v['text'])
        if new is not None:
            v['text'] = new
            fixed += 1
    # Matches the file's existing formatting byte for byte, so the diff shows
    # only the repaired marks.
    path.write_text(
        json.dumps(verses, ensure_ascii=False, indent=2) + '\n',
        encoding='utf-8')
    return fixed


def repair_tagged():
    data = json.loads(TAGGED.read_text(encoding='utf-8'))
    fixed = 0
    for ref in OPENERS.values():
        runs = data.get(ref)
        if runs is None:
            fail(f'{TAGGED.name}: {ref} not found')
        hits = [r for r in runs if '说：“' in r['w']]
        if not hits:
            continue  # already repaired
        if len(hits) != 1 or hits[0]['w'].count('说：“') != 1:
            fail(f'{TAGGED.name}: {ref} 说：“ is not unique')
        hits[0]['w'] = hits[0]['w'].replace('说：“', '说：‘')
        fixed += 1
    TAGGED.write_text(
        json.dumps(data, ensure_ascii=False, separators=(',', ':')),
        encoding='utf-8')
    return fixed


def main():
    total = 0
    for rel in BIBLES:
        n = repair_bible(rel)
        print(f'{rel}: {n} 說：「 → 說：『')
        total += n
    n = repair_tagged()
    print(f'assets/tagged/cuvs-yhwh/revelation.json: {n} 说：“ → 说：‘')
    print(f'total: {total + n} second-level quotation openings repaired')


if __name__ == '__main__':
    main()
