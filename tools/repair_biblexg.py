#!/usr/bin/env python3
"""Restore the verse boundaries the 梁家鏗譯本 converter lost.

`assets/biblexg-v2.json` (simplified) and `assets/biblexg-v2-tr.json`
(traditional) are one NT-only edition. `docs/DATA-INTEGRITY.md` check 13
measured eight references the two files disagree about and left them
unrepaired, on the reading that filling either gap needed a 简/繁 script
conversion this repository cannot perform without inventing characters.

That reading was wrong about seven of the eight. Re-reading the files in
record order rather than by key set shows the text is *present* in every
case but one — filed under the wrong number, merged into its neighbour,
or split across two rows. Nothing below creates a character that the file
did not already contain, and nothing below reads text out of the other
script's file: the two editions were independently revised (Acts 15:17 is
為了人類中餘下的人 in traditional against 为了人类其他成员 in simplified),
so the sibling file is a witness to *structure* only, never to wording.

Eight repairs, in descending order of what a reader loses. B8 was added
after the first seven shipped; it is the same class found by a different
instrument.

  T1  馬太福音 16:13 is filed as 16:3, where it collides with the real
      16:3. A reader asking for Matthew 16:3 gets the weather-signs
      saying or the Caesarea Philippi question depending on which record
      the index happens to keep. The source read `13`; the converter cut
      it into an empty verse `1` and a verse `3` carrying the text.
      Drop the empty record, renumber the other to 13.

  T2  使徒行傳 15:16 is two records with the same reference — the prose
      「如經上所記：」 and the Amos quotation it introduces, which the
      converter promoted to its own block. Lookup keeps one, so the
      reader loses half a verse. The simplified file holds both halves in
      a single record, which is the structure to follow.

  T3  以弗所書 3:16 is merged into 3:15 and its verse number was swallowed
      by the preceding footnote, which reads `參4.6、16`. The trailing
      separator is house style (`參2.18註，加4.6註，` ends the same way and
      loses nothing), and the simplified file carries `参4.6，` with no 16
      while holding 3:16 separately, so the `16` is the verse marker and
      not a second cross-reference.

  T4  彼得前書 3:11 and 3:12 are merged into 3:10 with their numbers left
      inline, so 3:10 prints 「⋯不沾詭詐。11還要避惡行善⋯」 — a verse
      number rendered as scripture, and two references that resolve to
      nothing.

  B5  路加福音 22:43 and 22:44 are inline inside 22:42, in BOTH files.
  B6  路加福音 23:17 is inline inside 23:16, in BOTH files.
  B7  路加福音 23:34a is inline at the end of 23:33 while the record
      numbered 34 holds only 34b, in BOTH files. So this edition answers
      「路加福音 23:34」 with 「然後，他們抓鬮分了耶穌的衣袍。」 and never
      with 「父親啊，赦免他們」. Move the marked clause into verse 34.

  B8  腓立比書 1:1 is printed as two blocks — the senders, then the
      people addressed — and the second block is numbered 2. It is not
      verse 2. Philippians names its readers inside verse 1 (「致在腓立
      比⋯各位監督及執事：」), and this edition's real verse 2, the grace,
      is nowhere in the book. So the file answers 腓立比書 1:2 with the
      address and never with 「願恩惠平安⋯」. Five other letters open with
      the same em-dash typography — 羅馬書, 哥林多前書, 歌羅西書, 提摩太
      前書, 提摩太後書 — and in every one of those the second block really
      is verse 2, which is why the shape alone was not the giveaway.
      Merge the two blocks into 1:1 and leave 1:2 absent, the same way
      加拉太書 1:1 already carries 1-2 and has no 1:2 record. Found by
      tools/audit_verse_alignment.py; in BOTH files.

B5-B7 are the passages NA28/UBS5 double-bracket, and the same converter
demonstrably loses verse numbers into adjacent markup (T3) and cuts them
in half (T1), so the inline placement is read here as the same failure
rather than as deliberate critical-text marking: the digits carry no
bracket, no footnote and no other signal a reader could act on. Flagged
in docs/DATA-INTEGRITY.md because it is the one judgement call here.

NOT repaired, and deliberately: 馬可福音 6:8-11 are absent from the
simplified file, whose 6:7 also stops mid-clause at 「並授予他們權能」.
Only the traditional file has them, so restoring them needs a 繁→简
conversion — the one place the original reading still holds. Twenty-seven
further references are absent from BOTH files because the publisher
printed them merged into the verse before (路加福音 1:2-4 inside 1:1,
羅馬書 15:19 inside 15:18, and 24 more); those carry no marker, so
splitting them would mean inventing a boundary. 腓立比書 1:2 joins that
second set once B8 has run: its words are in neither file, and writing
「願恩惠平安從我們的神天父⋯」 out of another edition would be putting a
sentence in this translator's mouth. Both sets are frozen at their
measured size by test/biblexg_verse_boundary_test.dart.

Every repair guards on the text it expects to find and skips if the file
already carries the result, so re-running finds nothing to do.

Usage: tools/repair_biblexg.py [--write]
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# 2026-09-14: the edition code is an argument now. The repairs below are
# about the PUBLISHER'S converter, not about one snapshot of its output,
# so every re-fetch needs them again — `tools/import_ljk2.py --code X`
# then `tools/repair_biblexg.py --code X --write`.
_CODE = 'biblexg-v3'
for _i, _a in enumerate(sys.argv):
    if _a == '--code' and _i + 1 < len(sys.argv):
        _CODE = sys.argv[_i + 1]

SIMPLIFIED = f'{_CODE}.json'
TRADITIONAL = f'{_CODE}-tr.json'


def write_like(path, original, data):
    """Re-serialises [data] in whatever layout [original] used.

    Both biblexg files are minified; guessing wrong would reflow two
    megabytes and bury a seven-verse correction in a diff nobody can read.
    """
    indented = original.startswith('[\n') or original.startswith('{\n')
    if indented:
        text = json.dumps(data, ensure_ascii=False, indent=2)
    else:
        text = json.dumps(data, ensure_ascii=False, separators=(',', ':'))
    if original.endswith('\n'):
        text += '\n'
    with open(path, 'w', encoding='utf-8') as f:
        f.write(text)


def find(verses, book, chapter, verse):
    """Every index in file order whose reference matches."""
    return [
        i for i, r in enumerate(verses)
        if r['book'] == book
        and str(r['chapter']) == str(chapter)
        and str(r['verse']) == str(verse)
    ]


def has(verses, book, chapter, verse):
    return bool(find(verses, book, chapter, verse))


def renumber(record, verse):
    """A copy of [record] carrying verse number [verse], id kept in step."""
    out = dict(record)
    out['verse'] = str(verse)
    out['verseLabel'] = str(verse)
    out['id'] = record['id'][:5] + '%03d' % int(verse)
    return out


class Skipped(Exception):
    """The file does not hold what this repair expects — leave it alone."""


def split_inline(verses, book, chapter, verse, markers, log):
    """Cut one record into several at the verse numbers left inside it.

    [markers] is the ordered list of numbers that appear literally in the
    text. Each becomes its own record carrying the text that follows it.
    No character moves except the marker itself.
    """
    tail = [str(m) for m in markers]
    if all(has(verses, book, chapter, m) for m in tail):
        return 0
    hits = find(verses, book, chapter, verse)
    if len(hits) != 1:
        raise Skipped('%s %s:%s is %d records, expected 1'
                      % (book, chapter, verse, len(hits)))
    at = hits[0]
    record = verses[at]
    text = record['text']

    pieces = []
    for m in tail:
        head, sep, text = text.partition(m)
        if not sep:
            raise Skipped('%s %s:%s carries no inline %s'
                          % (book, chapter, verse, m))
        if not head.strip():
            raise Skipped('%s %s:%s has nothing before marker %s'
                          % (book, chapter, verse, m))
        pieces.append(head)
    pieces.append(text)

    rejoined = pieces[0]
    for number, piece in zip(tail, pieces[1:]):
        rejoined += number + piece
    if rejoined != record['text']:
        raise Skipped('%s %s:%s split is not lossless' % (book, chapter, verse))
    for piece, number in zip(pieces[1:], tail):
        if not piece.strip():
            raise Skipped('%s %s:%s marker %s introduces nothing'
                          % (book, chapter, verse, number))

    rebuilt = [dict(record, text=pieces[0])]
    for number, piece in zip(tail, pieces[1:]):
        made = renumber(record, number)
        made['text'] = piece
        made['isParagraphStart'] = False
        rebuilt.append(made)
    verses[at:at + 1] = rebuilt
    log('  %s %s:%s split into %s'
        % (book, chapter, verse, '/'.join([str(verse)] + tail)))
    return len(tail)


# --- T1 ------------------------------------------------------------------

MT_16_13_OPENING = '耶穌來到該撒利亞腓立比境內'


def repair_misfiled_matthew(verses, log):
    if has(verses, '馬太福音', '16', '13'):
        return 0
    hits = find(verses, '馬太福音', '16', '3')
    if len(hits) != 2:
        raise Skipped('馬太福音 16:3 is %d records, expected 2' % len(hits))
    stray = hits[1]
    if not verses[stray]['text'].startswith(MT_16_13_OPENING):
        raise Skipped('馬太福音 16:3 second record is not 16:13')
    blanks = [i for i in find(verses, '馬太福音', '16', '1')
              if not verses[i]['text'].strip()]
    if len(blanks) != 1:
        raise Skipped('馬太福音 16:1 has %d empty records, expected 1'
                      % len(blanks))
    if blanks[0] + 1 != stray:
        raise Skipped('the empty 馬太福音 16:1 does not precede the stray 16:3')
    verses[stray] = renumber(verses[stray], 13)
    del verses[blanks[0]]
    log('  馬太福音 16:3 (second record) renumbered to 16:13; '
        'empty 16:1 removed')
    return 1


# --- T2 ------------------------------------------------------------------

def repair_split_acts(verses, log):
    hits = find(verses, '使徒行傳', '15', '16')
    if len(hits) == 1:
        return 0
    if len(hits) != 2 or hits[1] != hits[0] + 1:
        raise Skipped('使徒行傳 15:16 is %d records, expected 2 adjacent'
                      % len(hits))
    head, tailrec = verses[hits[0]], verses[hits[1]]
    if not head['text'].strip() or not tailrec['text'].strip():
        raise Skipped('使徒行傳 15:16 has an empty half')
    merged = dict(head)
    merged['text'] = head['text'] + '\n' + tailrec['text']
    verses[hits[0]:hits[1] + 1] = [merged]
    log('  使徒行傳 15:16 merged from two records into one')
    return 1


# --- T3 ------------------------------------------------------------------

EPH_NOTE_WITH_MARKER = '<note:參4.6、16>'
EPH_NOTE_REPAIRED = '<note:參4.6、>'


def repair_swallowed_ephesians(verses, log):
    if has(verses, '以弗所書', '3', '16'):
        return 0
    hits = find(verses, '以弗所書', '3', '15')
    if len(hits) != 1:
        raise Skipped('以弗所書 3:15 is %d records, expected 1' % len(hits))
    at = hits[0]
    record = verses[at]
    head, sep, tail = record['text'].partition(EPH_NOTE_WITH_MARKER)
    if not sep or not tail.strip():
        raise Skipped('以弗所書 3:15 does not carry the swallowed marker')
    fifteen = dict(record, text=head + EPH_NOTE_REPAIRED)
    sixteen = renumber(record, 16)
    sixteen['text'] = tail
    sixteen['isParagraphStart'] = False
    verses[at:at + 1] = [fifteen, sixteen]
    log('  以弗所書 3:15 split into 3:15/3:16; footnote 參4.6、16 → 參4.6、')
    return 1


# --- B7 ------------------------------------------------------------------

LUKE_34A = '34a'


# Set by `--sub-verses`; see `repairs_for`.
SUB_VERSE_MODEL = False


def repair_luke_34a(verses, log):
    hits = find(verses, '路加福音', '23', '33')
    if len(hits) != 1:
        raise Skipped('路加福音 23:33 is %d records, expected 1' % len(hits))
    at = hits[0]
    record = verses[at]
    head, sep, tail = record['text'].partition(LUKE_34A)
    if not sep:
        return 0
    if not head.strip() or not tail.strip():
        raise Skipped('路加福音 23:33 marker 34a bounds nothing')
    after = find(verses, '路加福音', '23', '34')
    if len(after) != 1 or after[0] != at + 1:
        raise Skipped('路加福音 23:34 is not the single record after 23:33')
    target = verses[after[0]]
    verses[at] = dict(record, text=head)
    verses[after[0]] = dict(target, text=tail + target['text'])
    log('  路加福音 23:33 marker 34a: clause moved into 23:34')
    return 1


# --- B8 ------------------------------------------------------------------

# The two blocks, verbatim per file. Kept separate rather than read from
# the sibling: the two editions were independently revised, so each file
# is the only witness to its own wording.
PHILIPPIANS = {
    SIMPLIFIED: (
        '腓立比书',
        '保罗和提摩太，基督耶稣的奴仆——',
        '致在腓立比在基督耶稣里的全体圣徒、各位监督及执事：',
    ),
    TRADITIONAL: (
        '腓立比書',
        '保羅和提摩太，基督耶穌的奴僕——',
        '致在腓立比在基督耶穌裡的全體聖徒、各位監督及執事：',
    ),
}


def repair_philippians(filename):
    book, senders, addressees = PHILIPPIANS[filename]
    whole = senders + addressees

    def repair(verses, log):
        at = find(verses, book, '1', '1')
        if len(at) != 1:
            raise Skipped('%s 1:1 is %d records, expected 1' % (book, len(at)))
        head = at[0]
        stray = find(verses, book, '1', '2')
        if not stray:
            if verses[head]['text'] != whole:
                raise Skipped('%s has no 1:2 and 1:1 is not the whole verse'
                              % book)
            return 0
        if len(stray) != 1 or stray[0] != head + 1:
            raise Skipped('%s 1:2 is not the single record after 1:1' % book)
        if verses[head]['text'] != senders:
            raise Skipped('%s 1:1 is not the senders block' % book)
        if verses[stray[0]]['text'] != addressees:
            raise Skipped('%s 1:2 is not the addressees block' % book)
        verses[head] = dict(verses[head], text=whole)
        del verses[stray[0]]
        log('  %s 1:1/1:2 merged into 1:1; 1:2 left absent (its words, the '
            'grace, are in neither file)' % book)
        return 1

    return repair


# --- driver --------------------------------------------------------------

def repairs_for(filename):
    """(name, callable) in the order they are applied.

    With `--sub-verses`, B7 is DROPPED. The two apps that ship this
    edition model 路加福音 23:34a differently, and both models are
    defensible:

      * Here, the 34a clause is moved into 23:34, so the reference holds
        the whole verse and the publisher's 「34a」 affix stops printing
        at the reader in the middle of a sentence.
      * In the other app, 34a becomes its OWN row (verseLabel `34a`,
        subVerseOrder 0) sitting before 23:34, which keeps the printed
        edition's sub-verse labelling visible. That app has a
        `subVerseOrder` field, a sort that uses it, and a test that pins
        it; `tools/repair_biblexg_luke_23_34a.py` is the step that
        builds it, and it needs 23:33 with the affix still in place.

    Running both produces the prayer TWICE — once as row 34a and again
    at the head of 34 — which is exactly what a 2026-09-14 refresh did
    before this flag existed. A data refresh must not quietly change
    which model an app uses, so the app states which one it wants.
    """
    return [r for r in _repairs_for(filename)
            if not (SUB_VERSE_MODEL and r[0].startswith('B7 '))]


def _repairs_for(filename):
    if filename == TRADITIONAL:
        return [
            ('T1 馬太福音 16:13 misfiled as 16:3', repair_misfiled_matthew),
            ('T2 使徒行傳 15:16 split across two records', repair_split_acts),
            ('T3 以弗所書 3:16 swallowed by a footnote',
             repair_swallowed_ephesians),
            ('T4 彼得前書 3:11-12 inline in 3:10',
             lambda v, log: split_inline(v, '彼得前書', '3', '10',
                                         [11, 12], log)),
            ('B5 路加福音 22:43-44 inline in 22:42',
             lambda v, log: split_inline(v, '路加福音', '22', '42',
                                         [43, 44], log)),
            ('B6 路加福音 23:17 inline in 23:16',
             lambda v, log: split_inline(v, '路加福音', '23', '16',
                                         [17], log)),
            ('B7 路加福音 23:34a inline in 23:33', repair_luke_34a),
            ('B8 腓立比書 1:1 split across 1:1/1:2',
             repair_philippians(TRADITIONAL)),
            # B9 — 2026-09-14, found when the edition was re-fetched.
            # Same class as B5-B7 and only in the traditional file: the
            # publisher's converter poured FOUR whole verses into 5:10's
            # markup, with two translator's notes between them. Not in
            # the May snapshot, which is why the earlier pass did not
            # name it.
            #
            # 約翰福音 5:3 was written as a second repair here and then
            # REMOVED. It also carries a `<sup>4</sup>`, but inside a
            # note — 「有較後期抄本加插」 — so the marker is part of the
            # apparatus, not a verse the translation prints. Splitting on
            # it manufactured a 5:4 whose text was the tail of a
            # footnote. The simplified file has no 5:4 either, and that
            # agreement is the translation being consistent, not a gap.
            ('B9 啟示錄 5:11-14 inline in 5:10',
             lambda v, log: split_inline(v, '啟示錄', '5', '10',
                                         [11, 12, 13, 14], log)),
        ]
    return [
        ('B5 路加福音 22:43-44 inline in 22:42',
         lambda v, log: split_inline(v, '路加福音', '22', '42', [43, 44], log)),
        ('B6 路加福音 23:17 inline in 23:16',
         lambda v, log: split_inline(v, '路加福音', '23', '16', [17], log)),
        ('B7 路加福音 23:34a inline in 23:33', repair_luke_34a),
        ('B8 腓立比书 1:1 split across 1:1/1:2',
         repair_philippians(SIMPLIFIED)),
    ]


def run(filename, write):
    path = os.path.join(ROOT, 'assets', filename)
    with open(path, encoding='utf-8') as f:
        original = f.read()
    verses = json.loads(original)
    before = len(verses)

    print('%s (%d records)' % (filename, before))
    lines = []
    skipped = 0
    for name, fn in repairs_for(filename):
        try:
            made = fn(verses, lines.append)
        except Skipped as why:
            print('  SKIP %s — %s' % (name, why))
            skipped += 1
            continue
        if made == 0:
            print('  ok   %s — already applied' % name)
    for line in lines:
        print(line)

    keys = [(r['book'], str(r['chapter']), str(r['verse'])) for r in verses]
    duplicated = sorted({k for k in keys if keys.count(k) > 1})
    if duplicated:
        print('  REFUSING TO WRITE — duplicate references remain: %s'
              % duplicated)
        return 1
    blank = [k for k, r in zip(keys, verses) if not r['text'].strip()]
    if blank:
        print('  REFUSING TO WRITE — empty verses remain: %s' % blank)
        return 1

    print('  %d records → %d' % (before, len(verses)))
    changed = verses != json.loads(original)
    if write and changed:
        write_like(path, original, verses)
        print('  written')
    elif write:
        print('  unchanged, not written')
    return 1 if skipped else 0


def main():
    global SUB_VERSE_MODEL
    write = '--write' in sys.argv
    SUB_VERSE_MODEL = '--sub-verses' in sys.argv
    if not write:
        print('dry run — pass --write to save\n')
    if SUB_VERSE_MODEL:
        print("--sub-verses: B7 路加福音 23:34a left to this repo's own "
              'sub-verse step\n')
    bad = 0
    for filename in (TRADITIONAL, SIMPLIFIED):
        bad += run(filename, write)
        print()
    return bad


if __name__ == '__main__':
    sys.exit(main())
