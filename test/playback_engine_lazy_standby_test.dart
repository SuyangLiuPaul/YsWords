import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yswords/services/playback/song_playback_engine_native.dart';

/// 2026-09-13: the gapless hand-off gave the engine a second player, and
/// the second player was built in the constructor. Creating and wiring a
/// player reaches the platform side, so four widget test files that
/// merely put a screen on screen began failing with
/// `MissingPluginException` on `audioplayers.global/events` — and on a
/// device it meant an app that never plays a note still started two
/// platform players.
///
/// The standby is built on first preload instead. This counts the
/// players the platform is actually asked for, rather than asking the
/// engine to report on itself: a getter on [SongPlaybackEngine] would
/// have to be implemented by every fake in the suite.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const global = MethodChannel('xyz.luan/audioplayers.global');
  const players = MethodChannel('xyz.luan/audioplayers');
  late List<String> created;

  setUp(() {
    created = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(global, (call) async => null);
    messenger.setMockMethodCallHandler(players, (call) async {
      if (call.method == 'create') {
        created.add('${(call.arguments as Map?)?['playerId']}');
      }
      return null;
    });
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(global, null);
    messenger.setMockMethodCallHandler(players, null);
  });

  test('constructing the engine asks the platform for one player', () async {
    SongPlaybackEngine();
    await Future<void>.delayed(Duration.zero);
    expect(created, hasLength(1));
  });

  test('preloading the next track is what asks for the second', () async {
    final engine = SongPlaybackEngine();
    await Future<void>.delayed(Duration.zero);
    // Not awaited: with only the two channels above mocked, the
    // buffering never completes under the test binding. The question
    // here is only whether the second player gets built, and that
    // happens before `setSource` is awaited.
    unawaited(engine.preload('https://example.org/next.mp3'));
    await Future<void>.delayed(Duration.zero);
    expect(created, hasLength(2),
        reason: 'gapless needs somewhere to buffer the next track');
  });
}
