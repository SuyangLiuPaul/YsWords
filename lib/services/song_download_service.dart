/// Offline downloads for the Songs directory.
///
/// Façade over two implementations, picked at compile time the same
/// way `LinkOpener` and `ShareService` do it:
///
///   • `song_download_io.dart`  — iOS / Android / macOS / Windows /
///     Linux. Real files under the app-support directory, with a
///     queue, per-song progress, cancel, delete and space accounting.
///   • `song_download_web.dart` — the browser, on every desktop and
///     mobile OS alike. Cache Storage holds whole response bodies on
///     disk, and playback reads them back through a blob URL. Same
///     queue, progress, cancel, delete and space accounting as native;
///     `isSupported` is true wherever `caches` exists, which is every
///     secure context. (Until 2026-08-10 this really was a no-op and
///     the comment was right. A Service Worker, `web/song_media_sw.js`,
///     was the plan then; it never worked and is gone — see HANDOFF.md.)
///
/// The split is a conditional import rather than a runtime `if (kIsWeb)`
/// because the native path imports `dart:io`, which does not compile
/// for web at all — a runtime check would still break the build.
///
/// Callers import THIS file plus `song_download_types.dart`, never a
/// platform file directly, and gate any download UI on [isSupported].
library;

export 'song_download_web.dart'
    if (dart.library.io) 'song_download_io.dart';
