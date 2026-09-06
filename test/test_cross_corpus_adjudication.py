#!/usr/bin/env python3
"""Invariants over the 2026-09-06 adjudication of `crossCorpus`.

Run:
    python3 test/test_cross_corpus_adjudication.py

These guard the FILE, not the script that wrote it. The verdicts are
judgements a rerun cannot re-derive, so what is testable is that the
file stays internally coherent and that the two facts a downstream
text-replacement pass would be harmed by never quietly go missing:
that `completeness` is present wherever a pair is confirmed, and that
no confirmed pair points at a library record with no body.
"""
import json, pathlib, unittest

REPO = pathlib.Path(__file__).resolve().parent.parent

# `assets/sermon_library/` is a gitignored local staging area — the app
# ships Pastor Eric Chang's sermons only, merged into assets/sermons/,
# and the 940-record library stays on disk. So a fresh clone, and every
# CI run, has no such directory.
#
# Loading it at MODULE level made this file fail to IMPORT there, which
# is worse than a failing test: unittest reports it as an error before
# any assertion runs, and it took CI red on 2026-09-06 while a local run
# stayed green because the files were sitting on one machine's disk.
# Guard the load, and skip with a reason that says what is missing
# rather than pretending the suite covered something it could not see.
_REFS_PATH = REPO / 'assets/sermon_library/refs.json'
_INDEX_PATH = REPO / 'assets/sermon_library/index.json'
_AVAILABLE = _REFS_PATH.exists() and _INDEX_PATH.exists()
_WHY = ('assets/sermon_library/ is gitignored and absent — regenerate it '
        'with scripts/sync_sermon_library.py to run these. A green run '
        'without it has checked NOTHING in this file.')

if _AVAILABLE:
    REFS = json.load(open(_REFS_PATH))
    INDEX = json.load(open(_INDEX_PATH))
    ROWS = REFS['duplicates']['crossCorpus']
    LIB = {str(s['id']): s for s in INDEX['sermons']}
else:
    REFS = INDEX = {}
    ROWS = []
    LIB = {}

VOCAB = {'complete', 'library-partial', 'library-fuller', 'unknown',
         'no-library-body'}


@unittest.skipUnless(_AVAILABLE, _WHY)
@unittest.skipUnless(_AVAILABLE, _WHY)
class Shape(unittest.TestCase):
    def test_the_row_count_is_unchanged(self):
        """Adjudication regrades rows. It never adds or drops one."""
        self.assertEqual(len(ROWS), 105)

    def test_every_row_still_carries_its_original_fields(self):
        for r in ROWS:
            for k in ('libId', 'appId', 'tier', 'titleSim', 'sharedChapters',
                      'seriesRisk', 'fingerprintAvailable', 'basis'):
                self.assertIn(k, r, f"{r['libId']}/{r['appId']} lost {k}")


@unittest.skipUnless(_AVAILABLE, _WHY)
class Completeness(unittest.TestCase):
    def test_every_confirmed_pair_states_its_completeness(self):
        """A confirmed pair with no completeness is the silent case.

        Two sermons can be the same sermon and still be a bad swap.
        A downstream pass reading `tier` alone would not know that; the
        field is only protective if it is never absent where it counts.
        """
        for r in ROWS:
            if r['tier'] == 'confirmed':
                self.assertIn('completeness', r,
                              f"confirmed {r['libId']}/{r['appId']} states no completeness")

    def test_completeness_uses_only_the_declared_vocabulary(self):
        declared = set(REFS['_meta']['adjudication']['completenessVocabulary'])
        self.assertEqual(declared, VOCAB)
        for r in ROWS:
            if 'completeness' in r:
                self.assertIn(r['completeness'], VOCAB,
                              f"{r['libId']}/{r['appId']} uses an undeclared value")

    def test_a_bodyless_library_record_is_never_confirmed(self):
        """The trap this pass found in the inherited `confirmed` tier.

        Library 6012 was graded `confirmed` on exact title alone, with
        no body and no fingerprint. Under a rule that promotes the
        library text over the app's, that pair substitutes nothing for
        11k characters. Whatever else moves, this must not come back.
        """
        for r in ROWS:
            if r['tier'] != 'confirmed':
                continue
            rec = LIB.get(r['libId'])
            self.assertIsNotNone(rec, f"unknown library id {r['libId']}")
            self.assertTrue(rec.get('hasBody') and rec.get('bodyFile'),
                            f"confirmed {r['libId']}/{r['appId']} has no library body")

    def test_no_library_body_is_reserved_for_records_with_no_body(self):
        for r in ROWS:
            if r.get('completeness') == 'no-library-body':
                self.assertFalse(LIB[r['libId']].get('hasBody'))


@unittest.skipUnless(_AVAILABLE, _WHY)
class Verdicts(unittest.TestCase):
    def test_the_probable_tier_was_fully_adjudicated(self):
        """No row is left saying `probable`: each got a verdict."""
        self.assertEqual([r for r in ROWS if r['tier'] == 'probable'], [])

    def test_every_adjudicated_row_carries_a_verdict_and_evidence(self):
        for r in ROWS:
            if 'verdict' not in r:
                continue
            self.assertIn(r['verdict'], {'SAME', 'DIFFERENT', 'UNRESOLVED', 'UNUSABLE'})
            self.assertTrue(r.get('evidence', '').strip(),
                            f"{r['libId']}/{r['appId']} has a verdict but no evidence")
            self.assertEqual(r.get('adjudicatedOn'), '2026-09-06')

    def test_the_untouched_tiers_were_left_alone(self):
        """`possible` and `weak` were out of scope and stay unjudged."""
        for r in ROWS:
            if r['tier'] in ('possible', 'weak'):
                self.assertNotIn('verdict', r)
        self.assertEqual(sum(r['tier'] == 'weak' for r in ROWS), 43)
        self.assertEqual(sum(r['tier'] == 'possible' for r in ROWS), 4)

    def test_a_refuted_pair_is_not_also_a_confirmed_one(self):
        conf = {(r['libId'], r['appId']) for r in ROWS if r['tier'] == 'confirmed'}
        ref = {(r['libId'], r['appId']) for r in ROWS if r['tier'] == 'refuted'}
        self.assertEqual(conf & ref, set())


if __name__ == '__main__':
    unittest.main(verbosity=2)
