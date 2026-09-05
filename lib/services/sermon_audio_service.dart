import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/services/error_reporter.dart';
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
    this.path = '',
  });

  /// 'a', 'b', 'c'… — the tape side, and the play order.
  final String part;

  /// Filename as it exists on the source drive.
  final String file;
  final int bytes;

  /// Host-relative location, e.g.
  /// `/sites/default/files/ehhc_mp3_sermons/09_Matthew_and_Luke/006a_….mp3`.
  ///
  /// The files are grouped into 20 category folders, so [file] alone
  /// cannot address one — the original `baseUrl + filename` shape was
  /// never going to resolve against this host. Written by
  /// `tools/build_sermon_audio_index.py`; empty only if that has not
  /// run, in which case [SermonAudioService.urlFor] falls back to the
  /// old flat shape.
  final String path;

  factory SermonAudioPart.fromJson(Map<String, dynamic> j) => SermonAudioPart(
        part: (j['part'] ?? 'a') as String,
        file: (j['file'] ?? '') as String,
        bytes: (j['bytes'] as num?)?.toInt() ?? 0,
        path: (j['path'] ?? '') as String,
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
  SermonAudioService._() : this.withEngine(SongPlaybackEngine());

  /// @visibleForTesting — builds an instance around a caller-supplied
  /// engine instead of [instance]'s own, so a test can drive playback
  /// with a fake (`test/support/fake_song_playback_engine.dart`)
  /// without a real audio plugin or a WebKit to reproduce
  /// `docs/autonomous-queue.md:11582`'s AbortError races against.
  @visibleForTesting
  SermonAudioService.withEngine(SongPlaybackEngine engine)
      : _player = engine {
    // One sound at a time — a hymn or a video starting pauses the
    // sermon, and vice versa. See [MediaFocus].
    MediaFocus.instance.register(
        this, () async => _playing ? await _player.pause() : null);
  }

  static final SermonAudioService instance = SermonAudioService._();

  /// Origin the sermon MP3s are served from, with NO trailing slash.
  ///
  /// 2026-09-02: the church publishes all of them itself, and the user
  /// pointed at it — 「录音你可以直接用我们教会的」. So this is no longer a
  /// hosting decision waiting on a bill: 589 files, 289 sermons, all of
  /// them already online at
  /// `/content/ehhc_sermons_public`, with `accept-ranges: bytes` (206
  /// confirmed, not just advertised) and a one-year cache header.
  ///
  /// **There is no `access-control-allow-origin`, and it does not
  /// matter.** A media element is not a fetch: `new Audio(url)` on the
  /// https://yahwehword.com origin resolved metadata for one of these
  /// and reported a 764 s duration. Checked in a browser on the real
  /// origin rather than inferred. Anything here that ever starts
  /// *reading the bytes* — waveform, offline download, transcoding —
  /// will need a proxy; playback does not.
  ///
  /// Still overridable with `--dart-define=SERMON_AUDIO_BASE=https://…`
  /// if the files are ever mirrored (a China-side copy is the likely
  /// reason — mainland reachability of this host is untested).
  static const String baseUrl = String.fromEnvironment(
    'SERMON_AUDIO_BASE',
    defaultValue: 'https://www.christiandiscipleschurch.org',
  );

  static bool get isConfigured => baseUrl.isNotEmpty;

  static const _positionKeyPrefix = 'sermon.audio.pos.';

  final SongPlaybackEngine _player;
  Map<String, List<SermonAudioPart>>? _index;

  String? _sermonId;
  int _partIndex = 0;
  bool _playing = false;
  bool _loading = false;
  String? _error;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _wired = false;

  /// Set by `_playPart` right before it starts a load, cleared the
  /// first time `onPlaying(true)` fires afterwards. Exists only so
  /// that first event can be told apart from every later play/pause
  /// toggle — see `docs/autonomous-queue.md:11582`'s breadcrumb trail.
  bool _awaitingFirstPlaying = false;

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

  /// Number of sermons that resolve to at least one playable part.
  /// Exposed for the test that pins "all 289, not most of them".
  int get playableSermonCount =>
      _index?.values.where((p) => p.isNotEmpty).length ?? 0;

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
      if (v) {
        _loading = false;
        // The FIRST playing event after a `_playPart` load — the event
        // `docs/autonomous-queue.md:11582`'s seek-race mechanism needs
        // ordered against `applyPendingSeek`'s crumb. Later play/pause
        // toggles of the same part are not re-crumbed; they are not
        // part of the race the item is watching for.
        if (_awaitingFirstPlaying) {
          _awaitingFirstPlaying = false;
          ErrorReporter.breadcrumb('sermon.playing',
              data: 'id=$_sermonId part=$_partIndex');
        }
      }
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
    _player.onError.listen((event) {
      // The attempt id exists for `song_audio_handler.dart`'s
      // multi-track queue; a sermon plays one part at a time with no
      // "already moved on" race to guard against, so it is unused here.
      final (_, message) = event;
      _error = message;
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

    // `docs/autonomous-queue.md:11582`: a double tap on a sermon that
    // is not current yet lands both calls in the window before
    // `_loading` is set below, so both take the "load" branch. This
    // crumb is what would show that as two `sermon.play` entries
    // milliseconds apart, rather than proving it happened.
    final branch = _sermonId == sermonId ? 'toggle' : 'load';
    ErrorReporter.breadcrumb('sermon.play',
        data: 'id=$sermonId branch=$branch loading=$_loading');

    if (_sermonId == sermonId) {
      if (_playing) {
        await _player.pause();
      } else {
        await MediaFocus.instance.claim(this);
        try {
          await _player.resume();
        } on PlaybackBlockedException catch (e) {
          // See the note on `_playPart` below — same exception, same
          // "say so and let one more tap recover it" handling.
          debugPrint('[SermonAudioService] playback blocked (resume): $e');
          ErrorReporter.breadcrumb('sermon.blocked',
              data: 'context=resume id=$sermonId');
          _error = 'blocked';
          notifyListeners();
        }
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
    ErrorReporter.breadcrumb('sermon.playPart',
        data: 'part=$_partIndex resumeAt=${resumeAt ?? "none"}');
    _position = Duration.zero;
    _duration = Duration.zero;
    _pendingSeek = resumeAt;
    _awaitingFirstPlaying = true;
    try {
      await _player.play(urlFor(parts[_partIndex]));
    } on PlaybackBlockedException catch (e) {
      // The browser refused to START — not a dead file (see
      // `playback_blocked.dart`'s own doc comment on why that
      // distinction needs its own type). `song_audio_handler.dart`'s
      // `_playCurrent` catches the identical exception for songs; this
      // is the sermon path's missing counterpart. Both callers of
      // `_playPart` (`play()`, `_advancePart()`) previously let this
      // propagate uncaught: `_loading` stayed true forever with the
      // Listen button disabled, and the exception reached the app's
      // Zone-level crash reporter as `source: 'Zone'` instead of a
      // reader-visible message — reported from an iPhone at
      // /sermons/421, `PlaybackBlockedException(AbortError: The
      // operation was aborted.)`.
      debugPrint('[SermonAudioService] playback blocked: $e');
      ErrorReporter.breadcrumb('sermon.blocked',
          data: 'context=playPart part=$_partIndex');
      _error = 'blocked';
      _loading = false;
      notifyListeners();
    }
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
  ///
  /// `Uri.encodeComponent` would escape the slashes in [SermonAudioPart.path]
  /// and produce one long unrequestable segment, so each segment is
  /// encoded on its own. It matters here: the filenames carry
  /// apostrophes, brackets and commas — `The_Lord's_Concept…`,
  /// `…Parenting_(1).mp3`.
  static String urlFor(SermonAudioPart part) {
    if (part.path.isEmpty) {
      // Pre-2026-09-02 index shape: flat base + filename.
      return '$baseUrl${Uri.encodeComponent(part.file)}';
    }
    final encoded = part.path
        .split('/')
        .map(Uri.encodeComponent)
        .join('/');
    return '$baseUrl$encoded';
  }

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
      // The only crumb of the four the item asks for that fires from a
      // widget rebuild rather than the service's own flow (see
      // `SermonAudioBar._onServiceChanged`) — which is exactly why it
      // can land ahead of the first `sermon.playing` crumb above.
      ErrorReporter.breadcrumb('sermon.seek',
          data: 'to=${pending.inSeconds}s duration=${_duration.inSeconds}s');
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

  // ── Test surface ────────────────────────────────────────────────
  //
  // `PlaybackBlockedException` is only ever thrown by
  // `song_playback_engine_web.dart` — the conditional import resolves
  // to the NATIVE engine under `flutter test`'s VM runtime (see
  // `song_playback_engine_native.dart`, which routes every failure
  // through `onError` and never throws it). So the 'blocked' state
  // `_playPart` and the resume branch of `play()` now set on catching
  // it can never be reached by driving a real play() call in a test —
  // this lets a widget test set it directly instead, the same
  // reasoning as `ErrorReporter.resetForTest`.

  /// @visibleForTesting — puts the service into the state it would be
  /// in right after `_playPart` (or the resume branch of `play()`)
  /// caught a `PlaybackBlockedException` for [sermonId], without
  /// needing a real (web-only) playback engine to throw one.
  ///
  /// Also seeds a minimal one-part index entry for [sermonId] if the
  /// real index has not loaded — `SermonAudioBar.hasAudio` gates the
  /// whole bar on a non-empty `_index` entry, and `load()`'s
  /// `rootBundle` read is not reliable inside a plain `testWidgets`
  /// (see `sermon_audio_index_test.dart`'s header note, and this
  /// file's `load()`-does-not-throw test — both work around the same
  /// thing rather than depend on it).
  /// @visibleForTesting — seeds [_index] with [parts] for [sermonId]
  /// without touching `rootBundle`, for a test built on
  /// [SermonAudioService.withEngine] rather than [instance] (see that
  /// constructor's doc comment for why `load()`'s real asset read is
  /// avoided there).
  @visibleForTesting
  void seedForTest(String sermonId, List<SermonAudioPart> parts) {
    _index ??= {};
    _index![sermonId] = parts;
  }

  @visibleForTesting
  void setBlockedForTest(String sermonId) {
    _index ??= {};
    if ((_index![sermonId] ?? const []).isEmpty) {
      _index![sermonId] = const [
        SermonAudioPart(part: 'a', file: 'test.mp3', bytes: 1),
      ];
    }
    _sermonId = sermonId;
    _error = 'blocked';
    _loading = false;
    notifyListeners();
  }
}
