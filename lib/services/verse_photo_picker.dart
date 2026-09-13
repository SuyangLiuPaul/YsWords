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

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
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
    var bytes = await picked.readAsBytes();
    // 2026-09-13: `maxWidth` / `maxHeight` above are honoured on iOS,
    // Android and the web, and silently ignored on macOS, Windows and
    // Linux, where image_picker is file_selector in a coat. So on the
    // desktops a 50-megapixel photograph came back at 50 megapixels —
    // the memory case kVersePhotoMaxEdge exists to prevent — and the
    // downscale is done here instead, by the engine.
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux)) {
      bytes = await downscaleVersePhoto(bytes);
    }
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

/// Re-encode [bytes] so the longer edge is at most [kVersePhotoMaxEdge].
///
/// Returns the input untouched when it is already small enough, or when
/// it cannot be decoded at all — the caller's own decode is what decides
/// whether a file is usable, and this must not pre-empt that with a
/// different answer. PNG out rather than JPEG because the engine has no
/// JPEG encoder; at 1920 px the size is fine for a card that is shared,
/// not stored.
Future<Uint8List> downscaleVersePhoto(Uint8List bytes) async {
  ui.Codec probe;
  try {
    probe = await ui.instantiateImageCodec(bytes);
  } catch (_) {
    return bytes;
  }
  final first = await probe.getNextFrame();
  final w = first.image.width;
  final h = first.image.height;
  first.image.dispose();
  probe.dispose();
  final longest = w > h ? w : h;
  if (longest <= kVersePhotoMaxEdge) return bytes;
  final scale = kVersePhotoMaxEdge / longest;
  final codec = await ui.instantiateImageCodec(
    bytes,
    targetWidth: (w * scale).round(),
    targetHeight: (h * scale).round(),
  );
  final frame = await codec.getNextFrame();
  try {
    final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    return png == null ? bytes : png.buffer.asUint8List();
  } finally {
    frame.image.dispose();
    codec.dispose();
  }
}

/// The photograph's mean relative luminance, 0 (black) to 1 (white),
/// from a 32-pixel-wide decode — a few hundred pixels are plenty for a
/// mean, and the full image is never held for this.
///
/// Feeds the photo card's scrim: a fixed veil that reads over a dark
/// photograph is 2.2:1 over a bright one, which is below what anyone
/// can read at a glance. See `VerseCardPalette.of`. Null when the bytes
/// do not decode, in which case the card keeps its fixed veil.
Future<double?> versePhotoLuminance(Uint8List bytes) async {
  ui.Codec codec;
  try {
    codec = await ui.instantiateImageCodec(bytes, targetWidth: 32);
  } catch (_) {
    return null;
  }
  final frame = await codec.getNextFrame();
  try {
    final data =
        await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;
    final px = data.buffer.asUint8List();
    if (px.length < 4) return null;
    double lin(int c) {
      final v = c / 255.0;
      return v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    }
    var sum = 0.0;
    final n = px.length ~/ 4;
    for (var i = 0; i < px.length; i += 4) {
      sum += 0.2126 * lin(px[i]) + 0.7152 * lin(px[i + 1]) + 0.0722 * lin(px[i + 2]);
    }
    return sum / n;
  } finally {
    frame.image.dispose();
    codec.dispose();
  }
}
