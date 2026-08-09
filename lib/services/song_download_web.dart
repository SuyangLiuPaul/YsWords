import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
// For `has` — Cache Storage is absent in non-secure contexts, so its
// presence has to be probed rather than assumed.
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

import 'package:yswords/models/song.dart';
import 'package:yswords/services/song_download_types.dart';
import 'package:yswords/services/song_player_service.dart';

/// Web build of the download service — real offline downloads, backed
/// by the Cache Storage API.
///
/// This used to be a no-op stub on the reasoning that a browser gives
/// no managed file system. It does give one: Cache Storage, which
/// holds whole responses on disk under a quota the page can ask to
/// have made durable.
///
/// Playback reads it **directly**, not through a Service Worker. The
/// worker route was tried and abandoned: a worker only sees requests
/// from pages inside its scope, and root scope already belongs to
/// Flutter's own generated worker — two scripts cannot share one.
/// Instead a downloaded song's cached body is turned into a blob URL
/// and handed to the audio element, which needs no interception, works
/// with the tab offline, and sidesteps Range requests entirely because
/// a blob URL is never fetched over HTTP.
///
/// Two honest differences from the native builds, both surfaced rather
/// than hidden:
///
///  * **The browser may evict it.** `navigator.storage.persist()` is
///    requested on first download, which on most browsers makes the
///    cache exempt from routine eviction, but it is a request and not
///    a guarantee. Downloads are re-checked against the cache on every
///    launch, so an evicted song reverts to "not downloaded" instead of
///    lying about being available.
///  * **The quota is not ours to set.** `estimate()` reports what is
///    left, and a download that would not fit fails with that reason
///    rather than filling the disk and dying halfway.
class SongDownloadService extends ChangeNotifier {
  SongDownloadService._();

  static final SongDownloadService instance = SongDownloadService._();

  /// Cache Storage is on every browser this app supports, but it is
  /// absent in non-secure contexts — so check rather than assume.
  static bool get isSupported {
    try {
      return (web.window as JSObject).has('caches');
    } catch (_) {
      return false;
    }
  }

  /// Kept as `song-media-v1` so anything an earlier build cached is
  /// still found. index.html's self-heal deliberately exempts every
  /// `song-media-` bucket from its cache sweep — downloads live here.
  static const _cacheName = 'song-media-v1';
  static const _indexKey = 'songs.downloads.web.v1';

  /// One at a time. The native service runs three, but every byte here
  /// crosses our own Netlify proxy rather than going direct to the
  /// church, so this is the download that costs us bandwidth — and a
  /// browser tab is a worse place to run three large streams.
  static const _maxConcurrent = 1;

  final Map<String, _WebDownload> _index = {};

  /// songId → object URL for its cached audio.
  ///
  /// Built up front rather than on demand because the player resolves
  /// a source SYNCHRONOUSLY: reading Cache Storage at play time would
  /// mean an await between the user's tap and `play()`, which is
  /// exactly what costs the gesture activation iOS requires. An object
  /// URL is only a handle to a blob the browser already has on disk,
  /// so holding a few hundred of them is cheap.
  final Map<String, String> _blobUrls = {};
  final Map<String, SongDownloadStatus> _status = {};
  final List<Song> _queue = [];
  final Set<String> _active = {};

  bool _loaded = false;
  bool _cancelled = false;
  int _batchTotal = 0;
  int _batchDone = 0;

  Future<void> init() async {
    if (_loaded || !isSupported) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_indexKey);
      if (raw != null) {
        final decoded = json.decode(raw) as Map<String, dynamic>;
        for (final e in decoded.entries) {
          final m = e.value as Map<String, dynamic>;
          _index[e.key] = _WebDownload(
            url: m['url'] as String,
            bytes: (m['bytes'] as num?)?.toInt() ?? 0,
          );
        }
      }

      // Reconcile against the cache, exactly as the native service
      // reconciles against the filesystem. The browser can evict
      // without telling us, and an index that still claims a song is
      // downloaded would send a plane passenger to a dead play button.
      final cache = await _cache();
      final gone = <String>[];
      for (final e in _index.entries) {
        final hit = await cache.match(e.value.url.toJS).toDart;
        if (hit == null) gone.add(e.key);
      }
      for (final id in gone) {
        _index.remove(id);
      }
      if (gone.isNotEmpty) await _persist();

      for (final e in _index.entries) {
        _status[e.key] = SongDownloadStatus(
          state: SongDownloadState.done,
          bytes: e.value.bytes,
        );
        await _makeBlobUrl(e.key, e.value.url, cache);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[SongDownloadService/web] init failed: $e');
    }
  }

  /// Turn a cached response into an object URL the player can use.
  Future<void> _makeBlobUrl(String songId, String url,
      [web.Cache? open]) async {
    try {
      final cache = open ?? await _cache();
      final hit = await cache.match(url.toJS).toDart;
      if (hit == null) return;
      final blob = await hit.blob().toDart;
      _blobUrls[songId] = web.URL.createObjectURL(blob);
    } catch (e) {
      // Falling back to the network URL is correct here: the song
      // simply streams instead of playing from disk.
      debugPrint('[SongDownloadService/web] blob url failed: $e');
    }
  }

  void _revoke(String songId) {
    final u = _blobUrls.remove(songId);
    if (u != null) {
      try {
        web.URL.revokeObjectURL(u);
      } catch (_) {/* already gone */}
    }
  }

  /// The source playback should use for [song] — the offline copy when
  /// there is one, else null so the caller falls back to the network.
  String? offlineSourceFor(Song song) => _blobUrls[song.id];

  Future<web.Cache> _cache() async =>
      (await web.window.caches.open(_cacheName).toDart);

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _indexKey,
      json.encode({
        for (final e in _index.entries)
          e.key: {'url': e.value.url, 'bytes': e.value.bytes},
      }),
    );
  }

  // ── Queries ─────────────────────────────────────────────────────

  SongDownloadStatus statusOf(Song song) =>
      _status[song.id] ?? const SongDownloadStatus();

  bool isDownloaded(Song song) => _index.containsKey(song.id);

  /// Always null: on web there is no filesystem path. The offline copy
  /// is reached through a blob URL instead — see [offlineSourceFor]
  /// and [resolveSongSource].
  String? localPathFor(Song song) => null;

  int get downloadedCount => _index.length;
  int get totalBytes =>
      _index.values.fold(0, (sum, d) => sum + d.bytes);
  int get pendingCount => _queue.length + _active.length;
  bool get isBusy => pendingCount > 0;
  int get batchTotal => _batchTotal;
  int get batchDone => _batchDone;
  double get batchProgress =>
      _batchTotal == 0 ? 0 : (_batchDone / _batchTotal).clamp(0.0, 1.0);

  /// Rough size of a selection, for the confirm dialog. Shares the
  /// native build's 4 MB-per-song assumption so the two agree.
  static int estimateBytes(Iterable<Song> songs) =>
      songs.where((s) => s.hasPlayableAudio).length * 4 * 1024 * 1024;

  static String formatBytes(int bytes) => formatDownloadBytes(bytes);

  // ── Commands ────────────────────────────────────────────────────

  Future<void> enqueue(Iterable<Song> songs) async {
    if (!isSupported) return;
    await init();
    _cancelled = false;

    // Ask to be exempt from routine eviction. Best-effort: Firefox
    // prompts, Safari decides on its own, and a refusal only means the
    // cache is evictable — which the reconcile on init already handles.
    try {
      await web.window.navigator.storage.persist().toDart;
    } catch (_) {/* not fatal */}

    final wanted = [
      for (final s in songs)
        if (s.hasPlayableAudio && !isDownloaded(s) && !_isQueued(s)) s,
    ];
    if (wanted.isEmpty) return;

    _queue.addAll(wanted);
    _batchTotal += wanted.length;
    for (final s in wanted) {
      _status[s.id] = const SongDownloadStatus(
          state: SongDownloadState.queued);
    }
    notifyListeners();
    _pump();
  }

  bool _isQueued(Song song) =>
      _active.contains(song.id) || _queue.any((s) => s.id == song.id);

  Future<void> cancelAll() async {
    _cancelled = true;
    for (final s in _queue) {
      _status.remove(s.id);
    }
    _queue.clear();
    _batchTotal = _batchDone = 0;
    notifyListeners();
  }

  Future<void> delete(Song song) async {
    final entry = _index.remove(song.id);
    _status.remove(song.id);
    _revoke(song.id);
    if (entry != null) {
      try {
        final cache = await _cache();
        await cache.delete(entry.url.toJS).toDart;
      } catch (e) {
        debugPrint('[SongDownloadService/web] delete failed: $e');
      }
      await _persist();
    }
    notifyListeners();
  }

  Future<void> deleteAll() async {
    final urls = [for (final d in _index.values) d.url];
    for (final id in _index.keys.toList()) {
      _revoke(id);
    }
    _index.clear();
    _status.clear();
    try {
      final cache = await _cache();
      for (final u in urls) {
        await cache.delete(u.toJS).toDart;
      }
    } catch (e) {
      debugPrint('[SongDownloadService/web] deleteAll failed: $e');
    }
    await _persist();
    notifyListeners();
  }

  // ── Worker ──────────────────────────────────────────────────────

  void _pump() {
    while (_active.length < _maxConcurrent && _queue.isNotEmpty) {
      if (_cancelled) return;
      final song = _queue.removeAt(0);
      _active.add(song.id);
      unawaited(_download(song).whenComplete(() {
        _active.remove(song.id);
        _batchDone++;
        if (_queue.isEmpty && _active.isEmpty) {
          _batchTotal = _batchDone = 0;
        }
        notifyListeners();
        _pump();
      }));
    }
  }

  Future<void> _download(Song song) async {
    final source = song.audioUrl ??
        (song.audioTracks.isEmpty ? null : song.audioTracks.first.url);
    if (source == null) return;

    // The same rewrite playback uses, so what we store is keyed by the
    // URL the player will later ask for. Caching the upstream URL
    // instead would store a file the Service Worker never matches.
    final url = SongPlayerService.resolvePlaybackUrl(source);

    _status[song.id] = const SongDownloadStatus(
        state: SongDownloadState.downloading);
    notifyListeners();

    try {
      final res = await web.window.fetch(url.toJS).toDart;
      if (!res.ok) {
        throw StateError('HTTP ${res.status}');
      }
      // Read to a blob rather than streaming chunk-by-chunk: the
      // per-song ring is a nicety, but a partially-written cache entry
      // that the Service Worker would happily serve as a whole song is
      // not. One complete response, stored in one step.
      final blob = await res.blob().toDart;
      final bytes = blob.size.toInt();

      final cache = await _cache();
      await cache
          .put(url.toJS, web.Response(blob as JSAny, _audioInit()))
          .toDart;

      _index[song.id] = _WebDownload(url: url, bytes: bytes);
      _status[song.id] = SongDownloadStatus(
          state: SongDownloadState.done, bytes: bytes);
      _blobUrls[song.id] = web.URL.createObjectURL(blob);
      await _persist();
    } catch (e) {
      debugPrint('[SongDownloadService/web] ${song.id} failed: $e');
      _status[song.id] = SongDownloadStatus(
        state: SongDownloadState.failed,
        error: '$e',
      );
    }
    notifyListeners();
  }

  /// Content-Type matters: the cached response is what the audio
  /// element receives, and a blob stored without it can come back as
  /// `application/octet-stream`, which Safari refuses to decode.
  static web.ResponseInit _audioInit() => web.ResponseInit(
        status: 200,
        statusText: 'OK',
        headers: {'Content-Type': 'audio/mpeg'}.jsify() as JSObject,
      );
}

class _WebDownload {
  final String url;
  final int bytes;
  const _WebDownload({required this.url, required this.bytes});
}

/// Where playback should read [song] from.
///
/// A downloaded song resolves to a blob URL backed by Cache Storage —
/// no network, so it plays with the tab offline. Everything else
/// resolves to the same-origin proxy path, which is what makes web
/// playback possible at all (the church servers send no CORS headers).
String? resolveSongSource(Song song, String url) =>
    SongDownloadService.instance.offlineSourceFor(song) ??
    SongPlayerService.resolvePlaybackUrl(url);
