// Getting the finished PNG out of the app, which is a different
// problem on the web than it is on a desktop and is not solved at all
// on a phone.
//
// Same conditional-import shape as `share_service.dart`, for the same
// reason: the web branch needs `dart:js_interop` and `package:web`,
// which do not exist on a native target, and the native branch needs
// `dart:io` through `path_provider`, which does not exist on the web.
//
// The honest part is [VerseCardDelivery.unavailable]. This app has no
// share-sheet plugin on native — `share_service_stub.dart` returns
// false on every non-web target — and no photo-library plugin. On iOS
// and Android that leaves nowhere a saved file could go that the
// reader could reach: the app's Documents directory is not exposed to
// the Files app (`UIFileSharingEnabled` is not set in
// `ios/Runner/Info.plist`, checked 2026-09-08). Writing the PNG there
// anyway and reporting success would be a button that does nothing,
// which is the specific failure this split exists to avoid. So those
// two platforms are told, in the sheet, that the card has to be
// screenshotted — and the card is already on screen, at full size,
// when they are told it.

import 'dart:typed_data';

import 'package:yswords/services/verse_card_export_types.dart';

import 'verse_card_export_stub.dart'
    if (dart.library.js_interop) 'verse_card_export_web.dart' as impl;

export 'package:yswords/services/verse_card_export_types.dart';

abstract class VerseCardExport {
  /// Whether the platform can hand the image to a share sheet, as
  /// opposed to only saving or downloading it. Drives the button's
  /// label — "Share" vs "Save" — so it never promises a sheet that
  /// will not appear.
  static bool get canShare => impl.canShareImage();

  /// Whether the platform can deliver the file at all, by any route.
  /// False only on iOS and Android, where the sheet swaps the button
  /// for the screenshot hint instead of offering an action that cannot
  /// happen.
  static bool get canDeliver => impl.canDeliverImage();

  /// Where [deliver] last wrote a file, for the "Saved to …" message.
  /// Null on every other outcome.
  static String? get lastSavedPath => impl.lastSavedPath;

  /// Deliver [png] to the reader by the best route this platform has.
  ///
  /// [shareText] rides along on the share-sheet route only — several
  /// targets (Mail, Messages) show it beside the image, and the ones
  /// that do not simply ignore it. It is never written to disk.
  static Future<VerseCardDelivery> deliver({
    required Uint8List png,
    required String fileName,
    required String shareText,
  }) =>
      impl.deliverImage(
        png: png,
        fileName: fileName,
        shareText: shareText,
      );
}
