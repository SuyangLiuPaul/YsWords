/// Web half of "discard the picker's copy" — see
/// `verse_photo_picker.dart`.
///
/// There is nothing to discard here. On the web `XFile.path` is a blob
/// URL, not a file: the bytes live in the browser's memory and go when
/// the page does, so no copy of the reader's photograph is left behind
/// for anyone to delete. Deliberately a no-op rather than an error, so
/// the caller does not need a `kIsWeb` branch.
Future<void> discardPickedFile(String path) async {}
