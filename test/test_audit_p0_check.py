#!/usr/bin/env python3
"""Tests for `tools/audit_p0.py`'s `check()` — the CI gate.

Run:
    python3 -m unittest discover -s test -p 'test_*.py' -v
    python3 test/test_audit_p0_check.py        # same thing

`check()` is imported and driven against synthetic fixtures in tempdirs
(rebinding the module's `TAGGED`/`SERMONS_TW`/`SERMONS_CN` constants), not
the real corpus — the real corpus should always pass, which proves
nothing about whether the check can fail. `test_null_strongs_is_caught`
is the one that matters: it pins the 2026-09-08 fix for a record holding
JSON `"s": null` (as opposed to an absent `"s"` key or an empty string),
which `r.get('s', '')` let through silently because `.get`'s default only
applies when the key is missing — a `None` value passes it through
unchanged, and `if s and ...` then treats `None` the same as "no code"
instead of "malformed code". Confirmed against the pre-fix line before
writing the corrected one: it returned 0 (no problem found) for exactly
this fixture.
"""
import importlib.util
import json
import os
import tempfile
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(REPO, 'tools', 'audit_p0.py')

_spec = importlib.util.spec_from_file_location('audit_p0', SCRIPT)
audit_p0 = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(audit_p0)


class CheckFixture(unittest.TestCase):
    """Rebinds the module's asset paths to a scratch tree per test."""

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        root = self._tmp.name

        self._orig = (audit_p0.TAGGED, audit_p0.SERMONS_TW, audit_p0.SERMONS_CN)

        audit_p0.TAGGED = os.path.join(root, 'tagged')
        audit_p0.SERMONS_TW = os.path.join(root, 'sermons', 'zh-TW')
        audit_p0.SERMONS_CN = os.path.join(root, 'sermons', 'zh-CN')
        os.makedirs(audit_p0.TAGGED)
        os.makedirs(audit_p0.SERMONS_TW)
        os.makedirs(audit_p0.SERMONS_CN)

        self.addCleanup(self._restore)

    def _restore(self):
        audit_p0.TAGGED, audit_p0.SERMONS_TW, audit_p0.SERMONS_CN = self._orig

    def _write_tagged(self, name, verses):
        with open(os.path.join(audit_p0.TAGGED, name), 'w', encoding='utf-8') as fh:
            json.dump(verses, fh, ensure_ascii=False)

    def _write_sermon(self, locale_dir, name):
        with open(os.path.join(locale_dir, name), 'w', encoding='utf-8') as fh:
            fh.write('sermon body')

    def _match_sermons(self, n=1):
        for i in range(n):
            self._write_sermon(audit_p0.SERMONS_TW, f'{i:03d}.txt')
            self._write_sermon(audit_p0.SERMONS_CN, f'{i:03d}.txt')


class NullStrongs(CheckFixture):
    def test_null_strongs_is_caught(self):
        """The regression this item exists for: explicit JSON null."""
        self._match_sermons()
        self._write_tagged('john.json', {'1:1': [{'w': '神', 's': None}]})
        self.assertEqual(audit_p0.check(), 1)

    def test_null_strongs_would_have_slipped_past_the_old_line(self):
        """Proves the fix was load-bearing: replays the pre-2026-09-08
        line and shows it returns 0 (no problem found) for the same
        fixture that test_null_strongs_is_caught now catches."""
        self._match_sermons()
        self._write_tagged('john.json', {'1:1': [{'w': '神', 's': None}]})
        import glob
        import re
        bad = []
        for path in sorted(glob.glob(os.path.join(audit_p0.TAGGED, '*.json'))):
            for vref, runs in audit_p0.load(path).items():
                for r in runs:
                    s = r.get('s', '')  # the old, buggy line
                    if s and not re.fullmatch(r'[GH]\d+', s):
                        bad.append((vref, s))
        self.assertEqual(bad, [], 'old line silently missed the null run')


class CleanCorpus(CheckFixture):
    def test_clean_fixture_returns_zero(self):
        self._match_sermons()
        self._write_tagged('john.json', {
            '1:1': [{'w': '太初', 's': 'H7225'}, {'w': '有', 's': ''}],
            '1:2': [{'w': '道'}],
        })
        self.assertEqual(audit_p0.check(), 0)


class MalformedString(CheckFixture):
    def test_malformed_string_code_is_still_caught(self):
        self._match_sermons()
        self._write_tagged('john.json', {'1:1': [{'w': '神', 's': 'X12'}]})
        self.assertEqual(audit_p0.check(), 1)


class SermonLocaleParity(CheckFixture):
    def test_mismatched_locale_counts_are_caught(self):
        self._write_sermon(audit_p0.SERMONS_TW, '001.txt')
        self._write_sermon(audit_p0.SERMONS_TW, '002.txt')
        self._write_sermon(audit_p0.SERMONS_CN, '001.txt')
        # no tagged files at all: that half of check() must stay silent
        self.assertEqual(audit_p0.check(), 1)

    def test_matched_locale_counts_pass(self):
        self._match_sermons(n=3)
        self.assertEqual(audit_p0.check(), 0)


if __name__ == '__main__':
    unittest.main()
