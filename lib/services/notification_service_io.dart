// 2026-05-21 (v1.2.69): native (iOS / Android / macOS) implementation
// of the NotificationService contract. Web continues to use the
// browser Notification API via notification_service_web.dart.
//
// Plugin: flutter_local_notifications. Handles:
//   • iOS / macOS: UNUserNotificationCenter permission + display
//   • Android: NotificationManagerCompat + POST_NOTIFICATIONS
//     permission (Android 13+) handled via plugin.requestPermission
//
// "Tag" → Android sets it on the notification, iOS folds it into the
// notification ID. We hash the tag to a stable 32-bit int for the
// plugin's int-only ID parameter.
//
// No scheduling here — only immediate-show. Daily verse / reading
// reminders are a future round and will live in a separate service
// that calls show() at fired times.

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_service.dart';

final FlutterLocalNotificationsPlugin _plugin =
    FlutterLocalNotificationsPlugin();

bool _initialized = false;
// Mirror of the last known permission state. The plugin's
// requestPermissions* methods return a bool; we coerce it into the
// shared NotificationPermission enum. iOS doesn't expose a "prompt"
// vs "denied" distinction without calling requestPermission, so we
// optimistically report `prompt` until the first request.
NotificationPermission _lastKnown = NotificationPermission.prompt;

bool notificationIsSupported() {
  // Plugin supports iOS / Android / macOS / Linux / Windows in modern
  // releases. We're shipping iOS / Android / macOS today; treat the
  // rest as supported too — worst case requestPermission returns
  // false and the UI flips back to denied.
  if (kIsWeb) return false; // web path uses the _web file, not this
  return Platform.isIOS ||
      Platform.isAndroid ||
      Platform.isMacOS ||
      Platform.isLinux ||
      Platform.isWindows;
}

NotificationPermission notificationPermission() => _lastKnown;

Future<void> _ensureInit() async {
  if (_initialized) return;
  // iOS / macOS init: we DON'T request permission at init — only when
  // the user explicitly toggles on. requestAlertPermission etc. all
  // false here.
  const darwinInit = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );
  // Android init: small white-on-transparent icon required. Using the
  // launcher icon for now (`@mipmap/ic_launcher`); a notification-
  // specific monochrome icon can be added later.
  const androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(
    iOS: darwinInit,
    macOS: darwinInit,
    android: androidInit,
  );
  await _plugin.initialize(initSettings);
  _initialized = true;

  // 2026-05-22 (v1.2.71): sync `_lastKnown` with the actual OS-level
  // permission state. The plugin's `checkPermissions` API tells us
  // whether the user has granted permission in a previous session.
  // Without this, `_lastKnown` would stay at `prompt` until the user
  // explicitly toggled in this session, and the "Send test" button
  // path silently dropped its first call.
  try {
    if (Platform.isIOS) {
      final opts = await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.checkPermissions();
      if (opts?.isAlertEnabled == true) {
        _lastKnown = NotificationPermission.granted;
      } else if (opts != null && opts.isAlertEnabled == false) {
        // Plugin returned a value AND alert is off — explicitly denied.
        _lastKnown = NotificationPermission.denied;
      }
    } else if (Platform.isMacOS) {
      final opts = await _plugin
          .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin>()
          ?.checkPermissions();
      if (opts?.isAlertEnabled == true) {
        _lastKnown = NotificationPermission.granted;
      } else if (opts != null && opts.isAlertEnabled == false) {
        _lastKnown = NotificationPermission.denied;
      }
    } else if (Platform.isAndroid) {
      final ok = await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.areNotificationsEnabled();
      if (ok == true) {
        _lastKnown = NotificationPermission.granted;
      } else if (ok == false) {
        _lastKnown = NotificationPermission.denied;
      }
    }
  } catch (e) {
    debugPrint('[notification] checkPermissions failed: $e');
  }
}

Future<NotificationPermission> requestNotificationPermission() async {
  if (!notificationIsSupported()) {
    return _lastKnown = NotificationPermission.unsupported;
  }
  await _ensureInit();

  bool? granted;
  if (Platform.isIOS) {
    granted = await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  } else if (Platform.isMacOS) {
    granted = await _plugin
        .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  } else if (Platform.isAndroid) {
    // Android 13+ POST_NOTIFICATIONS runtime permission. Older
    // Android grants by default — plugin returns true.
    granted = await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  } else {
    granted = true; // Linux / Windows: no explicit permission gate
  }

  _lastKnown =
      (granted == true) ? NotificationPermission.granted : NotificationPermission.denied;
  return _lastKnown;
}

// Stable 32-bit int from an arbitrary tag string. Same tag → same id,
// so re-firing replaces the previous notification rather than stacking.
int _idForTag(String? tag) {
  if (tag == null || tag.isEmpty) return 0;
  var h = 0;
  for (final c in tag.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return h;
}

Future<void> showNotification({
  required String title,
  String? body,
  String? tag,
  String? icon,
}) async {
  // 2026-05-22 (v1.2.71 fix): the previous early-return on
  // `_lastKnown != granted` silently dropped the test notification
  // when the in-memory state was stale (e.g. user previously granted
  // permission in a past session — _lastKnown is module state and
  // resets to `prompt` on each app launch). We now (1) request
  // permission on-demand if not yet granted in this session, and
  // (2) ALWAYS call _plugin.show — flutter_local_notifications
  // returns silently when the OS permission is denied, so it's safe.
  if (!notificationIsSupported()) {
    debugPrint('[notification] platform unsupported');
    return;
  }
  await _ensureInit();

  if (_lastKnown != NotificationPermission.granted) {
    // Re-request permission in case the OS state shifted (user
    // toggled it in Settings between sessions). On iOS/macOS this
    // is a no-op when already granted — no dialog shown.
    await requestNotificationPermission();
  }

  // Android channel: a single "general" channel. Importance bumped to
  // HIGH so the notification produces a heads-up alert (the previous
  // defaultImportance silently lands in the tray with no banner).
  const androidDetails = AndroidNotificationDetails(
    'yswords_general',
    'General',
    channelDescription: 'General YsWords notifications',
    importance: Importance.high,
    priority: Priority.high,
  );
  const darwinDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
    presentBanner: true,
    presentList: true,
  );
  const details = NotificationDetails(
    android: androidDetails,
    iOS: darwinDetails,
    macOS: darwinDetails,
  );

  try {
    await _plugin.show(_idForTag(tag), title, body, details);
    debugPrint(
        '[notification] show OK — title="$title" tag=$tag perm=$_lastKnown');
  } catch (e, st) {
    debugPrint('[notification] show FAILED — $e\n$st');
  }
}
