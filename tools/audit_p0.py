#!/usr/bin/env python3
"""P0 scripture-accuracy census — read-only, re-runnable, no writes.

    python3 tools/audit_p0.py              # all sections
    python3 tools/audit_p0.py glyphs       # one section
    python3 tools/audit_p0.py --refs 兇    # every verse ref holding a glyph

Why this exists
---------------
The P0 backlog is 56 items over two 6.4 MB scripture JSONs, 66 tagged-corpus
files and 289 Traditional sermon files. The expensive way to work it is to
read those assets into a model's context — twice as expensive if two agents
each read their own copy. This script emits COUNTS AND VERSE IDS instead, so
the reading is done once by grep-speed code and the judgement is done on a
table. Re-running it later costs nothing.

What it deliberately does NOT do
--------------------------------
It does not fix anything, and it does not recommend fixing anything. Several
of these classes are edition-CONSISTENCY questions the backlog has already
ruled are the user's call, not defects:

  * 兇/凶 — "Nothing false is printed. 兇 is a legitimate Traditional
    character and reads correctly, so this is an edition-consistency
    improvement, not a scripture defect. Ask the user before flipping 47
    positions."
  * 跡/蹟 and 鏈/鍊 — "standard Traditional spellings that read correctly,
    so nothing false is printed today. Restoring the distinction is an
    improvement to ask the user for (~165 positions), not a scripture defect
    to fix unattended."

Those sentences are the reason this file prints a table and stops. An agent
handed "sweep 兇→凶" without them would flip 47 verses of scripture on its
own authority. `test/traditional_tail_glyphs_test.dart` pins the counts so a
later sweep cannot happen silently.
"""
import json
import re
import sys
import glob
import os
from collections import Counter, defaultdict

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

TR = os.path.join(ROOT, 'assets/cuvs-yhwh-tr.json')
HANS = os.path.join(ROOT, 'assets/cuvs-yhwh.json')
TAGGED = os.path.join(ROOT, 'assets/tagged/cuvs-yhwh')
SERMONS_TW = os.path.join(ROOT, 'assets/sermons/zh-TW')


def load(path):
    with open(path, encoding='utf-8') as fh:
        return json.load(fh)


def ref(v):
    return f"{v['book']} {v['chapter']}:{v['verse']}"


# ── 1. Glyph pairs ────────────────────────────────────────────────────
# Each pair is (ours, printed-CUV-alternative, note). The backlog's own
# finding is recorded in the note so the table explains itself.
GLYPH_PAIRS = [
    ('兇', '凶', 'ask user; ~47 positions; nothing false printed'),
    ('剋', '克', 'ours holds ZERO 剋 — is that correct for this edition?'),
    ('蹟', '跡', 'deliberately NOT swept — reads correctly today'),
    ('鍊', '鏈', 'deliberately NOT swept — reads correctly today'),
    ('癒', '愈', 'two spin-offs left unswept; neither converter-backed'),
    ('幹', '干', 'sermons/zh-TW carries 17 wrong 幹 (separate from scripture)'),
]


def section_glyphs(show_refs=None):
    print('\n=== 1. GLYPH PAIRS (Traditional edition consistency) ===')
    print('    These are POLICY questions. The backlog says so explicitly.\n')
    tr = load(TR)
    print(f'    {"pair":<12}{"ours":>8}{"alt":>8}   note')
    print(f'    {"-"*12}{"-"*8}{"-"*8}   {"-"*44}')
    for ours, alt, note in GLYPH_PAIRS:
        n_ours = sum(v['text'].count(ours) for v in tr)
        n_alt = sum(v['text'].count(alt) for v in tr)
        print(f'    {ours}/{alt:<10}{n_ours:>8}{n_alt:>8}   {note}')
    if show_refs:
        print(f'\n    --- every verse holding {show_refs} ---')
        for v in tr:
            if show_refs in v['text']:
                i = v['text'].index(show_refs)
                print(f'    {ref(v):<18} …{v["text"][max(0,i-12):i+13]}…')


# ── 2. Quotation marks ────────────────────────────────────────────────
# The backlog reports 2,480 verses with more opening than closing marks.
# Raw imbalance is NOT itself a defect: CUV runs a quotation across many
# verses, so an unclosed 「 is normal mid-speech. What this does is split
# the population so the genuinely suspicious ones can be looked at.
def section_quotes():
    print('\n=== 2. QUOTATION MARKS ===')
    print('    A verse-level imbalance is EXPECTED — CUV speech spans verses.')
    print('    Split by class so the real questions separate from the noise.')
    # The two editions do not use the same marks, which is easy to miss and
    # makes a naive count report a clean zero for Simplified. Traditional
    # uses the CJK brackets 「」『』; Simplified uses curly quotes “”‘’.
    # Counting the wrong pair is how you conclude a file is perfect.
    print('    NOTE: Traditional uses 「」『』, Simplified uses “”‘’.\n')
    for label, path, (O1, C1, O2, C2) in (
        ('Traditional', TR, ('「', '」', '『', '』')),
        ('Simplified', HANS, ('“', '”', '‘', '’')),
    ):
        verses = load(path)
        open1 = close1 = open2 = close2 = 0
        imbalanced = []
        both_levels = []
        for v in verses:
            t = v['text']
            o1, c1 = t.count(O1), t.count(C1)
            o2, c2 = t.count(O2), t.count(C2)
            open1 += o1; close1 += c1; open2 += o2; close2 += c2
            if o1 != c1 or o2 != c2:
                imbalanced.append(v)
            if o2 and not c2:
                both_levels.append(v)
        print(f'    {label}:')
        print(f'      {O1} {open1:>6}   {C1} {close1:>6}   net {open1-close1:>+5}')
        print(f'      {O2} {open2:>6}   {C2} {close2:>6}   net {open2-close2:>+5}')
        print(f'      verses with any imbalance: {len(imbalanced)}')
        print(f'      verses opening {O2} without closing it: {len(both_levels)}')
        if both_levels and label == 'Traditional':
            print('      (second-level opens are the smaller, checkable set:)')
            for v in both_levels[:12]:
                print(f'        {ref(v)}')
            if len(both_levels) > 12:
                print(f'        … {len(both_levels)-12} more')


# ── 3. Tagged word-tap corpus ─────────────────────────────────────────
# 66 files, one per book, {"chapter:verse": [{"w": word, "s": strongs}]}.
# Disjoint from the scripture JSONs — this is the one area the backlog's
# work can be sharded by file without two writers touching one file.
def section_tagged():
    print('\n=== 3. TAGGED WORD-TAP CORPUS ===')
    files = sorted(glob.glob(os.path.join(TAGGED, '*.json')))
    print(f'    {len(files)} files (disjoint from the scripture JSONs)\n')
    h0 = []
    num_no_word = []
    stray_space = []
    bad_strongs = Counter()
    total_runs = 0
    for path in files:
        book = os.path.basename(path)[:-5]
        for vref, runs in load(path).items():
            for i, r in enumerate(runs):
                total_runs += 1
                w = r.get('w', '')
                s = r.get('s', '')
                if s == 'H0':
                    h0.append(f'{book} {vref}')
                elif s and not re.fullmatch(r'[GH]\d+', s):
                    bad_strongs[s] += 1
                if s and not w.strip():
                    num_no_word.append(f'{book} {vref} [{i}] s={s}')
                if re.search(r'(?<=[一-鿿]) +(?=[一-鿿])', w):
                    stray_space.append(f'{book} {vref} {w!r}')
    print(f'    total runs                 {total_runs}')
    print(f'    runs tagged H0             {len(h0)}')
    print(f'    runs with number, no word  {len(num_no_word)}')
    print(f'    runs w/ CJK-internal space {len(stray_space)}')
    if bad_strongs:
        print(f'    other non-conforming s     {sum(bad_strongs.values())}'
              f'  {dict(list(bad_strongs.items())[:5])}')
    for title, rows in (('H0', h0), ('number-without-word', num_no_word),
                        ('stray space', stray_space)):
        if rows:
            print(f'\n    --- {title} (first 8 of {len(rows)}) ---')
            for r in rows[:8]:
                print(f'      {r}')


# ── 4. Traditional sermons ────────────────────────────────────────────
# 289 files, also disjoint from everything above.
def section_sermons():
    print('\n=== 4. TRADITIONAL SERMON ASSETS ===')
    files = sorted(glob.glob(os.path.join(SERMONS_TW, '*')))
    files = [f for f in files if os.path.isfile(f)]
    print(f'    {len(files)} files (disjoint — safe to shard by file)\n')
    hits = defaultdict(list)
    for path in files:
        try:
            body = open(path, encoding='utf-8').read()
        except (UnicodeDecodeError, IsADirectoryError):
            continue
        for ours, alt, _ in GLYPH_PAIRS:
            if ours in body:
                hits[ours].append(os.path.basename(path))
    if not hits:
        print('    no tracked glyph found')
    for g, names in sorted(hits.items()):
        print(f'    {g}  in {len(names)} files: {", ".join(names[:4])}'
              f'{" …" if len(names) > 4 else ""}')


SECTIONS = {
    'glyphs': section_glyphs,
    'quotes': section_quotes,
    'tagged': section_tagged,
    'sermons': section_sermons,
}

if __name__ == '__main__':
    args = sys.argv[1:]
    if '--refs' in args:
        i = args.index('--refs')
        section_glyphs(show_refs=args[i + 1])
        sys.exit(0)
    wanted = [a for a in args if a in SECTIONS] or list(SECTIONS)
    for name in wanted:
        SECTIONS[name]()
    print('\nRead-only. Nothing here was changed.')
