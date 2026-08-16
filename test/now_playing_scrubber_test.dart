import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/models/app_settings.dart';
import 'package:yswords/pages/now_playing_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/song_player_service.dart';
import 'package:yswords/services/song_service.dart';

/// The seek bar used to seek on every drag frame. Each seek made the
/// engine's position stream emit, which rebuilt the Slider from the
/// ENGINE's position instead of from the finger, so the thumb was
/// pulled back out from under the drag — "拖动的时候很难不顺".
///
/// No audio plays in a widget test (no platform channels), so the
/// engine's reported position stays at zero throughout. That is exactly
/// what makes this a sharp test: with the old code the Slider is
/// rendered from that zero and cannot move at all, so any non-zero
/// value under the finger proves the thumb is following the drag.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the thumb follows the finger and stays put on release',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final catalogue = (await tester.runAsync(SongService.load))!;
    // The scrubber is deliberately disabled until a duration is known,
    // so the queue has to start on a song that publishes one.
    final playable = catalogue
        .where((s) => s.hasPlayableAudio && (s.durationSec ?? 0) > 60)
        .take(4)
        .toList();
    expect(playable.length, 4, reason: 'need songs with a known duration');

    final player = SongPlayerService.instance;
    await tester.runAsync(() => player.playQueue(playable, label: 'test'));
    // audioplayers reaches for platform channels that do not exist here;
    // the handler turns its own start-up failure into an onError event
    // and the plugin reports through FlutterError. Drain it — what is
    // under test is the thumb, not decoding.
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

    final slider = find.byType(Slider);
    expect(slider, findsOneWidget);
    expect(tester.widget<Slider>(slider).max, greaterThan(0),
        reason: 'a published duration should enable the scrubber');
    expect(player.position, Duration.zero,
        reason: 'nothing decodes in a widget test, so the engine '
            'never leaves zero — the drag is the only thing that can '
            'move the thumb');

    final box = tester.getRect(slider);
    final gesture = await tester.startGesture(box.centerLeft +
        const Offset(12, 0));
    await tester.pump();
    await gesture.moveTo(Offset(box.right - 12, box.center.dy));
    await tester.pump();

    final held = tester.widget<Slider>(slider).value;
    expect(held, greaterThan(tester.widget<Slider>(slider).max * 0.5),
        reason: 'the thumb must render where the finger is, not where '
            'the engine says the track is');

    // Releasing must not snap back: the engine reports position on a
    // ~200ms stream and seek() does not update it synchronously, so the
    // released value stays pinned until the engine catches up.
    await gesture.up();
    await tester.pump();
    expect(tester.widget<Slider>(slider).value, held,
        reason: 'the thumb should stay where it was dropped');

    // ...but the pin is bounded. A seek that never lands must not leave
    // the thumb lying about the position for the rest of the session.
    await tester.pump(const Duration(seconds: 4));
    expect(tester.widget<Slider>(slider).value, 0.0,
        reason: 'after the give-up window the thumb returns to the '
            'engine, which here has never left zero');

    await tester.runAsync(player.stop);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 400));
  });
}
