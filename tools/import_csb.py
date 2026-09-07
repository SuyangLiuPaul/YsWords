#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Build `assets/csb.json` from the CSB module in the 雅伟的话 database.

Licence: `docs/permissions/` holds the 2017 Holman grant and the record
of the owner's decisions on territory and scope. Read that first — this
script only moves text; it does not decide whether the text may ship.

    python3 tools/import_csb.py [--dry-run] [--report FILE]

WHAT THE SOURCE IS
------------------
`bsapp_bible_hcsbs` in the local MariaDB — 31,102 verses, a theWord-style
module. The table name is a legacy key: the 雅伟的话 note verifies
verse-by-verse that the text is **CSB 2017**, not HCSB (Ps 23:1 "I have
what I need", Rom 1:1 "servant", John 3:16 lower-case "his one and only
Son"). Its `_old` twin is byte-identical in every respect this script
cares about, so nothing here is undoing a previous pass.

THE MARKUP, ALL OF IT
---------------------
Counted, not assumed — every `<...>` in all 31,102 verses falls into
five kinds, and this script handles each explicitly rather than
blank-stripping angle brackets and hoping:

    WH####/WG#### 503,254   Strong's numbers (+2 malformed, see below)
    CL             24,655   poetic line break
    CM              9,932   paragraph break
    TS#…Ts          2,837   section heading, carried INSIDE verse text
    redletter       1,269   words of Christ

Section headings are dropped rather than concatenated: left in, Ps 23:1
would read "The Good ShepherdA psalm of David…". The app draws headings
from `assets/section_titles.json`, which is a separate file for exactly
this reason.

Strong's numbers are dropped here. That is right for THIS app, which
ships no tagged text; SeekSparks, which has `assets/tagged/`, wants them
kept and needs its own importer rather than this one with a flag.

THE DIVINE NAME — the one substantive edit, and why it is not one
-----------------------------------------------------------------
The module already reads **Yahweh** in 5,041 verses and contains the
string "the LORD" in none. But 982 verses still read "Lord", including
Deuteronomy 6:4 — the Shema. Loading it as-is would put a text that
spells the divine name two ways into an app named for that name.

They are not a translation choice; they are a **typographic residue**.
CSB prints YHWH as small-caps LORD and Adonai as ordinary Lord. When
this module lost the small-caps run it left the space that carried it,
so a lost LORD reads `Lord ` + another space:

    Deut 6:4   "The Lord  our God, the Lord  is one."
    Gen 4:16   "went out from the Lord ’s presence"

and a genuine Adonai does not:

    Ps 110:1   "the declaration of Yahweh   to my Lord:"   <- both, one verse

That is the rule below: `Lord` followed by an extra space becomes
Yahweh. It restores the publisher's own distinction from evidence inside
the publisher's own text. It is not a new editorial layer.

**Two checks that it is the right rule, both recorded because a rule
that only its author has tested is a guess:**

1. 955 of the 982 are independently corroborated by
   `assets/cuvs-yhwh.json` — the Yahweh-restored Chinese this app
   already ships — which reads 雅伟 at the same verse.
2. The 46 verses that contain both Yahweh and a normally-spaced Lord
   come through untouched. Ps 110:1 is the test case.

**What is deliberately NOT touched.** 190 verses read 雅伟 in the
Chinese while the English says Lord with no residue: Ps 130:3 (already
"Yah"), Matt 1:20 (Greek Kyrios), Isa 9:17 and Amos 8:3 (Adonai / Lord
GOD). Those are the Chinese edition's own restoration choices. Applying
them to the English would be re-translating the CSB, which is a thing
this repo does not do to anybody's text.
"""
import argparse
import io
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)
OUT = os.path.join(PROJECT, 'assets', 'csb.json')
KJV = os.path.join(PROJECT, 'assets', 'kjv.json')
CUV = os.path.join(PROJECT, 'assets', 'cuvs-yhwh.json')
YDH = os.path.expanduser('~/Documents/CodingProject/Yahwehdehua')

TABLE = 'bsapp_bible_hcsbs'
EXPECTED_VERSES = 31102
EXPECTED_BOOKS = 66

# Credentials live in the 雅伟的话 repo's own importer, which is where
# they already are; they are read, never printed, and never copied here.
CREDS_FROM = os.path.join(YDH, 'tools', 'fix-hcsb.py')


def _creds():
    src = io.open(CREDS_FROM, encoding='utf-8').read()
    mariadb = re.search(r"^MARIADB\s*=\s*'([^']*)'", src, re.M).group(1)
    db, user, pw = re.search(
        r"^DB,\s*USER,\s*PW\s*=\s*'([^']*)',\s*'([^']*)',\s*'([^']*)'",
        src, re.M).groups()
    return mariadb, db, user, pw


def fetch_rows():
    mariadb, db, user, pw = _creds()
    proc = subprocess.run(
        [mariadb, '-u', user, f'-p{pw}', db, '-N', '-B', '-e',
         f'SELECT book,chapter,verse,scripture FROM {TABLE} ORDER BY id'],
        capture_output=True, text=True)
    if proc.returncode != 0:
        sys.exit(f'query failed: {proc.stderr.strip()}')
    rows = [l.split('\t') for l in proc.stdout.split('\n') if l.count('\t') >= 3]
    if len(rows) != EXPECTED_VERSES:
        sys.exit(f'expected {EXPECTED_VERSES} verses, got {len(rows)}')
    return [(b, int(c), int(v), s) for b, c, v, s in rows]


# ── the divine name ─────────────────────────────────────────────────
# Applied to the RAW row, before any tag becomes a space. Doing it after
# would let a `<CL>` turned into a space manufacture the very residue
# this matches, and "the Lord<CL> and" is an ordinary poetic line break,
# not a lost LORD.
#
# The article goes with it. The 5,041 verses the module already restored
# read "Yahweh is my shepherd", never "the Yahweh is my shepherd": across
# all of them "The Yahweh" appears 0 times and "Yahweh's" is written
# without the article. Replacing only the word would have shipped
# "The Yahweh our God, the Yahweh is one" as the Shema, which is how this
# was caught — by reading the output rather than the count.
#
# TWO rules, because one was not safe. The residue is decisive when the
# article is there — "the LORD" is how CSB renders YHWH, and all 1,045
# such verses agree with the Chinese wherever the Chinese speaks. It is
# NOT decisive without one: seven verses carry the residue on a bare
# vocative "Lord", and they split 4/3.
#
#   1Sam 14:41  "Jonathan, Lord  God of Israel"   中文 雅伟   -> Yahweh
#   1Kgs 8:26   "Now Lord  God of Israel"         中文 (神啊) -> Yahweh
#   1Chr 17:16  "Who am I, Lord  God"             中文 雅伟神 -> Yahweh
#   Joel 2:17   "Have pity on your people, Lord " 中文 雅伟啊 -> Yahweh
#   Ps 44:23    "Wake up, Lord !"                 中文 主啊   -> Adonai, leave
#   Ps 62:12    "belongs to you, Lord ."          中文 主啊   -> Adonai, leave
#   Ps 116:8    "For you, Lord , rescued me"      中文 主啊   -> Adonai, leave
#
# So the bare vocative needs a witness. The one used is **KJV**, which
# this app already ships: it renders YHWH as all-caps LORD and Adonai as
# "Lord", the same distinction CSB makes, and `assets/kjv.json` is
# verse-aligned with this import by construction. It is independent of
# the Chinese edition and needs no network.
#
# It also corrected the author of this script. 1Kgs 8:26 was going to be
# restored by hand on the reasoning that "Now Lord God of Israel" must be
# YHWH; KJV reads "And now, O God of Israel" with no LORD at all, so the
# Hebrew has no name there and the Chinese — which also declined it — was
# right. Judgement lost to the witness, which is the point of having one.
#
# Had no witness been used, three Psalms would address Adonai by the
# personal name.
LOST_LORD_ARTICLE = re.compile(
    r'\b[Tt]he Lord (?=[\s,.;:!?’”\'")]|$)')
LOST_LORD_BARE = re.compile(r'\bLord (?=[\s,.;:!?’”\'")]|$)')

TS = re.compile(r'<TS\d*>.*?<Ts>')
STRONGS = re.compile(r'<W[HG]\d+[a-z]?>')   # the trailing letter covers
                                            # WH5766x / WH853x, the two
                                            # malformed tags in the module
REDLETTER = re.compile(r'</?redletter>')
BREAKS = re.compile(r'<C[LM]>')
ANY_TAG = re.compile(r'<[^>]*>')
SPACE_BEFORE_PUNCT = re.compile(r'\s+(?=[,.;:!?’”)])')


# The module's OWN restoration left the article standing in ten places —
# "This is the Yahweh's gate" (Ps 118:20), "the house of the Yahweh God"
# (1Chr 22:1), "Holy to the Yahweh" (Ex 28:36). Not English, and not the
# convention the other 5,041 follow. Repaired here rather than left,
# because this import is where the name is being made consistent and
# leaving ten behind would defeat the point.
STRAY_ARTICLE = re.compile(r'\b[Tt]he Yahweh\b')


def clean(raw, kjv_has_yhwh):
    """Returns (text, n_name_fixes, leftover_tags).

    [kjv_has_yhwh] is whether the KJV verse at this same id prints
    all-caps LORD. It decides ONLY the bare-vocative case; the article
    rule does not consult it, so a verse KJV renders differently is
    still restored on the CSB's own typographic evidence.
    """
    s, n = LOST_LORD_ARTICLE.subn('Yahweh ', raw)
    if kjv_has_yhwh:
        s, extra = LOST_LORD_BARE.subn('Yahweh ', s)
        n += extra
    s = TS.sub('', s)
    s = STRONGS.sub('', s)
    s = REDLETTER.sub('', s)
    s = BREAKS.sub(' ', s)
    leftover = ANY_TAG.findall(s)
    s = ANY_TAG.sub('', s)
    s = SPACE_BEFORE_PUNCT.sub('', s)
    s = re.sub(r'\s+', ' ', s).strip()
    # AFTER the tags, not before: in the raw module the article and the
    # name are separated by a Strong's tag — `the<WH9998> Yahweh` — so a
    # pattern run on the raw row matches two of the ten and silently
    # misses eight. Found by reading the output, not the regex.
    s, stray = STRAY_ARTICLE.subn('Yahweh', s)
    n += stray
    return s, n, leftover


def book_map(rows):
    """Abbreviation → the book name this app already uses.

    Derived by canonical position from `kjv.json` rather than typed out:
    a hand-written table of 66 names is 66 chances to introduce the one
    typo that puts Philemon's text under Philippians. Both sides are
    31,102 verses in canonical order, so position IS the mapping, and
    the assertions below are what make that safe to say.
    """
    kjv = json.load(io.open(KJV, encoding='utf-8'))
    if len(kjv) != EXPECTED_VERSES:
        sys.exit('kjv.json is not the expected length; cannot map books')
    kjv_books, seen = [], set()
    for r in kjv:
        if r['book'] not in seen:
            seen.add(r['book'])
            kjv_books.append(r['book'])
    src_books, seen = [], set()
    for b, _c, _v, _s in rows:
        if b not in seen:
            seen.add(b)
            src_books.append(b)
    if len(kjv_books) != EXPECTED_BOOKS or len(src_books) != EXPECTED_BOOKS:
        sys.exit(f'expected {EXPECTED_BOOKS} books, got '
                 f'{len(kjv_books)} / {len(src_books)}')
    # Verse counts per book must agree too, or the two canons are
    # ordered the same but versified differently and position lies.
    def counts(pairs):
        out = {}
        for b in pairs:
            out[b] = out.get(b, 0) + 1
        return out
    kc = counts([r['book'] for r in kjv])
    sc = counts([b for b, _c, _v, _s in rows])
    for kb, sb in zip(kjv_books, src_books):
        if kc[kb] != sc[sb]:
            sys.exit(f'{sb} has {sc[sb]} verses but {kb} has {kc[kb]}; '
                     'the two canons are not aligned')
    return dict(zip(src_books, kjv_books))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--report', help='write the divine-name changes here')
    args = ap.parse_args()

    rows = fetch_rows()
    names = book_map(rows)
    cuv = json.load(io.open(CUV, encoding='utf-8'))
    kjv = json.load(io.open(KJV, encoding='utf-8'))
    # All-caps LORD, not the word "Lord": the whole value of KJV as a
    # witness is that it keeps the two apart.
    lord = re.compile(r'\bLORD\b')

    out, changed, leftovers = [], [], set()
    for (b, c, v, raw), cn, kv in zip(rows, cuv, kjv):
        text, n, left = clean(raw, bool(lord.search(kv['text'])))
        leftovers.update(left)
        if n:
            changed.append((names[b], c, v, n, '雅伟' in cn['text'], text))
        book = names[b]
        out.append({
            'book': book,
            'chapter': str(c),
            'verse': str(v),
            'text': text,
            'id': f'{list(names.values()).index(book) + 1:03d}'
                  f'{c:03d}{v:03d}',
        })

    # Rebuild ids from the canonical order once, rather than calling
    # .index() per verse (which is O(n²) and, worse, silently wrong if a
    # name ever repeats).
    order = {n: i + 1 for i, n in enumerate(dict.fromkeys(
        names[b] for b, _c, _v, _s in rows))}
    for rec in out:
        rec['id'] = (f"{order[rec['book']]:03d}"
                     f"{int(rec['chapter']):03d}{int(rec['verse']):03d}")

    corroborated = sum(1 for r in changed if r[4])
    print(f'verses                     : {len(out)}')
    print(f'books                      : {len(order)}')
    print(f'divine-name restorations   : {len(changed)}')
    print(f'  corroborated by cuvs-yhwh: {corroborated}')
    print(f'leftover tag kinds         : '
          f'{sorted(leftovers) if leftovers else "none"}')
    if leftovers:
        sys.exit('unhandled markup — refusing to write a file with tags in it')

    # Spot checks that would have caught every defect found while writing
    # this, printed rather than asserted so a human sees the actual text.
    by_id = {r['id']: r['text'] for r in out}
    for label, vid in [('Deut 6:4  ', '005006004'),
                       ('Ps 23:1   ', '019023001'),
                       ('Ps 110:1  ', '019110001'),
                       ('John 3:16 ', '043003016')]:
        print(f'  {label} {by_id[vid][:88]}')

    if args.report:
        with io.open(args.report, 'w', encoding='utf-8') as f:
            f.write(f'# CSB divine-name restorations ({len(changed)})\n\n')
            f.write('`Lord ` + extra space -> `Yahweh`. See the module '
                    'docstring in tools/import_csb.py for why this is a '
                    'typographic repair and not a translation change.\n\n')
            f.write('| ref | n | in cuvs-yhwh | verse |\n|---|---|---|---|\n')
            for bk, c, v, n, zh, t in changed:
                f.write(f'| {bk} {c}:{v} | {n} | '
                        f'{"yes" if zh else "—"} | {t[:110]} |\n')
        print(f'report                     : {args.report}')

    if args.dry_run:
        print('dry run — nothing written')
        return
    with io.open(OUT, 'w', encoding='utf-8') as f:
        json.dump(out, f, ensure_ascii=False, separators=(',', ':'))
    print(f'wrote                      : {OUT} '
          f'({os.path.getsize(OUT) / 1e6:.1f} MB)')


if __name__ == '__main__':
    main()
