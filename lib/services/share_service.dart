// Cross-platform share helper. On web uses navigator.share when
// available (mobile + most modern desktop browsers), otherwise
// falls back to copy-to-clipboard + toast. The conditional import
// keeps non-web targets type-clean even though we currently only
// ship for web.

import 'share_service_stub.dart'
    if (dart.library.js_interop) 'share_service_web.dart' as impl;

class ShareService {
  /// Whether the platform exposes a native share sheet. UI uses
  /// this to label the button "Share" vs "Copy" (the copy-as-
  /// fallback works everywhere).
  static bool get isAvailable => impl.shareIsAvailable();

  /// Open the platform share sheet with [text] (and optional [title]
  /// shown as the share-target hint). Resolves to true on success,
  /// false on cancel / error / unsupported. Caller should fall back
  /// to clipboard copy when this returns false.
  static Future<bool> shareText({
    required String text,
    String? title,
    String? url,
  }) =>
      impl.shareText(text: text, title: title, url: url);
}
