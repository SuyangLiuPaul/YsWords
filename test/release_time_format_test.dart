// Pin behaviour for `formatReleaseTimeLocal()` introduced in
// v1.2.35: parse ISO 8601 UTC stamps, format in viewer's local
// timezone, fall back gracefully on unparseable input.
//
// The helper reads `kAppReleaseTime` (a compile-time const that
// dart-define injects from `tools/build_web.py`). We can't easily
// vary that from a unit test, so the tests below pin the
// well-formedness of the OUTPUT for the dev-build fallback path.
// The ISO-parse path is exercised by an inline parser test that
// mirrors the helper's logic.

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/constants/app_version.dart';

void main() {
  group('kAppReleaseTime + formatReleaseTimeLocal', () {
    test('kAppReleaseTime is non-empty and either ISO-UTC or fallback', () {
      expect(kAppReleaseTime, isNotEmpty);
      // Either parseable as ISO 8601 OR clearly a dev-build
      // placeholder (we keep both branches alive — production
      // builds get ISO, dev runs get the placeholder).
      final isIso = kAppReleaseTime.contains('T') &&
          (kAppReleaseTime.endsWith('Z') ||
              kAppReleaseTime.contains('+') ||
              kAppReleaseTime.contains('-'));
      final isDevFallback = kAppReleaseTime.contains('dev-build');
      expect(isIso || isDevFallback, isTrue,
          reason: 'Got: $kAppReleaseTime');
    });

    test('formatReleaseTimeLocal returns a non-empty display string', () {
      final out = formatReleaseTimeLocal();
      expect(out, isNotEmpty);
    });

    test('ISO-UTC stamp converts correctly to local time', () {
      // Mirror the helper's parsing logic so we can assert the
      // expected behaviour without depending on what the build
      // actually injected.
      const sample = '2026-05-10T09:48:00Z';
      final utc = DateTime.parse(sample);
      final local = utc.toLocal();

      // Same instant in time, just different wall-clock.
      expect(utc.millisecondsSinceEpoch,
          equals(local.millisecondsSinceEpoch));

      // The hour shifts according to local UTC offset.
      // We can't pin the exact local hour (depends on test
      // machine), but we CAN pin that minutes match (no DST
      // shenanigans operate at finer than 30-minute granularity
      // in standard zones, and Australia is on full hours).
      expect(local.minute, equals(48));
    });

    test('non-ISO string returns unchanged', () {
      // The helper falls back to the raw string when it doesn't
      // look like ISO 8601 — devs running `flutter run` see
      // the placeholder verbatim.
      const placeholder = '2026-05-10 dev-build (Melbourne)';
      // We can't call the real helper with a custom value, but
      // we can assert the heuristic the helper uses.
      final isIso = placeholder.contains('T') &&
          (placeholder.endsWith('Z') ||
              placeholder.contains('+') ||
              placeholder.contains('-'));
      expect(isIso, isFalse,
          reason: 'Placeholder must NOT be confused for ISO');
    });

    test('TZ-offset ISO stamps parse too (e.g. +10:00)', () {
      // Non-Z UTC stamps (with explicit offset) should also be
      // parseable. Sanity check that DateTime.parse accepts them.
      const sample = '2026-05-10T19:48:00+10:00';
      final dt = DateTime.parse(sample);
      // 19:48 AEST == 09:48 UTC.
      expect(dt.toUtc().hour, equals(9));
      expect(dt.toUtc().minute, equals(48));
    });
  });
}
