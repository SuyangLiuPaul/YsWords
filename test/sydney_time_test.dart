// DST-boundary tests for the Sydney time helper. Pre-fix the daily-
// news "last updated" line displayed times an hour behind reality
// from October to April because the offset was hardcoded to +10
// (AEST). Sydney runs on AEDT (+11) for that span.

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/utils/sydney_time.dart';

void main() {
  group('sydneyOffsetMinutes', () {
    test('AEST in May (autumn / standard time)', () {
      // 2026-05-15 12:00 UTC → Sydney is on AEST → +600 minutes (10h).
      final t = DateTime.utc(2026, 5, 15, 12);
      expect(sydneyOffsetMinutes(t), 600);
      expect(sydneyTzLabel(t), 'AEST');
    });

    test('AEDT in December (summer / daylight time)', () {
      // 2025-12-15 12:00 UTC → Sydney is on AEDT → +660 minutes (11h).
      final t = DateTime.utc(2025, 12, 15, 12);
      expect(sydneyOffsetMinutes(t), 660);
      expect(sydneyTzLabel(t), 'AEDT');
    });

    test('AEDT in February (still summer south of equator)', () {
      final t = DateTime.utc(2026, 2, 15, 12);
      expect(sydneyOffsetMinutes(t), 660);
      expect(sydneyTzLabel(t), 'AEDT');
    });

    test('DST start: AEDT begins at first Sunday of October 02:00 local', () {
      // 2026: first Sunday of October is the 4th.
      // Transition instant in UTC: 2026-10-03 16:00 UTC.
      final justBefore = DateTime.utc(2026, 10, 3, 15, 59);
      final atTransition = DateTime.utc(2026, 10, 3, 16);
      final justAfter = DateTime.utc(2026, 10, 3, 16, 1);

      expect(sydneyOffsetMinutes(justBefore), 600,
          reason: 'AEST one minute before transition');
      expect(sydneyOffsetMinutes(atTransition), 660,
          reason: 'AEDT exactly at transition');
      expect(sydneyOffsetMinutes(justAfter), 660,
          reason: 'AEDT one minute after transition');
    });

    test('DST end: AEST resumes at first Sunday of April 03:00 local', () {
      // 2026: first Sunday of April is the 5th.
      // Transition instant in UTC: 2026-04-04 16:00 UTC.
      final justBefore = DateTime.utc(2026, 4, 4, 15, 59);
      final atTransition = DateTime.utc(2026, 4, 4, 16);
      final justAfter = DateTime.utc(2026, 4, 4, 16, 1);

      expect(sydneyOffsetMinutes(justBefore), 660,
          reason: 'AEDT one minute before fall-back');
      expect(sydneyOffsetMinutes(atTransition), 600,
          reason: 'AEST exactly at fall-back');
      expect(sydneyOffsetMinutes(justAfter), 600,
          reason: 'AEST one minute after fall-back');
    });
  });

  group('formatSydneyStamp', () {
    test('formats AEST timestamp', () {
      // Generated at 2026-04-29T10:10:43Z (the bundle generatedAt
      // observed during the bug-hunt). AEST means add 10h →
      // 2026-04-29 20:10 Sydney.
      final t = DateTime.utc(2026, 4, 29, 10, 10, 43);
      expect(formatSydneyStamp(t), '2026-04-29 20:10');
    });

    test('formats AEDT timestamp', () {
      // 2025-12-25 03:00 UTC → AEDT (+11) → 2025-12-25 14:00 Sydney.
      final t = DateTime.utc(2025, 12, 25, 3);
      expect(formatSydneyStamp(t), '2025-12-25 14:00');
    });

    test('handles year-rollover during AEDT (UTC vs Sydney off-by-one day)', () {
      // Boxing Day 23:30 UTC during AEDT (+11) → 2026-12-27 10:30 Sydney.
      final t = DateTime.utc(2026, 12, 26, 23, 30);
      expect(formatSydneyStamp(t), '2026-12-27 10:30');
    });
  });

  group('formatViewerLocalStamp', () {
    test('returns a stamp + tz label for a valid moment', () {
      final t = DateTime.utc(2026, 4, 29, 20, 39, 32);
      final out = formatViewerLocalStamp(t);
      // Stamp matches YYYY-MM-DD HH:MM exactly (any TZ).
      expect(out.stamp, matches(RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$')));
      // tzLabel is non-empty — could be "AEST", "PDT", "UTC", etc.
      expect(out.tzLabel.isNotEmpty, isTrue,
          reason: 'always returns SOME label so the masthead never has a dangling space');
    });
  });
}
