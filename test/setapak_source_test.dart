import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yswords/constants/song_source_icons.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/song.dart';
import 'package:yswords/pages/songs_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/song_service.dart';

/// 2026-09-03. `setapak` — www.setapakcdc.com, the Kuala Lumpur
/// congregation — joined as a fifth source for exactly two songs.
///
/// It was added over a recommendation against it, and the reasons for
/// that recommendation are all still true: both rows are members' own
/// YouTube uploads, both are covers of songs the church does not own,
/// and neither has an audio file, a score, a catalogue code or an
/// album. The user weighed that and said add them. So what this file
/// guards is not whether they belong, but that a permanent fifth
/// source carrying two rows is wired up **completely** — the failure
/// mode for a source this small is that one of the five places it has
/// to be registered gets missed and nobody notices, because two
/// missing rows out of 623 look like nothing.
///
/// The row shape itself is NOT new: 20 Cahaya rows are the same
/// YouTube-only shape, which is why nothing here special-cases it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  const ids = {'setapak:2899', 'setapak:2902'};
  const youtubeIds = {'jhKTDLBX-Bk', 'qUW0l4r8oPY'};

  group('the source is registered everywhere it has to be', () {
    test('all three locales have a label, and they differ from the key', () {
      final labels = songSourceLabels['setapak'];
      expect(labels, isNotNull,
          reason: 'without this the filter chip reads "setapak"');
      for (final locale in ['zh-Hans', 'zh-Hant', 'en']) {
        final value = localizedSongSource('setapak', locale);
        expect(labels, contains(locale));
        expect(value, isNot('setapak'),
            reason: '$locale fell through to the raw key');
        expect(value.trim(), isNotEmpty);
      }
    });

    test('the label says WHICH church — three here share a name', () {
      // cdc, cgdc and setapak are the same denomination in three
      // cities. Labels that do not disambiguate would leave the source
      // filter showing three chips a reader cannot tell apart.
      final all = <String>{};
      for (final locale in ['zh-Hans', 'zh-Hant', 'en']) {
        for (final source in songSourceLabels.keys) {
          all.add('$locale/${localizedSongSource(source, locale)}');
        }
      }
      expect(all.length, songSourceLabels.length * 3,
          reason: 'two sources render as the same string in one locale');
    });

    test('the mark is bundled and reachable through rootBundle', () async {
      final path = songSourceIcons['setapak'];
      expect(path, isNotNull,
          reason: 'song_source_icon_test also fails on this — the row '
              'would fall back to a plain button');
      // rootBundle, not File: a file can sit in the repo and not ship.
      final data = await rootBundle.load(path!);
      expect(data.lengthInBytes, greaterThan(512));

      final image = await decodeImageFromList(
          data.buffer.asUint8List().sublist(0, data.lengthInBytes));
      expect(image.width, image.height);
      expect(image.width, 180,
          reason: 'the site publishes a 180x180 apple-touch-icon; '
              'anything else means the file was re-encoded');
    });

    test('the catalogue snapshot declares the source', () {
      final meta = (jsonDecode(File('assets/songs.json').readAsStringSync())
          as Map<String, dynamic>)['_meta'] as Map<String, dynamic>;
      final sources = meta['sources'] as Map<String, dynamic>;
      expect(sources, contains('setapak'));
      expect((sources['setapak'] as Map)['home'],
          'https://www.setapakcdc.com');
      expect((meta['bySource'] as Map)['setapak'], 2);
    });

    test('the sync script can still build the source', () {
      // Not a network test — just that the registry entry the fetcher
      // needs is present. `make_entry` throws KeyError without it, so
      // a sync would die rather than quietly emit nothing.
      final script = File('scripts/sync_songs.py').readAsStringSync();
      expect(script, contains("'setapak': {"));
      expect(script, contains('def fetch_setapak()'));
      expect(script, contains('+ fetch_setapak()'),
          reason: 'defined but never called is the whole failure this '
              'catches — the catalogue would lose both rows on the '
              'next sync');
    });

    test('the intro names the source the filter will show', () {
      // Standing rule on this string since Cahaya was re-enabled: the
      // sources it lists must match what the user can actually see.
      for (final locale in ['zh-Hans', 'zh-Hant', 'en']) {
        expect(uiStrings['songsIntroBody']?[locale], contains('setapak'),
            reason: '$locale lists sources but omits this one');
      }
    });
  });

  group('the two rows', () {
    late List<Song> setapak;

    setUp(() async {
      final songs = await SongService.load();
      setapak = songs.where((s) => s.source == 'setapak').toList();
    });

    test('both are present and reach the app', () {
      expect(setapak.map((s) => s.id).toSet(), ids);
      expect(SongService.hiddenSources, isNot(contains('setapak')));
    });

    test('each carries the verified YouTube id and nothing invented', () {
      expect(setapak.map((s) => s.youtubeId).toSet(), youtubeIds);
      for (final s in setapak) {
        // Verified against the site and YouTube's oEmbed on 2026-09-03.
        expect(s.youtubeUrl,
            'https://www.youtube.com/watch?v=${s.youtubeId}');
        expect(s.url, startsWith('https://www.setapakcdc.com/'));
        expect(s.url, isNot('https://www.setapakcdc.com/'),
            reason: '${s.id}: "Original page" must open the song\'s own '
                'post, not the site root');
      }
    });

    test('the empty fields are empty on purpose, not by accident', () {
      for (final s in setapak) {
        expect(s.hasPlayableAudio, isFalse);
        expect(s.audioTracks, isEmpty);
        expect(s.soundcloudTrackId, isNull);
        expect(s.videoUrl, isNull);
        expect(s.scoreUrl, isNull);
        expect(s.code, isNull);
        expect(s.album, isNull);
        // Both posts print full lyrics, and both are covers of songs
        // this church does not own. Carrying them would put a third
        // party's words in the bundle under a "used with permission"
        // line that does not cover them. See fetch_setapak().
        expect(s.lyrics, isNull,
            reason: '${s.id}: lyrics were deliberately not scraped — '
                'if a sync brought them back, that is a regression, '
                'not a backfill');
      }
    });

    test('each is well-formed for the list row', () {
      for (final s in setapak) {
        expect(s.title.trim(), isNotEmpty);
        expect(s.title, isNot(contains('&')),
            reason: '${s.id}: unescaped HTML entity in the title');
        expect(songLanguageLabels, contains(s.language));
        expect(songSourceLabels, contains(s.source));
        expect(s.sourceLabel.trim(), isNotEmpty);
        expect(s.hasVideo, isTrue);
        expect(s.firstSeenAt, isNotNull);
        expect(s.updatedAt, isNotNull);
        expect(DateTime.tryParse(s.firstSeenAt!), isNotNull);
      }
    });

    test('the credits name the cover artist, not just the writer', () {
      final byId = {for (final s in setapak) s.id: s};
      // Recorded as the site publishes them, not corrected by us.
      expect(byId['setapak:2899']!.artist, 'Tham Chen Tong');
      expect(byId['setapak:2899']!.composer,
          'Hillsong Worship and Jadwin Gillies');
      expect(byId['setapak:2902']!.composer, '許冠傑');
      expect(byId['setapak:2902']!.lyricist, '許冠傑/黎彼得');
      for (final s in setapak) {
        expect(s.creditLine, isNotNull,
            reason: '${s.id}: the subtitle would be the source label '
                'alone, and these rows have a credit to show');
      }
    });

    test('neither row is a dead end', () {
      // The same property cahaya_songs_enabled_test pins for Cahaya:
      // a row that can be neither played nor opened is inert.
      for (final s in setapak) {
        expect(s.youtubeUrl ?? s.soundcloudUrl ?? s.scoreUrl, isNotNull);
      }
    });
  });

  testWidgets('a Setapak row shows its mark and an honest sheet',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final songs = await tester.runAsync(SongService.load) ?? <Song>[];
    final target = songs.firstWhere((s) => s.id == 'setapak:2899');

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

    // 620+ rows build lazily — search rather than scroll.
    await tester.enterText(find.byType(TextField).first, target.title);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text(target.title), findsWidgets);

    // The row has no artwork, so the leading slot must reach the
    // bundled Setapak mark rather than render an empty box.
    final assets = tester
        .widgetList<Image>(find.byType(Image))
        .map((w) => w.image)
        .whereType<ResizeImage>()
        .map((r) => r.imageProvider)
        .whereType<AssetImage>()
        .map((a) => a.assetName)
        .toSet();
    expect(assets, contains(songSourceIcons['setapak']));

    // Open the detail sheet and check the attribution tells the truth:
    // this row has no audio and no score, so the general line — which
    // promises all three — must not be the one shown.
    //
    // Asserted across ALL locales rather than against the one this
    // test happens to run in: which locale that is depends on
    // AppSettings' default, and pinning it here would make this test
    // fail for a reason that has nothing to do with the attribution.
    // `.last`, not `.first`: the search field above the list is itself
    // an EditableText holding the title we just typed, so `.first`
    // matches the field and the tap only moves the caret.
    await tester.tap(find.text(target.title).last);
    await tester.pumpAndSettle();

    final linkOnly = uiStrings['songsAttributionLinkOnly']!.values;
    final general = uiStrings['songsAttribution']!.values;
    expect(linkOnly.where((t) => find.text(t).evaluate().isNotEmpty),
        hasLength(1),
        reason: 'the sheet should say it is a video link only, in '
            'exactly one locale');
    for (final t in general) {
      expect(find.text(t), findsNothing,
          reason: 'this row has neither audio nor sheet music, so the '
              'line promising both would be false');
    }
  });
}
