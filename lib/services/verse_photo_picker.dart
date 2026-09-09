// Getting one photograph out of the reader's own camera roll and into
// a verse card.
//
// The whole service is bytes in, bytes out, and that shape is the
// point. `image_picker` hands back an `XFile` whose `path` means four
// different things on four platforms — a blob URL on the web, a cache
// path on Android, a temporary copy on iOS — and only one of those can
// be turned into an `ImageProvider` that the card's export path can
// rasterise. `readAsBytes` is the same everywhere, `MemoryImage` takes
// it everywhere, and nothing here ever touches the filesystem.
//
// Nothing is stored. The bytes live in the sheet's State and go when
// the sheet does. That is a deliberate limit rather than an oversight:
// remembering the last photograph would mean keeping a copy of a
// picture out of somebody's camera roll inside the app's own storage,
// which is a promise this app has not made to anyone. Picking again is
// two taps.

import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';

import 'package:yswords/services/verse_photo_temp_stub.dart'
    if (dart.library.io) 'package:yswords/services/verse_photo_temp_io.dart';

/// Longest edge the picked photograph is downscaled to before it is
/// decoded, in pixels.
///
/// The card exports at 1080 px wide (360 dp × the export's pixel ratio
/// of 3), so 1920 is already more detail than any share can use. It is
/// not a quality setting, it is a memory one: a modern phone camera
/// produces 4000×3000, and holding that decoded — 48 MB as raw RGBA —
/// behind a bottom sheet is how a picker crashes a mid-range Android.
const double kVersePhotoMaxEdge = 1920;

/// Whether this build can offer the reader a photograph at all.
///
/// True everywhere `image_picker` has an implementation, which is
/// every platform this app ships to. It exists as a named constant
/// anyway so the sheet asks a question about capability rather than
/// about the operating system — the same shape `VerseCardExport`
/// already uses, and the reason the export button never promises a
/// share sheet that will not appear.
bool get canPickVersePhoto => true;

/// Ask the reader for one photograph.
///
/// Returns its bytes, or null when they backed out — which is the
/// common case and not an error, so it is not reported as one. Also
/// returns null if the platform channel throws, because the two
/// outcomes are indistinguishable to the reader and both mean "no
/// picture": on Android a denied media permission and a tapped Back
/// arrive as different exceptions and produce the same empty hands.
Future<Uint8List?> pickVersePhoto() async {
  try {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: kVersePhotoMaxEdge,
      maxHeight: kVersePhotoMaxEdge,
      // Re-encoding is skipped on the web (`image_quality` is not
      // supported there and the plugin warns if it is set), so this
      // is passed only where it does something.
      imageQuality: kIsWeb ? null : 88,
    );
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    // The plugin handed us a COPY it made in the app's own cache, not
    // the reader's original. Now that the bytes are in memory, that
    // copy is a photograph of theirs sitting in our storage — which is
    // exactly what this file's header and the permission prompt both
    // say does not happen. Discarded here, once, where the pick ends.
    // An XFile can be backed by bytes rather than by a file — the web
    // always is, and `XFile.fromData` (which is what a fake picker in a
    // test returns) is too. Both report an empty path, and there is
    // nothing on disk to discard.
    if (picked.path.isNotEmpty) await discardPickedFile(picked.path);
    return bytes;
  } catch (_) {
    return null;
  }
}
