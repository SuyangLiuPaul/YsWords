#!/usr/bin/env python3
"""Tests for `tools/audit_songs_snapshot_churn.py`'s pure comparison
functions.

stdlib `unittest`, matching the other scripts under test/: this repo has
no pytest. Synthetic fixtures only — never the real 848 KB
`assets/songs.json` and never git — so this proves the split logic
itself, independent of whatever the bundled snapshot happens to look
like on any given day.
"""

import importlib.util
import os
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(REPO, 'tools', 'audit_songs_snapshot_churn.py')

_spec = importlib.util.spec_from_file_location('audit_songs_snapshot_churn', SCRIPT)
churn = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(churn)


def _row(id_, source, updated_at, **extra):
    row = {'id': id_, 'source': source, 'title': id_, 'updatedAt': updated_at}
    row.update(extra)
    return row


class SplitSongChanges(unittest.TestCase):
    def test_timestamp_only_when_updatedAt_is_the_sole_diff(self):
        prev = [_row('a:1', 'a', '2026-09-14T00:00:00Z', title='Song A')]
        cur = [_row('a:1', 'a', '2026-09-15T00:00:00Z', title='Song A')]

        split = churn.split_song_changes(cur, prev)

        self.assertEqual(split['timestamp_only'], {'a': 1})
        self.assertEqual(split['content_changed'], {})
        self.assertEqual(split['unchanged'], {})

    def test_unchanged_when_row_is_fully_byte_identical(self):
        row = _row('a:1', 'a', '2026-09-14T00:00:00Z', title='Song A')
        split = churn.split_song_changes([dict(row)], [dict(row)])

        self.assertEqual(split['unchanged'], {'a': 1})
        self.assertEqual(split['timestamp_only'], {})
        self.assertEqual(split['content_changed'], {})

    def test_content_changed_when_a_non_timestamp_field_differs(self):
        prev = [_row('a:1', 'a', '2026-09-14T00:00:00Z', title='Old Title')]
        cur = [_row('a:1', 'a', '2026-09-15T00:00:00Z', title='New Title')]

        split = churn.split_song_changes(cur, prev)

        self.assertEqual(split['content_changed'], {'a': 1})
        self.assertEqual(split['timestamp_only'], {})
        self.assertIn('title', split['fields_changed'])
        self.assertEqual(split['fields_changed']['title'], 1)

    def test_added_and_removed_rows_by_id(self):
        prev = [_row('a:1', 'a', '2026-09-14T00:00:00Z')]
        cur = [_row('b:1', 'b', '2026-09-15T00:00:00Z')]

        split = churn.split_song_changes(cur, prev)

        self.assertEqual(split['added'], {'b': 1})
        self.assertEqual(split['removed'], {'a': 1})

    def test_per_source_split_is_independent_across_sources(self):
        """A source that is wholesale-restamped and one that has a real
        content change in the same sync must not be conflated."""
        prev = [
            _row('a:1', 'a', '2026-09-14T00:00:00Z', title='Song A'),
            _row('b:1', 'b', '2026-09-14T00:00:00Z', title='Old B'),
        ]
        cur = [
            _row('a:1', 'a', '2026-09-15T00:00:00Z', title='Song A'),
            _row('b:1', 'b', '2026-09-15T00:00:00Z', title='New B'),
        ]

        split = churn.split_song_changes(cur, prev)

        self.assertEqual(split['timestamp_only'], {'a': 1})
        self.assertEqual(split['content_changed'], {'b': 1})


class RestampedToGeneratedAt(unittest.TestCase):
    def test_counts_rows_matching_the_snapshots_own_generatedAt(self):
        songs = [
            _row('a:1', 'a', '2026-09-15T00:00:00Z'),
            _row('a:2', 'a', '2026-09-15T00:00:00Z'),
            _row('b:1', 'b', '2026-09-07T00:00:00Z'),
        ]

        counts = churn.restamped_to_generated_at(songs, '2026-09-15T00:00:00Z')

        self.assertEqual(counts, {'a': 2})

    def test_empty_when_nothing_matches(self):
        songs = [_row('a:1', 'a', '2026-09-01T00:00:00Z')]
        counts = churn.restamped_to_generated_at(songs, '2026-09-15T00:00:00Z')
        self.assertEqual(counts, {})


if __name__ == '__main__':
    unittest.main()
