// The result type shared by `verse_card_export.dart` and its two
// platform implementations.
//
// It lives in its own file for the same reason `song_download_types.dart`
// does: the façade conditionally imports the implementations, so an
// implementation that imported the façade back to reach this enum
// would close an import cycle for no gain.

/// What actually happened to the PNG. The sheet renders a different
/// message for each, so none of them may be collapsed into a bare
/// bool.
enum VerseCardDelivery {
  /// Handed to the platform share sheet (web only today, via
  /// `navigator.share` with a file).
  shared,

  /// The share sheet opened and the reader dismissed it. Not a
  /// failure, and must not be reported as one — nor silently retried
  /// as a download, which would drop a file into Downloads that
  /// nobody asked for.
  cancelled,

  /// Downloaded through the browser.
  downloaded,

  /// Opened in a new tab instead of being written to Downloads.
  ///
  /// iOS Safari's answer to `<a download>` on a blob URL: it shows the
  /// PNG rather than saving it, and the reader saves it from there with
  /// a long press. Telling them "Image downloaded" on that platform is
  /// a lie they will act on — they would go looking in Files for
  /// something that is not there — so it is its own outcome with its
  /// own wording.
  openedInTab,

  /// Written to a real path on disk. `VerseCardExport.lastSavedPath`
  /// holds it.
  savedToFile,

  /// 2026-09-15. Put into the device's own photo library.
  ///
  /// Its own outcome rather than [savedToFile], because there is no
  /// path to tell the reader and telling them one would send them
  /// looking in the wrong place. "Saved to your photos" is a different
  /// sentence from "Saved to /Users/…/Downloads", and the reader acts
  /// on which one they are given.
  savedToPhotos,

  /// 2026-09-15. The photo library refused — on iOS, permission not
  /// granted. Its own outcome because the remedy is the reader's and
  /// is specific: it is in Settings, not in this app, and "it broke"
  /// would send them nowhere.
  photosDenied,

  /// This platform has no way to deliver the file. The reader is told
  /// to screenshot the card instead.
  unavailable,

  /// It was attempted and it broke.
  failed,
}
