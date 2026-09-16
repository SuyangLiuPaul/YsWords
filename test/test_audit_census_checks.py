#!/usr/bin/env python3
"""Unit tests for the two CI census `--check` gates that had none until
now: `tools/audit_divine_name.py` and `tools/audit_strongs_tagging.py`.

`test/test_audit_p0_check.py` already covers the third `--check` gate
(`tools/audit_p0.py`); `tools/audit_originals_compounds.py`'s `--check`
is deliberately not wired into CI at all (see `flutter-ci.yml`'s comment
at its P0 step) and has no test here for the same reason.

Both gates under test share a shape: a `check()` that recomputes a
census/comparison over the real corpus and diffs it against a module-level
`PINNED` dict, printing `pinned N, measured M (delta ±D)` and returning 1
on any mismatch. What is untested — and what breaks silently if it ever
regresses — is that comparison/reporting logic, not the corpus itself:
CI's own `--check` invocations already exercise the real corpus on every
push, so re-walking it here would only prove the Mac agrees with itself.
Both `census()`/`reconcile()` (divine-name) and `_compute()`
(strongs-tagging) are monkeypatched to return small synthetic dicts
instead, so each test runs in milliseconds and pins the comparison logic
independently of corpus drift.

Run:
    python3 -m unittest discover -s test -p 'test_*.py' -v
    python3 test/test_audit_census_checks.py        # same thing
"""
import contextlib
import importlib.util
import io
import os
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _load(name, relpath):
    spec = importlib.util.spec_from_file_location(name, os.path.join(REPO, relpath))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


audit_divine_name = _load('audit_divine_name', os.path.join('tools', 'audit_divine_name.py'))
audit_strongs_tagging = _load('audit_strongs_tagging', os.path.join('tools', 'audit_strongs_tagging.py'))


# --- tools/audit_divine_name.py --------------------------------------------

class DivineNameCheckFixture(unittest.TestCase):
    """Stubs `census()`/`reconcile()` with functions returning lists of the
    requested LENGTH (check() only ever calls `len()` on their values), so
    a test controls the measured counts without touching
    assets/tagged/cuvs-yhwh/ or assets/originals/ at all."""

    def setUp(self):
        self._orig_census = audit_divine_name.census
        self._orig_reconcile = audit_divine_name.reconcile
        self.addCleanup(self._restore)

    def _restore(self):
        audit_divine_name.census = self._orig_census
        audit_divine_name.reconcile = self._orig_reconcile

    @staticmethod
    def _buckets(counts):
        return {key: [('book', f'{key}:{i}') for i in range(n)]
                for key, n in counts.items()}

    def _stub(self, census_counts, reconcile_counts):
        audit_divine_name.census = lambda: self._buckets(census_counts)
        audit_divine_name.reconcile = lambda: self._buckets(reconcile_counts)

    def _run_check(self):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            result = audit_divine_name.check()
        return result, buf.getvalue()


class DivineNameCheckMatching(DivineNameCheckFixture):
    def test_matching_counts_return_zero(self):
        self._stub(dict(audit_divine_name.PINNED),
                   dict(audit_divine_name.PINNED_RECONCILE))
        result, out = self._run_check()
        self.assertEqual(result, 0)
        self.assertIn('OK', out)


class DivineNameCheckCensusPerturbation(DivineNameCheckFixture):
    def test_one_off_census_perturbation_is_caught(self):
        """Perturbs one PINNED key by +1; every PINNED_RECONCILE key still
        matches, so this proves census (not reconcile) drove the failure."""
        census_counts = dict(audit_divine_name.PINNED)
        census_counts['agree'] += 1
        self._stub(census_counts, dict(audit_divine_name.PINNED_RECONCILE))

        result, out = self._run_check()

        self.assertEqual(result, 1)
        want = audit_divine_name.PINNED['agree']
        self.assertIn(
            f'census agree: pinned {want}, measured {want + 1} (delta +1)',
            out)


class DivineNameCheckReconcilePerturbation(DivineNameCheckFixture):
    def test_one_off_reconcile_perturbation_is_caught(self):
        """Mirrors the census test but on PINNED_RECONCILE, which check()
        diffs in a separate loop — a bug isolated to one loop would pass
        the census test above and still slip past here undetected."""
        reconcile_counts = dict(audit_divine_name.PINNED_RECONCILE)
        reconcile_counts['in_disagree_h3068'] -= 1
        self._stub(dict(audit_divine_name.PINNED), reconcile_counts)

        result, out = self._run_check()

        self.assertEqual(result, 1)
        want = audit_divine_name.PINNED_RECONCILE['in_disagree_h3068']
        self.assertIn(
            f'reconcile in_disagree_h3068: pinned {want}, measured {want - 1} '
            f'(delta -1)',
            out)


# --- tools/audit_strongs_tagging.py -----------------------------------------

class StrongsCheckFixture(unittest.TestCase):
    """Stubs `_compute(version, versify)` so check() never runs the real
    counting pass (367,573 runs, twice) — only its comparison against
    PINNED[True] / PINNED[False] is exercised."""

    def setUp(self):
        self._orig_compute = audit_strongs_tagging._compute
        self.addCleanup(self._restore)

    def _restore(self):
        audit_strongs_tagging._compute = self._orig_compute

    @staticmethod
    def _result_for(pinned_versify):
        """A `_compute()`-shaped dict whose derived `actual` values (see
        check()'s own arithmetic: total_runs/total_tagged passed through,
        orphan_occurrences = sum(not_in_verse.values()), left_to_read =
        sum(unexplained.values()), left_to_read_distinct =
        len(unexplained)) equal `pinned_versify` exactly."""
        result = {
            'total_runs': pinned_versify['total_runs'],
            'total_tagged': pinned_versify['total_tagged'],
            'not_in_verse': {'ref': pinned_versify['orphan_occurrences']},
            'unexplained': {},
        }
        if 'left_to_read' in pinned_versify:
            distinct = pinned_versify['left_to_read_distinct']
            total = pinned_versify['left_to_read']
            unexplained = {f'H{i}': 1 for i in range(distinct)}
            if distinct:
                unexplained[f'H{distinct - 1}'] += total - distinct
            result['unexplained'] = unexplained
        return result

    def _stub(self, true_pinned, false_pinned):
        results = {True: self._result_for(true_pinned),
                   False: self._result_for(false_pinned)}
        audit_strongs_tagging._compute = lambda version, versify: results[versify]

    def _run_check(self):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            result = audit_strongs_tagging.check()
        return result, buf.getvalue()


class StrongsCheckMatching(StrongsCheckFixture):
    def test_matching_counts_return_zero(self):
        self._stub(dict(audit_strongs_tagging.PINNED[True]),
                   dict(audit_strongs_tagging.PINNED[False]))
        result, out = self._run_check()
        self.assertEqual(result, 0)
        self.assertIn('OK', out)


class StrongsCheckTruePerturbation(StrongsCheckFixture):
    def test_one_off_versify_true_perturbation_is_caught(self):
        """Perturbs a versify=True-only key (left_to_read has no
        counterpart in PINNED[False]) while versify=False still matches
        exactly, isolating the True branch of check()'s per-versify loop."""
        true_pinned = dict(audit_strongs_tagging.PINNED[True])
        true_pinned['left_to_read'] += 1
        self._stub(true_pinned, dict(audit_strongs_tagging.PINNED[False]))

        result, out = self._run_check()

        self.assertEqual(result, 1)
        want = audit_strongs_tagging.PINNED[True]['left_to_read']
        self.assertIn(
            f'versify=True left_to_read: pinned {want}, measured {want + 1} '
            f'(delta +1)',
            out)


class StrongsCheckFalsePerturbation(StrongsCheckFixture):
    def test_one_off_versify_false_perturbation_is_caught(self):
        """The False branch has no left_to_read keys at all — a test that
        only ever perturbed True would leave this half of the gate
        unproven, so this perturbs orphan_occurrences under versify=False
        instead, with versify=True left matching."""
        false_pinned = dict(audit_strongs_tagging.PINNED[False])
        false_pinned['orphan_occurrences'] -= 1
        self._stub(dict(audit_strongs_tagging.PINNED[True]), false_pinned)

        result, out = self._run_check()

        self.assertEqual(result, 1)
        want = audit_strongs_tagging.PINNED[False]['orphan_occurrences']
        self.assertIn(
            f'versify=False orphan_occurrences: pinned {want}, measured '
            f'{want - 1} (delta -1)',
            out)


if __name__ == '__main__':
    unittest.main()
