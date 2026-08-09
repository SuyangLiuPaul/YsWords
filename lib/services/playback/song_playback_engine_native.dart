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
  }

  final ap.AudioPlayer _player = ap.AudioPlayer();

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
    await _player.play(source);
  }

  Future<void> resume() => _player.resume();
  Future<void> pause() => _player.pause();
  Future<void> stop() => _player.stop();
  Future<void> seek(Duration to) => _player.seek(to);
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  Future<void> dispose() async {
    await _player.dispose();
    await _position.close();
    await _duration.close();
    await _playing.close();
    await _complete.close();
    await _error.close();
  }
}
