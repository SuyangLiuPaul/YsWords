import 'dart:async';

import 'package:yswords/services/playback/song_playback_engine.dart';

/// A hand-written fake of the engine seam — no audio plugin, no
/// network, so tests run headlessly where the real bugs it was built to
/// pin (`docs/autonomous-queue.md:7636`, songs auto-advance; `:11582`,
/// the sermon-player AbortError breadcrumb trail) could not be
/// reproduced before.
///
/// Modelled on what native's `_guard` actually does (see
/// `song_playback_engine_native.dart:91`): EVERY guarded command
/// failure — `play`, `resume`, `pause`, `stop`, `seek`, `setVolume` —
/// is swallowed and re-reported on the single [onError] stream, and
/// the command's own returned future completes normally regardless.
/// So `play()` here never throws by default; failures are only ever
/// visible on [onError], exactly like on a real device.
///
/// The two `throwBlockedOn*` flags are the one deliberate exception:
/// `PlaybackBlockedException` is real only on the web engine (see
/// `playback_blocked.dart`), which `flutter test`'s VM runtime never
/// resolves to. Setting one of them lets a test exercise the catch
/// site that only web ever reaches, without pretending the fake now
/// models web's semantics generally.
class FakeSongPlaybackEngine implements SongPlaybackEngine {
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

  int _attempt = 0;
  @override
  int get attempt => _attempt;

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

  /// Makes [play] throw `PlaybackBlockedException` instead of
  /// resolving — the web-only "browser refused to start" case.
  bool throwBlockedOnPlay = false;

  /// Makes [resume] throw `PlaybackBlockedException` instead of
  /// resolving — same case, on the resume-an-already-loaded-track path.
  bool throwBlockedOnResume = false;

  @override
  Future<void> play(String url) {
    if (throwBlockedOnPlay) {
      throw const PlaybackBlockedException('fake: blocked on play');
    }
    final id = ++_attempt;
    playCalls.add(url);
    _playCount++;
    if (holdFirstPlay && _playCount == 1) {
      _held = Completer<void>();
      return _held!.future;
    }
    if (autoErrorBudget > 0) {
      autoErrorBudget--;
      Future.microtask(() => _error.add((id, 'dead: $url')));
    }
    return Future.value();
  }

  void resolveHeldPlay() => _held?.complete();

  /// [attempt] defaults to whatever the most recent play() issued —
  /// the same thing native's `_guard` does for a control-command
  /// error on the current track. Pass it explicitly to simulate a
  /// STALE error for a superseded attempt.
  void emitError(String message, {int? attempt}) =>
      _error.add((attempt ?? _attempt, message));
  void emitDuration(Duration d) => _duration.add(d);
  void emitPosition(Duration p) => _position.add(p);
  void emitPlaying(bool v) => _playing.add(v);

  @override
  Future<void> resume() {
    if (throwBlockedOnResume) {
      throw const PlaybackBlockedException('fake: blocked on resume');
    }
    return Future.value();
  }

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
