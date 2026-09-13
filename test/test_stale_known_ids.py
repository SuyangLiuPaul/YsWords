#!/usr/bin/env python3
"""Tests for `tools/audit_inserted_characters.stale_known_ids` — the split
between an EXPLAINED/PENDING id that has genuinely stopped reading long
(`gone`, update the entry) and one that merely moved from the `running`
bucket into the `apparatus` bucket (`moved`, the entry still stands).

Regression for the 2026-09-09 bug: `064001014` (約翰三書 1:14) is still
`〔15节...〕`-long at HEAD, but when `apparatus_mask` was taught to recognise
`〔…〕` as well as `<note:…>`, the hit moved out of `running` into
`apparatus` and the OLD `gone = known - {id for id, _ in running}` computation
started reporting it as "no longer reads long" — false, since it never left
`apparatus`. `test_moved_to_apparatus_is_not_gone` pins that this id is
`moved`, not `gone`.

Pure-function test only: `compute()` reads all 31,102 verses and shells out
to `git`/`opencc`, so it does not belong in a test — these fixtures are
hand-built `(id, agreed)` pairs in the same shape `compute()` returns.
"""
import importlib.util
import os
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(REPO, 'tools', 'audit_inserted_characters.py')

_spec = importlib.util.spec_from_file_location('audit_inserted_characters', SCRIPT)
aic = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(aic)


class StaleKnownIds(unittest.TestCase):
    def test_moved_to_apparatus_is_not_gone(self):
        """The 2026-09-09 regression, reproduced hermetically: an id present
        in `apparatus` but absent from `running` must be `moved`, not `gone`."""
        known = {'064001014'}
        running = []
        apparatus = [('064001014', ((15, 'x'),))]
        gone, moved = aic.stale_known_ids(known, running, apparatus)
        self.assertEqual(gone, [])
        self.assertEqual(moved, ['064001014'])

    def test_absent_from_both_is_gone(self):
        known = {'016001002'}
        running = []
        apparatus = []
        gone, moved = aic.stale_known_ids(known, running, apparatus)
        self.assertEqual(gone, ['016001002'])
        self.assertEqual(moved, [])

    def test_still_in_running_is_neither(self):
        known = {'041006033'}
        running = [('041006033', ((19, '的'),))]
        apparatus = []
        gone, moved = aic.stale_known_ids(known, running, apparatus)
        self.assertEqual(gone, [])
        self.assertEqual(moved, [])

    def test_mixed_batch_sorted_independently(self):
        known = {'gone-id', 'moved-id', 'running-id'}
        running = [('running-id', ((0, 'x'),))]
        apparatus = [('moved-id', ((0, 'y'),))]
        gone, moved = aic.stale_known_ids(known, running, apparatus)
        self.assertEqual(gone, ['gone-id'])
        self.assertEqual(moved, ['moved-id'])


if __name__ == '__main__':
    unittest.main()
