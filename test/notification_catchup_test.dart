// The rules that decide whether a reader's reminder reaches them on the
// web, where the platform gives us no scheduler at all.
//
// yahwehword.com is YsWords' primary channel, and until 2026-09-08 the
// notification settings there were wired to nothing:
// `notification_scheduler.dart` opens `if (kIsWeb) return;`. A reader
// could set a 07:00 daily verse with a weekday mask and never hear from
// it again. `NotificationCatchup` delivers on open instead — so the
// question these tests pin is the one that decides whether a reader gets
// a banner, gets it twice, or gets three at once the moment they opt in.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/notification_category.dart';
import 'package:yswords/services/notification_catchup.dart';
import 'package:yswords/services/profile_service.dart';

/// A weekday and a weekend day in the same week, so the weekday mask can
/// be exercised without arithmetic in the test bodies.
final DateTime tuesday0800 = DateTime(2026, 9, 8, 8, 0);
final DateTime tuesday0630 = DateTime(2026, 9, 8, 6, 30);
final DateTime saturday0800 = DateTime(2026, 9, 12, 8, 0);

NotificationCategoryPrefs Function(String) only({
  required String categoryId,
  required NotificationCategoryPrefs prefs,
}) =>
    (id) => id == categoryId
        ? prefs
        : NotificationCategoryPrefs.defaultFor(id);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    NotificationCatchup.debugPretendWeb = true;
  });

  tearDown(() {
    NotificationCatchup.debugPretendWeb = false;
    NotificationCatchup.nowFn = DateTime.now;
  });

  group('deciding what is due', () {
    test('a verse set for 07:00 is due when the reader opens at 08:00', () {
      expect(
        NotificationCatchup.dueCategories(
          notificationsEnabled: true,
          prefsFor: only(
            categoryId: NotificationCategoryIds.dailyVerse,
            prefs: const NotificationCategoryPrefs(
                enabled: true, hour: 7, minute: 0),
          ),
          now: tuesday0800,
          shownOn: const {},
        ),
        [NotificationCategoryIds.dailyVerse],
      );
    });

    test('the same verse is not due at 06:30 — its time has not come', () {
      expect(
        NotificationCatchup.dueCategories(
          notificationsEnabled: true,
          prefsFor: only(
            categoryId: NotificationCategoryIds.dailyVerse,
            prefs: const NotificationCategoryPrefs(
                enabled: true, hour: 7, minute: 0),
          ),
          now: tuesday0630,
          shownOn: const {},
        ),
        isEmpty,
      );
    });

    test('one already shown today is not shown again', () {
      expect(
        NotificationCatchup.dueCategories(
          notificationsEnabled: true,
          prefsFor: only(
            categoryId: NotificationCategoryIds.dailyVerse,
            prefs: const NotificationCategoryPrefs(
                enabled: true, hour: 7, minute: 0),
          ),
          now: tuesday0800,
          shownOn: {
            NotificationCategoryIds.dailyVerse:
                NotificationCatchup.dayKey(tuesday0800)
          },
        ),
        isEmpty,
      );
    });

    test('yesterday in the ledger does not suppress today', () {
      expect(
        NotificationCatchup.dueCategories(
          notificationsEnabled: true,
          prefsFor: only(
            categoryId: NotificationCategoryIds.dailyVerse,
            prefs: const NotificationCategoryPrefs(
                enabled: true, hour: 7, minute: 0),
          ),
          now: tuesday0800,
          shownOn: {
            NotificationCategoryIds.dailyVerse: NotificationCatchup.dayKey(
                tuesday0800.subtract(const Duration(days: 1)))
          },
        ),
        [NotificationCategoryIds.dailyVerse],
      );
    });

    test('a weekdays-only reminder stays silent on Saturday', () {
      expect(
        NotificationCatchup.dueCategories(
          notificationsEnabled: true,
          prefsFor: only(
            categoryId: NotificationCategoryIds.dailyVerse,
            prefs: const NotificationCategoryPrefs(
                enabled: true, hour: 7, minute: 0, weekdays: {1, 2, 3, 4, 5}),
          ),
          now: saturday0800,
          shownOn: const {},
        ),
        isEmpty,
      );
    });

    test('the master switch off silences a category that is on', () {
      expect(
        NotificationCatchup.dueCategories(
          notificationsEnabled: false,
          prefsFor: only(
            categoryId: NotificationCategoryIds.dailyVerse,
            prefs: const NotificationCategoryPrefs(
                enabled: true, hour: 7, minute: 0),
          ),
          now: tuesday0800,
          shownOn: const {},
        ),
        isEmpty,
      );
    });

    test('a category that is off is not delivered by the master switch', () {
      expect(
        NotificationCatchup.dueCategories(
          notificationsEnabled: true,
          prefsFor: (_) =>
              const NotificationCategoryPrefs(enabled: false, hour: 7, minute: 0),
          now: tuesday0800,
          shownOn: const {},
        ),
        isEmpty,
      );
    });

    test('an evening opener gets the morning verse before the evening sermon',
        () {
      // Three categories all overdue at once. They arrive in the order
      // they would have arrived in, not in category-declaration order,
      // so the notification stack reads as a day rather than a jumble.
      const times = {
        NotificationCategoryIds.dailyVerse: 7,
        NotificationCategoryIds.bibleEvidence: 12,
        NotificationCategoryIds.sermonOfDay: 19,
      };
      final due = NotificationCatchup.dueCategories(
        notificationsEnabled: true,
        prefsFor: (id) => NotificationCategoryPrefs(
            enabled: true, hour: times[id] ?? 9, minute: 0),
        now: DateTime(2026, 9, 8, 21, 30),
        shownOn: const {},
      );
      expect(due, [
        NotificationCategoryIds.dailyVerse,
        NotificationCategoryIds.bibleEvidence,
        NotificationCategoryIds.sermonOfDay,
      ]);
    });

    test('phase-2 categories are not delivered even when switched on', () {
      // `newsDigest` needs a network fetch at fire time and
      // `memoryVerse` needs bookmark integration; neither ships, and the
      // native scheduler only walks `phase1`. Delivering them here would
      // put a bare label on screen with nothing behind it.
      final due = NotificationCatchup.dueCategories(
        notificationsEnabled: true,
        prefsFor: (_) =>
            const NotificationCategoryPrefs(enabled: true, hour: 7, minute: 0),
        now: tuesday0800,
        shownOn: const {},
      );
      expect(due, isNot(contains(NotificationCategoryIds.newsDigest)));
      expect(due, isNot(contains(NotificationCategoryIds.memoryVerse)));
    });
  });

  group('arming, so opting in does not detonate', () {
    late AppSettings settings;

    Future<void> boot(Map<String, Object> seed) async {
      SharedPreferences.setMockInitialValues(seed);
      await ProfileService.instance.init();
      settings = AppSettings();
      await settings.loadSettings();
    }

    Map<String, String> ledgerNow(SharedPreferences prefs) {
      final raw = prefs.getString(ProfileService.instance
          .scopedKey(NotificationCatchup.ledgerBaseKey));
      if (raw == null) return {};
      return (jsonDecode(raw) as Map)
          .map((k, v) => MapEntry(k.toString(), v.toString()));
    }

    test('switching a 07:00 verse on at 20:00 does not fire it that evening',
        () async {
      final evening = DateTime(2026, 9, 8, 20, 0);
      NotificationCatchup.nowFn = () => evening;
      await boot({
        'notificationsEnabled': true,
        'notificationCategories': jsonEncode({
          NotificationCategoryIds.dailyVerse:
              const NotificationCategoryPrefs(
                      enabled: true, hour: 7, minute: 0)
                  .toJson(),
        }),
      });

      await NotificationCatchup.instance.armToday(settings);
      final prefs = await SharedPreferences.getInstance();

      expect(
        ledgerNow(prefs)[NotificationCategoryIds.dailyVerse],
        NotificationCatchup.dayKey(evening),
        reason: 'the morning that already passed must be marked delivered, '
            'or the reader is met by a banner for 07:00 at 20:00',
      );
      expect(
        NotificationCatchup.dueCategories(
          notificationsEnabled: true,
          prefsFor: settings.notificationCategory,
          now: evening,
          shownOn: ledgerNow(prefs),
        ),
        isEmpty,
      );
    });

    test('a 22:00 reminder set at 20:00 still arrives tonight', () async {
      final evening = DateTime(2026, 9, 8, 20, 0);
      NotificationCatchup.nowFn = () => evening;
      await boot({
        'notificationsEnabled': true,
        'notificationCategories': jsonEncode({
          NotificationCategoryIds.sermonOfDay:
              const NotificationCategoryPrefs(
                      enabled: true, hour: 22, minute: 0)
                  .toJson(),
        }),
      });

      await NotificationCatchup.instance.armToday(settings);
      final prefs = await SharedPreferences.getInstance();

      expect(ledgerNow(prefs), isNot(contains(NotificationCategoryIds.sermonOfDay)),
          reason: 'arming must only cover times that have already passed');
      expect(
        NotificationCatchup.dueCategories(
          notificationsEnabled: true,
          prefsFor: settings.notificationCategory,
          now: DateTime(2026, 9, 8, 22, 5),
          shownOn: ledgerNow(prefs),
        ),
        [NotificationCategoryIds.sermonOfDay],
      );
    });

    test('arming leaves tomorrow alone', () async {
      NotificationCatchup.nowFn = () => DateTime(2026, 9, 8, 20, 0);
      await boot({
        'notificationsEnabled': true,
        'notificationCategories': jsonEncode({
          NotificationCategoryIds.dailyVerse:
              const NotificationCategoryPrefs(
                      enabled: true, hour: 7, minute: 0)
                  .toJson(),
        }),
      });
      await NotificationCatchup.instance.armToday(settings);
      final prefs = await SharedPreferences.getInstance();

      expect(
        NotificationCatchup.dueCategories(
          notificationsEnabled: true,
          prefsFor: settings.notificationCategory,
          now: DateTime(2026, 9, 9, 8, 0),
          shownOn: {
            for (final e in ledgerNow(prefs).entries) e.key: e.value
          },
        ),
        [NotificationCategoryIds.dailyVerse],
      );
    });
  });

  group('the ledger', () {
    test('a day key is the local calendar day, zero-padded', () {
      expect(NotificationCatchup.dayKey(DateTime(2026, 1, 2, 23, 59)),
          '2026-01-02');
    });

    test('the ledger key is scoped to the profile, never global', () {
      // Two people sharing a tablet must not suppress each other's
      // reminders, which is the same reason bookmarks and notes are
      // scoped.
      expect(
        ProfileService.instance.scopedKey(NotificationCatchup.ledgerBaseKey),
        contains(NotificationCatchup.ledgerBaseKey),
      );
      expect(
        ProfileService.instance.scopedKey(NotificationCatchup.ledgerBaseKey),
        startsWith('profile.'),
      );
    });
  });
}
