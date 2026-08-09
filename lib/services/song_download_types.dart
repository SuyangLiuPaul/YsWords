/// Shared vocabulary for offline downloads.
///
/// Kept separate from the implementations so both the dart:io one and
/// the web stub can speak it — the UI imports only this plus the
/// conditional façade, and never a platform-specific file directly.
library;

/// What a song's audio is doing right now.
enum SongDownloadState { none, queued, downloading, done, failed }

/// A song's offline status, as the UI needs to render it.
class SongDownloadStatus {
  final SongDownloadState state;

  /// 0.0–1.0 while [SongDownloadState.downloading]; null when the
  /// server sends no Content-Length and progress is unknowable.
  final double? progress;

  /// Bytes on disk once [SongDownloadState.done].
  final int bytes;

  /// Why it failed, for the retry affordance.
  final String? error;

  const SongDownloadStatus({
    this.state = SongDownloadState.none,
    this.progress,
    this.bytes = 0,
    this.error,
  });

  bool get isDone => state == SongDownloadState.done;
  bool get isBusy =>
      state == SongDownloadState.queued ||
      state == SongDownloadState.downloading;
}

/// Human-readable size. Shared so the estimate shown before a download
/// and the total shown after it are formatted identically.
String formatDownloadBytes(int bytes) {
  if (bytes <= 0) return '0 MB';
  const mb = 1024 * 1024;
  if (bytes < mb) return '${(bytes / 1024).round()} KB';
  if (bytes < 1024 * mb) return '${(bytes / mb).round()} MB';
  return '${(bytes / (1024 * mb)).toStringAsFixed(1)} GB';
}
