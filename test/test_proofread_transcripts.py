"""Guards for the proofreading corrections and, above all, for their WIRING.

The defect this file exists because of: the corrections used to live only
in `assets/sermon_library/bodies/`, which is gitignored. Measured
2026-09-06, `transcribe_sermons.py --force` — advertised in its own
docstring as the cheap way to change an edit rule — would have silently
discarded proofreading in 12 of the 16 bodies. Nothing would have gone
red. So the load-bearing test here is not that the table is well formed;
it is `test_build_actually_applies_them`, which breaks if the call in
`build()` is ever removed.
"""
import os
import sys
import unittest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'scripts'))

import proofread_transcripts as PR  # noqa: E402

_ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), '..'))
_BODIES = os.path.join(_ROOT, 'assets', 'sermon_library', 'bodies')
_HAVE_BODIES = os.path.isdir(_BODIES)
_WHY = ('assets/sermon_library/bodies is gitignored and absent — '
        'regenerate it with scripts/transcribe_sermons.py to run these. '
        'A green run without it has checked NOTHING about the corpus.')


class TableShape(unittest.TestCase):
    """These need no corpus, so they run everywhere, CI included."""

    def test_no_fix_is_a_no_op(self):
        for sid, fixes in PR.FIXES.items():
            for f in fixes:
                with self.subTest(sid=sid, old=f.old):
                    self.assertNotEqual(f.old, f.new)
                    self.assertTrue(f.old, 'an empty `old` matches everywhere')
                    self.assertGreater(f.n, 0)
                    self.assertIn(f.kind, (PR.BOOK, PR.SCRIPTURE,
                                           PR.SENSE, PR.REMOVED))

    def test_a_wrong_count_raises_rather_than_passing_silently(self):
        """The whole safety property. A fix that matches nothing is
        indistinguishable from no proofreading at all, so it must be
        loud."""
        body = '甲乙丙甲乙丙\n'
        table = {'X': [PR.Fix('甲乙', '丁戊', 2, PR.SENSE)]}
        old = PR.FIXES
        try:
            PR.FIXES = table
            self.assertEqual(PR.apply('X', body)[0], '丁戊丙丁戊丙\n')
            # one occurrence too few in the text
            with self.assertRaises(PR.ProofreadError):
                PR.apply('X', '甲乙丙\n')
            # and one too many
            with self.assertRaises(PR.ProofreadError):
                PR.apply('X', '甲乙甲乙甲乙\n')
        finally:
            PR.FIXES = old

    def test_the_raise_names_the_fix_and_both_counts(self):
        old = PR.FIXES
        try:
            PR.FIXES = {'X': [PR.Fix('甲乙', '丁戊', 7, PR.SENSE)]}
            with self.assertRaises(PR.ProofreadError) as cm:
                PR.apply('X', '甲乙\n')
            msg = str(cm.exception)
            for part in ('甲乙', '丁戊', '7', 'found 1'):
                self.assertIn(part, msg)
        finally:
            PR.FIXES = old

    def test_an_inserting_fix_does_not_report_itself_uncorrected(self):
        """「因如此」 -> 「正因如此」 leaves `old` inside `new`."""
        old = PR.FIXES
        try:
            PR.FIXES = {'X': [PR.Fix('因如此', '正因如此', 1, PR.SENSE)]}
            self.assertEqual(PR.check('X', '正因如此\n'), [])
            self.assertNotEqual(PR.check('X', '甚麼都沒有\n'), [])
        finally:
            PR.FIXES = old


@unittest.skipUnless(_HAVE_BODIES, _WHY)
class AgainstTheCorpus(unittest.TestCase):

    def _body(self, sid):
        with open(os.path.join(_BODIES, f'{sid}.txt'), encoding='utf-8') as f:
            return f.read()

    def test_every_body_carries_its_corrections(self):
        for sid in PR.FIXES:
            with self.subTest(sid=sid):
                self.assertEqual(PR.check(sid, self._body(sid)), [])

    def test_build_actually_applies_them(self):
        """The regression. Rebuild a body the way `build()` does and
        assert the result differs from the raw decode in exactly the way
        the table says. If the `PROOFREAD.apply` call in `build()` is
        deleted, this goes red — which is what did NOT happen before.
        """
        import json
        import datetime
        import transcribe_sermons as TS
        from transcribe_targets import (targets, load_index, audio_path)

        recs = {str(r['id']): r for r in targets(load_index())}
        sid = '4259'  # 26 pass-2 fixes, the most of any Romans file
        self.assertIn(sid, recs)
        rec = recs[sid]
        side_p = os.path.join(TS.TRANSCRIPTS, f'{sid}.json')
        if not os.path.exists(side_p):
            self.skipTest('sidecar absent')
        side = json.load(open(side_p, encoding='utf-8'))
        day = (side['transcription'].get('transcribedAt')
               or datetime.date.today().isoformat())
        parts = []
        for i in range(len(rec['audioUrls'])):
            raw = os.path.join(TS.RAW_DIR, f'{audio_path(rec, i).stem}.json')
            if not os.path.exists(raw):
                self.skipTest('raw decode cache absent')
            d = json.load(open(raw, encoding='utf-8'))
            segs, edits = TS.postprocess(d['segments'])
            parts.append({**d, 'segments': segs, 'edits': edits})

        body, _reading, sidecar = TS.build(rec, parts, day)

        # It matches what is on disk …
        self.assertEqual(body, self._body(sid))
        # … it is NOT the raw text …
        #
        # 2026-09-07: the fixes are counted against the text WITHOUT the
        # note. `build` composes the note after `apply` has run, because
        # the note now states how many places were corrected — so a fix
        # can no longer match inside it and quietly spend one of its
        # expected occurrences there. Reproduce that shape here.
        raw_join = '\n'.join(
            [rec['title']]
            + [t for p in parts for _, t in TS.timed_paragraphs(p['segments'])]
        ) + '\n'
        # Strip every `[注：…]` back out of the built body — the machine
        # note and any seam notes — and what is left differs from the raw
        # decode by the corrections and nothing else. Comparing the
        # note-bearing body instead would differ whether or not a single
        # correction had been made, which is not a check.
        body_no_notes = '\n'.join(
            ln for ln in body.splitlines() if not ln.startswith('[注：')) + '\n'
        self.assertNotEqual(body_no_notes, raw_join)
        # … and every single fix for this file is accounted for.
        for f in PR.FIXES[sid]:
            with self.subTest(old=f.old):
                self.assertEqual(raw_join.count(f.old), f.n)
                if f.old not in f.new:
                    self.assertNotIn(f.old, body)
        self.assertEqual(sidecar['transcription']['proofread'], 'assisted')
        self.assertEqual(sidecar['transcription']['proofreadFixes'],
                         len(PR.FIXES[sid]))

    def test_a_machine_transcript_never_claims_a_human_proofreader(self):
        import json
        tr = os.path.join(_ROOT, 'assets', 'sermon_library', 'transcripts')
        if not os.path.isdir(tr):
            self.skipTest('transcripts/ absent')
        seen = 0
        for name in sorted(os.listdir(tr)):
            if not name.endswith('.json') or name in ('index.json',
                                                      'qa_report.json'):
                continue
            t = json.load(open(os.path.join(tr, name),
                               encoding='utf-8'))['transcription']
            with self.subTest(sid=name):
                self.assertIs(t['notHuman'], True)
                self.assertNotEqual(t['proofread'], 'human')
                if t['proofreadBy']:
                    self.assertIn('not a human', t['proofreadBy'])
            seen += 1
        self.assertGreater(seen, 0, 'no sidecars were checked')


if __name__ == '__main__':
    unittest.main()
