#!/usr/bin/env python3
"""Unit tests for `tools/audit_originals_compounds.py --check` — the
fourth and last census/audit `--check` gate to get one, after
`test/test_audit_p0_check.py` (2026-09-08) and
`test/test_audit_census_checks.py` (2026-09-16, strongs-tagging +
divine-name).

Unlike those three, this gate's PASS can be vacuous: `--check` exits 0
both when the corpus genuinely has no drift AND when `.cache/originals/`
is cold, and the only thing distinguishing the two on stdout is the word
`SKIP:` (see `tools/audit_originals_compounds.py:198-206`). This file's
job is narrower than the other three's: prove those two exit-0 paths are
actually different, and that the drift-reporting path (return 1, refs
listed, truncated at 20) works. `cache_ready`/`hebrew_drift`/
`greek_drift` are monkeypatched on the loaded module so every test runs
in milliseconds, touches no real corpus and no `.cache/`, and can assert
that a cold cache never even calls the two `*_drift()` functions.

This gate is deliberately NOT wired into CI (see flutter-ci.yml's own
comment at the P0 step) — a bare runner's cache is always cold, so
running it there would always vacuously SKIP. This test file has no such
problem: it never touches `.cache/originals/` at all, so it runs
unconditionally like its three siblings.

Run:
    python3 -m unittest discover -s test -p 'test_*.py' -v
    python3 test/test_audit_compounds_check.py      # same thing
"""
import contextlib
import importlib.util
import io
import os
import sys
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(REPO, 'tools', 'audit_originals_compounds.py')

_spec = importlib.util.spec_from_file_location('audit_originals_compounds', SCRIPT)
audit_originals_compounds = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(audit_originals_compounds)


class CheckFixture(unittest.TestCase):
    """Stubs `cache_ready`/`hebrew_drift`/`greek_drift` on the loaded
    module and drives `main()` with `sys.argv` set to `--check`, since
    the check logic lives inline in `main()`'s `--check` branch rather
    than in a standalone `check()` like the other three gates."""

    def setUp(self):
        self._orig_cache_ready = audit_originals_compounds.cache_ready
        self._orig_hebrew_drift = audit_originals_compounds.hebrew_drift
        self._orig_greek_drift = audit_originals_compounds.greek_drift
        self._orig_argv = sys.argv
        self.addCleanup(self._restore)

    def _restore(self):
        audit_originals_compounds.cache_ready = self._orig_cache_ready
        audit_originals_compounds.hebrew_drift = self._orig_hebrew_drift
        audit_originals_compounds.greek_drift = self._orig_greek_drift
        sys.argv = self._orig_argv

    def _run_check(self, cache_ready, hebrew_refs=None, greek_refs=None):
        """`hebrew_refs`/`greek_refs` left as `None` means the cold-cache
        path is expected to never call that function at all — call it and
        the stub raises, failing the test."""
        audit_originals_compounds.cache_ready = lambda: cache_ready

        def _unexpected(which):
            def _raise():
                raise AssertionError(
                    f'{which}_drift() called despite a cold cache')
            return _raise

        audit_originals_compounds.hebrew_drift = (
            (lambda refs=list(hebrew_refs): refs) if hebrew_refs is not None
            else _unexpected('hebrew'))
        audit_originals_compounds.greek_drift = (
            (lambda refs=list(greek_refs): refs) if greek_refs is not None
            else _unexpected('greek'))

        sys.argv = ['audit_originals_compounds.py', '--check']
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            result = audit_originals_compounds.main()
        return result, buf.getvalue()


class ColdCache(CheckFixture):
    def test_cold_cache_skips_without_measuring(self):
        """The vacuous-pass path this whole file exists to pin: exit 0,
        `SKIP:` on stdout, and — the part a bare exit-code check can't
        see — neither `*_drift()` function is even called."""
        result, out = self._run_check(cache_ready=False)
        self.assertEqual(result, 0)
        self.assertIn('SKIP:', out)


class WarmNoDrift(CheckFixture):
    def test_warm_cache_no_drift_returns_zero(self):
        result, out = self._run_check(
            cache_ready=True, hebrew_refs=[], greek_refs=[])
        self.assertEqual(result, 0)
        self.assertIn('0 drift', out)
        self.assertNotIn('SKIP:', out)


class WarmWithDrift(CheckFixture):
    def test_warm_cache_with_drift_lists_both_languages(self):
        """`drift = hebrew_drift() + greek_drift()` (main()'s own
        concatenation) — proves both contributions actually reach the
        printed list, not just whichever one a lazier check might
        short-circuit on."""
        hebrew_refs = ['Genesis 1:1', 'Genesis 1:2']
        greek_refs = ['Matthew 1:1']
        result, out = self._run_check(
            cache_ready=True, hebrew_refs=hebrew_refs, greek_refs=greek_refs)
        self.assertEqual(result, 1)
        self.assertIn('FAIL: 3 shipped verse(s)', out)
        for ref in hebrew_refs + greek_refs:
            self.assertIn(ref, out)


class TruncationBranch(CheckFixture):
    def test_more_than_twenty_refs_truncates_with_count(self):
        hebrew_refs = [f'Genesis 1:{i}' for i in range(1, 16)]  # 15
        greek_refs = [f'Matthew 1:{i}' for i in range(1, 11)]   # 10
        result, out = self._run_check(
            cache_ready=True, hebrew_refs=hebrew_refs, greek_refs=greek_refs)

        self.assertEqual(result, 1)
        self.assertIn('FAIL: 25 shipped verse(s)', out)
        printed = [line.strip() for line in out.splitlines()
                   if line.strip().startswith(('Genesis', 'Matthew'))]
        self.assertEqual(len(printed), 20)
        self.assertIn('… 5 more', out)


if __name__ == '__main__':
    unittest.main()
