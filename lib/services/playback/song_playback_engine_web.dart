import 'dart:async';

import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'package:yswords/services/playback/playback_blocked.dart';

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
      // call started them has returned. Tagged with `_attempt` at fire
      // time, not at the play() call that (maybe) caused it: this is
      // one shared `<audio>` element, so the browser resets `.error`
      // (and this listener only fires with it set — see
      // `_describeError`) whenever a later `play()` reassigns `src`.
      // An error that is still about the CURRENT src is therefore
      // always about the current attempt by the time it fires.
      _error.add((_attempt, _describeError()));
    });
  }

  late final web.HTMLAudioElement _el;

  final _position = StreamController<Duration>.broadcast();
  final _duration = StreamController<Duration>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  final _complete = StreamController<void>.broadcast();
  final _error = StreamController<(int, String)>.broadcast();

  Stream<Duration> get onPosition => _position.stream;
  Stream<Duration> get onDuration => _duration.stream;
  Stream<bool> get onPlaying => _playing.stream;
  Stream<void> get onComplete => _complete.stream;

  /// Errors, tagged with the [attempt] id current when they fired. See
  /// `song_playback_engine_native.dart`'s [onError] doc — the native
  /// engine is where a genuinely STALE id (an error for a superseded
  /// attempt) actually occurs; here it exists for interface parity so
  /// `song_audio_handler.dart` can treat both engines identically.
  Stream<(int, String)> get onError => _error.stream;

  int _attempt = 0;

  /// The id of the most recently issued `play()` call. See the native
  /// engine's [attempt] doc.
  int get attempt => _attempt;

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
    // Bumped first and unconditionally: every play() call — even one
    // that resolves to the same src as before — is a new attempt for
    // the id's purposes, since it means the caller wants to hear this
    // track again from the top.
    _attempt++;
    // Compared against what we last ASSIGNED, not against `_el.src`.
    // The element resolves src to an absolute URL, so reading it back
    // gives `https://host/song-media/…` while the caller passes the
    // relative `/song-media/…` the proxy uses — they never matched,
    // and every play re-assigned src and re-downloaded a file the
    // browser already had.
    if (_lastSrc != url) {
      _lastSrc = url;
      _el.src = url;
    }
    // Always from the top: this method means "start this track". A
    // resume goes through resume(), which leaves the position alone.
    _el.currentTime = 0;
    await _start();
  }

  String? _lastSrc;

  /// Call `play()` and tell a refusal apart from a broken file.
  ///
  /// Browsers reject with `NotAllowedError` when the call did not come
  /// from a user gesture (and `AbortError` when a new load interrupts a
  /// pending play). Neither is the track's fault — but left as a
  /// generic error they are indistinguishable from a 404, and the
  /// caller drops the song and advances. One refusal then walks the
  /// whole queue, refusing identically at every step, marking every
  /// song dead and ending in silence with nothing left to play.
  ///
  /// The signal is the element, not the exception object: a decode or
  /// network failure always sets `element.error`, while a policy
  /// refusal leaves it null. That avoids reading `name` off a JS value
  /// whose Dart representation differs between compilers.
  Future<void> _start() async {
    try {
      await _el.play().toDart;
    } catch (e) {
      if (_el.error == null) throw PlaybackBlockedException('$e');
      rethrow;
    }
  }

  Future<void> resume() => _start();

  Future<void> pause() async => _el.pause();

  Future<void> stop() async {
    _el.pause();
    _el.currentTime = 0;
    _playing.add(false);
  }

  /// Whether this engine can play at all. Always true on web: there is
  /// no plugin to be missing, so a failure can only be per-track and
  /// arrives on [onError]. Mirrors the native engine's field so callers
  /// need not know which one they hold.
  bool get isAvailable => true;

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
