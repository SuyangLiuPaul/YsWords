#!/usr/bin/env python3
"""Replay the publisher sync onto the Traditional edition, converting
what it inserts.

`sync_cuv_yhwh_to_publisher.py` brought `assets/cuvs-yhwh.json` up to
the publisher's current text. The Traditional twin has to take the same
edits at the same character positions, or the pair stops being one
edition in two scripts.

WHY THIS IS NOT `mirror_inner_quotes_to_tr.py`
---------------------------------------------
That script exists and it is WRONG for this pass. It copies the
Simplified's new characters into the Traditional verbatim, which was
safe when the only thing being inserted was an ASCII `"` -- a mark both
scripts of this edition set identically. This sync also inserts WORDS:
the publisher changed 那→哪, 阿→啊, 它/她/他, 嗎→么, 擘→掰 and more.
Running the verbatim mirror over it put **780 Simplified characters
into the Traditional file** and dropped 說 from 9,539 to 9,529. That was
measured and reverted rather than shipped; this script is the fix.

"PUNCTUATION IS SCRIPT-NEUTRAL" IS FALSE HERE
--------------------------------------------
The first version of this script carried a `if not is_han(ch)` shortcut
that appended punctuation verbatim, on the reasoning above. That
reasoning generalised from the ASCII `"` of the quote pass to marks it
does not cover, and it was wrong by 7,170 characters: this edition sets
“ ” ‘ ’ in the Simplified and 「 」 『 』 in the Traditional, so a
curly quote is exactly as much a script difference as 說/说 is.

The publisher's current text roughly doubles the curly quotes in the
Simplified. Mirrored verbatim, that put 3,155 `“`, 2,871 `”`, 574 `‘`
and 570 `’` into a Traditional file that had **zero of all four**, and
produced verses that open 「 and close ” -- 創世記 30:6, 出埃及記 3:5
and 3,903 others. Nothing caught it: the leak check below only knew
about Han pairs, so it printed those four at the top of "characters new
to the Traditional file" and then reported "a real leak: 0".

The fix is not a special case for quotes. It is to stop asking whether
a character is Han at all and let the derived correspondence decide,
which is what the rest of this script already does.

HOW THE CONVERSION IS DECIDED
-----------------------------
Not by a general 简→繁 table, which would have to make one-to-many
judgements (发→發/髮, 谷→谷/穀, 面→面/麵). The correspondence is derived
from THIS EDITION'S OWN two scripts, before the sync: walk every
character-aligned verse pair and record what stands opposite what. A
character that never differs between the scripts converts to itself; a
character with exactly one Traditional form converts to it.

That derivation is what makes dropping the Han test safe rather than
reckless. Across all 31,102 verse pairs the ONLY non-Han characters
that ever stand opposite something different are those four quotes,
each with exactly one Traditional form and no competitor:

    “ -> 「 (3,410)   ” -> 」 (3,087)
    ‘ -> 『 (630)     ’ -> 』 (599)

A comma, a 。, an ASCII `"`, a digit and a Latin letter are all
unattested as differences, so they fall through unchanged exactly as
they did before.

**A character with MORE THAN ONE Traditional form is refused**, and so
is a Han character the pair has never shown us. In either case the
whole verse is skipped and named. This pass may not be the place where
a 發/髮 decision gets made by a script -- that is the mistake the
Traditional edition is still recovering from.

Verses whose two scripts are not the same length are already skipped by
the sync itself, so there is nothing to align here for them.

Usage:  tools/mirror_publisher_sync_to_tr.py [--write]
"""
import collections
import difflib
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIMP = os.path.join(ROOT, 'assets', 'cuvs-yhwh.json')
TRAD = os.path.join(ROOT, 'assets', 'cuvs-yhwh-tr.json')


def is_han(ch):
    o = ord(ch)
    return 0x4E00 <= o <= 0x9FFF or 0x3400 <= o <= 0x4DBF


def load(path):
    return {r['id']: r['text']
            for r in json.load(open(path, encoding='utf-8'))}


def git_show(path):
    return {r['id']: r['text'] for r in json.loads(subprocess.check_output(
        ['git', 'show', 'HEAD:' + path], cwd=ROOT).decode('utf-8'))}


def correspondence(simp, trad):
    """simplified char -> {traditional char: count}, from the edition's
    own two scripts at aligned positions.

    Deliberately NOT restricted to Han. The four curly quotes are a
    script difference in this edition just as much as 说/說 is, and
    restricting the table to Han is what let 7,170 of them through
    verbatim -- see the docstring. Anything the two scripts never
    disagree about simply never enters the table.

    A CHARACTER STANDING OPPOSITE ITSELF IS A FORM, and counting it is
    the whole point of this function's second version. Skipping the
    equal pairs -- which the first version did -- makes 面 look
    unambiguous: it differs only ever as 麵 (107 times), so the table
    read "面 has exactly one Traditional form, 麵" and every 面 the
    publisher INSERTED was converted to flour. 馬太福音 6:2 shipped
    「不可在你麵前吹號」 -- do not sound a trumpet before your dough.
    Counting the 2,071 places 面 stands opposite 面 puts it back in
    `ambiguous`, where 谷, 干, 只, 松, 胡 and eleven others also belong
    and where the correct behaviour is to refuse the verse and name it.
    """
    counts = collections.defaultdict(collections.Counter)
    for vid, a in simp.items():
        b = trad.get(vid)
        if b is None or len(a) != len(b):
            continue
        for x, y in zip(a, b):
            counts[x][y] += 1
    return counts


def main():
    write = '--write' in sys.argv
    before = git_show('assets/cuvs-yhwh.json')
    after = load(SIMP)
    trad_rows = json.load(open(TRAD, encoding='utf-8'))
    trad = {r['id']: r['text'] for r in trad_rows}

    counts = correspondence(before, trad)
    ambiguous = {s for s, forms in counts.items() if len(forms) > 1}
    # A single form that is the character itself is not a conversion; it
    # is the ordinary case, and `out.append(ch)` handles it. Only a
    # single form that DIFFERS is a conversion this table may make.
    convert = {s: next(iter(forms)) for s, forms in counts.items()
               if len(forms) == 1 and next(iter(forms)) != s}
    print('correspondence derived from the pre-sync pair: %d characters '
          'differ, %d of them ambiguously'
          % (len(counts), len(ambiguous)))
    non_han = sorted(c for c in counts if not is_han(c))
    print('  non-Han characters in the table: %s'
          % ' '.join('%s->%s' % (c, ''.join(counts[c])) for c in non_han))

    mirrored = converted = quotes = 0
    refused = []
    revert = {}
    for r in trad_rows:
        old, new = before.get(r['id']), after.get(r['id'])
        if old is None or new is None or old == new:
            continue
        cur = r['text']
        if len(cur) != len(old):
            refused.append((r['id'], 'not character-aligned'))
            continue

        out, bad = [], None
        for tag, i1, i2, j1, j2 in difflib.SequenceMatcher(
                None, old, new, autojunk=False).get_opcodes():
            if tag == 'equal':
                out.append(cur[i1:i2])
                continue
            if tag == 'delete':
                continue
            for ch in new[j1:j2]:
                if ch in ambiguous:
                    bad = 'ambiguous 简→繁 for %r' % ch
                    break
                elif ch in convert:
                    out.append(convert[ch])
                    converted += 1
                    if not is_han(ch):
                        quotes += 1
                else:
                    # Never seen to differ between the two scripts, so it
                    # is the same character in both -- every comma, 。,
                    # ASCII `"`, digit and Latin letter lands here.
                    # Verified below.
                    out.append(ch)
            if bad:
                break
        if bad:
            # The pair moves together or not at all. A verse the
            # Traditional cannot take must be put BACK in the
            # Simplified, or the two scripts end up different lengths
            # and `search_synonyms_test` -- which derives the whole
            # character correspondence from their being aligned --
            # loses the verse. Reverting three verses is cheaper than
            # guessing a 坛/壇/罈, a 干/乾/幹 or a 须/須/鬚.
            refused.append((r['id'], bad))
            revert[r['id']] = old
            continue
        r['text'] = ''.join(out)
        mirrored += 1

    print('verses mirrored: %d   characters converted 简→繁: %d '
          '(%d of them 引號 “”‘’ -> 「」『』)'
          % (mirrored, converted, quotes))
    print('verses refused:  %d' % len(refused))
    for vid, why in refused[:20]:
        print('    %s  %s' % (vid, why))

    text = ''.join(r['text'] for r in trad_rows)
    print('\nTraditional after: 說 %d  説 %d   主[雅偉] %d  主[基督] %d  '
          '主[耶穌] %d   verses %d'
          % (text.count('說'), text.count('説'), text.count('主[雅偉]'),
             text.count('主[基督]'), text.count('主[耶穌]'), len(trad_rows)))

    # The check the verbatim mirror would have failed, and the first
    # version of this one got wrong too. "Is this character Simplified?"
    # is the wrong question -- 面, 只, 谷, 干 are all real Traditional
    # characters that ALSO happen to be the Simplified form of something
    # else, so asking it flags 3,325 innocent characters.
    #
    # The right question is what actually changed: which characters are
    # in the Traditional file now that were not in it before. A verbatim
    # mirror answers 嗎→么, 逿→趟 and friends; a converting one should
    # answer nothing at all.
    before_chars = {ch for t in trad.values() for ch in t}
    novel = collections.Counter(
        ch for r in trad_rows for ch in r['text']
        if ch not in before_chars)
    print('characters new to the Traditional file: %d occurrences, '
          '%d distinct' % (sum(novel.values()), len(novel)))
    for ch, n in novel.most_common(12):
        print('    %r %d' % (ch, n))

    # Of those, the ones that are actually a LEAK: a character this
    # edition's own two scripts have shown us has a different
    # Traditional form. `掰` and `䍁` are new here and are NOT leaks --
    # the publisher changed 擘→掰 and 繸→䍁, and neither has a
    # Traditional variant, so both belong in both scripts. Nor are the
    # publisher's own cross-reference notes (撒下8:3, and 馬太福音
    # 21:31's apparatus note citing WH / NA27 / BYZ), which is where
    # every new Latin letter and digit comes from.
    leaked = {ch: n for ch, n in novel.items()
              if ch in convert or ch in ambiguous}
    print('of those, characters with a known Traditional form (a real '
          'leak): %d' % sum(leaked.values()))
    for ch, n in sorted(leaked.items(), key=lambda kv: -kv[1])[:12]:
        print('    %r %d  -> should have been %r'
              % (ch, n, convert.get(ch, '?ambiguous')))

    if revert:
        print('\nreverting %d verse(s) in the SIMPLIFIED so the pair stays '
              'aligned:' % len(revert))
        for vid in revert:
            print('    %s' % vid)

    if write:
        if revert:
            simp_rows = json.load(open(SIMP, encoding='utf-8'))
            for r in simp_rows:
                if r['id'] in revert:
                    r['text'] = revert[r['id']]
            with open(SIMP, 'w', encoding='utf-8') as f:
                json.dump(simp_rows, f, ensure_ascii=False, indent=2)
                f.write('\n')
            print('WROTE %s (reverted %d)' % (SIMP, len(revert)))
        if leaked:
            raise SystemExit(
                'REFUSING TO WRITE: %d Simplified characters leaked into '
                'the Traditional edition' % sum(leaked.values()))
        with open(TRAD, 'w', encoding='utf-8') as f:
            json.dump(trad_rows, f, ensure_ascii=False, indent=2)
            f.write('\n')
        print('WROTE %s -- re-pin both hashes in cuvs_yhwh_frozen_test.dart'
              % TRAD)
    else:
        print('(dry run; pass --write)')


if __name__ == '__main__':
    main()
