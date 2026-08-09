import 'dart:async';

import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Web playback on a bare `HTMLAudioElement`.
///
/// Deliberately does NOT touch the Web Audio API — see the note in
/// `song_playback_engine.dart` for why routing through an AudioContext
/// makes iOS silent. Nothing here can be suspended: the element plays
/// straight to the output.
///
/// One element is created and reused for the whole session. iOS grants
/// a media element permission to play on its first user-gesture
/// `play()`, and that permission sticks to *that element* — so reusing
/// it means later programmatic plays (auto-advance, next track, the
/// lock-screen button) keep working without another tap.
class SongPlaybackEngine {
  SongPlaybackEngine() {
    final el = web.HTMLAudioElement()
      ..preload = 'auto'
      // No crossOrigin: playback goes through the same-origin
      // /song-media/* proxy, so there is nothing cross-origin to
      // negotiate. Setting it would re-introduce a CORS requirement
      // the churches' servers do not satisfy.
      ..autoplay = false;
    _el = el;

    _listen('timeupdate', () {
      _position.add(Duration(milliseconds: (el.currentTime * 1000).round()));
    });
    _listen('durationchange', () {
      final d = el.duration;
      if (d.isFinite && d > 0) {
        _duration.add(Duration(milliseconds: (d * 1000).round()));
      }
    });
    _listen('play', () => _playing.add(true));
    _listen('playing', () => _playing.add(true));
    _listen('pause', () => _playing.add(false));
    _listen('ended', () {
      _playing.add(false);
      _complete.add(null);
    });
    _listen('error', () {
      // Surfaced as a stream event rather than thrown: playback errors
      // arrive asynchronously from the element, long after whatever
      // call started them has returned.
      _error.add(_describeError());
    });
  }

  late final web.HTMLAudioElement _el;

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

  void _listen(String type, void Function() handler) {
    _el.addEventListener(type, ((web.Event _) => handler()).toJS);
  }

  String _describeError() {
    final e = _el.error;
    if (e == null) return 'playback failed';
    // MEDIA_ERR_SRC_NOT_SUPPORTED (4) is what a 404 or a wrong
    // content-type looks like from the element's side.
    return switch (e.code) {
      1 => 'aborted',
      2 => 'network error',
      3 => 'decode error',
      _ => 'source not supported',
    };
  }

  /// Start [url].
  ///
  /// `play()` is invoked with nothing awaited before it, so the call
  /// lands while the user gesture is still valid — the whole reason
  /// this class exists.
  Future<void> play(String url) async {
    if (_el.src != url) {
      _el.src = url;
      _el.currentTime = 0;
    }
    await _el.play().toDart;
  }

  Future<void> resume() async => _el.play().toDart;

  Future<void> pause() async => _el.pause();

  Future<void> stop() async {
    _el.pause();
    _el.currentTime = 0;
    _playing.add(false);
  }

  Future<void> seek(Duration to) async {
    _el.currentTime = to.inMilliseconds / 1000.0;
  }

  Future<void> setVolume(double volume) async {
    _el.volume = volume.clamp(0.0, 1.0);
  }

  Future<void> dispose() async {
    _el.pause();
    _el.removeAttribute('src');
    await _position.close();
    await _duration.close();
    await _playing.close();
    await _complete.close();
    await _error.close();
  }
}
