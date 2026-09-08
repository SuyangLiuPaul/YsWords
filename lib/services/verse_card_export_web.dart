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

import 'package:yswords/services/verse_card_export_types.dart';

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

String? _lastSavedPath;

/// Always null on the web — a download goes wherever the browser puts
/// it and the page is never told where that was. The sheet's "saved
/// to …" message is therefore never reached on this platform, which
/// is correct: [VerseCardDelivery.downloaded] is its own outcome with
/// its own wording.
String? get lastSavedPath => _lastSavedPath;

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
      await web.window.navigator
          .share(web.ShareData(files: <web.File>[file].toJS, text: shareText))
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
    return VerseCardDelivery.downloaded;
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
