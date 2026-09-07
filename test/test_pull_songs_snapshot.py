#!/usr/bin/env python3
"""Tests for `scripts/pull_songs_snapshot.py`.

Run:
    python3 -m unittest discover -s test -p 'test_*.py' -v
    python3 test/test_pull_songs_snapshot.py        # same thing

stdlib `unittest`, matching the other scripts under test/: this repo has
no pytest and an outage-classifying guard should not be the thing that
adds a dependency to CI.

These tests exist because of a real incident: 2026-09-04 through -07,
`Sync songs` went red on `main` four days running over
`missing sources: ['setapak', 'ydh']`, purely because yswords-data has
not built fetchers for those two sources yet. The bundled
`assets/songs.json` was never at risk — the guard already refuses to
overwrite a good bundle with a thin one — but the job's EXIT CODE did
not distinguish "upstream hasn't published a source" (nothing to do
here) from "the incoming file is actually bad" (block the write), so
every run hijacked this loop's "is CI green" check for an alarm
yswords-data's own workflow already raises.

`evaluate()` is the pure function that makes that split, kept free of
network and filesystem so it can be tested directly.
"""

import importlib.util
import os
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(REPO, 'scripts', 'pull_songs_snapshot.py')

_spec = importlib.util.spec_from_file_location('pull_songs_snapshot', SCRIPT)
pss = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(pss)


def _song(id_, source, audio=True):
    row = {'id': id_, 'source': source, 'title': id_}
    if audio:
        row['audioUrl'] = f'https://example.org/{id_}.mp3'
    return row


# A minimal, otherwise-healthy incoming payload: enough rows to clear
# MIN_SONGS, every REQUIRED_SOURCES floor met, `_meta.count` consistent.
#
# Padding uses `fydt` specifically — never the source a test drops —
# so dropping any *other* required source still leaves MIN_SONGS rows.
_PAD_SOURCE = 'fydt'


def _healthy_payload():
    assert _PAD_SOURCE in pss.REQUIRED_SOURCES
    songs = []
    for source, floor in pss.REQUIRED_SOURCES.items():
        for i in range(floor):
            songs.append(_song(f'{source}-{i}', source))
    # Padded past MIN_SONGS with headroom equal to the largest floor, so
    # a test that drops one whole required source's rows still clears
    # MIN_SONGS on its own — dropping a source should exercise ONLY the
    # "missing source" check, not also trip the unrelated row-count one.
    target = pss.MIN_SONGS + max(pss.REQUIRED_SOURCES.values())
    while len(songs) < target:
        songs.append(_song(f'{_PAD_SOURCE}-pad-{len(songs)}', _PAD_SOURCE))
    meta = {'count': len(songs)}
    by_source = {}
    for s in songs:
        by_source[s['source']] = by_source.get(s['source'], 0) + 1
    return songs, meta, by_source


def _droppable_source():
    """A REQUIRED_SOURCES key that is safe to remove entirely from a
    `_healthy_payload()` without falling under MIN_SONGS — i.e. not the
    padding source."""
    return next(s for s in pss.REQUIRED_SOURCES if s != _PAD_SOURCE)


class MissingSourceIsSoftWhenBundleValid(unittest.TestCase):
    """The 2026-09-04..07 incident, reduced to its smallest case."""

    def test_missing_required_source_with_valid_baseline_is_soft(self):
        songs, meta, by_source = _healthy_payload()
        dropped = _droppable_source()
        songs = [s for s in songs if s['source'] != dropped]
        by_source.pop(dropped, None)
        meta['count'] = len(songs)

        baseline_songs, _, _ = _healthy_payload()  # a valid current bundle

        hard, soft = pss.evaluate(songs, meta, by_source, baseline_songs)

        self.assertEqual(hard, [],
                          'a missing source must not block the job when '
                          'the currently-bundled snapshot is still valid')
        self.assertTrue(
            any('missing sources' in p and dropped in p for p in soft),
            f'expected a soft warning naming {dropped!r}, got {soft}')

    def test_missing_required_source_with_no_baseline_is_hard(self):
        """No valid bundle to fall back on -> nothing here is soft."""
        songs, meta, by_source = _healthy_payload()
        dropped = _droppable_source()
        songs = [s for s in songs if s['source'] != dropped]
        by_source.pop(dropped, None)
        meta['count'] = len(songs)

        hard, soft = pss.evaluate(songs, meta, by_source, None)

        self.assertEqual(soft, [])
        self.assertTrue(
            any('missing sources' in p and dropped in p for p in hard),
            f'expected a hard failure naming {dropped!r}, got {hard}')

    def test_healthy_payload_has_no_problems(self):
        songs, meta, by_source = _healthy_payload()
        hard, soft = pss.evaluate(songs, meta, by_source, songs)
        self.assertEqual((hard, soft), ([], []))


class GenuinelyBadFileStaysHard(unittest.TestCase):
    """A defect in the payload itself must never be waved through, even
    with a perfectly good baseline sitting right there."""

    def test_too_few_songs_overall_is_hard_even_with_valid_baseline(self):
        songs, meta, by_source = _healthy_payload()
        baseline_songs = list(songs)
        songs = songs[:pss.MIN_SONGS - 1]
        meta['count'] = len(songs)

        hard, _ = pss.evaluate(songs, meta, by_source, baseline_songs)

        self.assertTrue(any('expected ≥' in p for p in hard), hard)

    def test_meta_count_mismatch_is_hard_even_with_valid_baseline(self):
        songs, meta, by_source = _healthy_payload()
        baseline_songs = list(songs)
        meta['count'] = len(songs) - 1

        hard, _ = pss.evaluate(songs, meta, by_source, baseline_songs)

        self.assertTrue(any('_meta.count' in p for p in hard), hard)


class RegressionAgainstBaselineIsSoftNotSilent(unittest.TestCase):
    """A row losing its only media is worse than what we have, but the
    bundle we already hold is untouched — same "keep what we have and
    say so" treatment as a missing source, not silence and not a hard
    failure that blocks every subsequent healthy run."""

    def test_lost_media_row_is_soft_when_baseline_had_it(self):
        songs, meta, by_source = _healthy_payload()
        baseline_songs = [dict(s) for s in songs]
        # Strip the only media from one row, id preserved so the two
        # snapshots can be compared by id.
        songs[0] = dict(songs[0])
        songs[0].pop('audioUrl', None)

        hard, soft = pss.evaluate(songs, meta, by_source, baseline_songs)

        self.assertEqual(hard, [])
        self.assertTrue(any('lost their only audio' in p for p in soft),
                         soft)

    def test_allow_regression_suppresses_the_regression_check(self):
        songs, meta, by_source = _healthy_payload()
        baseline_songs = [dict(s) for s in songs]
        songs[0] = dict(songs[0])
        songs[0].pop('audioUrl', None)

        hard, soft = pss.evaluate(
            songs, meta, by_source, baseline_songs, allow_regression=True)

        self.assertEqual((hard, soft), ([], []))


if __name__ == '__main__':
    unittest.main()
