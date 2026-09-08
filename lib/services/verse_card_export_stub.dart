// Native delivery: write the PNG somewhere the reader can actually
// open it, or say plainly that this platform cannot.
//
// **There is no share sheet here.** `share_service_stub.dart` returns
// false for every non-web target, so nothing in this app can hand a
// file to iOS's or Android's share UI, and adding a plugin to do it is
// a dependency decision that is not this change's to make. What is
// available is `path_provider`, already a dependency since 2026-05-24.
//
// `getDownloadsDirectory()` is the whole native story, and it is
// honest about its own limits: path_provider implements it on macOS,
// Windows and Linux and documents it as returning null on iOS and
// Android, because those platforms have no such directory an app may
// write to. So the desktop targets get a real file at a real path they
// can be told, and the two mobile targets get
// [VerseCardDelivery.unavailable] — which the sheet renders as "take a
// screenshot", with the card sitting on screen at full size.
//
// The rejected alternative was `getApplicationDocumentsDirectory()`,
// which is non-null everywhere and would have made this file look
// complete. On iOS that path is inside the sandbox and is not surfaced
// in the Files app unless `UIFileSharingEnabled` is set in
// Info.plist, which this app does not set. "Saved!" pointing at a
// directory the reader cannot open is worse than "not supported yet".

import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'package:yswords/services/verse_card_export_types.dart';

/// No native target this app ships to can put an image into a share
/// sheet today. Stated as a constant rather than a platform switch so
/// that the day a share plugin is added, this is the one line that
/// has to change.
bool canShareImage() => false;

/// Whether this platform has ANY route for the file — asked before the
/// button is drawn, not after it is pressed.
///
/// iOS and Android have none, for the reasons in the header, and a
/// reader on those platforms is shown the screenshot hint in place of a
/// button rather than a "Save image" that turns out to mean "no". This
/// mirrors what `getDownloadsDirectory()` will return a moment later —
/// deliberately, because the answer has to be available synchronously
/// to `build` and that call is a Future.
bool canDeliverImage() => !(Platform.isIOS || Platform.isAndroid);

String? _lastSavedPath;

String? get lastSavedPath => _lastSavedPath;

Future<VerseCardDelivery> deliverImage({
  required Uint8List png,
  required String fileName,
  required String shareText,
}) async {
  _lastSavedPath = null;
  try {
    // Null on iOS and Android by path_provider's own contract, and
    // that null is the answer rather than a problem to work around.
    final dir = await getDownloadsDirectory();
    if (dir == null) return VerseCardDelivery.unavailable;
    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsBytes(png, flush: true);
    _lastSavedPath = file.path;
    return VerseCardDelivery.savedToFile;
  } catch (_) {
    // Includes the MissingPluginException a widget test raises for
    // path_provider. A share button must never throw into the zone
    // handler; the sheet shows a failure message instead.
    return VerseCardDelivery.failed;
  }
}
