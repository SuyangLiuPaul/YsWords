import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/services/remote_data_service.dart';

/// 2026-06-12 (v1.3.63 perf): the dashboard's single "Today's Evidence"
/// card used to re-download the whole ~420 KB evidence archive from
/// yswords-data on EVERY cold start (RemoteDataService.load fires a
/// background refresh on every call). `shouldThrottleRefresh` gates
/// that refresh by a per-service min-interval. These lock the
/// decision: rarely-changing archives skip the boot-time GET; the
/// hourly news feed (interval zero) and explicit refreshes never do.
void main() {
  final now = DateTime.utc(2026, 6, 12, 12, 0, 0);

  group('shouldThrottleRefresh', () {
    test('interval zero never throttles (news feed behavior)', () {
      final fiveMinAgo = now.subtract(const Duration(minutes: 5));
      expect(
        shouldThrottleRefresh(
            fiveMinAgo.toIso8601String(), Duration.zero, now),
        isFalse,
      );
    });

    test('throttles when last refresh is within the interval', () {
      final twoHoursAgo = now.subtract(const Duration(hours: 2));
      expect(
        shouldThrottleRefresh(twoHoursAgo.toIso8601String(),
            const Duration(hours: 12), now),
        isTrue,
        reason: '2h ago is within a 12h window → skip the GET',
      );
    });

    test('allows refresh once the interval has elapsed', () {
      final thirteenHoursAgo = now.subtract(const Duration(hours: 13));
      expect(
        shouldThrottleRefresh(thirteenHoursAgo.toIso8601String(),
            const Duration(hours: 12), now),
        isFalse,
      );
    });

    test('null/empty timestamp (never refreshed) always allows', () {
      expect(
        shouldThrottleRefresh(null, const Duration(hours: 12), now),
        isFalse,
      );
      expect(
        shouldThrottleRefresh('', const Duration(hours: 12), now),
        isFalse,
      );
    });

    test('unparseable timestamp falls open (allows refresh)', () {
      expect(
        shouldThrottleRefresh(
            'not-a-date', const Duration(hours: 12), now),
        isFalse,
      );
    });

    test('handles a non-UTC stored timestamp via toUtc()', () {
      // Local-zone ISO string 2h before `now`. difference() still < 12h.
      final localTwoHoursAgo =
          now.toLocal().subtract(const Duration(hours: 2));
      expect(
        shouldThrottleRefresh(localTwoHoursAgo.toIso8601String(),
            const Duration(hours: 12), now),
        isTrue,
      );
    });

    test('exactly at the boundary allows refresh (< is strict)', () {
      final exactly12h = now.subtract(const Duration(hours: 12));
      expect(
        shouldThrottleRefresh(exactly12h.toIso8601String(),
            const Duration(hours: 12), now),
        isFalse,
      );
    });
  });
}
