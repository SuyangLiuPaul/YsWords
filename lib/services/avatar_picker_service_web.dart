// Web binding for the avatar picker. The actual file-input + canvas
// resize logic lives in `web/index.html` as `window.yswordsPickAvatar()`
// — see the comment block above the script there. Keeping the JS
// inline in the HTML rather than building the same flow with raw
// js_interop primitives is much shorter and easier to maintain.

import 'dart:js_interop';

@JS('yswordsPickAvatar')
external JSPromise<JSAny?> _yswordsPickAvatar();

bool avatarPickerIsAvailable() {
  // The function is defined in web/index.html. We can't tear off
  // an external top-level member to inspect it, but in practice
  // the function is always present after index.html parses; the
  // only failure mode is if the script element 404s (Netlify
  // misconfig). The call site already wraps the invocation in a
  // try/catch — if it throws, the user sees the picker not opening,
  // not a crash.
  return true;
}

Future<String?> avatarPick() async {
  try {
    final result = await _yswordsPickAvatar().toDart;
    if (result == null) return null;
    // Result is a JS string (data URL) or null.
    final str = result as JSString?;
    return str?.toDart;
  } catch (_) {
    return null;
  }
}
