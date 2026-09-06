/// 2026-09-06 — a sync failure must be told, not hidden, when the
/// cause is that the network could not reach the server.
///
/// The ruling: never say "sync is on" before a round trip has
/// completed. Either a real "Last synced …" stamp, or a sentence
/// saying the server could not be reached, the local data is safe, the
/// reader is still signed in — plus Retry.
///
/// This matters most in a China build, where email sign-in can work
/// (`identitytoolkit.googleapis.com`) while RTDB
/// (`*.firebaseio.com`) does not. The pre-existing behaviour rendered
/// `SizedBox.shrink()` for that case: an account, no visible sync, and
/// no explanation, which reads as "everything is fine".
///
/// [classifySyncError] is pure and public specifically so this can be
/// a real test rather than a source assertion.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/services/cloud_sync_service.dart';
import 'package:yswords/widgets/sync_unreachable_notice.dart';

void main() {
  group('classifySyncError', () {
    test('a non-error status is never classified as an error', () {
      for (final s in const [
        CloudSyncStatus.disabled,
        CloudSyncStatus.synced,
        CloudSyncStatus.syncing,
      ]) {
        expect(classifySyncError(s, 'timed out'), SyncErrorKind.none,
            reason: '$s must not be read as an error');
      }
    });

    test('network failures are UNREACHABLE — the case that must be told',
        () {
      // Real shapes seen from RTDB / the app's own wrapper.
      for (final msg in const [
        'TimeoutException after 0:00:20.000000',
        'Sync timed out after 2 minutes (twice).',
        '[unavailable] The service is currently unavailable.',
        'Offline — sync will resume when your connection is back.',
        'Failed to connect to firebaseio.com',
        'WebChannel transport channel closed',
        'network-request-failed',
        'SocketException: Connection refused',
      ]) {
        expect(
          classifySyncError(CloudSyncStatus.error, msg),
          SyncErrorKind.unreachable,
          reason: 'not classified unreachable: $msg',
        );
      }
    });

    test('project misconfiguration stays hidden — the reader cannot act',
        () {
      for (final msg in const [
        '[permission-denied] Client does not have permission',
        'set error: Permission denied',
        '[database-disabled] Realtime Database is not enabled',
        'Database lives in a different region',
      ]) {
        expect(
          classifySyncError(CloudSyncStatus.error, msg),
          SyncErrorKind.misconfigured,
          reason: 'not classified misconfigured: $msg',
        );
      }
    });

    test('an unrecognised error is transient, not silently swallowed', () {
      expect(
        classifySyncError(CloudSyncStatus.error, 'something new broke'),
        SyncErrorKind.transient,
      );
      expect(
        classifySyncError(CloudSyncStatus.error, null),
        SyncErrorKind.transient,
      );
    });

    test('unreachable and misconfigured are genuinely distinguished', () {
      // A classifier that returned one value for everything would pass
      // half of the cases above by luck. This is the discriminating
      // pair: both are RTDB failures, and they must not land in the
      // same bucket.
      final a = classifySyncError(
          CloudSyncStatus.error, 'TimeoutException after 0:00:20');
      final b = classifySyncError(
          CloudSyncStatus.error, '[permission-denied] no access');
      expect(a, isNot(b));
    });
  });

  group('SyncUnreachableNotice', () {
    for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
      testWidgets('says the honest sentence in $locale', (tester) async {
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SyncUnreachableNotice(locale: locale, onRetry: () {}),
          ),
        ));
        final text = tester
            .widget<Text>(find.byKey(const Key('sync.unreachable')))
            .data;
        expect(text, uiStrings['syncUnreachable']![locale]);
        // It must not be the English fallback for a Chinese reader.
        if (locale != 'en') {
          expect(text, isNot(uiStrings['syncUnreachable']!['en']));
        }
      });
    }

    testWidgets('Retry is wired', (tester) async {
      var retries = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SyncUnreachableNotice(locale: 'en', onRetry: () => retries++),
        ),
      ));
      await tester.tap(find.byKey(const Key('sync.unreachableRetry')));
      await tester.pump();
      expect(retries, 1);
    });

    testWidgets('it claims nothing about sync working', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SyncUnreachableNotice(locale: 'en', onRetry: () {}),
        ),
      ));
      final text = tester
          .widget<Text>(find.byKey(const Key('sync.unreachable')))
          .data!
          .toLowerCase();
      for (final claim in const ['sync is on', 'synced', 'up to date']) {
        expect(text.contains(claim), isFalse,
            reason: 'the unreachable notice claims "$claim"');
      }
      // And it does make the three promises the ruling asks for.
      expect(text.contains("couldn't reach"), isTrue);
      expect(text.contains('safe on this device'), isTrue);
      expect(text.contains("still signed in"), isTrue);
    });
  });
}
