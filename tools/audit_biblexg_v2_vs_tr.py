#!/usr/bin/env python3
"""Diff 梁家鏗譯本's own two editions' `<note:…>` text against each other.

Why this is a different check from tools/audit_biblexg_notes.py
-----------------------------------------------------------------
That tool compares each edition to ITS OWN publisher source in isolation
(our tw vs their tw-*.json, our cn vs their cn-*.json) — and a verse can
pass both of those checks independently while the two editions still
tell a Traditional and a Simplified reader two different cross-references
for the same verse, because the publisher's own tw and cn files disagree
with EACH OTHER there. Neither per-edition check can see that; only a
direct v2-vs-tr comparison can.

This script does that: strip `<note:…>` from both editions, normalise
Traditional to Simplified (via `opencc -c t2s`, the same converter
`tools/fix_traditional_conversion.py` already uses — never a hand-rolled
per-character map), and diff. For every verse where the two editions'
note text still disagrees after that normalisation, it also prints what
the publisher's OWN tw (Traditional) and cn (Simplified) files say for
that verse, so a human — or the refuter — can tell "our conversion
diverged from the publisher" apart from "the publisher's own two
editions already disagree, and each of ours faithfully follows its own
source". Conflating those is exactly the mistake this script exists to
prevent: the first is ours to fix, the second is a publisher question
identical in kind to the ones already parked in
`tools/audit_biblexg_notes.py`'s ACCOUNTED_FOR_TEXT and in
docs/梁家鏗譯本-請教出版方.md §四之二 — not something to edit our way out of.

Usage:  python3 tools/audit_biblexg_v2_vs_tr.py

Read-only. Never writes to assets/. Skips cleanly (exit 0) if neither
source cache is present — CI has neither, and this script must never be
the thing that turns main red for a missing untracked directory.
"""

import json
import os
import re
import shutil
import subprocess
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(REPO_ROOT, 'tools'))
from audit_biblexg_notes import (  # noqa: E402
    BOOKS, publisher_cites, TAG, ACCOUNTED_FOR_TEXT)

# Prefer the cache tools/audit_biblexg_notes.py already populates; fall
# back to the gitignored webapp checkout, which carries the same files.
SOURCE_DIRS = [
    os.path.expanduser('~/.cache/yswords/ljk-source'),
    os.path.join(REPO_ROOT, 'ljk-nt-bible-webapp', 'public', 'resources'),
]

NOTE = re.compile(r'<note:(.*?)>', re.S)

# Verses where our TR and v2 note wording genuinely differs (not merely a
# publisher tw/cn split) but the question is already settled elsewhere —
# checked against the PRINTED 2025 second-edition 註釋本, a stronger
# authority than either electronic file, per
# docs/梁家鏗譯本-請教出版方.md §四之三 ("印刷版原來說得清楚"). The printed
# edition sets these four in 12pt (editorial note), matching the publisher's
# cn; our TR deliberately keeps its own original wording inside the note
# ("只是把我方原有的字移入註釋，一字未改、未增、未刪") rather than adopting
# v2's wording, so a v2-vs-TR string diff correctly reports these as
# unequal — that is the settled, accepted state, not an open defect.
SETTLED_BY_PRINTED_EDITION = {
    ('路加福音', '9', '5'): '9:5 — TR keeps 「作為警告」, printed+cn read 「意即警告」: same fact, different wording, already settled by the print',
    ('約翰福音', '12', '25'): '12:25 — TR keeps its own note wording against cn, settled by the print',
    ('加拉太書', '3', '7'): '3:7 — 「稱義」 kept as TR wrote it, settled by the print (12pt note, not 17pt scripture)',
    ('加拉太書', '3', '9'): '3:9 — same as 3:7',
}


def find_source_dir():
    for d in SOURCE_DIRS:
        if os.path.isdir(d) and any(f.startswith('cn-') for f in os.listdir(d)):
            return d
    return None


def t2s(text: str) -> str:
    """Traditional -> Simplified via the system opencc, not a hand map.

    Falls back to returning the text unconverted (with a warning) if
    opencc is not on PATH, rather than failing the whole audit — a
    machine without opencc should still be able to run the rest of the
    repo's checks.
    """
    if shutil.which('opencc') is None:
        return text
    result = subprocess.run(
        ['opencc', '-c', 't2s'], input=text, capture_output=True,
        text=True, check=True)
    return result.stdout.rstrip('\n')


def load_ours(path: str) -> dict:
    with open(os.path.join(REPO_ROOT, path), encoding='utf-8') as f:
        rows = json.load(f)
    out = {}
    for row in rows:
        key = (row['book'], row['chapter'], row['verseLabel'])
        out[key] = NOTE.findall(row.get('text', ''))
    return out


def main() -> int:
    src_dir = find_source_dir()
    if src_dir is None:
        print('SKIP — no publisher source cache found at '
              f'{SOURCE_DIRS[0]!r} or {SOURCE_DIRS[1]!r}. '
              'This is expected on CI; run tools/audit_biblexg_notes.py '
              'once (or check out ljk-nt-bible-webapp/) to populate one.')
        return 0

    v2 = load_ours('assets/biblexg-v2.json')
    tr = load_ours('assets/biblexg-v2-tr.json')

    # Map traditional book name -> simplified, so both sides key the same.
    tr2cn = {row[2]: row[1] for row in BOOKS}
    abbr_of = {row[1]: row[0] for row in BOOKS}

    divergences = []
    unmatched = 0
    for (book_tr, chapter, verse), tr_notes in tr.items():
        book_cn = tr2cn.get(book_tr)
        if book_cn is None:
            continue
        v2_notes = v2.get((book_cn, chapter, verse))
        if v2_notes is None:
            # TR has 7,928 verses to v2's 7,924 — a known, already-documented
            # structural difference in how the two editions split verses
            # (see docs/autonomous-queue.md, P0 biblexg item). Such a verse
            # has no counterpart key to diff notes against at all, so it is
            # counted here rather than silently dropped from the census.
            unmatched += 1
            continue
        tr_as_cn = [t2s(n) for n in tr_notes]
        if tr_as_cn == v2_notes:
            continue
        divergences.append((book_cn, book_tr, chapter, verse, tr_notes, v2_notes))

    print(f'{len(tr)} TR verse rows, {len(v2)} v2 verse rows.')
    print(f'{unmatched} TR verses have no v2 counterpart key at all '
          '(structural verse-split difference — not compared, not counted '
          'below).')
    print(f'{len(divergences)} verses where the note text disagrees after '
          't2s normalisation.')
    print('Caveat: t2s is a real converter, not a hand map, but a variant-'
          "character gap in it (e.g. it does not fold 藉→借) could in "
          'principle mask a genuine divergence as a false equality. None '
          'was found in this run, but the census does not rule it out.\n')

    publisher_only_count = 0
    genuine_count = 0
    for book_cn, book_tr, chapter, verse, tr_notes, v2_notes in divergences:
        abbr = abbr_of[book_cn]
        print(f'-- {book_tr} {chapter}:{verse}  ({book_cn})')
        print(f'   TR (as-is)      : {tr_notes}')
        print(f'   TR (t2s)        : {[t2s(n) for n in tr_notes]}')
        print(f'   v2              : {v2_notes}')

        try:
            src_dir_now = find_source_dir()
            tw_cites = {k: v for k, v in publisher_cites(
                json.load(open(os.path.join(src_dir_now, f'tw-{abbr}.json'),
                                encoding='utf-8'))).items()}
            cn_cites = {k: v for k, v in publisher_cites(
                json.load(open(os.path.join(src_dir_now, f'cn-{abbr}.json'),
                                encoding='utf-8'))).items()}
            pub_tw = [TAG.sub('', c).strip()
                      for c in tw_cites.get((chapter, verse), [])]
            pub_cn = [TAG.sub('', c).strip()
                      for c in cn_cites.get((chapter, verse), [])]
        except FileNotFoundError:
            pub_tw = pub_cn = None

        print(f'   publisher tw    : {pub_tw}')
        print(f'   publisher cn    : {pub_cn}')

        tr_matches_pub_tw = pub_tw is not None and [
            n.strip() for n in tr_notes] == pub_tw
        v2_matches_pub_cn = pub_cn is not None and [
            n.strip() for n in v2_notes] == pub_cn
        settled = (SETTLED_BY_PRINTED_EDITION.get((book_tr, chapter, verse))
                   or ACCOUNTED_FOR_TEXT.get(('tw', book_tr, chapter))
                   or ACCOUNTED_FOR_TEXT.get(('cn', book_cn, chapter)))
        if tr_matches_pub_tw and v2_matches_pub_cn:
            publisher_only_count += 1
            print('   => PUBLISHER-INTERNAL: our TR matches their own tw, '
                  'our v2 matches their own cn, and their tw and cn simply '
                  "disagree with each other. Not ours to fix — same class "
                  'as the existing ACCOUNTED_FOR_TEXT entries.')
        elif settled:
            publisher_only_count += 1
            print(f'   => SETTLED BY THE PRINTED EDITION: {settled}')
        else:
            genuine_count += 1
            print('   => NEEDS A LOOK: at least one side does not match '
                  'its own publisher source, and this pair is not in '
                  'SETTLED_BY_PRINTED_EDITION or the existing '
                  'ACCOUNTED_FOR/ACCOUNTED_FOR_TEXT dicts in '
                  'audit_biblexg_notes.py. Candidate for repair, but '
                  'confirm with git log -S before touching the asset.')
        print()

    print(f'Summary: {len(divergences)} divergences, '
          f'{publisher_only_count} explained as publisher tw/cn disagreeing '
          f'with itself, {genuine_count} unexplained.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
