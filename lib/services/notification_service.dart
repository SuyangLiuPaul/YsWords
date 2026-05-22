// Cross-platform notification helper.
//
// Web: wraps the browser Notification API via notification_service_web.dart.
// iOS / Android / macOS / desktop: flutter_local_notifications via
// notification_service_io.dart (v1.2.69+).
//
// FCM (remote push when the app is fully backgrounded) is still a
// future round — current implementation is local-only.

import 'notification_service_io.dart'
    if (dart.library.js_interop) 'notification_service_web.dart' as impl;

enum NotificationPermission { granted, denied, prompt, unsupported }

class NotificationService {
  /// Whether the current platform exposes any notification API at all.
  /// UI uses this to decide whether to even show the toggle.
  static bool get isSupported => impl.notificationIsSupported();

  /// Read the current permission state without prompting the user.
  static NotificationPermission get permission =>
      impl.notificationPermission();

  /// Trigger a permission prompt. Returns the resulting state. UI
  /// should call this only when the user explicitly opts into the
  /// notifications setting — never on app launch.
  static Future<NotificationPermission> requestPermission() =>
      impl.requestNotificationPermission();

  /// Show a single local notification. No-ops if the user has not
  /// granted permission. Body / icon are best-effort.
  static Future<void> show({
    required String title,
    String? body,
    String? tag,
    String? icon,
  }) =>
      impl.showNotification(title: title, body: body, tag: tag, icon: icon);
}
