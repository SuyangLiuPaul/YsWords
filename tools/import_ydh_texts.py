#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Build `assets/<code>.json` for the texts the 雅伟的话 project exports.

    python3 tools/import_ydh_texts.py --list
    python3 tools/import_ydh_texts.py bsb bsb-yhwh asv-yhwh wh
    python3 tools/import_ydh_texts.py --all --dry-run

THE SOURCE IS THE EXPORTED SQLITE, NOT THE SITE'S DATABASE
----------------------------------------------------------
`~/Documents/CodingProject/Yahwehdehua/app/build/bible.db` is the file
`Yahwehdehua/tools/export-app-db.py` writes for the 雅伟的话 phone app.
It is a plain SQLite with no credentials anywhere near it, which is why
this importer reads it instead of the MariaDB that `import_csb.py` talks
to. Nothing here needs a password and nothing here should ever grow one.

WHAT IS AND IS NOT WIRED INTO THE APP
-------------------------------------
This script can build all six texts the export carries beyond the ones
this app already ships. Four of them are wired into
`lib/constants/bible_versions.dart`; two are built only on request and
deliberately not offered to a reader. `SHIPPED` below is the machine-
readable form of that split, and the reason for each is in `TEXTS`.

THE MARKUP, COUNTED RATHER THAN ASSUMED
---------------------------------------
Every `<...>` in all 154,554 source verses was enumerated before this
mapping was written (the counts are per text, from the exported db):

    tag                     bsb    bsb-yhwh  asv-yhwh    wh      lxx
    <WH####> / <WG####>  437,559   437,560   346,817  137,733  432,946
    <WT...>                    -         -         -   90,911  337,412
    <i> </i>                   -         -    6,641×2       -        -
    <cite> </cite>             -         -      116×2       -        -
    <note> </note>             -     209×2         -        -        -
    <fnote> </fnote>           -      28×2         -        -        -
    <RF> <Rf>                  -         -         -        -      1×2

and how each is mapped, with the reason:

  * **`<WH####>` / `<WG####>` — Strong's numbers. DROPPED.** This app
    ships no tagged running text; the word-study features read
    `assets/tagged/` and `assets/originals/`, which are separate files.
    Same call `import_csb.py` made, and for the same reason.
  * **`<WT...>` — Robinson-style morphology (`WTN-GSM`, `WTV-2AAI-3S`).
    DROPPED**, with the Strong's numbers they qualify. Three of them in
    the LXX are malformed — `<WTV) PAPGP>`, `<WTVF FAI3P>`, `<WT2 GSM>`
    — so the pattern is `<WT[^>]*>` and not a tidy `[A-Z-]+`. A tighter
    pattern leaves them in the shipped text; that is exactly how they
    were found.
  * **`<i>…</i>` — the ASV's italics for words with no counterpart in
    the Hebrew or Greek. TAGS DROPPED, TEXT KEPT.** The italics are a
    typographic convention this app has no way to render inside a verse
    (nothing in `bible_reading_pane.dart` styles a span of verse text),
    and the words are the translation. Losing the words would be a
    mistranslation; losing the slant is a formatting loss.
  * **`<cite>…</cite>` — the ASV's psalm superscription ("A Psalm of
    David, when he fled from Absalom"). TAGS DROPPED, TEXT KEPT**, at
    the head of verse 1 where the module puts it. It is scripture in the
    Hebrew numbering and every other edition this app ships prints it
    inline the same way.
  * **`<note>…</note>` and `<fnote>…</fnote>` — the BSB's translator
    notes and footnotes. NOTE AND ITS TEXT BOTH DROPPED.** A footnote is
    apparatus, not the verse, and this app has nowhere to put one.
  * **`<TS#>…<Ts>` — a section heading carried inside the verse text.
    HEADING AND ITS TEXT BOTH DROPPED.** Only the CSB module has these;
    the rule is kept here so the CSB stays buildable. Left in, Ps 23:1
    would read "The Good ShepherdA psalm of David". Headings come from
    `assets/section_titles.json`.
  * **`<CL>` / `<CM>` — theWord's poetic-line and paragraph breaks.
    DROPPED.** Paragraphing comes from `assets/web-ot-paragraphs.json`.
  * **`<redletter>…</redletter>` — words of Christ. TAGS DROPPED, TEXT
    KEPT.** The app has no red-letter mode.
  * **`<RF>…<Rf>` — theWord's footnote marker, one pair in the whole
    export, around the `(1:)` at the head of Lamentations 1:1. TAGS
    DROPPED, TEXT KEPT**, because that `(1:)` is not a footnote: it is
    one of the 4,459 places where the module prints the Septuagint's own
    chapter:verse when it disagrees with the Hebrew numbering. The site
    renders those as prose in grey (`BibleLxx::htmlScripture`), and
    `Yahwehdehua/app/PLAN.md` records the same decision. Dropping it
    would silently hide the fact that LXX Lamentations opens with a
    prologue the Hebrew does not have.

`verses.plain` IS NOT USED, AND HERE IS THE BUG THAT SETTLED IT
---------------------------------------------------------------
The export ships a `plain` column, and reading it would have made this
script twenty lines long. It is wrong in 28 verses: it strips
`<fnote>`/`</fnote>` as tags instead of removing the footnote with them,
so the footnote text lands in the middle of the sentence —

    1 Cor 10:9  plain: "We should not test Christthe Lord* in some
                        Greek manuscripts, as some of them did"
                here : "We should not test Christ, as some of them did"

`<note>` is handled correctly in the same column, which is what makes
this a slip rather than a policy. So the mapping above is applied to the
`text` column, and `plain` is then used as a WITNESS: `--check` reports
every verse where the two disagree, and the expected disagreements are
declared per text in `PLAIN_DIFFS` so a new one fails the run.

THE ONE HAND-NAMED REPAIR
-------------------------
ASV John 8:11 ends `sin no more.]]` — the closing half of the double
bracket the ASV puts round the pericope adulterae. The opening `[[` is
in no verse of the module (John 7:53 and 8:1 are both bare), so the
survivor marks nothing and reads as an import artefact. Removed, as a
counted rule: `EXPECTED_REPAIRS` says exactly one verse may be touched
and the run fails if that stops being true.

WHAT IS DELIBERATELY LEFT ALONE
-------------------------------
`[`, `]` and `*` survive into three of these texts and all of them are
the publisher speaking, which `test/bible_version_integrity_test.dart`
already treats as the dividing line:

  * `asv-yhwh` — `[Selah]`, 63 verses.
  * `wh` — Westcott and Hort's own brackets round text they judged
    doubtful (`ιησου [χριστου]`), 487 verses, and the DOUBLE bracket
    round a passage they judged a later addition: 15 verses open `[[`
    and 14 close `]]`, over Mark 16:9-20, Luke 22:43-44, the Western
    non-interpolations in Luke 24, and John 7:53-8:11.
  * `bsb-yhwh` — `the Lord [Yahweh]` where the New Testament quotes an
    Old Testament passage that has the name (187 verses). This is the
    same convention as the 和合本雅伟版's `[雅伟]`, which this app
    already ships untouched.

    The other TWO markers of that same convention arrived unexpanded
    and are repaired by `tools/expand_bsb_yhwh_markers.py`: `Lord*` in
    111 verses and `Lord#` in 16. This docstring used to say `Lord*`
    marked "a Kyrios the edition read as Adonai rather than YHWH".
    That was wrong. Of the 111 verses carrying it, 108 read 主[耶稣] in
    the publisher's own Chinese edition at the same verse id, and 15 of
    the 16 carrying `Lord#` read 主[基督] — they are 耶稣 and 基督, the
    second and third members of the three-marker system whose first
    member this paragraph already recognised. If a future import
    reintroduces them, expand them; do not ship the printer's marks.

WHAT IS NOT RESTORED HERE
-------------------------
Nothing. Unlike `import_csb.py`, this script makes no divine-name edit
at all: `bsb-yhwh` and `asv-yhwh` arrive already restored by the
ministry, and `bsb`, `wh` and `lxx` are meant to read as published. The
`--check` divine-name census exists to prove that, not to change it.
"""
import argparse
import io
import json
import os
import re
import sqlite3
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(HERE)
ASSETS = os.path.join(PROJECT, 'assets')
SOURCE_DB = os.path.expanduser(
    '~/Documents/CodingProject/Yahwehdehua/app/build/bible.db')


class Text:
    """One text: where it comes from, what it should contain, and why.

    `verses` / `books` / `empty` are the shape of the SOURCE rows, not of
    the file written: an empty verse is a real row in the export (the
    critical text omits it, or the Septuagint has no counterpart) and is
    SKIPPED on the way out, because every bundled asset in this repo
    omits a verse it does not have rather than shipping a blank one —
    `nasb.json` is 31,090 records for exactly this reason, and
    `test/bible_version_integrity_test.dart` fails on an empty string.
    """

    def __init__(self, code, source, verses, books, empty, note):
        self.code = code
        self.source = source
        self.verses = verses
        self.books = books
        self.empty = empty
        self.note = note

    @property
    def expected_records(self):
        return self.verses - self.empty


TEXTS = [
    Text('bsb', 'bsbs', 31102, 66, 16,
         'Berean Standard Bible. Public domain outright since 2023-04-30 '
         '("any use, no permission required") — the one text here whose '
         'licensing needed no judgement from anybody.'),
    Text('bsb-yhwh', 'bsbys', 31102, 66, 16,
         'The same BSB with the divine name restored by the ministry: '
         '5,944 verses read Yahweh where the BSB prints the LORD. Public-'
         'domain base, ministry restoration, exactly the arrangement the '
         '和合本雅伟版 already ships under.'),
    Text('asv-yhwh', 'asvs', 31102, 66, 16,
         'American Standard Version 1901 — public domain by age — with '
         'the ASV\'s own Jehovah rendered Yahweh in 5,787 verses. Four '
         'verses still read Jehovah; they are the ASV\'s marginal notes '
         'on the name itself (Gen 22:14 Jehovah-jireh and friends), '
         'where the word is a place name rather than the tetragrammaton '
         'in running text.'),
    Text('wh', 'whs', 7957, 27, 17,
         'Westcott and Hort, The New Testament in the Original Greek '
         '(1881). Public domain by age.'),
    # ---- built on request, NOT offered to a reader ----
    Text('lxx', 'lxxs', 23145, 39, 303,
         'Septuagint (Greek OT). Shipped 2026-09-08 on the owner\'s '
         'instruction. The module does not name the critical edition it '
         'follows, and the licence note where it arrived reads '
         '「授权仍归 Peter 判断」 — so the About row says what is known '
         'and claims nothing more. See docs/permissions/README.md.'),
    Text('csb-yhwh', 'hcsbs', 31102, 66, 0,
         'CSB (Yahweh). NOT SHIPPED — this app already ships this exact '
         'module as `csb`, and ships it better. See SHIPPED below.'),
]

# The two texts this importer can build and this app does not offer.
#
# **`lxx` — the licence is unresolved, and it is not mine to resolve.**
# The obvious thing to write is "the Septuagint is ancient, therefore
# public domain", and it is wrong: what is copyrighted is the modern
# critical EDITION, and `Yahwehdehua/PROJECT_STATE.md` says so in its own
# words. Its survey of sources concluded that not one was simultaneously
# available, authoritative and clearly licensed — "Rahlfs 有版权,
# CATSS 要求签协议, Swete 只有白文" — and the module that ended up in the
# database did not settle that. It was handed over by Peter on
# 2026-08-30, and the note recording that says, in the same breath,
# 「授权仍归 Peter 判断」: the licence is still Peter's to judge. Nothing
# in a theWord module names its edition, and `tools/import-lxx-wh-ont.py`
# says as much, so this app cannot even state which text it would be
# shipping.
#
# `meta.licence` in the exported db does assert "WH/LXX/WLC public
# domain". That line is the exporter's own summary, written after the
# module was already loaded, and it does not survive being read next to
# the decision log above. `docs/permissions/README.md` sets the rule this
# follows: what a reader is shown must match a document on file or a
# note in `docs/`. There is no such document for this text, and one
# sentence in a generated database is not one.
#
# **`csb-yhwh` — it is the CSB this app already ships.** The export's
# `hcsbs` is `bsapp_bible_hcsbs`, which is the table `tools/import_csb.py`
# already built `assets/csb.json` from on 2026-09-07. Measured verse by
# verse: 26,298 of 31,102 verses are byte-identical, 1,633 differ only in
# whitespace, and the remaining 3,138 differ only by `import_csb.py`'s
# own two clean-ups — the `? ”` → `?”` spacing repair and the divine-name
# restoration. There is no third text here.
#
# Shipping it as a second edition would be worse than redundant, because
# the restoration runs the wrong way round. The module reads Yahweh in
# 5,041 verses; the `csb` this app already offers reads it in 5,805,
# including Deuteronomy 6:4 —
#
#     source module : "Listen, Israel: The Lord our God, the Lord is one."
#     shipped `csb` : "Listen, Israel: Yahweh our God, Yahweh is one."
#
# — so a row labelled "CSB (Yahweh)" would show a reader FEWER occurrences
# of the name than the row labelled plainly "CSB" sitting above it. That
# is not a distinct edition a reader could choose between; it is the same
# licensed text a second time, 6 MB of it, under a label that describes
# the other row.
SHIPPED = {'bsb-yhwh', 'asv-yhwh', 'wh', 'lxx'}
# 'bsb' was shipped for a few hours on 2026-09-08 and withdrawn the same
# day: 「bsbs 不用，就 bsb yahweh 版本导入」.
# 'lxx' was NOT shipped on 2026-09-08 and then WAS, later the same day,
# on the owner's explicit instruction 「用 yahwehdehua lxxs 版本吧」 —
# given after he was shown both options and what separates them. The
# licence position is unchanged by that and is recorded verbatim in
# docs/permissions/README.md; what changed is that the decision is his
# and he made it.

BY_CODE = {t.code: t for t in TEXTS}

# ── the mapping, as two passes ──────────────────────────────────────
# Content-bearing wrappers first, because their contents must go with
# them; the rest are tags round text that stays.
DROP_WITH_CONTENT = re.compile(
    r'<TS\d*>.*?<Ts>'          # section heading (CSB only)
    r'|<note>.*?</note>'       # BSB translator note
    r'|<fnote>.*?</fnote>',    # BSB footnote
    re.S)
DROP_TAG_ONLY = re.compile(
    r'<W[HG]\d+x?>'            # Strong's number (x = the module's own
                               #   marker for a word with no counterpart)
    r'|<WT[^>]*>'              # morphology — see the three malformed ones
    r'|<C[LM]>'                # poetic line / paragraph break
    r'|</?redletter>'          # words of Christ
    r'|</?i>'                  # ASV italics for supplied words
    r'|</?cite>'               # ASV psalm superscription
    r'|<RF>|<Rf>')             # theWord footnote marker, Lam 1:1 only
ANY_TAG = re.compile(r'<[^>]*>')

# ── the same mapping again, but keeping the numbers ─────────────────
# `--tagged` writes `assets/tagged/<code>/<book>.json`, the layer behind
# the Exegesis sheet's numbered running line
# (「地<0776>是<01961>空虚<08414>」). It is the SAME markup table above,
# read once more with the Strong's tags kept instead of dropped, which is
# why it lives in this file rather than in a script of its own: two
# readings of one source in one place cannot drift apart.
#
# Only `bsb-yhwh` and `asv-yhwh`. `bsb` is not offered as a version here,
# and `wh` is the Greek original — an interlinear of the original against
# itself is a different feature, and its 90,911 `<WT…>` morphology tags
# would want a `g` field this pass does not build.
TAGGED = {'bsb-yhwh', 'asv-yhwh'}

# theWord puts the tag AFTER the text it governs, so a run is the text
# since the previous tag. Group 3 is the `x` suffix.
#
# **`x` is not a malformed tag.** It is the module's own mark for a lemma
# that IS in the Hebrew or Greek and has no English word of its own —
# `eat<WH398><WH4480x>` for מִן, `Hallelujah<WH1984><WH3050x>` for
# הַלְלוּ + יָהּ. `bsbys` writes 55,633 of them, headed by H853x (the
# direct-object marker אֵת) and G3588x (the Greek article); `asvs` writes
# none at all. They become `TaggedRun.i` — implied — never `.s`. Reading
# them as ordinary numbers would either put 55,633 empty runs in the
# layer or attach the article's number to whatever English word happened
# to precede it.
STRONGS = re.compile(r'<W([HG])(\d+)(x?)>')

# Everything in DROP_TAG_ONLY except the Strong's tags, which this pass
# consumes rather than discards. Written out again rather than cut out of
# the other pattern by string surgery: a regex assembled by deleting an
# alternative from another regex is a thing nobody can read. The two are
# kept honest by the check that actually matters instead — every verse's
# runs must concatenate to the string `clean()` produced for the SAME
# verse, so a tag one pattern knows and the other does not stops the run.
DROP_TAG_ONLY_KEEPING_STRONGS = re.compile(
    r'<WT[^>]*>'               # morphology (none in these two)
    r'|<C[LM]>'                # poetic line / paragraph break
    r'|</?redletter>'          # words of Christ
    r'|</?i>'                  # ASV italics for supplied words
    r'|</?cite>'               # ASV psalm superscription
    r'|<RF>|<Rf>')             # theWord footnote marker

# Strong's itself stops at H8674 / G5624. Neither module writes above its
# own ceiling — measured, not assumed — and neither carries a tag in the
# H99xx placeholder band the CSB module is full of. The constant is here
# so a future source that DOES grow one fails loudly instead of shipping
# a number no lexicon can answer.
MAX_STRONGS = {'H': 8674, 'G': 5624}

# What `--tagged` must produce. Measured against the shipped reading
# assets; exact rather than a ceiling, for the reason EXPECTED_REPAIRS is
# exact. Measured 2026-09-08.
#
# `numbered` is 98.3% of `bsb-yhwh`'s runs and 100.0% of `asv-yhwh`'s.
# The ASV figure is not a rounding: 15 of its 346,832 runs carry no
# number, and they are the `<cite>` psalm superscriptions, which no
# Strong's tag governs.
#
# `implied` is `bsb-yhwh`'s 55,633 `x` tags, the largest such set in this
# app. `asv-yhwh` has none — that module writes no `x` at all — and a
# zero here is a fact about the source rather than a gap in this pass.
TAGGED_EXPECTED = {
    'bsb-yhwh': {'verses': 31086, 'runs': 388449, 'numbered': 381927,
                 'implied': 55633},
    # 2026-09-09: was {'runs': 346832, 'numbered': 346817, 'implied': 0}.
    #
    # The publisher rebuilt the ASV(Yahweh) theWord module that morning,
    # after 895 verses of the previous one shipped the literal string
    # `None` glued to every word — 以弗所書 2:1 read `NoneAndNone
    # NoneyouNone did he make alive, NonewhenNone …`. 19,167 glued
    # `None`s, gone; the 12 that remain are the English word ("None
    # ought to carry the ark"). Nothing else in the module moved: same
    # 31,114 lines, same 346,817 Strong's tags, same 6,641 `<i>`.
    #
    # But the corruption was MASKING something real, which is why these
    # three numbers move and `implied` in particular. A Strong's tag with
    # no English word in front of it is an implied lemma — the thing
    # `TaggedRun.i` exists for. In the broken module every tag had a word
    # in front of it, because `None` was that word. With the fake words
    # gone, 147 lines show a bare tag (`ye be<WG2075> <WG5100>
    # reprobate<WG96>` — τις, which the ASV renders in nothing), and 22
    # runs are correctly classified as implied instead of being counted
    # as numbered words.
    #
    # So `implied: 0` was never a fact about the ASV. It was a fact
    # about the corruption. `runs` and `numbered` fall by the same 22.
    'asv-yhwh': {'verses': 31086, 'runs': 346810, 'numbered': 346795,
                 'implied': 22},
}

# ASV John 8:11's orphaned closing bracket — see the docstring.
#
# **Keyed by text, and that is the whole point.** The first version of
# this ran on everything and quietly deleted eleven `]]` from the WH,
# where the double bracket is not damage but Westcott and Hort's own
# mark for a passage they judged a later addition. The census that
# caught it: WH has 15 verses opening `[[` and 14 closing `]]`, and they
# are the passages you would expect — Mark 16:9-20, Luke 22:43-44,
# Luke 23:34, the Western non-interpolations in Luke 24, Matt 16:2-3,
# Matt 27:49, John 7:53-8:11. The ASV has **0 openers and 1 closer**. So
# the same two characters are the editors speaking in one text and an
# import artefact in the other, and a rule that cannot tell them apart
# has no business running on both.
STRAY_CLOSER = re.compile(r'\]\]\s*$')
REPAIR_STRAY_CLOSER = {'asv-yhwh'}
EXPECTED_REPAIRS = {'asv-yhwh': 1}

# Verses where the export's own `plain` column disagrees with the mapping
# above. Declared so a NEW disagreement is a failure rather than a shrug.
#   bsb-yhwh 28 — the `<fnote>` verses `plain` inlines. `<note>` agrees
#                 in all 209, which is what makes the fnote handling a
#                 slip in the exporter rather than a policy.
#   asv-yhwh  1 — John 8:11, the bracket repair above.
#   lxx       0 — but only after `<WT[^>]*>` was widened and `<RF>`/`<Rf>`
#                 were added. Before that it was 4, and the four were the
#                 three malformed morphology tags and Lam 1:1. `plain`
#                 got all four right; agreeing with it here is the
#                 evidence that the widening was correct rather than
#                 merely quieter.
PLAIN_DIFFS = {'bsb': 0, 'bsb-yhwh': 28, 'asv-yhwh': 1, 'wh': 0,
               'lxx': 0, 'csb-yhwh': None}

# Verses quoted back at the operator after every build. Chosen because
# each one is a place a mapping mistake would show: Deut 6:4 and Ps 23:1
# for the divine name, Ps 3:1 for the ASV superscription that lives
# inside `<cite>`, John 1:1 for the Greek.
SPOT_CHECKS = [
    ('Deuteronomy', 6, 4),
    ('Psalms', 3, 1),
    ('Psalms', 23, 1),
    ('John', 1, 1),
]


def clean(raw):
    """Source `text` markup → the plain string this app stores.

    Returns (text, leftover_tags). Leftovers are returned rather than
    stripped: a tag this mapping does not know about is a fact about the
    source that the operator has to see, and silently deleting it is how
    `<WTV) PAPGP>` would have shipped inside a verse.
    """
    s = DROP_WITH_CONTENT.sub('', raw)
    s = DROP_TAG_ONLY.sub('', s)
    leftover = ANY_TAG.findall(s)
    return re.sub(r'\s+', ' ', s).strip(), leftover


def classify(pending):
    """-> (the run's own number, the numbers it only implies).

    The `x` suffix is the source's own statement that the lemma has no
    English word here, so it never becomes `s` however few numbers the
    run has. A run whose tags are ALL `x` therefore carries no `s` at
    all, which is the honest reading: whatever word is in that run is
    not what those numbers render.
    """
    real = [n for n, x in pending if not x]
    implied = [n for n, x in pending if x]
    return (real[0] if real else ''), real[1:] + implied


def split_runs(s, code, ref):
    """A cleaned verse with its Strong's tags still in it → runs.

    `s` has already had DROP_WITH_CONTENT applied, so no footnote body
    can reach a run and inherit the number of the word it interrupted —
    the defect `scripture_markup.dart` records for the Septuagint's
    `(102:12)` markers, 4,400 of which took the number they were glued
    to. This app drops footnotes from the reading text entirely (see the
    header), so unlike the SeekSparks importer there is no note run to
    emit; there is nothing left to emit one for.
    """
    out, cursor, pending = [], 0, []

    def strip(seg):
        return DROP_TAG_ONLY_KEEPING_STRONGS.sub('', seg)

    for m in STRONGS.finditer(s):
        seg = strip(s[cursor:m.start()])
        cursor = m.end()
        number = int(m.group(2))
        if number > MAX_STRONGS[m.group(1)]:
            sys.exit(f'{code} {ref}: {m.group(1)}{number} is above the '
                     "Strong's ceiling — this source has grown a "
                     'placeholder band, adjudicate it before importing')
        pending.append((f'{m.group(1)}{number}', m.group(3) == 'x'))
        if seg == '' and STRONGS.match(s, cursor):
            # Consecutive tags govern the one run between them; collect
            # the numbers rather than emit a run with no text.
            continue
        strongs, implied = classify(pending)
        pending = []
        if seg == '' and out:
            if strongs:
                out[-1]['i'].append(strongs)
            out[-1]['i'].extend(implied)
            continue
        out.append({'w': seg, 's': strongs, 'i': implied})

    tail = strip(s[cursor:])
    if tail:
        if pending:
            strongs, implied = classify(pending)
            out.append({'w': tail, 's': strongs, 'i': implied})
        elif out:
            out[-1]['w'] += tail
        else:
            out.append({'w': tail, 's': '', 'i': []})
    elif pending:
        strongs, implied = classify(pending)
        if out:
            if strongs:
                out[-1]['i'].append(strongs)
            out[-1]['i'].extend(implied)
        else:
            out.append({'w': '', 's': strongs, 'i': implied})
    return out


_WS = re.compile(r'\s')


def collapse_runs(runs):
    """`re.sub(r'\\s+', ' ', …).strip()`, applied ACROSS the run boundaries.

    `clean()` normalises the whole verse in one call, so a run pass that
    normalised each run on its own would leave a doubled space wherever
    the tagger happened to cut between two whitespace characters, and the
    runs would then no longer concatenate to the text this app ships.
    Streaming the same rule with one bit of carried state — "was the last
    character emitted a space" — reproduces it exactly.
    """
    out, last_was_space = [], True   # True so leading space is dropped
    for r in runs:
        buf = []
        for ch in r['w']:
            if _WS.match(ch):
                if last_was_space:
                    continue
                buf.append(' ')
                last_was_space = True
            else:
                buf.append(ch)
                last_was_space = False
        out.append({**r, 'w': ''.join(buf)})
    # `.strip()`'s trailing half: walk back over runs that are now empty
    # or all space.
    for r in reversed(out):
        r['w'] = r['w'].rstrip(' ')
        if r['w']:
            break
    return out


def fold_empty_runs(runs):
    """Drop runs with no text, keeping their numbers.

    A run can lose its text three ways — it was whitespace the collapse
    above ate, it was a `<cite>`/`<i>` tag and nothing else, or the
    tagger cut twice in the same place. Its numbers are still a fact
    about the verse, so they move to the run in front as IMPLIED: they
    are numbers the original has that no English word here renders,
    which is exactly what `TaggedRun.i` means.

    A leading empty run has no run in front and its numbers move to the
    run behind instead. Dropping them silently would lose a lemma; the
    count is reported either way.
    """
    out = []
    orphaned = []
    for r in runs:
        if r['w']:
            if orphaned:
                r = {**r, 'i': orphaned + r['i']}
                orphaned = []
            out.append(r)
            continue
        if r['s']:
            if out:
                out[-1]['i'].append(r['s'])
            else:
                orphaned.append(r['s'])
        if out:
            out[-1]['i'].extend(r['i'])
        else:
            orphaned.extend(r['i'])
    if orphaned and out:
        out[0] = {**out[0], 'i': orphaned + out[0]['i']}
    return out


def encode_runs(runs):
    """The on-disk shape: `i` omitted when empty, no `g` at all.

    `assets/tagged/cuvs-yhwh/` omits an empty `i`/`g` and
    `TaggedRun.fromJson` defaults both, so this matches its neighbour
    rather than carrying an empty array on every run. `g` is never
    written: neither module carries a tense/voice/mood code anywhere, and
    an empty list would claim the question was asked and came back empty.
    """
    out = []
    for r in runs:
        row = {'w': r['w'], 's': r['s']}
        if r['i']:
            row['i'] = r['i']
        out.append(row)
    return out


def tagged_verse(raw, code, ref, body):
    """Runs for one verse, checked against the text this app ships.

    `body` is what `clean()` produced for the same source string, after
    the one hand-named repair — the exact characters that go into
    `assets/<code>.json`. The runs must concatenate to it. That single
    equality is what makes the layer safe to render INSTEAD of the verse,
    which is what the Exegesis sheet does with it.
    """
    s = DROP_WITH_CONTENT.sub('', raw)
    runs = fold_empty_runs(collapse_runs(split_runs(s, code, ref)))
    if code in REPAIR_STRAY_CLOSER and runs:
        # ASV John 8:11's orphaned `]]`, removed from the tail run the
        # same way `build` removes it from the verse. Not a general rule
        # here either: see the note on REPAIR_STRAY_CLOSER.
        runs[-1] = {**runs[-1], 'w': STRAY_CLOSER.sub('', runs[-1]['w'])}
        runs = [r for r in runs if r['w']] or runs[:1]
        runs[-1] = {**runs[-1], 'w': runs[-1]['w'].rstrip()}
    joined = ''.join(r['w'] for r in runs)
    if joined != body:
        sys.exit(f'{code} {ref}: the runs do not reproduce the verse\n'
                 f'  runs : {joined!r}\n'
                 f'  text : {body!r}')
    return runs


def load_books(db):
    """(seq, source code, English name) for all 66, in canonical order.

    The English name is what goes in the `book` field. Every bundled
    English asset in this repo keys books that way and
    `bookNameToEnglish` maps them to themselves, which is what keeps a
    highlight on John 3:16 attached to John 3:16 after a version switch.
    The Greek texts use it too — a Greek book-name column exists nowhere
    in this app, and inventing one would detach every note taken in the
    WH from the same verse in every other edition.
    """
    return list(db.execute(
        'SELECT seq, code, name_en FROM books ORDER BY seq'))


def build(db, text, check=False, tagged=False):
    books = load_books(db)
    seq_of = {code: seq for seq, code, _name in books}
    name_of = {code: name for _seq, code, name in books}

    rows = list(db.execute(
        'SELECT book, chapter, verse, text, plain FROM verses '
        'WHERE version = ? ORDER BY book, chapter, verse', (text.source,)))
    if len(rows) != text.verses:
        sys.exit(f'{text.code}: source has {len(rows)} verses, '
                 f'expected {text.verses}')

    out, empties, leftovers, repairs, diffs = [], 0, set(), [], []
    layer = {}   # english book -> {"chapter:verse": [run, ...]}
    for book, chapter, verse, raw, plain in rows:
        body, left = clean(raw)
        leftovers.update(left)
        if not body:
            empties += 1
            continue
        mended = (STRAY_CLOSER.sub('', body).strip()
                  if text.code in REPAIR_STRAY_CLOSER else body)
        if mended != body:
            repairs.append(f'{name_of[book]} {chapter}:{verse}')
            body = mended
        if body != re.sub(r'\s+', ' ', plain).strip():
            diffs.append((name_of[book], chapter, verse, plain, body))
        out.append({
            'book': name_of[book],
            'chapter': str(chapter),
            'verse': str(verse),
            'text': body,
            'id': f'{seq_of[book]:03d}{chapter:03d}{verse:03d}',
        })
        if tagged:
            ref = f'{chapter}:{verse}'
            layer.setdefault(name_of[book], {})[ref] = tagged_verse(
                raw, text.code, f'{name_of[book]} {ref}', body)

    # Everything below refuses to write rather than warning. A Bible
    # asset that is subtly wrong is worse than one that is missing: the
    # missing one gets noticed.
    if leftovers:
        sys.exit(f'{text.code}: unhandled markup {sorted(leftovers)} — '
                 'refusing to write a file with tags in it')
    if empties != text.empty:
        sys.exit(f'{text.code}: {empties} empty verses, expected '
                 f'{text.empty}')
    if len(out) != text.expected_records:
        sys.exit(f'{text.code}: {len(out)} records, expected '
                 f'{text.expected_records}')
    seen_books = {r['book'] for r in out}
    if len(seen_books) != text.books:
        sys.exit(f'{text.code}: {len(seen_books)} books, expected '
                 f'{text.books}')
    if len(repairs) != EXPECTED_REPAIRS.get(text.code, 0):
        sys.exit(f'{text.code}: repaired {len(repairs)} verses '
                 f'({repairs}), expected '
                 f'{EXPECTED_REPAIRS.get(text.code, 0)}')
    expected_diffs = PLAIN_DIFFS.get(text.code)
    if expected_diffs is not None and len(diffs) != expected_diffs:
        sys.exit(f'{text.code}: differs from the export\'s own `plain` in '
                 f'{len(diffs)} verses, expected {expected_diffs} — read '
                 f'the first few with --check before changing this number')
    if len({r['id'] for r in out}) != len(out):
        sys.exit(f'{text.code}: duplicate verse ids')

    if tagged:
        counted = {
            'verses': sum(len(b) for b in layer.values()),
            'runs': sum(len(r) for b in layer.values() for r in b.values()),
            'numbered': sum(1 for b in layer.values() for r in b.values()
                            for x in r if x['s']),
            'implied': sum(len(x['i']) for b in layer.values()
                           for r in b.values() for x in r),
        }
        expected = TAGGED_EXPECTED.get(text.code)
        if expected is not None and counted != expected:
            sys.exit(f'{text.code}: tagged layer measures {counted}, '
                     f'expected {expected} — read the difference before '
                     'changing TAGGED_EXPECTED')
        print(f'  tagged layer             : {counted}')

    if check:
        print(f'  repaired                 : {repairs or "none"}')
        print(f'  disagrees with `plain` in: {len(diffs)} verses')
        for bk, c, v, plain, body in diffs[:3]:
            print(f'    {bk} {c}:{v}')
            print(f'      plain: {plain[:100]}')
            print(f'      here : {body[:100]}')
        named = sum(1 for r in out if 'Yahweh' in r['text'])
        print(f'  verses reading Yahweh    : {named}')
    return out, layer


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('codes', nargs='*', help='texts to build')
    ap.add_argument('--all', action='store_true',
                    help='every text in TEXTS, including the two this app '
                         'does not offer')
    ap.add_argument('--list', action='store_true')
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('--check', action='store_true',
                    help='print the `plain` disagreements and the divine-'
                         'name census')
    ap.add_argument('--tagged', action='store_true',
                    help='build `assets/tagged/<code>/` instead of the '
                         'reading asset — see TAGGED')
    ap.add_argument('--db', default=SOURCE_DB)
    args = ap.parse_args()

    if args.list:
        for t in TEXTS:
            mark = 'shipped' if t.code in SHIPPED else 'NOT shipped'
            print(f'{t.code:<10} {t.source:<7} {t.expected_records:>6} '
                  f'records  [{mark}]')
            print(f'           {t.note}')
        return

    codes = list(BY_CODE) if args.all else args.codes
    if not codes:
        sys.exit('nothing to do — pass some codes, --all or --list')
    unknown = [c for c in codes if c not in BY_CODE]
    if unknown:
        sys.exit(f'unknown text(s): {unknown}')
    if args.tagged:
        untagged = [c for c in codes if c not in TAGGED]
        if untagged:
            sys.exit(f'--tagged: {untagged} has no tagged layer here — '
                     f'only {sorted(TAGGED)} do, and the reason each other '
                     'text does not is in the note on TAGGED')
    if not os.path.isfile(args.db):
        sys.exit(f'{args.db}: not found — run Yahwehdehua/tools/'
                 'export-app-db.py to produce it')

    db = sqlite3.connect(f'file:{args.db}?mode=ro', uri=True)
    for code in codes:
        text = BY_CODE[code]
        print(f'{code} (source `{text.source}`)')
        out, layer = build(db, text, check=args.check, tagged=args.tagged)
        print(f'  records                  : {len(out)}')
        by_ref = {(r['book'], r['chapter'], r['verse']): r['text']
                  for r in out}
        for bk, c, v in SPOT_CHECKS:
            body = by_ref.get((bk, str(c), str(v)))
            if body is not None:
                print(f'  {bk} {c}:{v}: {body[:80]}')

        if args.tagged:
            # The reading asset is NOT rewritten here, and it is not
            # merely left alone either: the freshly-built records are
            # compared against the shipped file byte for byte. The whole
            # value of this layer is that the runs concatenate to the
            # verse a reader sees, and that claim is only worth
            # something if the verse this pass checked against is the
            # verse that ships.
            shipped_path = os.path.join(ASSETS, f'{code}.json')
            with io.open(shipped_path, encoding='utf-8') as f:
                shipped = f.read()
            fresh = json.dumps(out, ensure_ascii=False,
                               separators=(',', ':'))
            if fresh != shipped:
                sys.exit(f'  {code}: this run rebuilds `{shipped_path}` '
                         'differently from the file on disk. The tagged '
                         'layer would be checked against a verse nobody '
                         'reads. Reconcile the reading asset first.')
            print(f'  reading asset            : matches {shipped_path}')
            if args.dry_run:
                print('  dry run — nothing written')
                continue
            out_dir = os.path.join(ASSETS, 'tagged', code)
            os.makedirs(out_dir, exist_ok=True)
            total = 0
            for english_book, verses in layer.items():
                path = os.path.join(
                    out_dir, english_book.lower().replace(' ', '_') + '.json')
                with io.open(path, 'w', encoding='utf-8') as f:
                    json.dump(verses, f, ensure_ascii=False,
                              separators=(',', ':'))
                total += os.path.getsize(path)
            print(f'  wrote                    : {len(layer)} files to '
                  f'{out_dir} ({total / 1e6:.1f} MB)')
            continue

        if args.dry_run:
            print('  dry run — nothing written')
            continue
        if code not in SHIPPED:
            print(f'  NOT in SHIPPED — writing anyway, but nothing in '
                  f'lib/ will load it. {text.note}')
        path = os.path.join(ASSETS, f'{code}.json')
        with io.open(path, 'w', encoding='utf-8') as f:
            json.dump(out, f, ensure_ascii=False, separators=(',', ':'))
        print(f'  wrote                    : {path} '
              f'({os.path.getsize(path) / 1e6:.1f} MB)')


if __name__ == '__main__':
    main()
