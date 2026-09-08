// The sentence a reminder puts on screen, resolved once for every
// platform.
//
// Content resolution used to be private to `notification_scheduler.dart`
// and keyed on `tz.TZDateTime`. It moved into `notification_content.dart`
// when the web gained its own delivery path: two copies of "which verse
// is today's" would have drifted the first time either was corrected.

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/models/notification_category.dart';
import 'package:yswords/services/notification_content.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('which day it is', () {
    test('1 January is day 1 and 31 December of a leap year is day 366', () {
      expect(dayOfYear(DateTime(2026, 1, 1)), 1);
      expect(dayOfYear(DateTime(2024, 12, 31)), 366);
      expect(dayOfYear(DateTime(2026, 12, 31)), 365);
    });

    test('consecutive calendar dates always differ by exactly one', () {
      // The old form subtracted two LOCAL DateTimes and read `.inDays`,
      // which counts elapsed HOURS: in any zone that springs forward the
      // 23-hour day made every date after it come back one short, and
      // the reminder quietly served the wrong day's verse for months.
      // Walking a whole year one day at a time crosses whichever summer-
      // time transitions the machine running this test observes.
      var previous = dayOfYear(DateTime(2026, 1, 1));
      for (var day = DateTime(2026, 1, 2);
          day.year == 2026;
          day = DateTime(day.year, day.month, day.day + 1)) {
        final current = dayOfYear(day);
        expect(current - previous, 1,
            reason: 'day-of-year jumped at ${day.toIso8601String()}');
        previous = current;
      }
      expect(previous, 365);
    });
  });

  group('the category label', () {
    test('follows the reader\'s language, not the developer\'s', () {
      // Before v1.3.89 these were hardcoded Simplified Chinese, so an
      // English reader was reminded in a language they had not chosen.
      expect(
          notificationCategoryLabel(
              NotificationCategoryIds.dailyVerse, 'en'),
          'Daily Verse');
      expect(
          notificationCategoryLabel(
              NotificationCategoryIds.dailyVerse, 'zh-Hans'),
          '今日经文');
      expect(
          notificationCategoryLabel(
              NotificationCategoryIds.dailyVerse, 'zh-Hant'),
          '今日經文');
    });

    test('an unknown locale falls back to English rather than to nothing', () {
      expect(
          notificationCategoryLabel(NotificationCategoryIds.sermonOfDay, 'fr'),
          "Today's Sermon");
    });
  });

  group('resolving a reminder', () {
    test('the daily verse carries a reference in the reader\'s language',
        () async {
      final en = await resolveNotificationContent(
          NotificationCategoryIds.dailyVerse, DateTime(2026, 9, 8), 'en');
      final zh = await resolveNotificationContent(
          NotificationCategoryIds.dailyVerse, DateTime(2026, 9, 8), 'zh-Hans');
      expect(en.title, startsWith('Daily Verse · '));
      expect(zh.title, startsWith('今日经文 · '));
      expect(en.title, isNot(zh.title),
          reason: 'the reference itself must be localized, not just the label');
      expect(en.body, isNotEmpty);
    });

    test('the same day resolves to the same verse every time', () async {
      // The scheduler and the web catch-up both call this, potentially
      // hours apart on the same day. A reader who sees one notification
      // and opens the app must find the verse it named.
      final a = await resolveNotificationContent(
          NotificationCategoryIds.dailyVerse, DateTime(2026, 9, 8, 7), 'en');
      final b = await resolveNotificationContent(
          NotificationCategoryIds.dailyVerse, DateTime(2026, 9, 8, 23), 'en');
      expect(a.title, b.title);
    });

    test('an unknown category degrades to its label, never to an exception',
        () async {
      final out =
          await resolveNotificationContent('no_such_category', DateTime(2026, 9, 8), 'en');
      expect(out.title, "Yahweh's Words");
    });
  });
}
