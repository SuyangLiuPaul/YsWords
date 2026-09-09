import 'dart:io';

/// Native half of "discard the picker's copy" — see
/// `verse_photo_picker.dart`.
///
/// `image_picker` does not hand back the reader's original file. It
/// COPIES the chosen photograph into the app's own cache or temporary
/// directory and returns that path, and the copy outlives the pick:
/// nothing in the plugin or in this app ever removed it. So a picture
/// out of somebody's camera roll sat inside the app's storage
/// indefinitely, which both `verse_photo_picker.dart`'s own header
/// ("nothing here ever touches the filesystem", "Nothing is stored")
/// and the App Store string readers are shown at the permission prompt
/// ("The photo is used only on that card and is not stored or
/// uploaded") say does not happen.
///
/// Failure is swallowed on purpose. The bytes are already in hand by
/// the time this runs, so the pick has succeeded; a delete that fails
/// — a path the sandbox will not let us unlink, a file the OS already
/// swept — must not turn a working feature into an error the reader
/// sees. It is a tidy-up, not a step.
Future<void> discardPickedFile(String path) async {
  try {
    final f = File(path);
    if (await f.exists()) await f.delete();
  } catch (_) {
    // Deliberately ignored — see above.
  }
}
