#!/usr/bin/env python3
"""Apply the 2026-09-12 divine-name audit to the tagged 和合本雅偉版.

`tools/cuv-2026-09-12-divine-name-audit.tsv` is the finding, copied here
from the editor's own repository and tracked, because — as its header
says — it is not recoverable from anything else: the module it was lifted
out of (`cuvs+-YHWH.20260912.ont`, md5 f8f547517e5acfaf3dd7f11fde47eb64)
is **a regression as a whole** and is not installed. It drops 2,963 `"`
inside the editor's notes across 1,106 verses and restores 主[雅伟] at
路加 1:70, 使徒 5:12 and 羅馬 15:10, which Raymond had ruled to be
主<WG0> because WH has no κύριος there. These 41 verses are the part of
it that is right.

WHAT THE 41 ARE. H3069 is יהוה pointed as Elohim — the reading used next
to Adonai; H3068 is the ordinary one. All 41 were checked against the
project's own Hebrew (the Leningrad text with Westminster's tagging) and
the module agrees with it in all 41, this repo in none. 創世記 15:8 is
`主<WH136>` then the name, so H3069; 詩篇 1:2 is the name alone, so
H3068. 37 go 3069→3068 and 4 go 3068→3069.

WHERE IT LANDS HERE. Not in the reading assets — they carry no Strong's
numbers and are hash-frozen — but in `assets/tagged/cuvs-yhwh/`, where
the divine name's run carries `s`. The Traditional edition reads the same
tagged layer, so one pass covers both scripts.

WHAT IT REFUSES ON, because this writes the numbering a reader looks
words up by:

  * a verse the tagged layer does not have;
  * a verse where the number to change is not present exactly once on a
    run whose word is the divine name;
  * a row already applied — reported and skipped, so a second run is
    safe and a partial run can be finished.

Usage:
    tools/apply_cuv_divine_name_audit.py [--write] [--repo <path>]
"""
import io
import json
import os
import sys

BOOK_FILES = None  # filled from the tagged directory itself


def book_key(code, tagged_dir):
    """`Gen` -> `genesis.json`, using the directory's own names."""
    global BOOK_FILES
    if BOOK_FILES is None:
        BOOK_FILES = sorted(os.listdir(tagged_dir))
    # The audit uses SBL-style codes; the assets use lowercased English
    # names with underscores. Matched on the code's letters, with the
    # numeric prefix handled first (2Sam -> 2_samuel).
    digits = ''.join(c for c in code if c.isdigit())
    letters = ''.join(c for c in code if c.isalpha()).lower()
    for name in BOOK_FILES:
        stem = name[:-5]
        if digits and not stem.startswith(digits + '_'):
            continue
        if not digits and stem[0].isdigit():
            continue
        bare = stem.split('_', 1)[-1] if digits else stem
        if bare.replace('_', '').startswith(letters):
            return name
    return None


def rows(path):
    for line in io.open(path, encoding='utf-8'):
        if line.startswith('#') or not line.strip():
            continue
        parts = line.rstrip('\n').split('\t')
        if len(parts) < 5:
            continue
        book, chapter, verse, before, after = parts[:5]
        yield book, int(chapter), int(verse), before, after


def tags_of(text):
    """Every `<WH…>` number in order."""
    import re
    return re.findall(r'<W([GH])(\d+)([a-z]*)>', text)


def main():
    write = '--write' in sys.argv
    repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if '--repo' in sys.argv:
        repo = os.path.abspath(sys.argv[sys.argv.index('--repo') + 1])
    tagged = os.path.join(repo, 'assets', 'tagged', 'cuvs-yhwh')
    audit = os.path.join(repo, 'tools', 'cuv-2026-09-12-divine-name-audit.tsv')

    applied = already = refused = 0
    problems = []
    touched = {}
    for book, chapter, verse, before, after in rows(audit):
        name = book_key(book, tagged)
        if name is None:
            problems.append('%s %s:%s — no such book file' % (book, chapter, verse))
            refused += 1
            continue
        path = os.path.join(tagged, name)
        data = touched.get(path) or json.load(open(path, encoding='utf-8'))
        touched[path] = data
        ref = '%d:%d' % (chapter, verse)
        runs = data.get(ref)
        if runs is None:
            problems.append('%s %s — not in the tagged layer' % (book, ref))
            refused += 1
            continue

        # Which number moves, read off the audit's own two strings rather
        # than assumed: exactly one tag differs between them.
        pairs = [(b, a) for b, a in zip(tags_of(before), tags_of(after)) if b != a]
        # More than one is fine as long as they are the SAME swap — 詩篇
        # 6:2 calls the divine name twice and both move 3069→3068. Two
        # different swaps in one verse would be a row this script cannot
        # read, and it says so rather than guessing.
        if not pairs or len({(b, a) for b, a in pairs}) != 1:
            problems.append('%s %s — the row changes %d tags in %d ways'
                            % (book, ref, len(pairs),
                               len({(b, a) for b, a in pairs})))
            refused += 1
            continue
        wanted = len(pairs)
        (_, was, _), (_, now, _) = pairs[0]
        was, now = 'H' + str(int(was)), 'H' + str(int(now))

        hits = [r for r in runs
                if r.get('s') == was and '雅伟' in (r.get('w') or '')]
        if not hits:
            if any(r.get('s') == now and '雅伟' in (r.get('w') or '')
                   for r in runs):
                already += 1
                continue
            problems.append('%s %s — no 雅伟 run carries %s' % (book, ref, was))
            refused += 1
            continue
        if len(hits) != wanted:
            problems.append('%s %s — the row moves %d, the layer has %d '
                            '雅伟 runs carrying %s'
                            % (book, ref, wanted, len(hits), was))
            refused += 1
            continue
        for hit in hits:
            hit['s'] = now
        applied += 1

    print('applied : %d' % applied)
    print('already : %d' % already)
    print('refused : %d' % refused)
    for p in problems:
        print('    %s' % p)

    if write and applied:
        for path, data in touched.items():
            with open(path, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
                f.write('\n')
        print('WROTE %d files' % len(touched))
    elif not write:
        print('(dry run; pass --write)')


if __name__ == '__main__':
    main()
