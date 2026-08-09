import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'package:yswords/models/song.dart';

/// Which mix of a song is playing. fydt publishes up to three
/// renderings of the same piece and the church uses all of them —
/// the sung take for listening, the instrumental for accompaniment
/// when a congregation sings, the minus-one for practice.
enum SongTrack { vocal, instrumental, accompaniment }

/// App-wide single-track player for the Songs directory.
///
/// One [AudioPlayer] for the whole app, not one per tile: tapping a
/// second song stops the first, which is what a song *directory*
/// should do (a playlist player would be a different feature). Held
/// as a singleton rather than provided through the widget tree so
/// playback survives navigating away from the Songs page.
class SongPlayerService extends ChangeNotifier {
  SongPlayerService._() {
    _player.onPlayerStateChanged.listen((state) {
      _playing = state == PlayerState.playing;
      if (state == PlayerState.completed) {
        _position = Duration.zero;
      }
      notifyListeners();
    });
    _player.onDurationChanged.listen((d) {
      _duration = d;
      notifyListeners();
    });
    _player.onPositionChanged.listen((p) {
      _position = p;
      notifyListeners();
    });
  }

  static final SongPlayerService instance = SongPlayerService._();

  /// Hook letting the download layer redirect playback to a local
  /// file. Injected rather than imported so this service does not
  /// depend on the download service — which is native-only, while
  /// this one runs everywhere. Wired in `main.dart`.
  static String? Function(Song song, String url)? _sourceResolver;

  static void useSourceResolver(
      String? Function(Song song, String url) resolver) {
    _sourceResolver = resolver;
  }

  final AudioPlayer _player = AudioPlayer();

  Song? _current;
  SongTrack _track = SongTrack.vocal;

  /// The exact URL now loaded. [SongTrack] has three slots, but a song
  /// can publish several *vocal* takes (CDC's per-language recordings),
  /// so the enum alone cannot say which one is playing.
  String? _currentUrl;
  bool _playing = false;
  bool _loading = false;
  String? _error;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  Song? get current => _current;
  SongTrack get track => _track;
  bool get isPlaying => _playing;
  bool get isLoading => _loading;
  String? get error => _error;
  Duration get position => _position;

  /// Prefers the length the player reports; falls back to the
  /// catalogue's published duration so the scrubber has a sane range
  /// before the stream's metadata arrives.
  Duration get duration {
    if (_duration > Duration.zero) return _duration;
    final published = _current?.durationSec;
    return published == null ? Duration.zero : Duration(seconds: published);
  }

  String? get currentUrl => _currentUrl;

  bool isCurrent(Song song, [SongTrack? track]) =>
      _current?.id == song.id && (track == null || _track == track);

  /// Whether this exact URL is the one loaded — the check the detail
  /// sheet needs, where two chips can share [SongTrack.vocal].
  bool isCurrentUrl(Song song, String url) =>
      _current?.id == song.id && _currentUrl == url;

  /// The URL for [track] on [song], or null when that mix does not
  /// exist. SoundCloud rows return null everywhere — they have no
  /// streamable URL and are opened externally instead.
  static String? urlFor(Song song, SongTrack track) {
    switch (track) {
      case SongTrack.vocal:
        return song.audioUrl;
      case SongTrack.instrumental:
        return song.instrumentalUrl;
      case SongTrack.accompaniment:
        return song.accompanimentUrl;
    }
  }

  /// Upstream media host → the same-origin prefix that proxies it.
  /// Paired with the `/song-media/*` rules in `netlify.toml`.
  static const Map<String, String> _webProxyPrefixes = {
    'https://fydt.org/': '/song-media/fydt/',
    'https://www.christiandiscipleschurch.org/': '/song-media/cdc/',
    'https://cahayapengharapan.org/': '/song-media/cahaya/',
  };

  /// Rewrite an upstream media URL to whatever this platform can
  /// actually load.
  ///
  /// On **web** it goes through our own origin. `audioplayers_web`
  /// hard-codes `crossOrigin = 'anonymous'` on the <audio> element
  /// (wrapped_player.dart:78, no way to turn it off), so the browser
  /// CORS-checks every load — and none of the three church servers
  /// send `Access-Control-Allow-Origin`. Same-origin sidesteps the
  /// check entirely rather than asking three sites to reconfigure.
  ///
  /// Everywhere else the URL is returned untouched: native HTTP
  /// clients have no CORS notion, so those platforms stream directly
  /// from the church and none of the bandwidth touches our host.
  ///
  /// An unrecognised host is passed through unchanged — a new source
  /// added to the catalogue plays direct until a proxy rule for it
  /// lands in netlify.toml.
  static String resolvePlaybackUrl(String url) {
    if (!kIsWeb) return url;
    for (final entry in _webProxyPrefixes.entries) {
      if (url.startsWith(entry.key)) {
        return entry.value + url.substring(entry.key.length);
      }
    }
    return url;
  }

  /// Play [track] of [song]. Tapping the mix that is already playing
  /// pauses it; tapping a paused current track resumes without
  /// re-fetching.
  Future<void> toggle(
    Song song, [
    SongTrack track = SongTrack.vocal,
    String? explicitUrl,
  ]) async {
    // `explicitUrl` lets a caller pick one specific take — the
    // per-language vocals both map to SongTrack.vocal, so the enum
    // cannot distinguish them on its own.
    final url = explicitUrl ??
        urlFor(song, track) ??
        (track == SongTrack.vocal && song.audioTracks.isNotEmpty
            ? song.audioTracks.first.url
            : null);
    if (url == null) return;

    if (isCurrentUrl(song, url)) {
      if (_playing) {
        await _player.pause();
      } else {
        await _player.resume();
      }
      return;
    }

    _current = song;
    _track = track;
    _currentUrl = url;
    _position = Duration.zero;
    _duration = Duration.zero;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      await _player.stop();
      final source = _sourceResolver?.call(song, url);
      if (source != null && source.startsWith('/')) {
        // A downloaded file. DeviceFileSource, not UrlSource — the
        // latter would try to treat the path as a relative URL.
        await _player.play(DeviceFileSource(source));
      } else {
        await _player.play(UrlSource(source ?? resolvePlaybackUrl(url)));
      }
    } catch (e) {
      // A dead media URL must not take the page down with it — the
      // catalogue points at three third-party servers and any of them
      // can 404 between syncs. Surface it on the mini-player instead.
      _error = e.toString();
      _current = null;
      _currentUrl = null;
      _playing = false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> seek(Duration to) => _player.seek(to);

  Future<void> stop() async {
    await _player.stop();
    _current = null;
    _currentUrl = null;
    _playing = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  /// 'm:ss' for a scrubber label.
  static String formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
