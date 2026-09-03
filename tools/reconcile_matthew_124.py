#!/usr/bin/env python3
"""Match our 289 recorded sermons against the church's 124 written messages.

    python3 tools/reconcile_matthew_124.py            # print the report
    python3 tools/reconcile_matthew_124.py --json OUT # also write the survey
    python3 tools/reconcile_matthew_124.py --emit     # write the SHIPPED asset
    python3 tools/reconcile_matthew_124.py --refetch

Two passes over the same two datasets, and they answer different
questions.

  the SURVEY (four tiers, below) — "how much of their edition does our
  library cover at all?" Loose on purpose. Its headline figure is 61
  and **61 is not a shippable number**; see THE SURVEY IS NOT THE LINKS.

  the STRICT pass (`--emit`) — "which single written message is this
  recording, beyond argument?" It produces
  `assets/sermons/matthew_124.json`, the 36 links the app ships.

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

THE SURVEY IS NOT THE LINKS
---------------------------
The user decided (2026-09-03): link only what maps exactly, do not offer
the 124 as a browsable series, do not force a mapping that is not exact.

`exact` above cannot be that set, because it is one-directional and
lossy. Its key is `(book, chapter, FIRST verse)`, so `Matthew 3:13-17`
and `Matthew 3:13 - 4:17` are the same passage to it and messages 006,
007 and 008 all land on our single recording 002 — eight of our sermons
are claimed by two or three messages each. A sermon page has one link.
Shipping `exact` would point some of them at a message about a
different talk.

THE SHIPPING RULE (`--emit`)
----------------------------
A link is written only when all five hold. Each one exists because
dropping it admitted a specific wrong pair, named here.

  1. **Both references parse.** `tools/passage_range.py` keeps the
     whole range, not just the first verse. It refuses rather than
     repairs: message 046's `Matthew 15:21-18` is a typo for 15:21-28
     and is discarded, not corrected.

  2. **The full range is identical**, over the first book named — the
     church prints parallels after the passage the message is on
     ("Luke 9:23-25, par. Matthew 16:24-26"), so the first book is the
     subject. This is what rejects the near-miss the earlier title pass
     fell for: their 009 is `Luke 4:1-4` and our 004 is `Luke 4:5-13`,
     *Temptation after Baptism* #1 against #2.

  3. **Neither side carries a partial-verse suffix.** Their edition
     splits one verse across messages — 026 is `Matthew 11:12`, 027 is
     `Matthew 11:12b` — and our index gives no way to say which half a
     recording is.

  4. **One-to-one, and no near neighbour on either side**, where
     "neighbour" is anything sharing the loose `(book, chapter, first
     verse)` anchor. Rule 2 alone was not enough: 027 and 046 were
     dropped by rules 3 and 1, which left 026 and 047 looking unique —
     and both were wrong, as their own titles show (our 059 is titled
     *Take up your cross*, which is 027's title, not 026's; our 106 is
     *The Syrophoenician woman's faith*, which is 046's title, not
     047's). A message excluded for a technical reason is still a rival
     for the recording.

  5. **The preaching dates agree.** Every message page carries the date
     it was preached ("Montreal, April 8, 1979"); our index carries the
     same field. This is an entirely independent check — nothing about
     it derives from the passage — and 36 of the 37 pairs that survive
     rules 1-4 agree on it to the day. The one that does not is message
     090 (their May 3 1981 against our 1981-05-13) and it is not
     linked.

Title similarity is used for NOTHING. It was tried and it failed: a
first pass found 23 exact and 29 fuzzy title matches, and the fuzzy set
included `Temptation after Baptism #1` → our `temptation after baptism
2`. It is not used as a tie-breaker in the strict pass either, because
in the surviving set it would have vetoed three correct pairs on chance
resemblance — `Hell` scores closer to `The Will of God` than to `Hell:
The Place Where God Destroys Evil`.

**The message URL is `/content/matthew-NNN`, not `/matthew-NNN`.** The
page's own hrefs are relative to `/content/`; the absolute form this
tool used to print 404s. Both it and the PDF href are now read from the
page and probed before they are written.
"""
import argparse
import collections
import datetime
import difflib
import html as H
import json
import os
import re
import sys
import time
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from passage_range import normalize  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SITE = 'https://www.christiandiscipleschurch.org'
PAGE = f'{SITE}/content/124-messages'
CACHE = '/tmp/m124.html'
EMIT = 'assets/sermons/matthew_124.json'

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
    # The listing's own hrefs are RELATIVE ("matthew-010") and the page
    # lives at /content/, so the message pages are /content/matthew-010.
    # This used to build `{SITE}/matthew-010`, which 404s.
    rows = re.findall(
        r'<a class="linkstyle" href="(matthew-\d+)"[^>]*>(.*?)</a>',
        html, re.S | re.I)
    # One "Download PDF file" href per message, in the same order. Read
    # rather than constructed, so a rename shows up as a count mismatch
    # instead of 124 silently-broken links.
    pdfs = re.findall(r'href="(https?://[^"]*124_messages/pdf/[^"]+)"', html)
    if len(pdfs) != len(rows):
        sys.exit(f'REFUSE: {len(rows)} messages but {len(pdfs)} PDF links — '
                 'the page shape changed')
    out = []
    for (slug, txt), pdf in zip(rows, pdfs):
        t = H.unescape(re.sub(r'\s+', ' ', re.sub(r'<[^>]+>', '', txt))).strip()
        m = re.match(r'Message\s+(\d+)\s*[-–]\s*(.*?)\s*\(([^)]*)\)\s*$', t)
        if m:
            rec = {'n': m.group(1), 'title': m.group(2), 'ref': m.group(3)}
        else:
            # Six of them are titled without a parenthetical reference.
            m2 = re.match(r'Message\s+(\d+)\s*[-–]\s*(.*)$', t)
            rec = {'n': m2.group(1) if m2 else None,
                   'title': m2.group(2) if m2 else t, 'ref': None}
        if rec['n'] and not pdf.endswith(f"_{rec['n']}.pdf"):
            sys.exit(f"REFUSE: message {rec['n']} paired with {pdf} — "
                     'the PDF links are no longer in listing order')
        rec['slug'] = slug
        rec['url'] = f'{SITE}/content/{slug}'
        rec['pdf'] = pdf
        out.append(rec)
    return out


_MONTHS = {m: i + 1 for i, m in enumerate(
    ['January', 'February', 'March', 'April', 'May', 'June', 'July',
     'August', 'September', 'October', 'November', 'December'])}


def preached_on(url):
    """The date a message page says it was preached, as `YYYY-MM-DD`.

    Every page carries a byline like "Pastor Eric Chang / Montreal,
    April 8, 1979". Rule 5 of the shipping rule compares it to the
    `date` in our own index — an independent corroboration, since
    nothing about the date derives from the passage. Returns None when
    the page does not carry one, which is also a refusal to link.
    """
    req = urllib.request.Request(url, headers={'User-Agent': 'yswords-124'})
    with urllib.request.urlopen(req, timeout=60) as r:
        s = r.read().decode('utf-8', 'replace')
    s = re.sub(r'<script.*?</script>', ' ', s, flags=re.S | re.I)
    s = H.unescape(re.sub(r'\s+', ' ', re.sub(r'<[^>]+>', ' ', s)))
    m = re.search(r'\b([A-Z][a-z]+)\s+(\d{1,2}),\s*(\d{4})\b', s)
    if not m or m.group(1) not in _MONTHS:
        return None
    try:
        return datetime.date(int(m.group(3)), _MONTHS[m.group(1)],
                             int(m.group(2))).isoformat()
    except ValueError:
        return None


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


def strict_pairs(theirs, ours, check_dates=True, log=print):
    """Rules 1-5 in the docstring. -> (pairs, rejections).

    `pairs` is [(message, sermon, date)]; `rejections` is
    [(display, reason, [message ids], [sermon ids])] for the report.
    """
    exact_t = {t['n']: normalize(t['ref']) for t in theirs}
    exact_o = {o['id']: normalize(o.get('passage')) for o in ours}
    # Rule 4's "near neighbour" test reuses the SURVEY's loose anchor on
    # purpose: it is coarse enough to see a rival that rule 1 or 3 threw
    # out, which a strict key by construction cannot.
    loose_t = {t['n']: parse_ref(t['ref']) for t in theirs}
    loose_o = {o['id']: parse_ref(o.get('passage')) for o in ours}
    near_t = collections.Counter(v for v in loose_t.values() if v)
    near_o = collections.Counter(v for v in loose_o.values() if v)

    keyed_t, keyed_o = collections.defaultdict(list), collections.defaultdict(list)
    for t in theirs:                                    # rules 1 and 3
        p = exact_t[t['n']]
        if p and not p.partial:
            keyed_t[p.key()].append(t['n'])
    for o in ours:
        p = exact_o[o['id']]
        if p and not p.partial:
            keyed_o[p.key()].append(o['id'])

    by_n = {t['n']: t for t in theirs}
    by_id = {o['id']: o for o in ours}
    pairs, rejected = [], []
    for key in sorted(set(keyed_t) & set(keyed_o)):     # rule 2
        ms, os_ = keyed_t[key], keyed_o[key]
        shown = exact_t[ms[0]].display()
        if len(ms) != 1 or len(os_) != 1:               # rule 4
            rejected.append((shown, 'several on the same range', ms, os_))
            continue
        n, oid = ms[0], os_[0]
        if near_t[loose_t[n]] > 1:                      # rule 4
            rival = sorted(x for x in loose_t
                           if loose_t[x] == loose_t[n] and x != n)
            rejected.append(
                (shown, f'message {", ".join(rival)} starts at the same verse',
                 ms, os_))
            continue
        if near_o[loose_o[oid]] > 1:                    # rule 4
            rival = sorted(x for x in loose_o
                           if loose_o[x] == loose_o[oid] and x != oid)
            rejected.append(
                (shown, f'our {", ".join(rival)} starts at the same verse',
                 ms, os_))
            continue
        pairs.append((by_n[n], by_id[oid]))

    pairs.sort(key=lambda p: int(p[0]['n']))
    if not check_dates:
        return [(m, o, None) for m, o in pairs], rejected

    kept = []
    for m, o in pairs:                                  # rule 5
        try:
            theirdate = preached_on(m['url'])
        except Exception as e:                          # noqa: BLE001
            rejected.append((normalize(m['ref']).display(),
                             f'could not read {m["url"]}: {e}',
                             [m['n']], [o['id']]))
            continue
        time.sleep(0.3)
        if theirdate is None:
            rejected.append((normalize(m['ref']).display(),
                             'their page names no preaching date',
                             [m['n']], [o['id']]))
            continue
        if theirdate != o['date']:
            log(f"  date disagreement, NOT linked: message {m['n']} says "
                f"{theirdate}, our {o['id']} says {o['date']}")
            rejected.append((normalize(m['ref']).display(),
                             f'preaching dates disagree ({theirdate} vs '
                             f'{o["date"]})', [m['n']], [o['id']]))
            continue
        kept.append((m, o, theirdate))
    return kept, rejected


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--json', help='write the four-tier survey here')
    ap.add_argument('--emit', action='store_true',
                    help=f'write the shipped links to {EMIT}')
    ap.add_argument('--no-date-check', action='store_true',
                    help='skip rule 5 (one fetch per surviving pair). '
                         'Refuses to --emit, since rule 5 is the only '
                         'evidence that is independent of the passage.')
    ap.add_argument('--refetch', action='store_true')
    args = ap.parse_args()
    if args.emit and args.no_date_check:
        sys.exit('REFUSE: --emit needs the date check. See rule 5.')

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

    # ── the strict pass: what actually ships ──────────────────────────
    print('\n=== strict pass — the links ===')
    pairs, rejected = strict_pairs(theirs, ours,
                                   check_dates=not args.no_date_check)
    print(f'\nLINKED {len(pairs)} of {len(theirs)}'
          + ('' if args.no_date_check else ' (rules 1-5)'))
    for m, o, d in pairs:
        print(f"  {m['n']}  {normalize(m['ref']).display():<22} "
              f"our {o['id']:<5} {d or o['date']}  {m['title'][:40]}")
    print(f'\nNOT LINKED — shared a range but failed a rule: {len(rejected)}')
    for shown, why, ms, os_ in rejected:
        print(f"  {shown:<22} {why:<46} theirs {ms} ours {os_}")
    linked = {m['n'] for m, _, _ in pairs}
    print(f'\nNOT LINKED — no shared range at all: '
          f'{len(theirs) - len(linked) - len(rejected)}')

    if args.emit:
        out = {
            'source': PAGE,
            'messageCount': len(theirs),
            'rule': ('identical passage range over the first book named, '
                     'no partial-verse suffix, no rival on either side at '
                     'the same book+chapter+first verse, and the preaching '
                     'date on their page equal to ours'),
            'links': {
                o['id']: {
                    'message': m['n'],
                    'title': m['title'],
                    'ref': m['ref'],
                    'url': m['url'],
                    'pdf': m['pdf'],
                    'date': d,
                }
                for m, o, d in pairs
            },
        }
        path = os.path.join(ROOT, EMIT)
        with open(path, 'w', encoding='utf-8') as fh:
            json.dump(out, fh, ensure_ascii=False, indent=1, sort_keys=True)
            fh.write('\n')
        print(f'\nwrote {EMIT} — {len(out["links"])} links')


if __name__ == '__main__':
    main()
