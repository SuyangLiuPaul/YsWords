#!/usr/bin/env python3
"""Explain every run of adjacent same-Strong's tokens in the Hebrew OT.

Why this exists
---------------
A reader opened 創世記 35:18 and saw two visibly different Hebrew words,
בֵּן and אוֹנִי, rendered as two chips **both numbered H1126 and both
glossed 「拉结为便雅悯所取的名字」**. Neither chip lies about the number —
H1126 really is בֶּן־אוֹנִי — but nothing on screen says the two chips are
halves of one name, so the page reads as though בֵּן alone means "the
name Rachel gave Benjamin". It means "son".

`tools/build_originals.py` used to keep only the `<w>` elements of the
WLC, which dropped every marker the display needed. This script exists to
make sure the repair stayed applied and to say what the *remaining*
adjacent same-Strong's runs are, because most of them are correct and
must not be "fixed":

  * `lemma="1035+"` is OSHB's own mark for a non-final member of a
    multi-word lexeme, and it — not the maqqef — is the authority for
    merging. מוֹת־יוּמַת and קֹדֶשׁ־קָדָשִׁים carry a maqqef and are two
    words; בֵּית לָחֶם is one lexeme with no maqqef at all. Merging on the
    maqqef would have corrupted ~2,000 verses.
  * `<w type="x-ketiv">` plus `<note><rdg type="x-qere">` is one word
    written one way and read another, not two words.

Everything left over is genuine repetition — an infinitive absolute
before its verb (אָכֹל תֹּאכֵל), a construct chain (בֶּן־בְּנוֹ), a name
occurring twice in a genealogy — and belongs as two chips.

    python3 tools/audit_originals_compounds.py            # counts
    python3 tools/audit_originals_compounds.py --samples  # + examples

Reads the `.cache/originals/morphhb-<osis>.xml` files build_originals.py
caches, fetching any that are missing.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from collections import Counter
from xml.etree import ElementTree as ET

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_originals as B  # noqa: E402

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ORIGINALS_DIR = os.path.join(REPO_ROOT, 'assets', 'originals')
NS = B.NS_OSIS


def raw_verses(osis: str) -> dict[str, list[dict]]:
    """The WLC's own words, before compounds are joined or a ketiv/qere
    pair is collapsed — the marker stream the classification reads."""
    root = ET.fromstring(
        B.fetch(B.MORPHHB_BOOKS_URL.format(osis=osis), f'morphhb-{osis}.xml'))
    out: dict[str, list[dict]] = {}
    for verse in root.iter(f'{NS}verse'):
        osis_id = verse.get('osisID')
        if not osis_id:
            continue
        m = re.match(r'^[^.]+\.(\d+)\.(\d+)$', osis_id)
        if not m:
            continue
        out[f'{int(m.group(1))}:{int(m.group(2))}'] = \
            B._wlc_raw_tokens(verse)
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--samples', action='store_true',
                    help='print example references for each class')
    args = ap.parse_args()

    classes: Counter[str] = Counter()
    samples: dict[str, list[str]] = {}
    drift: list[str] = []
    tokens = merged = variants = 0

    for osis, english in B.OSIS_HEBREW:
        slug = english.lower().replace(' ', '_')
        with open(os.path.join(ORIGINALS_DIR, f'{slug}.json'),
                  encoding='utf-8') as f:
            shipped = json.load(f)
        rebuilt = B.parse_morphhb_book(osis)
        raw = raw_verses(osis)

        for cv, words in shipped.items():
            ref = f'{english} {cv}'
            # The classification only means anything where the importer
            # still reproduces what is shipped; anything else is upstream
            # drift and gets reported rather than silently explained.
            if rebuilt.get(cv) != words:
                drift.append(ref)
                continue
            tokens += len(words)
            merged += sum(1 for w in words if ' ' in w['w'] or '־' in w['w'])
            variants += sum(1 for w in words if 'k' in w or 'q' in w)
            for a, b in zip(words, words[1:]):
                if a['s'] != b['s']:
                    continue
                pointed = [bool(re.search(r'[֑-ֽֿ-ׇ]',
                                          w['w'])) for w in (a, b)]
                if pointed[0] != pointed[1]:
                    # One of the six words the Masoretes wrote and marked
                    # as not to be read (an empty `<rdg type="x-qere"/>`).
                    kind = 'written but not read'
                elif any(t['plus'] for t in raw.get(cv, [])):
                    kind = 'repetition beside a compound'
                else:
                    kind = 'genuine repetition'
                classes[kind] += 1
                samples.setdefault(kind, [])
                if len(samples[kind]) < 8:
                    samples[kind].append(
                        f'{ref}  {a["w"]} | {b["w"]}  {a["s"]}')

    print(f'Hebrew OT words          : {tokens}')
    print(f'  multi-word lexemes     : {merged}')
    print(f'  ketiv/qere             : {variants}')
    print(f'verses the importer no '
          f'longer reproduces        : {len(drift)}')
    if drift:
        print('  e.g. ' + ', '.join(drift[:5]))
    print()
    print(f'adjacent same-Strong runs: {sum(classes.values())}')
    for kind, n in classes.most_common():
        print(f'  {kind:30s} {n:6d}')
        if args.samples:
            for s in samples.get(kind, []):
                print(f'      {s}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
