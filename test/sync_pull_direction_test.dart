/// 2026-09-04: the "Sync now" button was upload-only.
///
/// Reported from an iPad: signed in, pressed Sync, the iPhone's
/// highlights / notes / bookmarks never came down. The cause was not a
/// network or account problem — `RealtimeDbSyncService.syncNow()` was
/// literally `await _uploadFromLocal()` and nothing else. The only code
/// that ever read the cloud was the `onValue` subscription opened at
/// sign-in, so the button could not pull by construction.
///
/// The second half of the same defect is destructive: the upload is a
/// `set()` on the whole `users/{uid}/sync` node and `_snapshotLocal()`
/// omits keys the device has never written, so pressing the button on a
/// device whose first pull had not landed replaced the cloud copy with
/// that device's emptiness.
///
/// What is genuinely tested here vs. what is only pinned:
///
///   • The merge cases below are REAL — `_mergeSnapshots` is pure and
///     runs without a backend. They prove the property that makes the
///     new bidirectional syncNow safe: an empty local merged against a
///     populated remote returns the remote intact.
///   • The `syncNow` ordering cases are SOURCE-STRUCTURE assertions.
///     Exercising the real method needs a Firebase backend, which this
///     suite does not have. They are here because the regression is
///     invisible to every behavioural test we can run: an upload-only
///     syncNow still returns true and still reports "Synced."
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/services/realtime_db_sync_service.dart';

void main() {
  final svc = RealtimeDbSyncService.instance;

  group('merge — the property that makes a read-before-write safe', () {
    test('empty local against populated remote returns the remote intact',
        () {
      final remote = <String, dynamic>{
        'bookmarks': ['John.3.16', 'Ps.23.1'],
        'highlights': jsonEncode({'John.3.16': 'yellow'}),
        'verseNotes': jsonEncode({'John.3.16': 'so loved'}),
        'notesSortMode': 'recent',
      };
      final merged =
          svc.mergeSnapshotsForTest(local: const {}, remote: remote);

      expect((merged['bookmarks'] as List).toSet(),
          {'John.3.16', 'Ps.23.1'});
      expect(jsonDecode(merged['highlights'] as String),
          {'John.3.16': 'yellow'});
      expect(jsonDecode(merged['verseNotes'] as String),
          {'John.3.16': 'so loved'});
      expect(merged['notesSortMode'], 'recent',
          reason: 'notesSortMode has no bespoke merge rule and was '
              'silently dropped before the generic carry-through loop');
    });

    test('a merged upload cannot delete a key that only the cloud has',
        () {
      // This is the whole reason the button was dangerous: the upload
      // is a whole-node set(), so anything missing from the merged
      // payload is deleted from the cloud.
      final local = <String, dynamic>{
        'highlights': jsonEncode({'Ps.23.1': 'green'}),
      };
      final remote = <String, dynamic>{
        'highlights': jsonEncode({'John.3.16': 'yellow'}),
        'bookmarks': ['Rom.8.28'],
        'notesSortMode': 'oldest',
        'lastRead': jsonEncode({'book': 'John', 'chapter': 3}),
        'lastReadTimestamp': 1725400000000,
      };
      final merged = svc.mergeSnapshotsForTest(local: local, remote: remote);

      for (final k in remote.keys) {
        expect(merged.containsKey(k), isTrue,
            reason: 'merged payload dropped "$k" — a set() with this '
                'payload would delete it from the cloud');
      }
      expect(jsonDecode(merged['highlights'] as String),
          {'John.3.16': 'yellow', 'Ps.23.1': 'green'});
    });

    test('local still wins a per-verse conflict after the carry-through',
        () {
      final merged = svc.mergeSnapshotsForTest(
        local: {'highlights': jsonEncode({'John.3.16': 'green'})},
        remote: {'highlights': jsonEncode({'John.3.16': 'yellow'})},
      );
      expect(jsonDecode(merged['highlights'] as String),
          {'John.3.16': 'green'});
    });

    test('local wins for a carried-through scalar', () {
      final merged = svc.mergeSnapshotsForTest(
        local: const {'notesSortMode': 'canonical'},
        remote: const {'notesSortMode': 'recent'},
      );
      expect(merged['notesSortMode'], 'canonical');
    });
  });

  group('syncNow source structure — it must read before it writes', () {
    late String body;

    setUpAll(() {
      final src = File('lib/services/realtime_db_sync_service.dart')
          .readAsStringSync();
      final start = src.indexOf('Future<bool> syncNow() async {');
      expect(start, greaterThan(-1), reason: 'syncNow() not found');
      // Everything up to the next top-level method declaration.
      final end = src.indexOf('\n  void requestUpload()', start);
      expect(end, greaterThan(start), reason: 'end of syncNow not found');
      body = src.substring(start, end);
    });

    test('reads the cloud copy', () {
      expect(body.contains(".ref('users/\${user.uid}/sync')"), isTrue);
      expect(body.contains('.get()'), isTrue,
          reason: 'syncNow must read before it writes; an upload-only '
              'syncNow is the 2026-09-04 regression');
    });

    test('merges what it read with local', () {
      expect(body.contains('_mergeSnapshots('), isTrue);
      expect(body.contains('_applyRemoteSuppressed('), isTrue,
          reason: 'the pulled result must be written into local prefs, '
              'otherwise nothing appears on screen');
    });

    test('every upload happens AFTER the read', () {
      final read = body.indexOf('.get()');
      for (final m in RegExp(r'_uploadFromLocal\(').allMatches(body)) {
        expect(m.start, greaterThan(read),
            reason: 'an _uploadFromLocal call at offset ${m.start} runs '
                'before the cloud read — that is the clobber path');
      }
    });

    test('clears the first-pull flag only after the read succeeds', () {
      final read = body.indexOf('.get()');
      final clear = body.indexOf('_firstPullAfterSignIn = false');
      expect(clear, greaterThan(read));
    });
  });

  group('upload clobber guard', () {
    test('_uploadFromLocal refuses an empty payload before the first pull',
        () {
      final src = File('lib/services/realtime_db_sync_service.dart')
          .readAsStringSync();
      final start = src.indexOf('Future<void> _uploadFromLocal(');
      final end = src.indexOf('\n  /// User-initiated "Sync now"', start);
      expect(end, greaterThan(start));
      final body = src.substring(start, end);

      expect(
          body.contains(
              'if (_firstPullAfterSignIn && !_localHasUserData(payload))'),
          isTrue,
          reason: 'the guard that stops a never-pulled device wiping the '
              'cloud is missing');
      // The guard must sit above the network write, not below it.
      expect(body.indexOf('_firstPullAfterSignIn && !_localHasUserData'),
          lessThan(body.indexOf('.set(body)')));
    });

    test('an empty snapshot is correctly recognised as having no data', () {
      expect(svc.localHasUserDataForTest(const {}), isFalse);
      expect(
          svc.localHasUserDataForTest(
              const {'highlights': '{}', 'verseNotes': '{}'}),
          isFalse);
      expect(
          svc.localHasUserDataForTest({
            'highlights': jsonEncode({'John.3.16': 'yellow'})
          }),
          isTrue);
    });
  });
}
