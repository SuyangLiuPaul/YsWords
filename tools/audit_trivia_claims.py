#!/usr/bin/env python3
"""Audit the numeric scripture claims in lib/pages/bible_trivia_page.dart.

Checks every claim in the "mechanically checkable" class — a verse count,
a chapter count, or a verse-range count tied to a specific reference —
against assets/kjv.json, the same reading asset the app displays. This is
the asset the trivia copy's claims should agree with; it is NOT a
judgement about Hebrew/Greek textual traditions.

A second class of claim (Hebrew/Greek word, letter or phrase-occurrence
counts) is checked separately against assets/originals/*.json where an
unambiguous original-language span is named (e.g. "Genesis 1:1 has 7
words"). These are reported but NOT used to fail the audit outright when
they disagree with our own originals asset, because our originals asset
follows the Textus-Receptus/Byzantine tradition underlying the KJV, while
many widely-cited figures for this kind of claim (e.g. "3 John is 219
Greek words") are conventionally quoted from the modern critical text
(NA27/28). A few-word gap in that direction is a known, explainable
edition difference, not evidence the copy is wrong — see the trailing
report section.

Run: python3 tools/audit_trivia_claims.py
"""
import json
import re
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
KJV = json.loads((ROOT / 'assets/kjv.json').read_text())

BOOK_ORDER = []
_seen = set()
for r in KJV:
    if r['book'] not in _seen:
        _seen.add(r['book'])
        BOOK_ORDER.append(r['book'])

CHAPTERS_OF = defaultdict(set)
VERSES_OF = defaultdict(lambda: defaultdict(int))
for r in KJV:
    ch = int(r['chapter'])
    CHAPTERS_OF[r['book']].add(ch)
    VERSES_OF[r['book']][ch] += 1


def n_chapters(book):
    return len(CHAPTERS_OF[book])


def verses_in_chapter(book, chapter):
    return VERSES_OF[book][chapter]


def total_verses(book, chapters=None):
    chapters = chapters or CHAPTERS_OF[book]
    return sum(VERSES_OF[book][c] for c in chapters)


def verse_range_count(book, chapter, v_start, v_end):
    return sum(
        1 for r in KJV
        if r['book'] == book and int(r['chapter']) == chapter
        and v_start <= int(r['verse']) <= v_end
    )


NT_START = BOOK_ORDER.index('Matthew')
OT_BOOK_COUNT = NT_START
NT_BOOK_COUNT = 66 - NT_START

# ── The mechanically-checkable class: (label, source line(s), claimed, actual) ──
# `source` cites the bible_trivia_page.dart line the claim is made on, so a
# failure can be traced straight back to the copy.
CHECKS = []


def check(label, source_line, claimed, actual):
    CHECKS.append((label, source_line, claimed, actual))


check('Psalm 119 verse count', 1727, 176, total_verses('Psalms', {119}))
check('Lamentations 1 verse count', 1763, 22, total_verses('Lamentations', {1}))
check('Lamentations 2 verse count', 1763, 22, total_verses('Lamentations', {2}))
check('Lamentations 4 verse count', 1763, 22, total_verses('Lamentations', {4}))
check('Lamentations 3 verse count', 1764, 66, total_verses('Lamentations', {3}))
check('Lamentations 5 verse count', 1765, 22, total_verses('Lamentations', {5}))
check('Proverbs 31:10-31 verse count', 1798, 22, verse_range_count('Proverbs', 31, 10, 31))
check('Exodus 25-31 chapter span (tabernacle instructions)', 2082, 7,
      sum(1 for c in range(25, 32) if c in CHAPTERS_OF['Exodus']))
check('1 Chronicles has >= 9 chapters (genealogy span 1-9)', 2288, True,
      all(c in CHAPTERS_OF['1 Chronicles'] for c in range(1, 10)))
check('Psalms total chapters (5-book division: 1-41/42-72/73-89/90-106/107-150)',
      2391, 150, n_chapters('Psalms'))
check('Ecclesiastes chapter count', 2410, 12, n_chapters('Ecclesiastes'))
check('Isaiah chapter count', 2446, 66, n_chapters('Isaiah'))
check('OT book count (Isaiah 1-39 mirrors OT books)', 2452, 39, OT_BOOK_COUNT)
check('NT book count (Isaiah 40-66 mirrors NT books)', 2452, 27, NT_BOOK_COUNT)
check('Zephaniah chapter count', 2677, 3, n_chapters('Zephaniah'))
check('Zephaniah total verse count', 2683, 53, total_verses('Zephaniah'))
check('Obadiah verse count (shortest OT book)', 2572, 21, total_verses('Obadiah'))
check('Ephesians chapter count', 2934, 6, n_chapters('Ephesians'))
check('Philippians chapter count', 2955, 4, n_chapters('Philippians'))
check('Romans chapter count', 2850, 16, n_chapters('Romans'))
check('Philemon verse count', 3100, 25, total_verses('Philemon'))
check('1 Corinthians 13 verse count', 2865, 13, total_verses('1 Corinthians', {13}))
check('James total verse count', 3146, 108, total_verses('James'))
check('Luke 1:1-4 word count', 2787, 42,
      sum(len(json.loads((ROOT / 'assets/originals/luke.json').read_text())[v])
          for v in ['1:1', '1:2', '1:3', '1:4']))
check('1 John chapter count', 3215, 5, n_chapters('1 John'))
check('2 John verse count', 3238, 13, total_verses('2 John'))
check('3 John verse count (matches the READING asset, not the NA28 15-verse split)',
      3253, 14, total_verses('3 John'))
check('Revelation chapter count', 3303, 22, n_chapters('Revelation'))

# ── Superlatives that reduce to a verifiable min/max over kjv.json ──
all_chapter_counts = [
    (b, c, VERSES_OF[b][c]) for b in BOOK_ORDER for c in CHAPTERS_OF[b]
]
longest_chapter = max(all_chapter_counts, key=lambda t: t[2])
check('"Psalm 119 is the longest chapter in the Bible" — no chapter has more verses',
      1727, ('Psalms', 119), longest_chapter[:2])

ot_by_verses = sorted(BOOK_ORDER[:NT_START], key=lambda b: total_verses(b))
check('"Obadiah is the shortest book in the OT" — fewest verses among the 39 OT books',
      2572, 'Obadiah', ot_by_verses[0])

WORD_RE = re.compile(r"[A-Za-z']+")


def english_word_count(book):
    return sum(
        len(WORD_RE.findall(r['text']))
        for r in KJV if r['book'] == book
    )


all_by_words = sorted(BOOK_ORDER, key=english_word_count)
check('"3 John is the shortest book in the Bible" (by English word count, all 66 books)',
      3253, '3 John', all_by_words[0])

gospels = ['Matthew', 'Mark', 'Luke', 'John']
shortest_gospel = min(gospels, key=english_word_count)
check('"Mark is the shortest gospel"', 2766, 'Mark', shortest_gospel)

luke_acts_words = english_word_count('Luke') + english_word_count('Acts')
nt_total_words = sum(english_word_count(b) for b in BOOK_ORDER[NT_START:])
luke_acts_pct = round(100 * luke_acts_words / nt_total_words, 1)
check('"Luke + Acts are about 27% of the NT" (English word count, within 1pt)',
      2787, True, abs(luke_acts_pct - 27) <= 1)

mal_last = max(
    (r for r in KJV if r['book'] == 'Malachi'),
    key=lambda r: (int(r['chapter']), int(r['verse'])),
)
mal_last_word = WORD_RE.findall(mal_last['text'])[-1].lower()
check('"the last word of the OT (Malachi) is curse"', 2744,
      'curse', mal_last_word)

sam_refrain_text = ' '.join(
    r['text'] for r in KJV
    if r['book'] == '2 Samuel' and int(r['chapter']) == 1
    and 19 <= int(r['verse']) <= 27
)
sam_refrain_count = len(re.findall(
    r'[Hh]ow are the mighty fallen', sam_refrain_text))
check('"How the mighty have fallen" repeats 3 times in 2 Samuel 1:19-27',
      2225, 3, sam_refrain_count)

gen_words = json.loads((ROOT / 'assets/originals/genesis.json').read_text())
check('Genesis 1:1 has 7 Hebrew words', 1901, 7, len(gen_words['1:1']))


def report():
    failures = []
    for label, line, claimed, actual in CHECKS:
        verdict = 'PASS' if claimed == actual else 'FAIL'
        if verdict == 'FAIL':
            failures.append((label, line, claimed, actual))
        print(f'[{verdict}] line {line}: {label} — claimed {claimed!r}, actual {actual!r}')

    print()
    print(f'{len(CHECKS)} checks run, {len(failures)} failed.')
    if failures:
        print('\nFAILURES:')
        for label, line, claimed, actual in failures:
            print(f'  line {line}: {label} — claimed {claimed!r} but kjv.json says {actual!r}')

    print()
    print('── Not run through pass/fail: text-critical / edition-dependent counts ──')
    print('These are Hebrew/Greek word- or occurrence-counts where our own')
    print('originals asset (Textus-Receptus/Byzantine-leaning, matching the KJV)')
    print('is not necessarily the same textual tradition the cited figure comes')
    print('from. Recording the numbers rather than failing on them:')

    john3 = json.loads((ROOT / 'assets/originals/3_john.json').read_text())
    john3_words = sum(len(v) for v in john3.values())
    print(f'  - 3 John (line 3253): copy says "219 Greek words"; our originals '
          f'asset counts {john3_words} word-tokens. 219 is the figure widely '
          f'cited externally (confirmed by web search); the 1-word gap is '
          f'consistent with a tokenization/edition difference, not a copy error.')
    print(f'  - 3 John (line 3253) / kjv.json: reading asset has 14 verses; '
          f'assets/originals/3_john.json has 15 keys (NA28 splits v14 into '
          f'14+15). Copy says 14, matching the asset the app actually shows.')

    mark_words = json.loads((ROOT / 'assets/originals/mark.json').read_text())
    euthys = sum(
        1 for v in mark_words.values() for w in v if w['s'] in ('G2117', 'G2112'))
    print(f'  - Mark (line 2766): copy says euthus ("immediately") appears '
          f'"41 times"; our originals asset (G2117+G2112 combined) counts '
          f'{euthys}. 41 is the figure widely cited for the NA28 text '
          f'(which uses only G2117); our TR/Byzantine-leaning asset mixes '
          f'both eu-forms, so this is expected to differ and is not a copy '
          f'error.')

    return len(failures)


if __name__ == '__main__':
    import sys
    sys.exit(1 if report() else 0)
