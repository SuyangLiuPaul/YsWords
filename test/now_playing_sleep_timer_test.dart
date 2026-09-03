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

/// "sleep can you have customized time" — the sleep timer used to be a
/// single fixed 30-minute preset.
///
/// Driven through the real page rather than the sheet builders, because
/// the two things that can quietly rot here are wiring, not layout: a
/// preset that never reaches [SongPlayerService.setSleepTimer], and
/// "end of this song" — which cannot be a `DateTime`, since seeking or
/// skipping would desync one faked from the remaining position, and so
/// travels as a separate flag that `_onTrackFinished` reads.
///
/// The two modes are mutually exclusive by contract: arming either one
/// must disarm the other, or a queue could pause twice for one request.
///
/// Labels are looked up through [uiStrings] rather than typed out: the
/// page renders in the user's locale (zh-Hans by default), and a test
/// that hard-codes one language fails the next time a translation is
/// edited, which says nothing about the timer.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppSettings settings;
  String label(String key) => uiStrings[key]![settings.locale]!;
  String minutes(int m) => '$m ${label('songsMinutes')}';

  Future<SongPlayerService> startPlaying(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final catalogue = (await tester.runAsync(SongService.load))!;
    final playable =
        catalogue.where((s) => s.hasPlayableAudio).take(3).toList();
    expect(playable, hasLength(3));

    final player = SongPlayerService.instance;
    await tester.runAsync(() => player.playQueue(playable, label: 'test'));
    // audioplayers has no platform channel here; the handler turns its
    // own start-up failure into an onError and the plugin reports it
    // through FlutterError. Drain it — the sleep timer is what is under
    // test, not decoding.
    tester.takeException();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MainProvider()),
          ChangeNotifierProvider(create: (_) => settings = AppSettings()),
        ],
        child: const MaterialApp(home: NowPlayingPage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    return player;
  }

  /// Explicit pumps, not `pumpAndSettle`: the armed button re-renders a
  /// countdown, so this page never reaches a settled frame.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('presets, a custom duration and end-of-song are all wired',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final player = await startPlaying(tester);
    expect(player.sleepAt, isNull);
    expect(player.sleepAtEndOfTrack, isFalse);

    // ── the presets the item asked for ────────────────────────────
    await tester.tap(find.byIcon(Icons.bedtime_outlined).first);
    await settle(tester);
    for (final m in [15, 30, 45, 60]) {
      expect(find.text(minutes(m)), findsOneWidget,
          reason: '\$m is one of the four presets');
    }
    expect(find.text(label('songsSleepCustom')), findsOneWidget);
    expect(find.text(label('songsSleepEndOfSong')), findsOneWidget,
        reason: 'the one most music apps have, and the one this app '
            'would use in a car');

    await tester.tap(find.text(minutes(45)));
    await settle(tester);
    final armedFor = player.sleepAt!.difference(DateTime.now());
    expect(armedFor.inMinutes, inInclusiveRange(43, 45));
    expect(player.sleepAtEndOfTrack, isFalse);
    // The button stops naming the feature and starts counting down.
    // `_remaining` is not localised — it renders "45 min" in every
    // locale — so this is written the way the code renders it.
    expect(find.text('45 min'), findsOneWidget);

    // ── the custom picker ─────────────────────────────────────────
    await tester.tap(find.byIcon(Icons.bedtime_rounded).first);
    await settle(tester);
    await tester.tap(find.text(label('songsSleepCustom')));
    await settle(tester);

    expect(find.text(minutes(90)), findsOneWidget,
        reason: 'the stepper opens past the largest preset — nobody '
            'reaches for Custom to ask for 30');
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await settle(tester);
    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await settle(tester);
    expect(find.text(minutes(100)), findsOneWidget);

    await tester.tap(find.text(label('songsSleepSet')));
    await settle(tester);
    expect(player.sleepAt!.difference(DateTime.now()).inMinutes,
        inInclusiveRange(98, 100));

    // ── end of this song ──────────────────────────────────────────
    await tester.tap(find.byIcon(Icons.bedtime_rounded).first);
    await settle(tester);
    await tester.tap(find.text(label('songsSleepEndOfSong')));
    await settle(tester);

    expect(player.sleepAtEndOfTrack, isTrue);
    expect(player.sleepAt, isNull,
        reason: 'arming end-of-song must disarm the clock, or the queue '
            'pauses twice for one request');
    expect(find.text(label('songsSleepEndOfSongShort')), findsOneWidget);

    // ── and it can be called off ──────────────────────────────────
    await tester.tap(find.byIcon(Icons.bedtime_rounded).first);
    await settle(tester);
    await tester.tap(find.text(label('songsSleepCancel')));
    await settle(tester);

    expect(player.sleepAt, isNull);
    expect(player.sleepAtEndOfTrack, isFalse,
        reason: 'Cancel has to clear BOTH modes; it is one button and '
            'the user means "no sleep timer"');
    expect(find.text(label('songsSleepTimer')), findsOneWidget);

    await tester.runAsync(player.stop);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('a clock timer disarms end-of-song, and vice versa',
      (tester) async {
    // Same contract as above, asserted directly on the service so it
    // holds for the lock screen and CarPlay too, not only for taps on
    // this page.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    final player = await startPlaying(tester);

    player.setSleepAtEndOfTrack(true);
    expect(player.sleepAtEndOfTrack, isTrue);
    expect(player.sleepAt, isNull);

    player.setSleepTimer(const Duration(minutes: 20));
    expect(player.sleepAtEndOfTrack, isFalse,
        reason: 'one sleep mode is armed at a time');
    expect(player.sleepAt, isNotNull);

    player.setSleepAtEndOfTrack(true);
    expect(player.sleepAt, isNull);

    player.setSleepTimer(null);
    expect(player.sleepAt, isNull);
    expect(player.sleepAtEndOfTrack, isFalse);

    await tester.runAsync(player.stop);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 400));
  });
}
