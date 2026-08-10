import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yswords/services/song_service.dart';

/// 2026-08-10 (v1.4.39). A cached edition must never outlive a newer
/// bundled one.
///
/// The failure this pins was live and self-perpetuating. A yswords-data
/// cron ran while christiandiscipleschurch.org was refusing
/// connections and published a catalogue whose 283 CDC entries had lost
/// their audio. Clients that fetched in that window wrote it to
/// SharedPreferences — and `_firstLoad` returned the cache whenever one
/// existed, without ever comparing it to the bundle.
///
/// SharedPreferences survives an app upgrade, so every subsequent
/// release shipped a corrected `assets/songs.json` that was never read.
/// On screen: CDC songs with a language badge where the play button
/// belongs, and no reinstall could clear it.
///
/// This file runs in its own isolate, so `_SongServiceImpl`'s static
/// in-memory cache starts empty — the first `load()` here really is a
/// cold start, which is the only moment the choice is made.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The bundled snapshot, degraded the way the bad publish degraded
  /// it: older `generatedAt`, and every CDC song stripped of audio.
  Future<String> staleCachePayload() async {
    final raw = await rootBundle.loadString('assets/songs.json');
    final doc = json.decode(raw) as Map<String, dynamic>;

    (doc['_meta'] as Map<String, dynamic>)['generatedAt'] =
        '2020-01-01T00:00:00Z';
    for (final s in (doc['songs'] as List).cast<Map<String, dynamic>>()) {
      if (s['source'] == 'cdc') {
        s['audioUrl'] = null;
        s['instrumentalUrl'] = null;
        s['accompanimentUrl'] = null;
        s['audioTracks'] = <dynamic>[];
      }
    }
    return json.encode(doc);
  }

  test('a stale cache does not shadow a newer bundled snapshot',
      () async {
    // Sanity-check the fixture first: if this ever stopped actually
    // removing the audio, the real assertion below would pass for the
    // wrong reason.
    final payload = await staleCachePayload();
    final degraded = (json.decode(payload) as Map<String, dynamic>)['songs']
        as List;
    final degradedCdcWithAudio = degraded
        .cast<Map<String, dynamic>>()
        .where((s) => s['source'] == 'cdc' && s['audioUrl'] != null)
        .length;
    expect(degradedCdcWithAudio, 0,
        reason: 'the fixture must really be missing CDC audio');

    SharedPreferences.setMockInitialValues(<String, Object>{
      'songs.cachedJson.v2': payload,
      'songs.cachedJson.v2.at': DateTime.now().toUtc().toIso8601String(),
    });

    final songs = await SongService.load();
    final cdcWithAudio =
        songs.where((s) => s.source == 'cdc' && s.hasPlayableAudio).length;

    expect(cdcWithAudio, greaterThan(200),
        reason: 'the bundled snapshot is newer than the cached one, so its '
            'CDC audio must win — this is the assertion that fails on the '
            'pre-fix code, where the cache was returned unconditionally');
  });
}
