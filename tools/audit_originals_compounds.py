#!/usr/bin/env python3
"""Explain every run of adjacent same-Strong's tokens in the Hebrew OT.

Why this exists
---------------
A reader opened 創世記 35:18 and saw two visibly different Hebrew words,
בֵּן and אוֹנִי, rendered as two separate chips **both numbered H1126 and
both glossed 「拉结为便雅悯所取的名字」**. Neither chip is a lie about the
number — H1126 really is בֶּן־אוֹנִי — but a reader has no way to tell
that the two chips are halves of one name, and concludes that בֵּן on its
own means "the name Rachel gave Benjamin". It does not; it means "son".

`assets/originals/*.json` is built from openscriptures/morphhb (WLC), and
`tools/build_originals.py` keeps only `<w>` elements. The WLC marks the
structure this display needs, and all of it was dropped on import:

  * `<seg type="x-maqqef">־</seg>` between two `<w>` — the two words are
    typographically ONE unit in the printed text.
  * `lemma="1035+"` — OSHB's own marker for "this word is a non-final
    part of a multi-word lexeme" (בֵּית לָחֶם Bethlehem, which has no
    maqqef at all, so the maqqef alone would miss it).
  * `<w type="x-ketiv">` followed by `<note><rdg type="x-qere"><w>` — a
    word written one way and read another. Our importer emitted BOTH as
    ordinary tokens, so the app prints the unpointed ketiv as though it
    were a word of the text and then prints it again, pointed.

This script does not fix anything. It re-parses the WLC with those three
markers intact, aligns the result against the shipped asset token for
token, and reports how many of the adjacent same-Strong's runs each
marker accounts for — so a repair is applied on the evidence of the
source text rather than on a guess about pointing.

    python3 tools/audit_originals_compounds.py            # counts
    python3 tools/audit_originals_compounds.py --samples  # + examples

Reads the same `.cache/originals/morphhb-<osis>.xml` files
`build_originals.py` caches; fetches any that are missing.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import urllib.request
from collections import Counter
from xml.etree import ElementTree as ET

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ORIGINALS_DIR = os.path.join(REPO_ROOT, 'assets', 'originals')
CACHE_DIR = os.path.join(REPO_ROOT, '.cache', 'originals')
NS = '{http://www.bibletechnologies.net/2003/OSIS/namespace}'
URL = ('https://raw.githubusercontent.com/openscriptures/morphhb/master/'
       'wlc/{osis}.xml')

# Same list, same order as build_originals.py OSIS_HEBREW.
BOOKS = [
    ('Gen', 'Genesis'), ('Exod', 'Exodus'), ('Lev', 'Leviticus'),
    ('Num', 'Numbers'), ('Deut', 'Deuteronomy'), ('Josh', 'Joshua'),
    ('Judg', 'Judges'), ('Ruth', 'Ruth'),
    ('1Sam', '1 Samuel'), ('2Sam', '2 Samuel'),
    ('1Kgs', '1 Kings'), ('2Kgs', '2 Kings'),
    ('1Chr', '1 Chronicles'), ('2Chr', '2 Chronicles'),
    ('Ezra', 'Ezra'), ('Neh', 'Nehemiah'), ('Esth', 'Esther'),
    ('Job', 'Job'), ('Ps', 'Psalms'), ('Prov', 'Proverbs'),
    ('Eccl', 'Ecclesiastes'), ('Song', 'Song of Solomon'),
    ('Isa', 'Isaiah'), ('Jer', 'Jeremiah'), ('Lam', 'Lamentations'),
    ('Ezek', 'Ezekiel'), ('Dan', 'Daniel'),
    ('Hos', 'Hosea'), ('Joel', 'Joel'), ('Amos', 'Amos'),
    ('Obad', 'Obadiah'), ('Jonah', 'Jonah'), ('Mic', 'Micah'),
    ('Nah', 'Nahum'), ('Hab', 'Habakkuk'), ('Zeph', 'Zephaniah'),
    ('Hag', 'Haggai'), ('Zech', 'Zechariah'), ('Mal', 'Malachi'),
]

MAQQEF = '־'


def cached_xml(osis: str) -> bytes:
    os.makedirs(CACHE_DIR, exist_ok=True)
    path = os.path.join(CACHE_DIR, f'morphhb-{osis}.xml')
    if os.path.exists(path) and os.path.getsize(path) > 10000:
        with open(path, 'rb') as f:
            return f.read()
    req = urllib.request.Request(
        URL.format(osis=osis), headers={'User-Agent': 'YsWords audit'})
    with urllib.request.urlopen(req, timeout=90) as resp:
        data = resp.read()
    with open(path, 'wb') as f:
        f.write(data)
    return data


def strongs(lemma: str) -> str:
    """Same normalisation build_originals.py::_hebrew_strongs uses."""
    if not lemma:
        return ''
    for part in reversed(re.split(r'[\s/]+', lemma.strip())):
        m = re.match(r'(\d+)', part)
        if m:
            return 'H' + m.group(1)
    return ''


def word_text(el: ET.Element) -> str:
    return ''.join(el.itertext()).strip().replace('/', '')


def parse_verse(verse: ET.Element) -> list[dict]:
    """One entry per `<w>` in the same document order build_originals.py
    produces, annotated with the markers it threw away:

      maqqefNext — a `<seg type="x-maqqef">` sits between this `<w>` and
                   the next one, i.e. the printed text joins them.
      plus       — this token's @lemma ends with '+', OSHB's marker for a
                   non-final member of a multi-word lexeme.
      role       — 'ketiv' / 'qere' for a variant pair, else ''.
    """
    out: list[dict] = []
    for child in verse:
        tag = child.tag
        if tag == f'{NS}w':
            text = word_text(child)
            if not text:
                continue
            lemma = child.get('lemma', '')
            out.append({
                'w': text,
                's': strongs(lemma),
                'lemma': lemma,
                'plus': lemma.rstrip().endswith('+'),
                'maqqefNext': False,
                'role': 'ketiv' if child.get('type') == 'x-ketiv' else '',
            })
        elif tag == f'{NS}seg':
            if child.get('type') == 'x-maqqef' and out:
                out[-1]['maqqefNext'] = True
        elif tag == f'{NS}note':
            # <note type="variant"><catchWord/><rdg type="x-qere"><w/></rdg>
            for rdg in child.iter(f'{NS}rdg'):
                if rdg.get('type') != 'x-qere':
                    continue
                for w in rdg.iter(f'{NS}w'):
                    text = word_text(w)
                    if not text:
                        continue
                    lemma = w.get('lemma', '')
                    out.append({
                        'w': text,
                        's': strongs(lemma),
                        'lemma': lemma,
                        'plus': lemma.rstrip().endswith('+'),
                        'maqqefNext': False,
                        'role': 'qere',
                    })
    # build_originals.py drops tokens with no resolvable Strong's number.
    return [t for t in out if t['s']]


def parse_book(osis: str) -> dict[str, list[dict]]:
    root = ET.fromstring(cached_xml(osis))
    out: dict[str, list[dict]] = {}
    for verse in root.iter(f'{NS}verse'):
        osis_id = verse.get('osisID')
        if not osis_id:
            continue
        m = re.match(r'^[^.]+\.(\d+)\.(\d+)$', osis_id)
        if not m:
            continue
        toks = parse_verse(verse)
        if toks:
            out[f'{int(m.group(1))}:{int(m.group(2))}'] = toks
    return out


def classify(a: dict, b: dict) -> str:
    """Why do these two adjacent tokens carry the same Strong's number?"""
    if a['role'] == 'ketiv' and b['role'] == 'qere':
        return 'ketiv/qere'
    if a['plus']:
        return 'compound (OSHB +)'
    if a['maqqefNext']:
        return 'compound (maqqef)'
    return 'unexplained'


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--samples', action='store_true',
                    help='print example references for each class')
    args = ap.parse_args()

    classes: Counter[str] = Counter()
    samples: dict[str, list[str]] = {}
    verses_with_runs: set[str] = set()
    misaligned: list[str] = []
    total_tokens = 0
    ketiv_total = 0
    plus_total = 0
    maqqef_total = 0

    for osis, english in BOOKS:
        slug = english.lower().replace(' ', '_')
        asset_path = os.path.join(ORIGINALS_DIR, f'{slug}.json')
        if not os.path.exists(asset_path):
            print(f'  missing asset: {asset_path}', file=sys.stderr)
            continue
        with open(asset_path, encoding='utf-8') as f:
            asset = json.load(f)
        parsed = parse_book(osis)

        for cv, shipped in asset.items():
            fresh = parsed.get(cv)
            ref = f'{english} {cv}'
            # The audit is only meaningful where the re-parse reproduces
            # the shipped token stream exactly; anything else is upstream
            # drift and gets reported rather than silently classified.
            if fresh is None or len(fresh) != len(shipped) or any(
                    f['w'] != s['w'] or f['s'] != s['s']
                    for f, s in zip(fresh, shipped)):
                misaligned.append(ref)
                continue
            total_tokens += len(fresh)
            ketiv_total += sum(1 for t in fresh if t['role'] == 'ketiv')
            plus_total += sum(1 for t in fresh if t['plus'])
            maqqef_total += sum(1 for t in fresh if t['maqqefNext'])
            for i in range(len(fresh) - 1):
                if fresh[i]['s'] != fresh[i + 1]['s']:
                    continue
                kind = classify(fresh[i], fresh[i + 1])
                classes[kind] += 1
                verses_with_runs.add(ref)
                samples.setdefault(kind, [])
                if len(samples[kind]) < 8:
                    samples[kind].append(
                        f'{ref}  {fresh[i]["w"]} {MAQQEF} {fresh[i+1]["w"]}'
                        f'  {fresh[i]["s"]}  '
                        f'[{fresh[i]["lemma"]} | {fresh[i+1]["lemma"]}]')

    print(f'Hebrew OT tokens compared : {total_tokens}')
    print(f'verses not re-parsable    : {len(misaligned)}')
    if misaligned:
        print('  e.g. ' + ', '.join(misaligned[:5]))
    print(f'ketiv tokens in the asset : {ketiv_total}')
    print(f'"+" compound-part tokens  : {plus_total}')
    print(f'maqqef-joined tokens      : {maqqef_total}')
    print()
    print(f'adjacent same-Strong runs : {sum(classes.values())} '
          f'in {len(verses_with_runs)} verses')
    for kind, n in classes.most_common():
        print(f'  {kind:22s} {n:6d}')
        if args.samples:
            for s in samples.get(kind, []):
                print(f'      {s}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
