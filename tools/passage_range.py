#!/usr/bin/env python3
"""Normalise a free-form scripture reference to a comparable range list.

Used by `reconcile_matthew_124.py` to decide whether two references —
one written by us in `assets/sermons/index.json`, one written by the
church on `/content/124-messages` — name the SAME passage.

`reconcile_matthew_124.py`'s original `parse_ref` reduced a reference to
`(book, chapter, first verse)`. That is deliberately loose, and it is
what produced the "61 exact" figure: under it `Matthew 3:13-17` and
`Matthew 3:13 - 4:17` are the same passage, so messages 006, 007 and 008
all collapsed onto our single recording 002. Loose is right for a
survey. It is wrong for a link.

This module keeps the whole range, so those three stay distinct.

WHAT IT RETURNS
---------------
`normalize(ref)` -> `Passage(book, ranges, partial)` or None.

  book    canonical name of the FIRST book named in the string. The
          church lists parallels after the passage the message is
          actually on ("Luke 9:23-25, par. Matthew 16:24-26"), so the
          first book is the subject and the rest are cross-references.
  ranges  every range given for that book, in order, as
          `(startChapter, startVerse, endChapter, endVerse)`. A whole
          chapter is `(c, None, c, None)`.
  partial True when any verse carried a letter suffix — `11:12b`,
          `12:30b`. See PARTIAL VERSES.

Segments naming other books are parsed only far enough to know where
the first book's text ends.

PARTIAL VERSES ARE NOT NORMALISED AWAY
--------------------------------------
The church's edition splits a single verse across separate messages:
026 is `Matthew 11:12` and 027 is `Matthew 11:12b`, two different talks.
Our index writes `Mt 11:12` for one recording and gives no way to tell
which half it is. So a letter suffix is recorded and the caller must
refuse the pair — dropping the suffix would make 11:12b look like an
exact match for a recording that may be about 11:12a.

MALFORMED RANGES ARE REJECTED, NOT REPAIRED
-------------------------------------------
Message 046 reads `Matthew 15:21-18`, plainly a typo for 15:21-28 (047
has it right). `normalize` returns None for it rather than guessing,
because a guess here is indistinguishable from a reading.
"""
import re

# Canonical names for every abbreviation that appears on either side.
# An unknown token must fail rather than quietly match nothing, so the
# caller checks for None.
BOOKS = {
    'gen': 'Genesis', 'genesis': 'Genesis',
    'deut': 'Deuteronomy', 'deuteronomy': 'Deuteronomy',
    'ps': 'Psalms', 'psalm': 'Psalms', 'psalms': 'Psalms',
    'songs': 'Song of Songs', 'song': 'Song of Songs',
    'isa': 'Isaiah', 'isaiah': 'Isaiah',
    'mt': 'Matthew', 'matt': 'Matthew', 'matthew': 'Matthew',
    'mk': 'Mark', 'mark': 'Mark',
    'lk': 'Luke', 'luke': 'Luke',
    'jn': 'John', 'john': 'John',
    'acts': 'Acts',
    'rom': 'Romans', 'romans': 'Romans',
    '1cor': '1 Corinthians', '2cor': '2 Corinthians',
    'gal': 'Galatians', 'galatians': 'Galatians',
    'eph': 'Ephesians', 'ephesians': 'Ephesians',
    'phil': 'Philippians', 'philippians': 'Philippians',
    'col': 'Colossians', 'colossians': 'Colossians',
    'heb': 'Hebrews', 'hebrews': 'Hebrews',
    'jas': 'James', 'james': 'James',
    '1pet': '1 Peter', '2pet': '2 Peter',
    '1jn': '1 John', '1john': '1 John',
    'titus': 'Titus',
    'rev': 'Revelation', 'revelation': 'Revelation',
}

# Longest-first so `matthew` wins over `matt`, and `1cor` over `cor`.
_BOOK_RE = re.compile(
    r'(?<![A-Za-z0-9])('
    + '|'.join(re.escape(b) for b in sorted(BOOKS, key=len, reverse=True))
    + r')\.?(?![A-Za-z])', re.I)

# Words that join references and carry no reference of their own.
_NOISE = re.compile(r'\b(par|parallel|parallels|cf|and|see|also|verse|'
                    r'verses|vv|v)\b\.?', re.I)


class Passage:
    """A book plus the ranges given for it. Compare with `==`."""

    __slots__ = ('book', 'ranges', 'partial')

    def __init__(self, book, ranges, partial):
        self.book = book
        self.ranges = tuple(ranges)
        self.partial = partial

    def key(self):
        """Hashable identity. Excludes `partial` — a partial reference
        never reaches a comparison; the caller drops it first."""
        return (self.book, self.ranges)

    def __eq__(self, other):
        return isinstance(other, Passage) and self.key() == other.key()

    def __hash__(self):
        return hash(self.key())

    def __repr__(self):
        return f'Passage({self.book!r}, {self.ranges!r}, partial={self.partial})'

    def display(self):
        """`Matthew 3:13-4:17`, `Matthew 23`, `Matthew 3:15, 4:17`."""
        out = []
        for c1, v1, c2, v2 in self.ranges:
            if v1 is None:
                out.append(str(c1) if c1 == c2 else f'{c1}-{c2}')
            elif c1 == c2 and v1 == v2:
                out.append(f'{c1}:{v1}')
            elif c1 == c2:
                out.append(f'{c1}:{v1}-{v2}')
            else:
                out.append(f'{c1}:{v1}-{c2}:{v2}')
        return f'{self.book} ' + ', '.join(out)


def _segments(ref):
    """[(canonical book, the text that follows it)] in source order."""
    out = []
    hits = list(_BOOK_RE.finditer(ref))
    for i, m in enumerate(hits):
        book = BOOKS.get(m.group(1).lower())
        if not book:
            continue
        end = hits[i + 1].start() if i + 1 < len(hits) else len(ref)
        out.append((book, ref[m.end():end]))
    return out


def _parse_spec(spec):
    """`3:13-17, 20` -> [(3,13,3,17), (3,20,3,20)], or None if malformed.

    Returns `(ranges, partial)`. `partial` is True when a verse carried
    a letter suffix.
    """
    s = _NOISE.sub(',', spec)
    # `23:31-24.3` and `11:30-12.1` write the chapter break with a dot.
    s = re.sub(r'(?<=\d)\s*\.\s*(?=\d)', ':', s)
    s = s.replace(';', ',').replace('–', '-').replace('—', '-')
    s = re.sub(r'[^0-9:,\-a-z]', ' ', s.lower())

    parts = [p.strip() for p in s.split(',')]
    parts = [p for p in parts if p]
    if not parts:
        return None, False

    # A segment with no colon anywhere is chapter-only ("Matthew 8",
    # "Matthew 23 and 24"). Once a colon appears, a bare number is a
    # verse continuing the chapter in force ("13:24-30, 36-43").
    versed = ':' in s
    ranges = []
    partial = False
    cur = None
    for p in parts:
        p = re.sub(r'\s+', '', p)
        if not p:
            continue
        if re.search(r'\d[a-z]', p):
            partial = True
            p = re.sub(r'(?<=\d)[a-z]+', '', p)
        if not versed:
            m = re.fullmatch(r'(\d+)(?:-(\d+))?', p)
            if not m:
                return None, partial
            c1 = int(m.group(1))
            c2 = int(m.group(2)) if m.group(2) else c1
            if c2 < c1:
                return None, partial
            ranges.append((c1, None, c2, None))
            continue
        m = re.fullmatch(r'(?:(\d+):)?(\d+)(?:-(?:(\d+):)?(\d+))?', p)
        if not m:
            return None, partial
        c1 = int(m.group(1)) if m.group(1) else cur
        if c1 is None:
            return None, partial
        v1 = int(m.group(2))
        c2 = int(m.group(3)) if m.group(3) else c1
        v2 = int(m.group(4)) if m.group(4) else v1
        if (c2, v2) < (c1, v1):
            return None, partial
        ranges.append((c1, v1, c2, v2))
        cur = c2
    return (ranges or None), partial


def normalize(ref):
    """Free-form reference -> Passage for its FIRST book, or None."""
    if not ref or not ref.strip():
        return None
    segs = _segments(ref)
    if not segs:
        return None
    book = segs[0][0]
    ranges = []
    partial = False
    for b, spec in segs:
        if b != book:
            continue
        got, part = _parse_spec(spec)
        partial = partial or part
        if got is None:
            return None
        ranges.extend(got)
    if not ranges:
        return None
    return Passage(book, ranges, partial)


# `python3 tools/passage_range.py` — the parsing rules, pinned. Every
# case below is a real string from one side or the other, and the ones
# that return None or set `partial` are the reason the shipped mapping
# is 36 and not 61.
_CHECKS = [
    # The three that collapse onto our recording 002 under a
    # first-verse key and stay distinct under this one.
    ('Matthew 3:13-17', 'Matthew 3:13-17', False),
    ('Matthew 3:13 - 4:17', 'Matthew 3:13-4:17', False),
    ('Mt 3:13-17', 'Matthew 3:13-17', False),
    # Our index and their listing write a chapter break differently.
    ('Mt 23:31-24.3', 'Matthew 23:31-24:3', False),
    ('Matthew 23:31-24:3', 'Matthew 23:31-24:3', False),
    # Parallels follow the subject, so only the first book counts.
    ('Luke 9:23-25, par. Matthew 16:24-26', 'Luke 9:23-25', False),
    ('Mark 10:21-30; par. Matthew 19:16-30', 'Mark 10:21-30', False),
    # Two disjoint verses, written two ways, same passage.
    ('Mt 3:15 and Mt 4:17', 'Matthew 3:15, 4:17', False),
    ('Matthew 3:15, 4:17', 'Matthew 3:15, 4:17', False),
    # A bare number is a chapter until a colon appears, then a verse.
    ('Matthew 23 and 24', 'Matthew 23, 24', False),
    ('Mt 23', 'Matthew 23', False),
    ('Mt 13:24-30, 36-43', 'Matthew 13:24-30, 13:36-43', False),
    # Partial verses: recorded, never normalised away.
    ('Matthew 11:12', 'Matthew 11:12', False),
    ('Matthew 11:12b', 'Matthew 11:12', True),
    # Refused, not repaired. 046's end verse precedes its start (a typo
    # for 15:21-28); 063's passage in our own index is unparseable.
    ('Matthew 15:21-18', None, None),
    ('Mt 11:30-12.1-8', None, None),
    ('Spiritual Direction #2', None, None),
    # The near-miss that title matching fell for: #1 and #2 of the same
    # series, and the ranges are what tell them apart.
    ('Luke 4:1-4, Matthew 4:1-4', 'Luke 4:1-4', False),
    ('Luke 4:5-13, Matthew 4:5-11', 'Luke 4:5-13', False),
]

if __name__ == '__main__':
    bad = 0
    for ref, want, want_partial in _CHECKS:
        got = normalize(ref)
        shown = got.display() if got else None
        if shown != want or (got is not None and got.partial != want_partial):
            bad += 1
            print(f'FAIL {ref!r}\n  want {want!r} partial={want_partial}\n'
                  f'  got  {shown!r} '
                  f'partial={got.partial if got else None}')
    print(f'{len(_CHECKS) - bad}/{len(_CHECKS)} ok')
    raise SystemExit(1 if bad else 0)
