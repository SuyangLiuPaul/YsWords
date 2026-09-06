#!/usr/bin/env python3
"""Tests for `scripts/index_sermon_library_refs.py`.

Run:
    python3 -m unittest discover -s test -p 'test_*.py' -v
    python3 test/test_sermon_library_refs.py        # same thing

stdlib `unittest`, matching `test/test_sermon_library.py` next door:
this repo has no pytest, and an indexer's tests should not be the thing
that adds a dependency to CI.

Two kinds of test, the same split the sync script's tests use.

1. RULE TESTS. Every rule this script adds gets a test that exercises
   it against the SMALLEST input that distinguishes it from its
   neighbours (trap 59: an index built by merging N sources has N ways
   for an assertion about it to be true, and only one of them is the
   rule). Each was mutation-checked — the rule was broken in turn and
   the mapped test confirmed to go red. A rule no test can make fail is
   decorative.

   Where a rule is a CONJUNCTION, both halves get their own test, so
   that dropping either half is caught. `focus_chapters` is the case
   that matters: its bar is ">=3 keys AND >=20% share", and a suite that
   only ever fed it inputs failing both halves would stay green if the
   AND became an OR.

2. SNAPSHOT TESTS. Assertions about the emitted
   `assets/sermon_library/refs.json`, so a bad regeneration is caught
   even when every unit rule still passes. They SKIP rather than fail
   when the artifact is absent, so a fresh clone that has not run the
   indexer still gets a green rule suite.

   The snapshot numbers below are LITERALS measured on 2026-09-06, not
   values recomputed from the file under test. A floor that recomputes
   its own bound compares a constant to itself and can never fail.
"""

import importlib.util
import json
import os
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(REPO, 'scripts', 'index_sermon_library_refs.py')
REFS = os.path.join(REPO, 'assets', 'sermon_library', 'refs.json')
APP_SERMONS = os.path.join(REPO, 'assets', 'sermons')

_spec = importlib.util.spec_from_file_location('index_sermon_library_refs',
                                               SCRIPT)
ix = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ix)


# ── Measured literals ─────────────────────────────────────────────
# Measured against assets/sermon_library/ on 2026-09-06. Quoted as
# literals on purpose — see the module docstring.
N_RECORDS = 940
N_WITH_BOOK = 839
N_WITH_CHAPTER = 812
N_WITH_VERSE = 797
N_WITH_NOTHING = 101
N_BODYLESS = 97
N_TAXONOMY = 461
N_TAXONOMY_ONLY = 27
N_APP_SERMONS = 289
N_SAME_PREACHER = 198


class BracketNormalization(unittest.TestCase):
    """The 》 that this corpus puts between a book name and its chapter.

    The rule is scoped to a COMPLETE 《book》 wrapper standing in front of
    a number. Each of those three conditions — opening bracket, book
    name, following number — gets its own negative test, because a
    blanket bracket strip would pass a test that only ever checked the
    positive case.
    """

    def test_closer_between_book_and_digit_is_removed(self):
        self.assertEqual(ix.normalize_body('《哥林多前书》15：15-17节'),
                         '《哥林多前书15：15-17节')

    def test_the_citation_is_invisible_without_the_rule(self):
        """The whole point: the raw text yields NOTHING and the
        normalized text yields the passage. Asserting only the second
        half would stay green if the grammar had learned 》 by itself,
        which is a different fact."""
        raw = '我们今天看《哥林多前书》15：20-22节。'
        self.assertEqual(ix.G.extract_refs(raw), [])
        self.assertEqual(
            ix.G.extract_refs(ix.normalize_body(raw)),
            ['1 Corinthians 15:20', '1 Corinthians 15:21',
             '1 Corinthians 15:22'])

    def test_chinese_numeral_and_di_forms_also_reached(self):
        for raw, want in (
                ('《路加福音》12章16节', ['Luke 12:16']),
                ('《箴言》三十章十节', ['Proverbs 30:10']),
                ('《哥林多前书》第七章', ['1 Corinthians 7']),
                ('（《出埃及记》11:4）', ['Exodus 11:4']),
        ):
            self.assertEqual(ix.G.extract_refs(ix.normalize_body(raw)),
                             want, raw)

    def test_closer_not_following_a_book_name_is_kept(self):
        """《恩典之路》3 is not scripture, and a blanket strip would make
        it look like one. Note the trap the anchor exists to avoid: the
        title ENDS in 路, which is the one-character alias for Luke."""
        text = '他写的《恩典之路》3年前出版。'
        self.assertEqual(ix.normalize_body(text), text)

    def test_a_title_merely_ending_in_a_book_alias_is_kept(self):
        """The 17 sites the anchored form gives up, and why. 摩 and 书
        here are the tails of MOSES and JOSHUA, and 第六讲 is "lecture
        six", not a chapter. The looser rule that only asked for an
        alias in front of the 》 rewrote all of these."""
        for text in ('《圣经人物·摩西》第六讲',
                     '《圣经人物·约书亚》第一讲',
                     '倪柝声在《天国的福音——马太福音》一书中写道'):
            self.assertEqual(ix.normalize_body(text), text, text)

    def test_the_looser_rule_would_have_invented_a_reference(self):
        """Not merely untidy — wrong. 一书中 means "in a book", and the
        unanchored rule turns it into Matthew chapter 1."""
        text = '倪柝声在《天国的福音——马太福音》一书中写道'
        self.assertEqual(ix.G.extract_refs(ix.normalize_body(text)), [])
        loosened = text.replace('马太福音》一书中', '马太福音一书中')
        self.assertEqual(ix.G.extract_refs(loosened), ['Matthew 1'])

    def test_closer_not_followed_by_a_number_is_kept(self):
        text = '请翻到《哥林多前书》，我们一起读。'
        self.assertEqual(ix.normalize_body(text), text)

    def test_opening_bracket_is_never_touched(self):
        """Only the CLOSER is in the grammar's way. 《 sits before the
        book name, where a word boundary already matches, so it is kept
        and the normalized text still reads as the corpus wrote it."""
        self.assertEqual(ix.normalize_body('《哥林多前书》15章'),
                         '《哥林多前书15章')

    def test_normalizer_is_a_noop_on_the_app_corpus(self):
        """The load-bearing claim of the whole design: this cannot move
        `assets/sermons/refs.json`, because it changes no byte of any of
        that corpus's 867 body files."""
        checked = 0
        for lang in ('en', 'zh-CN', 'zh-TW'):
            d = os.path.join(APP_SERMONS, lang)
            if not os.path.isdir(d):
                continue
            for name in sorted(os.listdir(d)):
                if not name.endswith('.txt'):
                    continue
                with open(os.path.join(d, name), encoding='utf-8') as f:
                    text = f.read()
                self.assertEqual(ix.normalize_body(text), text,
                                 f'{lang}/{name}')
                checked += 1
        if not checked:
            self.skipTest('app sermon corpus not present')
        self.assertGreaterEqual(checked, 800)


class TaxonomyResolution(unittest.TestCase):

    def test_plain_term_resolves(self):
        self.assertEqual(ix.taxonomy_book('创世记'), 'Genesis')
        self.assertEqual(ix.taxonomy_book('马太福音'), 'Matthew')

    def test_overview_qualifier_folds_to_the_same_book(self):
        """罗马书 and 罗马书(纵览) are two live terms naming one book. A
        reader after sermons on Romans wants both."""
        self.assertEqual(ix.taxonomy_book('罗马书(纵览)'), 'Romans')
        self.assertEqual(ix.taxonomy_book('罗马书(纵览)'),
                         ix.taxonomy_book('罗马书'))

    def test_all_fifteen_live_terms_resolve(self):
        """The 15 terms fetched from /wp-json/wp/v2/shujuanchakao on
        2026-09-06. An unresolved term silently drops a whole book's
        worth of records out of `byBook`."""
        for term in ('马太福音', '创世记', '雅各书', '箴言', '列王纪上',
                     '列王纪下', '罗马书', '哥林多前书', '彼得前书',
                     '腓立比书', '彼得后书', '罗马书(纵览)', '犹大书',
                     '约翰一书', '提摩太后书'):
            self.assertIsNotNone(ix.taxonomy_book(term), term)

    def test_absent_and_unknown_terms_give_none(self):
        self.assertIsNone(ix.taxonomy_book(None))
        self.assertIsNone(ix.taxonomy_book(''))
        self.assertIsNone(ix.taxonomy_book('圣经人物'))


class FocusRule(unittest.TestCase):
    """">=3 distinct keys AND >=20% share." Both halves, separately."""

    def test_dominant_chapter_qualifies(self):
        keys = ['Genesis 3:1', 'Genesis 3:6', 'Genesis 3:15', 'Romans 5:12']
        self.assertEqual(ix.focus_chapters(keys), ['Genesis 3'])

    def test_share_alone_is_not_enough(self):
        """Two keys are 100% of this sermon, and two keys is not a
        sermon ABOUT a chapter. Kills dropping the key-count floor."""
        self.assertEqual(ix.focus_chapters(['Genesis 3:1', 'Genesis 3:6']),
                         [])

    def test_key_count_alone_is_not_enough(self):
        """Three keys of Genesis 3 buried in a wide-ranging sermon is a
        passage quoted, not a sermon's subject. Kills dropping the share
        floor. 3/21 = 14.3%, under the 20% bar."""
        keys = ['Genesis 3:1', 'Genesis 3:6', 'Genesis 3:15']
        keys += [f'Psalms {c}:1' for c in range(1, 19)]
        self.assertEqual(len(keys), 21)
        self.assertEqual(ix.focus_chapters(keys), [])

    def test_both_halves_together_qualify(self):
        """The same three Genesis keys, in a sermon small enough for
        them to be 3/9 = 33%. Same chapter, same key count — only the
        share changed, which is what makes this the smallest input that
        distinguishes the share floor."""
        keys = ['Genesis 3:1', 'Genesis 3:6', 'Genesis 3:15']
        keys += [f'Psalms {c}:1' for c in range(1, 7)]
        self.assertEqual(len(keys), 9)
        self.assertEqual(ix.focus_chapters(keys), ['Genesis 3'])

    def test_ordered_by_weight_not_by_name(self):
        keys = []
        for book, n in (('Zechariah 1', 9), ('Exodus 2', 7), ('Luke 3', 5)):
            keys += [f'{book}:{v}' for v in range(1, n + 1)]
        self.assertEqual(ix.focus_chapters(keys),
                         ['Zechariah 1', 'Exodus 2', 'Luke 3'])

    def test_capped_at_three(self):
        """FOUR chapters that each clear BOTH halves of the bar — 5 keys
        apiece is 25% of 20 — so the cap is the only thing that can trim
        the list. An earlier version of this test used weights that fell
        under the share floor, which meant the cap was never exercised
        and raising it to 99 changed nothing: the test asserted the cap
        without testing it."""
        keys = []
        for book in ('Genesis 1', 'Exodus 2', 'Luke 3', 'John 4'):
            keys += [f'{book}:{v}' for v in range(1, 6)]
        self.assertEqual(len(keys), 20)
        qualifying = [c for c, n in
                      __import__('collections').Counter(
                          k.split(':')[0] for k in keys).items()
                      if n >= ix.FOCUS_MIN_KEYS
                      and n / len(keys) >= ix.FOCUS_MIN_SHARE]
        self.assertEqual(len(qualifying), 4, 'fixture must over-qualify')
        self.assertEqual(len(ix.focus_chapters(keys)),
                         ix.FOCUS_MAX_CHAPTERS)

    def test_no_qualifying_chapter_gives_an_empty_list(self):
        """A topical sermon that is about no single chapter says so,
        rather than having a bar lowered until something appears."""
        keys = [f'Psalms {c}:1' for c in range(1, 21)]
        self.assertEqual(ix.focus_chapters(keys), [])

    def test_bare_chapter_keys_count_toward_their_own_chapter(self):
        keys = ['Genesis 3', 'Genesis 3:6', 'Genesis 3:15', 'Romans 5:12']
        self.assertEqual(ix.focus_chapters(keys), ['Genesis 3'])


class FingerprintHelpers(unittest.TestCase):

    def test_chapters_of_collapses_verses(self):
        self.assertEqual(
            ix.chapters_of(['Genesis 3:1', 'Genesis 3:15', 'Genesis 3']),
            {'Genesis 3'})

    def test_chapters_of_keeps_chapters_apart(self):
        self.assertEqual(
            ix.chapters_of(['Genesis 3:1', 'Genesis 4:1']),
            {'Genesis 3', 'Genesis 4'})

    def test_jaccard_is_intersection_over_union(self):
        self.assertEqual(ix.jaccard({'a', 'b'}, {'a', 'b'}), 1.0)
        self.assertEqual(ix.jaccard({'a', 'b'}, {'c', 'd'}), 0.0)
        self.assertAlmostEqual(ix.jaccard({'a', 'b'}, {'b', 'c'}), 1 / 3)

    def test_jaccard_of_two_empty_sets_is_zero_not_an_error(self):
        self.assertEqual(ix.jaccard(set(), set()), 0.0)


class TitleMatching(unittest.TestCase):

    def test_punctuation_and_width_are_normalized_away(self):
        self.assertEqual(ix.normalize_title('八福：与圣灵的果子'),
                         ix.normalize_title('八福 — 与圣灵的果子'))

    def test_different_titles_stay_different(self):
        self.assertNotEqual(ix.normalize_title('撒网的比喻'),
                            ix.normalize_title('撒种的比喻'))

    def test_similarity_is_high_for_a_prefix_variant(self):
        self.assertGreaterEqual(
            ix.title_similarity('怜恤人的人有福了', '八福：怜恤人的人有福了'),
            ix.DUP_TITLE_HIGH)

    def test_similarity_is_low_for_the_pair_titles_cannot_catch(self):
        """Library 4249 and app 062 are the SAME sermon and their titles
        agree on almost nothing. This is the measurement that says a
        title-only duplicate check is the wrong instrument."""
        self.assertLess(
            ix.title_similarity('舍己：门徒的标记',
                                '施与，成为世上的光 — 星辰与黑洞：神是施与者'),
            ix.DUP_TITLE_HIGH)


class WithinCorpusDuplicates(unittest.TestCase):
    """Byte-identical republications versus bare title collisions."""

    def _records(self):
        return [
            {'id': 1, 'title': '清心的人有福了', 'author': None,
             'bodyFile': 'bodies/1.txt', 'hasBody': True},
            {'id': 2, 'title': '清心的人有福了', 'author': '张熙和牧师',
             'bodyFile': 'bodies/2.txt', 'hasBody': True},
            {'id': 3, 'title': '万物的结局近了', 'author': '小珊姊妹',
             'bodyFile': 'bodies/3.txt', 'hasBody': True},
            {'id': 4, 'title': '万物的结局近了', 'author': '张熙和牧师',
             'bodyFile': 'bodies/4.txt', 'hasBody': True},
            # Two body-less records sharing a title. Both hash to None,
            # which is the same value — so a rule that groups on the
            # digest without excluding None would call them identical
            # copies of each other on the strength of having no text at
            # all. The corpus has 97 body-less records for this to go
            # wrong across.
            {'id': 5, 'title': '圣诞节的故事', 'author': '小珊姊妹',
             'bodyFile': None, 'hasBody': False},
            {'id': 6, 'title': '圣诞节的故事', 'author': '张成牧师',
             'bodyFile': None, 'hasBody': False},
        ]

    def setUp(self):
        import tempfile
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        base = os.path.join(self.tmp.name, 'bodies')
        os.makedirs(base)
        for n, text in ((1, 'same text'), (2, 'same text'),
                        (3, 'one text'), (4, 'a different text')):
            with open(os.path.join(base, f'{n}.txt'), 'w',
                      encoding='utf-8') as f:
                f.write(text)
        self._real_lib = ix.LIB
        ix.LIB = __import__('pathlib').Path(self.tmp.name)
        self.addCleanup(lambda: setattr(ix, 'LIB', self._real_lib))

    def test_identical_bodies_are_reported_as_copies(self):
        identical, _ = ix.within_corpus_duplicates(self._records(), {})
        self.assertEqual([(d['id'], d['identicalCopyOf']) for d in identical],
                         [('1', '2')])

    def test_the_attributed_copy_is_canonical(self):
        """Record 2 carries the author, so it is the one to keep. If the
        canonical pick were arbitrary the pointer would run the other
        way and the UI would collapse onto the unattributed copy."""
        identical, _ = ix.within_corpus_duplicates(self._records(), {})
        self.assertEqual(identical[0]['identicalCopyOf'], '2')
        self.assertEqual(identical[0]['id'], '1')

    def test_same_title_different_text_is_a_collision_not_a_copy(self):
        identical, collisions = ix.within_corpus_duplicates(
            self._records(), {})
        self.assertNotIn('3', [d['id'] for d in identical])
        self.assertNotIn('4', [d['id'] for d in identical])
        self.assertEqual([c['ids'] for c in collisions], [['3', '4']])

    def test_two_bodyless_records_are_not_copies_of_each_other(self):
        """Having no text is not the same as having the same text. Both
        hash to None, and a digest grouping that admits None would
        report one as an identical copy of the other."""
        identical, _ = ix.within_corpus_duplicates(self._records(), {})
        reported = {d['id'] for d in identical} | {
            d['identicalCopyOf'] for d in identical}
        self.assertNotIn('5', reported)
        self.assertNotIn('6', reported)

    def test_a_collision_records_whether_the_preacher_is_the_same(self):
        """With 71 preachers, a shared title across two of them is a
        coincidence of naming, not a duplicate."""
        _, collisions = ix.within_corpus_duplicates(self._records(), {})
        self.assertFalse(collisions[0]['samePreacher'])


class CrossCorpusTiers(unittest.TestCase):
    """The four tiers, one test per predicate boundary."""

    # 'B' must resemble neither 'A' nor the LIB_UNLIKE title below, or a
    # tier test silently becomes an exact-title test.
    LIB_UNLIKE = '两种根基的比喻'
    APP_TITLES = {'A': '怜恤人的人有福了', 'B': '雅伟是我的牧者'}

    def _run(self, lib_title, lib_keys, app_keys, app_id='A'):
        records = [{'id': 9, 'title': lib_title, 'author': '张熙和牧师',
                    'hasBody': True}]
        return ix.cross_corpus_duplicates(
            records, {'9': lib_keys}, {app_id: app_keys},
            self.APP_TITLES, set(), '张熙和牧师')

    def test_exact_title_is_confirmed(self):
        got = self._run('怜恤人的人有福了',
                        ['Genesis 1:1', 'Exodus 2:2', 'Luke 3:3'],
                        ['Genesis 1:1', 'Exodus 2:2', 'Luke 3:3'])
        self.assertEqual(got[0]['tier'], 'confirmed')

    def test_high_fingerprint_with_unlike_title_is_probable(self):
        """The 4249/062 shape: the tier that title matching cannot
        reach, and 36 of the corpus's candidates live in it."""
        got = self._run(self.LIB_UNLIKE,
                        ['Genesis 1:1', 'Exodus 2:2', 'Luke 3:3'],
                        ['Genesis 1:1', 'Exodus 2:2', 'Luke 3:3'])
        self.assertEqual(got[0]['tier'], 'probable')
        self.assertGreaterEqual(got[0]['chapterJaccard'], ix.DUP_CHAP_HIGH)

    def test_like_title_with_middling_fingerprint_is_possible(self):
        got = self._run('八福：怜恤人的人有福了',
                        ['Genesis 1:1', 'Exodus 2:2', 'Luke 3:3',
                         'John 4:4'],
                        ['Genesis 1:1', 'Exodus 2:2', 'Mark 5:5',
                         'Acts 6:6'])
        self.assertEqual(got[0]['tier'], 'possible')

    def test_unlike_title_with_middling_fingerprint_is_weak(self):
        got = self._run(self.LIB_UNLIKE,
                        ['Genesis 1:1', 'Exodus 2:2', 'Luke 3:3',
                         'John 4:4'],
                        ['Genesis 1:1', 'Exodus 2:2', 'Mark 5:5',
                         'Acts 6:6'], app_id='B')
        self.assertEqual(got[0]['tier'], 'weak')

    def test_below_the_floor_is_not_a_candidate_at_all(self):
        got = self._run(self.LIB_UNLIKE,
                        ['Genesis 1:1', 'Exodus 2:2', 'Luke 3:3'],
                        ['Mark 5:5', 'Acts 6:6', 'John 7:7'], app_id='B')
        self.assertEqual(got, [])

    def test_a_record_by_another_preacher_is_never_a_candidate(self):
        """The app corpus is one man's. A library record by someone else
        that happens to share a title is a title collision, and calling
        it a duplicate would tell the reader two different men preached
        one sermon."""
        records = [{'id': 9, 'title': '怜恤人的人有福了',
                    'author': '张成牧师', 'hasBody': True}]
        got = ix.cross_corpus_duplicates(
            records, {'9': ['Genesis 1:1', 'Exodus 2:2', 'Luke 3:3']},
            {'A': ['Genesis 1:1', 'Exodus 2:2', 'Luke 3:3']},
            self.APP_TITLES, set(), '张熙和牧师')
        self.assertEqual(got, [])

    def test_no_fingerprint_plus_exact_title_is_confirmed_but_flagged(self):
        """Record 6012's shape: an exact title match and a zero-length
        body. It is confirmed on the title and explicitly unverifiable —
        not silently dropped, and not silently treated as fingerprinted."""
        got = self._run('怜恤人的人有福了', [],
                        ['Genesis 1:1', 'Exodus 2:2', 'Luke 3:3'])
        self.assertEqual(len(got), 1)
        self.assertEqual(got[0]['tier'], 'confirmed')
        self.assertFalse(got[0]['fingerprintAvailable'])
        self.assertIsNone(got[0]['chapterJaccard'])

    def test_no_fingerprint_and_no_title_match_says_nothing(self):
        got = self._run(self.LIB_UNLIKE, [],
                        ['Genesis 1:1', 'Exodus 2:2', 'Luke 3:3'],
                        app_id='B')
        self.assertEqual(got, [])

    def test_series_risk_fires_only_when_every_shared_chapter_is_in_one(self):
        records = [{'id': 9, 'title': 'x', 'author': '张熙和牧师',
                    'hasBody': True}]
        keys = ['Matthew 5:1', 'Matthew 6:1', 'Matthew 7:1']
        only_matthew = ix.cross_corpus_duplicates(
            records, {'9': keys}, {'A': keys}, {'A': 'y'},
            {'Matthew'}, '张熙和牧师')
        self.assertTrue(only_matthew[0]['seriesRisk'])
        mixed_keys = keys + ['Romans 8:1']
        mixed = ix.cross_corpus_duplicates(
            records, {'9': mixed_keys}, {'A': mixed_keys}, {'A': 'y'},
            {'Matthew'}, '张熙和牧师')
        self.assertFalse(mixed[0]['seriesRisk'])


class PreacherName(unittest.TestCase):

    def test_read_from_sermon_credit_not_typed_here(self):
        """The whole cross-corpus check hangs off this name. It is read
        out of the Dart file the app itself credits from, so the two
        cannot drift."""
        self.assertEqual(ix.app_preacher(), '张熙和牧师')


class Snapshot(unittest.TestCase):
    """Assertions about the committed artifact. See the module docstring
    on why these are literals."""

    @classmethod
    def setUpClass(cls):
        if not os.path.exists(REFS):
            raise unittest.SkipTest(
                'assets/sermon_library/refs.json not built')
        with open(REFS, encoding='utf-8') as f:
            cls.doc = json.load(f)

    def test_record_and_resolution_counts(self):
        m = self.doc['_meta']
        self.assertEqual(m['records'], N_RECORDS)
        self.assertEqual(m['withAtLeastOneBook'], N_WITH_BOOK)
        self.assertEqual(m['withAtLeastOneChapter'], N_WITH_CHAPTER)
        self.assertEqual(m['withAtLeastOneVerse'], N_WITH_VERSE)
        self.assertEqual(m['withNothing'], N_WITH_NOTHING)
        self.assertEqual(m['bodylessRecords'], N_BODYLESS)

    def test_the_four_tiers_partition_the_records(self):
        m = self.doc['_meta']
        self.assertEqual(
            m['withAtLeastOneBook'] + m['withNothing'], N_RECORDS)
        self.assertGreaterEqual(m['withAtLeastOneBook'],
                                m['withAtLeastOneChapter'])
        self.assertGreaterEqual(m['withAtLeastOneChapter'],
                                m['withAtLeastOneVerse'])

    def test_taxonomy_coverage(self):
        m = self.doc['_meta']
        self.assertEqual(m['taxonomyBookRecords'], N_TAXONOMY)
        self.assertEqual(m['taxonomyOnlyRecords'], N_TAXONOMY_ONLY)

    def test_byverse_and_bysermon_are_mutually_consistent(self):
        """The two directions of one index. A record listed under a key
        must carry that key, and vice versa — this is what the UI's two
        questions each rely on."""
        for key, ids in self.doc['byVerse'].items():
            for sid in ids:
                self.assertIn(key, self.doc['bySermon'][sid],
                              f'{sid} listed under {key} but does not '
                              f'carry it')
        for sid, keys in self.doc['bySermon'].items():
            for key in keys:
                self.assertIn(sid, self.doc['byVerse'][key],
                              f'{sid} carries {key} but is not listed '
                              f'under it')

    def test_every_indexed_id_is_a_real_record(self):
        path = os.path.join(REPO, 'assets', 'sermon_library', 'index.json')
        with open(path, encoding='utf-8') as f:
            real = {str(r['id']) for r in json.load(f)['sermons']}
        self.assertEqual(set(self.doc['bySermon']) - real, set())
        self.assertEqual(set(self.doc['focus']) - real, set())
        self.assertEqual(set(self.doc['unresolved']) - real, set())

    def test_unresolved_records_appear_nowhere_else(self):
        unresolved = set(self.doc['unresolved'])
        self.assertEqual(unresolved & set(self.doc['bySermon']), set())
        self.assertEqual(unresolved & set(self.doc['bookSource']), set())
        self.assertEqual(len(unresolved), N_WITH_NOTHING)

    def test_book_source_labels_are_honest(self):
        """A book marked `taxonomy` must NOT be one the body cites, and
        a book marked `body` must be. Mislabelling here would let the UI
        present an editor's filing as a quotation."""
        for sid, books in self.doc['bookSource'].items():
            cited = {k.rsplit(' ', 1)[0]
                     for k in self.doc['bySermon'].get(sid, [])}
            for book, src in books.items():
                if src == 'taxonomy':
                    self.assertNotIn(book, cited, f'{sid} {book}')
                else:
                    self.assertIn(book, cited, f'{sid} {book}')

    def test_focus_entries_are_levelled(self):
        """`level` is mandatory: a book-level taxonomy entry read as a
        chapter is the same over-broad mistake colon-less keys already
        cause elsewhere."""
        seen = set()
        for entries in self.doc['focus'].values():
            for e in entries:
                self.assertIn(e['level'], ('chapter', 'book'))
                self.assertIn(e['source'], ('body', 'taxonomy'))
                if e['level'] == 'book':
                    self.assertNotIn(':', e['ref'])
                    self.assertEqual(e['source'], 'taxonomy')
                seen.add(e['level'])
        self.assertEqual(seen, {'chapter', 'book'})

    def test_focus_chapters_are_a_subset_of_what_the_sermon_cites(self):
        for sid, entries in self.doc['focus'].items():
            cited = ix.chapters_of(self.doc['bySermon'].get(sid, []))
            for e in entries:
                if e['level'] == 'chapter':
                    self.assertIn(e['ref'], cited, sid)

    def test_no_duplicate_is_merged_or_removed(self):
        """The ruling: flagged, never merged. Every record named in the
        duplicate report must still be present in the index."""
        path = os.path.join(REPO, 'assets', 'sermon_library', 'index.json')
        with open(path, encoding='utf-8') as f:
            real = {str(r['id']) for r in json.load(f)['sermons']}
        d = self.doc['duplicates']
        for row in d['crossCorpus']:
            self.assertIn(row['libId'], real)
        for row in d['identicalWithinCorpus']:
            self.assertIn(row['id'], real)
            self.assertIn(row['identicalCopyOf'], real)
        for row in d['titleCollisionsWithinCorpus']:
            for sid in row['ids']:
                self.assertIn(sid, real)

    def test_duplicate_tiers_are_all_populated(self):
        counts = self.doc['_meta']['duplicateTierCounts']
        self.assertEqual(set(counts),
                         {'confirmed', 'probable', 'possible', 'weak'})
        self.assertEqual(counts['confirmed'], 22)
        self.assertEqual(counts['probable'], 36)
        self.assertEqual(counts['possible'], 4)
        self.assertEqual(counts['weak'], 43)

    def test_title_matching_alone_would_have_missed_most_duplicates(self):
        """The finding that reframes the brief. If this ever stops being
        true the duplicate check has quietly become title matching
        again."""
        rows = [r for r in self.doc['duplicates']['crossCorpus']
                if r['tier'] in ('confirmed', 'probable')]
        by_title = [r for r in rows if r['titleSim'] >= ix.DUP_TITLE_HIGH]
        self.assertGreater(len(rows) - len(by_title), len(by_title))

    def test_cross_corpus_scope(self):
        m = self.doc['_meta']
        self.assertEqual(m['appCorpusSermons'], N_APP_SERMONS)
        self.assertEqual(m['libraryRecordsBySamePreacher'], N_SAME_PREACHER)
        self.assertEqual(m['duplicateRule']['restrictedToPreacher'],
                         '张熙和牧师')


if __name__ == '__main__':
    unittest.main(verbosity=2)
