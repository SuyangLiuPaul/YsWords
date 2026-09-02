#!/usr/bin/env python3
"""Restore the 和合本雅偉版 `主*` marker as `主[耶穌]` / `主[耶稣]`.

WHY THIS EXISTS
---------------
This edition marks the referent of 主 three ways:

    主[雅偉]  → Yahweh      212 in the asset, never lost
    主#       → 基督        17, imported as 主[基督]
    主*       → 耶穌        121, DELETED — this script puts them back

The asterisk was removed twice, both times by someone who read it as
importer noise rather than as the publisher's convention:

  * b1dbb96a (2025-05-17) "remove 主*" — 121 occurrences in 112 verses,
    out of BOTH reading assets at once.
  * 4d019c19 (2026-08-10) "16 verses displayed a character that is not
    in scripture" — the last 2 (馬太福音 9:28, 路加福音 24:34).
  * 65eef087 (2026-08-24) did the same to assets/tagged/cuvs-yhwh/,
    arguing that "all 115 being NT kills the reading that the asterisk
    is a divine-name convention". That has it backwards: 主* means 耶穌,
    so NT-only is exactly the distribution it must have.

Both the reading assets and the tagged corpus are restored HERE, in one
script, on purpose. The word-tap sheet renders the tagged line verbatim
in place of the reader's verse, so the two must agree: restoring only
the reading side leaves the sheet showing a bare 主 under a verse that
reads 主[耶穌], and restoring only the tagged side reprints an asterisk
at readers — which is the defect 65eef087 was written to fix. Keeping
them in one file is the cheapest way to stop someone doing half.

WHY IT DOES NOT RESTORE THE OLD FILE
------------------------------------
The 2025 asset is nineteen months stale: typo repairs, ASCII
punctuation, glyph fixes and more have landed since. Rolling it back
would undo all of that to win an asterisk. So this reads only the
POSITIONS from history and edits today's text in place.

The gate is deliberately LOCAL to the marker rather than whole-verse.
Whole-verse equality was tried first and rejected 12 verses whose only
sin was a later repair elsewhere in the line — 潔凈→潔淨, 仆人→僕人, a
restored 」, a stray space after 主. Refusing to restore a marker
because some other character got fixed is the wrong trade. So a verse
qualifies when it still holds the same NUMBER of 主 and each marked 主
is still followed by the same character; a clause that actually moved
fails both. Anything that fails is reported, never guessed at.

Usage:  restore_cuv_jesus_marker.py --check | --apply
"""
import json
import re
import subprocess
import sys

ASSETS = {
    'assets/cuvs-yhwh.json': '主[耶稣]',
    'assets/cuvs-yhwh-tr.json': '主[耶穌]',
}

# Commits whose PARENT still holds the marker.
SOURCES = ['b1dbb96a', '4d019c19']

# `主* 知道…` and `主*啊` both occur: the marker eats an optional space.
MARKER = re.compile(r'主\*\s?')



def count_zhu(text):
    return text.count('主')


def marked_occurrences(old_text, marker=None):
    """Which 主 (by occurrence index) carried the asterisk."""
    marker = marker or MARKER
    stripped = marker.sub('主', old_text)
    marked = []
    idx = -1
    pos = 0
    while True:
        hit = old_text.find('主', pos)
        if hit < 0:
            break
        idx += 1
        if marker.match(old_text, hit):
            marked.append(idx)
        pos = hit + 1
    return marked, stripped


def insert_at(current, marked, stripped, replacement):
    """Rewrite the marked 主 in `current`, checking the next character.

    Returns (new_text, ok). `ok` is False when a marked 主 is no longer
    followed by what it followed in the historical text — the sign that
    the clause moved rather than that a neighbouring glyph was fixed.
    """
    positions = [m.start() for m in re.finditer('主', current)]
    old_positions = [m.start() for m in re.finditer('主', stripped)]
    out = []
    last = 0
    for occ in marked:
        if occ >= len(positions) or occ >= len(old_positions):
            return current, False
        here, then = positions[occ], old_positions[occ]
        if current[here + 1:here + 2] != stripped[then + 1:then + 2]:
            return current, False
        out.append(current[last:here])
        out.append(replacement)
        last = here + 1
    out.append(current[last:])
    return ''.join(out), True


def rows_of(doc):
    return doc if isinstance(doc, list) else doc.get('verses', doc)


def load_git(commit, path):
    raw = subprocess.run(['git', 'show', f'{commit}^:{path}'],
                         capture_output=True, text=True, check=True).stdout
    return rows_of(json.loads(raw))


def key_of(row):
    return row.get('id') or (
        f"{row.get('book')}|{row.get('chapter')}|{row.get('verse')}")



TAGGED_DIR = 'assets/tagged/cuvs-yhwh'
TAGGED_SOURCE = '65eef087'
TAGGED_REPLACEMENT = '主[耶稣]'   # the corpus is simplified

# In the corpus a run boundary can fall between 主 and its marker, so
# concatenating the runs yields `主 *` — 路加 24:34 and 馬太 9:28 are the
# two. The reading assets never do this, and their pattern stays strict:
# a space before the asterisk there would mean something else.
TAGGED_MARKER = re.compile(r'主\s?\*\s?')

# One reference where the two sources DISAGREE, and the reading text wins.
#
# 使徒行傳 9:29 「奉主的名放膽傳道」 carries 主* in the word-tap corpus and
# has never carried it in the reading assets — not today, and not in the
# 2025 text before the first deletion. So it is not something we removed;
# the two imports differ at source.
#
# Restoring it would put 耶稣 on screen in a verse whose scripture does not
# contain it (the sheet prints the tagged line in place of the verse), which
# `tagged_rendered_duplication_test.dart` exists to prevent — and it caught
# exactly this. Skipping it leaves the corpus agreeing with the text we
# actually ship. Worth asking the publisher which is right; not worth
# guessing at.
TAGGED_EXCEPTIONS = {('acts.json', '9:29')}


def restore_tagged(apply):
    """Put the marker back into the word-tap corpus.

    Anchored on WHICH 主 carries it, not on run boundaries. 65eef087 did
    not merely delete the asterisk: in 19 places the marker sat at the
    start of its own run with the 主 at the end of the run before, and
    the repair moved the 主 across — sometimes merging the two runs,
    sometimes not. Patching run by run would have to reproduce both
    shapes, and getting it wrong moves a Strong's number onto the wrong
    word, which is the exact fault this corpus already carries in six
    other places.

    So: concatenate the verse's runs into a line, find the same 主 by
    occurrence index, and write the bracket into whichever run holds
    that character. The gate is that the line still holds the same
    number of 主 as it did before the repair.
    """
    import os
    restored = verses = historical = already = excepted = 0
    skipped = []
    for name in sorted(os.listdir(TAGGED_DIR)):
        if not name.endswith('.json'):
            continue
        path = f'{TAGGED_DIR}/{name}'
        try:
            old_doc = json.loads(subprocess.run(
                ['git', 'show', f'{TAGGED_SOURCE}^:{path}'],
                capture_output=True, text=True, check=True).stdout)
        except subprocess.CalledProcessError:
            continue
        doc = json.load(open(path))
        touched = False
        for ref, old_runs in old_doc.items():
            old_line = ''.join((r.get('w') or '') for r in old_runs
                               if isinstance(r, dict))
            if '*' not in old_line:
                continue
            marked, stripped = marked_occurrences(
                old_line, marker=TAGGED_MARKER)
            historical += old_line.count('*')
            if (name, ref) in TAGGED_EXCEPTIONS:
                excepted += old_line.count('*')
                continue
            if not marked:
                skipped.append(f'{name} {ref}: asterisk not on a 主')
                continue
            runs = doc.get(ref)
            if runs is None:
                skipped.append(f'{name} {ref} (verse gone)')
                continue
            line = ''.join((r.get('w') or '') for r in runs)
            if TAGGED_REPLACEMENT in line:
                already += 1
                continue
            if line.count('主') != stripped.count('主'):
                skipped.append(f'{name} {ref}: 主 count {stripped.count("主")}'
                               f' -> {line.count("主")}')
                continue
            # Walk the runs, counting 主 as we go, and rewrite in place.
            seen = -1
            done = 0
            for run in runs:
                w = run.get('w') or ''
                if '主' not in w:
                    continue
                out = []
                last = 0
                for m in re.finditer('主', w):
                    seen += 1
                    if seen in marked:
                        out.append(w[last:m.start()])
                        out.append(TAGGED_REPLACEMENT)
                        last = m.end()
                        done += 1
                if out:
                    out.append(w[last:])
                    if apply:
                        run['w'] = ''.join(out)
                    touched = True
            if done != len(marked):
                skipped.append(f'{name} {ref}: matched {done}/{len(marked)}')
                continue
            verses += 1
            restored += done
        if apply and touched:
            # The corpus ships MINIFIED with no trailing newline —
            # separators=(',',':') reproduces it byte for byte, verified
            # on a no-op run. Writing it pretty-printed instead turned an
            # 8-line diff into 80,000 and buried the change.
            with open(path, 'w', encoding='utf-8') as fh:
                json.dump(doc, fh, ensure_ascii=False,
                          separators=(',', ':'))
    print(f'{TAGGED_DIR}/')
    print(f'  asterisks in history           : {historical}')
    print(f'  restored                       : {restored} in {verses} verses')
    if already:
        print(f'  already restored, left alone   : {already} verses')
    if excepted:
        print(f'  skipped, reading text disagrees: {excepted}'
              f'  {sorted(TAGGED_EXCEPTIONS)}')
    if skipped:
        print(f'  SKIPPED                        : {len(skipped)}')
        for x in skipped[:8]:
            print(f'      {x}')
    return 1 if skipped else 0


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in ('--check', '--apply'):
        print(__doc__)
        return 2
    apply = sys.argv[1] == '--apply'
    exit_code = 0

    for path, replacement in ASSETS.items():
        # Union the marker positions from every source commit.
        wanted = {}
        for commit in SOURCES:
            for row in load_git(commit, path):
                text = row.get('text', '')
                if '主*' in text:
                    wanted[key_of(row)] = text

        doc = json.load(open(path))
        rows = rows_of(doc)
        by_key = {key_of(r): r for r in rows}

        applied = occurrences = already = 0
        drifted = []
        missing = []
        for key, old_text in sorted(wanted.items()):
            row = by_key.get(key)
            if row is None:
                missing.append(key)
                continue
            current = row.get('text', '')
            marked, stripped = marked_occurrences(old_text)
            # Idempotent: a second run must not report the verses it
            # already fixed as damaged. Checked before the gate, because
            # the restored text deliberately fails the gate.
            if replacement in current:
                already += 1
                continue
            # Whole-verse equality is too strict: nineteen months of
            # legitimate repair landed in between — 潔凈→潔淨, 仆人→僕人,
            # a missing 」, a stray space after 主. Rejecting those would
            # refuse to restore a marker because some OTHER character in
            # the verse was fixed. So the gate is local to the marker:
            #   * the verse must hold the same NUMBER of 主, and
            #   * each marked 主 must still be followed by the same
            #     character it was followed by then.
            # Both hold across every repair above, and both fail if the
            # clause the marker sits in has actually moved.
            if count_zhu(stripped) != count_zhu(current):
                drifted.append((key, old_text, current))
                continue
            new_text, ok = insert_at(current, marked, stripped, replacement)
            if not ok:
                drifted.append((key, old_text, current))
                continue
            occurrences += len(marked)
            applied += 1
            if apply:
                row['text'] = new_text

        print(f'{path}')
        print(f'  verses carrying 主* in history : {len(wanted)}')
        print(f'  restorable                     : {applied}'
              f'  ({occurrences} occurrences)')
        if already:
            print(f'  already restored, left alone   : {already}')
        if missing:
            print(f'  MISSING from today\'s asset     : {len(missing)}')
            for k in missing[:5]:
                print(f'      {k}')
            exit_code = 1
        if drifted:
            print(f'  DRIFTED, left alone            : {len(drifted)}')
            for k, o, c in drifted[:5]:
                print(f'      {k}\n        then: {o[:70]}\n        now : {c[:70]}')
            exit_code = 1

        if apply:
            with open(path, 'w', encoding='utf-8') as fh:
                # indent=2 + a trailing newline reproduces the asset byte for
                # byte on a no-op run — verified before this was first used,
                # so the diff shows the restored markers and nothing else.
                json.dump(doc, fh, ensure_ascii=False, indent=2)
                fh.write('\n')
            print('  WRITTEN')

    exit_code |= restore_tagged(apply)
    return exit_code


if __name__ == '__main__':
    sys.exit(main())
