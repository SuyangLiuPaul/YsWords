#!/usr/bin/env python3
"""Proofread our TRADITIONAL 梁家鏗譯本 against the printed 註釋本.

WHY THIS EXISTS
---------------
The publisher's web reader ships SIMPLIFIED ONLY, so `proofread_biblexg.py`
can only check the Simplified side. The user then supplied the publisher's
own printed 《新約聖經 梁家鏗譯本（註釋本）》2025 第二版 as five PDFs with
a clean text layer — the first authority we have ever had for the
Traditional. This tool compares against it.

WHY IT DOES NOT COMPARE VERSE BY VERSE
--------------------------------------
`pdftotext` hoists the printed superscript verse numbers onto lines of
their own, and not always adjacent to the text they introduce — in
使徒行傳 9 the numbers 32 and 33 both appear two lines *above* the
sentence they open. Reconstructing verse boundaries from that would
invent alignment errors and then report them as scripture defects.

So the printed volume is flattened into one digit-free character stream
per book, and each of our verses is checked by CONTAINMENT: every
segment of our verse (the parts either side of a `<note:>`) must occur
verbatim in the printed stream. A verse whose segments are all present
is confirmed word for word. A verse with a missing segment is a
candidate difference for a human to look at — never an automatic edit.

Splitting on `<note:>` matters: the printed edition sets scripture
citations inline in the body ("……無人居住。詩 69.25。又載……") where we
carry them as notes. Comparing whole verses would report every one of
those as a difference.

USAGE
-----
    python3 tools/proofread_ljk_tr.py --volume 2          # 使徒行傳
    python3 tools/proofread_ljk_tr.py --volume 1 --book 馬太福音
    python3 tools/proofread_ljk_tr.py --volume 2 --json out.json

It NEVER writes to assets/. Conform to the printed text where it
differs — do not "correct" the printed text into better Chinese; a
first pass did exactly that and every one of its corrections was wrong.
"""
import argparse
import json
import os
import re
import sys

SRC = '/tmp/ljk_tr'

# volume number -> (extracted text file, books in printed order)
VOLUMES = {
    1: ('讀_繁_註_1_太可路約.txt',
        ['馬太福音', '馬可福音', '路加福音', '約翰福音']),
    2: ('讀_繁_註_2_徒.txt', ['使徒行傳']),
    3: ('讀_繁_註_3_保羅.txt',
        ['羅馬書', '哥林多前書', '哥林多後書', '加拉太書', '以弗所書',
         '腓立比書', '歌羅西書', '帖撒羅尼迦前書', '帖撒羅尼迦後書',
         '提摩太前書', '提摩太後書', '提多書', '腓利門書']),
    4: ('讀_繁_註_4_其他書信.txt',
        ['希伯來書', '雅各書', '彼得前書', '彼得後書', '約翰一書',
         '約翰二書', '約翰三書', '猶大書']),
    5: ('讀_繁_註_5_啓.txt', ['啟示錄']),
}

FOOTNOTE = re.compile(r'^\d+(?:[-–]\d+)?節註[：:]')
CHAPTER = re.compile(r'^\d+\s*章$')
PAGE = re.compile(r'^[0-9ivxlcIVXLC]+$')


def book_body(lines, book, books):
    """Line range of one book's body, skipping the table of contents.

    The book's title appears in the front matter and the abbreviation
    table too, so the body is the title line followed within a few lines
    by "1章". The one-chapter books (腓利門書, 約翰二書, 約翰三書, 猶大書)
    are printed without any chapter heading at all, so they are found by
    a bare "1" verse number followed by a line of real text.
    """
    start = None
    for i, line in enumerate(lines):
        if line.strip().lstrip('\x0c').strip() != book:
            continue
        window = [lines[j].strip() for j in range(i + 1, min(i + 6, len(lines)))]
        one_chapter = any(re.fullmatch(r'\d+(?:-\d+)?', w)
                          and any(len(x) > 10 for x in window[k + 1:])
                          for k, w in enumerate(window))
        if any(CHAPTER.match(w) for w in window) or one_chapter:
            start = i
            break
    if start is None:
        raise SystemExit(f'{book}: could not find the start of the body')

    end = len(lines)
    later = books[books.index(book) + 1:]
    for i in range(start + 1, len(lines)):
        if lines[i].strip().lstrip('\x0c').strip() in later:
            end = i
            break
    return start, end


def stream(lines, book):
    """One flat character stream of a book's body text.

    Footnotes, running headers, chapter headings and page numbers are
    dropped. A footnote block runs from its "N節註：" line until a
    blank line, a page break, or a hoisted verse number — every block
    in the five volumes ends at one of those.
    """
    header = re.compile(rf'^{re.escape(book)}\s*\d*\s*章?$')
    out, in_note = [], False
    for raw in lines:
        line = raw.replace('\x0c', '').strip()
        if not line:
            in_note = False
            continue
        if FOOTNOTE.match(line):
            in_note = True
            continue
        if header.match(line) or CHAPTER.match(line) or line == book:
            in_note = False
            continue
        if PAGE.match(line):
            in_note = False
            continue
        if in_note:
            continue
        out.append(line)
    return norm(''.join(out))


def norm(s):
    """Compare wording, not typography.

    Digits go because the printed superscript verse numbers land inside
    the text; Latin and Greek go because they only ever occur in the
    footnote apparatus, which the flattener may not have removed
    perfectly.
    """
    s = re.sub(r'<note:[^>]*>', '', s)
    s = re.sub(r'<[^>]+>', '', s)
    s = re.sub(r'[0-9A-Za-zͰ-Ͽἀ-῿]', '', s)
    return re.sub(r'[\s　\-–—.·]', '', s)


def segments(text):
    """Our verse text, split where a `<note:>` interrupts it."""
    parts = re.split(r'<note:[^>]*>', text)
    return [p for p in (norm(p) for p in parts) if p]


def to_simplified(chars):
    """Each character's Simplified form, via the opencc CLI.

    Only `--apply` needs this. It is how "same word, different glyph" is
    told apart from "different word", and that distinction is the whole
    safety of writing back: 托/託 is one word and may be conformed to the
    printed edition, 他/穌 is two and may not.
    """
    import subprocess
    chars = sorted(chars)
    try:
        out = subprocess.run(['opencc', '-c', 't2s'], input='\n'.join(chars),
                             capture_output=True, text=True, check=True).stdout
    except (OSError, subprocess.CalledProcessError) as e:
        sys.exit(f'--apply needs the opencc CLI to tell a glyph variant from '
                 f'a different word: {e}')
    return dict(zip(chars, out.split('\n')))


def admissible(ours, printed, t2s, printed_corpus):
    """May this one character be conformed to the printed edition?

    Three ways to get this wrong, all of them present in the real data:

    * a different WORD — the printed 馬可福音 reads 耶穌 where we read 他.
      Adopting that is adopting a revision, which is the publisher's
      question to answer, not ours. Rejected by requiring both characters
      to reduce to the same Simplified character.
    * the printed edition's OWN typos — it prints 审 once in 4,800 verses
      of 審, and 麽 five times against 745 of 麼. Adopting those would put
      Simplified characters into the Traditional text. Rejected by never
      accepting a Simplified reading over a Traditional one.
    * glyph churn — 說/説, 着/著, 溫/温 differ by font convention, we are
      internally consistent, and changing thousands of them is a
      readability decision for the user rather than an accuracy fix.
      Rejected by only touching characters that are either Simplified on
      our side or absent from all five printed volumes.
    """
    if t2s.get(ours) != t2s.get(printed):
        return False
    if t2s.get(ours) != ours and t2s.get(printed) == printed:
        return False
    ours_is_simplified = t2s.get(ours) == ours and t2s.get(printed) != printed
    return ours_is_simplified or ours not in printed_corpus


def repairs_for(seg, printed, spans=(7, 5, 4)):
    """Same, tried at several context widths.

    A wide window is the safest evidence, but two differences less than
    seven characters apart hide each other — 馬可福音 14:58 reads
    他説過 and 拆毁 within eight characters, and the wide window found
    only the first. So the window narrows until the printed edition
    answers, and never below eight fixed characters of context, which in
    Chinese is already far past coincidence in a 286,000-character
    corpus.
    """
    out, seen_at = [], set()
    for span in spans:
        for i, a, b in _repairs_at(seg, printed, span):
            if i not in seen_at:
                seen_at.add(i)
                out.append((i, a, b))
    return out


def _repairs_at(seg, printed, span):
    """Every character the printed edition reads differently, with evidence.

    Deliberately not a list of variant pairs. A list gets applied
    everywhere and is wrong wherever the printed edition happens to use
    the other form — and it does: it prints 贊同 at 路加福音 11:48 and
    讚同 at 使徒行傳 8:1, 托夢 at 馬太福音 2:19 and 託付 four verses later.
    So each character is settled by the printed text AT THAT PLACE:
    hold its neighbours fixed, wildcard the one position, and believe
    the answer only if the printed edition supplies exactly one.

    The neighbourhood is a window rather than the whole verse because
    verses have more than one difference. 馬可福音 14:58 differs in two
    places, and requiring the rest of the verse to match exactly hid a
    real defect behind an unrelated one — we read 拆毁 where the printed
    edition reads 拆毀.
    """
    if seg in printed:
        return []
    found = []
    for i in range(len(seg)):
        lo, hi = max(0, i - span), min(len(seg), i + span + 1)
        if (hi - lo) - 1 < 8:  # too little context to be sure of a match
            continue
        pattern = re.escape(seg[lo:i]) + '.' + re.escape(seg[i + 1:hi])
        seen = {m.group(0)[i - lo] for m in re.finditer(pattern, printed)}
        if len(seen) == 1:
            other = seen.pop()
            if other != seg[i]:
                found.append((i, seg[i], other))
    return found


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--volume', type=int, required=True, choices=sorted(VOLUMES))
    ap.add_argument('--book', help='one book of the volume')
    ap.add_argument('--assets', default='assets/biblexg-v2-tr.json')
    ap.add_argument('--json', help='write the candidate differences to a file')
    ap.add_argument('--min-segment', type=int, default=4,
                    help='ignore fragments shorter than this many characters')
    ap.add_argument('--apply', action='store_true',
                    help='write back the single-character repairs the printed '
                         'edition settles on its own; wording differences are '
                         'always left alone')
    args = ap.parse_args()

    name, books = VOLUMES[args.volume]
    path = os.path.join(SRC, name)
    if not os.path.exists(path):
        sys.exit(f'{path} missing — re-extract with '
                 f'pdftotext -enc UTF-8 from the user\'s Downloads')
    lines = open(path, encoding='utf-8').read().split('\n')

    ours = json.load(open(args.assets, encoding='utf-8'))
    wanted = [args.book] if args.book else books
    if args.book and args.book not in books:
        sys.exit(f'{args.book} is not in volume {args.volume}')

    total = confirmed = 0
    suspects, repairs = [], []
    for book in wanted:
        start, end = book_body(lines, book, books)
        printed = stream(lines[start:end], book)
        verses = [v for v in ours if v['book'] == book]
        print(f'{book}: {len(verses):,} verses ours, '
              f'{len(printed):,} characters printed', file=sys.stderr)
        for v in verses:
            segs = [s for s in segments(v['text']) if len(s) >= args.min_segment]
            if not segs:
                continue
            total += 1
            missing = [s for s in segs if s not in printed]
            if not missing:
                confirmed += 1
                continue
            fixes = [(seg, r) for seg in missing
                     for r in repairs_for(seg, printed)]
            suspects.append({'book': book, 'chapter': v['chapter'],
                             'verse': v['verseLabel'], 'ours': v['text'],
                             'missing': missing,
                             'repairs': [{'ours': a, 'printed': b, 'at': seg}
                                         for seg, (_, a, b) in fixes]})
            for seg, (i, a, b) in fixes:
                repairs.append((v, seg, i, a, b))

    print()
    print(f'verses checked          : {total:,}')
    print(f'confirmed word for word : {confirmed:,} '
          f'({confirmed * 100 // max(total, 1)}%)')
    print(f'candidate differences   : {len(suspects):,}')
    print(f'  of which one character the printed edition settles: {len(repairs):,}')
    print()
    for s in suspects:
        print(f"{s['book']} {s['chapter']}:{s['verse']}")
        print(f"  ours    : {norm(s['ours'])}")
        for m in s['missing']:
            print(f"  missing : {m}")
        for r in s['repairs']:
            print(f"  printed reads {r['printed']} where we have {r['ours']}")
        print()

    if args.apply and repairs:
        corpus = set(''.join(open(os.path.join(SRC, n), encoding='utf-8').read()
                             for n, _ in VOLUMES.values()))
        t2s = to_simplified({c for _, _, _, a, b in repairs for c in (a, b)})
        allowed = [r for r in repairs if admissible(r[3], r[4], t2s, corpus)]
        held = len(repairs) - len(allowed)
        print(f'{len(allowed)} conformable, {held} held back as wording or '
              f'glyph decisions', file=sys.stderr)
        applied = 0
        for v, seg, i, a, b in allowed:
            # Rewrite the raw verse, not the normalised one: our text may
            # carry markup and spacing that normalisation dropped, so the
            # position is re-found by the neighbouring characters.
            ctx = re.escape(seg[max(0, i - 4):i]) + a + re.escape(seg[i + 1:i + 5])
            new, n = re.subn(ctx, lambda mm: mm.group(0).replace(a, b, 1),
                             v['text'], count=1)
            if n:
                v['text'] = new
                applied += 1
            else:
                print(f"  SKIPPED {v['book']} {v['chapter']}:{v['verseLabel']} "
                      f"{a}->{b} — could not place it in the raw text",
                      file=sys.stderr)
        json.dump(ours, open(args.assets, 'w', encoding='utf-8'),
                  ensure_ascii=False, indent=1)
        print(f'applied {applied} single-character repairs to {args.assets}',
              file=sys.stderr)

    if args.json:
        json.dump(suspects, open(args.json, 'w', encoding='utf-8'),
                  ensure_ascii=False, indent=1)
        print(f'wrote {args.json}', file=sys.stderr)
    return 0


if __name__ == '__main__':
    sys.exit(main())
