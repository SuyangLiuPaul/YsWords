// Web implementation of cross-platform sharing using the Web Share
// API. `navigator.share` is supported on iOS Safari, Android
// Chrome, and recent Edge/Chrome on desktop (with HTTPS). Fires a
// promise that resolves on success or rejects on user-cancel /
// permission denied / unsupported.

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('navigator')
external _Navigator get _navigator;

@JS()
@staticInterop
class _Navigator {}

extension on _Navigator {
  external JSPromise<JSAny?> share(JSObject data);
}

bool shareIsAvailable() {
  try {
    // Feature-detect via property lookup on the navigator object.
    // `hasProperty` is from dart:js_interop_unsafe; it's the
    // closest mapping to JS's `'share' in navigator`.
    return _navigator.has('share');
  } catch (_) {
    return false;
  }
}

extension on _Navigator {
  bool has(String prop) =>
      (this as JSObject).hasProperty(prop.toJS).toDart;
}

Future<bool> shareText({
  required String text,
  String? title,
  String? url,
}) async {
  if (!shareIsAvailable()) return false;
  try {
    // Build a plain JS object (the shape navigator.share expects).
    final data = JSObject()
      ..setProperty('text'.toJS, text.toJS)
      ..setProperty('title'.toJS, (title ?? 'YsWords').toJS);
    if (url != null && url.isNotEmpty) {
      data.setProperty('url'.toJS, url.toJS);
    }
    await _navigator.share(data).toDart;
    return true;
  } catch (_) {
    // User cancelled, browser blocked, or another error. Caller
    // falls back to clipboard.
    return false;
  }
}
