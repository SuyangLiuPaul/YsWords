/// 2026-06-15 (v1.3.80): regression test for the "Syncing↔Synced 来回跳"
/// (发癫) cloud-sync flicker loop.
///
/// Root cause: `MainProvider.saveCurrentState()` (and the parallel
/// `AppSettings._writeUserPrefsBlob()`) stamped a fresh
/// `lastReadTimestamp = now()` and fired `RealtimeDbSyncService
/// .requestUpload()` on EVERY call — including calls driven by rebuilds
/// that a sync-status change triggered (PageView re-settling on the same
/// chapter, restoreState's boot-seed, a status-listener setState). Because
/// the timestamp changed each time, the sync layer's own dedupe hash
/// never matched, so it uploaded again → flipped the status → rebuilt →
/// called saveCurrentState again … forever.
///
/// The fix is a content guard: only re-stamp + upload when the synced
/// blob actually changed. This test locks that contract for the
/// reading-position blob (the userPrefs blob shares the identical
/// pattern via the shared `_userPrefsSnapshot()` serializer).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/profile_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String tsKey() => ProfileService.instance.scopedKey('lastReadTimestamp');

  group('saveCurrentState content guard', () {
    test('identical reading position does NOT re-stamp the timestamp',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final mp = MainProvider();
      mp.currentVersion = 'cuvs-yhwh';
      mp.currentBook = 'John';
      mp.currentChapter = 3;

      await mp.saveCurrentState();
      final t1 = prefs.getInt(tsKey());
      expect(t1, isNotNull,
          reason: 'first save must seed the lastReadTimestamp');

      // A second save with the SAME position (the kind of call a
      // status-driven rebuild produces) must be a no-op for the
      // synced blob — same timestamp, no churn.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await mp.saveCurrentState();
      final t2 = prefs.getInt(tsKey());
      expect(t2, equals(t1),
          reason: 'unchanged position must not bump lastReadTimestamp');
    });

    test('a genuine position change DOES re-stamp the timestamp', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final mp = MainProvider();
      mp.currentVersion = 'cuvs-yhwh';
      mp.currentBook = 'John';
      mp.currentChapter = 3;
      await mp.saveCurrentState();
      final t1 = prefs.getInt(tsKey());

      // Navigate to a new chapter → the blob differs → re-stamp.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      mp.currentChapter = 4;
      await mp.saveCurrentState();
      final t2 = prefs.getInt(tsKey());

      expect(t2, isNotNull);
      expect(t2, isNot(equals(t1)),
          reason: 'a real navigation must update lastReadTimestamp');
    });
  });
}
