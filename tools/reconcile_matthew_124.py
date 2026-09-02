#!/usr/bin/env python3
"""Match our 289 recorded sermons against the church's 124 written messages.

    python3 tools/reconcile_matthew_124.py            # print the report
    python3 tools/reconcile_matthew_124.py --json OUT # also write the mapping
    python3 tools/reconcile_matthew_124.py --refetch

Read-only with respect to the app: it writes nothing under assets/ or
lib/. The mapping it emits is evidence for a decision, not a shipped
feature — see WHY IT STOPS SHORT.

WHAT THE TWO THINGS ARE
-----------------------
Ours: 289 sermons, digitised from Pastor Eric's cassette tapes, indexed
in `assets/sermons/index.json` with a `passage` like `Mt.3.13-17`.

Theirs: `christiandiscipleschurch.org/content/124-messages` — Bentley's
9-volume written edition of the Matthew series, 124 messages, each with
a web page (`/matthew-001`) and a PDF, titled like

    Message 006 - Submission to God's Will Fulfills All Righteousness
                  (Matthew 3:13-17)

These are NOT the same series renumbered. The written edition is finer
and re-titled, so several of its messages can expound one recording.

MATCHING
--------
**Title matching does not work and looked like it did.** A first pass on
titles found 23 exact and 29 fuzzy of 124 — the fuzzy hits included
`Temptation after Baptism #1` → our `temptation after baptism 2`, which
is a different sermon in the same series. Off by one talk, and it would
have read as a success.

Passage is the real key: 006's `Matthew 3:13-17` is our 002
`Mt.3.13-17`, whose title is the single word `Submission`. So this
matches on book + chapter + verse, and uses title similarity only to
BREAK TIES, never to make a match.

Four tiers, and the tier is the point:

  exact    one of ours shares book+chapter+first verse, uniquely
  chapter  same book+chapter, or several of ours match — ambiguous
  cited    no recording is ABOUT it, but `refs.json` shows recordings
           that quote it. Weakest tier and kept separate on purpose: a
           sermon citing Matthew 28:18 in passing is not a sermon on the
           Great Commission.
  none     nothing at all

**46% of our own index has no passage.** 132 of the 289 sermons carry
one this parser cannot read — mostly empty — so the first two tiers see
only 157 recordings. That is the ceiling on this whole exercise, it is
our data and not the church's, and it is why the `cited` tier exists at
all. A `none` here means "we could not find one", never "we do not have
one".

WHY IT STOPS SHORT
------------------
The obvious next step is a "read the written version" link on each
sermon page. This tool deliberately does not generate one, because the
queue's own warning about the 在十字架下 references applies here with more
force: *a citation that opens the wrong passage is P0*. A `chapter`-tier
match is a guess, and `exact` is still many-to-one in places — messages
007 and 008 both expound `Matthew 3:13 - 4:17`, which is our single
recording 002. Shipping all of them links some sermons to a message
about a different talk.

What to link, and whether to link at all rather than offering the 124 as
their own browsable series, is a decision. This produces the evidence.
"""
import argparse
import difflib
import html as H
import json
import os
import re
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PAGE = 'https://www.christiandiscipleschurch.org/content/124-messages'
CACHE = '/tmp/m124.html'

# Only the books the 124 actually cite; an unknown abbreviation must
# fail loudly rather than silently match nothing.
BOOK = {
    'mt': 'Matthew', 'matt': 'Matthew', 'matthew': 'Matthew',
    'mk': 'Mark', 'mark': 'Mark',
    'lk': 'Luke', 'luke': 'Luke',
    'jn': 'John', 'john': 'John',
    'acts': 'Acts', 'rom': 'Romans', 'romans': 'Romans',
    '1cor': '1 Corinthians', '2cor': '2 Corinthians',
    'gal': 'Galatians', 'galatians': 'Galatians',
    'eph': 'Ephesians', 'ephesians': 'Ephesians',
    'phil': 'Philippians', 'col': 'Colossians',
    'heb': 'Hebrews', 'hebrews': 'Hebrews',
    'ps': 'Psalms', 'psalm': 'Psalms', 'psalms': 'Psalms',
    'isa': 'Isaiah', 'isaiah': 'Isaiah',
    'rev': 'Revelation', 'revelation': 'Revelation',
    'jas': 'James', 'james': 'James',
    '1jn': '1 John', '1john': '1 John',
    'gen': 'Genesis', 'genesis': 'Genesis',
    'deut': 'Deuteronomy', 'deuteronomy': 'Deuteronomy',
}


def fetch(refetch=False):
    if not refetch and os.path.exists(CACHE):
        return open(CACHE, encoding='utf-8', errors='replace').read()
    req = urllib.request.Request(PAGE, headers={'User-Agent': 'yswords-124'})
    with urllib.request.urlopen(req, timeout=60) as r:
        html = r.read().decode('utf-8', 'replace')
    open(CACHE, 'w', encoding='utf-8').write(html)
    return html


def their_messages(html):
    rows = re.findall(
        r'<a class="linkstyle" href="(matthew-\d+)"[^>]*>(.*?)</a>',
        html, re.S | re.I)
    out = []
    for slug, txt in rows:
        t = H.unescape(re.sub(r'\s+', ' ', re.sub(r'<[^>]+>', '', txt))).strip()
        m = re.match(r'Message\s+(\d+)\s*[-–]\s*(.*?)\s*\(([^)]*)\)\s*$', t)
        if m:
            out.append({'n': m.group(1), 'title': m.group(2),
                        'ref': m.group(3), 'slug': slug})
        else:
            # Six of them are titled without a parenthetical reference.
            m2 = re.match(r'Message\s+(\d+)\s*[-–]\s*(.*)$', t)
            out.append({'n': m2.group(1) if m2 else None,
                        'title': m2.group(2) if m2 else t,
                        'ref': None, 'slug': slug})
    return out


def parse_ref(p):
    """First passage in a reference string -> (Book, chapter, verse|None)."""
    if not p:
        return None
    s = p.strip().replace('.', ' ').replace(':', ' ')
    m = re.match(r'^([1-3]?\s*[A-Za-z]+)\s+(\d+)(?:\s+(\d+))?', s)
    if not m:
        return None
    book = BOOK.get(re.sub(r'\s+', '', m.group(1)).lower())
    if not book:
        return None
    return (book, int(m.group(2)),
            int(m.group(3)) if m.group(3) else None)


def norm(s):
    s = re.sub(r'[^a-z0-9 ]', ' ', (s or '').lower())
    return re.sub(r'\s+', ' ', s).strip()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--json', help='write the mapping here')
    ap.add_argument('--refetch', action='store_true')
    args = ap.parse_args()

    theirs = their_messages(fetch(args.refetch))
    if len(theirs) != 124:
        sys.exit(f'REFUSE: found {len(theirs)} messages, expected 124 — '
                 'the page shape changed')

    with open(os.path.join(ROOT, 'assets/sermons/index.json'),
              encoding='utf-8') as fh:
        ours = json.load(fh)

    by_verse, by_chapter = {}, {}
    no_passage = 0
    for o in ours:
        k = parse_ref(o.get('passage'))
        if not k:
            no_passage += 1
            continue
        by_verse.setdefault(k, []).append(o)
        by_chapter.setdefault((k[0], k[1]), []).append(o)

    # Secondary key: every scripture our transcripts actually quote.
    # `assets/sermons/refs.json` is the citation index the sermon pages
    # already use, so this costs nothing to consult and reaches the 124
    # sermons whose `passage` is empty.
    by_id = {o['id']: o for o in ours}
    with open(os.path.join(ROOT, 'assets/sermons/refs.json'),
              encoding='utf-8') as fh:
        cited = json.load(fh).get('byVerse', {})
    cite_verse, cite_chapter = {}, {}
    for ref, ids in cited.items():
        k = parse_ref(ref)
        if not k:
            continue
        cite_verse.setdefault(k, set()).update(ids)
        cite_chapter.setdefault((k[0], k[1]), set()).update(ids)

    result = []
    tally = {'exact': 0, 'chapter': 0, 'cited': 0, 'none': 0}
    for t in theirs:
        k = parse_ref(t['ref'])
        cands = by_verse.get(k, []) if k else []
        tier = 'exact'
        if not cands and k:
            cands = by_chapter.get((k[0], k[1]), [])
            tier = 'chapter'
        if not cands and k:
            # Nothing is ABOUT it. Does anything quote it?
            ids = (cite_verse.get(k) or cite_chapter.get((k[0], k[1]))
                   or set())
            cands = [by_id[i] for i in sorted(ids) if i in by_id]
            tier = 'cited' if cands else 'none'
        if not cands:
            tier = 'none'

        best = None
        if len(cands) == 1:
            best = cands[0]
        elif cands:
            # Ties only. Title similarity decides WHICH of several
            # equally-referenced recordings, never WHETHER there is one.
            scored = sorted(
                cands,
                key=lambda o: difflib.SequenceMatcher(
                    None, norm(t['title']),
                    norm(o.get('title'))).ratio(),
                reverse=True)
            best = scored[0]
            if tier == 'exact':
                tier = 'chapter'

        tally[tier] += 1
        result.append({
            'message': t['n'], 'theirTitle': t['title'], 'ref': t['ref'],
            'url': f'https://www.christiandiscipleschurch.org/{t["slug"]}',
            'pdf': ('https://www.christiandc.org/sites/default/files/'
                    f'124_messages/pdf/matthew_sermon_{t["n"]}.pdf'
                    if t['n'] else None),
            'tier': tier,
            'ourId': best['id'] if best else None,
            'ourTitle': best.get('title') if best else None,
            'ourPassage': best.get('passage') if best else None,
            'candidates': [c['id'] for c in cands],
        })

    print(f'church messages : {len(theirs)}')
    print(f'our sermons     : {len(ours)}')
    print(f"  exact   {tally['exact']:>3}  unique recording on the same verse")
    print(f"  chapter {tally['chapter']:>3}  ambiguous — same chapter, or "
          f'several ours')
    print(f"  cited   {tally['cited']:>3}  only quoted, never expounded")
    print(f"  none    {tally['none']:>3}  nothing at all")
    print(f'\nour index carries NO passage for {no_passage} of {len(ours)} '
          f'sermons, so the top two tiers see only {len(ours) - no_passage}')
    covered = {r['ourId'] for r in result if r['ourId']}
    print(f'\nour sermons referenced at least once: {len(covered)}')

    print('\n--- none (nothing at all) ---')
    for r in result:
        if r['tier'] == 'none':
            print(f"  {r['message']}  {str(r['ref'])[:26]:<28} "
                  f"{r['theirTitle'][:44]}")

    if args.json:
        with open(args.json, 'w', encoding='utf-8') as fh:
            json.dump(result, fh, ensure_ascii=False, indent=1)
        print(f'\nwrote {args.json}')


if __name__ == '__main__':
    main()
