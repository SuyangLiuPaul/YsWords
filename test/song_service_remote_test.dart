import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yswords/services/song_service.dart';

/// 2026-08-09. The Songs catalogue moved from a bundled-only asset to
/// the yswords-data dataset, so a song added upstream reaches users
/// without an app rebuild.
///
/// The property that matters is the FALLBACK: the network must never
/// be on the critical path. A user offline, behind the GFW, or hitting
/// yswords-data while it is down must still get the full directory
/// from the bundled snapshot. These tests run with no network at all
/// (nothing stubs http), which is exactly that worst case.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('loads the full catalogue with no network available', () async {
    final songs = await SongService.load();

    // The bundled snapshot has to carry the whole directory, not a
    // teaser — offline users get exactly this.
    expect(songs.length, greaterThan(500));
    final sources = songs.map((s) => s.source).toSet();
    expect(sources, containsAll(<String>['fydt', 'cdc', 'cgdc']));
  });

  test('hidden sources are filtered out of what the app sees', () async {
    final songs = await SongService.load();
    for (final hidden in SongService.hiddenSources) {
      expect(songs.any((s) => s.source == hidden), isFalse,
          reason: '$hidden is in hiddenSources but still reaches the UI');
    }
  });

  test('the underlying dataset still carries the hidden sources', () async {
    // Hiding is a PRESENTATION decision. The bundled data — and
    // yswords-data upstream — stay complete, so re-enabling a source
    // is emptying a set, not re-running a sync.
    final raw = await rootBundle.loadString('assets/songs.json');
    final doc = json.decode(raw) as Map<String, dynamic>;
    final sources = (doc['songs'] as List)
        .map((e) => (e as Map)['source'])
        .toSet();
    for (final hidden in SongService.hiddenSources) {
      expect(sources, contains(hidden),
          reason: 'the data should still be there, just not shown');
    }
  });

  test('the bundled asset parses into the same shape the remote '
      'publishes', () async {
    // Guards against the bundled snapshot and the published dataset
    // drifting apart — they are produced by the same script, so a
    // shape difference means one of them is stale.
    final raw = await rootBundle.loadString('assets/songs.json');
    final doc = json.decode(raw) as Map<String, dynamic>;

    expect(doc.containsKey('_meta'), isTrue);
    expect(doc.containsKey('songs'), isTrue);

    final meta = doc['_meta'] as Map<String, dynamic>;
    expect(meta['count'], (doc['songs'] as List).length);
    expect(meta['generatedAt'], isA<String>());
    expect(DateTime.tryParse(meta['generatedAt'] as String), isNotNull,
        reason: 'generatedAt must parse — RemoteDataService uses it to '
            'decide whether a fetched payload is newer than the cached '
            'one, and an unparseable value silently disables that');
  });

  test('a second load reuses the parsed bundle', () async {
    final first = await SongService.load();
    final second = await SongService.load();

    // The LISTS differ — load() filters hidden sources, so it builds a
    // new list each call — but the Song objects must be the same
    // instances, which is what proves the ~790 KB JSON was parsed once
    // per session rather than on every page open. Asserting on the
    // list identity would have been testing the filter, not the cache.
    expect(first.length, second.length);
    expect(identical(first.first, second.first), isTrue,
        reason: 'the catalogue should be parsed once per session');
  });

  test('metadata is available after loading', () async {
    await SongService.load();
    expect(SongService.meta, isNotNull);
    expect(SongService.generatedAt, isNotNull,
        reason: 'the page shows when the catalogue was published so '
            '"why is the new song not here yet" has an answer');
  });
}
