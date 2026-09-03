import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:yswords/models/song.dart';
import 'package:yswords/models/song_queue.dart';
import 'package:yswords/services/playback/song_playback_engine.dart';
import 'package:yswords/services/song_audio_handler.dart';

/// A trimmed copy of the fake in test/song_auto_advance_test.dart —
/// that class is file-private, and duplicating a ~30-line fake reads
/// better here than exporting a shared test seam for one field's worth
/// of extra behaviour.
class _FakeEngine implements SongPlaybackEngine {
  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  final _complete = StreamController<void>.broadcast();
  final _error = StreamController<(int, String)>.broadcast();

  @override
  Stream<Duration> get onPosition => _position.stream;
  @override
  Stream<Duration> get onDuration => _duration.stream;
  @override
  Stream<bool> get onPlaying => _playing.stream;
  @override
  Stream<void> get onComplete => _complete.stream;
  @override
  Stream<(int, String)> get onError => _error.stream;

  @override
  bool get isAvailable => true;

  final List<String> playCalls = [];
  final List<String> pauseCalls = [];

  int _attempt = 0;
  @override
  int get attempt => _attempt;

  @override
  Future<void> play(String url) {
    _attempt++;
    playCalls.add(url);
    return Future.value();
  }

  /// Fires the same stream the real engine uses to signal a track
  /// playing to its natural end.
  void complete() => _complete.add(null);

  @override
  Future<void> resume() => Future.value();
  @override
  Future<void> pause() {
    pauseCalls.add('pause');
    return Future.value();
  }

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

  Future<void> settle(WidgetTester tester, [int cycles = 10]) async {
    for (var i = 0; i < cycles; i++) {
      await tester.pump();
    }
  }

  testWidgets(
      '"end of this song" pauses on the natural end and does not '
      'advance the queue — today, before this fix, onComplete always '
      'calls skipToNext regardless of any armed sleep mode',
      (tester) async {
    final engine = _FakeEngine();
    final handler = SongAudioHandler(engine: engine);
    await handler.setQueue(queueOf(['s0', 's1']), autoPlay: false);
    unawaited(handler.playAt(0));
    await settle(tester);

    expect(handler.sleepAtEndOfTrack, isFalse);
    handler.setSleepAtEndOfTrack(true);
    expect(handler.sleepAtEndOfTrack, isTrue);

    engine.complete();
    await settle(tester);

    expect(handler.songQueue.index, 0,
        reason: '"end of this song" must pause in place, not advance '
            'to track 1 the way a plain natural end would');
    expect(engine.pauseCalls, isNotEmpty,
        reason: 'the armed mode must actually pause playback');
    expect(handler.sleepAtEndOfTrack, isFalse,
        reason: 'the flag is one-shot — it must not re-arm itself and '
            'pause every subsequent track too');

    unawaited(handler.stop());
  });

  testWidgets(
      '"end of this song" overrides repeat-one: the track must pause, '
      'not seek back to zero and keep playing itself', (tester) async {
    final engine = _FakeEngine();
    final handler = SongAudioHandler(engine: engine);
    await handler.setQueue(
      queueOf(['s0', 's1'], repeat: RepeatMode.one),
      autoPlay: false,
    );
    unawaited(handler.playAt(0));
    await settle(tester);

    handler.setSleepAtEndOfTrack(true);
    final playCallsBefore = engine.playCalls.length;
    engine.complete();
    await settle(tester);

    expect(handler.songQueue.index, 0);
    expect(engine.pauseCalls, isNotEmpty);
    // Repeat-one's own path calls seek(0) + resume(), never play() —
    // so a NEW play() call here would mean the repeat-one branch ran
    // instead of (or after) the end-of-track one.
    expect(engine.playCalls.length, playCallsBefore,
        reason: 'the end-of-track branch must return before reaching '
            'the repeat-one seek/resume path');

    unawaited(handler.stop());
  });

  testWidgets(
      'without end-of-track armed, a natural end still advances '
      'normally — the new flag must not touch the unarmed case',
      (tester) async {
    final engine = _FakeEngine();
    final handler = SongAudioHandler(engine: engine);
    await handler.setQueue(queueOf(['s0', 's1']), autoPlay: false);
    unawaited(handler.playAt(0));
    await settle(tester);

    engine.complete();
    await settle(tester);

    expect(handler.songQueue.index, 1,
        reason: 'plain auto-advance must still work when no sleep mode '
            'is armed');

    unawaited(handler.stop());
  });

  testWidgets(
      'arming a DateTime sleep timer disarms end-of-track, and vice '
      'versa — only one sleep mode is armed at a time', (tester) async {
    final engine = _FakeEngine();
    final handler = SongAudioHandler(engine: engine);
    await handler.setQueue(queueOf(['s0']), autoPlay: false);
    unawaited(handler.playAt(0));
    await settle(tester);

    handler.setSleepAtEndOfTrack(true);
    expect(handler.sleepAtEndOfTrack, isTrue);
    handler.setSleepTimer(const Duration(minutes: 30));
    expect(handler.sleepAtEndOfTrack, isFalse,
        reason: 'arming the DateTime timer must disarm end-of-track');
    expect(handler.sleepAt, isNotNull);

    handler.setSleepAtEndOfTrack(true);
    expect(handler.sleepAt, isNull,
        reason: 'arming end-of-track must cancel the DateTime timer');
    expect(handler.sleepAtEndOfTrack, isTrue);

    handler.setSleepTimer(null);
    expect(handler.sleepAt, isNull);
    expect(handler.sleepAtEndOfTrack, isFalse,
        reason: 'cancelling clears whichever mode was armed');

    unawaited(handler.stop());
  });
}
