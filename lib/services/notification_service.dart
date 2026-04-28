// Cross-platform notification helper.
//
// Web (today's only target): wraps the browser Notification API. Can
// request permission and fire local "in-page" notifications when the
// user has the tab open (e.g. "Today's verse is ready", "You haven't
// read today's reading yet"). Persistent push when the tab is
// closed needs Firebase Cloud Messaging — a future round.
//
// Other platforms: stubbed to no-op. When we add iOS / Android we
// swap in `flutter_local_notifications` + FCM in the impl file.

import 'notification_service_stub.dart'
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
