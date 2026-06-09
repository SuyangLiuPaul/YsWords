import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/constants/app_version.dart';

/// Regression coverage for the About-footer "last updated" stamp.
///
/// Two bugs prompted this (2026-06-09, v1.3.59):
///   1. The footer rendered with a DIFFERENT format on iOS / web /
///      Android for the same instant, because it used
///      `DateTime.timeZoneName` (platform-specific). Replaced with a
///      self-computed UTC offset via [formatUtcOffsetLabel].
///   2. The footer was BLANK on the Mi Pad, because a build injected an
///      empty `--dart-define=APP_RELEASE_TIME=`. [formatReleaseStamp]
///      now guards empty/blank input.
void main() {
  group('formatUtcOffsetLabel — identical on every platform', () {
    test('whole-hour offsets omit the minutes', () {
      expect(formatUtcOffsetLabel(const Duration(hours: 10)), 'UTC+10');
      expect(formatUtcOffsetLabel(const Duration(hours: 8)), 'UTC+8');
      expect(formatUtcOffsetLabel(Duration.zero), 'UTC+0');
    });

    test('negative offsets keep the sign', () {
      expect(formatUtcOffsetLabel(const Duration(hours: -5)), 'UTC-5');
      expect(
        formatUtcOffsetLabel(const Duration(hours: -3, minutes: -30)),
        'UTC-3:30',
      );
    });

    test('fractional-hour offsets show zero-padded minutes', () {
      expect(
        formatUtcOffsetLabel(const Duration(hours: 5, minutes: 30)),
        'UTC+5:30',
      );
      expect(
        formatUtcOffsetLabel(const Duration(hours: 5, minutes: 45)),
        'UTC+5:45',
      );
    });
  });

  group('formatReleaseStamp', () {
    // Identity-ish converter: keep the parsed instant as UTC (offset 0)
    // so the expected output is deterministic on any host timezone.
    DateTime asUtc(DateTime u) => u.toUtc();

    test('never blank: empty or whitespace input → em dash', () {
      expect(formatReleaseStamp('', asUtc), '—');
      expect(formatReleaseStamp('   ', asUtc), '—');
    });

    test('valid ISO UTC → date + 24h time + offset label', () {
      expect(
        formatReleaseStamp('2026-06-09T02:30:00Z', asUtc),
        '2026-06-09 02:30 UTC+0',
      );
    });

    test('the toLocal converter is applied to the wall clock', () {
      // Shift +10h; `.add` on a UTC DateTime stays UTC (offset 0), so the
      // label is UTC+0 but the date/time advance — proving the converted
      // value (not the raw parse) drives the output.
      DateTime plus10(DateTime u) =>
          u.toUtc().add(const Duration(hours: 10));
      expect(
        formatReleaseStamp('2026-06-09T20:00:00Z', plus10),
        '2026-06-10 06:00 UTC+0',
      );
    });

    test('non-ISO dev-build placeholder passes through unchanged', () {
      expect(
        formatReleaseStamp('2026-05-10 dev-build (Melbourne)', asUtc),
        '2026-05-10 dev-build (Melbourne)',
      );
    });

    test('ISO-shaped but unparseable string falls back to raw', () {
      expect(
        formatReleaseStamp('XXXX-XX-XXTXX:XX:XXZ', asUtc),
        'XXXX-XX-XXTXX:XX:XXZ',
      );
    });
  });

  group('formatReleaseTimeLocal — live constant', () {
    test('the shipped kAppReleaseTime is never blank', () {
      // Whatever the build stamped, the footer must show SOMETHING.
      expect(formatReleaseTimeLocal().trim(), isNotEmpty);
    });
  });
}
