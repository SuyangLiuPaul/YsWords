import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/pages/now_playing_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/song_player_service.dart';
import 'package:yswords/services/song_service.dart';

/// Now Playing used to show "3 / 47" as dead text — the only hint that
/// a queue existed, with no way to see it or move around it. Reaching
/// track 30 meant pressing next 27 times.
///
/// No audio actually plays here: there are no platform channels in a
/// widget test, so the engine's play() fails and the handler records an
/// error. That is fine — what is under test is the queue's visibility
/// and the index the tap sends, not decoding.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final locale = AppSettings().locale;

  testWidgets('the queue is browsable and a row jumps to that track',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final catalogue = (await tester.runAsync(SongService.load))!;
    final playable =
        catalogue.where((s) => s.hasPlayableAudio).take(8).toList();
    expect(playable.length, 8, reason: 'need a queue to browse');

    final player = SongPlayerService.instance;
    await tester.runAsync(() => player.playQueue(playable, label: 'test'));

    // audioplayers reaches for platform channels that do not exist in
    // a widget test. The engine already turns its own start-up failure
    // into an onError event, but the plugin's global EventChannel is
    // opened inside the package and reports through FlutterError, so
    // drain that here rather than let an absent native side read as a
    // test failure. Anything unexpected still fails the assertions
    // below, which are about the queue, not about decoding.
    tester.takeException();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MainProvider()),
          ChangeNotifierProvider(create: (_) => AppSettings()),
        ],
        child: const MaterialApp(home: NowPlayingPage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(player.queue.length, 8);

    // The entry point: a real control now, not a label.
    final queueButton = find.textContaining(uiStrings['songsQueue']![locale]!);
    expect(queueButton, findsOneWidget,
        reason: 'the queue counter should be tappable');
    await tester.tap(queueButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Every queued song is listed, so "what is coming" is answerable.
    for (final s in playable) {
      expect(find.text(s.title), findsWidgets);
    }

    await tester.tap(find.text(playable[5].title).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(player.queue.index, 5,
        reason: 'tapping a queue row should jump to that track');

    await tester.runAsync(player.stop);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 400));
  });
}
