import 'package:flutter/foundation.dart';

import 'package:yswords/models/song.dart';
import 'package:yswords/services/song_download_types.dart';
import 'package:yswords/services/song_player_service.dart';

/// Web build of the download service.
///
/// A browser gives no managed file system, and the catalogue's audio
/// is ~2.5 GB — far past what a tab may keep. So there is nothing
/// here to manage and every command is a no-op; [isSupported] is
/// false and the UI hides the download affordances rather than
/// offering a button that quietly does nothing.
///
/// Web offline listening is handled instead by `web/song_media_sw.js`,
/// a Service Worker that caches media the user has actually played.
/// That is a genuinely weaker guarantee than a downloaded file — the
/// browser may evict it at any time and the quota is not ours to set —
/// so it is surfaced as its own thing rather than dressed up as
/// "downloaded".
class SongDownloadService extends ChangeNotifier {
  SongDownloadService._();

  static final SongDownloadService instance = SongDownloadService._();

  static bool get isSupported => false;

  Future<void> init() async {}

  SongDownloadStatus statusOf(Song song) => const SongDownloadStatus();

  bool isDownloaded(Song song) => false;

  String? localPathFor(Song song) => null;

  int get downloadedCount => 0;
  int get totalBytes => 0;
  int get pendingCount => 0;
  bool get isBusy => false;
  double get batchProgress => 0;
  int get batchTotal => 0;
  int get batchDone => 0;

  static int estimateBytes(Iterable<Song> songs) => 0;

  static String formatBytes(int bytes) => formatDownloadBytes(bytes);

  Future<void> enqueue(Iterable<Song> songs) async {}
  Future<void> cancelAll() async {}
  Future<void> delete(Song song) async {}
  Future<void> deleteAll() async {}
}

/// On web there is never a local file, so playback always resolves to
/// the same-origin proxy path. The Service Worker, if it has the media
/// cached, serves that request from cache transparently — the app does
/// not need to know which happened.
String? resolveSongSource(Song song, String url) =>
    SongPlayerService.resolvePlaybackUrl(url);
