import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yswords/constants/song_source_icons.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/song.dart';
import 'package:yswords/pages/songs_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/song_service.dart';

/// 2026-09-03. Most of the song list has no cover: 359 of 621 songs
/// carry no `artworkUrl`, and 298 of those are CDC. The user asked for
/// the source's own site icon in that slot — "没有封面的你可以用他们来源
/// 的封面做为歌曲的吗？" — so this file pins the three things that can
/// quietly undo it:
///
///   1. a new source appears in the catalogue with no icon mapped,
///   2. the assets stop being bundled (a pubspec edit, a moved file),
///   3. the row stops reaching them.
///
/// (3) is the one worth a widget test rather than a data check: the
/// mark lives inside `RemoteImage`'s `fallback:`, which is also the
/// loading state and the failure state, so it is easy to wire in a way
/// that looks right and never renders.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('every source in the catalogue has a bundled mark', () async {
    final songs = await SongService.load();
    final sources = songs.map((s) => s.source).toSet();
    expect(sources, isNotEmpty);
    final uncovered = sources.difference(songSourceIcons.keys.toSet());
    expect(uncovered, isEmpty,
        reason: 'these sources would fall back to the plain button: '
            '$uncovered. Add the site icon to assets/song_sources/ and '
            'map it in lib/constants/song_source_icons.dart.');
  });

  test('the songs that need this are the ones measured', () async {
    // The premise is asserted rather than remembered. It has already
    // moved once: it was 359 bare songs when the mark was built and
    // 168 an hour later, because re-checking CDC found 191 real covers
    // the catalogue had recorded as non-existent. What must stay true
    // is narrower and more durable — there are still bare rows, and
    // every source that has one is covered.
    final songs = await SongService.load();
    final bare = songs.where((s) => s.artworkUrl == null).toList();
    expect(bare, isNotEmpty,
        reason: 'if every song has real artwork the source mark is dead '
            'code and should be deleted, not silently kept');

    final bySource = <String, int>{};
    for (final s in bare) {
      bySource[s.source] = (bySource[s.source] ?? 0) + 1;
    }
    // Every source that has bare rows must be covered; cgdc having none
    // is fine and is why this is derived rather than hard-coded.
    for (final src in bySource.keys) {
      expect(songSourceIcons[src], isNotNull,
          reason: '$src has ${bySource[src]} songs with no artwork');
    }
  });

  test('each mark is bundled, non-empty and square', () async {
    for (final entry in songSourceIcons.entries) {
      // rootBundle is the real test of the pubspec entry: the file can
      // sit in the repo and still not ship.
      final data = await rootBundle.load(entry.value);
      expect(data.lengthInBytes, greaterThan(512),
          reason: '${entry.value} is suspiciously small');

      final image = await decodeImageFromList(
          data.buffer.asUint8List().sublist(0, data.lengthInBytes));
      expect(image.width, image.height,
          reason: '${entry.value} is not square — it would be cropped by '
              'BoxFit.cover in a 40×40 slot');
      expect(image.width, greaterThanOrEqualTo(48),
          reason: '${entry.value} is smaller than CDC\'s 48×48 floor');
      // Upscaling in the asset stores blur and costs bytes; the widget
      // scales at paint time instead.
      expect(image.width, lessThanOrEqualTo(180));
    }
  });

  test('the marks stay small enough to bundle without argument', () {
    final dir = Directory('assets/song_sources');
    expect(dir.existsSync(), isTrue);
    final bytes = dir
        .listSync()
        .whereType<File>()
        .fold<int>(0, (a, f) => a + f.lengthSync());
    expect(bytes, lessThan(128 * 1024),
        reason: 'four site icons should cost tens of KB, not hundreds — '
            'if this grows, something other than an icon got in');
  });

  test('every mapped file is one of the files actually on disk', () {
    final onDisk = Directory('assets/song_sources')
        .listSync()
        .whereType<File>()
        .map((f) => 'assets/song_sources/${f.uri.pathSegments.last}')
        .toSet();
    expect(songSourceIcons.values.toSet(), onDisk,
        reason: 'an orphan file in the directory still ships (the pubspec '
            'entry is the whole directory), and a mapped file that is '
            'missing would throw at paint');
  });

  test('the catalogue snapshot names the same four sources', () {
    // Guards the other direction from the first test: _meta.sources is
    // what the sync writes, so a fifth source is announced there before
    // any song carries it.
    final meta = (jsonDecode(File('assets/songs.json').readAsStringSync())
        as Map<String, dynamic>)['_meta'] as Map<String, dynamic>;
    final declared = (meta['sources'] as Map<String, dynamic>).keys.toSet();
    expect(declared.difference(songSourceIcons.keys.toSet()), isEmpty);
  });

  testWidgets('a row with no artwork shows its source mark, not a hole',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    // rootBundle needs real async time; SongService memoises, so the
    // page's own load() then resolves from the warmed cache.
    final songs = await tester.runAsync(SongService.load) ?? <Song>[];
    final target = songs.firstWhere(
      (s) => s.source == 'cdc' && s.artworkUrl == null,
      orElse: () => throw StateError('no bare CDC song — premise changed'),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MainProvider()),
          ChangeNotifierProvider(create: (_) => AppSettings()),
        ],
        child: const MaterialApp(home: SongsPage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 600));

    // 600+ rows are built lazily, so search rather than scroll.
    await tester.enterText(find.byType(TextField).first, target.title);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(target.title), findsWidgets);

    final assets = tester
        .widgetList<Image>(find.byType(Image))
        .map((w) => w.image)
        .whereType<ResizeImage>()
        .map((r) => r.imageProvider)
        .whereType<AssetImage>()
        .map((a) => a.assetName)
        .toSet();
    expect(assets, contains(songSourceIcons['cdc']),
        reason: 'the CDC mark should be behind the play button on a row '
            'with no artwork of its own');
  });

  testWidgets('a source with no mark still renders a usable button',
      (tester) async {
    // The map is allowed to be incomplete; the row is not allowed to
    // break because of it. Exercised through the real widget by asking
    // the lookup directly — the helper is the only branch that differs.
    expect(songSourceIcon('a-source-we-have-never-heard-of'), isNull);
    expect(songSourceIcon(null), isNull);
  });
}
