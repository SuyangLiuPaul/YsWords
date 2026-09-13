// Saving a song's audio or score as a FILE the reader can find.
//
// Not the same thing as the offline download (`song_download_service.dart`),
// which keeps media in the app's own store for the app's own playback.
// This is 「下载」 in the sense a person means it: an mp3 or a PDF that
// shows up in Downloads, in the Files app, on the desktop — somewhere
// they can open with something else, send on, or keep. It was never
// built on any platform; the doc comments that said the web could not
// download were about the other thing.
//
// One façade, one per-platform half:
//   • web   — fetch to a blob and click an <a download>. The browser
//             does the rest, in its own Downloads.
//   • io    — fetch to the temp dir, then put it where the platform's
//             readers look: Android's public Downloads through MediaStore
//             (a native channel; below API 29 the app's folder); the
//             Documents folder on iOS, which Info.plist exposes to the
//             Files app; the Downloads folder on the desktops.
//
// Callers hand over a URL that is already the one the player would
// fetch (proxied on the web), a file name, and a MIME type. The outcome
// says where the file went, in words the toast can show.

import 'song_file_saver_stub.dart'
    if (dart.library.js_interop) 'song_file_saver_web.dart'
    if (dart.library.io) 'song_file_saver_io.dart';

/// Where a saved file went, or why it did not.
sealed class SaveOutcome {
  const SaveOutcome();
}

/// Saved; [location] is what to tell the reader — `Download/x.mp3`,
/// `Files › 雅伟之言`, `~/Downloads/x.mp3`, or `browser` on the web where
/// the browser owns the rest.
class SaveSaved extends SaveOutcome {
  const SaveSaved(this.location);
  final String location;
}

/// The fetch or the write failed; [reason] is for the log, not the toast.
class SaveFailed extends SaveOutcome {
  const SaveFailed(this.reason);
  final String reason;
}

class SongFileSaver {
  SongFileSaver._();

  /// Whether this build can put a file somewhere the reader can find it.
  static bool get isSupported => songFileSaverSupported;

  static Future<SaveOutcome> save({
    required String url,
    required String fileName,
    required String mime,
  }) =>
      songFileSaverSave(url: url, fileName: fileName, mime: mime);
}

/// A file name the platforms will all accept: the song's title with the
/// characters that break a path or a download header replaced, trimmed,
/// and bounded. Chinese titles pass through untouched — every target
/// here handles them — and an empty result falls back to [fallback].
String safeFileName(String title, {required String extension,
    String fallback = 'song'}) {
  var base = title
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (base.length > 80) base = base.substring(0, 80).trim();
  if (base.isEmpty) base = fallback;
  return '$base.$extension';
}
