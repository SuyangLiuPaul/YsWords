import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:yswords/models/song.dart';
import 'package:yswords/models/song_queue.dart';
import 'package:yswords/services/song_audio_handler.dart';

import 'support/fake_song_playback_engine.dart';

/// Repeat-one has to be the PLAYER's job, not ours.
///
/// Reported from an iPhone in a car, app in the background because
/// navigation was in front: 「单曲循环…播完一次就停了」, and the song
/// picked up again the moment the app was reopened.
///
/// That last detail is the whole diagnosis. iOS keeps a backgrounded
/// app scheduled only while it is actually producing audio. The old
/// repeat-one waited for end-of-track and THEN seeked back and played
/// — but end-of-track, by definition, arrives after the audio has
/// stopped, so the work was queued into a page iOS had already
/// suspended and only ran when the reader looked at their phone.
///
/// Handing the repeat to the player (`<audio loop>` on web,
/// ReleaseMode.loop natively) means the audio is never interrupted, so
/// there is no gap to be suspended in. Android was always fine — a
/// foreground service keeps it scheduled either way — which is why
/// this only ever showed up on the iPhone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Song song(String id) => Song(
        id: id,
        title: id,
        language: 'zh',
        source: 'cgdc',
        sourceLabel: 'CGDC',
        url: 'https://example.test/$id',
        audioUrl: 'https://example.test/$id.mp3',
        audioTracks: [
          SongTrackInfo(url: 'https://example.test/$id.mp3', kind: 'vocal'),
        ],
        themes: const [],
      );

  SongQueue queueOf(List<String> ids, {RepeatMode repeat = RepeatMode.off}) =>
      SongQueue.fromSongs([for (final id in ids) song(id)], repeat: repeat);

  Future<void> settle(WidgetTester tester, [int cycles = 10]) async {
    for (var i = 0; i < cycles; i++) {
      await tester.pump();
    }
  }

  testWidgets('repeat-one is pushed down to the player, not kept up here',
      (tester) async {
    final engine = FakeSongPlaybackEngine();
    final handler = SongAudioHandler(engine: engine);
    await handler.setQueue(queueOf(['s0', 's1']), autoPlay: false);
    unawaited(handler.playAt(0));
    await settle(tester);

    expect(engine.loopCalls.last, isFalse,
        reason: 'a queue that is not on repeat-one must not loop');

    await handler.setRepeat(RepeatMode.one);
    await settle(tester);

    expect(engine.loopCalls.last, isTrue,
        reason: 'turning on repeat-one must reach the player, so the '
            'audio never stops and iOS never suspends the page');

    unawaited(handler.stop());
  });

  testWidgets('leaving repeat-one takes the loop back off', (tester) async {
    final engine = FakeSongPlaybackEngine();
    final handler = SongAudioHandler(engine: engine);
    await handler.setQueue(queueOf(['s0', 's1'], repeat: RepeatMode.one),
        autoPlay: false);
    unawaited(handler.playAt(0));
    await settle(tester);
    expect(engine.loopCalls.last, isTrue);

    await handler.setRepeat(RepeatMode.all);
    await settle(tester);

    expect(engine.loopCalls.last, isFalse,
        reason: 'repeat-all advances through the queue; a looping player '
            'would play track 0 forever and never reach track 1');

    unawaited(handler.stop());
  });

  testWidgets(
      'a new track gets the loop flag too, not just the one playing when '
      'it was switched on', (tester) async {
    final engine = FakeSongPlaybackEngine();
    final handler = SongAudioHandler(engine: engine);
    await handler.setQueue(queueOf(['s0', 's1'], repeat: RepeatMode.one),
        autoPlay: false);
    unawaited(handler.playAt(0));
    await settle(tester);

    engine.loopCalls.clear();
    unawaited(handler.playAt(1));
    await settle(tester);

    expect(engine.loopCalls, contains(true),
        reason: 'the release mode is per-source on some native platforms, '
            'so every play() must re-apply it — otherwise repeat-one '
            'silently stops working after the first skip');

    unawaited(handler.stop());
  });

  testWidgets(
      '"stop at the end of this song" wins over repeat-one, because a '
      'looping player never reports the end it needs', (tester) async {
    final engine = FakeSongPlaybackEngine();
    final handler = SongAudioHandler(engine: engine);
    await handler.setQueue(queueOf(['s0', 's1'], repeat: RepeatMode.one),
        autoPlay: false);
    unawaited(handler.playAt(0));
    await settle(tester);
    expect(engine.loopCalls.last, isTrue);

    handler.setSleepAtEndOfTrack(true);
    await settle(tester);

    expect(engine.loopCalls.last, isFalse,
        reason: 'both engines stop reporting end-of-track while looping, '
            'and this feature is built on that report — so the loop must '
            'come off or the music would never stop');

    handler.setSleepAtEndOfTrack(false);
    await settle(tester);

    expect(engine.loopCalls.last, isTrue,
        reason: 'disarming the sleep must give repeat-one back');

    unawaited(handler.stop());
  });
}
