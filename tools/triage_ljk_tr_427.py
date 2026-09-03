#!/usr/bin/env python3
"""Triage the Traditional verses that differ from the printed 註釋本.

WHY THIS EXISTS
---------------
`proofread_ljk_tr.py` reports the verses where our Traditional differs
from the publisher's printed 《新約聖經 梁家鏗譯本（註釋本）》2025 第二版.
§四之二 of `docs/梁家鏗譯本-請教出版方.md` carries the wording ones, and
the letter used to gate itself on deciding, for every one of them,
「是出版方的修訂，還是我們的缺陷」.

That gate could never be satisfied, because it is circular. Whether a
difference is *their revision* depends on which edition governs, and
which edition governs is the very thing §四之二 asks them. So the letter
could not be finished, and the question could not be asked.

THE QUESTION THAT BREAKS THE CIRCLE
-----------------------------------
There are three published states of this text, not two — 啟示錄 20:4
proves it. Our reading matches the 2025 print word for word, while the
publisher's current electronic Traditional (`tw-rev.json`) differs from
BOTH. So for a verse that differs from the print, there is a second
question, and this one needs no answer from the publisher:

    does our reading match the publisher's CURRENT electronic
    Traditional?

  yes → we are holding a reading the publisher themselves published.
        Not a defect of ours. It is genuinely an edition question, and
        it belongs in the letter.
  no  → our reading appears in neither official source, which would make
        it a third reading nobody published — almost certainly ours, and
        ours to fix rather than to ask about.

Two things stand between that question and a verdict, and both of them
would otherwise pile verses onto the "ours" side that are not ours:

* the publisher has revised their electronic file since we imported it,
  so a verse can fail against the current file and still be a reading
  they published (`--snapshot`, below);
* one word set in two glyphs is not two readings. 使徒行傳 20:32 reads
  託付 with us and 托付 in their file, and the difference is there
  because §三 of the letter conformed that character to the printed
  edition on purpose. Told apart the way `proofread_ljk_tr.admissible`
  does it — both characters reducing to the same Simplified character —
  which needs the opencc CLI; without it these fall in with the rest and
  the run says so.

WHICH FILE IS "CURRENT"
-----------------------
Not `ljk-nt-bible-webapp/public/resources/tw-*.json`. That directory is
untracked in the publisher's own repo (only `.dir` is committed), so it
is a snapshot somebody downloaded — and it is the snapshot we imported
FROM: its 啟示錄 20:4 is our reading character for character, 「參啟1.2註」
and all, where the live file reads 「坐在那些寶座上的」 and 「參啟1.2注」.
Classifying against it would be circular in a new way: it would answer
"do we match what we imported", which is always yes.

The current file is the one the publisher serves, and
`audit_biblexg_notes.py` already caches it, so this tool reuses that
cache (`--refresh` re-fetches). The local snapshot is still worth
consulting for the verses that fail — a reading that matches it is the
publisher's own EARLIER electronic reading, not an invention of ours —
so `--snapshot` reports that as a separate class.

HOW THE COMPARISON IS MADE
--------------------------
Against the PRINT: unchanged from `proofread_ljk_tr.py`, containment
against a digit-free flattened stream. Read its docstring for why it is
not verse by verse; reconstructing verse boundaries from `pdftotext`
invents alignment errors and then reports them as scripture defects.

Punctuation-only differences are split off first, because §四之二 counts
wording and the letter carries punctuation as its own bucket. A verse is
punctuation-only when every segment, with punctuation removed, is in the
print stream with punctuation removed.

Against the ELECTRONIC: their file is keyed by verse, so the primary
test is per-verse equality of the wording. It falls back to containment
in the book's stream when the key is missing or unequal, because the
publisher packs several verses into one `verseIndex` in a few places
(彼得前書 3:10 holds 3:10-12, 以弗所書 3:15 holds 3:16, 路加福音 23:33
holds 23:34a) and our importer splits them. Without the fallback those
verses report as differences that do not exist.

`<note:…>` on our side and `<cite>…</cite>` on theirs are removed before
comparing, on both sides alike — the same reason `proofread_ljk_tr.py`
splits on `<note:>`. Comparing them as body text reports every inline
citation as a difference in wording.

USAGE
-----
    python3 tools/triage_ljk_tr_427.py
    python3 tools/triage_ljk_tr_427.py --refresh          # re-fetch theirs
    python3 tools/triage_ljk_tr_427.py --json out.json

Needs the five printed volumes extracted to /tmp/ljk_tr — see
`proofread_ljk_tr.py`. Read-only: it reports, it never edits assets/.
"""
import argparse
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import audit_biblexg_notes as notes          # noqa: E402  BOOKS, fetch()
import proofread_ljk_tr as print_edition     # noqa: E402  VOLUMES, stream()

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SNAPSHOT = os.path.join(REPO_ROOT, 'ljk-nt-bible-webapp/public/resources')

# Traditional book name -> the publisher's file abbreviation.
ABBR = {tw: abbr for abbr, _cn, tw in notes.BOOKS}

# Everything that is not a word. Kept as one list so that the print side
# and the electronic side are stripped by exactly the same rule.
PUNCT = re.compile(r'[，。、；：？！「」『』“”‘’（）〈〉《》〔〕【】…—–－·~～\s　'
                   r'\.,;:?!\'"()\[\]-]')


def wording(text):
    """One verse reduced to the words, from either side's markup.

    Notes go — ours as `<note:…>`, theirs as `<cite>…</cite>` — then all
    remaining tags, then digits and non-CJK scripts (verse numbers, the
    Greek and Hebrew the publisher sets in `<mark>`), then punctuation.
    """
    text = re.sub(r'<cite>.*?</cite>', '', text, flags=re.S)
    text = re.sub(r'<note:[^>]*>', '', text)
    text = re.sub(r'<[^>]+>', '', text)
    text = re.sub(r'[0-9A-Za-zͰ-Ͽἀ-῿֐-׿]', '', text)
    return PUNCT.sub('', text)


def electronic(chapters):
    """{(chapter, verseLabel): text} from one publisher book file.

    Contents are joined per key rather than assigned, because a packed
    node can carry the same `verseIndex` twice.
    """
    out, chapter = {}, None
    for chap in chapters:
        for node in chap.get('nodeData', []):
            if node.get('type') == 'chapter':
                chapter = str(node['chapterIndex'])
            if node.get('type') != 'verse':
                continue
            label = str(node.get('verseIndex', '')).strip()
            if not label:
                continue
            out.setdefault((chapter, label), []).append(''.join(
                c['content'] if isinstance(c, dict) else str(c)
                for c in node.get('contents', [])))
    return {k: ''.join(v) for k, v in out.items()}


def differs_from_print(ours, min_segment=4):
    """The verses `proofread_ljk_tr.py` reports, split into two buckets.

    Returns (punctuation_only, wording_differences). The wording list is
    the population §四之二 of the publisher letter is about.
    """
    punct_only, differ = [], []
    for name, books in print_edition.VOLUMES.values():
        path = os.path.join(print_edition.SRC, name)
        if not os.path.exists(path):
            sys.exit(f'{path} missing — extract the five printed volumes '
                     f'first; see proofread_ljk_tr.py')
        lines = open(path, encoding='utf-8').read().split('\n')
        for book in books:
            start, end = print_edition.book_body(lines, book, books)
            printed = print_edition.stream(lines[start:end], book)
            bare = PUNCT.sub('', printed)
            for verse in (v for v in ours if v['book'] == book):
                segs = [s for s in print_edition.segments(verse['text'])
                        if len(s) >= min_segment]
                if not segs or all(s in printed for s in segs):
                    continue
                if all(PUNCT.sub('', s) in bare for s in segs):
                    punct_only.append(verse)
                else:
                    differ.append(verse)
    return punct_only, differ


def glyph_pairs(mine, theirs):
    """The character pairs by which two readings of one verse differ.

    None unless the two are the same words in the same order — equal
    length, and every mismatch a pair of glyphs for one character. A
    difference in wording changes the length or the word, and either
    way this returns None rather than a pair list.
    """
    if len(mine) != len(theirs) or mine == theirs:
        return None
    pairs = [(a, b) for a, b in zip(mine, theirs) if a != b]
    try:
        t2s = print_edition.to_simplified({c for p in pairs for c in p})
    except SystemExit:  # no opencc — say nothing rather than guess
        return None
    if any(t2s.get(a) != t2s.get(b) for a, b in pairs):
        return None
    return pairs


def held_on_their_authority(verse, verses, stream):
    """Is our reading of this verse one the publisher published?

    Per-verse first, then containment — see the module docstring on the
    packed `verseIndex` nodes.
    """
    mine = wording(verse['text'])
    theirs = verses.get((verse['chapter'], verse['verseLabel']))
    if theirs is not None and wording(theirs) == mine:
        return True
    return bool(mine) and mine in stream


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--assets', default='assets/biblexg-v2-tr.json')
    ap.add_argument('--refresh', action='store_true',
                    help="re-fetch the publisher's current electronic files")
    ap.add_argument('--snapshot', default=SNAPSHOT,
                    help='the publisher electronic files as downloaded at '
                         'import time, consulted only for the verses that '
                         'fail against the current ones')
    ap.add_argument('--min-segment', type=int, default=4)
    ap.add_argument('--json', help='write the classification to a file')
    args = ap.parse_args()

    ours = json.load(open(os.path.join(REPO_ROOT, args.assets),
                          encoding='utf-8'))
    punct_only, differ = differs_from_print(ours, args.min_segment)

    current, streams = {}, {}
    for book, abbr in ABBR.items():
        current[book] = electronic(notes.fetch('tw', abbr, args.refresh))
        streams[book] = ''.join(wording(t) for t in current[book].values())

    snapshot, snap_streams = {}, {}
    if not os.path.isdir(args.snapshot):
        # Silently skipping it would move every verse the publisher has
        # revised since our import into the "ours to fix" pile, which is
        # the one verdict that must never be reached by accident.
        print(f'WARNING: {args.snapshot} is not there, so "their file as '
              f'we imported it" cannot be consulted. Verses the publisher '
              f'has revised since will be reported as ours. Pass '
              f'--snapshot with the path in the main checkout.',
              file=sys.stderr)
    for book, abbr in ABBR.items():
        path = os.path.join(args.snapshot, f'tw-{abbr}.json')
        if not os.path.exists(path):
            continue
        snapshot[book] = electronic(json.load(open(path, encoding='utf-8')))
        snap_streams[book] = ''.join(wording(t)
                                     for t in snapshot[book].values())

    theirs, superseded, glyph_only, ours_to_fix = [], [], [], []
    pairs_of = {}
    for verse in differ:
        book = verse['book']
        key = (verse['chapter'], verse['verseLabel'])
        if held_on_their_authority(verse, current[book], streams[book]):
            theirs.append(verse)
            continue
        if book in snapshot and held_on_their_authority(
                verse, snapshot[book], snap_streams[book]):
            superseded.append(verse)
            continue
        pairs = glyph_pairs(wording(verse['text']),
                            wording(current[book].get(key) or ''))
        if pairs:
            pairs_of[(book,) + key] = pairs
            glyph_only.append(verse)
        else:
            ours_to_fix.append(verse)

    verdicts = [
        ("the publisher's current electronic Traditional", theirs),
        ('their electronic file as we imported it, since revised',
         superseded),
        ('their current file but for a glyph we took from the print',
         glyph_only),
        ('NO publisher file we hold — ours to fix', ours_to_fix),
    ]

    print(f'differ from the printed 註釋本 : {len(punct_only) + len(differ):,}')
    print(f'  punctuation only           : {len(punct_only):,}')
    print(f'  wording                    : {len(differ):,}')
    print()
    print(f'of those {len(differ):,}, our reading is —')
    for label, group in verdicts:
        print(f'  {len(group):>4,}  {label}')
    print()

    for label, group in verdicts[1:]:
        if not group:
            continue
        print(f'== {label}')
        for verse in group:
            book = verse['book']
            key = (verse['chapter'], verse['verseLabel'])
            print(f"{book} {verse['chapter']}:{verse['verseLabel']}")
            print(f"  ours     : {verse['text']}")
            print(f"  current  : {current[book].get(key)}")
            print(f"  imported : {snapshot.get(book, {}).get(key)}")
            pairs = pairs_of.get((book,) + key)
            if pairs:
                print('  glyphs   : ' + '、'.join(f'{a}／{b}'
                                                 for a, b in pairs))
        print()

    if args.json:
        def rows(group, verdict):
            return [{'book': v['book'], 'chapter': v['chapter'],
                     'verse': v['verseLabel'], 'verdict': verdict,
                     'ours': v['text'],
                     'current': current[v['book']].get(
                         (v['chapter'], v['verseLabel'])),
                     'imported': snapshot.get(v['book'], {}).get(
                         (v['chapter'], v['verseLabel']))}
                    for v in group]
        json.dump(rows(theirs, 'publisher-current')
                  + rows(superseded, 'publisher-superseded')
                  + rows(glyph_only, 'publisher-current-but-print-glyph')
                  + rows(ours_to_fix, 'no-publisher-source'),
                  open(args.json, 'w', encoding='utf-8'),
                  ensure_ascii=False, indent=1)
        print(f'wrote {args.json}', file=sys.stderr)
    return 0


if __name__ == '__main__':
    sys.exit(main())
