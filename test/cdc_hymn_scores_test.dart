import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The 15 CDC hymns had audio and no sheet music, while the church has
/// published a PDF score for every one of them all along.
///
/// They were invisible to the songs sync for a specific reason worth
/// keeping: the sync reads the church's `music/` directory, where songs
/// are code-named (`music/mp3/D0180.mp3` for `/content/d0180`). The
/// hymns live in `hymns/`, named by title. So the sweep that asked
/// "are there songs we don't have" correctly answered no — we had all
/// 256 code-named songs plus 42 more, and all 15 hymns too — while a
/// whole directory of sheet music sat unused.
///
/// `tools/add_cdc_hymn_scores.py` sets them and refuses rather than
/// guesses if a title stops matching exactly one cdc song.
void main() {
  final doc = json.decode(File('assets/songs.json').readAsStringSync())
      as Map<String, dynamic>;
  final songs = (doc['songs'] as List).cast<Map<String, dynamic>>();

  List<Map<String, dynamic>> hymns() =>
      songs.where((s) => RegExp(r'^cdc:h\d+$').hasMatch(s['id'] as String))
          .toList();

  test('all 15 hymns are present', () {
    expect(hymns(), hasLength(15));
  });

  test('every hymn has a score, and it points at the church', () {
    for (final s in hymns()) {
      final url = s['scoreUrl'] as String?;
      expect(url, isNotNull, reason: '${s['id']} ${s['title']} has no score');
      expect(url, contains('/sites/default/files/hymns/pdf/'),
          reason: '${s['id']} score is not the church hymn PDF');
      expect(url, endsWith('.pdf'));
      // The hymns directory is title-named. A code-shaped filename here
      // would mean the matcher paired a hymn with a `music/` song.
      expect(url, isNot(matches(RegExp(r'/[A-Z]\d{3,4}\.pdf$'))));
    }
  });

  test('the hymns kept their audio', () {
    // The whole point was to ADD a score, not to trade one for the other.
    for (final s in hymns()) {
      expect(s['audioUrl'], isNotNull, reason: '${s['id']} lost its audio');
    }
  });

  test('no score url was handed to a non-hymn song', () {
    final strays = songs.where((s) =>
        (s['scoreUrl'] as String? ?? '').contains('/hymns/pdf/') &&
        !RegExp(r'^cdc:h\d+$').hasMatch(s['id'] as String));
    expect(strays.map((s) => s['id']), isEmpty);
  });

  test('CDC songs without sheet music are down to the known remainder', () {
    // 280 of 298 had a score before this; the 15 hymns were 15 of the 18
    // that did not. If this climbs back, a sync overwrote them.
    final cdc = songs.where((s) => s['source'] == 'cdc');
    final noScore = cdc.where((s) => (s['scoreUrl'] as String?) == null);
    expect(noScore.length, lessThanOrEqualTo(3),
        reason: 'was 18 before 2026-09-02, expected 3 after the hymns: '
            'now ${noScore.length} (${noScore.map((s) => s['id']).take(8)})');
  });
}
