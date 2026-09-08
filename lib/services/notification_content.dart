// 2026-09-08: the title and body of a reminder, resolved from the
// bundled assets, with nothing platform-specific attached.
//
// This used to live inside `notification_scheduler.dart` as private
// helpers keyed on `tz.TZDateTime`. It moved out when the web gained a
// delivery path of its own (`notification_catchup.dart`): both the
// native scheduler and the web catch-up must produce the SAME sentence
// for the same category on the same day, and the only way to guarantee
// that is to have one function produce it. Two copies would have drifted
// the first time anyone fixed a wording.
//
// Nothing here touches `dart:io`, `flutter_local_notifications` or
// `package:timezone`, so it compiles and runs unchanged on the web.
// [resolveNotificationContent] takes a plain [DateTime]: a
// `tz.TZDateTime` IS a `DateTime`, so the scheduler passes its fire time
// straight through.

import 'dart:convert';
import 'dart:math' show Random;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;

import 'package:yswords/models/notification_category.dart';
import 'package:yswords/utils/passage_localizer.dart' show localizePassage;

/// One resolved reminder, ready to hand to whichever delivery mechanism
/// the platform has.
class NotificationContent {
  final String title;
  final String body;
  const NotificationContent(this.title, this.body);
}

/// 2026-06-16 (v1.3.89): localized category label (the notification title
/// prefix). These were HARDCODED in Simplified Chinese before, so an
/// English- or Traditional-Chinese-locale user still got 简体 reminders.
/// Now they follow the app's effective locale (which itself follows the
/// system when set to auto), threaded in from the caller's settings.
String notificationCategoryLabel(String categoryId, String locale) {
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
      m = const {
        'en': "Yahweh's Words",
        'zh-Hans': '雅伟之言',
        'zh-Hant': '雅偉之言',
      };
  }
  return m[locale] ?? m['en']!;
}

/// Localized "tap to open" body, used when only a reference is available.
String _openPrompt(String locale) {
  const m = {
    'en': "Tap to read today's verse in Yahweh's Words",
    'zh-Hans': '点按在雅伟之言中阅读今日经文',
    'zh-Hant': '點按在雅偉之言中閱讀今日經文',
  };
  return m[locale] ?? m['en']!;
}

/// Day of the year for [d], 1-366.
///
/// Computed from the calendar fields via UTC rather than by subtracting
/// two local `DateTime`s. The old form built `DateTime(d.year, 1, 1)` and
/// took `.difference(...).inDays`, which counts ELAPSED HOURS — so in any
/// zone with summer time the answer slips by one for part of the year,
/// and the reminder quietly serves the wrong day's verse. Anchoring both
/// ends in UTC removes the offset entirely.
int dayOfYear(DateTime d) =>
    DateTime.utc(d.year, d.month, d.day)
        .difference(DateTime.utc(d.year, 1, 1))
        .inDays +
    1;

/// Look up the title + body for one category's fire on [when].
///
/// Never throws: a missing or malformed asset degrades to the bare
/// category label, because a reminder with a thin body is still a
/// reminder and an exception here would take the whole delivery down.
Future<NotificationContent> resolveNotificationContent(
    String categoryId, DateTime when, String locale) async {
  switch (categoryId) {
    case NotificationCategoryIds.dailyVerse:
      return _resolveDailyVerse(when, locale);
    case NotificationCategoryIds.bibleEvidence:
      return _resolveBibleEvidence(when, locale);
    case NotificationCategoryIds.sermonOfDay:
      return _resolveSermonOfDay(when, locale);
    case NotificationCategoryIds.newsDigest:
    case NotificationCategoryIds.memoryVerse:
      return NotificationContent(
          notificationCategoryLabel(categoryId, locale), _openPrompt(locale));
    default:
      return NotificationContent(
          notificationCategoryLabel(categoryId, locale), '');
  }
}

/// Daily verse: `assets/daily_verses.json` → `verses` is a list of
/// reference STRINGS ("Genesis 1:1"), one per day-of-year. Title =
/// localized label + the reference localized to the user's language
/// (`localizePassage`); body = a localized "tap to open" prompt (the JSON
/// carries no verse text — only the reference).
Future<NotificationContent> _resolveDailyVerse(
    DateTime when, String locale) async {
  final label =
      notificationCategoryLabel(NotificationCategoryIds.dailyVerse, locale);
  try {
    final raw = await rootBundle.loadString('assets/daily_verses.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final verses = (json['verses'] as List?) ?? const [];
    if (verses.isEmpty) return NotificationContent(label, _openPrompt(locale));
    final ref = verses[dayOfYear(when) % verses.length].toString();
    final localizedRef = localizePassage(ref, locale);
    return NotificationContent(
      localizedRef.isNotEmpty ? '$label · $localizedRef' : label,
      _openPrompt(locale),
    );
  } catch (e) {
    debugPrint('[notif-content] daily_verses lookup failed: $e');
    return NotificationContent(label, _openPrompt(locale));
  }
}

/// Bible evidence: `assets/bible_evidence.json` → entries live under the
/// `evidences` key (NOT `entries`/`items` — that read silently returned
/// empty before). Title = localized label + the entry title; body = the
/// entry summary.
Future<NotificationContent> _resolveBibleEvidence(
    DateTime when, String locale) async {
  final label =
      notificationCategoryLabel(NotificationCategoryIds.bibleEvidence, locale);
  try {
    final raw = await rootBundle.loadString('assets/bible_evidence.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final entries = (json['evidences'] as List?) ??
        (json['entries'] as List?) ??
        (json['items'] as List?) ??
        const [];
    if (entries.isEmpty) return NotificationContent(label, '');
    final entry =
        entries[dayOfYear(when) % entries.length] as Map<String, dynamic>;
    final title = entry['title'] as String? ?? '';
    final summary = entry['summary'] as String? ??
        entry['snippet'] as String? ??
        entry['description'] as String? ??
        '';
    final body = summary.length > 90 ? '${summary.substring(0, 90)}…' : summary;
    return NotificationContent(
        title.isNotEmpty ? '$label · $title' : label, body);
  } catch (e) {
    debugPrint('[notif-content] bible_evidence lookup failed: $e');
    return NotificationContent(label, '');
  }
}

Future<NotificationContent> _resolveSermonOfDay(
    DateTime when, String locale) async {
  final label =
      notificationCategoryLabel(NotificationCategoryIds.sermonOfDay, locale);
  try {
    final raw = await rootBundle.loadString('assets/sermons/index.json');
    final list = jsonDecode(raw) as List;
    if (list.isEmpty) {
      return NotificationContent(label, '');
    }
    // Deterministic-ish pick: hash of yyyymmdd → index. Spreads
    // sermons across days more evenly than dayOfYear modulo.
    final ymd = when.year * 10000 + when.month * 100 + when.day;
    final rng = Random(ymd);
    final entry = list[rng.nextInt(list.length)] as Map<String, dynamic>;
    final title = entry['title'] as String? ?? entry['name'] as String? ?? '';
    final author =
        entry['author'] as String? ?? entry['preacher'] as String? ?? '';
    return NotificationContent(
      label,
      author.isNotEmpty ? '$title · $author' : title,
    );
  } catch (e) {
    debugPrint('[notif-content] sermon lookup failed: $e');
    return NotificationContent(label, '');
  }
}
