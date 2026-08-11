#!/usr/bin/env python3
"""Check every editorial note in 梁家鏗譯本 against the publisher's own JSON.

Why this exists
---------------
The queue carried an item reading "18 verses set an editor's gloss as
scripture in the Traditional", on the evidence that our Traditional
prints 「即葡萄酒，」 inside 馬太福音 26:29 while our Simplified marks the
same words as a note. That is the same shape as 羅馬書 16:24, where an
editor's manuscript note really had been flattened into the verse, so it
was filed as a scripture-accuracy defect.

It is not one. A diff of our two editions cannot tell "our importer lost
the markup" from "the publisher's two editions differ", and those need
opposite responses: the first is ours to fix, the second is ours to ask
about and otherwise leave alone. Only the publisher's own file can tell
them apart, because only it says whether the gloss sits in a `<cite>`.

The printed 註釋本 cannot settle it either — `pdftotext` renders a
footnote inline, indistinguishable from body text, so the extracted
volumes agree with whatever you already believed.

What it compares
----------------
Two passes, because they catch different things.

**Pass 1 — counts, per verse.** For each of the 7,919/7,920 verses, the
count of `<cite>` elements in the publisher's `tw-*.json` / `cn-*.json`
against the count of `<note:…>` markers in our shipped
`assets/biblexg-v2-tr.json` / `biblexg-v2.json`.

  ours < publisher  → we dropped an editorial note, and if the note was
                      inline its words are now sitting in the verse as
                      scripture. This is the defect worth finding.
  ours > publisher  → we invented one.

Result as of 2026-08-11 — 0 of either that is not accounted for below.

**Pass 2 — text, per chapter.** Pass 1 says a note is there; it does not
say it points anywhere near the right place. A wrong cross-reference is
not a false claim about what scripture says, but it is quoted in Bible
study, so it is worth a count.

It compares the multiset of note strings in a chapter, not verse by
verse, and that choice is load-bearing: the publisher packs several
verses into one `verseIndex` in four places and our importer splits
them, so a verse-keyed text comparison silently skips exactly those
verses — including 以弗所書 3:15, the one difference that was already
known when this pass was written. At chapter level the packing cannot
hide anything.

Both sides are normalised by stripping HTML (`<mark class="hebrew">`,
`<span class="affix">`, `<sup>`, which our importer drops on purpose)
and removing whitespace. Neither carries meaning in a citation, and
leaving them in reports 33 differences that are all markup.

Result as of 2026-08-11 — 1,134/1,135 tw and 1,133/1,134 cn note
strings, **6 chapters per edition whose text differs, and not one of
them is a defect of ours.** All are listed in ACCOUNTED_FOR_TEXT below.

Known non-defects, all verified individually rather than waved through:

  • An empty `<cite></cite>`. The upstream emits these as a chapter
    placeholder; `import_ljk2.py` discards them deliberately. 4 verses.
  • A publisher node that packs several verses into one `verseIndex`
    with `<sup>n</sup>` affixes (彼得前書 3:10 holds 10-12, 以弗所書 3:15
    holds 15-16). Our importer splits them, so the note lands on the
    verse it belongs to and this tool, which keys on the publisher's
    label, looks for it on the wrong one. Checked by hand: every such
    note is present on the right verse.
  • Upstream revision since our import. The publisher has revised ~136
    verse texts, and some of those moved a cross-reference with them —
    哥林多前書 15:11, 馬太福音 7:11 / 路加福音 11:9. Adopting them is the
    open question in §四之二 of the publisher letter, not a repair.

Usage:  python3 tools/audit_biblexg_notes.py [--refresh]

Read-only. Never writes to assets/.
"""

import json
import os
import re
import sys
import urllib.request
from collections import Counter

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_BASE = 'https://mattwhatsup.github.io/ljk-nt-bible-webapp/resources'
CACHE_DIR = os.path.expanduser('~/.cache/yswords/ljk-source')

# (upstream abbreviation, simplified book name, traditional book name)
BOOKS = [
    ('mt', '马太福音', '馬太福音'),
    ('mk', '马可福音', '馬可福音'),
    ('lk', '路加福音', '路加福音'),
    ('joh', '约翰福音', '約翰福音'),
    ('act', '使徒行传', '使徒行傳'),
    ('rom', '罗马书', '羅馬書'),
    ('1co', '哥林多前书', '哥林多前書'),
    ('2co', '哥林多后书', '哥林多後書'),
    ('gal', '加拉太书', '加拉太書'),
    ('eph', '以弗所书', '以弗所書'),
    ('phi', '腓立比书', '腓立比書'),
    ('col', '歌罗西书', '歌羅西書'),
    ('1th', '帖撒罗尼迦前书', '帖撒羅尼迦前書'),
    ('2th', '帖撒罗尼迦后书', '帖撒羅尼迦後書'),
    ('1ti', '提摩太前书', '提摩太前書'),
    ('2ti', '提摩太后书', '提摩太後書'),
    ('tit', '提多书', '提多書'),
    ('phm', '腓利门书', '腓利門書'),
    ('heb', '希伯来书', '希伯來書'),
    ('jas', '雅各书', '雅各書'),
    ('1pe', '彼得前书', '彼得前書'),
    ('2pe', '彼得后书', '彼得後書'),
    ('1jo', '约翰一书', '約翰一書'),
    ('2jo', '约翰二书', '約翰二書'),
    ('3jo', '约翰三书', '約翰三書'),
    ('jud', '犹大书', '猶大書'),
    ('rev', '启示录', '啟示錄'),
]

CITE = re.compile(r'<cite>(.*?)</cite>', re.S)
NOTE = re.compile(r'<note:(.*?)>', re.S)
TAG = re.compile(r'<[^>]+>')
BLANK = re.compile(r'[\s​　]+')


def normalise(note: str) -> str:
    """A citation's text with markup and whitespace removed.

    The publisher wraps原文 in `<mark class="hebrew">`, doubtful words in
    `<span class="affix">` and inserted verse numbers in `<sup>`; our
    importer drops all three deliberately. Comparing them raw reports 33
    differences that are entirely markup and no difference in wording.
    """
    return BLANK.sub('', TAG.sub('', note))

# Verses where our note count legitimately differs from the publisher's,
# each with the reason established by reading the node. Keyed by the
# publisher's own label, which for a packed node is not the verse the
# note ends up on.
ACCOUNTED_FOR = {
    ('tw', '哥林多前書 15:11'): 'upstream revision — adds the gloss 「福音」',
    ('tw', '彼得前書 3:10'): 'publisher packs 3:10-12 in one node; the '
                            '詩34.12-16 citation is on our 3:12',
    ('tw', '以弗所書 3:15'): 'publisher packs 3:15-16 in one node; the '
                            '參2.18註 citation is on our 3:16',
    ('tw', '馬太福音 16:3'): 'upstream labels 16:13 as verseIndex 3; the '
                            '參可8.27 citation is on our 16:13',
    ('cn', '哥林多前书 15:11'): 'upstream revision — adds the gloss 「福音」',
    ('cn', '马太福音 7:11'): 'upstream revision moved 參路11.9-13 here; ours '
                            'still carries it on 路加福音 11:9',
    ('cn', '路加福音 11:9'): 'upstream revision moved 參太7.7-8 to 馬太福音 '
                            '7:11; ours predates it',
    ('cn', '马太福音 1:16'): 'empty <cite></cite>, discarded on purpose',
    ('cn', '马太福音 23:36'): 'empty <cite></cite>, discarded on purpose',
    ('cn', '马太福音 27:50'): 'empty <cite></cite>, discarded on purpose',
    ('cn', '提摩太后书 3:3'): 'empty <cite></cite>, discarded on purpose',
}

# Chapters whose note TEXT differs from the publisher's current file, each
# with the authority that settled it. Keyed (lang, book, chapter).
#
# Every one of these was read against a third source before being written
# down — the printed 《新約聖經 梁家鏗譯本（註釋本）》2025 第二版, or the
# publisher's other edition. None is a defect of ours, and none is fixed
# here: adopting an upstream revision by guess is rewriting scripture.
ACCOUNTED_FOR_TEXT = {
    # Upstream revisions since our import. Same question as the 427
    # Traditional / 86 Simplified wording differences — §四之二 of the
    # publisher letter, not a repair.
    ('tw', '哥林多前書', '15'): 'upstream revision adds the gloss 「福音」',
    ('cn', '哥林多前书', '15'): 'upstream revision adds the gloss 「福音」',
    ('cn', '马太福音', '7'): 'upstream moved 參路11.9-13 to 7:11; ours predates it',
    ('cn', '路加福音', '11'): 'upstream merged 參太7.7-8 and 參徒1-2章 into one '
                             'note on 11:13; ours predates it',
    # Upstream revisions that post-date the PRINTED 2025 second edition,
    # which is the authority for our Traditional. Ours matches the print.
    ('tw', '以弗所書', '3'): "3:15 — printed 註釋本 sets 「參 4.6，」, which is "
                            'what we ship; the publisher\'s current tw adds '
                            '「、16」. Ours is not Simplified-sourced: 3:16 '
                            'ships their tw\'s 「參2.18註」 against their cn\'s 注',
    ('tw', '啟示錄', '20'): "20:4 — publisher's own tw prints 「參啟1.2注」 with "
                           'the Simplified 注, against 註 everywhere else in '
                           'their own file and in the printed 註釋本. Ours '
                           'reads 註 and is the one that matches the print',
    # Our edition punctuates where the current upstream does not. Same
    # class as the 307 tw / 46 cn punctuation differences the verse
    # proofread already counted — 腓立比書 2:6-11 is the known example.
    ('tw', '提摩太前書', '3'): '3:16 — the hymn is unpunctuated upstream and '
                              'set as punctuated lines by us, note included',
    ('cn', '提摩太前书', '3'): '3:16 — the hymn is unpunctuated upstream and '
                              'set as punctuated lines by us, note included',
    ('tw', '雅各書', '2'): '2:8 — trailing 「，」; upstream drops it, we keep it',
    ('cn', '雅各书', '2'): '2:8 — trailing 「，」; upstream drops it, we keep it',
    ('tw', '啟示錄', '7'): '7:17 — trailing 「。」; upstream drops it, we keep it',
    ('cn', '启示录', '7'): '7:17 — trailing 「。」; upstream drops it, we keep it',
}


def fetch(lang: str, abbr: str, refresh: bool) -> list:
    fname = f'{lang}-{abbr}.json'
    cached = os.path.join(CACHE_DIR, fname)
    if refresh or not os.path.exists(cached):
        os.makedirs(CACHE_DIR, exist_ok=True)
        with urllib.request.urlopen(f'{SRC_BASE}/{fname}', timeout=30) as r:
            data = r.read()
        # Netlify-style hosts answer a missing file with a 200 and HTML.
        if not data.lstrip().startswith(b'['):
            raise SystemExit(f'{fname}: not JSON — upstream served HTML?')
        with open(cached, 'wb') as f:
            f.write(data)
    with open(cached, encoding='utf-8') as f:
        return json.load(f)


def publisher_cites(chapters: list) -> dict:
    """{(chapter, verseIndex): [cite, …]} from one publisher book file."""
    out = {}
    for chap in chapters:
        chapter = None
        for node in chap.get('nodeData', []):
            if node.get('type') == 'chapter':
                chapter = str(node['chapterIndex'])
            if node.get('type') != 'verse':
                continue
            label = str(node.get('verseIndex', '')).strip()
            if not label:
                continue
            text = ''.join(
                c['content'] if isinstance(c, dict) else str(c)
                for c in node.get('contents', []))
            out.setdefault((chapter, label), []).extend(
                m.strip() for m in CITE.findall(text))
    return out


def ours(path: str) -> dict:
    with open(os.path.join(REPO_ROOT, path), encoding='utf-8') as f:
        rows = json.load(f)
    out = {}
    for row in rows:
        key = (row['book'], row['chapter'], row['verseLabel'])
        out.setdefault(key, []).extend(NOTE.findall(row.get('text', '')))
    return out


def audit(lang: str, asset: str, book_index: int, refresh: bool) -> int:
    shipped = ours(asset)
    unexplained = 0
    fewer = more = 0
    for row in BOOKS:
        abbr, name = row[0], row[book_index]
        cites = publisher_cites(fetch(lang, abbr, refresh))
        for (chapter, label), theirs in cites.items():
            mine = shipped.get((name, chapter, label))
            if mine is None:
                print(f'  MISSING VERSE  {name} {chapter}:{label}')
                unexplained += 1
                continue
            if len(mine) == len(theirs):
                continue
            ref = f'{name} {chapter}:{label}'
            reason = ACCOUNTED_FOR.get((lang, ref))
            direction = 'FEWER' if len(mine) < len(theirs) else 'MORE'
            if len(mine) < len(theirs):
                fewer += 1
            else:
                more += 1
            if reason:
                print(f'  ok  {ref}: {direction} '
                      f'({len(mine)} vs {len(theirs)}) — {reason}')
            else:
                unexplained += 1
                print(f'  ** {ref}: we have {direction} notes than the '
                      f'publisher ({len(mine)} vs {len(theirs)})')
                print(f'       publisher: {theirs}')
                print(f'       ours     : {mine}')
    print(f'  {lang}: {fewer} verses with fewer notes, {more} with more, '
          f'{unexplained} unexplained')
    return unexplained


def audit_text(lang: str, asset: str, book_index: int, refresh: bool) -> int:
    """Compare what the notes SAY, per chapter. See the module docstring
    for why this is keyed on the chapter and not on the verse."""
    mine_by_chapter: dict = {}
    for (book, chapter, _), notes in ours(asset).items():
        counter = mine_by_chapter.setdefault((book, chapter), Counter())
        counter.update(n for n in map(normalise, notes) if n)

    unexplained = ours_total = theirs_total = differing = 0
    for row in BOOKS:
        abbr, name = row[0], row[book_index]
        theirs_by_chapter: dict = {}
        for (chapter, _), cites in publisher_cites(
                fetch(lang, abbr, refresh)).items():
            counter = theirs_by_chapter.setdefault(chapter, Counter())
            counter.update(c for c in map(normalise, cites) if c)
        for chapter, theirs in theirs_by_chapter.items():
            mine = mine_by_chapter.get((name, chapter), Counter())
            ours_total += sum(mine.values())
            theirs_total += sum(theirs.values())
            if mine == theirs:
                continue
            differing += 1
            reason = ACCOUNTED_FOR_TEXT.get((lang, name, chapter))
            missing = list((theirs - mine).elements())
            extra = list((mine - theirs).elements())
            if reason:
                print(f'  ok  {name} {chapter}: {reason}')
            else:
                unexplained += 1
                print(f'  ** {name} {chapter}: our notes do not say what the '
                      f"publisher's do")
                print(f'       only theirs: {missing}')
                print(f'       only ours  : {extra}')
    print(f'  {lang}: {ours_total} notes ours / {theirs_total} theirs, '
          f'{differing} chapters differ, {unexplained} unexplained')
    return unexplained


def main() -> int:
    refresh = '--refresh' in sys.argv
    total = 0
    print('== Do we carry every note? (count, per verse)')
    print('Traditional (tw-*.json → assets/biblexg-v2-tr.json)')
    total += audit('tw', 'assets/biblexg-v2-tr.json', 2, refresh)
    print()
    print('Simplified (cn-*.json → assets/biblexg-v2.json)')
    total += audit('cn', 'assets/biblexg-v2.json', 1, refresh)
    print()
    print('== Do they say the same thing? (text, per chapter)')
    print('Traditional')
    total += audit_text('tw', 'assets/biblexg-v2-tr.json', 2, refresh)
    print()
    print('Simplified')
    total += audit_text('cn', 'assets/biblexg-v2.json', 1, refresh)
    print()
    if total:
        print(f'FAIL — {total} places where our editorial notes do not '
              f'match the publisher and no reason is on record.')
        print('A note we dropped may now be printed as scripture, and a '
              'note that differs is a cross-reference pointing somewhere '
              'the publisher does not. Read the publisher node, and the '
              'printed 註釋本, before changing anything.')
        return 1
    print('OK — both editions carry every editorial note the publisher '
          'does, and each one says what theirs says.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
