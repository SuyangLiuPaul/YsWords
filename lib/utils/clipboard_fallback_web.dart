import 'package:web/web.dart' as web;

/// Legacy `document.execCommand('copy')` fallback for browsers where
/// the async Clipboard API rejects the write.
///
/// Why this exists (2026-07-10, prod crash `copy_fail` on iOS 18.7
/// Safari): Safari only allows `navigator.clipboard.writeText` while a
/// user-activation window is open and the page has clipboard
/// permission; otherwise the promise rejects and Flutter surfaces
/// `PlatformException(copy_fail, Clipboard.setData failed.)`. The
/// synchronous `execCommand('copy')` path predates that permission
/// model and still succeeds in the same tap handler on iOS Safari, so
/// we use it as the second attempt before giving up.
///
/// Mechanics: inject an off-screen readonly `<textarea>` (readonly
/// suppresses the iOS keyboard), select its full contents (iOS needs a
/// real selection range — `select()` alone is not enough), run
/// `execCommand('copy')`, and remove the node. Returns whether the
/// browser reported the copy as successful. Never throws.
bool legacyClipboardCopy(String text) {
  try {
    final doc = web.document;
    final body = doc.body;
    if (body == null) return false;
    final ta = doc.createElement('textarea') as web.HTMLTextAreaElement;
    ta.value = text;
    ta.readOnly = true;
    ta.style
      ..position = 'fixed'
      ..top = '0'
      ..left = '0'
      ..width = '1px'
      ..height = '1px'
      ..padding = '0'
      ..border = 'none'
      ..outline = 'none'
      ..boxShadow = 'none'
      ..background = 'transparent'
      ..opacity = '0';
    body.appendChild(ta);
    ta.focus();
    ta.select();
    ta.setSelectionRange(0, text.length);
    final ok = doc.execCommand('copy');
    ta.blur();
    ta.remove();
    return ok;
  } catch (_) {
    return false;
  }
}
