// Pinned regression test for the dashboard greeting bug:
// pre-fix `hour < 12` returned "Good morning" at 00:00 — midnight is
// not morning. Now morning starts at 05:00.

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/utils/greeting.dart';

void main() {
  group('dayPartForHour', () {
    test('night covers 22:00 - 04:59', () {
      for (final h in [22, 23, 0, 1, 2, 3, 4]) {
        expect(dayPartForHour(h), DayPart.night, reason: 'hour=$h');
      }
    });

    test('morning is 05:00 - 11:59 (NOT before 05:00)', () {
      for (final h in [5, 6, 8, 11]) {
        expect(dayPartForHour(h), DayPart.morning, reason: 'hour=$h');
      }
      // Bug-pin: 00, 03, 04 must NOT be morning.
      for (final h in [0, 3, 4]) {
        expect(dayPartForHour(h), DayPart.night,
            reason: 'pre-5am must be night, not morning (hour=$h)');
      }
    });

    test('afternoon is 12:00 - 17:59', () {
      for (final h in [12, 13, 15, 17]) {
        expect(dayPartForHour(h), DayPart.afternoon, reason: 'hour=$h');
      }
    });

    test('evening is 18:00 - 21:59', () {
      for (final h in [18, 19, 20, 21]) {
        expect(dayPartForHour(h), DayPart.evening, reason: 'hour=$h');
      }
    });

    test('boundary hours snap correctly', () {
      expect(dayPartForHour(4), DayPart.night);
      expect(dayPartForHour(5), DayPart.morning);
      expect(dayPartForHour(11), DayPart.morning);
      expect(dayPartForHour(12), DayPart.afternoon);
      expect(dayPartForHour(17), DayPart.afternoon);
      expect(dayPartForHour(18), DayPart.evening);
      expect(dayPartForHour(21), DayPart.evening);
      expect(dayPartForHour(22), DayPart.night);
    });
  });

  group('greetingFor', () {
    test('returns Good morning at 06:00', () {
      final t = DateTime(2026, 4, 30, 6);
      expect(greetingFor(now: t, locale: 'en'), 'Good morning');
      expect(greetingFor(now: t, locale: 'zh-Hans'), '早安');
    });

    test('returns Good night at 00:00 (the original bug)', () {
      final t = DateTime(2026, 4, 30, 0);
      expect(greetingFor(now: t, locale: 'en'), 'Good night');
      expect(greetingFor(now: t, locale: 'zh-Hans'), '夜安');
      expect(greetingFor(now: t, locale: 'zh-Hant'), '夜安');
    });

    test('returns Good afternoon at 14:00', () {
      final t = DateTime(2026, 4, 30, 14);
      expect(greetingFor(now: t, locale: 'en'), 'Good afternoon');
      expect(greetingFor(now: t, locale: 'zh-Hans'), '午安');
    });

    test('returns Good evening at 19:00', () {
      final t = DateTime(2026, 4, 30, 19);
      expect(greetingFor(now: t, locale: 'en'), 'Good evening');
      expect(greetingFor(now: t, locale: 'zh-Hans'), '晚安');
    });
  });
}
