// Non-web fallback. Add flutter_local_notifications + FCM here when
// the app ships native iOS / Android / desktop builds.

import 'notification_service.dart';

bool notificationIsSupported() => false;

NotificationPermission notificationPermission() =>
    NotificationPermission.unsupported;

Future<NotificationPermission> requestNotificationPermission() async =>
    NotificationPermission.unsupported;

Future<void> showNotification({
  required String title,
  String? body,
  String? tag,
  String? icon,
}) async {}
