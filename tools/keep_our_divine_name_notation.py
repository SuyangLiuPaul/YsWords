#!/usr/bin/env python3
"""Restore the readings the publisher sync overwrote that are OURS.

Two groups, and the second is not about the divine name at all — see
below. What they share is that the sync's rule (their words, our
markers) does not by itself decide them, and that the file at HEAD is
the record of a decision somebody made on purpose.

## 1. The divine name in the line

WHAT THE PUBLISHER'S NEWER TEXT DOES
------------------------------------
Three verses render the name INLINE in our copy and behind a footnote
in the publisher's current text:

    創世記 18:19   使我[雅偉]所應許    ->  使我<note: "我"原文是"雅偉">所應許
    出埃及記 24:1  上到我[雅偉]這裏來  ->  上到我<note: "我"原文是"雅偉">這裏來
    歷代志下 29:6  轉臉背向他[雅偉]    ->  轉臉背向他<note: "他"原文是"雅偉">

`cuv_three_referent_markers_test` counts the `[雅偉]` brackets and calls
them "the marker, which was never lost". It went 212 -> 209.

WHY OURS IS KEPT
----------------
`sync_cuv_yhwh_to_publisher.py` states the rule this pass runs on: **the
publisher's WORDS are taken and our MARKERS are re-applied.** Not one
word changed in any of these three. What changed is the notation of the
marker — and the marker is the reason 和合本雅偉版 exists. A reader of a
Yahweh-restoring edition who reaches 出埃及記 24:1 and sees 「都要上到我
這裏來」 with the name behind an icon has been shown the bare pronoun
the edition was made to open up.

歷代志下 29:6 also lost the 破折號 of 「雅偉─我們神」, which the official
和合本繁體 prints (git blob 7a2dc43: 「行耶和華─我們　神眼中看為惡的
事」) — a second reason this verse goes back rather than forward.

Restoring the whole verse rather than surgically re-bracketing it is
safe precisely because the words did not move: our text and theirs are
the same sentence, and the file at HEAD is the one that says it with
the name in it.

FOR THE OWNER, NOT FOR A SCRIPT
-------------------------------
This is a place where our edition and the publisher's now differ on
purpose, and it belongs in the questions document
(`docs/和合本雅伟版-请教出版方.md`) rather than being settled quietly
here. This tool records the decision; it does not close the question.

Usage:  tools/keep_our_divine_name_notation.py [--write]
"""
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FILES = {'assets/cuvs-yhwh.json': None, 'assets/cuvs-yhwh-tr.json': None}

# The three above, plus:
#
# ## 2. 意料, which is the owner's own edit
#
# 以賽亞書 64:3 and 使徒行傳 25:18 read 意料 in our text where the
# printed 1919 和合本, both external witnesses, our own tagged corpus and
# the publisher's own site all read 逆料. Four independent lines against
# our reading — and the reading text is not a witness at these two
# verses. It is an EDIT: commit 81db105 (Paul Liu, 2025-08-10) changed
# 逆料 -> 意料 in exactly these two verses, in both editions, in a
# hand-made editorial commit.
#
# The sync put 逆料 back, which is the publisher's reading and the
# official one. `test/niliao_test.dart` exists precisely to stop that,
# and its own words are the argument: "a targeted two-verse
# substitution in a hand-made editorial commit is a decision by the
# repo's owner, not corruption to be undone — whatever the other four
# lines read."
#
# The owner's ruling of 2026-09-08 — 「参考和合本繁體官方的去决定」 —
# was given about verses where the PUBLISHER's text looked wrong, and
# generalising it into permission to overturn the owner's own hand edit
# while they are away is not a reading of it I am willing to make. It
# goes back to 意料 and the question goes to them.
VERSES = {
    '001018019': '創世記 18:19',
    '002024001': '出埃及記 24:1',
    '014029006': '歷代志下 29:6',
    '023064003': '以賽亞書 64:3 (意料, commit 81db105)',
    '044025018': '使徒行傳 25:18 (意料, commit 81db105)',
}
NO_MARKER_EXPECTED = {'023064003', '044025018'}


def at_head(rel):
    return {r['id']: r['text'] for r in json.loads(subprocess.check_output(
        ['git', 'show', 'HEAD:' + rel], cwd=ROOT).decode('utf-8'))}


def main():
    write = '--write' in sys.argv
    restored = already = 0
    out = []
    for rel in FILES:
        path = os.path.join(ROOT, rel)
        rows = json.load(open(path, encoding='utf-8'))
        head = at_head(rel)
        touched = False
        for r in rows:
            if r['id'] not in VERSES:
                continue
            was = head.get(r['id'])
            if was is None:
                raise SystemExit('%s missing at HEAD' % r['id'])
            if r['text'] == was:
                already += 1
                continue
            if (r['id'] not in NO_MARKER_EXPECTED
                    and '[雅伟]' not in was and '[雅偉]' not in was):
                raise SystemExit(
                    'REFUSING: %s at HEAD carries no inline marker — the '
                    'premise of this tool does not hold, read the verse'
                    % r['id'])
            print('%s  %s  restored our reading' % (rel, VERSES[r['id']]))
            r['text'] = was
            restored += 1
            touched = True
        if touched:
            out.append((path, rows))

    print('\nrestored %d, already inline %d' % (restored, already))
    if not write:
        print('(dry run; pass --write)')
        return
    for path, rows in out:
        with open(path, 'w', encoding='utf-8') as f:
            json.dump(rows, f, ensure_ascii=False, indent=2)
            f.write('\n')
        print('WROTE %s' % path)


if __name__ == '__main__':
    main()
