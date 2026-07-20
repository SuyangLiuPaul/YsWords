// 2026-05-24 (v1.3.0): scheduled notification dispatcher. Uses
// flutter_local_notifications' `zonedSchedule` with daily-repeat
// matchDateTimeComponents so each enabled category fires at its
// configured local time every day.
//
// Architecture: pull-based, idempotent.
//   AppSettings change → AppSettings.setX → rescheduleAll(settings)
//   App launch         → main.dart        → rescheduleAll(settings)
//
// rescheduleAll cancels every scheduled notification then re-creates
// the enabled ones with fresh content from the bundled JSON sources.
// Stale content gets refreshed every time the user opens the app or
// touches a setting — no separate refresh path needed.
//
// Web is a no-op: web browsers' Notification API doesn't support
// scheduled delivery, only immediate show. A future v1.3.x could add
// a Service Worker periodic-sync fallback but the spec is poorly
// supported (only Chromium with experimental flags).

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' show Random;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/notification_category.dart';
import 'package:yswords/utils/passage_localizer.dart' show localizePassage;

final FlutterLocalNotificationsPlugin _plugin =
    FlutterLocalNotificationsPlugin();

bool _tzReady = false;
bool _pluginInitialized = false;

/// Initialise timezone data + flutter_local_notifications. Idempotent.
/// MUST be called once at app startup before any rescheduleAll().
Future<void> initNotificationScheduler() async {
  if (kIsWeb) return;
  if (!_tzReady) {
    tz_data.initializeTimeZones();
    try {
      // flutter_timezone 5.x returns a TimezoneInfo record; the IANA
      // name ("Australia/Melbourne") now lives on `.identifier`.
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
      debugPrint('[scheduler] tz set to ${tzInfo.identifier}');
    } catch (e) {
      // Fall back to UTC on platforms where flutter_timezone fails
      // (mostly unsupported desktop builds). Daily fires still work,
      // just at UTC-relative times — visible cosmetic issue only.
      debugPrint('[scheduler] tz detection failed: $e — falling back to UTC');
    }
    _tzReady = true;
  }
  if (!_pluginInitialized) {
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const androidInit =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(
      iOS: darwinInit,
      macOS: darwinInit,
      android: androidInit,
    );
    await _plugin.initialize(initSettings);
    _pluginInitialized = true;
  }
}

bool _isSupported() {
  if (kIsWeb) return false;
  try {
    return Platform.isIOS || Platform.isAndroid || Platform.isMacOS;
  } catch (_) {
    return false;
  }
}

/// Cancel every scheduled YsWords notification and re-create the
/// enabled categories with fresh content.
Future<void> rescheduleAll(AppSettings settings) async {
  if (!_isSupported()) return;
  await initNotificationScheduler();

  await _plugin.cancelAll();
  if (!settings.notificationsEnabled) {
    debugPrint('[scheduler] master toggle off — left empty');
    return;
  }
  if (!_tzReady) {
    debugPrint('[scheduler] tz not ready — skip');
    return;
  }

  for (final id in NotificationCategoryIds.phase1) {
    final prefs = settings.notificationCategory(id);
    if (!prefs.enabled) continue;
    try {
      await _scheduleCategory(id, prefs, settings.locale);
    } catch (e, st) {
      debugPrint('[scheduler] $id failed: $e\n$st');
    }
  }
}

const _kAndroidChannel = AndroidNotificationDetails(
  'yswords_scheduled',
  'Scheduled YsWords notifications',
  channelDescription:
      'Daily Bible verse, sermon, and evidence digests',
  importance: Importance.high,
  priority: Priority.high,
);
const _kDarwinDetails = DarwinNotificationDetails(
  presentAlert: true,
  presentBadge: true,
  presentSound: true,
  presentBanner: true,
  presentList: true,
);
const _kDetails = NotificationDetails(
  android: _kAndroidChannel,
  iOS: _kDarwinDetails,
  macOS: _kDarwinDetails,
);

/// Compute the next instance of [prefs.hour]:[prefs.minute] that
/// matches one of the weekdays in prefs.weekdays. Always returns a
/// future TZDateTime.
tz.TZDateTime _nextFire(NotificationCategoryPrefs prefs) {
  final now = tz.TZDateTime.now(tz.local);
  var candidate = tz.TZDateTime(
      tz.local, now.year, now.month, now.day, prefs.hour, prefs.minute);
  // Step forward at least one minute to avoid scheduling in the past.
  while (!candidate.isAfter(now) ||
      !prefs.weekdays.contains(candidate.weekday)) {
    candidate = candidate.add(const Duration(days: 1));
  }
  return candidate;
}

Future<void> _scheduleCategory(String categoryId,
    NotificationCategoryPrefs prefs, String locale) async {
  final fire = _nextFire(prefs);
  final content = await _resolveContent(categoryId, fire, locale);
  // Stable int id derived from category string so cancel-by-category
  // works without bookkeeping.
  final id = _idForCategory(categoryId);
  await _plugin.zonedSchedule(
    id,
    content.title,
    content.body,
    fire,
    _kDetails,
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    // Repeat every day at the same time. Combined with weekdays
    // filtering at fire time isn't directly supported here, so on
    // weekday-restricted categories we'll cancel+reschedule daily
    // (handled by app-launch rescheduleAll).
    matchDateTimeComponents: DateTimeComponents.time,
    payload: categoryId,
  );
  debugPrint(
      '[scheduler] $categoryId scheduled for $fire — "${content.title}"');
}

int _idForCategory(String categoryId) {
  // Pick a stable but unique-per-category int. 1000 + offset matches
  // human-readable conventions; cancel(id) targets exactly this row.
  switch (categoryId) {
    case NotificationCategoryIds.dailyVerse:
      return 1001;
    case NotificationCategoryIds.bibleEvidence:
      return 1002;
    case NotificationCategoryIds.sermonOfDay:
      return 1003;
    case NotificationCategoryIds.newsDigest:
      return 1004;
    case NotificationCategoryIds.memoryVerse:
      return 1005;
    default:
      return 1000 + categoryId.hashCode.abs() % 1000;
  }
}

class _ScheduledContent {
  final String title;
  final String body;
  _ScheduledContent(this.title, this.body);
}

/// 2026-06-16 (v1.3.89): localized category label (the notification title
/// prefix). These were HARDCODED in Simplified Chinese before, so an
/// English- or Traditional-Chinese-locale user still got 简体 reminders.
/// Now they follow the app's effective locale (which itself follows the
/// system when set to auto), threaded in from `rescheduleAll(settings)`.
String _label(String categoryId, String locale) {
  Map<String, String> m;
  switch (categoryId) {
    case NotificationCategoryIds.dailyVerse:
      m = const {'en': 'Daily Verse', 'zh-Hans': '今日经文', 'zh-Hant': '今日經文'};
      break;
    case NotificationCategoryIds.bibleEvidence:
      m = const {
        'en': 'Bible Evidence',
        'zh-Hans': '圣经考证',
        'zh-Hant': '聖經考證'
      };
      break;
    case NotificationCategoryIds.sermonOfDay:
      m = const {
        'en': "Today's Sermon",
        'zh-Hans': '今日讲道',
        'zh-Hant': '今日講道'
      };
      break;
    case NotificationCategoryIds.newsDigest:
      m = const {'en': 'Bible News', 'zh-Hans': '圣经新闻', 'zh-Hant': '聖經新聞'};
      break;
    case NotificationCategoryIds.memoryVerse:
      m = const {'en': 'Bedtime Verse', 'zh-Hans': '睡前经文', 'zh-Hant': '睡前經文'};
      break;
    default:
      m = const {'en': 'YsWords', 'zh-Hans': 'YsWords', 'zh-Hant': 'YsWords'};
  }
  return m[locale] ?? m['en']!;
}

/// Localized "tap to open" body, used when only a reference is available.
String _openPrompt(String locale) {
  const m = {
    'en': "Tap to read today's verse in YsWords",
    'zh-Hans': '点按在 YsWords 中阅读今日经文',
    'zh-Hant': '點按在 YsWords 中閱讀今日經文',
  };
  return m[locale] ?? m['en']!;
}

/// Look up the title + body for a category fire. Reads from bundled
/// JSON; web/native parity is irrelevant because web doesn't schedule.
Future<_ScheduledContent> _resolveContent(
    String categoryId, tz.TZDateTime fire, String locale) async {
  switch (categoryId) {
    case NotificationCategoryIds.dailyVerse:
      return _resolveDailyVerse(fire, locale);
    case NotificationCategoryIds.bibleEvidence:
      return _resolveBibleEvidence(fire, locale);
    case NotificationCategoryIds.sermonOfDay:
      return _resolveSermonOfDay(fire, locale);
    case NotificationCategoryIds.newsDigest:
    case NotificationCategoryIds.memoryVerse:
      return _ScheduledContent(_label(categoryId, locale), _openPrompt(locale));
    default:
      return _ScheduledContent(_label(categoryId, locale), '');
  }
}

int _dayOfYear(tz.TZDateTime d) {
  final firstDay = tz.TZDateTime(tz.local, d.year, 1, 1);
  return d.difference(firstDay).inDays + 1;
}

/// Daily verse: `assets/daily_verses.json` → `verses` is a list of
/// reference STRINGS ("Genesis 1:1"), one per day-of-year. Title =
/// localized label + the reference localized to the user's language
/// (`localizePassage`); body = a localized "tap to open" prompt (the JSON
/// carries no verse text — only the reference).
Future<_ScheduledContent> _resolveDailyVerse(
    tz.TZDateTime fire, String locale) async {
  final label = _label(NotificationCategoryIds.dailyVerse, locale);
  try {
    final raw = await rootBundle.loadString('assets/daily_verses.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final verses = (json['verses'] as List?) ?? const [];
    if (verses.isEmpty) return _ScheduledContent(label, _openPrompt(locale));
    final ref = verses[_dayOfYear(fire) % verses.length].toString();
    final localizedRef = localizePassage(ref, locale);
    return _ScheduledContent(
      localizedRef.isNotEmpty ? '$label · $localizedRef' : label,
      _openPrompt(locale),
    );
  } catch (e) {
    debugPrint('[scheduler] daily_verses lookup failed: $e');
    return _ScheduledContent(label, _openPrompt(locale));
  }
}

/// Bible evidence: `assets/bible_evidence.json` → entries live under the
/// `evidences` key (NOT `entries`/`items` — that read silently returned
/// empty before). Title = localized label + the entry title; body = the
/// entry summary.
Future<_ScheduledContent> _resolveBibleEvidence(
    tz.TZDateTime fire, String locale) async {
  final label = _label(NotificationCategoryIds.bibleEvidence, locale);
  try {
    final raw = await rootBundle.loadString('assets/bible_evidence.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final entries = (json['evidences'] as List?) ??
        (json['entries'] as List?) ??
        (json['items'] as List?) ??
        const [];
    if (entries.isEmpty) return _ScheduledContent(label, '');
    final entry =
        entries[_dayOfYear(fire) % entries.length] as Map<String, dynamic>;
    final title = entry['title'] as String? ?? '';
    final summary = entry['summary'] as String? ??
        entry['snippet'] as String? ??
        entry['description'] as String? ??
        '';
    final body =
        summary.length > 90 ? '${summary.substring(0, 90)}…' : summary;
    return _ScheduledContent(
        title.isNotEmpty ? '$label · $title' : label, body);
  } catch (e) {
    debugPrint('[scheduler] bible_evidence lookup failed: $e');
    return _ScheduledContent(label, '');
  }
}

Future<_ScheduledContent> _resolveSermonOfDay(
    tz.TZDateTime fire, String locale) async {
  final label = _label(NotificationCategoryIds.sermonOfDay, locale);
  try {
    final raw = await rootBundle.loadString('assets/sermons/index.json');
    final list = jsonDecode(raw) as List;
    if (list.isEmpty) {
      return _ScheduledContent(label, '');
    }
    // Deterministic-ish pick: hash of yyyymmdd → index. Spreads
    // sermons across days more evenly than dayOfYear modulo.
    final ymd = fire.year * 10000 + fire.month * 100 + fire.day;
    final rng = Random(ymd);
    final entry = list[rng.nextInt(list.length)] as Map<String, dynamic>;
    final title =
        entry['title'] as String? ?? entry['name'] as String? ?? '';
    final author =
        entry['author'] as String? ?? entry['preacher'] as String? ?? '';
    return _ScheduledContent(
      label,
      author.isNotEmpty ? '$title · $author' : title,
    );
  } catch (e) {
    debugPrint('[scheduler] sermon lookup failed: $e');
    return _ScheduledContent(label, '');
  }
}
