import 'dart:async';

import 'package:audioplayers/audioplayers.dart' as ap;

/// Native playback on audioplayers.
///
/// Kept as-is on iOS, Android, macOS, Windows and Linux: it works
/// there, covers all five from one package, and pairs with
/// audio_service for the lock screen, CarPlay and Android Auto. Only
/// the web build needed a different engine — see
/// `song_playback_engine.dart`.
class SongPlaybackEngine {
  SongPlaybackEngine() {
    _player.onPositionChanged.listen(_position.add);
    _player.onDurationChanged.listen(_duration.add);
    _player.onPlayerStateChanged.listen((s) {
      _playing.add(s == ap.PlayerState.playing);
    });
    // Fires only on a natural end — not on stop() or pause() — so a
    // caller can use it for auto-advance without looping on
    // user-initiated stops.
    _player.onPlayerComplete.listen(_complete.add);

    // Start listening to the player's start-up before it can fail.
    //
    // audioplayers signals a failed platform hand-shake by completing
    // an internal future with the error. Every command awaits that
    // future — but if nothing is awaiting at the moment it completes,
    // the error is unhandled and brings down the enclosing zone. A
    // widget test surfaced it as an ownerless MissingPluginException.
    //
    // setVolume is a harmless probe that begins awaiting in this same
    // turn, so the failure lands in a catch we own. The realistic
    // causes are a platform where the plugin was never registered and
    // a host that refuses to start an audio session; neither should
    // crash an app whose other twenty features are fine, so it is
    // latched and reported like any other playback failure and every
    // command below then no-ops instead of throwing.
    _player.setVolume(1.0).catchError((Object e) {
      _unavailable = true;
      _error.add('audio engine unavailable: $e');
    });
  }

  final ap.AudioPlayer _player = ap.AudioPlayer();

  /// Set once the platform side is known to be missing. Latched rather
  /// than re-checked: it never recovers within a process.
  bool _unavailable = false;

  /// True when this device can actually play audio. The UI does not
  /// branch on it — a failed play surfaces through [onError] like any
  /// other — but it keeps every later command cheap and quiet.
  bool get isAvailable => !_unavailable;

  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  final _complete = StreamController<void>.broadcast();
  final _error = StreamController<String>.broadcast();

  Stream<Duration> get onPosition => _position.stream;
  Stream<Duration> get onDuration => _duration.stream;
  Stream<bool> get onPlaying => _playing.stream;
  Stream<void> get onComplete => _complete.stream;
  Stream<String> get onError => _error.stream;

  /// Start [url], which may be an https URL or a local file path from
  /// the offline downloads.
  Future<void> play(String url) async {
    final source = url.startsWith('/')
        ? ap.DeviceFileSource(url)
        : ap.UrlSource(url) as ap.Source;
    await _guard(() => _player.play(source));
  }

  Future<void> resume() => _guard(_player.resume);
  Future<void> pause() => _guard(_player.pause);
  Future<void> stop() => _guard(_player.stop);
  Future<void> seek(Duration to) => _guard(() => _player.seek(to));
  Future<void> setVolume(double volume) =>
      _guard(() => _player.setVolume(volume));

  /// Run a player command, turning any failure into an [onError] event.
  ///
  /// Every one of these awaits `creatingCompleter` internally, so on a
  /// device where the platform side never came up they would each
  /// rethrow the same start-up error. Reporting once and returning
  /// keeps a dead audio stack from propagating into the queue logic,
  /// which would otherwise abandon the whole playlist on track one.
  Future<void> _guard(Future<void> Function() action) async {
    if (_unavailable) return;
    try {
      await action();
    } catch (e) {
      _error.add('$e');
    }
  }

  Future<void> dispose() async {
    // `AudioPlayer.dispose()` awaits the same start-up future that
    // failed for want of a platform side — and it does not fail fast,
    // it simply never completes. Anything awaiting this then waits
    // forever; it wedged an entire test file before it was noticed,
    // and would do the same to a shutdown path on a device where the
    // plugin is missing.
    //
    // Skip it outright when start-up is known to have failed, and cap
    // it otherwise: a player that will not release in three seconds is
    // being torn down with the process anyway.
    if (!_unavailable) {
      try {
        await _player.dispose().timeout(const Duration(seconds: 3));
      } catch (_) {
        // Disposing a player that never started is not worth reporting.
      }
    }
    await _position.close();
    await _duration.close();
    await _playing.close();
    await _complete.close();
    await _error.close();
  }
}
