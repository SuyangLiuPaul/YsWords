#!/usr/bin/env python3
"""Tests for `scripts/sync_sermon_library.py`.

Run:
    python3 -m unittest discover -s test -p 'test_*.py' -v
    python3 test/test_sermon_library.py            # same thing

stdlib `unittest` on purpose: this repo has no pytest and no Python test
infrastructure, and an importer's tests should not be the thing that
adds a dependency to CI.

Two kinds of test live here.

1. GUARD TESTS. Every guard gets a test that feeds it deliberately
   broken input and asserts it fires, plus a test that feeds it good
   input and asserts it stays quiet. These are the tests that were
   mutation-checked: each guard was broken in turn and the mapped test
   was confirmed to fail. A guard no test can make fail is decorative.

2. SNAPSHOT TESTS. Assertions about the committed
   `assets/sermon_library/index.json`, so a bad regeneration is caught
   even if the guards were bypassed. These skip (not fail) when the
   snapshot is absent, so a fresh clone that has not run the sync yet
   still gets a green guard suite.
"""

import contextlib
import importlib.util
import io
import json
import os
import re
import unittest
import urllib.error
import urllib.request

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(REPO, 'scripts', 'sync_sermon_library.py')
INDEX = os.path.join(REPO, 'assets', 'sermon_library', 'index.json')

_spec = importlib.util.spec_from_file_location('sync_sermon_library', SCRIPT)
sl = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(sl)


# ── Fixtures ──────────────────────────────────────────────────────
#
# The fixture corpus has to be a REALISTIC corpus, not merely a
# well-formed one. The version of this file that shipped on 2026-09-05
# gave every record the same body string and the same audio attachment
# id, which is a degenerate corpus — and a degenerate corpus cannot
# exercise a distinctness guard, because it fails one. That fixture is
# part of why the substitution attacks were never noticed.
#
# So: bodies are unique per record and sized to the measured mean
# (6,469 characters over the real 843), and audio ids are unique per
# record, matching the measured 739-distinct-of-739.

# Measured against assets/sermon_library/ on 2026-09-06 and quoted here
# as LITERALS on purpose. The snapshot floors used to be asserted
# against `sl.MIN_BODIED`, which is the same constant on both sides of
# the comparison: setting MIN_BODIED to 1 left the whole suite green.
# A floor must be checked against a number measured from the data, not
# against itself.
# Re-measured 2026-09-06 after the 16 audio-only sermons by Pastor Eric
# Chang were transcribed. Every number below was read off the data before
# it was changed here, not adjusted until the suite went quiet.
#
# 2026-09-07: the index and the directory agree again, at 859. They
# disagreed for one day. `bodies/6012.txt` (ws01, 活着就是基督) was
# written but its `hasBody` deliberately not set, because 6012 is the
# same sermon as app CP37 and flipping it would have shipped that sermon
# twice — the adjudication row said `refuted`, so the merge would have
# taken 6012 down the NEW-record path.
#
# That row said `refuted` only because there was no library body to
# check the identity against, and transcribing 6012 produced one. The
# owner then chose which text the corpus should carry — CP37's Chinese
# is a machine translation of the English camp recording, 6012's a
# machine transcript of the Chinese radio delivery, so no rule could
# choose for them — and took the library's. The row is now
# `confirmed`/`library-fuller`, the merge REPLACES CP37's Chinese
# instead of adding a record, and the app corpus stays at 429.
#
# So every number here is +16 now, and 6012 is no longer an orphan.
MEASURED = {
    'records': 940,
    'bodyFiles': 859,
    'bodied200': 856,
    'withAudio': 673,
    # 5_541_718 after proofreading pass 1 on 2026-09-06: 62 misheard book
    # names corrected (格林多→哥林多, 加勒泰→加拉太, 菲利比→腓立比,
    # 西伯来→希伯来, 民俗记→民数记 and the rest), a 14-fold
    # hallucinated phone advert replaced by one note recording that
    # ~28 s of audio decoded to nothing, and four fabricated
    # subtitle credits removed — those named real people who did no
    # such work, which is the worst kind of invention because it
    # reads exactly like a real credit.
    #
    # 5_541_703 after pass 2, the same day: 687 more corrections over the
    # same sixteen files, found by READING them rather than by any check.
    # The number moved by FIFTEEN characters, which is the useful part of
    # this line — a mishearing is overwhelmingly a same-length homophone
    # (作亡 for 作王, 畫餅 for 話柄, 精力 for 經歷), so a volume snapshot is
    # blind to almost all of them. Nothing that watches size can watch
    # this class of defect, and nothing did: see
    # `scripts/proofread_transcripts.py`, which is where they now live so
    # that a `--force` rebuild reproduces them instead of discarding them.
    #
    # 5_542_483 on 2026-09-07, and the arithmetic is the whole reason
    # this line is allowed to move: the head-of-body note was rewritten
    # to state the proofreading it had been denying, which lengthens
    # EVERY machine-transcribed body by exactly 52 characters. Fifteen
    # such bodies are counted here — the sixteenth, 6012/ws01, is held
    # back and carries no `bodyChars` — so 15 x 52 = 780, and
    # 5_541_703 + 780 = 5_542_483. Not one character of sermon text
    # moved; verified separately by diffing all fifteen against the
    # shipped copies, which matched except for the deliberate
    # 耶和华 → 雅伟 the merge applies downstream.
    'bodyChars': 5_559_159,
    'distinctBodies': 857,
    'maxSameBody': 2,
    'distinctTitles': 933,
    'distinctUrls': 938,
    'distinctSlugs': 940,
    'audioRefs': 739,
    'distinctAudio': 739,
    'authors': 71,
    'suspectDates': [2967],
}

_BODY_CACHE = {}


def _body_for(mid):
    """A unique body, cached because it is immutable.

    Sized so that MIN_RECORDS of them clear MIN_BODY_CHARS even when 97
    are body-less, as in the real corpus — roughly the measured
    6,469-character mean. A fixture that cannot clear the corpus's own
    character floor is not a fixture for this pipeline.
    """
    if mid not in _BODY_CACHE:
        _BODY_CACHE[mid] = (f'第{mid}讲，本篇讲道的开头是独一无二的。'
                            + f'这是第{mid}篇的正文内容，' * 460)
    return _BODY_CACHE[mid]


class _Media(dict):
    """Resolves any attachment id to its own distinct URL.

    A plain dict would hand every record the same URL, which is
    attack #7 baked into the fixture.
    """

    def get(self, key, default=None):
        if key not in self and isinstance(key, int):
            self[key] = {
                'url': f'https://fuyindiantai.org/wp-content/uploads/'
                       f'{key}.mp3',
                'mime': 'audio/mpeg'}
        return dict.get(self, key, default)


def make_message(mid, body=None, author_terms=(1,),
                 author_simple='', audio=None, book=(100,),
                 date='2020-01-01T00:00:00'):
    """One API-shaped `message` record.

    `body=None` means "a realistic unique body"; `body=''` still means
    "this record legitimately has no transcript".
    """
    if body is None:
        body = _body_for(mid)
    if audio is None:
        audio = (700_000 + mid,)
    return {
        'id': mid,
        'slug': f'slug-{mid}',
        'link': f'https://fuyindiantai.org/message/slug-{mid}/',
        'title': {'rendered': f'讲道 {mid}'},
        'date': date,
        'modified': '2020-01-02T00:00:00',
        'content': {'rendered': ''},
        'content_author': list(author_terms),
        'zhuantixilie': [],
        'shujuanchakao': list(book),
        'shengjingyishenlun': [],
        'qimiaoendian': [],
        'shengmingzaisi': [],
        'jiangdaoxinxi': [],
        'acf': {
            'refcode': f'RC{mid}',
            'author_simple': author_simple,
            'transcription_displayed': f'<p>{body}</p>' if body else '',
            'audio_recording_mp3': [{'mp3_recording': a} for a in audio],
            'transcription_doc_pdf': None,
            'mobile_version_transcript': None,
            'video': None,
        },
    }


TERMS = {
    'content_author': {1: {'name': '张成牧师', 'slug': 'zc', 'count': 1},
                       2: {'name': '奇妙恩典', 'slug': 'qmed', 'count': 1}},
    'zhuantixilie': {},
    'shujuanchakao': {100: {'name': '马太福音', 'slug': 'mt', 'count': 1}},
    'shengjingyishenlun': {},
    'qimiaoendian': {},
    'shengmingzaisi': {},
    'jiangdaoxinxi': {},
}

MEDIA = _Media({
    10: {'url': 'https://fuyindiantai.org/wp-content/uploads/a.mp3',
         'mime': 'audio/mpeg'},
    11: {'url': 'https://fuyindiantai.org/wp-content/uploads/b.mp3',
         'mime': 'audio/mpeg'}})


def rows_from(messages, terms=None, media=None):
    rows, _ = sl.build_records(messages, terms or TERMS, media or MEDIA)
    return rows


def parts_from(messages, terms=None, media=None):
    """(rows, bodies) — what `run_guards` needs."""
    return sl.build_records(messages, terms or TERMS, media or MEDIA)


def good_corpus(n=None):
    """A corpus that clears every floor AND every ceiling."""
    n = n or sl.MIN_RECORDS
    return [make_message(1000 + i) for i in range(n)]


def guards_on(messages, existing=None, terms=None, media=None):
    rows, bodies = parts_from(messages, terms, media)
    return sl.run_guards(messages, rows, bodies, terms or TERMS,
                         existing if existing is not None else [])


# ── Transform ─────────────────────────────────────────────────────

class TestBodyText(unittest.TestCase):

    def test_one_line_per_source_paragraph(self):
        html = '<p>第一段</p>\r\n<p>第二段</p>'
        self.assertEqual(sl.body_text(html), '第一段\n第二段')

    def test_does_not_invent_paragraph_breaks(self):
        """A single long paragraph must come out as ONE line.

        The app's rule for the other sermon corpus is that nothing
        re-paragraphs another man's sermon; this pins it here.
        """
        html = '<p>' + ('句子。' * 300) + '</p>'
        self.assertEqual(len(sl.body_text(html).split('\n')), 1)

    def test_strips_tags_and_decodes_entities(self):
        html = '<p><span style="x"><strong>a</strong>&amp;b</span></p>'
        self.assertEqual(sl.body_text(html), 'a&b')

    def test_empty_inputs(self):
        for v in ('', None, '   ', False, 0, []):
            self.assertEqual(sl.body_text(v), '')


class TestCleanTitle(unittest.TestCase):
    """Direct tests for `clean_title`.

    These exist because of a mutation result: breaking the entity
    decoding was originally SURVIVED by the whole suite. The only test
    that looked like it covered this asserted over the COMMITTED
    snapshot, which was generated by correct code and therefore stays
    green no matter what the code later does. A snapshot assertion
    cannot catch a code regression — it needs a unit test underneath it.
    """

    def test_decodes_html_entities(self):
        """7 of the 940 upstream titles carry entities."""
        self.assertEqual(sl.clean_title('&#8220;a&#8221;'), '\u201ca\u201d')
        self.assertEqual(sl.clean_title('a &amp; b'), 'a & b')

    def test_strips_tags(self):
        self.assertEqual(sl.clean_title('<em>论舌头</em>'), '论舌头')

    def test_collapses_whitespace(self):
        self.assertEqual(sl.clean_title('  a \n\t b  '), 'a b')

    def test_blank_becomes_none(self):
        for v in ('', '   ', None, '<em></em>'):
            self.assertIsNone(sl.clean_title(v))


class TestAuthorAttribution(unittest.TestCase):

    def test_taxonomy_wins(self):
        m = make_message(1, author_terms=(1,), author_simple='其他人')
        self.assertEqual(sl.resolve_author(m, TERMS),
                         ('张成牧师', 'taxonomy', 'person'))

    def test_legacy_fallback_when_no_term(self):
        m = make_message(1, author_terms=(), author_simple='凉水')
        self.assertEqual(sl.resolve_author(m, TERMS),
                         ('凉水', 'legacy_field', 'person'))

    def test_numeric_legacy_value_is_refused(self):
        """"9" / "3" / "10" are stale term ids, not names."""
        m = make_message(1, author_terms=(), author_simple='9')
        self.assertEqual(sl.resolve_author(m, TERMS), (None, 'none', None))

    def test_unattributed_is_none_not_placeholder(self):
        m = make_message(1, author_terms=(), author_simple='')
        name, source, kind = sl.resolve_author(m, TERMS)
        self.assertIsNone(name)
        self.assertEqual(source, 'none')
        self.assertNotIn(name, ('', '未知', '福音电台'))

    def test_programme_author_flagged_not_person(self):
        m = make_message(1, author_terms=(2,))
        self.assertEqual(sl.resolve_author(m, TERMS),
                         ('奇妙恩典', 'taxonomy', 'programme'))


class TestBuildRecords(unittest.TestCase):

    def test_shape_and_fields(self):
        rows = rows_from([make_message(1)])
        self.assertEqual(tuple(rows[0].keys()), sl.FIELD_ORDER)

    def test_multi_part_audio_is_a_list(self):
        """44 real records carry more than one mp3."""
        rows = rows_from([make_message(1, audio=(10, 11))])
        self.assertEqual(len(rows[0]['audioUrls']), 2)

    def test_bodyless_record_is_kept_not_dropped(self):
        """Ruling: a body-less record is emitted, not skipped."""
        rows = rows_from([make_message(1, body='')])
        self.assertEqual(len(rows), 1)
        self.assertFalse(rows[0]['hasBody'])
        self.assertIsNone(rows[0]['bodyFile'])
        self.assertEqual(rows[0]['title'], '讲道 1')

    def test_book_reference_resolved(self):
        self.assertEqual(rows_from([make_message(1)])[0]['book'], '马太福音')


# ── Guards ────────────────────────────────────────────────────────

class TestGuardStructural(unittest.TestCase):
    """The guard that separates 'no transcript' from 'field renamed'."""

    def test_quiet_on_good_input(self):
        self.assertEqual(sl.guard_structural(good_corpus(3)), [])

    def test_quiet_when_body_merely_empty(self):
        """97 real records are legitimately body-less. Not a failure."""
        msgs = [make_message(1, body=''), make_message(2, body='')]
        self.assertEqual(sl.guard_structural(msgs), [])

    def test_fires_when_acf_object_missing(self):
        msgs = good_corpus(3)
        msgs[0]['acf'] = None
        self.assertTrue(sl.guard_structural(msgs))

    def test_fires_when_body_key_renamed(self):
        msgs = good_corpus(3)
        del msgs[1]['acf']['transcription_displayed']
        fails = sl.guard_structural(msgs)
        self.assertTrue(fails)
        self.assertIn('transcription_displayed', fails[0])


class TestGuardFloors(unittest.TestCase):

    def test_quiet_on_good_input(self):
        self.assertEqual(sl.guard_floors(rows_from(good_corpus())), [])

    def test_fires_on_short_crawl(self):
        rows = rows_from(good_corpus(sl.MIN_RECORDS - 1))
        self.assertTrue(any('records' in f for f in sl.guard_floors(rows)))

    def test_fires_when_bodies_stop_rendering(self):
        msgs = good_corpus()
        for m in msgs[:sl.MIN_RECORDS - sl.MIN_BODIED + 1]:
            m['acf']['transcription_displayed'] = ''
        self.assertTrue(any('body' in f for f in
                            sl.guard_floors(rows_from(msgs))))

    def test_fires_when_audio_resolution_fails(self):
        """Attachment lookup returning nothing must not write silently."""
        rows, _ = sl.build_records(good_corpus(), TERMS, {})
        self.assertTrue(any('audio' in f for f in sl.guard_floors(rows)))


class TestGuardHosts(unittest.TestCase):

    def test_quiet_on_both_real_hosts(self):
        rows = rows_from(good_corpus(2))
        rows[0]['url'] = 'https://fydt.org/message/x/'
        self.assertEqual(sl.guard_hosts(rows), [])

    def test_fires_on_foreign_host(self):
        rows = rows_from(good_corpus(2))
        rows[0]['url'] = 'https://evil.example.com/message/x/'
        self.assertTrue(sl.guard_hosts(rows))

    def test_fires_on_foreign_media_host(self):
        rows = rows_from(good_corpus(2))
        rows[0]['audioUrls'] = ['https://cdn.example.net/a.mp3']
        self.assertTrue(sl.guard_hosts(rows))


class TestGuardIdentity(unittest.TestCase):

    def test_quiet_on_good_input(self):
        self.assertEqual(sl.guard_identity(rows_from(good_corpus(5))), [])

    def test_fires_on_duplicate_ids(self):
        rows = rows_from([make_message(1), make_message(1)])
        self.assertTrue(any('duplicate' in f
                            for f in sl.guard_identity(rows)))

    def test_fires_on_missing_title(self):
        rows = rows_from(good_corpus(3))
        rows[0]['title'] = None
        self.assertTrue(any('title' in f for f in sl.guard_identity(rows)))


class TestGuardUnresolvedTerms(unittest.TestCase):

    def test_quiet_on_good_input(self):
        self.assertEqual(sl.guard_unresolved_terms(good_corpus(3), TERMS), [])

    def test_fires_when_term_fetch_truncated(self):
        """A short taxonomy fetch would otherwise blank authors silently."""
        terms = {k: dict(v) for k, v in TERMS.items()}
        terms['content_author'] = {}
        fails = sl.guard_unresolved_terms(good_corpus(3), terms)
        self.assertTrue(any('content_author' in f for f in fails))


class TestGuardAuthorCollapse(unittest.TestCase):

    def test_quiet_without_previous_snapshot(self):
        self.assertEqual(
            sl.guard_author_collapse(rows_from(good_corpus(3)), []), [])

    def test_quiet_when_stable(self):
        rows = rows_from(good_corpus(20))
        self.assertEqual(sl.guard_author_collapse(rows, rows), [])

    def test_fires_when_author_halves(self):
        before = rows_from(good_corpus(20))
        after = rows_from(good_corpus(9))
        self.assertTrue(sl.guard_author_collapse(after, before))

    def test_fires_when_author_disappears_at_any_size(self):
        before = rows_from([make_message(1, author_terms=(2,))])
        after = rows_from([make_message(1, author_terms=(1,))])
        fails = sl.guard_author_collapse(after, before)
        self.assertTrue(any('奇妙恩典' in f for f in fails))


# ── The guards added on 2026-09-06 ────────────────────────────────
#
# Each of the eight attacks below WROTE A SNAPSHOT WITH EXIT 0 against
# the real 940-record corpus before these guards existed. The numbers in
# the docstrings are the measured results of those runs, not estimates.

class TestGuardCeiling(unittest.TestCase):
    """Attack 3: every record five times over under fresh ids — 4,700
    rows, and there was no ceiling of any kind."""

    def test_quiet_on_good_input(self):
        rows = rows_from(good_corpus())
        self.assertEqual(sl.guard_ceiling(rows, rows), [])

    def test_quiet_without_previous_snapshot(self):
        self.assertEqual(sl.guard_ceiling(rows_from(good_corpus(10)), []), [])

    def test_fires_above_the_absolute_ceiling(self):
        rows = rows_from(good_corpus(sl.MAX_RECORDS + 1))
        self.assertTrue(any('ceiling' in f for f in sl.guard_ceiling(rows, [])))

    def test_fires_on_sudden_growth_under_the_absolute(self):
        """1002 rows against a 940 snapshot is under MAX_RECORDS but is
        still not one sync's worth of new sermons."""
        before = rows_from(good_corpus(300))
        after = rows_from(good_corpus(400))
        self.assertTrue(any('growth' in f
                            for f in sl.guard_ceiling(after, before)))

    def test_growth_clause_also_watches_the_bodied_count(self):
        """This is what catches the chrome substitution from the ceiling
        side: it drove withBody from the true 841 to 940."""
        before = rows_from([make_message(i, body='') for i in range(1000, 1100)]
                           + good_corpus(100))
        after = rows_from(good_corpus(200))
        self.assertTrue(any('bodied' in f
                            for f in sl.guard_ceiling(after, before)))

    def test_growth_clause_also_watches_the_audio_count(self):
        before = rows_from([make_message(1000 + i, audio=())
                            for i in range(100)] + good_corpus(100))
        after = rows_from(good_corpus(200))
        self.assertTrue(any('audio' in f
                            for f in sl.guard_ceiling(after, before)))

    def test_ceiling_is_not_a_barn_door(self):
        """The import-time assert that keeps the band meaningful."""
        self.assertLessEqual(sl.MAX_RECORDS, sl.MIN_RECORDS * 1.15)
        self.assertGreater(sl.MAX_RECORDS, sl.MIN_RECORDS)


class TestGuardBodySubstitution(unittest.TestCase):
    """Attack 1, the one this whole pass exists for.

    Replacing every body with the SAME >=200-character navigation string
    took the corpus from 5,440,652 characters to 555,540 and from 840
    distinct first lines to 1 — while `_meta.withBody` rose from the true
    841 to 940, because chrome clears a length bar as easily as a sermon
    does. Every count guard read that as an improvement.
    """

    CHROME = '首页 关于我们 讲道信息 联系我们 奉献支持 版权所有 福音电台 ' * 40

    def test_quiet_on_good_input(self):
        rows, bodies = parts_from(good_corpus())
        self.assertEqual(sl.guard_body_substitution(rows, bodies), [])

    def test_quiet_when_a_few_records_have_no_body(self):
        """97 real records are legitimately body-less; empty bodies are
        excluded from the distinctness ratio, not counted as one shared
        value."""
        msgs = good_corpus()
        for m in msgs[:97]:
            m['acf']['transcription_displayed'] = ''
        rows, bodies = parts_from(msgs)
        self.assertEqual(sl.guard_body_substitution(rows, bodies), [])

    def test_fires_when_every_body_is_the_same_chrome_string(self):
        msgs = good_corpus()
        for m in msgs:
            m['acf']['transcription_displayed'] = f'<p>{self.CHROME}</p>'
        rows, bodies = parts_from(msgs)
        fails = sl.guard_body_substitution(rows, bodies)
        self.assertTrue(any('characters of body text' in f for f in fails))
        self.assertTrue(any('distinct body texts' in f for f in fails))
        self.assertTrue(any('shared by' in f for f in fails))

    def test_fires_on_volume_collapse_alone(self):
        """Attack 8: bodies cut to a uniform 200-char stub — still
        `hasBody`, still past the 200-char bar, 32x under the floor."""
        msgs = good_corpus()
        for m in msgs:
            m['acf']['transcription_displayed'] = '<p>' + ('短' * 210) + '</p>'
        rows, bodies = parts_from(msgs)
        self.assertTrue(any('characters of body text' in f
                            for f in sl.guard_body_substitution(rows, bodies)))

    def test_fires_on_a_partial_substitution_the_ratio_would_pass(self):
        """The realistic failure the MAX_SAME_BODY clause is for: a theme
        change makes the scraper return chrome for a handful of the
        newest posts. Nine of 940 is 0.96% — the 0.95 distinctness
        fraction passes it; nine identical transcripts is never real."""
        msgs = good_corpus()
        for m in msgs[:sl.MAX_SAME_BODY + 1]:
            m['acf']['transcription_displayed'] = f'<p>{self.CHROME}</p>'
        rows, bodies = parts_from(msgs)
        fails = sl.guard_body_substitution(rows, bodies)
        self.assertTrue(any('shared by' in f for f in fails), fails)
        self.assertFalse(any('distinct body texts' in f for f in fails),
                         'the fraction should NOT be what catches this')

    def test_compares_whole_bodies_not_first_lines(self):
        """Two sermons that open with the same greeting are not the same
        sermon, and a substitution varying only the first line would walk
        past a first-line rule."""
        msgs = good_corpus(20)
        for m in msgs:
            m['acf']['transcription_displayed'] = (
                '<p>弟兄姊妹平安</p><p>' + m['acf']['refcode'] + '</p>')
        rows, bodies = parts_from(msgs)
        self.assertEqual(len({b.split(chr(10))[0] for b in bodies.values()}), 1)
        self.assertFalse(any('shared by' in f
                             for f in sl.guard_body_substitution(rows, bodies)))


class TestGuardFieldDistinctness(unittest.TestCase):
    """Attacks 4, 5 and 7: every url null, every title identical, every
    audio reference repointed at one file. All three wrote, exit 0."""

    def test_quiet_on_good_input(self):
        self.assertEqual(
            sl.guard_field_distinctness(rows_from(good_corpus())), [])

    def test_quiet_on_the_real_amount_of_duplication(self):
        """933 distinct titles of 940 upstream — real series parts such
        as 约书亚(2) collide, and that must stay legal."""
        msgs = good_corpus()
        for m in msgs[:7]:
            m['title'] = {'rendered': '约书亚'}
        self.assertEqual(sl.guard_field_distinctness(rows_from(msgs)), [])

    def test_fires_when_every_title_is_identical(self):
        rows = rows_from(good_corpus(100))
        for r in rows:
            r['title'] = '讲道'
        self.assertTrue(any('titles' in f
                            for f in sl.guard_field_distinctness(rows)))

    def test_fires_when_every_url_is_identical(self):
        rows = rows_from(good_corpus(100))
        for r in rows:
            r['url'] = 'https://fuyindiantai.org/message/x/'
        self.assertTrue(any('urls' in f
                            for f in sl.guard_field_distinctness(rows)))

    def test_fires_when_every_slug_is_identical(self):
        rows = rows_from(good_corpus(100))
        for r in rows:
            r['slug'] = 'x'
        self.assertTrue(any('slugs' in f
                            for f in sl.guard_field_distinctness(rows)))

    def test_fires_when_all_audio_points_at_one_file(self):
        """739 distinct audio URLs across 739 references upstream — not
        one file is shared by two records."""
        msgs = [make_message(1000 + i, audio=(10,)) for i in range(100)]
        self.assertTrue(any('audio' in f for f in
                            sl.guard_field_distinctness(rows_from(msgs))))


class TestDateSanity(unittest.TestCase):
    """Attack 6: every date corrupt.

    And the standing data defect: record 2967 (约书亚(2)) carries
    `0214-07-02T11:19:11`, a corrupt year upstream. Per the ruling it is
    kept verbatim and flagged, never inferred to 2014.
    """

    def test_accepts_a_real_date(self):
        self.assertTrue(sl.date_is_sane('2014-06-18T22:30:00'))

    def test_rejects_the_corrupt_year_on_record_2967(self):
        """`datetime.fromisoformat` parses this happily, which is exactly
        why the guard does not rely on it."""
        self.assertFalse(sl.date_is_sane('0214-07-02T11:19:11'))
        import datetime as _dt
        self.assertTrue(_dt.datetime.fromisoformat('0214-07-02T11:19:11'))

    def test_rejects_unparseable_and_impossible_dates(self):
        for v in ('0000-00-00T00:00:00', 'not-a-date', '', None,
                  '2020-13-01T00:00:00', '2020-02-30T00:00:00',
                  '2020-01-01', 3):
            self.assertFalse(sl.date_is_sane(v), v)

    def test_rejects_a_year_beyond_next_year(self):
        self.assertFalse(sl.date_is_sane('2999-01-01T00:00:00'))

    def test_guard_quiet_on_good_input(self):
        self.assertEqual(sl.guard_dates(rows_from(good_corpus())), [])

    def test_guard_tolerates_a_handful_of_upstream_typos(self):
        """One today; the limit leaves room for two more before a human
        has to look. Tolerating them is the ruling, not laxity — a run
        that goes red on somebody else's typo stays red forever."""
        msgs = good_corpus(100)
        for m in msgs[:sl.MAX_SUSPECT_DATES]:
            m['date'] = '0214-07-02T11:19:11'
        self.assertEqual(sl.guard_dates(rows_from(msgs)), [])

    def test_guard_fires_when_every_date_is_corrupt(self):
        msgs = good_corpus(100)
        for m in msgs:
            m['date'] = '0000-00-00T00:00:00'
        self.assertTrue(sl.guard_dates(rows_from(msgs)))

    def test_guard_fires_just_past_the_limit(self):
        msgs = good_corpus(100)
        for m in msgs[:sl.MAX_SUSPECT_DATES + 1]:
            m['date'] = 'not-a-date'
        self.assertTrue(sl.guard_dates(rows_from(msgs)))

    def test_suspect_record_is_flagged_and_its_value_kept_verbatim(self):
        """The annotation must never become a correction."""
        rows = rows_from([make_message(2967, date='0214-07-02T11:19:11')])
        self.assertTrue(rows[0]['dateSuspect'])
        self.assertEqual(rows[0]['date'], '0214-07-02T11:19:11')

    def test_sane_record_is_not_flagged(self):
        self.assertFalse(rows_from([make_message(1)])[0]['dateSuspect'])

    def test_meta_lists_the_suspect_ids(self):
        msgs = good_corpus(5)
        msgs[2]['date'] = '0214-07-02T11:19:11'
        rows = rows_from(msgs)
        meta = sl.build_document(rows, TERMS, 'fuyindiantai.org')['_meta']
        self.assertEqual(meta['suspectDates'], [msgs[2]['id']])


class TestGuardHostsMissingUrl(unittest.TestCase):
    """Attack 4, from the other side.

    The host check read `if u and url_host(u) not in ALLOWED_HOSTS`, so
    a null url was not on a foreign host — it was skipped entirely.
    """

    def test_fires_when_a_url_is_missing(self):
        rows = rows_from(good_corpus(3))
        rows[0]['url'] = None
        self.assertTrue(any('no `url`' in f for f in sl.guard_hosts(rows)))

    def test_fires_when_a_url_is_blank(self):
        rows = rows_from(good_corpus(3))
        rows[0]['url'] = '   '
        self.assertTrue(any('no `url`' in f for f in sl.guard_hosts(rows)))

    def test_one_missing_url_is_enough(self):
        """Not a threshold: `link` is present on all 940 upstream."""
        rows = rows_from(good_corpus(940))
        rows[500]['url'] = None
        self.assertTrue(sl.guard_hosts(rows))


# ── run_guards composition ────────────────────────────────────────

class TestRunGuardsComposition(unittest.TestCase):
    """Test the WIRING, not just the guards.

    Measured 2026-09-06 on the version that shipped: any one of the six
    guards could be deleted from `run_guards` — replace its call with
    `[]` — and all 54 tests stayed green. Only deleting all six at once
    went red, and then only via `test_run_guards_aggregates`, which
    exercises `guard_structural` alone. Every other guard was reachable
    by its own unit test and by nothing else.

    So each case below builds input that ONLY ONE guard rejects, and
    asserts `run_guards` still reports it. Delete that guard's line from
    `run_guards` and exactly this case goes red.
    """

    def _isolating_case(self, name):
        """(messages, existing) that only `name` should reject."""
        msgs = good_corpus()
        existing = []
        if name == 'structural':
            msgs[0]['acf'] = None
        elif name == 'unresolved_terms':
            msgs[0]['content_author'] = [999]
        elif name == 'identity':
            msgs[0]['title'] = {'rendered': ''}
        elif name == 'floors':
            for m in msgs[:sl.MIN_RECORDS - sl.MIN_WITH_AUDIO + 1]:
                m['acf']['audio_recording_mp3'] = []
        elif name == 'ceiling':
            msgs = good_corpus(sl.MAX_RECORDS + 1)
        elif name == 'hosts':
            msgs[0]['link'] = 'https://evil.example.com/message/x/'
        elif name == 'body_substitution':
            chrome = '首页 关于我们 讲道信息 联系我们 版权所有 福音电台 ' * 40
            for m in msgs[:sl.MAX_SAME_BODY + 1]:
                m['acf']['transcription_displayed'] = f'<p>{chrome}</p>'
        elif name == 'field_distinctness':
            for m in msgs:
                m['title'] = {'rendered': '讲道'}
        elif name == 'dates':
            for m in msgs[:sl.MAX_SUSPECT_DATES + 1]:
                m['date'] = '0000-00-00T00:00:00'
        elif name == 'author_collapse':
            # Full size on both sides, or the ceiling's growth clause
            # fires too and the case stops isolating anything.
            existing = rows_from(good_corpus()
                                 + [make_message(999999, author_terms=(2,))])
        else:
            self.fail(f'no isolating case written for guard {name!r} — '
                      f'a guard was added to GUARDS without one')
        return msgs, existing

    def test_every_guard_in_the_table_has_an_isolating_case(self):
        """If somebody adds a guard, this fails until they wire a case
        for it, so the composition suite cannot silently fall behind."""
        for name, _fn in sl.GUARDS:
            with self.subTest(guard=name):
                self._isolating_case(name)

    def test_each_guard_is_reachable_through_run_guards(self):
        for name, _fn in sl.GUARDS:
            with self.subTest(guard=name):
                msgs, existing = self._isolating_case(name)
                rows, bodies = parts_from(msgs)
                self.assertTrue(
                    sl.run_guards(msgs, rows, bodies, TERMS, existing),
                    f'input that {name} rejects passed run_guards — the '
                    f'guard is defined but not wired in')

    def test_each_isolating_case_is_isolating(self):
        """A case that trips three guards would keep passing after the
        one it names is deleted, which would make the test above
        decorative. This is the assertion that keeps it honest."""
        for name, _fn in sl.GUARDS:
            with self.subTest(guard=name):
                msgs, existing = self._isolating_case(name)
                rows, bodies = parts_from(msgs)
                ctx = {'messages': msgs, 'rows': rows, 'bodies': bodies,
                       'terms': TERMS, 'existing_rows': existing}
                firing = [g for g, fn in sl.GUARDS if fn(ctx)]
                self.assertEqual(
                    firing, [name],
                    f'case for {name} also trips {set(firing) - {name}}')

    def test_run_guards_calls_every_guard_in_the_table(self):
        """Nothing may be defined in GUARDS and skipped by the loop."""
        called = []
        original = sl.GUARDS
        try:
            sl.GUARDS = tuple(
                (n, (lambda nn, ff: lambda ctx: (called.append(nn), ff(ctx))[1])(n, f))
                for n, f in original)
            msgs = good_corpus(5)
            rows, bodies = parts_from(msgs)
            sl.run_guards(msgs, rows, bodies, TERMS, [])
        finally:
            sl.GUARDS = original
        self.assertEqual(called, [n for n, _ in original])


class TestRunGuards(unittest.TestCase):

    def test_clean_corpus_passes_every_guard(self):
        msgs = good_corpus()
        rows, bodies = parts_from(msgs)
        self.assertEqual(sl.run_guards(msgs, rows, bodies, TERMS, []), [])

    def test_clean_corpus_passes_against_itself_as_previous(self):
        msgs = good_corpus()
        rows, bodies = parts_from(msgs)
        self.assertEqual(sl.run_guards(msgs, rows, bodies, TERMS, rows), [])

    def test_run_guards_aggregates(self):
        msgs = good_corpus(3)
        msgs[0]['acf'] = None
        rows, bodies = parts_from(msgs)
        self.assertTrue(sl.run_guards(msgs, rows, bodies, TERMS, []))


# ── The crawl bound ───────────────────────────────────────────────
#
# `fetch_messages` used to be `while True`, breaking only on a short or
# empty page. Measured 2026-09-06 against a stand-in server that ignores
# `?page=` — an ordinary WordPress/caching behaviour — it issued 201
# requests and was still going when the harness stopped it. The target
# is a church's WordPress install this project has already knocked over
# once with doubled traffic, so this is not a tidiness fix.
#
# Every test here drives a FAKE server. Nothing in this file may ever
# touch fuyindiantai.org or fydt.org.

class _FakeServer:
    """Serves `total` synthetic records, and can be told to misbehave."""

    def __init__(self, total=940, per_page=100, ignore_page=False,
                 headers=True, total_pages=None, drop_key=None,
                 empty_from=None, header_total=None):
        self.total = total
        # What `x-wp-total` claims, when that differs from what the
        # pages actually hold.
        self.header_total = total if header_total is None else header_total
        self.per_page = per_page
        self.ignore_page = ignore_page
        self.headers = headers
        self.total_pages = (total_pages if total_pages is not None
                            else -(-total // per_page))
        self.drop_key = drop_key
        self.empty_from = empty_from
        self.urls = []

    def __call__(self, url, timeout=60):
        self.urls.append(url)
        page = int(re.search(r'[?&]page=(\d+)', url).group(1))
        if self.empty_from is not None and page >= self.empty_from:
            rows = []
        else:
            start = 0 if self.ignore_page else (page - 1) * self.per_page
            rows = []
            for i in range(start, min(start + self.per_page, self.total)):
                r = {'id': 1000 + i, 'title': {'rendered': f'讲道 {i}'},
                     'link': f'https://fuyindiantai.org/message/{i}/',
                     'date': '2020-01-01T00:00:00', 'acf': {}}
                if self.drop_key:
                    r.pop(self.drop_key, None)
                rows.append(r)
        h = {}
        if self.headers:
            h = {'X-WP-Total': str(self.header_total),
                 'X-WP-TotalPages': str(self.total_pages),
                 'Content-Type': 'application/json'}
        return rows, h


class CrawlTestCase(unittest.TestCase):
    """Swaps the network out for a fake server for the duration."""

    def drive(self, server, host='example.invalid'):
        real_json, real_sleep = sl.http_json, sl.time.sleep
        sl.http_json = server
        sl.time.sleep = lambda _s: None
        try:
            with contextlib.redirect_stdout(io.StringIO()):
                return sl.fetch_messages(host)
        finally:
            sl.http_json, sl.time.sleep = real_json, real_sleep


class TestCrawlTerminates(CrawlTestCase):

    def test_a_normal_crawl_returns_every_record(self):
        s = _FakeServer(total=940)
        out = self.drive(s)
        self.assertEqual(len(out), 940)
        self.assertEqual(len(s.urls), 10)
        self.assertEqual(len({r['id'] for r in out}), 940)

    def test_it_asks_for_a_stable_order(self):
        """Without `orderby=id&order=asc`, a sermon published mid-crawl
        shifts every offset and a record is served twice."""
        s = _FakeServer()
        self.drive(s)
        for u in s.urls:
            self.assertIn('orderby=id', u)
            self.assertIn('order=asc', u)

    def test_a_server_that_ignores_page_is_caught_in_two_requests(self):
        """THE BUG. This used to run forever; 201 requests were measured
        before a harness stopped it."""
        s = _FakeServer(total=940, ignore_page=True)
        with self.assertRaises(sl.CrawlAbort) as cm:
            self.drive(s)
        self.assertEqual(cm.exception.kind, sl.SITE_CHANGED)
        self.assertIn('pagination is broken', cm.exception.message)
        self.assertLessEqual(len(s.urls), 2,
                             'the abort must stop the traffic, not just '
                             'the loop')

    def test_never_exceeds_the_hard_page_cap(self):
        s = _FakeServer(total=940)
        self.drive(s)
        self.assertLessEqual(len(s.urls), sl.HARD_PAGE_CAP)

    def test_page_cap_is_derived_from_the_record_ceiling(self):
        self.assertEqual(sl.HARD_PAGE_CAP,
                         -(-sl.MAX_RECORDS // sl.PER_PAGE) + 1)


class TestCrawlHeadersAreTheAuthority(CrawlTestCase):

    def test_missing_wp_headers_are_a_site_change(self):
        """WordPress always sends them; their absence means this is not
        the collection we think it is, so we do not page through blind."""
        s = _FakeServer(headers=False)
        with self.assertRaises(sl.CrawlAbort) as cm:
            self.drive(s)
        self.assertEqual(cm.exception.kind, sl.SITE_CHANGED)
        self.assertIn('x-wp-total', cm.exception.message)
        self.assertEqual(len(s.urls), 1)

    def test_a_total_above_the_ceiling_refuses_after_one_request(self):
        """The ceiling fires on the header, not after a full crawl."""
        s = _FakeServer(total=sl.MAX_RECORDS + 1)
        with self.assertRaises(sl.CrawlAbort) as cm:
            self.drive(s)
        self.assertEqual(cm.exception.kind, sl.SITE_CHANGED)
        self.assertIn('ceiling', cm.exception.message)
        self.assertEqual(len(s.urls), 1)

    def test_too_many_pages_refuses_after_one_request(self):
        s = _FakeServer(total=900, total_pages=sl.HARD_PAGE_CAP + 1)
        with self.assertRaises(sl.CrawlAbort) as cm:
            self.drive(s)
        self.assertEqual(cm.exception.kind, sl.SITE_CHANGED)
        self.assertEqual(len(s.urls), 1)

    def test_a_crawl_that_disagrees_with_x_wp_total_is_refused(self):
        """Headers claim 940 over 10 pages; the pages hold 50 each, so
        only 500 arrive. Tolerance is 2, for a publish landing mid-crawl."""
        s = _FakeServer(total=940, total_pages=10)
        s.per_page = 50
        with self.assertRaises(sl.CrawlAbort) as cm:
            self.drive(s)
        self.assertEqual(cm.exception.kind, sl.SITE_CHANGED)
        self.assertIn('x-wp-total', cm.exception.message)

    def test_one_publish_landing_mid_crawl_is_tolerated(self):
        """The header says 941 because a sermon was published while we
        were paging; 940 arrived. That is inside the tolerance."""
        out = self.drive(_FakeServer(total=940, header_total=941))
        self.assertEqual(len(out), 940)

    def test_an_empty_page_before_the_last_is_refused(self):
        s = _FakeServer(total=940, empty_from=5)
        with self.assertRaises(sl.CrawlAbort) as cm:
            self.drive(s)
        self.assertEqual(cm.exception.kind, sl.SITE_CHANGED)
        self.assertIn('empty', cm.exception.message)


class TestCrawlShape(CrawlTestCase):

    def test_records_missing_a_required_key_are_a_site_change(self):
        for key in ('id', 'title', 'link', 'date'):
            with self.subTest(key=key):
                s = _FakeServer(drop_key=key)
                with self.assertRaises(sl.CrawlAbort) as cm:
                    self.drive(s)
                self.assertEqual(cm.exception.kind, sl.SITE_CHANGED)

    def test_a_non_list_response_is_a_site_change(self):
        def server(url, timeout=60):
            return {'code': 'rest_no_route'}, {'X-WP-Total': '940',
                                               'X-WP-TotalPages': '10'}
        with self.assertRaises(sl.CrawlAbort) as cm:
            self.drive(server)
        self.assertEqual(cm.exception.kind, sl.SITE_CHANGED)


class TestTransientVersusSiteChanged(unittest.TestCase):
    """Ruling: classify at FETCH time, not at guard time.

    The payoff is that a guard failure never needs a "maybe we were just
    throttled" caveat — if the crawl completed with every page 200 and
    valid JSON, a guard firing can only be a real change.
    """

    def _with_http_get(self, fn, url='https://x.invalid/a'):
        real = sl.http_get
        sl.http_get = fn
        try:
            return sl.http_json(url)
        finally:
            sl.http_get = real

    def test_html_instead_of_json_is_transient_not_site_changed(self):
        """A Cloudflare challenge or a cache page — retry later, do not
        go rewriting the script."""
        page = '<html><body>Checking your browser…</body></html>'
        with self.assertRaises(sl.CrawlAbort) as cm:
            self._with_http_get(
                lambda u, timeout=60: (200, {'Content-Type': 'text/html'},
                                       page))
        self.assertEqual(cm.exception.kind, sl.TRANSIENT)
        self.assertIn('Checking your browser', cm.exception.detail)
        # Not merely "TRANSIENT": the message must name the content
        # type, or this path is indistinguishable from undecodable JSON
        # and the operator cannot tell a challenge page from a truncated
        # response.
        self.assertIn('content type', cm.exception.message)
        self.assertIn('text/html', cm.exception.message)

    def test_undecodable_json_is_transient(self):
        with self.assertRaises(sl.CrawlAbort) as cm:
            self._with_http_get(
                lambda u, timeout=60: (200,
                                       {'Content-Type': 'application/json'},
                                       '{"broken'))
        self.assertEqual(cm.exception.kind, sl.TRANSIENT)

    def test_valid_json_passes_through_with_its_headers(self):
        data, headers = self._with_http_get(
            lambda u, timeout=60: (200, {'Content-Type': 'application/json',
                                         'X-WP-Total': '940'}, '[1,2,3]'))
        self.assertEqual(data, [1, 2, 3])
        self.assertEqual(headers['X-WP-Total'], '940')

    def _urlopen_status(self, status):
        class _Resp:
            def __init__(self):
                self.status = status
                self.headers = {'Content-Type': 'application/json'}

            def read(self):
                return b'[]'

            def __enter__(self):
                return self

            def __exit__(self, *a):
                return False

        def fake(req, timeout=None):
            if status == 200:
                return _Resp()
            raise urllib.error.HTTPError(
                'https://x.invalid/a', status, 'err',
                {'Content-Type': 'text/html'}, None)
        return fake

    def _drive_http_get(self, status):
        real_open, real_sleep = urllib.request.urlopen, sl.time.sleep
        urllib.request.urlopen = self._urlopen_status(status)
        sl.time.sleep = lambda _s: None
        try:
            return sl.http_get('https://x.invalid/a')
        finally:
            urllib.request.urlopen = real_open
            sl.time.sleep = real_sleep

    def test_404_is_a_site_change_and_is_not_retried(self):
        """The endpoint moved. Retrying it is pointless traffic."""
        with self.assertRaises(sl.CrawlAbort) as cm:
            self._drive_http_get(404)
        self.assertEqual(cm.exception.kind, sl.SITE_CHANGED)

    def test_429_is_transient(self):
        with self.assertRaises(sl.CrawlAbort) as cm:
            self._drive_http_get(429)
        self.assertEqual(cm.exception.kind, sl.TRANSIENT)

    def test_503_is_transient(self):
        with self.assertRaises(sl.CrawlAbort) as cm:
            self._drive_http_get(503)
        self.assertEqual(cm.exception.kind, sl.TRANSIENT)

    def test_exit_codes_are_distinct_and_documented(self):
        self.assertEqual(sl.EXIT_OK, 0)
        self.assertEqual(len({sl.EXIT_OK, sl.EXIT_REFUSED,
                              sl.EXIT_TRANSIENT}), 3)


# ── End to end, through main(), with no network ───────────────────

class TestMainEndToEnd(unittest.TestCase):
    """Drives the real `main()` against a `--cache-dir`.

    This is the only test that exercises the actual decision to write:
    everything above tests a guard or the wiring, and a pipeline can
    have both and still write the file anyway. It also pins the exit
    codes, which are what an operator (or a future workflow) reads.

    `--cache-dir` is the documented way to re-run a transform without
    costing the church a crawl, so using it here is not a test-only
    back door.
    """

    def _cache(self, tmp, messages):
        os.makedirs(tmp, exist_ok=True)
        with open(os.path.join(tmp, 'messages.json'), 'w',
                  encoding='utf-8') as f:
            json.dump(messages, f, ensure_ascii=False)
        with open(os.path.join(tmp, 'terms.json'), 'w',
                  encoding='utf-8') as f:
            json.dump({k: {str(i): v for i, v in d.items()}
                       for k, d in TERMS.items()}, f, ensure_ascii=False)
        ids = sl.collect_attachment_ids(messages)
        with open(os.path.join(tmp, 'media.json'), 'w',
                  encoding='utf-8') as f:
            json.dump({str(i): MEDIA.get(i) for i in ids}, f,
                      ensure_ascii=False)

    def _run(self, messages, extra=()):
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            cache = os.path.join(d, 'cache')
            out = os.path.join(d, 'out')
            self._cache(cache, messages)
            with contextlib.redirect_stdout(io.StringIO()) as so, \
                    contextlib.redirect_stderr(io.StringIO()) as se:
                code = sl.main(['--cache-dir', cache, '--out-dir', out,
                                *extra])
            index = os.path.join(out, 'index.json')
            doc = None
            if os.path.exists(index):
                with open(index, encoding='utf-8') as f:
                    doc = json.load(f)
            # Count inside the context: the temp dir is gone once we
            # return, and an assertion against a deleted path errors
            # instead of measuring anything.
            bodies_dir = os.path.join(out, 'bodies')
            n_bodies = (len([x for x in os.listdir(bodies_dir)
                             if x.endswith('.txt')])
                        if os.path.isdir(bodies_dir) else None)
            return code, doc, n_bodies, so.getvalue() + se.getvalue()

    def test_a_clean_corpus_is_written_and_exits_zero(self):
        code, doc, n_bodies, _log = self._run(good_corpus())
        self.assertEqual(code, sl.EXIT_OK)
        self.assertIsNotNone(doc)
        self.assertEqual(doc['_meta']['count'], sl.MIN_RECORDS)
        self.assertEqual(n_bodies, sl.MIN_RECORDS)

    def test_dry_run_writes_nothing(self):
        code, doc, n_bodies, log = self._run(good_corpus(),
                                             extra=['--dry-run'])
        self.assertEqual(code, sl.EXIT_OK)
        self.assertIsNone(doc)
        self.assertIsNone(n_bodies, 'a dry run created a bodies directory')
        self.assertIn('dry run', log)

    def test_the_chrome_substitution_is_refused_and_exits_two(self):
        """Attack 1, end to end. This is the run that used to exit 0."""
        msgs = good_corpus()
        chrome = '首页 关于我们 讲道信息 联系我们 版权所有 福音电台 ' * 40
        for m in msgs:
            m['acf']['transcription_displayed'] = f'<p>{chrome}</p>'
        code, doc, _n, log = self._run(msgs)
        self.assertEqual(code, sl.EXIT_REFUSED)
        self.assertIsNone(doc, 'a suspect snapshot reached the disk')
        self.assertIn('refusing to write', log.lower())
        self.assertIn('REFUSED', log)

    def test_the_five_fold_inflation_is_refused(self):
        """Attack 3: 4,700 rows under fresh ids."""
        msgs = []
        for k in range(5):
            for m in good_corpus():
                c = json.loads(json.dumps(m))
                if k:
                    c['id'] += 100000 * k
                    c['slug'] = f"{c['slug']}-{k}"
                    c['link'] = f"{c['link']}{k}/"
                msgs.append(c)
        code, doc, _n, _log = self._run(msgs)
        self.assertEqual(code, sl.EXIT_REFUSED)
        self.assertIsNone(doc)

    def test_null_urls_are_refused(self):
        """Attack 4."""
        msgs = good_corpus()
        for m in msgs:
            m['link'] = None
        code, doc, _n, _log = self._run(msgs)
        self.assertEqual(code, sl.EXIT_REFUSED)
        self.assertIsNone(doc)

    def test_corrupt_dates_are_refused(self):
        """Attack 6."""
        msgs = good_corpus()
        for m in msgs:
            m['date'] = '0000-00-00T00:00:00'
        code, doc, _n, _log = self._run(msgs)
        self.assertEqual(code, sl.EXIT_REFUSED)
        self.assertIsNone(doc)

    def test_one_corrupt_date_is_written_and_flagged(self):
        """The other half of the ruling: a handful of upstream typos are
        annotated, not fatal. A run that goes red on somebody else's
        typo stays red forever."""
        msgs = good_corpus()
        msgs[3]['date'] = '0214-07-02T11:19:11'
        code, doc, _n, _log = self._run(msgs)
        self.assertEqual(code, sl.EXIT_OK)
        self.assertEqual(doc['_meta']['suspectDates'], [msgs[3]['id']])
        row = next(r for r in doc['sermons'] if r['id'] == msgs[3]['id'])
        self.assertEqual(row['date'], '0214-07-02T11:19:11')
        self.assertTrue(row['dateSuspect'])

    def test_a_short_crawl_is_still_refused(self):
        """The shrinkage half must not have been weakened by any of
        this — that refusal is what has protected the songs data."""
        code, doc, _n, _log = self._run(good_corpus(sl.MIN_RECORDS - 1))
        self.assertEqual(code, sl.EXIT_REFUSED)
        self.assertIsNone(doc)


# ── Committed snapshot ────────────────────────────────────────────

def load_snapshot():
    if not os.path.exists(INDEX):
        return None
    with open(INDEX, encoding='utf-8') as f:
        return json.load(f)


@unittest.skipIf(
    load_snapshot() is None,
    'assets/sermon_library/ is deliberately untracked (see .gitignore) — '
    'run scripts/sync_sermon_library.py to regenerate it locally. On a '
    'fresh clone this class SKIPS, which means CI green here does not '
    'mean the snapshot was checked. Everything above this line runs '
    'without it.')
class TestSnapshot(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.doc = load_snapshot()
        cls.rows = cls.doc['sermons']
        cls.meta = cls.doc['_meta']

    def test_record_count_matches_upstream_total(self):
        """940 is upstream's own x-wp-total, measured 2026-09-05."""
        self.assertEqual(len(self.rows), 940)
        self.assertEqual(self.meta['count'], 940)

    def test_ids_unique(self):
        ids = [r['id'] for r in self.rows]
        self.assertEqual(len(set(ids)), len(ids))

    def test_every_record_has_a_title(self):
        self.assertEqual([r['id'] for r in self.rows if not r['title']], [])

    def test_no_html_entities_left_in_titles(self):
        """7 upstream titles carry entities; they must not reach the UI."""
        bad = [r['id'] for r in self.rows
               if r['title'] and ('&#' in r['title'] or '&amp;' in r['title'])]
        self.assertEqual(bad, [])

    # ── Floors, asserted against MEASURED values ──────────────────
    #
    # This block used to be one assertion:
    #
    #     self.assertGreaterEqual(self.meta['withBody'], sl.MIN_BODIED)
    #
    # which compares the snapshot to a constant in the script — and the
    # snapshot was generated by that same script. Measured 2026-09-06:
    # setting MIN_BODIED to 1, MIN_WITH_AUDIO to 1 and MIN_RECORDS to 1
    # each left all 54 tests green. A floor compared only to itself is
    # not a floor. So the numbers below are LITERALS measured from the
    # data, and the constants are checked against them separately.

    def test_floor_constants_still_match_what_was_measured(self):
        """If the church publishes more, ratchet BOTH the constant and
        the literal here, in the same edit, having re-measured."""
        self.assertEqual(sl.MIN_RECORDS, MEASURED['records'])
        self.assertEqual(sl.MIN_BODIED, MEASURED['bodied200'])
        self.assertEqual(sl.MIN_WITH_AUDIO, MEASURED['withAudio'])

    def test_body_and_audio_coverage_holds(self):
        self.assertGreaterEqual(self.meta['withBody'], MEASURED['bodied200'])
        self.assertGreaterEqual(self.meta['withAudio'], MEASURED['withAudio'])
        self.assertGreaterEqual(len(self.rows), MEASURED['records'])

    def test_body_volume_holds(self):
        """The single measurement the chrome substitution could not
        fake: it took 5,440,652 characters down to 555,540."""
        base = os.path.dirname(INDEX)
        total = 0
        for r in self.rows:
            if r['bodyFile']:
                with open(os.path.join(base, r['bodyFile']),
                          encoding='utf-8') as f:
                    total += len(f.read().rstrip('\n'))
        self.assertEqual(total, MEASURED['bodyChars'])
        self.assertGreaterEqual(total, sl.MIN_BODY_CHARS)
        self.assertEqual(sum(r['bodyChars'] for r in self.rows), total,
                         'index bodyChars disagrees with the body files')

    def test_bodies_are_distinct_transcripts_not_one_string(self):
        base = os.path.dirname(INDEX)
        texts = []
        for r in self.rows:
            if r['bodyFile']:
                with open(os.path.join(base, r['bodyFile']),
                          encoding='utf-8') as f:
                    texts.append(f.read().rstrip('\n'))
        self.assertEqual(len(texts), MEASURED['bodyFiles'])
        self.assertEqual(len(set(texts)), MEASURED['distinctBodies'])
        counts = {}
        for t in texts:
            counts[t] = counts.get(t, 0) + 1
        self.assertEqual(max(counts.values()), MEASURED['maxSameBody'])
        self.assertLessEqual(max(counts.values()), sl.MAX_SAME_BODY)

    def test_near_unique_fields_are_still_near_unique(self):
        n = len(self.rows)
        self.assertEqual(len({r['title'] for r in self.rows}),
                         MEASURED['distinctTitles'])
        self.assertEqual(len({r['url'] for r in self.rows}),
                         MEASURED['distinctUrls'])
        self.assertEqual(len({r['slug'] for r in self.rows}),
                         MEASURED['distinctSlugs'])
        self.assertGreaterEqual(MEASURED['distinctTitles'] / n,
                                sl.MIN_DISTINCT_TITLE_FRACTION)
        self.assertGreaterEqual(MEASURED['distinctUrls'] / n,
                                sl.MIN_DISTINCT_URL_FRACTION)

    def test_no_audio_file_is_shared_between_records(self):
        refs = [u for r in self.rows for u in r['audioUrls']]
        self.assertEqual(len(refs), MEASURED['audioRefs'])
        self.assertEqual(len(set(refs)), MEASURED['distinctAudio'])

    def test_every_record_has_a_url(self):
        """Attack 4 set all 940 to null and wrote."""
        self.assertEqual([r['id'] for r in self.rows
                          if not (r['url'] or '').strip()], [])

    def test_the_committed_snapshot_passes_the_real_guards(self):
        """The end-to-end statement: whatever else these tests check,
        the data on disk is data this pipeline would agree to write."""
        self.assertEqual(sl.guard_ceiling(self.rows, self.rows), [])
        self.assertEqual(sl.guard_field_distinctness(self.rows), [])
        self.assertEqual(sl.guard_dates(self.rows), [])
        self.assertEqual(sl.guard_hosts(self.rows), [])
        self.assertEqual(sl.guard_floors(self.rows), [])

    # ── The one corrupt date, flagged and not repaired ────────────

    def test_the_corrupt_date_is_flagged_not_fixed(self):
        """Record 2967 (约书亚(2)) carries `0214-07-02T11:19:11`. Per the
        ruling the value stays byte-for-byte and gains an annotation;
        inferring 2014 would be the silent fix this repo forbids."""
        self.assertEqual(self.meta['suspectDates'], MEASURED['suspectDates'])
        r = next(x for x in self.rows if x['id'] == 2967)
        self.assertEqual(r['date'], '0214-07-02T11:19:11')
        self.assertTrue(r['dateSuspect'])

    def test_every_other_record_has_a_sane_date(self):
        bad = [r['id'] for r in self.rows if r['dateSuspect']]
        self.assertEqual(bad, MEASURED['suspectDates'])
        for r in self.rows:
            self.assertEqual(r['dateSuspect'],
                             not sl.date_is_sane(r['date']), r['id'])

    def test_suspect_dates_stay_under_the_limit(self):
        self.assertLessEqual(len(self.meta['suspectDates']),
                             sl.MAX_SUSPECT_DATES)

    def test_attribution_accounts_for_every_record(self):
        by = self.meta['byAuthorSource']
        self.assertEqual(by['taxonomy'] + by['legacy_field'] + by['none'],
                         len(self.rows))

    def test_no_placeholder_author(self):
        for r in self.rows:
            self.assertNotIn(r['author'], ('', '未知', 'unknown'))

    def test_author_source_none_implies_no_author(self):
        for r in self.rows:
            if r['authorSource'] == 'none':
                self.assertIsNone(r['author'])
            else:
                self.assertIsNotNone(r['author'])

    def test_programme_authors_are_live_taxonomy_terms(self):
        """The hardcoded set must not rot: every name in it has to still
        appear as an author upstream, or the flag is silently dead."""
        seen = {r['author'] for r in self.rows}
        for name in sl.PROGRAMME_AUTHORS:
            self.assertIn(name, seen,
                          f'{name} is in PROGRAMME_AUTHORS but no longer '
                          f'appears upstream — re-check the taxonomy')

    def test_programme_authors_flagged(self):
        for r in self.rows:
            if r['author'] in sl.PROGRAMME_AUTHORS:
                self.assertEqual(r['authorKind'], 'programme')
            elif r['author']:
                self.assertEqual(r['authorKind'], 'person')

    def test_every_url_on_an_allowed_host(self):
        self.assertEqual(sl.guard_hosts(self.rows), [])

    def test_canonical_host_is_the_cms_siteurl(self):
        self.assertEqual(self.meta['canonicalHost'], 'fuyindiantai.org')

    def test_rights_recorded_without_inventing_a_licence(self):
        self.assertTrue(self.meta['rights'])
        self.assertTrue(self.meta['rightsNote'])
        for forbidden in ('CC BY', 'Creative Commons', 'public domain',
                          'MIT', 'GPL'):
            self.assertNotIn(forbidden, self.meta['rightsNote'])
            self.assertNotIn(forbidden, self.meta['rightsEn'])

    def test_body_files_match_the_index(self):
        base = os.path.dirname(INDEX)
        claimed = {r['bodyFile'] for r in self.rows if r['bodyFile']}
        for rel in claimed:
            self.assertTrue(os.path.exists(os.path.join(base, rel)), rel)
        on_disk = {f'bodies/{n}' for n in
                   os.listdir(os.path.join(base, 'bodies'))
                   if n.endswith('.txt')}
        # One orphan is deliberate and is named rather than tolerated.
        # `bodies/6012.txt` is the transcript of library 6012 (ws01,
        # 活着就是基督), which is the same sermon as app CP37: setting its
        # `hasBody` would send it down the merge's new-sermon path and
        # ship that sermon twice. The transcript is kept because it is
        # what MADE the comparison possible — there was no body to
        # compare against before it existed.
        #
        # Naming it means an accidental orphan still fails here, and it
        # means anyone who later decides 6012 should ship has to delete
        # this line and read why it was written.
        DELIBERATE_ORPHANS = {'bodies/6012.txt'}
        for rel in DELIBERATE_ORPHANS:
            self.assertTrue(os.path.exists(os.path.join(base, rel)),
                            f'{rel} is listed as a deliberate orphan but '
                            'is not on disk — remove it from the set '
                            'rather than leaving a dangling exception')
        self.assertEqual(on_disk - claimed - DELIBERATE_ORPHANS, set(),
                         'orphan body files not referenced by the index')

    def test_bodyless_records_still_carry_metadata(self):
        """The 97 body-less records are kept, per the skip ruling."""
        bodyless = [r for r in self.rows if not r['hasBody']]
        self.assertTrue(bodyless)
        for r in bodyless:
            self.assertTrue(r['title'])
            self.assertTrue(r['url'])


if __name__ == '__main__':
    unittest.main(verbosity=2)
