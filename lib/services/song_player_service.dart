import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';

import 'package:yswords/models/song.dart';
import 'package:yswords/models/song_queue.dart';
import 'package:yswords/services/media_focus.dart';
import 'package:yswords/services/song_audio_handler.dart';

/// Which mix of a song is playing. fydt and CDC both publish up to
/// three renderings of the same piece and the church uses all of them —
/// the sung take for listening, the instrumental when a congregation
/// sings, the minus-one for practice.
enum SongTrack { vocal, instrumental, accompaniment }

/// App-facing player façade.
///
/// 2026-08-09: this used to own an [AudioPlayer] directly and play one
/// track at a time. It is now a thin façade over [SongAudioHandler],
/// which adds the platform media session — lock screen, Control
/// Centre, CarPlay, Android Auto, headset and steering-wheel buttons,
/// and the Media Session API on web — plus a real queue.
///
/// Keeping the façade means widgets carry on talking to
/// `SongPlayerService.instance` and know nothing about audio_service.
/// It also gives one place to degrade gracefully: if `AudioService.init`
/// fails (an unconfigured platform, or a widget test with no
/// platform channels), playback still works through the bare handler,
/// just without system controls. Songs playing beats a crash.
class SongPlayerService extends ChangeNotifier {
  SongPlayerService._() {
    // Registered for the life of the app: this is a singleton, so
    // there is nothing to unregister and no leak to avoid.
    MediaFocus.instance.register(this, _pauseForFocus);
  }

  static final SongPlayerService instance = SongPlayerService._();

  static SongAudioHandler? _handler;
  static bool _initStarted = false;

  /// True when the platform media session is live — i.e. the lock
  /// screen and car controls will actually appear.
  static bool get hasMediaSession => _mediaSession;
  static bool _mediaSession = false;

  /// Boot the audio session. Call once, before `runApp`.
  ///
  /// Never throws: a failure here must not stop the whole app from
  /// starting, since Songs is one feature among many.
  static Future<void> init() async {
    if (_initStarted) return;
    _initStarted = true;
    final handler = SongAudioHandler();

    // 2026-08-10: audio_service is back on web.
    //
    // v1.4.22 skipped it here on the theory that it had silenced web
    // playback — the timeline fitted, but the theory was wrong and the
    // silence persisted without it. The real cause was audioplayers_web
    // routing audio through a suspended Web Audio context; web now
    // uses a bare HTMLAudioElement instead (see
    // services/playback/song_playback_engine.dart) and that whole
    // class of problem is gone.
    //
    // audio_service_web only manages Media Session metadata — it never
    // touches playback — so with the real cause removed there is no
    // reason to deny web the system media controls.
    try {
      _handler = await AudioService.init(
        builder: () => handler,
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'app.yswords.songs.playback',
          androidNotificationChannelName: 'Songs playback',
          // Keep the notification while paused: a driver who pauses at
          // a light must still be able to resume from the lock screen
          // without unlocking the phone.
          androidNotificationOngoing: false,
          androidStopForegroundOnPause: false,
        ),
      );
      _mediaSession = true;
    } catch (e) {
      // Unconfigured platform, or a test environment with no platform
      // channels. Fall back to the handler on its own.
      debugPrint('[SongPlayerService] media session unavailable: $e');
      _handler = handler;
      _mediaSession = false;
    }
    _handler!.revision.addListener(instance.notifyListeners);
  }

  static SongAudioHandler get _h {
    final h = _handler;
    if (h != null) return h;
    // A widget built before init() finished — construct a bare handler
    // so reads return sane values instead of throwing.
    final fallback = SongAudioHandler();
    _handler = fallback;
    fallback.revision.addListener(instance.notifyListeners);
    return fallback;
  }

  /// Where playback should read from — a downloaded file when there is
  /// one, else the network. Injected by main.dart so this layer keeps
  /// no dependency on the native-only download service.
  static void useSourceResolver(
      String? Function(Song song, String url) resolver) {
    SongAudioHandler.sourceResolver = resolver;
  }

  /// The origin whose `/song-media/*` rules native falls back to when
  /// a direct stream fails. qat rather than prod on purpose: prod is
  /// pinned at v1.4.11, which predates the proxy rules entirely — its
  /// `/song-media/*` returns the SPA's index.html (verified 2026-08-23,
  /// `content-type: text/html`), which an audio element cannot play.
  /// qat always carries the same netlify.toml dev just verified.
  static const String _fallbackProxyOrigin =
      'https://yswords-qat.netlify.app';

  /// Absolute proxy URL for [url], or null when no rule covers it.
  /// Native only — web ALWAYS goes through the proxy via
  /// [resolvePlaybackUrl], so there is no second route to fall to.
  static String? nativeProxyFallbackUrl(String url) {
    if (kIsWeb) return null;
    for (final entry in _webProxyPrefixes.entries) {
      if (url.startsWith(entry.key)) {
        return _fallbackProxyOrigin +
            entry.value +
            url.substring(entry.key.length);
      }
    }
    return null;
  }

  // ── State ───────────────────────────────────────────────────────

  Song? get current => _h.currentSong;
  QueueItem? get currentItem => _h.currentItem;
  SongQueue get queue => _h.songQueue;
  bool get isPlaying => _h.isPlaying;
  bool get isLoading => _h.isLoading;
  String? get error => _h.error;
  Duration get position => _h.position;
  Duration get duration => _h.duration;
  DateTime? get sleepAt => _h.sleepAt;
  bool get sleepAtEndOfTrack => _h.sleepAtEndOfTrack;
  String? get currentUrl => _h.currentItem?.url;

  /// Which mix is playing, for the UI's chip highlighting.
  SongTrack get track => switch (_h.currentItem?.kind) {
        'instrumental' => SongTrack.instrumental,
        'accompaniment' => SongTrack.accompaniment,
        _ => SongTrack.vocal,
      };

  bool isCurrent(Song song, [SongTrack? t]) =>
      _h.currentSong?.id == song.id && (t == null || track == t);

  /// Match on the exact URL: a song can have several *vocal* takes
  /// (CDC's per-language recordings), which the enum cannot tell apart.
  bool isCurrentUrl(Song song, String url) =>
      _h.currentSong?.id == song.id && _h.currentItem?.url == url;

  // ── Commands ────────────────────────────────────────────────────

  /// Play one song on its own, or toggle it if already current.
  ///
  /// Kept for the row play button and the detail sheet's mix chips.
  /// Playing from a list should use [playQueue] instead so next/
  /// previous and the lock-screen controls have somewhere to go.
  Future<void> toggle(
    Song song, [
    SongTrack t = SongTrack.vocal,
    String? explicitUrl,
  ]) async {
    final url = explicitUrl ?? _urlFor(song, t);
    if (url == null) return;

    if (isCurrentUrl(song, url)) {
      if (isPlaying) {
        await _h.pause();
      } else {
        // Resuming counts as starting to make sound — a video that is
        // running has to give way, same as on a fresh play.
        unawaited(MediaFocus.instance.claim(this));
        await _h.play();
      }
      return;
    }

    // NOT awaited before `setQueue`: on iOS web the play() call has to
    // land inside the user's gesture, and awaiting anything first
    // spends it. Pausing a video a beat late is invisible; losing the
    // gesture means silence.
    unawaited(MediaFocus.instance.claim(this));

    await _h.setQueue(SongQueue(
      items: [QueueItem(song: song, url: url, kind: _kindOf(t))],
      sourceLabel: song.album ?? song.sourceLabel,
    ));
  }

  /// Play a whole list, starting at [startIndex].
  /// Pass [startSongId] rather than [startIndex] whenever the caller is
  /// starting from a row the user tapped: unplayable songs are dropped
  /// while building, so a position taken from the visible list does not
  /// survive the trip.
  Future<void> playQueue(
    List<Song> songs, {
    int startIndex = 0,
    String? startSongId,
    TrackPreference preference = TrackPreference.vocal,
    TrackFallback fallback = TrackFallback.useVocal,
    bool shuffle = false,
    RepeatMode repeat = RepeatMode.off,
    String? label,
  }) async {
    final q = SongQueue.fromSongs(
      songs,
      preference: preference,
      fallback: fallback,
      startIndex: startIndex,
      startSongId: startSongId,
      shuffled: shuffle,
      repeat: repeat,
      sourceLabel: label,
    );
    unawaited(MediaFocus.instance.claim(this));
    await _h.setQueue(q);
  }

  /// Queue a song after the current one, or at the end.
  Future<void> addToQueue(Song song, {bool playNext = false}) =>
      _h.addToQueue(song, playNext: playNext);

  /// Drop a track from the queue you are listening to.
  Future<void> removeFromQueue(int index) => _h.removeFromQueue(index);

  Future<void> next() => _h.skipToNext();

  /// Registered with [MediaFocus] so a video can silence the hymn.
  /// Pause, never stop: the queue and the position stay put.
  Future<void> _pauseForFocus() => isPlaying ? _h.pause() : Future.value();

  Future<void> previous() => _h.skipToPrevious();
  Future<void> playAt(int index) => _h.playAt(index);
  Future<void> seek(Duration to) => _h.seek(to);
  Future<void> stop() => _h.stop();

  /// Stop and put the player away entirely — see
  /// [SongAudioHandler.dismiss]. This is what the mini-player's ✕ and
  /// its swipe-away gesture call. `stop()` alone leaves the strip on
  /// screen, which is the bug this exists to fix.
  Future<void> dismiss() => _h.dismiss();
  Future<void> setShuffle(bool on) => _h.setShuffle(on);
  Future<void> setRepeat(RepeatMode mode) => _h.setRepeat(mode);
  void setSleepTimer(Duration? after) => _h.setSleepTimer(after);
  void setSleepAtEndOfTrack(bool on) => _h.setSleepAtEndOfTrack(on);
  void clearError() => _h.clearError();

  /// Switch the whole queue between the sung take, the instrumental
  /// and the accompaniment without losing your place.
  Future<void> setTrackPreference(
    TrackPreference preference, {
    TrackFallback fallback = TrackFallback.useVocal,
  }) =>
      _h.setTrackPreference(preference, fallback);

  TrackPreference get trackPreference => _h.preference;
  TrackFallback get trackFallback => _h.fallback;

  bool get isShuffled => _h.songQueue.shuffled;
  RepeatMode get repeatMode => _h.songQueue.repeat;
  bool get hasQueue => _h.songQueue.length > 1;

  // ── Helpers ─────────────────────────────────────────────────────

  static String _kindOf(SongTrack t) => switch (t) {
        SongTrack.vocal => 'vocal',
        SongTrack.instrumental => 'instrumental',
        SongTrack.accompaniment => 'accompaniment',
      };

  String? _urlFor(Song song, SongTrack t) {
    final direct = switch (t) {
      SongTrack.vocal => song.audioUrl,
      SongTrack.instrumental => song.instrumentalUrl,
      SongTrack.accompaniment => song.accompanimentUrl,
    };
    if (direct != null) return direct;
    if (t == SongTrack.vocal && song.audioTracks.isNotEmpty) {
      return song.audioTracks.first.url;
    }
    return null;
  }

  /// Upstream media host → the same-origin prefix that proxies it.
  /// Paired with the `/song-media/*` rules in `netlify.toml`.
  static const Map<String, String> _webProxyPrefixes = {
    'https://fydt.org/': '/song-media/fydt/',
    'https://www.christiandiscipleschurch.org/': '/song-media/cdc/',
    'https://cahayapengharapan.org/': '/song-media/cahaya/',
    'https://cgdc.hk/': '/song-media/cgdc/',
  };

  /// Rewrite an upstream media URL to whatever this platform can load.
  ///
  /// On **web** it goes through our own origin: `audioplayers_web`
  /// hard-codes `crossOrigin = 'anonymous'` (wrapped_player.dart:78, no
  /// opt-out), so the browser CORS-checks every load — and none of the
  /// four church servers send `Access-Control-Allow-Origin`.
  /// Same-origin sidesteps the check rather than asking four sites to
  /// reconfigure.
  ///
  /// Everywhere else the URL is returned untouched: native HTTP clients
  /// have no CORS notion, so those platforms stream directly from the
  /// church and none of the bandwidth touches our host.
  static String resolvePlaybackUrl(String url) {
    if (!kIsWeb) return url;
    for (final entry in _webProxyPrefixes.entries) {
      if (url.startsWith(entry.key)) {
        return entry.value + url.substring(entry.key.length);
      }
    }
    return url;
  }

  /// 'm:ss' for a scrubber label.
  static String formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
