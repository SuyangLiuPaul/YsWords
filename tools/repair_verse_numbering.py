#!/usr/bin/env python3
"""Re-keys the references where an edition's own verse numbering put a
verse's text under a DIFFERENT verse's canonical reference.

docs/DATA-INTEGRITY.md check 30. Found while classifying the 72
references the two 梁家鏗譯本 editions do not carry.

THE LINE THIS TOOL DRAWS, because most numbering differences must be
left exactly as they are:

  * A reference that holds a SUPERSET or a PREFIX of what the canon puts
    there is the edition's own versification and is honest. LEB and four
    other editions split 3 John 14 into 14 and 15, so reference 14 holds
    the first half; LEB's Acts 19:40 holds both 40 and 41 and says so in
    its own note. A reader sees all the words, in order, in that column.
    NOTHING HERE TOUCHES THOSE.
  * A reference that holds a DIFFERENT verse is a defect. 2 Corinthians
    13:13 in three editions holds the grace benediction, which is 13:14;
    a reader comparing columns saw it beside the KJV's "All the saints
    salute you" with nothing to say they are different verses. That is
    the one thing this document exists to prevent: plausible, wrong, and
    unfalsifiable by a reader.

Every change is guarded on the text it expects to find, refuses rather
than guesses, invents no character the file did not already contain, and
is idempotent — a second run reports "already repaired" and writes
nothing.
"""

import argparse
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def asset(name):
    return os.path.join(ROOT, 'assets', name + '.json')


def load(code):
    with open(asset(code), encoding='utf-8') as fh:
        raw = fh.read()
    return json.loads(raw), raw


def save(code, data, original):
    """Re-serialises in whatever layout the file already used.

    `leb.json` is indented and both 梁家鏗譯本 files are minified;
    guessing wrong reflows two megabytes and buries a one-record
    correction in a diff nobody can read. Same rule as
    `repair_biblexg.py`, which learned it the same way."""
    if original.startswith('[\n'):
        text = json.dumps(data, ensure_ascii=False, indent=2)
    else:
        text = json.dumps(data, ensure_ascii=False, separators=(',', ':'))
    if original.endswith('\n'):
        text += '\n'
    with open(asset(code), 'w', encoding='utf-8') as fh:
        fh.write(text)


def find(data, book, chapter, verse):
    for i, v in enumerate(data):
        if (v['book'] == book and v['chapter'] == str(chapter)
                and v['verse'] == str(verse)):
            return i
    return None


def renumber(record, verse):
    """Moves a record to a new verse number, keeping every other field.

    The `id` is rewritten by replacing its last three digits rather than
    rebuilt from a book table: the two id schemes in the corpus differ in
    width (`047013013` for LEB, `40001001` for 梁家鏗譯本) and a table
    that had to know both would be a second place for the same fact to
    rot."""
    record['verse'] = str(verse)
    if record.get('verseLabel', '').isdigit():
        record['verseLabel'] = str(verse)
    old = record.get('id')
    if isinstance(old, str) and old.isdigit() and len(old) > 3:
        record['id'] = old[:-3] + f'{verse:03d}'


# --------------------------------------------------------------------
# 2 Corinthians 13 — the last verse is filed one number early.
#
# The critical text prints the chapter in thirteen verses: what the
# English tradition numbers 12 and 13 ("Greet one another with a holy
# kiss" / "All the saints salute you") are one verse there, so the grace
# benediction the English tradition calls 13:14 is its verse 13.
#
# Three editions follow that numbering, and the app keys every edition
# by the English reference, so the grace was answering 13:13. The verse
# BEFORE it is untouched by this repair and needs no repair: 13:12 holds
# canonical 12 and 13 together, which is a superset, not a displacement.
#
# The guards below are the witnesses. `expect_moved` is what the record
# being moved must say (the grace: its three genitives are unmistakable
# in any of the three languages), and `expect_head` is what the verse
# before it must say, because the whole reading of the shift depends on
# 13:12 already carrying the saints' greeting.
# --------------------------------------------------------------------

TAIL_SHIFTS = [
    dict(code='leb', book='2 Corinthians', chapter=13, frm=13, to=14,
         expect_moved=['grace', 'love of God', 'fellowship'],
         expect_head=['holy kiss', 'saints greet you']),
    dict(code='biblexg-v2', book='哥林多后书', chapter=13, frm=13, to=14,
         expect_moved=['恩', '爱', '圣灵'],
         expect_head=['亲吻', '全体圣徒']),
    dict(code='biblexg-v2-tr', book='哥林多後書', chapter=13, frm=13, to=14,
         expect_moved=['恩', '愛', '聖靈'],
         expect_head=['親吻', '全體聖徒']),
]


def repair_tail_shift(data, spec):
    already = find(data, spec['book'], spec['chapter'], spec['to'])
    src = find(data, spec['book'], spec['chapter'], spec['frm'])
    if already is not None and src is None:
        return 'already repaired'
    if already is not None:
        return (f'REFUSED: both {spec["chapter"]}:{spec["frm"]} and '
                f'{spec["chapter"]}:{spec["to"]} exist')
    if src is None:
        return f'REFUSED: no {spec["chapter"]}:{spec["frm"]} to move'
    head = find(data, spec['book'], spec['chapter'], spec['frm'] - 1)
    if head is None:
        return f'REFUSED: no {spec["chapter"]}:{spec["frm"] - 1} to read'
    for token in spec['expect_moved']:
        if token not in data[src]['text']:
            return f'REFUSED: {spec["frm"]} does not contain {token!r}'
    for token in spec['expect_head']:
        if token not in data[head]['text']:
            return f'REFUSED: {spec["frm"] - 1} does not contain {token!r}'
    renumber(data[src], spec['to'])
    return f'moved {spec["chapter"]}:{spec["frm"]} -> {spec["to"]}'


# --------------------------------------------------------------------
# Acts 8:40 — one verse cut into two rows, the second numbered 41.
#
# No versification tradition gives Acts 8 more than forty verses, and
# 8:41 appears in no other edition in the corpus. Both 梁家鏗譯本 files
# have it, and the row numbered 40 stops at a comma — 「腓利卻出現在亞
# 鎖城，」 — with the rest of the KJV's verse 40 in the row numbered 41.
# Same failure as 使徒行傳 15:16, which `repair_biblexg.py` found as two
# rows under one number; here the converter gave the second row the next
# number instead of repeating it, which is why a key-set comparison
# reported an extra verse rather than a lost one.
#
# The join adds no character: the first row already ends in the comma
# that separates the clauses.
#
# 2026-09-14, from the upstream JSON this edition is now imported from:
# the split is the PUBLISHER'S OWN, and deliberate. A chapter-end note
# says so —「另外，舊譯本將40、41兩節合為一節，歸入40節。本譯本遵從最新
# 希臘文新約底本 NA28、UBS5 修正為40和41兩節。」— so this is not a
# converter slip, and the note is the reason to record rather than to
# hide. We depart from it anyway, for one reason that is about the app
# and not about the text: every edition here is keyed by its ENGLISH
# reference, and no English reference 「Acts 8:41」 exists. Left split,
# the second half is reachable by no cross-reference, no parallel
# column and no reference search — present in the file and invisible in
# the app. (NA28 itself ends Acts 8 at verse 40; the note's appeal to it
# is the publisher's, not ours to repeat.) The join keeps every
# character the publisher printed, in their order, where a reader can
# find them.
# --------------------------------------------------------------------

ROW_JOINS = [
    dict(code='biblexg-v2', book='使徒行传', chapter=8, head=40, tail=41,
         head_ends='，', expect_tail='凯撒利亚'),
    dict(code='biblexg-v2-tr', book='使徒行傳', chapter=8, head=40, tail=41,
         head_ends='，', expect_tail='凱撒利亞'),
]


def repair_row_join(data, spec):
    tail = find(data, spec['book'], spec['chapter'], spec['tail'])
    head = find(data, spec['book'], spec['chapter'], spec['head'])
    if tail is None:
        return 'already repaired'
    if head is None:
        return f'REFUSED: no {spec["chapter"]}:{spec["head"]} to join onto'
    if not data[head]['text'].rstrip().endswith(spec['head_ends']):
        return (f'REFUSED: {spec["chapter"]}:{spec["head"]} does not end in '
                f'{spec["head_ends"]!r}')
    if spec['expect_tail'] not in data[tail]['text']:
        return (f'REFUSED: {spec["chapter"]}:{spec["tail"]} does not contain '
                f'{spec["expect_tail"]!r}')
    data[head]['text'] = data[head]['text'].rstrip() + data[tail]['text']
    del data[tail]
    return f'joined {spec["chapter"]}:{spec["tail"]} into {spec["head"]}'


def retarget(code):
    """Point the 梁家鏗譯本 specs at `code`, and DROP every other spec.

    Dropping the others is the point, not a side effect. This tool is
    step 3 of the LJK re-import pipeline, and on 2026-09-14 a run of it
    inside the other app silently repaired that app's `leb.json` as
    well — a real defect, but not the one the operator had asked about,
    landing in an unrelated asset in the middle of a Bible import. A
    pipeline step must change only the edition the pipeline names.

    Run with no `--code` to repair everything this file knows about.
    """
    keep = []
    for spec in TAIL_SHIFTS + ROW_JOINS:
        if not spec['code'].startswith('biblexg'):
            continue
        spec['code'] = code + ('-tr' if spec['code'].endswith('-tr') else '')
        keep.append(spec)
    TAIL_SHIFTS[:] = [s for s in TAIL_SHIFTS if s in keep]
    ROW_JOINS[:] = [s for s in ROW_JOINS if s in keep]


def select(code):
    """Keep only the specs already written against `code`.

    Unlike [retarget], this changes nothing about a spec — the guards,
    the book, the verse numbers and the witness strings are all the ones
    somebody wrote for that edition after reading it. Running
    `--edition leb` repairs exactly what the LEB entry above describes
    and leaves every other edition in this file alone.
    """
    TAIL_SHIFTS[:] = [s for s in TAIL_SHIFTS if s['code'] == code]
    ROW_JOINS[:] = [s for s in ROW_JOINS if s['code'] == code]
    if not TAIL_SHIFTS and not ROW_JOINS:
        raise SystemExit(f'no spec in this file is written against {code!r}')


def main():
    """`--code biblexg-v3` re-points the two 梁家鏗譯本 specs at that
    edition, so a re-import gets the same two repairs.

    They were hardcoded to `biblexg-v2` and so were silently skipped
    when v3 arrived — the grace benediction went back to answering
    2 Corinthians 13:13 and Acts 8:41 reappeared. Both guards still
    hold: nothing is written unless the text the spec expects is the
    text that is there.
    """
    ap = argparse.ArgumentParser()
    ap.add_argument('--code',
                    help='LJK edition code to repair. Given, ONLY the '
                         '梁家鏗譯本 specs run — see below. Omitted, every '
                         'spec in this file runs, including LEB.')
    ap.add_argument('--edition',
                    help='Run ONLY the specs already written against this '
                         'exact code, changing nothing about them. Use it '
                         'to repair one edition on its own — `--edition '
                         'leb` — without touching the others this file '
                         'knows about.')
    args = ap.parse_args()
    if args.code and args.edition:
        ap.error('--code re-points the LJK specs; --edition selects specs '
                 'as written. They answer different questions and cannot '
                 'be combined.')
    if args.code:
        retarget(args.code)
    if args.edition:
        # 2026-09-14. `--code` could not express this: it re-points the
        # LJK specs at a new edition and drops the rest, so there was no
        # way to ask for the LEB alone — only "the LJK pair" or
        # "everything". Repairing the LEB in the YsWords repo therefore
        # meant running the LJK specs too, against that repo's RETIRED
        # v2 pair, in the same command. This flag is the narrow door: it
        # selects, it does not rewrite.
        select(args.edition)

    by_code = {}
    for spec in TAIL_SHIFTS:
        by_code.setdefault(spec['code'], []).append(('shift', spec))
    for spec in ROW_JOINS:
        by_code.setdefault(spec['code'], []).append(('join', spec))

    refused = 0
    for code, jobs in by_code.items():
        data, raw = load(code)
        before = json.dumps(data, ensure_ascii=False)
        for kind, spec in jobs:
            fn = repair_tail_shift if kind == 'shift' else repair_row_join
            result = fn(data, spec)
            print(f'{code:16s} {spec["book"]} {spec["chapter"]}: {result}')
            if result.startswith('REFUSED'):
                refused += 1
        if json.dumps(data, ensure_ascii=False) != before:
            save(code, data, raw)
            print(f'{code:16s} written, {len(data)} records')
    return 1 if refused else 0


if __name__ == '__main__':
    sys.exit(main())
