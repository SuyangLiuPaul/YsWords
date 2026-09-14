#!/usr/bin/env python3
"""Fill verses a new 梁家铿译本 revision lost, from the edition it replaces.

THE LAST STEP of the LJK update, and the order is not arbitrary:

    tools/import_ljk2.py       --code biblexg-v3 --force
    tools/repair_biblexg.py    --code biblexg-v3 --write
    tools/carry_forward_ljk.py --code biblexg-v3 --from biblexg-v2 --write

`repair_biblexg.py` SPLITS OUT verses the publisher's converter merged
into their neighbours — Luke 22:43-44, 23:17, John 5:4, Acts 15:34 are
all present upstream, printed inline inside the preceding verse with
their numbers. Run carry-forward before it and those verses look
missing, so they get filled from the OLDER snapshot: the reader then
sees May's wording for four verses and the revision's for the rest, and
nothing anywhere says so.

WHY CARRY FORWARD AT ALL. Measured on 2026-09-14, and the measurement
was taken twice because the first answer was wrong. Seven traditional
verses looked lost against the May edition; running the repair pass
first showed that three of them — 以弗所書 3:16 and 彼得前書 3:11-12 —
were present all along, printed inside the preceding verse, and the
repair splits them back out. That is exactly why this step runs last.

What is genuinely gone is 啟示錄 5:11-14 — 「配得的是羔羊」 — absent
from the traditional file and present in the simplified one and in the
edition already on readers' screens. A revision that silently takes
scripture off the screen is worse than no revision, so those are
carried over verbatim from the previous edition: the same translation,
the same publisher, one snapshot older. Every carried verse is
printed by name.

WHAT IS NOT CARRIED. Verses this translation deliberately does not
print, because it follows the critical text and explains each in a
note. Filling those would not be restoring a lost verse; it would be
overruling the translator.
"""

import argparse
import json
import os
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Verified against the source one at a time, NOT taken from a general
# list of "verses the critical text omits" — four of those turned out to
# be present upstream and inline. See the module docstring.
CRITICAL_TEXT_OMISSIONS = {
    '40017021', '40018011', '40023014',   # Mt 17:21, 18:11, 23:14
    '41011026', '41015028',               # Mk 11:26, 15:28
    '42017036',                           # Lk 17:36
    '44008037',                           # Acts 8:37 — in a note, not the text
    '44024007', '44028029',               # Acts 24:7, 28:29
    '47013014',                           # 2 Cor 13:14 (NA28 ends at 13)
}


# References the repair steps DELIBERATELY removed from this edition.
#
# Carry-forward runs last and fills whatever the older snapshot has and
# the new one lacks. That is exactly wrong for a reference step 2 or
# step 3 just eliminated on purpose: the old snapshot still has it, so
# carry-forward puts it straight back and silently undoes the repair.
#
# 2026-09-14, found in the other app and not in this one — and the
# reason it did not show up here is the point. This repository's
# `biblexg-v2` had ALREADY been through the same repairs, so it no
# longer had any of these three to give back, and the run reported
# "0 carried". The other app's snapshot had not, so its run put Acts
# 8:41, 2 Corinthians 13:13 and Philippians 1:2 back and reported them
# as a success. A pipeline whose correctness depends on the state of the
# file it reads FROM is a pipeline that works until it does not.
#
# Each entry names the step that owns the reference, because "we removed
# this deliberately" is only a defensible claim if you can say where.
REPAIRED_REFERENCES = {
    # step 3, repair_verse_numbering: the second half of Acts 8:40, which
    # the publisher numbers 41. No English reference Acts 8:41 exists.
    '44008041',
    # step 3: this edition numbers the chapter in thirteen verses, so the
    # grace benediction is its 13 and is re-keyed to canonical 13:14.
    # 13:13's WORDS are inside 13:12, which is a superset, not a loss.
    '47013013',
    # step 2, repair_biblexg: 腓立比書 1:1 and 1:2 are one row upstream in
    # BOTH scripts, and the grace of 1:2 is in neither file. 1:2 is left
    # absent on purpose rather than filled from an older fetch that does
    # not have it either.
    '50001002',
}


def carry(code: str, previous: str, write: bool) -> int:
    total = 0
    for suffix in ('', '-tr'):
        new_path = os.path.join(REPO_ROOT, 'assets', f'{code}{suffix}.json')
        old_path = os.path.join(REPO_ROOT, 'assets', f'{previous}{suffix}.json')
        if not os.path.exists(new_path):
            print(f'  no {os.path.basename(new_path)} — run the importer '
                  f'first', file=sys.stderr)
            return 1
        if not os.path.exists(old_path):
            print(f'  no {os.path.basename(old_path)} to carry from — '
                  f'skipping', file=sys.stderr)
            continue
        with open(new_path, encoding='utf-8') as f:
            rows = json.load(f)
        with open(old_path, encoding='utf-8') as f:
            prev = json.load(f)
        have = {r['id'] for r in rows}
        skip = CRITICAL_TEXT_OMISSIONS | REPAIRED_REFERENCES
        undone = [r for r in prev
                  if r['id'] not in have and r['id'] in REPAIRED_REFERENCES]
        for r in undone:
            print(f'  NOT carrying {r["book"]} {r["chapter"]}:'
                  f'{r["verseLabel"]} — a repair step removed it on '
                  f'purpose; {previous}{suffix} predates that repair')
        missing = [r for r in prev if r['id'] not in have
                   and r['id'] not in skip]
        for r in missing:
            print(f'  carry {r["book"]} {r["chapter"]}:{r["verseLabel"]} '
                  f'from {previous}{suffix}')
        if missing:
            rows.extend(missing)
            rows.sort(key=lambda r: r['id'])
            if write:
                with open(new_path, 'w', encoding='utf-8') as f:
                    json.dump(rows, f, ensure_ascii=False,
                              separators=(',', ':'))
        total += len(missing)
        print(f'  {os.path.basename(new_path)}: {len(rows)} records '
              f'({len(missing)} carried)')
    print(f'\n  {total} verses carried forward'
          f'{"" if write else " (dry run — pass --write)"}')
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--code', default='biblexg-v3')
    ap.add_argument('--from', dest='previous', default='biblexg-v2')
    ap.add_argument('--write', action='store_true')
    args = ap.parse_args()
    return carry(args.code, args.previous, args.write)


if __name__ == '__main__':
    raise SystemExit(main())
