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


class TheTrackedDecisionActuallyReachesTheMerge(unittest.TestCase):
    """The gap this closes, found 2026-09-07.

    `scripts/adjudicate_cross_corpus_duplicates.py` is TRACKED and holds
    every verdict. `assets/sermon_library/refs.json` is GITIGNORED and is
    what `merge_sermon_library.py` actually reads. Nothing compared them.

    So a regeneration of refs.json that skipped the adjudication script
    would silently drop every verdict, and the one that costs something
    is 6012/CP37: back at `refuted`, the merge sends 6012 down the
    NEW-record path and ships 活着就是基督 twice, at 430. The corpus would
    be wrong and every count in the suite would still be green, because
    every count is pinned to a number that the same regeneration moves.

    This is the same shape as the day's other three: a decision living
    where nothing checks it. `docs/` remembers it, git does not.
    """

    @unittest.skipUnless(_AVAILABLE, _WHY)
    def test_every_tracked_verdict_is_present_in_refs_json(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location(
            'adj', REPO / 'scripts' / 'adjudicate_cross_corpus_duplicates.py')
        adj = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(adj)

        by_key = {f"{r.get('libId')}|{r.get('appId')}": r for r in ROWS}
        missing, disagreed = [], []
        for key, (tier, comp, verdict, _ev) in adj.A.items():
            row = by_key.get(key)
            if row is None:
                missing.append(key)
                continue
            if (row.get('tier'), row.get('completeness'),
                    row.get('verdict')) != (tier, comp, verdict):
                disagreed.append(
                    f"{key}: refs.json says "
                    f"{row.get('tier')}/{row.get('completeness')}/"
                    f"{row.get('verdict')}, the tracked table says "
                    f"{tier}/{comp}/{verdict}")
        self.assertEqual(missing, [], 'adjudicated pairs absent from refs.json')
        self.assertEqual(
            disagreed, [],
            'refs.json disagrees with the tracked adjudication — it was '
            'regenerated without `python3 scripts/'
            'adjudicate_cross_corpus_duplicates.py`. Run it.')

    def test_the_corpus_ships_that_sermon_exactly_once(self):
        """The outcome, asserted instead of the mechanism.

        This reads `assets/sermons/index.json`, which is TRACKED, so
        unlike everything above it also runs on a machine that has never
        seen the staging library — including CI.
        """
        shipped = REPO / 'assets' / 'sermons' / 'index.json'
        if not shipped.exists():
            self.skipTest('assets/sermons/index.json absent')
        rows = json.load(open(shipped, encoding='utf-8'))
        titled = [r['id'] for r in rows
                  if (r.get('titles') or {}).get('zh-CN') == '活着就是基督']
        self.assertEqual(
            titled, ['CP37'],
            '活着就是基督 must appear once, as CP37. Two ids means library '
            '6012 was merged as a NEW record instead of replacing CP37\'s '
            'Chinese body — check the 6012|CP37 row is still '
            'confirmed/library-fuller.')
