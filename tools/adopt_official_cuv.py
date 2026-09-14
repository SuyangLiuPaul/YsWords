#!/usr/bin/env python3
"""Adopt the official 和合本雅偉版 text, both scripts, from yahwehdehua.

2026-09-14, on the owner's instruction: 「繁体版也adopt yahwehdehua他们的
版本 ... 因为那边才是正式的」.

WHAT CHANGES, AND WHY THIS IS NOT THE EDIT THE FREEZE FORBIDS
-------------------------------------------------------------
`cuvs_yhwh_frozen_test.dart` says it in as many words: "The hash changes
only when the publisher ships us a new module — and then the commit that
updates it should say so and nothing else." That is this. The freeze
exists to stop US correcting a text we do not own; this replaces our copy
with theirs, which is the opposite direction.

The Traditional column is the one that moves. `tools/export-app-db.py` on
the official side records that `bible_cuvt` was built with `tools/tc`
(OpenCC plus scripture corrections) — so the official Traditional is a
conversion of the official Simplified, and this repo's Traditional was a
different lineage with a different convention:

    ours     神說：「要有光。」就有了光。
    theirs   神説：“要有光。”就有了光。

Corner brackets become curly quotes and 說 becomes 説, on every quoted
line in the Bible. That is a large visible change and it is deliberate:
the owner's ruling is that the official side is the text, and a reader
who compares the app with yahwehword.com should see the same words.

`docs/cuv-yhwh-publisher-notes.md` recorded the 「」/『』 correspondence as
a rule with no counter-example. It was true of the assets as they stood.
It is not a rule about the edition, and that page is corrected rather
than quietly left behind.

WHAT IS NOT TAKEN
-----------------
**The three markers on 主 are ours and win**, exactly as in
`sync_cuv_yhwh_to_publisher.py`, and for the reason recorded there and in
the publisher notes: `主[雅伟]` / `主[基督]` / `主[耶稣]` render the
publisher's `主[雅伟]` / `主#` / `主*`, the 主* set was restored from git
history rather than from this database, and 使徒行傳 9:29 must NOT gain
one because the two sources disagree at source. So the publisher's WORDS
are taken and our MARKERS are re-applied by counting 主 left to right. A
verse whose bare-主 count differs between the two is not a mapping this
can make: it is skipped and named.

House style is likewise preserved: `〔…〕` becomes `<note: …>`, except
where the brackets nest (馬太福音 17:21) or where the note IS the whole
verse (the 84 verses reading 〔见上节〕), both of which stay raw for the
reasons the sibling tool documents.

Unlike that tool, the two scripts are adopted INDEPENDENTLY, each from
its own official column. The old pass mirrored Simplified edits onto the
Traditional at matching character positions and had to skip whatever was
not aligned; there is nothing to mirror when both sides are given.

Usage:
    tools/adopt_official_cuv.py                 # dry run, both scripts
    tools/adopt_official_cuv.py --write
    tools/adopt_official_cuv.py --repo <path>   # the sibling app
"""
import json
import os
import re
import sqlite3
import sys

DB = os.path.expanduser(
    '~/Documents/CodingProject/Yahwehdehua/app/build/bible.db')

# One entry per script: the official column, our asset, and the three
# markers as that script spells them.
SCRIPTS = {
    'cuvs': dict(asset='cuvs-yhwh.json',
                 yahweh='主[雅伟]', christ='主[基督]', jesus='主[耶稣]'),
    'cuvt': dict(asset='cuvs-yhwh-tr.json',
                 yahweh='主[雅偉]', christ='主[基督]', jesus='主[耶穌]'),
}


# Corruptions this repo has already found and repaired, and which the
# official text still carries. Adopting a verse that would put one back is
# the one thing this pass must not do.
#
# 2026-09-14: the first run of this tool re-introduced 承巡 for 承受
# (耶利米書 12:14), 愚昧人所用, and 像烧碎一样 — a simile whose object
# (H7179 קַשׁ, stubble) is missing. `cuvs_yhwh_integrity_test.dart`'s
# lookalike check caught all of them, which is what it is for.
#
# So the rule is the markers' rule, applied to characters: the
# publisher's WORDS are taken, and a verse whose official text would
# reintroduce a named corruption keeps OURS and is reported. These are
# not our corrections to the edition's wording; they are OCR damage the
# edition's own source has, already diagnosed against the Hebrew, each
# entry carrying the Strong's number that proves it.
#
# The list is the keys of that test's table. `adopt_official_cuv_test`
# keeps the two in step.
KNOWN_CORRUPTIONS = [
    '丶', '恉', '逿', '承巡', '扔菏', '暇疵',
    '归到们', '歸到們', '的士师年', '的士師年',
    '因为罗变为', '因為羅變為', '地着的出产', '地著的出產',
    '城邑中里', '城邑中裏', '记纪念碑', '記紀念碑',
    '像烧碎一样', '像燒碎一樣', '作以色的',
    '站玛他提雅', '站瑪他提雅', '为上友', '為上友',
    '江河并河的', '江河並河的', '愚昧人所用',
]


# The repair for each, as a substring pair. Six verses, every one of them
# already diagnosed in `cuvs_yhwh_integrity_test.dart` against the Hebrew
# — H7179 קַשׁ for the missing stubble, H3478 יִשְׂרָאֵל for the truncated
# 以色, H8193 for the displaced 上 of 嘴上.
#
# Applied AFTER the official text is taken, so the verse keeps the
# official wording and punctuation and loses only the damage. Keeping our
# whole verse instead was the first attempt and left six verses on the old
# quotation convention while the other 31,096 moved — which the derived
# Traditional layer caught immediately, because its positional table had
# moved with the majority.
REPAIRS = [
    ('烧碎一样', '烧碎秸一样'),
    ('燒碎一樣', '燒碎秸一樣'),
    ('作以色的', '作以色列的'),
    ('暇疵', '瑕疵'),
    ('承巡', '承受'),
    ('愚昧人所用', '愚昧牧人所用'),
    # 箴言 22:11, both scripts: the 上 of 嘴上 (H8193, lips) was displaced
    # to the end, where 为上友 says nothing. Moving it back is one pair
    # rather than two, so a half-applied repair cannot happen.
    ('嘴的恩言，王必与他为上友', '嘴上的恩言，王必与他为友'),
    ('嘴的恩言，王必與他為上友', '嘴上的恩言，王必與他為友'),
]


def repair(text):
    for wrong, right in REPAIRS:
        text = text.replace(wrong, right)
    return text


def corruptions_in(text):
    return [c for c in KNOWN_CORRUPTIONS if c in text]


def marked_re(spec):
    inner = '|'.join(re.escape(spec[k][2:-1]) for k in ('yahweh', 'christ', 'jesus'))
    return re.compile(r'主(?:\[(?:' + inner + r')\]|\*|#)?')


def fold(text, spec):
    """Our rendering -> the publisher's own notation."""
    text = re.sub(r'<note:\s*([^>]*)>',
                  lambda m: '〔' + m.group(1).strip() + '〕', text)
    return text.replace(spec['jesus'], '主*').replace(spec['christ'], '主#')


def unfold(text, spec, keep_brackets=False):
    text = text.replace('主*', spec['jesus']).replace('主#', spec['christ'])
    if keep_brackets:
        return text
    if re.search(r'〔[^〕]*〔', text):
        return text
    converted = re.sub(r'〔([^〕]*)〕',
                       lambda m: '<note: ' + m.group(1) + '>', text)
    # A verse whose WHOLE body is a note. The sibling tool keeps the
    # brackets here unconditionally, for the 84 verses reading 〔见上节〕
    # and nothing else — converting those left the reader an empty verse
    # behind a footnote icon.
    #
    # 2026-09-14: unconditional was too broad, and `keep_brackets` already
    # carries the answer — it says what OUR verse did. 馬可福音 9:44 and
    # 9:46 are whole-verse notes too (〔有些抄本有44節：…〕), and both
    # scripts have shipped them as `<note: …>` for as long as the assets
    # have existed, which is why `verse_alignment_test` requires the
    # omitted references to carry no scripture. Keeping the brackets there
    # made the Traditional read as scripture while the Simplified did not
    # — one verse, two forms, from a rule that never looked.
    if keep_brackets and re.sub(r'<note:[^>]*>', '', converted).strip() == '':
        return text
    return converted


# A footnote, in the publisher's own notation. Everything inside one is
# apparatus rather than scripture.
NOTE = re.compile(r'〔[^〕]*〕')


def _outside_notes(text):
    """The spans of `text` that are scripture, not footnote."""
    spans, pos = [], 0
    for m in NOTE.finditer(text):
        if m.start() > pos:
            spans.append((pos, m.start()))
        pos = m.end()
    if pos < len(text):
        spans.append((pos, len(text)))
    return spans


def suffixes(text, marked):
    """What follows each 主 IN SCRIPTURE, in order: '[雅伟]', '*', '#' or ''.

    Notes are excluded, and that is not a detail. The publisher writes
    footnotes such as 〔"主"原文是"雅伟"〕 — the note is ABOUT the word 主
    and therefore contains it, while our own wording of the same note
    does not. Counting those made eleven verses look like a 1-vs-2
    mismatch and skipped them, including 申命記 6:4, the Shema. A marker
    never attaches to a 主 inside an apparatus note; only scripture
    carries them.
    """
    return [m.group(0)[1:]
            for a, b in _outside_notes(text)
            for m in marked.finditer(text[a:b])]


def apply_suffixes(text, want, marked):
    """Rewrite each scripture 主's marker to the corresponding entry of
    `want`. Caller guarantees the counts match."""
    out, pos, i = [], 0, 0
    for a, b in _outside_notes(text):
        out.append(text[pos:a])
        seg, last = text[a:b], 0
        for m in marked.finditer(seg):
            out.append(seg[last:m.start()])
            out.append('主' + want[i])
            last = m.end()
            i += 1
        out.append(seg[last:])
        pos = b
    out.append(text[pos:])
    return ''.join(out)


def is_han(ch):
    return '\u3400' <= ch <= '\u9fff' or '\uf900' <= ch <= '\ufaff'


def keep_our_glyphs(ours, theirs):
    """Take the official punctuation, keep our Han-glyph decisions.

    2026-09-14, after the first full run: the official Traditional is
    built by OpenCC (`tools/export-app-db.py` on that side says so), and
    OpenCC has to guess the one-to-many cases — 干 → 乾/幹, 谷 → 谷/穀,
    发 → 發/髮, 面 → 面/麵. It guesses wrong in places this repo has
    already settled, verse by verse, with a test each: 創世紀 41's lean
    cows are 乾瘦, not 幹瘦. Adopting wholesale reverted about fifty such
    repairs and turned twenty test files red — `traditional_dry_glyph`,
    `_grain_`, `_hair_`, `_flour_`, `_jar_`, `_ridge_`, `_tail_` and the
    rest, each of which exists because somebody checked one against the
    Hebrew.
    
    So the split is by KIND of character, which is the line the two sides
    actually disagree along:
    
      * **Punctuation takes the official form.** 「」→“” and the rest of
        the convention is the owner's ruling and the visible half of it.
      * **A Han character keeps ours** where the two differ, because ours
        is a decision and theirs is a conversion.
    
    Both strings stand opposite the same Simplified verse and so are the
    same length; where they are not, nothing is merged and the official
    text is taken whole.
    """
    if len(ours) != len(theirs):
        return theirs
    return ''.join(
        o if (o != t and is_han(o) and is_han(t)) else t
        for o, t in zip(ours, theirs))


def adopt(repo, version, write):
    spec = SCRIPTS[version]
    marked = marked_re(spec)
    asset = os.path.join(repo, 'assets', spec['asset'])
    if not os.path.exists(asset):
        print('%-5s  no such asset in this repo: %s' % (version, asset))
        return
    con = sqlite3.connect('file:%s?mode=ro' % DB, uri=True)
    seq = {code: s for s, code in con.execute('select seq, code from books')}
    pub = {'%03d%03d%03d' % (seq[b], c, v): p
           for b, c, v, p in con.execute(
               'select book, chapter, verse, plain from verses '
               'where version=?', (version,))}

    rows = json.load(open(asset, encoding='utf-8'))
    updated = same = marker_only = skipped = missing = corrupt = 0
    repaired = 0
    skips = []
    corruptions = []
    for r in rows:
        theirs = pub.get(r['id'])
        if theirs is None:
            missing += 1
            continue
        ours = fold(r['text'], spec)
        if ours == theirs:
            same += 1
            continue
        mine, yours = suffixes(ours, marked), suffixes(theirs, marked)
        if len(mine) != len(yours):
            skipped += 1
            skips.append((r['id'], r['book'], r['chapter'], r['verse'],
                          len(mine), len(yours)))
            continue
        merged = apply_suffixes(theirs, mine, marked)
        if merged == ours:
            marker_only += 1
            continue
        candidate = unfold(merged, spec, keep_brackets='〔' in r['text'])
        if version == 'cuvt':
            candidate = keep_our_glyphs(r['text'], candidate)
        before = corruptions_in(candidate)
        if before:
            candidate = repair(candidate)
            still = [c for c in corruptions_in(candidate)
                     if c not in corruptions_in(r['text'])]
            if still:
                # Nothing in REPAIRS answered it. Keep ours and say so,
                # rather than ship damage this repo has already named.
                corrupt += 1
                corruptions.append((r['id'], r['book'], r['chapter'],
                                    r['verse'], '/'.join(still)))
                continue
            repaired += 1
        if candidate == r['text']:
            same += 1
            continue
        r['text'] = candidate
        updated += 1

    print('%s  (%s)' % (version, spec['asset']))
    print('    already current:                     %6d' % same)
    print('    adopted from the official text:      %6d' % updated)
    print('    differed only in 主 markers, ours kept: %4d' % marker_only)
    print('    skipped, the 主 count itself differs:   %4d' % skipped)
    print('    not in the official table:             %5d' % missing)
    print('    adopted, then repaired a known corruption:      %4d'
          % repaired)
    print('    kept ours, no repair answered the corruption:   %4d'
          % corrupt)
    for c in corruptions:
        print('        %s %s %s:%s  would reintroduce %s' % c)
    for s in skips[:20]:
        print('        %s %s %s:%s  ours %d 主, theirs %d' % s)
    if len(skips) > 20:
        print('        ... and %d more' % (len(skips) - 20))

    text = ''.join(r['text'] for r in rows)
    print('    markers after: %s %d  %s %d  %s %d   verses %d'
          % (spec['yahweh'], text.count(spec['yahweh']),
             spec['christ'], text.count(spec['christ']),
             spec['jesus'], text.count(spec['jesus']), len(rows)))

    if write:
        with open(asset, 'w', encoding='utf-8') as f:
            json.dump(rows, f, ensure_ascii=False, indent=2)
            f.write('\n')
        print('    WROTE %s' % asset)


def main():
    write = '--write' in sys.argv
    repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if '--repo' in sys.argv:
        repo = os.path.abspath(sys.argv[sys.argv.index('--repo') + 1])
    print('repo: %s' % repo)
    for version in ('cuvs', 'cuvt'):
        adopt(repo, version, write)
    if not write:
        print('\n(dry run; pass --write)')


if __name__ == '__main__':
    main()
