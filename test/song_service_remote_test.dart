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
    expect(sources, containsAll(<String>['fydt', 'cahaya', 'cdc']));
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

  test('a second load is served from memory, not re-parsed', () async {
    final first = await SongService.load();
    final second = await SongService.load();
    expect(identical(first, second), isTrue,
        reason: 'the ~700 KB catalogue should be parsed once per '
            'session, not on every page open');
  });

  test('metadata is available after loading', () async {
    await SongService.load();
    expect(SongService.meta, isNotNull);
    expect(SongService.generatedAt, isNotNull,
        reason: 'the page shows when the catalogue was published so '
            '"why is the new song not here yet" has an answer');
  });
}
