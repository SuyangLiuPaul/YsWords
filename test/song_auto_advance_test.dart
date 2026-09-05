import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:yswords/models/song.dart';
import 'package:yswords/models/song_queue.dart';
import 'package:yswords/services/song_audio_handler.dart';

import 'support/fake_song_playback_engine.dart';

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

  /// Drains pending microtasks/timers so a chain of onError → skip →
  /// play() → onError… settles before the next assertion.
  ///
  /// testWidgets runs inside a FakeAsync zone, where a raw
  /// `Future.delayed` never fires on its own — only `tester.pump`
  /// advances that clock — so this must pump, not just await.
  Future<void> settle(WidgetTester tester, [int cycles = 20]) async {
    for (var i = 0; i < cycles; i++) {
      await tester.pump();
    }
  }

  testWidgets(
      'onError for the current, never-started track quarantines it and '
      'advances; a queue where every track dies this way terminates '
      'instead of spinning forever under repeat-all',
      (tester) async {
    final engine = FakeSongPlaybackEngine()..autoErrorBudget = 6;
    final handler = SongAudioHandler(engine: engine);
    await handler.setQueue(
      queueOf(['s0', 's1', 's2'], repeat: RepeatMode.all),
      autoPlay: false,
    );

    unawaited(handler.playAt(0));
    await settle(tester);

    // Every track failed before ever producing a duration/position, so
    // each is a play-attempt failure, not a mid-playback one — it
    // should have been quarantined (docs' "onError never adds to
    // _failed" claim) and the all-dead queue should have stopped
    // rather than wrapping through repeat-all forever.
    expect(engine.playCalls.length, 3,
        reason: 'three dead tracks should cost exactly three play() '
            'attempts; today onError never quarantines a track, so '
            'repeat-all keeps replaying them (bounded here only by the '
            'fake\'s autoErrorBudget, not by the handler)');
    expect(handler.isPlaying, isFalse,
        reason: 'an all-dead queue must stop, not loop');
  });

  testWidgets(
      'a control-command error on an already-playing track does not '
      'skip to the next song', (tester) async {
    final engine = FakeSongPlaybackEngine();
    final handler = SongAudioHandler(engine: engine);
    await handler.setQueue(queueOf(['s0', 's1']), autoPlay: false);

    unawaited(handler.playAt(0));
    await settle(tester);
    // This track is genuinely alive: it has produced real position and
    // duration, the same signal the stall watchdog itself trusts.
    engine.emitDuration(const Duration(seconds: 30));
    engine.emitPosition(const Duration(seconds: 5));
    await settle(tester);

    // Native's _guard funnels a failed pause()/stop()/seek() into this
    // exact same onError stream — see song_playback_engine_native.dart.
    engine.emitError('mock pause failure');
    await settle(tester);

    expect(handler.songQueue.index, 0,
        reason: 'the user paused (or sought, or stopped); the track '
            'that was playing did not die, so the queue must not have '
            'moved on without them');
    // No explicit stop(): emitDuration/emitPosition above already
    // cancelled the stall watchdog (same "is this track alive" signal
    // _armStallWatchdog itself trusts), so nothing is left pending.
    // handler.stop() cannot be awaited here — see the third test's
    // comment: BaseAudioHandler.stop() hangs forever in a widget test.
  });

  testWidgets(
      'an onError that arrives while the original play() future is '
      'still pending still advances the queue', (tester) async {
    final engine = FakeSongPlaybackEngine()..holdFirstPlay = true;
    final handler = SongAudioHandler(engine: engine);
    await handler.setQueue(
      queueOf(['s0', 's1', 's2']),
      autoPlay: false,
    );

    unawaited(handler.playAt(0));
    await settle(tester);
    expect(engine.playCalls, ['https://example.test/s0.mp3'],
        reason: 'the held play() call was made but never resolved on '
            'its own — anything that happens next has to come from '
            'onError, not from awaiting it');
    engine.emitError('dead, before play() ever resolved');
    await settle(tester);

    expect(handler.songQueue.index, 1,
        reason: 'a dead track reported before its own play() future '
            'settles must still be skipped — otherwise the handler '
            'would wait on a future that, on a genuinely dead host, '
            'may never resolve at all');

    // The stale first play() now resolves normally, long after the
    // handler already moved on to track 2 in response to onError.
    engine.resolveHeldPlay();
    await settle(tester);

    expect(handler.songQueue.index, 1,
        reason: 'the stale play() for track 1 finishing late must not '
            'undo the advance to track 2');

    // Track 2's stall watchdog is still armed (never produced a
    // duration/position in this test) and must be cancelled before the
    // test ends, or the framework's pending-timer check fails it.
    // stop()'s FIRST line does exactly that, synchronously, before its
    // own first `await` — but stop() itself must never be AWAITED in a
    // widget test: BaseAudioHandler.stop() (audio_service) ends with
    // `await playbackState.firstWhere((s) => s.processingState ==
    // idle)`, which never completes without a real platform behind it
    // (confirmed in isolation: `await BaseAudioHandler().stop()` alone
    // hangs forever here — nothing to do with this handler or this
    // fix). Fire-and-forget gets the synchronous cancellation without
    // ever waiting on the part that hangs. See
    // docs/autonomous-queue.md for the follow-up this discovery was
    // queued as.
    unawaited(handler.stop());
  });

  testWidgets(
      'a stale onError for an attempt the handler has already moved past '
      'is not blamed on whatever track is current now', (tester) async {
    final engine = FakeSongPlaybackEngine()..holdFirstPlay = true;
    final handler = SongAudioHandler(engine: engine);
    await handler.setQueue(
      queueOf(['s0', 's1', 's2']),
      autoPlay: false,
    );

    // Attempt 1: s0, held — its play() future never resolves on its
    // own, mirroring A in the bug report.
    unawaited(handler.playAt(0));
    await settle(tester);
    expect(engine.attempt, 1);

    // Before attempt 1's error/success arrives, move to s1 — attempt 2.
    unawaited(handler.playAt(1));
    await settle(tester);
    expect(engine.attempt, 2);
    expect(handler.songQueue.index, 1);

    // Attempt 1's now-stale error finally lands. It must be discarded
    // outright — not read as an error on s1 (the current track, which
    // has itself not yet produced position/duration and so looks
    // exactly as "unproven" as a genuinely dead s1 would).
    engine.emitError('dead: attempt 1, arriving late', attempt: 1);
    await settle(tester);

    expect(handler.songQueue.index, 1,
        reason: 'a stale error for the abandoned attempt 1 (s0) must '
            'not skip s1 — the track it was never actually about');
    expect(handler.error, isNull,
        reason: 'a discarded stale error must not surface as the '
            'current track\'s visible error either');

    // A genuine error for the CURRENT attempt (2) is still honoured —
    // the id check must not have swallowed error handling altogether.
    engine.emitError('dead: attempt 2, for real this time', attempt: 2);
    await settle(tester);

    expect(handler.songQueue.index, 2,
        reason: 'an error carrying the CURRENT attempt id must still '
            'quarantine and skip past a track that never played');

    unawaited(handler.stop());
  });
}
