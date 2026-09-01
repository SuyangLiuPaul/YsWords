#!/usr/bin/env python3
"""路加福音 23:34a — stop printing the publisher's affix as running text.

    python3 tools/repair_biblexg_luke_23_34a.py --check   # report only
    python3 tools/repair_biblexg_luke_23_34a.py           # apply

Re-runnable and idempotent: applying it twice is a no-op, and `--check`
never writes. Written as a script rather than a one-off hand edit because
`assets/biblexg-v2*.json` is scheduled to be REBUILT from the publisher's
corrected Simplified once they answer (see the queue). A rebuild throws
away hand edits; it cannot throw away a script you re-run afterwards.

WHAT IS WRONG
-------------
梁家鏗譯本 marks a doubtful passage the way the printed 註釋本 does, by
labelling the halves 34a and 34b. The import put the affix into the verse
body, so 23:33 currently reads, in both editions:

    來到那片地，名叫髑髏地，就在那裡將耶穌釘上了十字架，也釘了那兩個罪犯，
    右手一個，左手一個。34a耶穌說：父親啊，赦免他們，因為他們不曉得自己在
    做甚麼。

The characters `34a` are printed at the reader in the middle of a
sentence. It is the only occurrence in either edition — `\\d{1,3}[a-d]`
matches exactly once in each — so this is a single defect, not a class.

WHAT THIS DOES
--------------
Splits 23:33 at the affix into two entries:

    verse 33, label "33"    來到那片地…左手一個。
    verse 34, label "34a"   耶穌說：父親啊…做甚麼。      subVerseOrder 0

and marks the existing 23:34 (「然後，他們抓鬮分了耶穌的衣袍。」 — which is
really 34b) with `subVerseOrder: 1` so it sorts after 34a. Both share
`verse: 34`, and Dart's sort is unstable, so the ordinal is not optional.

WHY 34 KEEPS ITS LABEL
----------------------
The obvious move is to relabel the second half "34b" to match the print.
Do not. `Verse.id` is `<book>-<chapter>-<verseLabel>` and highlights and
notes key off it ACROSS versions, so renaming 34 → 34b would silently
move every existing highlight on Luke 23:34 in every edition. Leaving it
alone means:

    Luke-23-33     unchanged
    Luke-23-34     unchanged      ← nobody's highlight moves
    Luke-23-34a    new, collides with nothing

A highlight on 34a has no counterpart in other versions, which is honest:
no other edition in this app numbers that half-verse. The publisher's own
Simplified also keeps the second half as plain 34, so this follows the
print for the half that had no number and the publisher for the half that
had one.

REFUSALS
--------
Refuses if the verse text is not what it expects, if the split would
produce an empty half, if 23:34 is missing, or if the affix appears more
than once — each of those means the asset moved and a human should look
before a script rewrites scripture.
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

EDITIONS = [
    ('assets/biblexg-v2.json', '路加福音'),
    ('assets/biblexg-v2-tr.json', '路加福音'),
]
CHAPTER = '23'
AFFIX = '34a'


def load(path):
    with open(path, encoding='utf-8') as fh:
        return json.load(fh)


def is_minified(path):
    """True when the file is one long line (the Simplified edition)."""
    with open(path, encoding='utf-8') as fh:
        return '\n' not in fh.read(4096)


def repair(path, book, check):
    full = os.path.join(ROOT, path)
    verses = load(full)
    minified = is_minified(full)
    idx33 = idx34 = None
    for i, v in enumerate(verses):
        if v.get('book') == book and str(v.get('chapter')) == CHAPTER:
            if str(v.get('verse')) == '33':
                idx33 = i
            elif str(v.get('verse')) == '34':
                idx34 = i

    if idx33 is None or idx34 is None:
        return f'REFUSE {path}: 23:33 or 23:34 not found'

    v33 = verses[idx33]
    text = v33['text']

    # Already applied? The affix is gone and a 34a entry exists.
    has_34a = any(
        v.get('book') == book
        and str(v.get('chapter')) == CHAPTER
        and str(v.get('verseLabel')) == AFFIX
        for v in verses
    )
    if AFFIX not in text and has_34a:
        return f'ok   {path}: already applied, nothing to do'
    if AFFIX not in text and not has_34a:
        return f'REFUSE {path}: no "{AFFIX}" in 23:33 and no 34a entry — ' \
               'the asset is neither before nor after this repair'

    if text.count(AFFIX) != 1:
        return f'REFUSE {path}: "{AFFIX}" appears {text.count(AFFIX)} times'

    head, tail = text.split(AFFIX, 1)
    if not head.strip() or not tail.strip():
        return f'REFUSE {path}: splitting at "{AFFIX}" leaves an empty half'
    # The affix should sit at a sentence boundary. If it does not, the
    # import changed shape and the split point is a guess.
    if not head.rstrip().endswith(('。', '.', '！', '？')):
        return (f'REFUSE {path}: 23:33 does not end a sentence before the '
                f'affix — got {head[-6:]!r}')

    new34a = dict(v33)
    new34a['verse'] = '34'
    new34a['verseLabel'] = AFFIX
    new34a['text'] = tail
    new34a['subVerseOrder'] = 0
    # A new verse starts its own line only if 33 did; inherit nothing else.
    new34a['isParagraphStart'] = False
    if 'id' in new34a:
        new34a['id'] = f"{v33['id']}a"

    if check:
        return (f'WOULD SPLIT {path}\n'
                f'    33  → {head[-24:]!r}\n'
                f'    34a → {tail[:24]!r}\n'
                f'    34  → subVerseOrder 1 '
                f'({verses[idx34]["text"][:16]!r})')

    verses[idx33] = {**v33, 'text': head}
    verses[idx34] = {**verses[idx34], 'subVerseOrder': 1}
    verses.insert(idx33 + 1, new34a)

    # Match each file's OWN shape. The two editions are not stored the
    # same way and assuming they are produces an unreviewable diff: the
    # Traditional is pretty-printed at indent=1 with a trailing newline
    # (81,457 lines), the Simplified is minified onto a single line with
    # none. Writing indent=1 over the Simplified rewrote all 81,429
    # lines to bury a three-verse change; writing minified over the
    # Traditional would do the mirror image.
    with open(full, 'w', encoding='utf-8') as fh:
        if minified:
            json.dump(verses, fh, ensure_ascii=False, separators=(',', ':'))
        else:
            json.dump(verses, fh, ensure_ascii=False, indent=1)
            fh.write('\n')
    return f'✓    {path}: split; {len(verses)} verses'


if __name__ == '__main__':
    check = '--check' in sys.argv[1:]
    rc = 0
    for path, book in EDITIONS:
        out = repair(path, book, check)
        print(out)
        if out.startswith('REFUSE'):
            rc = 1
    sys.exit(rc)
