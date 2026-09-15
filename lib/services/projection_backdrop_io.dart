/// The operator's own picture for the wall, kept where it will still be
/// there next Sunday.
///
/// 2026-09-15. 「projector可以选择image background吗在setting设置」.
///
/// WHY THIS IS NOT JUST A PATH IN PREFS. `image_picker` hands back a
/// file in a TEMPORARY directory — on Android a cache the system is
/// free to empty whenever it wants space, on iOS a container that does
/// not survive reinstalls and is not promised to survive much else.
/// Storing that path would give an operator a background that works all
/// week and is gone on Sunday morning, with no way to tell why. So the
/// BYTES are written into the app's own support directory, and it is
/// that copy whose path is remembered.
///
/// Bytes rather than a file copy because `verse_photo_picker.dart`
/// already established that shape for this app, and its reasoning holds
/// here: an `XFile.path` means four different things on four platforms
/// and only some of them can be copied, while `readAsBytes` is the same
/// everywhere. Reusing that picker also reuses its downscale, which is
/// what keeps a 4000×3000 phone photograph from being held decoded.
///
/// One file, one name, overwritten each time. A history of the
/// operator's rejected backgrounds is not something anyone asked for
/// and it would grow without limit on a device nobody prunes.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart' show ImageProvider, FileImage;
import 'package:path_provider/path_provider.dart';

/// The single file the chosen backdrop lives in.
const String kProjectionBackdropFileName = 'projection-backdrop.img';

/// Whether this build can keep a backdrop at all.
///
/// True here and false in the web half of this pair. On the web there
/// is no durable file to copy into and a picked image is a blob URL
/// that does not survive a reload, so the Settings card hides the
/// control rather than offering one that forgets — see
/// `projectionBackdropUnavailable` in the strings.
bool get projectionBackdropSupported => true;

/// Where the backdrop is kept, whether or not one has been chosen.
Future<File> projectionBackdropFile() async {
  final dir = await getApplicationSupportDirectory();
  return File('${dir.path}${Platform.pathSeparator}'
      '$kProjectionBackdropFileName');
}

/// Write [bytes] in as the backdrop, replacing any previous one.
///
/// Returns the stored path, or null if the write failed — a picker that
/// cannot save must not leave a setting pointing at nothing.
Future<String?> storeProjectionBackdrop(Uint8List bytes) async {
  try {
    final target = await projectionBackdropFile();
    await target.writeAsBytes(bytes, flush: true);
    // The path never changes, so a `FileImage` from the previous pick
    // would serve the old picture out of Flutter's image cache. Evict
    // it here, at the one place that knows the file changed.
    FileImage(target).evict();
    return target.path;
  } catch (_) {
    return null;
  }
}

/// Forget the backdrop, and delete the copy.
///
/// The delete is best-effort: a stored path that no longer resolves is
/// already handled everywhere it is read (the ground falls back to its
/// base), so a file left behind is untidy rather than broken.
Future<void> clearProjectionBackdrop() async {
  try {
    final target = await projectionBackdropFile();
    if (target.existsSync()) await target.delete();
  } catch (_) {
    // Nothing to report: the setting is cleared either way.
  }
}

/// The stored backdrop as something the stage can paint, or null.
///
/// Null for an empty setting AND for a path that no longer resolves.
/// The second case is not an error: a file the system reclaimed leaves
/// the photo ground painting its base, which is the default wall, so
/// the operator loses their picture rather than their service.
ImageProvider? projectionBackdropImage(String path) {
  if (path.isEmpty) return null;
  final file = File(path);
  if (!file.existsSync()) return null;
  return FileImage(file);
}
