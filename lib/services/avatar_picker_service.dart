// Cross-platform image picker for the profile editor. On web uses a
// small JS helper in `web/index.html` (yswordsPickAvatar) that
// opens a file input, center-crops + resizes to 256×256, and
// returns a JPEG data URL. On non-web targets stubbed to null —
// we ship web only, but conditional import keeps types clean.

import 'avatar_picker_service_stub.dart'
    if (dart.library.js_interop) 'avatar_picker_service_web.dart' as impl;

class AvatarPickerService {
  /// Whether the platform supports avatar picking. UI hides the
  /// "Set photo" button when false.
  static bool get isAvailable => impl.avatarPickerIsAvailable();

  /// Open the file picker. Resolves to a JPEG data URL ("data:image
  /// /jpeg;base64,...") of the selected + resized image, or null if
  /// the user cancelled or the read failed. Caller stores the
  /// data URL directly in SharedPreferences.
  static Future<String?> pickAvatar() => impl.avatarPick();
}
