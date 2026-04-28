// Web implementation: wrap window.Notification. Same dart:js_interop
// pattern as share_service_web.dart and link_opener_web.dart.

import 'dart:js_interop';

import 'notification_service.dart';

@JS('Notification.permission')
external String get _notificationPermission;

@JS('Notification.requestPermission')
external JSPromise<JSString> _notificationRequestPermission();

@JS('window.Notification')
external JSAny? get _windowNotification;

// We construct via a small JS shim defined inline in web/index.html
// so the Dart side can pass an options bag without hitting the
// extension-type / inline-class dance (which needs Dart 3.3).
@JS('window.yswordsShowNotification')
external JSAny? _windowShowNotification(String title, JSObject? options);

bool notificationIsSupported() => _windowNotification != null;

NotificationPermission notificationPermission() {
  if (!notificationIsSupported()) return NotificationPermission.unsupported;
  switch (_notificationPermission) {
    case 'granted':
      return NotificationPermission.granted;
    case 'denied':
      return NotificationPermission.denied;
    case 'default':
      return NotificationPermission.prompt;
    default:
      return NotificationPermission.prompt;
  }
}

Future<NotificationPermission> requestNotificationPermission() async {
  if (!notificationIsSupported()) return NotificationPermission.unsupported;
  try {
    final result = await _notificationRequestPermission().toDart;
    final s = result.toDart;
    switch (s) {
      case 'granted':
        return NotificationPermission.granted;
      case 'denied':
        return NotificationPermission.denied;
      default:
        return NotificationPermission.prompt;
    }
  } catch (_) {
    return NotificationPermission.denied;
  }
}

Future<void> showNotification({
  required String title,
  String? body,
  String? tag,
  String? icon,
}) async {
  if (!notificationIsSupported()) return;
  if (notificationPermission() != NotificationPermission.granted) return;
  try {
    final opts = <String, dynamic>{};
    if (body != null && body.isNotEmpty) opts['body'] = body;
    if (tag != null && tag.isNotEmpty) opts['tag'] = tag;
    if (icon != null && icon.isNotEmpty) opts['icon'] = icon;
    final optsJs = opts.jsify() as JSObject?;
    _windowShowNotification(title, optsJs);
  } catch (_) {
    // Browser refused (e.g. permission revoked between checks) —
    // best-effort, no-op.
  }
}
