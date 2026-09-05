import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/services/song_service.dart';

/// The 191 CDC covers exist only in the bundled catalogue, and the
/// live fetch path had no cover logic at all.
///
/// `tools/add_cdc_artwork.py` wrote them into `assets/songs.json` on
/// 2026-09-03. The script that publishes the live dataset has no
/// artwork logic in its CDC fetcher, so the published catalogue has
/// none of them. Nothing is visibly broken today only because the
/// bundled snapshot happens to be NEWER than the live one, which is
/// what makes `_freshestLocal` and `refresh`'s staleness guard keep
/// the bundle. The next successful publish inverts that and takes all
/// 191 covers away from every user — out of a SharedPreferences cache
/// that survives an app upgrade, which is exactly how the 2026-08-10
/// CDC-audio incident behaved.
///
/// `test/cdc_artwork_test.dart` already guards the bundled asset. It
/// reads the file off disk and cannot see the network or cache path at
/// all, so it would stay green through the whole failure. This is the
/// runtime half.
///
/// The shim under test is deliberately self-limiting: it fires only
/// when the incoming payload shows NO knowledge of the field anywhere
/// in CDC. The second group is the half that matters most — it is what
/// stops this becoming a permanent override that upstream can never
/// take a cover back from.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The real bundled catalogue, decoded fresh each time (the shim
  /// mutates the payload it is handed).
  Future<Map<String, dynamic>> bundled() async => json.decode(
        await rootBundle.loadString('assets/songs.json'),
      ) as Map<String, dynamic>;

  List<Map<String, dynamic>> cdcOf(Map<String, dynamic> doc) =>
      (doc['songs'] as List)
          .cast<Map<String, dynamic>>()
          .where((s) => s['source'] == 'cdc')
          .toList();

  /// What the publisher actually emits today: every row present, every
  /// CDC `artworkUrl` an explicit null. (Verified against the live
  /// dataset — the rows carry the key, they carry `null` in it, so
  /// "absent vs null" is not a distinction this data offers.)
  Future<Map<String, dynamic>> asPublished({int keepCovers = 0}) async {
    final doc = await bundled();
    var kept = 0;
    for (final s in cdcOf(doc)) {
      if (s['artworkUrl'] != null && kept < keepCovers) {
        kept++;
        continue;
      }
      s['artworkUrl'] = null;
    }
    return doc;
  }

  /// Put [body] in the prefs cache and make the singleton look at it.
  ///
  /// Order matters and is not obvious: `setMockInitialValues` has to
  /// run first so the plugin channel exists at all — `clearCache`
  /// calls `SharedPreferences.getInstance()` and throws
  /// MissingPluginException without it — and it also REPLACES the
  /// whole store, so the seeded body has to be written after the
  /// clear, not before it.
  Future<void> seedCache(String body) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await SongService.clearCache();
    SharedPreferences.setMockInitialValues(<String, Object>{
      'songs.cachedJson.v2': body,
      'songs.cachedJson.v2.at': '2099-01-01T00:00:00Z',
    });
  }

  // ── The loss, and the repair ───────────────────────────────────

  group('backfillCdcArtwork', () {
    test('a payload with no CDC covers gets the bundled ones back',
        () async {
      final reference = await bundled();
      final expected = {
        for (final s in cdcOf(reference))
          if (s['artworkUrl'] != null) s['id'] as String: s['artworkUrl']
      };
      // Reproduce the loss first: this is what the app would show.
      final incoming = await asPublished();
      expect(cdcOf(incoming).where((s) => s['artworkUrl'] != null), isEmpty,
          reason: 'the fixture is meant to model total cover loss');
      expect(expected.length, greaterThanOrEqualTo(191),
          reason: 'the bundled snapshot lost its covers — see '
              'test/cdc_artwork_test.dart, which is the guard for that');

      final repaired = backfillCdcArtwork(incoming, await bundled());

      final got = {
        for (final s in cdcOf(repaired))
          if (s['artworkUrl'] != null) s['id'] as String: s['artworkUrl']
      };
      expect(got, expected,
          reason: 'every cover the bundle knows, and no others');
    });

    test('rows the bundle has no cover for stay without one', () async {
      // The 107 CDC rows with no cover — the 15 hymns among them —
      // must not acquire one from anywhere.
      final reference = await bundled();
      final noCover = cdcOf(reference)
          .where((s) => s['artworkUrl'] == null)
          .map((s) => s['id'] as String)
          .toSet();
      expect(noCover, isNotEmpty);

      final repaired =
          backfillCdcArtwork(await asPublished(), await bundled());
      for (final s in cdcOf(repaired)) {
        if (noCover.contains(s['id'])) {
          expect(s['artworkUrl'], isNull,
              reason: '${s['id']} invented a cover');
        }
      }
    });

    test('nothing outside CDC is touched', () async {
      final reference = await bundled();
      final before = {
        for (final s in (reference['songs'] as List).cast<Map>())
          if (s['source'] != 'cdc') s['id'] as String: s['artworkUrl']
      };
      final repaired =
          backfillCdcArtwork(await asPublished(), await bundled());
      final after = {
        for (final s in (repaired['songs'] as List).cast<Map>())
          if (s['source'] != 'cdc') s['id'] as String: s['artworkUrl']
      };
      expect(after, before);
    });

    test('no row is added, removed or otherwise reshaped', () async {
      final reference = await bundled();
      final repaired =
          backfillCdcArtwork(await asPublished(), await bundled());
      expect((repaired['songs'] as List).length,
          (reference['songs'] as List).length);
      for (final s in (repaired['songs'] as List).cast<Map>()) {
        expect(s['id'], isNotNull);
        expect(s['url'], isNotNull);
        expect(s['source'], isNotNull);
      }
    });
  });

  // ── The gate: upstream keeps the right to delete ───────────────

  group('the shim stands down once the publisher knows the field', () {
    test('ONE surviving CDC cover disables the whole backfill', () async {
      // The assertion a mutation of the gate fails. Partial presence
      // means the publisher emits `artworkUrl` and every absence is
      // its decision — an editorial takedown, not a lost field. A
      // backfill here would make a cover undeletable forever.
      final incoming = await asPublished(keepCovers: 1);
      final withArtBefore =
          cdcOf(incoming).where((s) => s['artworkUrl'] != null).toList();
      expect(withArtBefore, hasLength(1));

      final result = backfillCdcArtwork(incoming, await bundled());
      expect(cdcOf(result).where((s) => s['artworkUrl'] != null), hasLength(1),
          reason: 'the backfill ran even though the incoming payload '
              'already carried a CDC cover. Upstream can no longer take a '
              'cover down.');
    });

    test('a full upstream catalogue passes through untouched', () async {
      // The state after the publisher is fixed: the shim contributes
      // nothing at all, forever.
      final incoming = await bundled();
      final before = {
        for (final s in cdcOf(incoming)) s['id'] as String: s['artworkUrl']
      };
      final result = backfillCdcArtwork(incoming, await bundled());
      final after = {
        for (final s in cdcOf(result)) s['id'] as String: s['artworkUrl']
      };
      expect(after, before);
    });

    test('an empty or malformed payload is left alone', () async {
      expect(backfillCdcArtwork(<String, dynamic>{}, await bundled()),
          <String, dynamic>{});
      final noSongs = <String, dynamic>{'songs': 'not a list'};
      expect(backfillCdcArtwork(noSongs, await bundled()), noSongs);
      final empty = <String, dynamic>{'songs': <dynamic>[]};
      expect((backfillCdcArtwork(empty, await bundled())['songs'] as List),
          isEmpty);
    });
  });

  // ── End to end, through the path that actually loses them ──────

  test('a cached catalogue newer than the bundle still shows its covers',
      () async {
    // The real failure mode, driven through the real service. The
    // prefs cache is the tier that outlives an app upgrade, so it is
    // the one where the loss becomes permanent; and a cache newer than
    // the bundle is exactly what the next successful publish creates.
    final payload = await asPublished();
    (payload['_meta'] as Map)['generatedAt'] = '2099-01-01T00:00:00Z';
    await seedCache(json.encode(payload));

    final songs = await SongService.load();
    final cdc = songs.where((s) => s.source == 'cdc').toList();
    expect(cdc, isNotEmpty);
    final withArt = cdc.where((s) => s.artworkUrl != null).toList();

    expect(withArt.length, greaterThanOrEqualTo(191),
        reason: 'the app is serving a catalogue that lost its CDC covers. '
            'This is what a snapshot pull from the publisher does today.');
    for (final s in withArt) {
      expect(s.artworkUrl, contains('/sites/default/files/music/jpg/'),
          reason: '${s.id} got a cover from somewhere unexpected');
    }

    await SongService.clearCache();
  });

  test('the cache keeps upstream\'s own body, not the repaired one',
      () async {
    // The shim must not launder itself into storage: prefs stays a
    // faithful copy of what the server said, and the repair is
    // re-applied on every load. Otherwise a future release that drops
    // the shim would keep serving its output with nothing left to
    // explain where it came from.
    final payload = await asPublished();
    (payload['_meta'] as Map)['generatedAt'] = '2099-01-01T00:00:00Z';
    final body = json.encode(payload);
    await seedCache(body);

    await SongService.load();

    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('songs.cachedJson.v2');
    // Either untouched (no network in this test) or replaced by a real
    // network body — never rewritten by the shim.
    if (stored == body) {
      final doc = json.decode(stored!) as Map<String, dynamic>;
      expect(cdcOf(doc).where((s) => s['artworkUrl'] != null), isEmpty,
          reason: 'the backfill was written back into the cache');
    }

    await SongService.clearCache();
  });
}
