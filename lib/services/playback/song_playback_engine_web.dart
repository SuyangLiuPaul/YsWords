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
    _el = _newElement();
    _standby = _newElement();
    _wire(_el);
    _wire(_standby);
  }

  static web.HTMLAudioElement _newElement() => web.HTMLAudioElement()
    ..preload = 'auto'
    // No crossOrigin: playback goes through the same-origin
    // /song-media/* proxy, so there is nothing cross-origin to
    // negotiate. Setting it would re-introduce a CORS requirement
    // the churches' servers do not satisfy.
    ..autoplay = false;

  /// Attach the stream plumbing to [el]. Every handler first checks that
  /// [el] is still the LIVE element: both elements are wired once, at
  /// construction, and [play] swaps which one is live, so a standby
  /// element's `timeupdate` while it warms the next track must not be
  /// reported as the position of the song the listener is hearing.
  void _wire(web.HTMLAudioElement el) {
    void on(String type, void Function() handler) {
      el.addEventListener(
          type,
          ((web.Event _) {
            if (!identical(el, _el)) return;
            handler();
          }).toJS);
    }

    on('timeupdate', () {
      _position.add(Duration(milliseconds: (el.currentTime * 1000).round()));
    });
    on('durationchange', () {
      final d = el.duration;
      if (d.isFinite && d > 0) {
        _duration.add(Duration(milliseconds: (d * 1000).round()));
      }
    });
    on('play', () => _playing.add(true));
    on('playing', () => _playing.add(true));
    on('pause', () => _playing.add(false));
    on('ended', () {
      _playing.add(false);
      _complete.add(null);
    });
    on('error', () {
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

  /// The element the listener is hearing. Not final: [play] swaps it
  /// with [_standby] when the standby already holds the requested track.
  late web.HTMLAudioElement _el;

  /// The other element. Between tracks it holds whatever [preload] was
  /// last asked for, buffered and ready; the rest of the time it is
  /// idle. See [preload] for why there are two.
  late web.HTMLAudioElement _standby;

  /// What [_standby] currently holds, as the caller spelled it — the
  /// element resolves `src` to an absolute URL, so it cannot be compared
  /// back (see [_lastSrc]).
  String? _standbySrc;

  /// Whether [_standby] has been through a user-gesture `play()` yet.
  /// iOS grants playback per ELEMENT on a gesture; an element that has
  /// never been played inside one is refused later, so the standby is
  /// unlocked on the first gesture that reaches [_start] — a silent
  /// play-and-pause, see [_unlockStandby].
  bool _standbyUnlocked = false;

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
    // The hand-off. If the standby already holds this track, the two
    // elements swap roles and the old one is parked; `play()` on the new
    // live element then has nothing to fetch, which is the whole point —
    // see [preload]. Done synchronously, with nothing awaited before it,
    // for the same reason the rest of this method is.
    if (_standbySrc != null && _standbySrc == url && _lastSrc != url) {
      final old = _el;
      _el = _standby;
      _standby = old;
      _lastSrc = url;
      _standbySrc = null;
      old.pause();
      _standbyUnlocked = true; // the parked one has certainly played
      _el.currentTime = 0;
      await _start();
      return;
    }
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
      final started = _el.play().toDart;
      // Inside the same gesture as the play above: `_unlockStandby`
      // must run before the first await spends the activation.
      _unlockStandby();
      await started;
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

  /// Repeat-one, done by the browser instead of by us.
  ///
  /// This is the whole fix for 「单曲循环…播完一次就停了」 on iPhone,
  /// reported from a car with the app in the background and navigation
  /// in front.
  ///
  /// The Dart route — wait for `ended`, then `seek(0)` and `play()` —
  /// cannot work backgrounded on iOS, and the reason is a sequencing
  /// one rather than a bug anywhere in it. iOS keeps a backgrounded
  /// page alive **while it is actually producing audio**. `ended` fires
  /// AFTER the audio has stopped, so by the time the event has crossed
  /// into Dart, travelled a broadcast stream and come back, the page it
  /// needs is already suspended. It resumes when the reader next looks
  /// at their phone — which is exactly the symptom: the song restarts
  /// the moment you reopen the app.
  ///
  /// `loop` is set on the element, so the media stack repeats without
  /// waking JavaScript at all. Audio never stops, so the page is never
  /// suspended, so there is no gap to lose. It also means `ended` never
  /// fires while it is on, which is why the handler gates this on the
  /// sleep-at-end-of-track flag: that feature needs the event.
  Future<void> setLoop(bool on) async {
    _el.loop = on;
  }

  /// Warm the NEXT track so that when this one ends there is nothing to
  /// fetch.
  ///
  /// The other half of the iPhone background story, and the harder
  /// half. Repeat-one was fixed by letting the element loop (see
  /// [setLoop]); between two DIFFERENT songs the silence is real —
  /// the next file has to come over the network — and iOS suspends a
  /// backgrounded page the moment its audio stops. The `play()` we
  /// issue from `ended` is not the problem; it is issued in the same
  /// task as the event. It is the FETCH that follows it: with the page
  /// suspended the bytes never arrive, and the next song starts when the
  /// reader next looks at their phone. 「播放全部…第一个歌完了不会自动
  /// 播放下一首」.
  ///
  /// So the fetch is moved to BEFORE the end, while audio is still
  /// playing and the page is still scheduled. The handler calls this a
  /// little before the current track ends; the standby element loads
  /// and buffers the URL; and when the current track ends, [play] finds
  /// the standby holding exactly that URL and swaps it in, so the
  /// `play()` it issues starts from buffer.
  ///
  /// Two elements rather than one because an `<audio>` has one `src`,
  /// and re-pointing the live one would stop the song in the reader's
  /// ears.
  ///
  /// Idempotent per URL: the handler calls it on every `timeupdate`
  /// inside the lead window, and reassigning `src` would restart the
  /// buffering it already did.
  Future<void> preload(String url) async {
    if (_standbySrc == url) return;
    _standbySrc = url;
    _standby.src = url;
    _standby.load();
  }

  /// Play-and-pause the standby inside a user gesture, so that its
  /// later programmatic `play()` — from `ended`, with no gesture in
  /// sight — is permitted. Runs at most once, on the first [_start] that
  /// succeeds, which is by construction a gesture play (the first one
  /// always is, and a refused one throws before reaching here).
  ///
  /// The source is a one-sample silent WAV so the unlock is inaudible
  /// and fetches nothing. Failure is swallowed: a browser that does not
  /// need the unlock rejects nothing, and a browser that refuses it here
  /// would have refused the real play later anyway, at which point the
  /// old path (fetch at `ended`) still works in the foreground.
  void _unlockStandby() {
    if (_standbyUnlocked) return;
    _standbyUnlocked = true;
    try {
      final el = _standby;
      if (_standbySrc == null) el.src = _kSilentWav;
      el.play().toDart.then((_) => el.pause()).catchError((_) {});
    } catch (_) {
      // Deliberately ignored — see above.
    }
  }

  /// 44-byte RIFF header plus one silent 8-bit mono sample at 8 kHz.
  static const _kSilentWav =
      'data:audio/wav;base64,UklGRiUAAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQEAAAAA';

  Future<void> dispose() async {
    _standby.pause();
    _standby.removeAttribute('src');
    _el.pause();
    _el.removeAttribute('src');
    await _position.close();
    await _duration.close();
    await _playing.close();
    await _complete.close();
    await _error.close();
  }
}
