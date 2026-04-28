// Cross-platform "open URL in browser" helper. On web, opens the URL
// in a new tab via window.open(url, '_blank'). On other platforms
// (we don't ship them today, but the contract is here for when we
// do), it returns false so callers can fall back to share-or-copy.
//
// Uses the same conditional-import pattern as `ShareService`.

import 'link_opener_stub.dart'
    if (dart.library.js_interop) 'link_opener_web.dart' as impl;

class LinkOpener {
  /// Open [url] in a new tab (web) / external browser (native, when
  /// we add `url_launcher`). Returns true on apparent success, false
  /// otherwise. Pop-up blockers can cause `true` even when the
  /// browser silently blocks the open — there's no DOM API to detect
  /// that. Callers that need certainty should also offer a copy
  /// fallback.
  static Future<bool> open(String url) => impl.openUrl(url);

  /// Whether this platform can open URLs at all. Web returns true
  /// unconditionally; non-web returns false until url_launcher is
  /// added.
  static bool get isAvailable => impl.openIsAvailable();
}
