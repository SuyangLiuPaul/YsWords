import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/song.dart';
import 'package:yswords/pages/songs_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/song_service.dart';

/// 2026-08-17. The 47 Cahaya Pengharapan songs were hidden because none
/// of them has a stream the player can open — the audio lives on
/// SoundCloud or YouTube — so each row showed a language badge where
/// every other row shows a play button. The user asked for them back
/// ("还是enable吧"), which is only honest if the row reaches the audio
/// instead of sitting there inert.
///
/// So there are two properties here, and the second is the one that
/// makes re-enabling defensible: the rows are visible, and no visible
/// row is a dead end.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('the Cahaya songs reach the app', () async {
    final songs = await SongService.load();
    final cahaya = songs.where((s) => s.source == 'cahaya').toList();
    expect(cahaya, isNotEmpty,
        reason: 'cahaya was un-hidden; its songs should now load');
    expect(SongService.hiddenSources, isEmpty);
  });

  test('every song with no stream still offers somewhere to hear or read it',
      () async {
    // A data check, not a code check: the failure this guards against is
    // a future sync adding a row that can neither be played nor opened,
    // which no unit test of the widget would notice.
    final songs = await SongService.load();
    final silent = songs.where((s) => !s.hasPlayableAudio).toList();
    expect(silent, isNotEmpty,
        reason: 'the whole point of this file is that such rows exist');

    final deadEnds = silent
        .where((s) =>
            s.soundcloudUrl == null && s.youtubeUrl == null && s.scoreUrl == null)
        .map((s) => s.id)
        .toList();
    expect(deadEnds, isEmpty,
        reason: 'these rows can neither be played nor opened anywhere');
  });

  test('every Cahaya song offers audio or video off-site', () async {
    // Stricter than the check above, because sheet music is not
    // listening: the leading control on these rows opens SoundCloud or
    // YouTube, so one without either would render the inert badge again.
    final songs = await SongService.load();
    final cahaya = songs.where((s) => s.source == 'cahaya');
    final unreachable = cahaya
        .where((s) => s.soundcloudUrl == null && s.youtubeUrl == null)
        .map((s) => s.id)
        .toList();
    expect(unreachable, isEmpty);
  });

  testWidgets('a streamless row offers its off-site source, not a dead badge',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    // The page reads assets/songs.json through rootBundle, which needs
    // real async time — the fake clock alone leaves the FutureBuilder
    // on its spinner. SongService memoises, so the widget's own load()
    // then resolves from the warmed cache.
    final songs = await tester.runAsync(SongService.load) ?? <Song>[];
    final target = songs.firstWhere(
      (s) => !s.hasPlayableAudio && s.soundcloudUrl != null,
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

    // 600+ songs are lazily built, so search rather than scroll.
    await tester.enterText(find.byType(TextField).first, target.title);
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(target.title), findsWidgets,
        reason: 'the row itself should be in the list now that cahaya '
            'is no longer hidden');

    final locale = AppSettings().locale;
    final label = uiStrings['songsListenElsewhere']![locale]!;
    expect(find.bySemanticsLabel(label), findsWidgets,
        reason: 'the leading control should open SoundCloud/YouTube; '
            'before this change it was an untappable language badge');
  });
}
