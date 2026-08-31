import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:yswords/models/song.dart';
import 'package:yswords/models/song_queue.dart';
import 'package:yswords/services/playback/song_playback_engine.dart';
import 'package:yswords/services/song_audio_handler.dart';

/// A hand-written fake of the engine seam — no audio plugin, no
/// network, so this runs headlessly where the real bug
/// (`docs/autonomous-queue.md:7636`, "下首歌没有继续播放而是停住了")
/// could not be reproduced before.
///
/// Modelled on what native's `_guard` actually does (see
/// `song_playback_engine_native.dart:91`): EVERY guarded command
/// failure — `play`, `resume`, `pause`, `stop`, `seek`, `setVolume` —
/// is swallowed and re-reported on the single [onError] stream, and
/// the command's own returned future completes normally regardless.
/// So `play()` here never throws; failures are only ever visible on
/// [onError], exactly like on a real device.
class _FakeEngine implements SongPlaybackEngine {
  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  final _complete = StreamController<void>.broadcast();
  final _error = StreamController<String>.broadcast();

  @override
  Stream<Duration> get onPosition => _position.stream;
  @override
  Stream<Duration> get onDuration => _duration.stream;
  @override
  Stream<bool> get onPlaying => _playing.stream;
  @override
  Stream<void> get onComplete => _complete.stream;
  @override
  Stream<String> get onError => _error.stream;

  @override
  bool get isAvailable => true;

  final List<String> playCalls = [];

  /// When true, the FIRST play() call never completes on its own —
  /// simulating a load whose future is still pending when a later
  /// event arrives. [resolveHeldPlay] completes it on demand.
  bool holdFirstPlay = false;
  Completer<void>? _held;
  int _playCount = 0;

  /// How many of the NEXT play() calls should self-report an error a
  /// microtask later, mimicking a dead track that native accepts and
  /// then fails asynchronously. Decrements per call.
  int autoErrorBudget = 0;

  @override
  Future<void> play(String url) {
    playCalls.add(url);
    _playCount++;
    if (holdFirstPlay && _playCount == 1) {
      _held = Completer<void>();
      return _held!.future;
    }
    if (autoErrorBudget > 0) {
      autoErrorBudget--;
      Future.microtask(() => _error.add('dead: $url'));
    }
    return Future.value();
  }

  void resolveHeldPlay() => _held?.complete();

  void emitError(String message) => _error.add(message);
  void emitDuration(Duration d) => _duration.add(d);
  void emitPosition(Duration p) => _position.add(p);

  @override
  Future<void> resume() => Future.value();
  @override
  Future<void> pause() => Future.value();
  @override
  Future<void> stop() => Future.value();
  @override
  Future<void> seek(Duration to) => Future.value();
  @override
  Future<void> setVolume(double volume) => Future.value();

  @override
  Future<void> dispose() async {
    await _position.close();
    await _duration.close();
    await _playing.close();
    await _complete.close();
    await _error.close();
  }
}

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
    final engine = _FakeEngine()..autoErrorBudget = 6;
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
    final engine = _FakeEngine();
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
    final engine = _FakeEngine()..holdFirstPlay = true;
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
}
