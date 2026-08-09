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

  final AudioPlayer _player = AudioPlayer();

  Song? _current;
  SongTrack _track = SongTrack.vocal;
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

  bool isCurrent(Song song, [SongTrack? track]) =>
      _current?.id == song.id && (track == null || _track == track);

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

  /// Play [track] of [song]. Tapping the mix that is already playing
  /// pauses it; tapping a paused current track resumes without
  /// re-fetching.
  Future<void> toggle(Song song, [SongTrack track = SongTrack.vocal]) async {
    final url = urlFor(song, track);
    if (url == null) return;

    if (isCurrent(song, track)) {
      if (_playing) {
        await _player.pause();
      } else {
        await _player.resume();
      }
      return;
    }

    _current = song;
    _track = track;
    _position = Duration.zero;
    _duration = Duration.zero;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      await _player.stop();
      await _player.play(UrlSource(url));
    } catch (e) {
      // A dead media URL must not take the page down with it — the
      // catalogue points at three third-party servers and any of them
      // can 404 between syncs. Surface it on the mini-player instead.
      _error = e.toString();
      _current = null;
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
