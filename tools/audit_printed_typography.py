#!/usr/bin/env python3
"""Read the printed 註釋本's TYPE SIZES, not just its characters.

WHY THIS EXISTS
---------------
`proofread_ljk_tr.py` flattens the printed volumes with `pdftotext` and
compares characters. That was written believing the print could not
settle whether a phrase is scripture or an editor's gloss — its own
docstring, and `test/biblexg_verse_integrity_test.dart`, say so:

    "The printed 註釋本 cannot arbitrate this: pdftotext renders a
     footnote inline and indistinguishable from body text."

It can. `pdftohtml -xml` keeps the font size of every run, and the
2025 二版 sets four sizes that mean four different things:

    18pt  chapter headings
    17pt  scripture (16pt where the typesetter tightened a page)
    12pt  the editor's voice — inline glosses AND the footnote blocks
     8pt  verse numbers

So the print DOES distinguish the translator's supplied words from the
words being translated, in the manner of the KJV's italics, and it is
per-occurrence rather than per-word: 加拉太書 3:7 and 3:9 set 稱義 at
12pt while 3:8 and 3:11 set the same two characters at 17pt.

The publisher's electronic editions lose that distinction, and we
inherited the loss — which is why 31 spans of our Traditional read as
scripture that the printed edition marks as the editor's.

WHAT IT MEASURES
----------------
The 8pt verse numbers also make a per-VERSE alignment possible, which
`proofread_ljk_tr.py` deliberately gave up on because pdftotext hoists
the superscripts onto lines of their own. Here each verse's printed
text is split into

    body      the scripture, 16pt and up
    gloss     12pt sharing a LINE with body text — an inline gloss
    apparatus 12pt on its own lines — the footnote blocks

and every verse of `assets/biblexg-v2-tr.json` is compared against its
own printed counterpart.

WHAT IT WILL AND WILL NOT WRITE
-------------------------------
`--apply` moves a span out of the verse and into a `<note:…>`. It never
writes, converts or reorders a character, and it refuses unless THREE
independent authorities agree the words are the editor's:

  1. the printed 註釋本 sets them at 12pt,
  2. the printed body of that verse does not contain them, and
  3. the publisher's own Simplified edition already marks them as a
     note — i.e. our two editions disagree and the print breaks the tie.

The other 27 spans are reported and left alone. Their two electronic
editions AGREE with each other and only the print differs, which is a
question for the publisher (§四之三 of docs/梁家鏗譯本-請教出版方.md),
not a defect of ours to repair on one witness.

USAGE
-----
    python3 tools/audit_printed_typography.py
    python3 tools/audit_printed_typography.py --apply
"""
import argparse
import html
import json
import os
import re
import subprocess
import sys

import importlib.util

HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    'proofread_ljk_tr', os.path.join(HERE, 'proofread_ljk_tr.py'))
ljk = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ljk)

XML = os.path.expanduser('~/.cache/yswords/ljk-print-xml')
TEXT = re.compile(r'<text top="(\d+)" left="(\d+)"[^>]*font="(\d+)"[^>]*>'
                  r'(.*?)</text>', re.S)
NOTE = re.compile(r'<note:.*?>')

# 16pt is body too: the typesetter drops a page from 17 to 16 to fit it
# (使徒行傳 7:56-8:1 is set that way), and reading 16 as the editor's
# voice reports six whole verses of Acts as glosses.
BODY_PT = 16
SAME_LINE = 6      # points; an inline gloss sits on the body's own line


def xml_for(volume):
    """The volume as pdftohtml XML, converted once and cached."""
    name = ljk.VOLUMES[volume][0]
    pdf = os.path.join(ljk.SRC, name.replace('.txt', '.pdf'))
    out = os.path.join(XML, name.replace('.txt', ''))
    if not os.path.exists(out + '.xml'):
        if not os.path.exists(pdf):
            sys.exit(f'{pdf} missing — copy the publisher\'s five printed '
                     f'volumes into {ljk.SRC}')
        os.makedirs(XML, exist_ok=True)
        subprocess.run(['pdftohtml', '-xml', '-i', '-q', '-nodrm', pdf, out],
                       check=True)
    return open(out + '.xml', encoding='utf-8').read()


def runs(volume):
    """(size, text, on_a_body_line) for every run, in reading order."""
    x = xml_for(volume)
    size = {m.group(1): float(m.group(2))
            for m in re.finditer(r'<fontspec id="(\d+)"[^>]*size="([-\d.]+)"', x)}
    out = []
    for page in re.finditer(r'<page number="\d+"[^>]*>(.*?)</page>', x, re.S):
        els = [(int(t), size[f], html.unescape(re.sub('<[^>]+>', '', s)))
               for t, _, f, s in TEXT.findall(page.group(1)) if s.strip()]
        tops = [t for t, sz, _ in els if sz >= BODY_PT]
        for top, sz, text in els:
            out.append((sz, text, any(abs(top - t) <= SAME_LINE for t in tops)))
    return out


def printed_verses(volume):
    """(book, chapter, verse) -> {body, gloss, apparatus} from the print.

    Books are separated by the chapter heading returning to 1 rather than
    by finding their titles: the titles also appear in the table of
    contents and in the abbreviation tables, where a chapter number
    cannot.
    """
    books = ljk.VOLUMES[volume][1]
    out, cur, chapter, book, started = {}, None, None, -1, False
    for sz, text, inline in runs(volume):
        s = text.strip()
        if sz >= 18 and re.fullmatch(r'\d+', s):
            if s == '1' and (not started or chapter != 1):
                book += 1
                started = True
            chapter = int(s)
            continue
        if sz == 8 and re.fullmatch(r'\d+(?:[-–]\d+)?', s):
            if started:
                key = (books[book], str(chapter), s.replace('–', '-'))
                cur = out.setdefault(key, {'body': [], 'gloss': [],
                                           'apparatus': []})
            continue
        if cur is None:
            continue
        if sz >= BODY_PT:
            cur['body'].append(text)
        elif inline:
            cur['gloss'].append(text)
        else:
            cur['apparatus'].append(text)
    return out


def visible(verse):
    return ljk.norm(NOTE.sub('', verse['text']))


def spans_the_print_glosses(ours, printed):
    """Every span of our verse the print sets at 12pt, with its verse."""
    import difflib
    found = []
    for v in ours:
        p = printed.get((v['book'], v['chapter'], v['verseLabel']))
        if not p:
            continue
        body = ljk.norm(''.join(p['body']))
        gloss = ljk.norm(''.join(p['gloss']))
        seen = visible(v)
        if seen in body or not gloss:
            continue
        for tag, a1, a2, _, _ in difflib.SequenceMatcher(
                None, seen, body).get_opcodes():
            span = seen[a1:a2]
            if tag in ('delete', 'replace') and len(span) >= 2 and span in gloss:
                found.append((v, span))
    return found


def simplified_notes(path='assets/biblexg-v2.json'):
    """id -> (visible text, [note bodies]) of the publisher's Simplified."""
    out = {}
    for v in json.load(open(path, encoding='utf-8')):
        out[v['id']] = (ljk.norm(NOTE.sub('', v['text'])),
                        [m[6:-1] for m in NOTE.findall(v['text'])])
    return out


def t2s(strings):
    joined = '\n'.join(strings)
    r = subprocess.run(['opencc', '-c', 't2s'], input=joined,
                       capture_output=True, text=True)
    if r.returncode:
        sys.exit('this needs the opencc CLI to compare the two editions')
    return dict(zip(strings, r.stdout.split('\n')))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--assets', default='assets/biblexg-v2-tr.json')
    ap.add_argument('--apply', action='store_true',
                    help='move the spans all three authorities call a gloss '
                         'into a <note:…>; never writes a character')
    args = ap.parse_args()

    printed = {}
    for volume in sorted(ljk.VOLUMES):
        printed.update(printed_verses(volume))
    ours = json.load(open(args.assets, encoding='utf-8'))
    paired = sum(1 for v in ours
                 if (v['book'], v['chapter'], v['verseLabel']) in printed)
    identical = sum(
        1 for v in ours
        if (v['book'], v['chapter'], v['verseLabel']) in printed
        and visible(v) in ljk.norm(''.join(
            printed[(v['book'], v['chapter'], v['verseLabel'])]['body'])))

    print(f'printed verses parsed        : {len(printed):,}')
    print(f'ours                         : {len(ours):,} '
          f'({paired:,} have a printed counterpart)')
    print(f'identical to the printed BODY: {identical:,}')

    hits = spans_the_print_glosses(ours, printed)
    simplified = simplified_notes()
    conversions = t2s([span for _, span in hits])

    repairable, publisher_question = [], []
    for v, span in hits:
        seen, notes = simplified.get(v['id'], ('', []))
        marked = conversions[span] not in seen and any(
            conversions[span] in n for n in notes)
        (repairable if marked else publisher_question).append((v, span, marked))

    print(f'\nour scripture the print sets at 12pt: {len(hits)}')
    for v, span, marked in publisher_question:
        print(f"  {v['book']} {v['chapter']}:{v['verseLabel']:<5} {span!r}"
              f"   (both electronic editions print it as text — ask, do not "
              f"change)")
    print(f'\nof those, ALSO a note in the publisher\'s Simplified: '
          f'{len(repairable)}')
    for v, span, _ in repairable:
        print(f"  {v['book']} {v['chapter']}:{v['verseLabel']:<5} {span!r}")

    # A gloss the two editions WORD DIFFERENTLY cannot be found by matching
    # the span: 路加福音 9:5 trails 作為警告。 in our Traditional where the
    # print and the Simplified both say 意即警告。 So one shape, and only
    # one, is admitted — the print's scripture ENDS and our verse carries on:
    #
    #     our visible text == the printed body + a tail,
    #     the print sets a 12pt gloss in that verse, and
    #     the Simplified neither shows that tail nor lacks a note.
    #
    # Requiring the tail be the whole remainder is what makes this safe. A
    # looser test — any extra span in a verse that happens to have a
    # footnote — reported ten, and nine were ordinary wording differences
    # between the editions (馬可福音 15:21 揹耶穌/背他, 腓立比書 2:1 甚麼/任何,
    # 羅馬書 12:6 照著信心的程度去做/應與信心成比例) sitting beside an
    # unrelated footnote. Those belong to the publisher's revision, and
    # moving them into a note would hide translated words as an editor's.
    trailing = []
    for v in ours:
        p = printed.get((v['book'], v['chapter'], v['verseLabel']))
        seen_cn, notes_cn = simplified.get(v['id'], (None, []))
        if not p or seen_cn is None or not notes_cn or not p['gloss']:
            continue
        body = ljk.norm(''.join(p['body']))
        seen = visible(v)
        if not body or seen == body or not seen.startswith(body):
            continue
        tail = seen[len(body):]
        if len(tail) >= 3 and t2s([tail])[tail] not in seen_cn:
            trailing.append((v, tail))
    if trailing:
        print(f'\nand worded differently in the two editions: {len(trailing)}')
        for v, span in trailing:
            print(f"  {v['book']} {v['chapter']}:{v['verseLabel']:<5} {span!r}")

    if not args.apply:
        return 0

    applied = 0
    for v, span, _ in repairable + [(v, s, True) for v, s in trailing]:
        if f'<note:{span}>' in v['text']:
            continue
        if v['text'].count(span) != 1:
            print(f"  SKIPPED {v['book']} {v['chapter']}:{v['verseLabel']} "
                  f"{span!r} — {v['text'].count(span)} places to put it",
                  file=sys.stderr)
            continue
        v['text'] = v['text'].replace(span, f'<note:{span}>', 1)
        applied += 1
    json.dump(ours, open(args.assets, 'w', encoding='utf-8'),
              ensure_ascii=False, indent=1)
    print(f'\nmoved {applied} spans into a note in {args.assets}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
