import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/services/realtime_db_sync_service.dart';

void main() {
  final svc = RealtimeDbSyncService.instance;

  group('isInvalidRtdbKey — the v1.3.45 regression guard', () {
    test('rejects the legacy plan.* keys that broke prod sync', () {
      // plan.activeId / plan.completed.* carried a "." which RTDB
      // forbids in keys → every set() rejected → 100% sync failure.
      expect(RealtimeDbSyncService.isInvalidRtdbKeyForTest('plan.activeId'),
          isTrue);
      expect(
          RealtimeDbSyncService.isInvalidRtdbKeyForTest('plan.completed.1'),
          isTrue);
    });

    test('rejects every RTDB-forbidden character', () {
      for (final bad in ['a.b', 'a#b', 'a\$b', 'a/b', 'a[b', 'a]b', '']) {
        expect(RealtimeDbSyncService.isInvalidRtdbKeyForTest(bad), isTrue,
            reason: 'should reject "$bad"');
      }
    });

    test('accepts the keys the sync schema actually uses', () {
      for (final ok in [
        'bookmarks',
        'highlights',
        'verseNotes',
        'lastRead',
        'lastReadTimestamp',
        'userPrefs',
      ]) {
        expect(RealtimeDbSyncService.isInvalidRtdbKeyForTest(ok), isFalse,
            reason: 'should accept "$ok"');
      }
    });
  });

  group('localHasUserData', () {
    test('false for an empty / pristine snapshot', () {
      expect(svc.localHasUserDataForTest(const {}), isFalse);
      expect(
        svc.localHasUserDataForTest(
            const {'bookmarks': [], 'highlights': '{}', 'verseNotes': '{}'}),
        isFalse,
      );
    });

    test('true when any of bookmarks / highlights / notes is present', () {
      expect(
          svc.localHasUserDataForTest(const {
            'bookmarks': ['Genesis 1:1']
          }),
          isTrue);
      expect(
          svc.localHasUserDataForTest(
              const {'highlights': '{"Genesis 1:1":4294948960}'}),
          isTrue);
      expect(
          svc.localHasUserDataForTest(
              const {'verseNotes': '{"John 3:16":"loved"}'}),
          isTrue);
    });
  });

  group('mergeSnapshots — conflict resolution', () {
    test('bookmarks merge as a deduped union', () {
      final out = svc.mergeSnapshotsForTest(
        local: const {
          'bookmarks': ['Genesis 1:1', 'John 3:16']
        },
        remote: const {
          'bookmarks': ['John 3:16', 'Psalms 23:1']
        },
      );
      final bm = (out['bookmarks'] as List).cast<String>().toSet();
      expect(bm, {'Genesis 1:1', 'John 3:16', 'Psalms 23:1'});
    });

    test('highlights: local wins on a per-verse key conflict', () {
      final out = svc.mergeSnapshotsForTest(
        local: const {'highlights': '{"Genesis 1:1":111}'},
        remote: const {'highlights': '{"Genesis 1:1":999,"Exodus 2:2":222}'},
      );
      final hl = jsonDecode(out['highlights'] as String) as Map;
      expect(hl['Genesis 1:1'], 111); // local edit kept
      expect(hl['Exodus 2:2'], 222); // remote-only carried over
    });

    test('lastRead is newest-timestamp-wins (remote newer)', () {
      final out = svc.mergeSnapshotsForTest(
        local: const {'lastRead': 'LOCAL', 'lastReadTimestamp': 1000},
        remote: const {'lastRead': 'REMOTE', 'lastReadTimestamp': 2000},
      );
      expect(out['lastRead'], 'REMOTE');
      expect(out['lastReadTimestamp'], 2000);
    });

    test('lastRead is newest-timestamp-wins (local newer)', () {
      final out = svc.mergeSnapshotsForTest(
        local: const {'lastRead': 'LOCAL', 'lastReadTimestamp': 5000},
        remote: const {'lastRead': 'REMOTE', 'lastReadTimestamp': 2000},
      );
      expect(out['lastRead'], 'LOCAL');
      expect(out['lastReadTimestamp'], 5000);
    });

    test('lastRead present on only one side wins by default', () {
      final out = svc.mergeSnapshotsForTest(
        local: const {'lastRead': 'ONLY_LOCAL', 'lastReadTimestamp': 7},
        remote: const {},
      );
      expect(out['lastRead'], 'ONLY_LOCAL');
    });

    test('verseNoteTimestamps merge max-per-key', () {
      final out = svc.mergeSnapshotsForTest(
        local: const {'verseNoteTimestamps': '{"a":100,"b":50}'},
        remote: const {'verseNoteTimestamps': '{"a":80,"c":300}'},
      );
      final ts = jsonDecode(out['verseNoteTimestamps'] as String) as Map;
      expect(ts['a'], 100); // max(100, 80)
      expect(ts['b'], 50);
      expect(ts['c'], 300);
    });

    test('two empty snapshots merge to an empty map (no crash)', () {
      expect(svc.mergeSnapshotsForTest(local: const {}, remote: const {}),
          isEmpty);
    });
  });
}
