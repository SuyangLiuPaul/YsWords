// Web implementation: open external links WITHOUT navigating away.
//
// 2026-08-10: this used to be a bare `window.open(url, '_blank')`.
//
// In an installed PWA — `display: standalone`, which this app declares
// and iOS honours once it is on the Home Screen — there is no tab bar
// for `_blank` to open into, and iOS resolves that by loading the URL
// in the app's OWN window. A standalone window has no address bar and
// no back button, so the user ends up parked on someone else's site
// with no way back to YsWords short of force-quitting; audio started
// beforehand keeps playing, so the iOS Now Playing card then returns
// them to "YsWords" and shows that other site.
//
// A synthetic anchor click with `target="_blank"` is the long-standing
// workaround: iOS hands it to Safari as a separate app and leaves the
// PWA window alone. `window.open` stays as the fallback for browsers
// where the anchor route is blocked.

import 'dart:js_interop';

import 'package:web/web.dart' as web;

bool openIsAvailable() => true;

Future<bool> openUrl(String url) async {
  if (url.isEmpty) return false;
  try {
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..target = '_blank'
      // noopener also stops the opened page reaching back through
      // window.opener, which it has no reason to do.
      ..rel = 'noopener noreferrer';
    web.document.body?.appendChild(anchor);
    anchor.click();
    anchor.remove();
    return true;
  } catch (_) {
    // Fall back to the old route rather than silently doing nothing.
    try {
      return _windowOpen(url, '_blank') != null;
    } catch (_) {
      return false;
    }
  }
}

@JS('window.open')
external JSAny? _windowOpen(String url, String target);
