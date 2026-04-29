// Web implementation: window.open(url, '_blank') via dart:js_interop.
// Mirrors the JS interop pattern already used in `share_service_web.dart`.

import 'dart:js_interop';

@JS('window.open')
external JSAny? _windowOpen(String url, String target);

bool openIsAvailable() => true;

Future<bool> openUrl(String url) async {
  if (url.isEmpty) return false;
  try {
    final result = _windowOpen(url, '_blank');
    // result is null if the popup was blocked by the browser.
    return result != null;
  } catch (_) {
    return false;
  }
}
