#!/usr/bin/env python3
"""Tests for `scripts/transcribe_sermons.py` and `scripts/transcribe_qa.py`.

Run:
    python3 -m unittest discover -s test -p 'test_*.py' -v
    python3 test/test_transcribe_qa.py            # same thing

stdlib `unittest`, matching `test/test_sermon_library.py`: this repo has
no pytest and a transcription pass should not be what adds a dependency.

Three kinds of test live here.

1. GUARD TESTS. Every check in `transcribe_qa.py` gets a test that feeds
   it deliberately broken input and asserts it fires, plus one that feeds
   it good input and asserts it stays quiet.

2. THE MUTATION HARNESS, `test_every_guard_is_load_bearing`. Point 1 is
   worth nothing on its own — ten tests were found in this repo on
   2026-09-06 that PASSED while the thing they claimed to test was
   deliberately broken. So this test breaks each guard in turn, re-runs
   the test that maps to it, and FAILS if that test still passes. A guard
   no test can make fail is decorative, and this is the assertion that
   says so out loud rather than in a comment.

3. SEAM TESTS. The body this pass writes has to survive
   `merge_sermon_library.py::library_body_to_app_body`, which refuses a
   blank line and drops a first line equal to the title. These assert the
   shape against the real merge function, not against a description of
   it. They skip when a transcript has not been produced yet.
"""

import importlib.util
import json
import os
import sys
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(REPO, 'scripts'))

import transcribe_qa as QA          # noqa: E402
import transcribe_sermons as TS     # noqa: E402


def _merge_module():
    spec = importlib.util.spec_from_file_location(
        'merge_sermon_library',
        os.path.join(REPO, 'scripts', 'merge_sermon_library.py'))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def segs(*texts, step=3.0):
    """Contiguous segments, the shape whisper.cpp actually emits."""
    return [{'start': i * step, 'end': (i + 1) * step, 'text': t}
            for i, t in enumerate(texts)]


def _runons_with_newlines(text):
    """`find_runons` as it was before the newline strip — the bug itself.

    Kept so the mutation harness can put the bug back and prove the test
    that found it still catches it.
    """
    out, pos = [], 0
    stop = __import__('re').compile(r'[。！？!?；;\n]')
    for m in stop.finditer(text):
        if m.start() - pos >= QA.RUNON_CHARS:
            out.append({'kind': 'runon', 'chars': m.start() - pos})
        pos = m.end()
    if len(text) - pos >= QA.RUNON_CHARS:
        out.append({'kind': 'runon', 'chars': len(text) - pos})
    return out


CLEAN = segs('保罗在六章二节完全否定了这样的观点。',
             '神的恩典不是犯罪的许可证。',
             '我们看罗马书六章第三节。')
CLEAN_TEXT = '\n'.join(s['text'] for s in CLEAN)


# ── guard tests ─────────────────────────────────────────────────────

class LoopTests(unittest.TestCase):
    def test_segment_repeat_fires(self):
        s = segs('主是我的牧者', '主是我的牧者', '主是我的牧者', '主是我的牧者')
        found = QA.find_segment_loops(s)
        self.assertTrue(found, 'a 4x consecutive repeat must be reported')
        self.assertEqual(found[0]['runLength'], 4)

    def test_two_in_a_row_is_not_a_loop(self):
        self.assertEqual(QA.find_segment_loops(segs('是的。', '是的。')), [])

    def test_ngram_repeat_inside_one_segment_fires(self):
        text = '他说' + '因为神爱我们' * 5 + '所以'
        self.assertTrue(QA.find_ngram_loops(text))

    def test_clean_text_has_no_ngram_loop(self):
        self.assertEqual(QA.find_ngram_loops(CLEAN_TEXT), [])


class BadRefTests(unittest.TestCase):
    def test_impossible_chapter_fires(self):
        # Amos has 9 chapters. Revelation has 22.
        found = QA.find_impossible_refs('他引用阿摩司书十二章三节，又读启示录二十五章一节。')
        self.assertEqual(len(found), 2, found)
        self.assertEqual({f['book'] for f in found}, {'Amos', 'Revelation'})

    def test_real_reference_is_not_reported(self):
        self.assertEqual(
            QA.find_impossible_refs('我们看罗马书六章十二节和阿摩司书九章一节。'), [])

    def test_a_verse_of_a_one_chapter_book_is_not_an_impossible_chapter(self):
        """CM03 read 「在犹大书十一节」 and this check called it impossible.

        Jude has one chapter and 25 verses, so that is Jude 11 — the Korah
        verse the sermon goes on to discuss. Obadiah, Philemon, 2 John and
        3 John are the same shape.
        """
        self.assertEqual(QA.find_impossible_refs('在犹大书十一节'), [])
        self.assertEqual(QA.find_impossible_refs('在腓利门书六节'), [])
        # …but a number past the end of the only chapter still is one.
        self.assertTrue(QA.find_impossible_refs('在犹大书四十节'))


class BookNameTests(unittest.TestCase):
    def test_one_character_wrong_in_citation_position_fires(self):
        found = QA.find_bad_book_names('我们看格林多前书十三章二节')
        self.assertEqual(len(found), 1, found)
        self.assertEqual(found[0]['matched'], '格林多前书')
        self.assertEqual(found[0]['probably'], '哥林多前书')

    def test_a_correct_book_name_is_not_reported(self):
        self.assertEqual(
            QA.find_bad_book_names('我们看哥林多前书十三章二节'), [])

    def test_a_near_miss_outside_citation_position_is_not_reported(self):
        """Without the citation tail the rule fires on ordinary prose."""
        self.assertEqual(QA.find_bad_book_names('他说格林多前书很长'), [])


class GapTests(unittest.TestCase):
    def test_hole_in_the_timeline_fires(self):
        s = [{'start': 0.0, 'end': 10.0, 'text': '一'},
             {'start': 300.0, 'end': 310.0, 'text': '二'}]
        found = QA.find_gaps(s, 310.0)
        self.assertEqual(len(found), 1, found)
        self.assertAlmostEqual(found[0]['seconds'], 290.0)

    def test_tail_dropout_fires(self):
        found = QA.find_gaps(segs('一', '二'), 1800.0)
        self.assertTrue(any(f.get('tail') for f in found), found)

    def test_contiguous_segments_are_clean(self):
        self.assertEqual(QA.find_gaps(CLEAN, 9.0), [])

    def test_span_removed_by_the_transcriber_is_not_a_dropout(self):
        """The regression this check was rebuilt for.

        The transcriber drops boilerplate segments; the first version of
        find_gaps then reported the holes IT had made as decode dropouts.
        """
        s = [{'start': 60.0, 'end': 70.0, 'text': '讲道开始'}]
        removed = [{'start': 0.0, 'end': 59.98,
                    'text': '请不吝点赞 订阅 转发 打赏支持明镜与点点栏目'}]
        self.assertTrue(QA.find_gaps(s, 70.0), 'without the exemption it fires')
        self.assertEqual(QA.find_gaps(s, 70.0, removed), [])


class BoilerplateTests(unittest.TestCase):
    def test_residual_exact_boilerplate_is_named_as_such(self):
        """A segment the transcriber's own blocklist should have dropped."""
        found = QA.find_boilerplate(
            segs('请不吝点赞 订阅 转发 打赏支持明镜与点点栏目'))
        self.assertEqual(len(found), 1, found)
        self.assertEqual(found[0]['why'], 'blocklist match not dropped')

    def test_unknown_boilerplate_fires_on_the_wide_net(self):
        """Boilerplate the DELETING list does not know, and must not.

        The wide net exists precisely for this: the narrow list is narrow
        because it removes, so something has to point at the rest.
        """
        text = '欢迎大家点赞并且关注我们'
        self.assertFalse(TS.is_hallucination(text),
                         'the narrow removal list must not match this')
        self.assertTrue(QA.find_boilerplate(segs(text)))

    def test_sermon_text_is_not_boilerplate(self):
        self.assertEqual(QA.find_boilerplate(CLEAN), [])


class RunOnTests(unittest.TestCase):
    def test_long_unpunctuated_run_fires(self):
        # A literal, NOT `QA.RUNON_CHARS + 10`. Sizing the sample from the
        # constant makes the test move with the threshold, so raising the
        # threshold to a million still passed and the mutation harness
        # caught it. A guard test must not read the guard's own dial.
        self.assertTrue(QA.find_runons('神' * 400))

    def test_newlines_do_not_count_as_sentence_stops(self):
        """The bug this check had until it was measured.

        The sidecar stores one ~11-character segment per line. Counting a
        newline as a stop made every run 11 characters long and the check
        reported zero for a file with 59 stops per 10 000 characters.
        """
        text = '\n'.join(['神' * 10] * 40)
        self.assertTrue(QA.find_runons(text))

    def test_punctuated_text_is_clean(self):
        self.assertEqual(QA.find_runons('。'.join(['神' * 20] * 20)), [])


class ThinTests(unittest.TestCase):
    def test_near_empty_output_fires(self):
        self.assertTrue(QA.find_thin('只有几个字', 1800.0))

    def test_empty_output_with_no_duration_fires(self):
        self.assertTrue(QA.find_thin('', None))

    def test_normal_density_is_clean(self):
        self.assertEqual(QA.find_thin('神' * 5000, 1740.0), [])


class NonChineseTests(unittest.TestCase):
    def test_english_segment_fires(self):
        self.assertTrue(QA.find_non_chinese(
            segs('Thank you for watching this video')))

    def test_chinese_segment_is_clean(self):
        self.assertEqual(QA.find_non_chinese(CLEAN), [])


# ── transcriber tests ───────────────────────────────────────────────

class TranscriberEditTests(unittest.TestCase):
    def test_boilerplate_is_dropped_only_as_a_whole_segment(self):
        self.assertTrue(TS.is_hallucination('请不吝点赞 订阅 转发 打赏支持明镜与点点栏目'))
        # CM03, 4 times. Its 33-character English tail is why the length
        # bound on this pattern is 40 and not the 12 first written.
        self.assertTrue(TS.is_hallucination(
            '优优独播剧场——YoYo Television Series Exclusive'))
        # The same words INSIDE real speech must survive: deleting a
        # substring would silently edit the preacher.
        self.assertFalse(TS.is_hallucination(
            '保罗说我们不是打赏支持神的国度而是把自己献上'))

    def test_punctuation_normalisation_moves_no_character_but_the_mark(self):
        out, moved = TS.normalise_punct('是的,真的?对!')
        self.assertEqual(out, '是的，真的？对！')
        self.assertEqual(moved, 3)

    def test_paragraphs_join_with_a_space_never_a_comma(self):
        p = TS.paragraphs(segs('这是第一句', '这是第二句'))
        self.assertEqual(p, ['这是第一句 这是第二句'])
        self.assertNotIn('，', p[0])

    def test_paragraphs_respect_the_hard_cap(self):
        many = segs(*(['神' * 20] * 60))
        for line in TS.paragraphs(many):
            self.assertLessEqual(len(line), TS.PARA_HARD_CHARS + 40)

    def test_paragraphs_never_emit_a_blank_line(self):
        p = TS.paragraphs(segs('一', '', '二'))
        self.assertTrue(all(line.strip() for line in p), p)

    def test_the_machine_note_names_the_model_and_the_date(self):
        note = TS.NOTE_MACHINE.format(model=TS.MODEL_NAME, date='2026-09-06')
        self.assertIn('机器转录', note)
        self.assertIn('ggml-large-v3', note)
        self.assertIn('2026-09-06', note)
        self.assertTrue(note.startswith('[注：'))


# ── seam tests ──────────────────────────────────────────────────────

class SeamTests(unittest.TestCase):
    """The produced body must survive the real merge function."""

    def setUp(self):
        self.bodies = os.path.join(REPO, 'assets', 'sermon_library', 'bodies')
        self.tr = os.path.join(REPO, 'assets', 'sermon_library', 'transcripts')
        if not os.path.isdir(self.tr):
            self.skipTest('no transcripts produced yet')
        self.sidecars = [f for f in sorted(os.listdir(self.tr))
                         if f.endswith('.json')
                         and f not in ('index.json', 'qa_report.json')]
        if not self.sidecars:
            self.skipTest('no transcripts produced yet')

    def test_every_transcribed_body_passes_the_merge_converter(self):
        M = _merge_module()
        for name in self.sidecars:
            sid = name[:-5]
            with self.subTest(sid=sid):
                side = json.load(open(os.path.join(self.tr, name),
                                      encoding='utf-8'))
                path = os.path.join(self.bodies, f'{sid}.txt')
                self.assertTrue(os.path.exists(path), path)
                raw = open(path, encoding='utf-8').read()
                out = M.library_body_to_app_body(raw, side['title'],
                                                 side['refcode'])
                self.assertTrue(out.startswith(f"# {side['title']}\n\n"))
                # The provenance mark is the FIRST paragraph after the H1,
                # because the body text is the only thing the merge carries.
                paras = out.split('\n\n')
                self.assertTrue(paras[1].startswith('[注：'), paras[1][:60])
                self.assertIn('机器转录', paras[1])
                self.assertIn(TS.MODEL_NAME, paras[1])
                # …and it survives the Traditional conversion too.
                self.assertIn('機器轉錄', M.to_traditional(out))

    def test_the_proofreading_timestamps_never_reach_the_body(self):
        """The reading copy carries [h:mm:ss]; the shipped body must not."""
        import re as _re
        stamp = _re.compile(r'\[\d+:\d{2}:\d{2}\]')
        for name in self.sidecars:
            sid = name[:-5]
            with self.subTest(sid=sid):
                body = open(os.path.join(self.bodies, f'{sid}.txt'),
                            encoding='utf-8').read()
                self.assertIsNone(stamp.search(body))
                self.assertNotIn('此标记不进入正文', body)
                reading = os.path.join(self.tr, f'{sid}.txt')
                if os.path.exists(reading):
                    self.assertTrue(
                        stamp.search(open(reading, encoding='utf-8').read()),
                        'the reading copy should carry them')

    def test_every_sidecar_says_it_is_machine_output(self):
        for name in self.sidecars:
            with self.subTest(sid=name):
                d = json.load(open(os.path.join(self.tr, name),
                                   encoding='utf-8'))
                t = d['transcription']
                self.assertEqual(t['kind'], 'machine')
                self.assertIs(t['notHuman'], True)
                self.assertEqual(t['model'], TS.MODEL_NAME)
                # The point of this guard is that a machine transcript must
                # never be able to pass for a human one. 'assisted' is
                # honest — an agent read it against the bundled CUV — and
                # 'human' would be the lie, so THAT is what is forbidden,
                # rather than pinning the field to a single value that a
                # later proofreading pass has to edit the test to change.
                self.assertIn(t['proofread'], ('none', 'assisted'))
                if t['proofread'] == 'none':
                    self.assertIsNone(t['proofreadBy'])
                else:
                    self.assertIn('not a human', t['proofreadBy'])
                    self.assertGreater(t['proofreadFixes'], 0)


# ── the mutation harness ────────────────────────────────────────────

class MutationHarness(unittest.TestCase):
    """Break each guard; the test that maps to it must go red.

    Each entry is (label, module, attribute, broken value, TestCase,
    method). The value is restored afterwards whatever happens.
    """

    MUTATIONS = [
        ('loop: raise the consecutive-run bar out of reach',
         QA, 'LOOP_MIN_RUN', 10**6, LoopTests, 'test_segment_repeat_fires'),
        ('loop: raise the n-gram repeat bar out of reach',
         QA, 'LOOP_NGRAM_MIN_REPEATS', 10**6, LoopTests,
         'test_ngram_repeat_inside_one_segment_fires'),
        ('badref: make every chapter and verse exist',
         QA.ESR, 'exists', staticmethod(lambda *a, **k: True), BadRefTests,
         'test_impossible_chapter_fires'),
        ('badref: pretend every book has many chapters, so the '
         'one-chapter rule stops applying',
         QA.ESR, 'CANON', {**QA.ESR.CANON,
                           'Jude': {c: {1} for c in range(1, 60)}},
         BadRefTests,
         'test_a_verse_of_a_one_chapter_book_is_not_an_impossible_chapter'),
        ('bookname: require an exact match, so no near-miss is a near-miss',
         QA, '_one_edit_apart', staticmethod(lambda a, b: False),
         BookNameTests, 'test_one_character_wrong_in_citation_position_fires'),
        ('bookname: accept any tail, so citation position stops mattering',
         QA, '_CITE_TAIL', __import__('re').compile(r''),
         BookNameTests,
         'test_a_near_miss_outside_citation_position_is_not_reported'),
        ('gap: raise the gap floor past any hole',
         QA, 'GAP_SEC', 10**6, GapTests, 'test_hole_in_the_timeline_fires'),
        ('gap: raise the gap floor past a tail dropout',
         QA, 'GAP_SEC', 10**6, GapTests, 'test_tail_dropout_fires'),
        ('boilerplate: neuter the transcriber blocklist the QA net reuses',
         TS, '_HALL_RE', __import__('re').compile(r'^(?!x)x$'),
         BoilerplateTests, 'test_residual_exact_boilerplate_is_named_as_such'),
        ('boilerplate: empty the wide substring net',
         QA, 'SUSPECT_SUBSTRINGS', [], BoilerplateTests,
         'test_unknown_boilerplate_fires_on_the_wide_net'),
        ('runon: raise the run-on length past the sample',
         QA, 'RUNON_CHARS', 10**6, RunOnTests,
         'test_long_unpunctuated_run_fires'),
        # Mutating `_SENT_STOP` alone does NOT restore the bug, because
        # find_runons strips the newlines before the scan — which is
        # itself worth knowing, and is why the mutation replaces the
        # whole function with the version that had the bug.
        ('runon: put back the version that scanned the newlines',
         QA, 'find_runons', staticmethod(_runons_with_newlines),
         RunOnTests, 'test_newlines_do_not_count_as_sentence_stops'),
        ('thin: drop the characters-per-minute floor to zero',
         QA, 'THIN_CHARS_PER_MIN', 0, ThinTests,
         'test_near_empty_output_fires'),
        ('nonzh: require an impossible CJK ratio to pass',
         QA, 'NONZH_CJK_RATIO', 0.0, NonChineseTests,
         'test_english_segment_fires'),
        ('transcriber: neuter the hallucination blocklist',
         TS, '_HALL_RE', __import__('re').compile(r'^(?!x)x$'),
         TranscriberEditTests,
         'test_boilerplate_is_dropped_only_as_a_whole_segment'),
        ('transcriber: normalise nothing',
         TS, 'PUNCT_MAP', {}, TranscriberEditTests,
         'test_punctuation_normalisation_moves_no_character_but_the_mark'),
        ('transcriber: join paragraphs with a comma',
         TS, 'paragraphs',
         staticmethod(lambda s: ['，'.join(x['text'] for x in s)]),
         TranscriberEditTests,
         'test_paragraphs_join_with_a_space_never_a_comma'),
        ('transcriber: strip the model name out of the note',
         TS, 'NOTE_MACHINE', '[注：本篇为转录稿。{date}]',
         TranscriberEditTests,
         'test_the_machine_note_names_the_model_and_the_date'),
    ]

    def test_every_guard_is_load_bearing(self):
        survivors = []
        for label, mod, attr, broken, case, method in self.MUTATIONS:
            original = getattr(mod, attr)
            value = (broken.__func__ if isinstance(broken, staticmethod)
                     else broken)
            setattr(mod, attr, value)
            try:
                result = unittest.TestResult()
                case(method).run(result)
                if result.wasSuccessful():
                    survivors.append(label)
            finally:
                setattr(mod, attr, original)
        self.assertEqual(survivors, [],
                         'these mutations were not caught by any test:\n  '
                         + '\n  '.join(survivors))


if __name__ == '__main__':
    unittest.main(verbosity=2)
