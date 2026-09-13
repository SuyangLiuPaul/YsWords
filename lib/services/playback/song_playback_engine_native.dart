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
    _wire(_a);
    _wire(_b);

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
    _a.setVolume(1.0).catchError((Object e) {
      _unavailable = true;
      _error.add((0, 'audio engine unavailable: $e'));
    });
  }

  /// Two players, so the next track can be buffered while this one is
  /// still sounding — see [preload]. [_player] is whichever one the
  /// listener is hearing; they swap at the hand-off.
  final ap.AudioPlayer _a = ap.AudioPlayer();
  final ap.AudioPlayer _b = ap.AudioPlayer();
  late ap.AudioPlayer _player = _a;
  ap.AudioPlayer get _standby => identical(_player, _a) ? _b : _a;

  /// What [_standby] has been prepared with, as the caller spelled it.
  String? _standbyUrl;

  /// Attach the stream plumbing to [p], reporting only while [p] is the
  /// LIVE player: the standby buffers — and reports a duration, and a
  /// state change — while the listener is still hearing the other one,
  /// and none of that is news about the song they are on.
  void _wire(ap.AudioPlayer p) {
    p.onPositionChanged.listen((d) {
      if (identical(p, _player)) _position.add(d);
    });
    p.onDurationChanged.listen((d) {
      if (identical(p, _player)) _duration.add(d);
    });
    p.onPlayerStateChanged.listen((st) {
      if (identical(p, _player)) _playing.add(st == ap.PlayerState.playing);
    });
    // Fires only on a natural end — not on stop() or pause() — so a
    // caller can use it for auto-advance without looping on
    // user-initiated stops.
    p.onPlayerComplete.listen((e) {
      if (identical(p, _player)) _complete.add(e);
    });
  }

  ap.Source _sourceFor(String url) => url.startsWith('/')
      ? ap.DeviceFileSource(url)
      : ap.UrlSource(url) as ap.Source;

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
  final _error = StreamController<(int, String)>.broadcast();

  Stream<Duration> get onPosition => _position.stream;
  Stream<Duration> get onDuration => _duration.stream;
  Stream<bool> get onPlaying => _playing.stream;
  Stream<void> get onComplete => _complete.stream;

  /// Errors, tagged with the [attempt] id of the `play()` call they
  /// belong to. Every guarded command shares the id of the most recent
  /// `play()` — see [attempt] — so a caller can tell a stale error for
  /// a track it has already moved past from one about the track it is
  /// currently trying to play.
  Stream<(int, String)> get onError => _error.stream;

  int _attempt = 0;

  /// The id of the most recently issued `play()` call. Bumped
  /// synchronously at the top of [play], before any `await`, so a
  /// caller that reads this right after calling `play()` gets exactly
  /// the id that call's errors will carry — even if a later `play()`
  /// bumps it again before the first one's error arrives.
  int get attempt => _attempt;

  /// Start [url], which may be an https URL or a local file path from
  /// the offline downloads.
  Future<void> play(String url) async {
    final id = ++_attempt;
    // The hand-off. If the standby was prepared with this very track it
    // is already buffered, so the two swap roles and the new live player
    // only has to start — no fetch, and so no silence for iOS to suspend
    // us in. The old one is stopped AFTER, not before: stopping first is
    // the gap this exists to close.
    if (_standbyUrl == url) {
      final old = _player;
      _player = _standby;
      _standbyUrl = null;
      await _guard(id, _player.resume);
      unawaited(_guard(id, old.stop));
      return;
    }
    await _guard(id, () => _player.play(_sourceFor(url)));
  }

  Future<void> resume() => _guard(_attempt, _player.resume);
  Future<void> pause() => _guard(_attempt, _player.pause);
  Future<void> stop() => _guard(_attempt, _player.stop);
  Future<void> seek(Duration to) => _guard(_attempt, () => _player.seek(to));
  Future<void> setVolume(double volume) =>
      _guard(_attempt, () => _player.setVolume(volume));

  /// Warm the NEXT track so the hand-off has nothing to fetch.
  ///
  /// A no-op here, said plainly rather than faked. audioplayers holds
  /// one platform player and offers no second source to prime, and the
  /// gap this exists to close was reported on the web build. The native
  /// iOS build has its own version of the same gap — audioplayers
  /// empties the AVPlayer (`replaceCurrentItem(nil)`) before Dart is
  /// asked what plays next — and closing that needs a second player
  /// and a background task, which is a separate change. Until then this
  /// returns immediately so the handler can call it unconditionally.
  /// Prepare the NEXT track on the other player, so the hand-off in
  /// [play] has nothing to fetch.
  ///
  /// The other half of the iPhone background story, and the half the
  /// web engine's counterpart explains in full: iOS keeps a backgrounded
  /// app scheduled only while it is actually producing audio, so a fetch
  /// that starts when a track ends never finishes. `setSource` buffers
  /// without sounding, which is exactly what is wanted — the listener
  /// hears one player while the other fills.
  ///
  /// Idempotent per URL: the handler calls this on every position tick
  /// inside the lead window, and re-setting the source would restart the
  /// buffering it already did.
  Future<void> preload(String url) async {
    if (_unavailable || _standbyUrl == url) return;
    _standbyUrl = url;
    try {
      await _standby.setSource(_sourceFor(url));
    } catch (_) {
      // A track that will not prepare is not an error here: the play
      // that follows takes the ordinary path and reports it properly.
      _standbyUrl = null;
    }
  }

  /// Repeat-one, done by the platform player instead of by us.
  ///
  /// The web engine's counterpart carries the full reasoning; the same
  /// sequencing problem exists here on iOS, where audioplayers empties
  /// the AVPlayer at the end of a track (`replaceCurrentItem(nil)`)
  /// before Dart is asked what to do next. Looping in the player keeps
  /// the audio unbroken, which is what keeps a backgrounded app
  /// scheduled.
  ///
  /// [ap.ReleaseMode.loop] suppresses `onPlayerComplete`, so the
  /// handler only turns this on when nothing is waiting for that event
  /// — see `_syncLoop` in song_audio_handler.dart. Turning it off
  /// restores whatever mode the player was built with rather than a
  /// guessed constant.
  Future<void> setLoop(bool on) => _guard(
        _attempt,
        () => _player.setReleaseMode(on ? ap.ReleaseMode.loop : _bornWith),
      );

  /// The release mode this player was constructed with, captured so
  /// [setLoop] can put it back without hardcoding audioplayers' default.
  late final ap.ReleaseMode _bornWith = _a.releaseMode;

  /// Run a player command, turning any failure into an [onError] event
  /// tagged with [id] — the attempt that was current when the command
  /// was issued, not whatever `_attempt` has become by the time it
  /// fails.
  ///
  /// Every one of these awaits `creatingCompleter` internally, so on a
  /// device where the platform side never came up they would each
  /// rethrow the same start-up error. Reporting once and returning
  /// keeps a dead audio stack from propagating into the queue logic,
  /// which would otherwise abandon the whole playlist on track one.
  Future<void> _guard(int id, Future<void> Function() action) async {
    if (_unavailable) return;
    try {
      await action();
    } catch (e) {
      _error.add((id, '$e'));
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
      for (final p in [_a, _b]) {
        try {
          await p.dispose().timeout(const Duration(seconds: 3));
        } catch (_) {
          // Disposing a player that never started is not worth reporting.
        }
      }
    }
    await _position.close();
    await _duration.close();
    await _playing.close();
    await _complete.close();
    await _error.close();
  }
}
