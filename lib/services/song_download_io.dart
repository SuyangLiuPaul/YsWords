import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/models/song.dart';
import 'package:yswords/services/song_download_types.dart';
import 'package:yswords/services/song_player_service.dart';

/// Downloads song audio for offline listening.
///
/// **Native only.** [isSupported] is false on web and every entry
/// point no-ops there. A browser has no file system this can manage,
/// and the catalogue's audio is ~2.5 GB — far past what a tab may
/// keep. Web offline support is a Service Worker cache instead
/// (`web/song_media_sw.js`), which is a genuinely different thing with
/// different guarantees, so it is not pretended to be this one.
///
/// Design notes:
///
///  • **Only the primary audio** is fetched by default. Pulling every
///    mix, MV and score for all 543 songs would be many gigabytes;
///    someone wanting a specific instrumental can queue that song's
///    other tracks explicitly.
///  • **Bounded concurrency.** Three at a time — enough to saturate a
///    normal connection without opening 500 sockets against three
///    small church servers.
///  • **Failure is per-song.** One dead URL marks that song failed and
///    the queue keeps going; a batch of 300 is not lost to one 404.
///  • **Resumes across restarts** at song granularity: the index only
///    records completed files, and a partial file is written to
///    `.part` and renamed on success, so an interrupted download is
///    never mistaken for a finished one.
class SongDownloadService extends ChangeNotifier {
  SongDownloadService._();

  static final SongDownloadService instance = SongDownloadService._();

  /// File downloads exist on native only — see the class docs.
  static bool get isSupported => !kIsWeb;

  static const _indexKey = 'songs.downloads.v1';
  static const _maxConcurrent = 3;

  /// songId → relative filename of the completed download.
  final Map<String, _DownloadRecord> _index = {};
  final Map<String, SongDownloadStatus> _status = {};
  final List<Song> _queue = [];
  final Set<String> _active = {};
  final Map<String, http.Client> _clients = {};

  Directory? _dir;
  bool _loaded = false;
  bool _cancelled = false;

  // ── Lifecycle ───────────────────────────────────────────────────

  /// Reads the on-disk index. Safe to call repeatedly.
  Future<void> init() async {
    if (_loaded || !isSupported) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_indexKey);
      if (raw != null) {
        final decoded = json.decode(raw) as Map<String, dynamic>;
        for (final entry in decoded.entries) {
          _index[entry.key] = _DownloadRecord.fromJson(
              (entry.value as Map).cast<String, dynamic>());
        }
      }
      // Reconcile against reality: a user can clear app storage, and
      // the OS can evict caches. An index entry whose file is gone
      // would otherwise render as "downloaded" and then fail to play.
      final dir = await _mediaDir();
      final missing = <String>[];
      for (final entry in _index.entries) {
        if (!File('${dir.path}/${entry.value.filename}').existsSync()) {
          missing.add(entry.key);
        }
      }
      for (final id in missing) {
        _index.remove(id);
      }
      if (missing.isNotEmpty) await _persist();

      for (final entry in _index.entries) {
        _status[entry.key] = SongDownloadStatus(
          state: SongDownloadState.done,
          bytes: entry.value.bytes,
        );
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[SongDownloadService] init failed: $e');
    }
  }

  Future<Directory> _mediaDir() async {
    if (_dir != null) return _dir!;
    // Application *support*, not documents: this is a reproducible
    // cache the user did not author, so it should not show up in
    // file browsers or iCloud backups.
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/song_media');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    _dir = dir;
    return dir;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _indexKey,
      json.encode({for (final e in _index.entries) e.key: e.value.toJson()}),
    );
  }

  // ── Queries ─────────────────────────────────────────────────────

  SongDownloadStatus statusOf(Song song) =>
      _status[song.id] ?? const SongDownloadStatus();

  bool isDownloaded(Song song) => _index.containsKey(song.id);

  /// Local file for [song]'s audio, when it has been downloaded.
  /// Returns null on web and for anything not downloaded.
  String? localPathFor(Song song) {
    final rec = _index[song.id];
    if (rec == null || _dir == null) return null;
    return '${_dir!.path}/${rec.filename}';
  }

  /// Local sheet-music PDF for [song], when one was downloaded with it.
  /// Null for songs that publish no score, whose score failed, or that
  /// were downloaded before scores were included.
  String? localScorePathFor(Song song) {
    final rec = _index[song.id];
    final name = rec?.scoreFilename;
    if (name == null || _dir == null) return null;
    return '${_dir!.path}/$name';
  }

  bool hasOfflineScore(Song song) => _index[song.id]?.scoreFilename != null;

  /// Always null on native — the offline score is a real file, reached
  /// through [localScorePathFor]. Present so the score viewer can ask
  /// both builds the same two questions without a `kIsWeb` branch.
  String? offlineScoreSourceFor(Song song) => null;

  int get downloadedCount => _index.length;

  /// Counts the scores too — this figure is what the Downloads page
  /// reports as space used, and it has to match what is actually on
  /// disk or the page is lying about the user's storage.
  int get totalBytes => _index.values
      .fold<int>(0, (sum, r) => sum + r.bytes + r.scoreBytes);

  int get pendingCount => _queue.length + _active.length;

  bool get isBusy => pendingCount > 0;

  /// Overall progress across the current batch, 0.0–1.0.
  double get batchProgress {
    if (_batchTotal == 0) return 0;
    return (_batchDone / _batchTotal).clamp(0.0, 1.0);
  }

  int get batchTotal => _batchTotal;
  int get batchDone => _batchDone;

  /// How many of [batchDone] failed, and why the last one did.
  ///
  /// Without these the UI could only show "N / M", which is the same
  /// display whether songs are downloading slowly or every single one
  /// is failing — the user's report was "我其实看不到下载进程都不知道到底
  /// 有没有真的下载", and they were right that the screen could not
  /// tell them.
  int get batchFailed => _batchFailed;
  String? get lastError => _lastError;

  int _batchTotal = 0;
  int _batchDone = 0;
  int _batchFailed = 0;
  String? _lastError;

  /// How long to wait for a server to start answering.
  static const _headersTimeout = Duration(seconds: 15);

  /// What [songs] would cost to download, in bytes.
  ///
  /// The catalogue does not publish file sizes, so this is an estimate
  /// from duration at a typical 128 kbps, falling back to a flat 4 MB
  /// where the source publishes no duration either. Deliberately shown
  /// as approximate in the UI — quoting a precise figure we cannot
  /// know would be worse than admitting the range.
  static int estimateBytes(Iterable<Song> songs) {
    var total = 0;
    for (final s in songs) {
      if (!s.hasPlayableAudio) continue;
      final secs = s.durationSec;
      total += secs != null && secs > 0
          ? (secs * 128 * 1000 / 8).round()
          : 4 * 1024 * 1024;
      // Sheet music now comes down with the audio. A flat 400 KB: the
      // scores are 1-4 page engravings and the catalogue publishes no
      // sizes, so this is the same honest guess the audio figure is,
      // and leaving it out would under-quote 579 of 606 songs.
      if (s.scoreUrl != null) total += 400 * 1024;
    }
    return total;
  }

  /// Shared with the web stub so the estimate shown before a download
  /// and the total shown after it read identically.
  static String formatBytes(int bytes) => formatDownloadBytes(bytes);

  // ── Commands ────────────────────────────────────────────────────

  /// Queue [songs] for download. Already-downloaded and audio-less
  /// entries are skipped, so "download all" is idempotent and a
  /// re-run after a partial failure only retries what is missing.
  Future<void> enqueue(Iterable<Song> songs) async {
    if (!isSupported) return;
    await init();
    _cancelled = false;

    final toAdd = songs
        .where((s) => s.hasPlayableAudio)
        .where((s) => !_index.containsKey(s.id))
        .where((s) => !_active.contains(s.id))
        .where((s) => !_queue.any((q) => q.id == s.id))
        .toList();
    if (toAdd.isEmpty) return;

    for (final s in toAdd) {
      _status[s.id] = const SongDownloadStatus(
          state: SongDownloadState.queued);
    }
    _queue.addAll(toAdd);
    _batchTotal += toAdd.length;
    notifyListeners();
    _pump();
  }

  /// Stop the batch. In-flight downloads are aborted and their partial
  /// files removed; completed ones stay.
  Future<void> cancelAll() async {
    _cancelled = true;
    _queue.clear();
    for (final client in _clients.values) {
      client.close();
    }
    _clients.clear();
    for (final id in _active.toList()) {
      _status[id] = const SongDownloadStatus();
    }
    _active.clear();
    _batchTotal = 0;
    _batchDone = 0;
    _batchFailed = 0;
    _lastError = null;
    notifyListeners();
  }

  Future<void> delete(Song song) async {
    final rec = _index.remove(song.id);
    if (rec != null) {
      try {
        final dir = await _mediaDir();
        for (final name in [rec.filename, rec.scoreFilename]) {
          if (name == null) continue;
          final f = File('${dir.path}/$name');
          if (f.existsSync()) f.deleteSync();
        }
      } catch (e) {
        debugPrint('[SongDownloadService] delete failed: $e');
      }
      await _persist();
    }
    _status[song.id] = const SongDownloadStatus();
    notifyListeners();
  }

  /// Remove every downloaded file.
  Future<void> deleteAll() async {
    await cancelAll();
    try {
      final dir = await _mediaDir();
      if (dir.existsSync()) dir.deleteSync(recursive: true);
      _dir = null;
      await _mediaDir();
    } catch (e) {
      debugPrint('[SongDownloadService] deleteAll failed: $e');
    }
    _index.clear();
    _status.clear();
    await _persist();
    notifyListeners();
  }

  // ── Worker ──────────────────────────────────────────────────────

  void _pump() {
    while (_active.length < _maxConcurrent && _queue.isNotEmpty) {
      final song = _queue.removeAt(0);
      _active.add(song.id);
      // ignore: unawaited_futures
      _download(song).whenComplete(() {
        _active.remove(song.id);
        _batchDone++;
        if (_queue.isEmpty && _active.isEmpty) {
          _batchTotal = 0;
          _batchDone = 0;
          // _batchFailed and _lastError deliberately survive the reset:
          // a batch that failed entirely finishes by clearing its
          // counters, and wiping the reason at the same moment would
          // leave the screen looking exactly like a batch that never
          // ran.
        }
        notifyListeners();
        if (!_cancelled) _pump();
      });
    }
  }

  Future<void> _download(Song song) async {
    final url = song.audioUrl ??
        (song.audioTracks.isNotEmpty ? song.audioTracks.first.url : null);
    if (url == null) return;

    _status[song.id] = const SongDownloadStatus(
        state: SongDownloadState.downloading, progress: 0);
    notifyListeners();

    final client = http.Client();
    _clients[song.id] = client;
    File? partial;
    try {
      final dir = await _mediaDir();
      final name = _filenameFor(song.id, url);
      partial = File('${dir.path}/$name.part');
      final target = File('${dir.path}/$name');

      final request = http.Request('GET', Uri.parse(url));
      // A host that never answers must fail in seconds, not minutes.
      //
      // 2026-08-11: the user queued 495 songs and the progress sat at
      // "0 / 495" indefinitely. Nothing was broken in the queue — 495
      // of the 559 songs live on fydt.org and
      // www.christiandiscipleschurch.org, which accept no TCP
      // connection at all from their network, and `send` had no
      // timeout. Each song therefore held a worker for the OS default
      // (~75s on iOS) before failing, so with a handful of workers the
      // batch could not visibly advance. The 63 that DID download were
      // all cgdc.hk, the one reachable host.
      //
      // This bounds the wait for the response HEADERS only; a slow but
      // live download keeps streaming below without a deadline, so a
      // large file on a poor connection is not cut off.
      final response = await client
          .send(request)
          .timeout(_headersTimeout, onTimeout: () {
        throw TimeoutException(
            'no response from ${Uri.parse(url).host}', _headersTimeout);
      });
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}');
      }

      final expected = response.contentLength ?? 0;
      var received = 0;
      final sink = partial.openWrite();
      try {
        await for (final chunk in response.stream) {
          if (_cancelled) throw const _Cancelled();
          sink.add(chunk);
          received += chunk.length;
          if (expected > 0) {
            _status[song.id] = SongDownloadStatus(
              state: SongDownloadState.downloading,
              progress: received / expected,
              bytes: received,
            );
            notifyListeners();
          }
        }
      } finally {
        await sink.close();
      }

      // Rename only after the stream completes, so a killed process
      // can never leave a truncated file looking like a finished one.
      await partial.rename(target.path);
      _index[song.id] = _DownloadRecord(filename: name, bytes: received);
      _status[song.id] = SongDownloadStatus(
          state: SongDownloadState.done, bytes: received);
      await _persist();

      // The score rides along AFTER the audio is safely committed, and
      // its failure is not the song's failure: 579 of 606 songs publish
      // a PDF, and an offline song without its music is the thing being
      // fixed here — but a 404 on the PDF must not turn a perfectly
      // downloaded song red in the Downloads list, nor put it in the
      // "Retry" batch. Errors are swallowed inside [_downloadScore].
      await _downloadScore(song);
    } on _Cancelled {
      _status[song.id] = const SongDownloadStatus();
    } catch (e) {
      _status[song.id] = SongDownloadStatus(
        state: SongDownloadState.failed,
        error: e.toString(),
      );
      _batchFailed++;
      _lastError = e is TimeoutException
          ? 'unreachable: ${Uri.tryParse(url)?.host ?? url}'
          : e.toString();
      debugPrint('[SongDownloadService] ${song.id} failed: $e');
    } finally {
      _clients.remove(song.id)?.close();
      try {
        if (partial != null && partial.existsSync()) partial.deleteSync();
      } catch (_) {}
      notifyListeners();
    }
  }

  /// Fetch [song]'s sheet music next to its audio. Best-effort by
  /// design — see the call site. Never throws.
  ///
  /// Not streamed: scores are a few hundred KB against several MB of
  /// audio, so there is no progress worth reporting and a plain `get`
  /// keeps the failure surface small. It is also not cancellable, for
  /// the same reason — by the time it runs the expensive part is done.
  Future<void> _downloadScore(Song song) async {
    final url = song.scoreUrl;
    final rec = _index[song.id];
    if (url == null || rec == null || rec.scoreFilename != null) return;
    try {
      final resp = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 30));
      if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) return;
      // The churches' sites answer a missing file with an HTML page and
      // a 200, so a "successful" fetch can be the site's 404 page. A
      // PDF starts with %PDF-; anything else is not sheet music and
      // storing it would show the user a broken viewer later.
      final b = resp.bodyBytes;
      if (b.length < 5 ||
          b[0] != 0x25 || b[1] != 0x50 || b[2] != 0x44 || b[3] != 0x46) {
        debugPrint('[SongDownloadService] ${song.id} score is not a PDF — '
            'the site probably served an error page with HTTP 200');
        return;
      }
      final dir = await _mediaDir();
      final name = '${sha1.convert(utf8.encode(song.id))}.pdf';
      final tmp = File('${dir.path}/$name.part');
      await tmp.writeAsBytes(b, flush: true);
      await tmp.rename('${dir.path}/$name');
      _index[song.id] = rec.withScore(name, b.length);
      await _persist();
      notifyListeners();
    } catch (e) {
      debugPrint('[SongDownloadService] ${song.id} score failed: $e');
    }
  }

  /// Stable filename: the song id is not filesystem-safe (it contains
  /// `:` and, for Cahaya, arbitrary title text), so hash it and keep
  /// the source extension.
  static String _filenameFor(String songId, String url) {
    final digest = sha1.convert(utf8.encode(songId)).toString();
    final ext = url.toLowerCase().endsWith('.m4a') ? 'm4a' : 'mp3';
    return '$digest.$ext';
  }
}

class _DownloadRecord {
  final String filename;
  final int bytes;

  /// The sheet-music PDF stored alongside the audio, when the song has
  /// one and it downloaded. Null covers three different cases that all
  /// behave the same way — the song publishes no score, the score
  /// failed, or the record predates scores being downloaded at all.
  final String? scoreFilename;
  final int scoreBytes;

  const _DownloadRecord({
    required this.filename,
    required this.bytes,
    this.scoreFilename,
    this.scoreBytes = 0,
  });

  /// Short keys because this is re-encoded into SharedPreferences on
  /// every completed download. The two score keys are omitted when
  /// absent so existing records keep their current size, and
  /// [fromJson] tolerates their absence — an index written by an older
  /// build must keep loading, or an upgrade silently forgets every
  /// download the user has.
  Map<String, dynamic> toJson() => {
        'f': filename,
        'b': bytes,
        if (scoreFilename != null) 's': scoreFilename,
        if (scoreBytes > 0) 'sb': scoreBytes,
      };

  factory _DownloadRecord.fromJson(Map<String, dynamic> j) =>
      _DownloadRecord(
        filename: j['f'] as String,
        bytes: (j['b'] as num?)?.toInt() ?? 0,
        scoreFilename: j['s'] as String?,
        scoreBytes: (j['sb'] as num?)?.toInt() ?? 0,
      );

  _DownloadRecord withScore(String name, int size) => _DownloadRecord(
        filename: filename,
        bytes: bytes,
        scoreFilename: name,
        scoreBytes: size,
      );
}

class _Cancelled implements Exception {
  const _Cancelled();
}

/// Resolve what the player should actually open for [song].
///
/// A downloaded file wins over the network every time — that is the
/// whole point of downloading it, and it also means a user on a train
/// keeps listening when the connection drops mid-song.
String? resolveSongSource(Song song, String url) {
  if (SongDownloadService.isSupported) {
    final local = SongDownloadService.instance.localPathFor(song);
    // Only the primary audio is downloaded, so an alternate mix still
    // streams even when the song shows as downloaded.
    if (local != null && url == song.audioUrl) return local;
  }
  return SongPlayerService.resolvePlaybackUrl(url);
}
