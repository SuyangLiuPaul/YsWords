#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Derive `assets/tagged/cuvs-yhwh-tr/` from `assets/tagged/cuvs-yhwh/`.

    python3 tools/derive_tagged_traditional.py            # write
    python3 tools/derive_tagged_traditional.py --dry-run  # measure only

WHY THIS EXISTS
---------------
The Exegesis sheet renders a running line with the Strong's numbers set
into it — 「地<0776>是<01961>空虚<08414>混沌<0922>」 — and it can only do
that for an edition that has a tagged layer. Until now this repo had
exactly one, `cuvs-yhwh`, so a reader on the **Traditional** 和合本雅偉版
(`cuvs-yhwh-tr`) saw a grid of word cards and no line at all. That is the
screenshot the owner filed on 2026-09-08.

`lib/services/tagged_text_service.dart` said producing one "means running
the Simplified tagging through a 简→繁 conversion, and this app has no
converter". That is true and it is also not the only route. **This script
does not convert anything.** It reads the Traditional character out of
the edition's own shipped Traditional text, at the position the
Simplified character stands in. The publisher already made every
one-to-many choice — 发→發/髮, 谷→谷/穀, 面→面/麵 — and the answer is
sitting in `assets/cuvs-yhwh-tr.json`. Taking it from there is why the
one-to-many problem never arises and why the check below can be exact.

WHAT IS AND IS NOT TOUCHED
--------------------------
Only `w` is rewritten. `s`, `i` and `g` are copied through verbatim — the
Strong's number of a word does not depend on which script prints it, and
a derivation pass that edited them would be making a claim about the
original languages, which is not its business.

Neither reading asset is opened for writing. Both are hash-pinned by
`test/cuvs_yhwh_frozen_test.dart`; see `docs/cuv-yhwh-publisher-notes.md`
before going near them.

THE ALIGNMENT, AND WHY IT IS NOT JUST `zip()`
---------------------------------------------
Three strings are in play per verse and only two of them are the same
string in two scripts:

    S_read   assets/cuvs-yhwh.json          the Simplified reading text
    T_read   assets/cuvs-yhwh-tr.json       the Traditional reading text
    S_tag    concat of assets/tagged/cuvs-yhwh/<book>.json runs

S_read and T_read are character-aligned: 31,041 of 31,102 pairs are the
same length, character for character, which is the correspondence
`lib/constants/search_synonyms.dart` was itself derived from.

S_tag is a **separate import of the same edition** and is not S_read.
Measured over the shipped assets, 23,774 of 31,102 verses agree exactly;
the rest differ only in notation, not in scripture:

    S_read   …天空之中<note: 原文作"天空的表面">。”
    S_tag    …天空之中〔原文作"天空的表面"〕。”

So the map from S_tag to Traditional is built in two steps.

  1. `difflib.SequenceMatcher(autojunk=False)` aligns S_tag against
     S_read. Every character inside an `equal` block has a known index
     in S_read, and therefore — because S_read and T_read are the same
     length — a known Traditional character in T_read at that same
     index. **That is a lookup, not a conversion**, and it covers
     14,652 fewer than all of them: 99.9% of characters.

  2. The characters left over are the ones S_tag has and S_read does
     not — the 〔 〕 the tagged import prints around a note, and the
     quotation marks around a note body. They are resolved against a
     map built from the verse's OWN equal blocks first (so a verse
     containing both 發 and 髮 disambiguates itself), and then against a
     global table built by the same positional lookup over all 31,041
     aligned verse pairs, most frequent reading first — the identical
     policy `kCuvTraditionalChars` records.

  3. Sixteen characters in seven distinct forms are in neither table
     and are passed through unchanged. Every one has been read: `8`,
     `—`, U+2009 THIN SPACE (script-neutral), 蹧 and 杴 (the same
     character in both scripts), and 眾 / 偉, which are already
     Traditional inside the Simplified tagged import. Passing these
     through is right in all seven cases; the count is asserted below
     so an eighth has to be looked at.

WHAT IS SKIPPED, AND WHY IT IS SKIPPED RATHER THAN GUESSED
-----------------------------------------------------------
61 verses whose S_read and T_read are NOT the same length. There is no
positional correspondence for those, and the two ways to fake one — a
conversion table, or a second difflib pass between the two readings —
would both be this script inventing an answer the publisher already gave
somewhere else. They are named in the output and left out of the derived
layer, where the sheet falls back to plain text exactly as it does for
any untagged verse. They are 0.2% of the Bible and they are listed in
full by `--list-skipped`.

THE CHECK THAT MAKES THIS SHIPPABLE
-----------------------------------
For every verse where S_tag == S_read, the derived runs MUST concatenate
to T_read exactly — same characters, same length, no allowance. That is
23,730 verses of end-to-end verification against the real shipped
Traditional asset rather than against a fixture, and one failure stops
the run. `test/tagged_traditional_derived_test.dart` re-runs the same
check against the written files.
"""
import argparse
import collections
import difflib
import io
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)
ASSETS = os.path.join(PROJECT, 'assets')

SIMPLIFIED = os.path.join(ASSETS, 'cuvs-yhwh.json')
TRADITIONAL = os.path.join(ASSETS, 'cuvs-yhwh-tr.json')
KJV = os.path.join(ASSETS, 'kjv.json')
SRC_DIR = os.path.join(ASSETS, 'tagged', 'cuvs-yhwh')
OUT_DIR = os.path.join(ASSETS, 'tagged', 'cuvs-yhwh-tr')

# Measured 2026-09-08 against the shipped assets. Exact rather than a
# ceiling: a ceiling lets a re-run trade one of these for a defect
# somewhere else and still pass, which is the only failure a counted
# rule exists to catch.
# 2026-09-08: all four moved, because the reading assets did. The
# publisher sync brought 8,566 verses up to the publisher's current
# text and the repair layer was re-run over that base; this file
# derives the Traditional tagged layer positionally FROM those assets,
# so it measures them.
#
#   skipped_unaligned  61 -> 60   路加福音 23:16 carried a leaked
#       〔有古卷在此有： in the Simplified only, which made the pair
#       different lengths. Removed, so the verse has a position to
#       derive from again.
#   derived_verses  31041 -> 31042   the same verse, from the other end.
#   verified_exact  23730 -> 27299   the big one, and an improvement of
#       3,569 verses: the reading text and the tagged import now agree
#       character for character far more often, because the reading
#       text moved TOWARDS the publisher's current text and the tagged
#       corpus was already on it.
#   passthrough_chars  16 -> 29   characters in no correspondence table,
#       passed through as they stand. The set is named in the run
#       output and every one of them is a character with no Traditional
#       variant (蹧, 繸, 鐏, 辊, 杴, 镟, 嗐) or already Traditional
#       (偉, 眾), so passing them through is right; there are simply
#       more of them in the newer text.
EXPECTED = {
    'source_verses': 31102,
    'skipped_unaligned': 60,
    'derived_verses': 31042,
    # Verses where the tagged import and the reading asset agree
    # character for character, and where the derived line is therefore
    # checked against the shipped Traditional text with no allowance.
    # 27,299 for a few hours on 2026-09-08; 27,306 once the last of the
    # publisher's own defects were repaired against the official edition
    # (16 transpositions, the Revelation refrain's ！, two lost closing
    # quotes, 約伯記 31:36's doubled 敵 and 歷代志上 21:17's displaced 的).
    # 27,307 once 士師記 15:13's 以坦 was spliced back into the Simplified
    # tagged source as an untagged run (queue:2548) — the source layer
    # now agrees with the reading text character for character, so this
    # verse newly qualifies for the exact check.
    'verified_exact': 27307,
    # Characters resolved by step 3 above — in no table, passed through.
    'passthrough_chars': 29,
}


def load(path):
    with io.open(path, encoding='utf-8') as f:
        return json.load(f)


def book_order(rows):
    out, seen = [], set()
    for r in rows:
        if r['book'] not in seen:
            seen.add(r['book'])
            out.append(r['book'])
    return out


def file_name(english_book):
    """"1 Corinthians" -> "1_corinthians" — TaggedTextService._fileName."""
    return english_book.lower().replace(' ', '_')


def build_global_table(s_by_id, t_by_id):
    """Simplified char -> Traditional char, by position, most frequent first.

    Built from the reading pair alone and used only for characters the
    per-verse alignment could not place. Ambiguity is reported rather
    than hidden: 19 Simplified characters stand opposite more than one
    Traditional character across the Bible, which is the same finding
    `kCuvSimplifiedChars` records.
    """
    counts = collections.defaultdict(collections.Counter)
    for vid, s in s_by_id.items():
        t = t_by_id[vid]
        if len(s) != len(t):
            continue
        for a, b in zip(s, t):
            counts[a][b] += 1
    table = {a: c.most_common(1)[0][0] for a, c in counts.items()}
    ambiguous = {a: dict(c) for a, c in counts.items() if len(c) > 1}
    return table, ambiguous


def derive_verse(s_tag, s_read, t_read, table):
    """The Traditional form of `s_tag`, and the characters guessed at.

    Returns (converted, passthrough_chars). `converted` is the same
    LENGTH as `s_tag` — every step here is one character in, one
    character out — which is what lets the caller slice it back into
    runs by the original run lengths.
    """
    out = [None] * len(s_tag)
    local = {}
    matcher = difflib.SequenceMatcher(None, s_tag, s_read, autojunk=False)
    for tag, i0, i1, j0, j1 in matcher.get_opcodes():
        if tag != 'equal':
            continue
        for n in range(i1 - i0):
            src, dst = s_tag[i0 + n], t_read[j0 + n]
            out[i0 + n] = dst
            # A character standing opposite two different Traditional
            # forms inside ONE verse cannot steer a fallback; mark it
            # unusable rather than picking the first sighting.
            if src in local and local[src] != dst:
                local[src] = None
            elif src not in local:
                local[src] = dst

    passthrough = []
    for n, ch in enumerate(s_tag):
        if out[n] is not None:
            continue
        if local.get(ch):
            out[n] = local[ch]
        elif ch in table:
            out[n] = table[ch]
        else:
            out[n] = ch
            passthrough.append(ch)
    return ''.join(out), passthrough


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--dry-run', action='store_true',
                    help='measure and verify, write nothing')
    ap.add_argument('--list-skipped', action='store_true',
                    help='name every verse left out of the derived layer')
    args = ap.parse_args()

    simplified = load(SIMPLIFIED)
    traditional = load(TRADITIONAL)
    kjv = load(KJV)

    s_by_id = {r['id']: r['text'] for r in simplified}
    t_by_id = {r['id']: r['text'] for r in traditional}
    if set(s_by_id) != set(t_by_id):
        sys.exit('the two reading assets do not cover the same verses — '
                 'the positional correspondence this script rests on is '
                 'not there')

    zh_books = book_order(simplified)
    en_books = book_order(kjv)
    if len(zh_books) != len(en_books):
        sys.exit(f'{len(zh_books)} Chinese books vs {len(en_books)} English '
                 '— cannot pair them by canonical order')
    english_of = dict(zip(zh_books, en_books))
    id_of = {(r['book'], r['chapter'], r['verse']): r['id']
             for r in simplified}

    table, ambiguous = build_global_table(s_by_id, t_by_id)
    print(f'positional table: {len(table)} characters, '
          f'{len(ambiguous)} of them ambiguous across the Bible')

    source_verses = 0
    derived_verses = 0
    verified_exact = 0
    skipped = []
    passthrough = collections.Counter()
    written = {}

    for zh_book in zh_books:
        src_path = os.path.join(SRC_DIR, file_name(english_of[zh_book]) + '.json')
        if not os.path.isfile(src_path):
            sys.exit(f'{src_path}: missing — the source layer is incomplete')
        book = load(src_path)
        out_book = {}
        for ref, runs in book.items():
            chapter, verse = ref.split(':')
            vid = id_of.get((zh_book, chapter, verse))
            source_verses += 1
            if vid is None:
                sys.exit(f'{zh_book} {ref}: the tagged layer has a verse the '
                         'reading asset does not — refusing to guess')
            s_read, t_read = s_by_id[vid], t_by_id[vid]
            if len(s_read) != len(t_read):
                skipped.append(f'{zh_book} {ref}')
                continue
            s_tag = ''.join(r.get('w', '') for r in runs)
            converted, missed = derive_verse(s_tag, s_read, t_read, table)
            if len(converted) != len(s_tag):
                sys.exit(f'{zh_book} {ref}: conversion changed the length — '
                         'a bug in derive_verse, not in the data')
            passthrough.update(missed)

            # Slice back into runs by the ORIGINAL run lengths. One
            # character in, one character out, so the boundaries the
            # tagger drew are the boundaries that survive.
            cursor = 0
            new_runs = []
            for r in runs:
                w = r.get('w', '')
                out_run = {'w': converted[cursor:cursor + len(w)],
                           's': r.get('s', '')}
                cursor += len(w)
                if r.get('i'):
                    out_run['i'] = r['i']
                if r.get('g'):
                    out_run['g'] = r['g']
                new_runs.append(out_run)

            if s_tag == s_read:
                # The check the whole script is built to be able to
                # make. No allowance, no normalisation.
                if converted != t_read:
                    sys.exit(f'{zh_book} {ref}: derived line does not '
                             f'reproduce the shipped Traditional verse\n'
                             f'  derived : {converted}\n'
                             f'  shipped : {t_read}')
                verified_exact += 1
            out_book[ref] = new_runs
            derived_verses += 1
        written[file_name(english_of[zh_book]) + '.json'] = out_book

    print(f'source verses            : {source_verses}')
    print(f'derived verses           : {derived_verses}')
    print(f'skipped (unaligned pair) : {len(skipped)}')
    print(f'verified against T_read  : {verified_exact}')
    print(f'passed through unmapped  : {sum(passthrough.values())} '
          f'({dict(passthrough)})')
    if args.list_skipped:
        for ref in skipped:
            print(f'  skipped: {ref}')
    elif skipped:
        print(f'  first few: {", ".join(skipped[:6])} '
              f'(--list-skipped for all {len(skipped)})')

    got = {
        'source_verses': source_verses,
        'skipped_unaligned': len(skipped),
        'derived_verses': derived_verses,
        'verified_exact': verified_exact,
        'passthrough_chars': sum(passthrough.values()),
    }
    wrong = {k: (v, EXPECTED[k]) for k, v in got.items() if v != EXPECTED[k]}
    if wrong:
        sys.exit(f'measurements moved: {wrong} — read the difference before '
                 'changing EXPECTED, and say in the commit what moved it')

    if args.dry_run:
        print('dry run — nothing written')
        return

    os.makedirs(OUT_DIR, exist_ok=True)
    total = 0
    for name, book in written.items():
        path = os.path.join(OUT_DIR, name)
        with io.open(path, 'w', encoding='utf-8') as f:
            # Compact, matching `assets/tagged/cuvs-yhwh/` byte for byte
            # in everything but the characters. Pretty-printing the same
            # data costs 1.8 MB of spaces in the shipped bundle.
            json.dump(book, f, ensure_ascii=False, separators=(',', ':'))
        total += os.path.getsize(path)
    print(f'wrote {len(written)} files to {OUT_DIR} ({total / 1e6:.1f} MB)')


if __name__ == '__main__':
    main()
