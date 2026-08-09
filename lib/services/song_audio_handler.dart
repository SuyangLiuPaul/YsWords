import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/foundation.dart';

import 'package:yswords/models/song.dart';
import 'package:yswords/models/song_queue.dart';

/// Bridges the song queue to the platform media session.
///
/// audio_service owns the parts a plain player cannot reach: the iOS
/// AVAudioSession and now-playing info (lock screen, Control Center,
/// CarPlay), the Android foreground service and media notification
/// (including Android Auto and steering-wheel buttons), and the Media
/// Session API on web. audioplayers stays the actual playback engine
/// underneath — this class translates between the two.
///
/// Why wrap rather than migrate: audioplayers already covers all six
/// targets this app ships to. just_audio would have needed a separate
/// media-kit backend for Windows and Linux, for no gain here.
class SongAudioHandler extends BaseAudioHandler with SeekHandler {
  SongAudioHandler() {
    _player.onPlayerStateChanged.listen((s) {
      _playing = s == ap.PlayerState.playing;
      _broadcast();
    });
    _player.onDurationChanged.listen((d) {
      _duration = d;
      _broadcast();
      _publishMediaItem();
    });
    _player.onPositionChanged.listen((p) {
      _position = p;
      _broadcast();
    });
    // Auto-advance. `onPlayerComplete` fires only on natural end, not
    // on stop()/pause(), so this cannot loop on user-initiated stops.
    _player.onPlayerComplete.listen((_) => _onTrackFinished());

    // ignore: unawaited_futures
    _configureSession();
  }

  /// Declare this app as a music player to the OS.
  ///
  /// Without an explicit category, iOS treats the audio as ambient and
  /// **the physical Ring/Silent switch mutes it** — playback keeps
  /// running, the position advances, the lock screen shows controls,
  /// and no sound comes out. That exact symptom was reported from an
  /// iPhone with the silent switch on. `AVAudioSessionCategory.playback`
  /// is what every music app uses to keep playing regardless of the
  /// switch, and it is also what permits audio to continue while the
  /// screen is locked.
  ///
  /// `usage: media` + `contentType: music` on Android does the
  /// equivalent: routes to the media volume stream rather than the
  /// notification one, so the volume keys adjust the right thing.
  ///
  /// Note this cannot help the WEB build — a browser page has no
  /// audio-session category to set, so on iOS Safari/Chrome the silent
  /// switch mutes web audio and nothing in our code can override it.
  /// That is a platform rule, and one more reason the native app is
  /// the answer for listening while driving.
  Future<void> _configureSession() async {
    if (kIsWeb) return;
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
        // Pause for a phone call, duck for a nav prompt, and resume
        // after — the behaviour a driver expects.
        androidAudioFocusGainType:
            AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: false,
      ));
    } catch (e) {
      // A misconfigured session must not stop playback from working
      // at all; it only costs the silent-switch override.
      debugPrint('[SongAudioHandler] audio session config failed: $e');
    }
  }

  final ap.AudioPlayer _player = ap.AudioPlayer();

  /// Injected so this file stays free of the native-only download
  /// layer: given a song and its upstream URL, returns what to
  /// actually open (a local file when downloaded, else the proxied or
  /// direct URL). Wired in main.dart.
  static String? Function(Song song, String url)? sourceResolver;

  SongQueue _queue = SongQueue.empty;
  bool _playing = false;
  bool _loading = false;
  String? _error;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Timer? _sleepTimer;
  DateTime? _sleepAt;

  /// Songs whose URL failed this session. Prevents an auto-advance
  /// loop: without it a queue of dead links would skip forward
  /// forever, hammering three church servers as it went.
  final Set<String> _failed = {};

  /// The song queue. Named `songQueue`, not `queue`, because
  /// BaseAudioHandler already owns `queue` as its BehaviorSubject of
  /// MediaItems — the OS-facing view of the same thing.
  SongQueue get songQueue => _queue;
  bool get isPlaying => _playing;
  bool get isLoading => _loading;
  String? get error => _error;
  Duration get position => _position;
  QueueItem? get currentItem => _queue.current;
  Song? get currentSong => _queue.current?.song;
  DateTime? get sleepAt => _sleepAt;

  Duration get duration {
    if (_duration > Duration.zero) return _duration;
    final published = _queue.current?.song.durationSec;
    return published == null ? Duration.zero : Duration(seconds: published);
  }

  // ── Queue control ───────────────────────────────────────────────

  /// Replace the queue and start playing at its current index.
  ///
  /// Note the ORDER: playback starts before the queue is published to
  /// the OS. Publishing is an await, and on iOS web an await between
  /// the user's tap and the play call costs the gesture activation the
  /// Web Audio context needs — see [_playCurrent]. The OS queue is a
  /// display detail; sound is not.
  Future<void> setQueue(SongQueue next, {bool autoPlay = true}) async {
    _queue = next;
    _failed.clear();
    if (next.isEmpty) {
      await _publishQueue();
      await stop();
      return;
    }
    if (autoPlay) {
      final started = _playCurrent();
      await _publishQueue();
      await started;
    } else {
      await _publishQueue();
      _publishMediaItem();
      _broadcast();
    }
  }

  Future<void> playAt(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _queue = _queue.copyWith(index: index);
    await _playCurrent();
  }

  Future<void> setShuffle(bool on) async {
    _queue = _queue.withShuffle(on);
    await _publishQueue();
    _broadcast();
  }

  Future<void> setRepeat(RepeatMode mode) async {
    _queue = _queue.copyWith(repeat: mode);
    _broadcast();
  }

  /// Sleep timer — pauses playback at [at]. Passing null cancels.
  void setSleepTimer(Duration? after) {
    _sleepTimer?.cancel();
    if (after == null) {
      _sleepTimer = null;
      _sleepAt = null;
      _broadcast();
      return;
    }
    _sleepAt = DateTime.now().add(after);
    _sleepTimer = Timer(after, () async {
      _sleepAt = null;
      await pause();
    });
    _broadcast();
  }

  // ── audio_service contract ──────────────────────────────────────
  // These are what the lock screen, CarPlay, Android Auto, headset
  // buttons and the web Media Session actually call.

  @override
  Future<void> play() async {
    if (_queue.isEmpty) return;
    if (currentItem == null) return;
    await _player.resume();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() async {
    _sleepTimer?.cancel();
    _sleepAt = null;
    await _player.stop();
    _playing = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    _broadcast();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    final next = _queue.nextIndex();
    if (next == null) {
      await stop();
      return;
    }
    _queue = _queue.copyWith(index: next);
    await _playCurrent();
  }

  @override
  Future<void> skipToPrevious() async {
    // Standard media behaviour: past a few seconds in, "previous"
    // restarts the current track rather than leaving it.
    if (_position > const Duration(seconds: 3)) {
      await seek(Duration.zero);
      return;
    }
    final prev = _queue.previousIndex();
    if (prev == null) {
      await seek(Duration.zero);
      return;
    }
    _queue = _queue.copyWith(index: prev);
    await _playCurrent();
  }

  @override
  Future<void> skipToQueueItem(int index) => playAt(index);

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    await setRepeat(switch (repeatMode) {
      AudioServiceRepeatMode.one => RepeatMode.one,
      AudioServiceRepeatMode.all ||
      AudioServiceRepeatMode.group =>
        RepeatMode.all,
      AudioServiceRepeatMode.none => RepeatMode.off,
    });
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) =>
      setShuffle(shuffleMode != AudioServiceShuffleMode.none);

  // ── Internals ───────────────────────────────────────────────────

  Future<void> _playCurrent() async {
    final item = _queue.current;
    if (item == null) return;

    // ── iOS web: play() MUST be reached with the user gesture still
    // valid. ────────────────────────────────────────────────────────
    //
    // audioplayers_web routes audio through the Web Audio API
    // (`createMediaElementSource` in wrapped_player.recreateNode), so
    // nothing is audible unless its AudioContext is running. It tries
    // to `resume()` that context — but iOS only permits
    // AudioContext.resume() inside a user gesture, and every `await`
    // between the tap and that call spends the activation.
    //
    // The symptom when it fails is precisely what was reported from an
    // iPhone: element.play() succeeds, currentTime advances, the media
    // session shows "playing", and there is no sound.
    //
    // So the play call is issued FIRST, synchronously, before any
    // state updates or notifications — and the future is awaited
    // afterwards. Everything below this line used to happen before it.
    final resolved = sourceResolver?.call(item.song, item.url) ?? item.url;
    final source = resolved.startsWith('/') && !kIsWeb
        ? ap.DeviceFileSource(resolved)
        : ap.UrlSource(resolved) as ap.Source;
    final playing = _player.play(source);

    _loading = true;
    _error = null;
    _position = Duration.zero;
    _duration = Duration.zero;
    _publishMediaItem();
    _broadcast();

    try {
      await playing;
      _failed.remove(item.song.id);
    } catch (e) {
      // One dead URL must not end the listening session. Drop it and
      // move on — the catalogue points at four third-party servers and
      // any of them can 404 between syncs.
      debugPrint('[SongAudioHandler] ${item.song.id} failed: $e');
      _failed.add(item.song.id);
      _error = e.toString();
      _loading = false;
      _broadcast();
      await _skipPastFailure();
      return;
    }
    _loading = false;
    _broadcast();
  }

  Future<void> _skipPastFailure() async {
    // Every remaining track already failed → stop rather than spin.
    final playable =
        _queue.items.where((i) => !_failed.contains(i.song.id)).length;
    if (playable == 0) {
      await stop();
      return;
    }
    final next = _queue.nextIndex();
    if (next == null) {
      await stop();
      return;
    }
    _queue = _queue.copyWith(index: next);
    await _playCurrent();
  }

  Future<void> _onTrackFinished() async {
    if (_queue.repeat == RepeatMode.one) {
      await seek(Duration.zero);
      await _player.resume();
      return;
    }
    await skipToNext();
  }

  /// Publish the queue to the OS so CarPlay / Android Auto can show
  /// and jump around the track list, not just play/pause.
  Future<void> _publishQueue() async {
    queue.add([for (final item in _queue.items) _toMediaItem(item)]);
  }

  void _publishMediaItem() {
    final item = _queue.current;
    if (item == null) return;
    mediaItem.add(_toMediaItem(item));
  }

  /// What the lock screen / CarPlay actually displays.
  MediaItem _toMediaItem(QueueItem item) {
    final s = item.song;
    // Name the mix in the title when it is not the sung take, so a
    // glance at the lock screen says whether this is the instrumental.
    final suffix = switch (item.kind) {
      'instrumental' => ' (伴奏)',
      'accompaniment' => ' (伴唱)',
      _ => '',
    };
    return MediaItem(
      id: item.url,
      title: '${s.title}$suffix',
      artist: s.creditLine ?? s.sourceLabel,
      album: s.album ?? _queue.sourceLabel,
      duration: s.durationSec == null
          ? null
          : Duration(seconds: s.durationSec!),
      artUri: s.artworkUrl == null ? null : Uri.tryParse(s.artworkUrl!),
      extras: {'songId': s.id, 'kind': item.kind},
    );
  }

  /// Push transport state to the OS + any listening UI.
  void _broadcast() {
    final hasNext = _queue.hasNext;
    final hasPrev = _queue.hasPrevious;
    playbackState.add(PlaybackState(
      controls: [
        if (hasPrev) MediaControl.skipToPrevious,
        if (_playing) MediaControl.pause else MediaControl.play,
        if (hasNext) MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: _loading
          ? AudioProcessingState.loading
          : (_queue.isEmpty
              ? AudioProcessingState.idle
              : AudioProcessingState.ready),
      playing: _playing,
      updatePosition: _position,
      bufferedPosition: _position,
      speed: 1.0,
      queueIndex: _queue.isEmpty ? null : _queue.index,
      repeatMode: switch (_queue.repeat) {
        RepeatMode.off => AudioServiceRepeatMode.none,
        RepeatMode.all => AudioServiceRepeatMode.all,
        RepeatMode.one => AudioServiceRepeatMode.one,
      },
      shuffleMode: _queue.shuffled
          ? AudioServiceShuffleMode.all
          : AudioServiceShuffleMode.none,
    ));
    notifyUi();
  }

  /// ChangeNotifier-style hook for Flutter widgets. audio_service's
  /// streams are the OS-facing contract; this is the in-app one.
  final ValueNotifier<int> revision = ValueNotifier(0);
  void notifyUi() => revision.value++;

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyUi();
  }

  Future<void> dispose() async {
    _sleepTimer?.cancel();
    await _player.dispose();
  }
}
