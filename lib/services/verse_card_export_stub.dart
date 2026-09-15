// Native delivery: put the PNG where the reader asked for it.
//
// 2026-09-15, and this file used to say the opposite. It read:
//
//     **There is no share sheet here.** … adding a plugin to do it is
//     a dependency decision that is not this change's to make.
//
// The decision has now been made — 「两个都加」 — and both plugins are
// in: `gal` for the photo library and `share_plus` for the OS share
// sheet. What that comment got right, and what still holds, is WHY the
// mobile targets had nothing: `getDownloadsDirectory()` is documented
// as returning null on iOS and Android, because those platforms have no
// such directory an app may write to. That was the whole native story
// and it left a phone with no route at all — the sheet swapped the Save
// button for "take a screenshot".
//
// TWO ROUTES, NOT ONE, because saving and sharing are two different
// wants. The desktop and web paths have offered them as two buttons
// since they existed; the phone now does too:
//
//   * **save** — `Gal.putImageBytes` on iOS and Android, straight into
//     the photo library where a reader looks for a picture. On desktop
//     it stays `getDownloadsDirectory()`, which is where a reader looks
//     for a file.
//   * **share** — `SharePlus` everywhere native. It needs a real file,
//     so the PNG goes to a temporary path first; that path is the share
//     sheet's to read and nobody else's, and the OS reclaims it.
//
// The rejected alternative for saving remains rejected, for its
// original reason: `getApplicationDocumentsDirectory()` is non-null
// everywhere and would have made this file look complete, but on iOS
// that path is inside the sandbox and is not surfaced in the Files app
// unless `UIFileSharingEnabled` is set, which this app does not set.
// "Saved!" pointing at a directory the reader cannot open is worse than
// "not supported yet" — and is now moot, because the photo library is
// a place they can actually open.

import 'dart:io';
import 'dart:typed_data';

import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:yswords/services/verse_card_export_types.dart';

/// Whether the image can be handed to a share sheet.
///
/// True on every native target: `share_plus` implements all five.
bool canShareImage() => true;

/// Whether this platform has ANY route for the file — asked before the
/// button is drawn, not after it is pressed.
///
/// True everywhere now. Kept rather than deleted because the sheet asks
/// a question about CAPABILITY, and a capability that is currently
/// universal is still the right question: a future platform without a
/// photo library or a share sheet answers it honestly.
bool canDeliverImage() => true;

/// True where "save" means the photo library rather than a file path.
///
/// Not `Platform.isIOS || Platform.isAndroid` spelled at the call site,
/// because the distinction the sheet cares about is *is there a path to
/// tell the reader*, and that is what this names.
bool get savesToPhotoLibrary => Platform.isIOS || Platform.isAndroid;

String? _lastSavedPath;

String? get lastSavedPath => _lastSavedPath;

/// Keep a copy, without going through anyone's share sheet.
Future<VerseCardDelivery> saveImage({
  required Uint8List png,
  required String fileName,
}) async {
  _lastSavedPath = null;
  if (savesToPhotoLibrary) {
    try {
      // `name` without the extension: gal appends its own, and a file
      // called `verse.png.png` in someone's camera roll is a bug they
      // can see.
      await Gal.putImageBytes(png, name: _stem(fileName));
      return VerseCardDelivery.savedToPhotos;
    } on GalException catch (e) {
      // Permission is the reader's to grant and the remedy is in the
      // OS, not here, so it is not reported as a breakage.
      return e.type == GalExceptionType.accessDenied
          ? VerseCardDelivery.photosDenied
          : VerseCardDelivery.failed;
    } catch (_) {
      // Includes the MissingPluginException a widget test raises.
      return VerseCardDelivery.failed;
    }
  }
  try {
    final dir = await getDownloadsDirectory();
    if (dir == null) return VerseCardDelivery.unavailable;
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(png, flush: true);
    _lastSavedPath = file.path;
    return VerseCardDelivery.savedToFile;
  } catch (_) {
    return VerseCardDelivery.failed;
  }
}

/// Hand the image to the platform's share sheet.
Future<VerseCardDelivery> deliverImage({
  required Uint8List png,
  required String fileName,
  required String shareText,
}) async {
  _lastSavedPath = null;
  try {
    // A share sheet needs a file. The temporary directory is the right
    // home for it: the sheet reads it while it is open and the OS
    // reclaims it afterwards, which is exactly the lifetime wanted —
    // this copy is not the reader's keepsake, `saveImage` is.
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(png, flush: true);
    final result = await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png')],
      text: shareText.isEmpty ? null : shareText,
    );
    switch (result.status) {
      case ShareResultStatus.success:
        return VerseCardDelivery.shared;
      case ShareResultStatus.dismissed:
        // Backing out is the common case and is not a failure. It must
        // also not be silently retried as a save — that would put a
        // picture in someone's camera roll that they just declined to
        // share.
        return VerseCardDelivery.cancelled;
      case ShareResultStatus.unavailable:
        return VerseCardDelivery.unavailable;
    }
  } catch (_) {
    return VerseCardDelivery.failed;
  }
}

/// `verse-card-John-3-16.png` → `verse-card-John-3-16`.
String _stem(String fileName) {
  final dot = fileName.lastIndexOf('.');
  return dot <= 0 ? fileName : fileName.substring(0, dot);
}
