import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/services/media_focus.dart';
import 'package:yswords/services/playback/song_playback_engine.dart';

/// One audio file of a sermon.
///
/// Sermons were recorded onto tape sides, so a single sermon is
/// normally two files and can be six. They are parts of one talk, not
/// separate items: part b begins mid-sentence where part a ran out.
@immutable
class SermonAudioPart {
  const SermonAudioPart({
    required this.part,
    required this.file,
    required this.bytes,
  });

  /// 'a', 'b', 'c'… — the tape side, and the play order.
  final String part;

  /// Filename as it exists on the source drive.
  final String file;
  final int bytes;

  factory SermonAudioPart.fromJson(Map<String, dynamic> j) => SermonAudioPart(
        part: (j['part'] ?? 'a') as String,
        file: (j['file'] ?? '') as String,
        bytes: (j['bytes'] as num?)?.toInt() ?? 0,
      );
}

/// Playback for Pastor Eric H.H. Chang's recorded sermons.
///
/// Every one of the 289 sermons has audio — 661 files, 5.46 GB, 32 kbps
/// mono. The inventory lives in `assets/sermons/audio_index.json` and
/// carries filenames only, because **where the audio is hosted is not
/// decided yet**. [baseUrl] is the single place that answers it: point
/// it at a bucket and every sermon resolves.
///
/// Until it is set, [isAvailable] is false and the UI shows nothing —
/// which is the honest state. A play button that 404s would be worse
/// than no play button.
class SermonAudioService extends ChangeNotifier {
  SermonAudioService._() {
    // One sound at a time — a hymn or a video starting pauses the
    // sermon, and vice versa. See [MediaFocus].
    MediaFocus.instance.register(
        this, () async => _playing ? await _player.pause() : null);
  }

  static final SermonAudioService instance = SermonAudioService._();

  /// Where the sermon MP3s live, with a trailing slash.
  ///
  /// Empty until hosting is chosen (Cloudflare R2, a Netlify site, a
  /// China-side bucket — the decision is about cost and about whether
  /// mainland listeners can reach it, not about this code). Set it via
  /// `--dart-define=SERMON_AUDIO_BASE=https://…/` and everything below
  /// starts working; nothing else needs to change.
  static const String baseUrl =
      String.fromEnvironment('SERMON_AUDIO_BASE', defaultValue: '');

  static bool get isConfigured => baseUrl.isNotEmpty;

  static const _positionKeyPrefix = 'sermon.audio.pos.';

  final SongPlaybackEngine _player = SongPlaybackEngine();
  Map<String, List<SermonAudioPart>>? _index;

  String? _sermonId;
  int _partIndex = 0;
  bool _playing = false;
  bool _loading = false;
  String? _error;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _wired = false;

  // ── State ───────────────────────────────────────────────────────

  String? get sermonId => _sermonId;
  bool get isPlaying => _playing;
  bool get isLoading => _loading;
  String? get error => _error;
  Duration get position => _position;
  Duration get duration => _duration;

  /// 1-based, for "Part 2 of 4".
  int get partNumber => _partIndex + 1;
  int get partCount => _sermonId == null ? 0 : (_index?[_sermonId]?.length ?? 0);
  bool get hasMultipleParts => partCount > 1;

  bool isCurrent(String sermonId) => _sermonId == sermonId;

  /// Whether this sermon can be played at all.
  bool hasAudio(String sermonId) =>
      isConfigured && (_index?[sermonId]?.isNotEmpty ?? false);

  // ── Setup ───────────────────────────────────────────────────────

  Future<void> load() async {
    if (_index != null) return;
    try {
      final raw =
          await rootBundle.loadString('assets/sermons/audio_index.json');
      final decoded = json.decode(raw) as Map<String, dynamic>;
      _index = {
        for (final e in decoded.entries)
          e.key: [
            for (final p in (e.value as List))
              SermonAudioPart.fromJson(p as Map<String, dynamic>),
          ],
      };
    } catch (e) {
      // No manifest is the normal state before hosting is wired.
      debugPrint('[SermonAudioService] no audio index: $e');
      _index = const {};
    }
    notifyListeners();
  }

  void _wire() {
    if (_wired) return;
    _wired = true;
    _player.onPlaying.listen((v) {
      _playing = v;
      if (v) _loading = false;
      notifyListeners();
    });
    _player.onPosition.listen((p) {
      _position = p;
      notifyListeners();
    });
    _player.onDuration.listen((d) {
      _duration = d;
      notifyListeners();
    });
    _player.onError.listen((e) {
      _error = e;
      _loading = false;
      notifyListeners();
    });
    // A tape side ending is not the sermon ending: roll straight into
    // the next part, because part b opens mid-sentence.
    _player.onComplete.listen((_) => _advancePart());
  }

  // ── Commands ────────────────────────────────────────────────────

  /// Start [sermonId], resuming where this listener left off.
  Future<void> play(String sermonId) async {
    await load();
    _wire();
    final parts = _index?[sermonId];
    if (!isConfigured || parts == null || parts.isEmpty) return;

    if (_sermonId == sermonId) {
      if (_playing) {
        await _player.pause();
      } else {
        await MediaFocus.instance.claim(this);
        await _player.resume();
      }
      return;
    }

    await MediaFocus.instance.claim(this);

    _sermonId = sermonId;
    _error = null;
    final saved = await _savedPosition(sermonId);
    _partIndex = saved.$1.clamp(0, parts.length - 1);
    _loading = true;
    notifyListeners();

    await _playPart(resumeAt: saved.$2);
  }

  Future<void> _playPart({Duration? resumeAt}) async {
    final parts = _index?[_sermonId];
    if (parts == null || _partIndex >= parts.length) return;
    _position = Duration.zero;
    _duration = Duration.zero;
    _pendingSeek = resumeAt;
    await _player.play(urlFor(parts[_partIndex]));
  }

  Duration? _pendingSeek;

  Future<void> _advancePart() async {
    final parts = _index?[_sermonId];
    if (parts == null) return;
    if (_partIndex + 1 >= parts.length) {
      // Finished. Clear the saved position so next time starts fresh
      // rather than resuming two seconds from the end.
      _playing = false;
      await _clearPosition(_sermonId!);
      notifyListeners();
      return;
    }
    _partIndex += 1;
    _loading = true;
    notifyListeners();
    await _playPart();
  }

  Future<void> pause() async {
    await _player.pause();
    await _savePosition();
  }

  Future<void> resume() => _player.resume();

  Future<void> stop() async {
    await _savePosition();
    await _player.stop();
    _sermonId = null;
    _playing = false;
    _position = Duration.zero;
    notifyListeners();
  }

  Future<void> seek(Duration to) async {
    await _player.seek(to);
    await _savePosition();
  }

  /// Skip within the talk. Sermons are long and people lose their
  /// place; 30 seconds back is the gesture every podcast app has.
  Future<void> nudge(Duration by) async {
    final target = _position + by;
    await seek(target < Duration.zero ? Duration.zero : target);
  }

  Future<void> skipToPart(int index) async {
    final parts = _index?[_sermonId];
    if (parts == null || index < 0 || index >= parts.length) return;
    _partIndex = index;
    _loading = true;
    notifyListeners();
    await _playPart();
  }

  /// The URL for one part. Kept public so a test can assert the shape
  /// without a network.
  static String urlFor(SermonAudioPart part) =>
      '$baseUrl${Uri.encodeComponent(part.file)}';

  /// Ordered parts for a sermon, or empty.
  List<SermonAudioPart> partsOf(String sermonId) =>
      _index?[sermonId] ?? const [];

  // ── Resume ──────────────────────────────────────────────────────
  //
  // A sermon runs 35-70 minutes across its parts. Losing your place is
  // the difference between a feature people use and one they try once.

  Future<void> _savePosition() async {
    final id = _sermonId;
    if (id == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        '$_positionKeyPrefix$id', '$_partIndex:${_position.inSeconds}');
  }

  Future<void> _clearPosition(String sermonId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_positionKeyPrefix$sermonId');
  }

  /// (partIndex, offset) for [sermonId].
  Future<(int, Duration)> _savedPosition(String sermonId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_positionKeyPrefix$sermonId');
      if (raw == null) return (0, Duration.zero);
      final bits = raw.split(':');
      return (
        int.tryParse(bits.first) ?? 0,
        Duration(seconds: int.tryParse(bits.last) ?? 0),
      );
    } catch (_) {
      return (0, Duration.zero);
    }
  }

  /// Apply a resume offset once the file reports a duration — seeking
  /// before that is clamped to zero.
  void applyPendingSeek() {
    final pending = _pendingSeek;
    if (pending == null || _duration <= Duration.zero) return;
    if (pending > Duration.zero && pending < _duration) {
      _pendingSeek = null;
      unawaited(_player.seek(pending));
    } else {
      _pendingSeek = null;
    }
  }

  static String formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
  }
}
