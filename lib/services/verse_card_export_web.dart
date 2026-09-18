// Web delivery: the share sheet where the browser has one for files,
// a download everywhere else.
//
// The two routes are not interchangeable and the split is not
// cosmetic. `navigator.share` with a `files` array is what puts a
// verse card into WhatsApp / WeChat / Messages in one tap, and it is
// the ONLY route that works on iOS Safari, where `<a download>` on a
// blob URL opens the image in a new tab instead of saving it. It is
// also absent on desktop Firefox and on Chrome for Linux, where the
// anchor download is the route that works. So both are implemented and
// the button's label is chosen from `canShareImage()` rather than
// assumed — a "Share" button that silently does nothing is the exact
// failure this file exists to avoid.
//
// `canShare` is feature-detected with a real (empty) PNG File rather
// than by looking for the method: browsers ship `navigator.canShare`
// while refusing `files` specifically, and the only way to learn that
// is to ask about a file.

import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'package:yahwehs_words/services/verse_card_export_types.dart';

/// Cached because this is read from `build` to label the button, and
/// the probe allocates a JS File. Browser capability does not change
/// within a page's lifetime.
bool? _canShareFiles;

bool canShareImage() {
  final cached = _canShareFiles;
  if (cached != null) return cached;
  var result = false;
  try {
    final nav = web.window.navigator as JSObject;
    if (nav.has('share') && nav.has('canShare')) {
      final probe = web.File(
        <JSAny>[].toJS,
        'verse.png',
        web.FilePropertyBag(type: 'image/png'),
      );
      result = web.window.navigator
          .canShare(web.ShareData(files: <web.File>[probe].toJS));
    }
  } catch (_) {
    result = false;
  }
  _canShareFiles = result;
  return result;
}

/// Every browser can be given a file one way or the other — the share
/// sheet where it exists, the anchor download where it does not.
bool canDeliverImage() => true;

/// The browser saves through its own download UI, so there is never a
/// photo library in the picture and never a path to name.
bool get savesToPhotoLibrary => false;

String? _lastSavedPath;

/// Always null on the web — a download goes wherever the browser puts
/// it and the page is never told where that was. The sheet's "saved
/// to …" message is therefore never reached on this platform, which
/// is correct: [VerseCardDelivery.downloaded] is its own outcome with
/// its own wording.
String? get lastSavedPath => _lastSavedPath;

/// The download route on its own, for the sheet's explicit "save"
/// action. Kept separate from [deliverImage] because a reader who asks
/// to SAVE must not be handed a share sheet instead.
VerseCardDelivery saveImage({
  required Uint8List png,
  required String fileName,
}) =>
    _download(png, fileName);

Future<VerseCardDelivery> deliverImage({
  required Uint8List png,
  required String fileName,
  required String shareText,
}) async {
  if (canShareImage()) {
    try {
      final file = web.File(
        <JSAny>[png.toJS].toJS,
        fileName,
        web.FilePropertyBag(type: 'image/png'),
      );
      // The FILE ALONE — no `text` beside it.
      //
      // 2026-09-13, owner-reported: the share sheet came up and had no
      // way to keep the picture. iOS treats a share carrying both a
      // file and text as a TEXT share with an attachment, and its
      // image actions — 存储图像 / Save Image / Add to Photos — are not
      // offered for one. Sharing the file on its own gets the image
      // sheet, which has them.
      //
      // Nothing is lost by dropping it: the verse, its reference and
      // its edition are all rendered INTO the card. The text was a
      // second copy of what the reader is already looking at.
      await web.window.navigator
          .share(web.ShareData(files: <web.File>[file].toJS))
          .toDart;
      return VerseCardDelivery.shared;
    } catch (error) {
      // A dismissed share sheet rejects with AbortError, and that is
      // not a failure — reporting it as one, or quietly downloading
      // the file instead, both punish the reader for changing their
      // mind. Anything else IS a failure, and for those the download
      // route below still works, so fall through to it rather than
      // leaving the reader with nothing.
      if (_isAbort(error)) return VerseCardDelivery.cancelled;
    }
  }
  return _download(png, fileName);
}

/// iOS Safari, and every iPadOS browser — they are all WebKit, and
/// they all behave the same way about `<a download>`.
///
/// User-agent sniffing, which is normally the wrong tool. There is no
/// feature to detect here: the anchor click succeeds on both platforms
/// and the difference is what the browser then DOES with it, which is
/// not observable from the page. The alternative is to describe the
/// outcome wrongly on one platform or the other.
bool _isIosSafari() {
  try {
    final nav = web.window.navigator;
    final ua = nav.userAgent;
    final ios = ua.contains('iPhone') || ua.contains('iPad');
    // iPadOS 13+ reports a desktop Mac UA; the touch points give it
    // away, since no real Mac has any.
    final iPadOsDesktop = ua.contains('Macintosh') && nav.maxTouchPoints > 0;
    return ios || iPadOsDesktop;
  } catch (_) {
    return false;
  }
}

bool _isAbort(Object? error) {
  try {
    final name = (error as JSObject).getProperty<JSString?>('name'.toJS);
    return name?.toDart == 'AbortError';
  } catch (_) {
    // Unreadable rejection value. Treat it as a real failure so the
    // caller falls through to the download — the reader still gets
    // the file, which is the outcome that matters.
    return false;
  }
}

VerseCardDelivery _download(Uint8List png, String fileName) {
  String? url;
  try {
    final blob = web.Blob(
      <JSAny>[png.toJS].toJS,
      web.BlobPropertyBag(type: 'image/png'),
    );
    url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = fileName
      // Never attached to the document. A detached anchor's synthetic
      // click still triggers the download in every browser that
      // honours `download` at all, and not appending it means there is
      // no element left behind if anything below throws.
      ..style.display = 'none';
    anchor.click();
    // iOS Safari ignores `download` on a blob URL and OPENS the image
    // instead. That is still a route to keeping it — long-press the
    // picture — but it is not a download, and saying "Image
    // downloaded" would send the reader to look in Files for a file
    // that is not there.
    return _isIosSafari()
        ? VerseCardDelivery.openedInTab
        : VerseCardDelivery.downloaded;
  } catch (_) {
    return VerseCardDelivery.failed;
  } finally {
    // Revoked immediately: the browser has already taken its own
    // reference by the time `click()` returns, and an un-revoked
    // object URL pins the whole PNG in memory for the life of the
    // document. A reader who makes twenty cards would otherwise be
    // carrying twenty of them.
    if (url != null) web.URL.revokeObjectURL(url);
  }
}
