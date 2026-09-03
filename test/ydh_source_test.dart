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

/// 2026-09-03. `ydh` — yahwehdehua.net, 雅伟的话 — joined as a sixth
/// source for the five Good Friday / Easter songs on
/// `/assets/page/easter/`. The queue asked whether songs published
/// beside a video series belong in the Songs section; the user said
/// yes.
///
/// Two things separate these from every other source and both are what
/// this file guards:
///
///   1. **They carry lyrics.** Outside `fydt` they are the only rows
///      that do. That is allowed here and refused for `setapak` for
///      the same reason in both directions — carry the words when the
///      publisher owns them. These are the ministry's own
///      compositions, credited on its own page. The catalogue's
///      "used with permission" line now says so, and if these lyrics
///      ever vanish it should be because someone decided that, not
///      because a parse quietly broke.
///
///   2. **Only ONE of the five is bilingual.** The queue entry said
///      all five were. The page says otherwise: song 1 prints a
///      Chinese translation, songs 2-5 are English only. So this file
///      pins the asymmetry rather than a tidier claim — a future
///      "backfill" that puts Chinese on the other four would be
///      inventing a translation the church never published.
///
/// The row SHAPE is not new: these are YouTube-only rows with no
/// audio, no score, no code and no album, exactly like the 20 Cahaya
/// videos and the 2 Setapak songs, so nothing here special-cases it —
/// it only checks they land on the right side of the attribution fix
/// that shipped with `setapak`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  // Read off the page's "Songs / 诗歌" tab on 2026-09-03 and confirmed
  // against YouTube's oEmbed: all five resolve, all five are on the
  // ministry's own channel (@RRSuen).
  const youtubeIds = {
    '4ImxTDU5J0k', // Standing at the Cross 1
    'xrHR1ybo1J0', // Standing at the Cross 2
    's3-qcRZrfZk', // Standing at the Cross 3
    'YTp0Z_TYOns', // Easter Song 1
    '4GBO6CWR6go', // Easter Song 2
  };
  final ids = youtubeIds.map((v) => 'ydh:$v').toSet();
  const bilingual = 'ydh:4ImxTDU5J0k';

  group('the source is registered everywhere it has to be', () {
    test('all three locales have a label, and they differ from the key', () {
      final labels = songSourceLabels['ydh'];
      expect(labels, isNotNull,
          reason: 'without this the filter chip reads "ydh"');
      for (final locale in ['zh-Hans', 'zh-Hant', 'en']) {
        final value = localizedSongSource('ydh', locale);
        expect(labels, contains(locale));
        expect(value, isNot('ydh'),
            reason: '$locale fell through to the raw key');
        expect(value.trim(), isNotEmpty);
      }
    });

    test('no two sources render as the same string in one locale', () {
      // Six sources now, three of them 基督门徒福音会 congregations.
      // The chips sit next to each other with nothing else to tell
      // them apart.
      final all = <String>{};
      for (final locale in ['zh-Hans', 'zh-Hant', 'en']) {
        for (final source in songSourceLabels.keys) {
          all.add('$locale/${localizedSongSource(source, locale)}');
        }
      }
      expect(all.length, songSourceLabels.length * 3);
    });

    test('the mark is bundled, square and opaque', () async {
      final path = songSourceIcons['ydh'];
      expect(path, isNotNull);
      final data = await rootBundle.load(path!);
      expect(data.lengthInBytes, greaterThan(512));

      final bytes = data.buffer.asUint8List().sublist(0, data.lengthInBytes);
      final image = await decodeImageFromList(bytes);
      expect(image.width, image.height);
      expect(image.width, 64,
          reason: 'the site publishes exactly one icon — a 64x64 '
              'favicon.ico frame; another size means the file was '
              'resampled rather than re-encoded');

      // The source file is a black outline on a TRANSPARENT ground,
      // which disappears against a dark row. It is composited onto
      // white on purpose (see song_source_icons.dart) and this is the
      // check that the flattening was not lost in a later re-export.
      final rgba = await image.toByteData();
      var transparent = 0;
      for (var i = 3; i < rgba!.lengthInBytes; i += 4) {
        if (rgba.getUint8(i) < 255) transparent++;
      }
      expect(transparent, 0,
          reason: 'ydh.png has $transparent non-opaque pixels — the '
              'black ichthys would vanish on a dark surface');
    });

    test('the catalogue snapshot declares the source', () {
      final meta = (jsonDecode(File('assets/songs.json').readAsStringSync())
          as Map<String, dynamic>)['_meta'] as Map<String, dynamic>;
      final sources = meta['sources'] as Map<String, dynamic>;
      expect(sources, contains('ydh'));
      expect((sources['ydh'] as Map)['home'], 'https://yahwehdehua.net');
      expect((meta['bySource'] as Map)['ydh'], 5);
    });

    test('the sync script can still build the source', () {
      final script = File('scripts/sync_songs.py').readAsStringSync();
      expect(script, contains("'ydh': {"));
      expect(script, contains('def fetch_ydh()'));
      expect(script, contains('+ fetch_ydh()'),
          reason: 'defined but never called is the whole failure this '
              'catches — the catalogue would lose all five rows on the '
              'next sync');
      // The parse is anchored on the page's own Songs tab. Sweeping
      // the whole page would file the 22 teaching videos as songs.
      expect(script, contains('id="nav-hymn"'));
    });

    test('the snapshot pull refuses to drop these five', () {
      // The bundle is overwritten from yswords-data, which does not
      // publish this source yet. The floor is what stops a pull from
      // that dataset deleting the rows in silence.
      final script = File('scripts/pull_songs_snapshot.py').readAsStringSync();
      expect(script, contains("'ydh': 5"));
    });

    test('the intro names the source the filter will show', () {
      for (final locale in ['zh-Hans', 'zh-Hant', 'en']) {
        expect(uiStrings['songsIntroBody']?[locale], contains('yahwehdehua'),
            reason: '$locale lists sources but omits this one');
      }
    });

    test('the licence line covers lyrics we now redistribute', () {
      // These five ship with their words. Naming the site and the
      // composer is the difference between "used with permission" and
      // a claim the About page cannot support.
      for (final locale in ['zh-Hans', 'zh-Hant', 'en']) {
        final line = uiStrings['aboutLicenseSongs']?[locale];
        expect(line, contains('yahwehdehua.net'), reason: locale);
        expect(line, contains('Rosablanca Suen'), reason: locale);
      }
    });
  });

  group('the five rows', () {
    late Map<String, Song> byId;

    setUp(() async {
      final songs = await SongService.load();
      byId = {
        for (final s in songs.where((s) => s.source == 'ydh')) s.id: s
      };
    });

    test('all five are present and reach the app', () {
      expect(byId.keys.toSet(), ids);
      expect(SongService.hiddenSources, isNot(contains('ydh')));
    });

    test('each carries the verified YouTube id and nothing invented', () {
      expect(byId.values.map((s) => s.youtubeId).toSet(), youtubeIds);
      for (final s in byId.values) {
        expect(s.youtubeUrl, 'https://www.youtube.com/watch?v=${s.youtubeId}');
        // All five share one page: the site publishes no per-song URL
        // and inventing a fragment that Bootstrap does not act on
        // would send the reader to the wrong tab.
        expect(s.url, 'https://yahwehdehua.net/assets/page/easter/');
      }
    });

    test('the empty fields are empty on purpose, not by accident', () {
      for (final s in byId.values) {
        expect(s.hasPlayableAudio, isFalse);
        expect(s.audioTracks, isEmpty);
        expect(s.soundcloudTrackId, isNull);
        expect(s.videoUrl, isNull);
        expect(s.scoreUrl, isNull);
        expect(s.code, isNull);
        expect(s.album, isNull);
        expect(s.durationSec, isNull);
        expect(s.artworkUrl, isNull,
            reason: '${s.id}: the bundled mark fills this slot; '
                'hot-linking i.ytimg.com is what that mark exists to '
                'avoid');
      }
    });

    test('each is well-formed for the list row', () {
      for (final s in byId.values) {
        expect(s.title.trim(), isNotEmpty);
        expect(s.title, isNot(contains('&')),
            reason: '${s.id}: unescaped HTML entity in the title');
        expect(s.title, isNot(contains('<')),
            reason: '${s.id}: markup survived the title parse');
        expect(songLanguageLabels, contains(s.language));
        expect(songSourceLabels, contains(s.source));
        expect(s.sourceLabel.trim(), isNotEmpty);
        expect(s.hasVideo, isTrue);
        expect(s.firstSeenAt, isNotNull);
        expect(DateTime.tryParse(s.firstSeenAt!), isNotNull);
        expect(DateTime.tryParse(s.updatedAt!), isNotNull);
      }
    });

    test('every row is filed under English, including the bilingual one',
        () {
      // These are English compositions; song 1 additionally publishes a
      // Chinese translation. Filing that one as `zh` because its title
      // has a second line would hide an English song from the English
      // filter — the CJK sniff in detect_language() reads the FIRST
      // title line for exactly this reason.
      for (final s in byId.values) {
        expect(s.language, 'en', reason: s.id);
      }
    });

    test('the composer is the one the page credits', () {
      for (final s in byId.values) {
        expect(s.composer, 'Rosablanca Suen', reason: s.id);
        expect(s.artist, isNull,
            reason: '${s.id}: the site names no performer, and the '
                'YouTube channel is a channel, not one');
        expect(s.creditLine, 'Rosablanca Suen', reason: s.id);
      }
    });

    test('neither the row nor the sheet is a dead end', () {
      for (final s in byId.values) {
        expect(s.youtubeUrl ?? s.soundcloudUrl ?? s.scoreUrl, isNotNull);
      }
    });
  });

  group('lyrics', () {
    late Map<String, Song> byId;

    setUp(() async {
      final songs = await SongService.load();
      byId = {
        for (final s in songs.where((s) => s.source == 'ydh')) s.id: s
      };
    });

    final cjk = RegExp(r'[一-鿿]');

    test('all five carry the words the church published', () {
      for (final s in byId.values) {
        expect(s.lyrics, isNotNull,
            reason: '${s.id}: these are the ministry\'s own '
                'compositions and the page prints them in full — an '
                'empty lyrics field here means the parse broke, not '
                'that the church stopped publishing them');
        expect(s.lyrics!.length, greaterThan(400), reason: s.id);
        // The section markers the page prints in <b> survive as their
        // own lines; if they had been swallowed the whole lyric would
        // be one wall of text. Matched by shape, not by name — song 2
        // numbers its choruses ("[Chorus 1]", "[Chorus 2]").
        expect(RegExp(r'^\[[A-Za-z][^\]]*\]$', multiLine: true)
            .hasMatch(s.lyrics!), isTrue,
            reason: '${s.id}: no section marker survived on its own '
                'line — the <br/> structure was lost');
        expect(s.lyrics, isNot(contains('<')),
            reason: '${s.id}: markup leaked into the lyrics');
        expect(s.lyrics, isNot(contains('&nbsp')), reason: s.id);
        // One line per printed line. A parse that doubled the breaks
        // would make every line its own paragraph.
        final blank = '\n\n\n'.allMatches(s.lyrics!).length;
        expect(blank, 0,
            reason: '${s.id}: runs of blank lines mean the source\'s '
                'own indentation was read as line breaks');
      }
    });

    test('song 1 carries BOTH languages, in the order the page prints', () {
      final lyrics = byId[bilingual]!.lyrics!;
      final english = lyrics.indexOf('Standing at the cross');
      final chinese = lyrics.indexOf('站在十字架下');
      expect(english, greaterThanOrEqualTo(0));
      expect(chinese, greaterThan(english),
          reason: 'the page prints the English stanza first and the '
              'Chinese translation below it');
      // Both are whole lyrics, not a stray line of the other language.
      expect(cjk.allMatches(lyrics).length, greaterThan(150));
      expect(lyrics, contains('【副歌】'));
      expect(lyrics, contains('[Chorus]'));
    });

    test('the other four are English only, and stay that way', () {
      // The queue entry claimed all five were bilingual. The page says
      // otherwise. Nothing here may quietly translate them.
      for (final s in byId.values.where((s) => s.id != bilingual)) {
        expect(cjk.hasMatch(s.lyrics!), isFalse,
            reason: '${s.id}: Chinese text appeared in a lyric the '
                'church publishes only in English');
        expect(cjk.hasMatch(s.title), isFalse, reason: s.id);
      }
    });

    test('this is the only source outside fydt that carries lyrics', () async {
      // Stated as a property rather than a count so it survives new
      // songs. It is what the About line's wording rests on: the rows
      // that ship words are the ones whose publisher owns them.
      final songs = await SongService.load();
      final withLyrics =
          songs.where((s) => s.lyrics != null).map((s) => s.source).toSet();
      expect(withLyrics, {'fydt', 'ydh'});
    });
  });

  group('scripture', () {
    // The page prints a scripture box under two of the five cards and
    // none under the other three. `verse` drives a tappable book
    // filter, so a wrong book here is a citation that opens the wrong
    // passage — the P0 shape tools/add_cross_series_refs.py exists to
    // avoid. It also once mis-attributed exactly these two citations
    // to episode 10 by reading past the end of a block, so they are
    // checked against our own Bible, not against the page.
    late Map<String, Song> byId;

    setUp(() async {
      final songs = await SongService.load();
      byId = {
        for (final s in songs.where((s) => s.source == 'ydh')) s.id: s
      };
    });

    test('exactly the two cards with a scripture box carry a verse', () {
      final withVerse = {
        for (final s in byId.values)
          if (s.verse != null) s.id: s.verse,
      };
      expect(withVerse, {
        'ydh:4ImxTDU5J0k': 'Luke 9:22-23',
        'ydh:4GBO6CWR6go': 'Acts 5:30-31',
      });
      // Absent, not guessed. The other three print no scripture at all.
      for (final s in byId.values.where((s) => s.verse == null)) {
        expect(s.verseBook, isNull, reason: s.id);
      }
    });

    test('both references resolve in our own Bible', () {
      final verses =
          jsonDecode(File('assets/cuvs-yhwh.json').readAsStringSync()) as List;
      final present = <String>{
        for (final v in verses)
          '${(v as Map)['book']}|${v['chapter']}|${v['verse']}'
      };
      const enToZh = {'Luke': '路加福音', 'Acts': '使徒行传'};
      // Both ends of each range, so a transposed digit cannot hide.
      const checks = [
        ['Luke', '9', '22'],
        ['Luke', '9', '23'],
        ['Acts', '5', '30'],
        ['Acts', '5', '31'],
      ];
      for (final c in checks) {
        expect(present, contains('${enToZh[c[0]]}|${c[1]}|${c[2]}'),
            reason: '${c[0]} ${c[1]}:${c[2]} does not exist in our text');
      }
      // And the book names are the ones the app's filter can parse.
      expect(byId['ydh:4ImxTDU5J0k']!.verseBook, 'Luke');
      expect(byId['ydh:4GBO6CWR6go']!.verseBook, 'Acts');
    });
  });

  testWidgets('a ydh row shows its mark, its lyrics and an honest sheet',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final songs = await tester.runAsync(SongService.load) ?? <Song>[];
    final target = songs.firstWhere((s) => s.id == bilingual);

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

    // No artwork, so the leading slot must reach the bundled mark
    // rather than render an empty box.
    final assets = tester
        .widgetList<Image>(find.byType(Image))
        .map((w) => w.image)
        .whereType<ResizeImage>()
        .map((r) => r.imageProvider)
        .whereType<AssetImage>()
        .map((a) => a.assetName)
        .toSet();
    expect(assets, contains(songSourceIcons['ydh']));

    // `.last`: the search field above the list is an EditableText
    // holding the title we just typed, so `.first` only moves a caret.
    await tester.tap(find.text(target.title).last);
    await tester.pumpAndSettle();

    // The row has no audio and no score, so the general attribution —
    // which promises both — must not be the one shown.
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

    // No dead chip for media the row does not have.
    for (final label in [
      ...uiStrings['songsScore']!.values,
      ...uiStrings['songsWatchMv']!.values,
    ]) {
      expect(find.text(label), findsNothing, reason: label);
    }
    expect(find.text('YouTube'), findsOneWidget,
        reason: 'the one thing this row does have must be offered');

    // And the lyrics are actually on screen, both languages of them.
    final shown = tester
        .widgetList<SelectableText>(find.byType(SelectableText))
        .map((w) => w.data)
        .whereType<String>()
        .toList();
    expect(shown, contains(target.lyrics),
        reason: 'the lyrics section did not render the stored text');
  });
}
