// What the app is allowed to claim about the reader's reading.
//
// YouVersion and 微读圣经 both report reading back to the reader;
// YsWords had only `lastRead`, a single synced slot answering "where do
// I resume". `ReadingHistoryService` is the record the new statistics
// page is built on, so these tests pin the two things that decide
// whether the numbers on that page are true: the dwell gate that
// separates reading from swiping past, and the normalisation that stops
// one book being counted as two.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yswords/services/profile_service.dart';
import 'package:yswords/services/reading_history_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = ReadingHistoryService.instance;
  var clock = DateTime(2026, 9, 8, 9, 0);
  void advance(Duration d) => clock = clock.add(d);

  /// Longer than the dwell bar, so a chapter parked before this counts.
  final dwelt = ReadingHistoryService.minDwell + const Duration(seconds: 1);

  setUp(() async {
    clock = DateTime(2026, 9, 8, 9, 0);
    ReadingHistoryService.nowFn = () => clock;
    SharedPreferences.setMockInitialValues({});
    await ProfileService.instance.init();
    service.resetForTest();
  });

  tearDown(() {
    ReadingHistoryService.nowFn = DateTime.now;
    service.resetForTest();
  });

  Future<void> open(String book, int chapter, {String version = 'kjv'}) =>
      service.noteChapterOpen(book: book, chapter: chapter, version: version);

  group('the dwell gate', () {
    test('a chapter the reader stayed in is counted', () async {
      await open('John', 3);
      advance(dwelt);
      final snap = await service.load();
      expect(snap.coverage['John'], {3});
      expect(snap.chaptersOpened, 1);
    });

    test('a swipe through six chapters counts none of them', () async {
      // The chapter pager makes Genesis 1-6 in four seconds look like
      // six chapters read. It is not, and a coverage figure built from
      // it would be fiction.
      for (var c = 1; c <= 6; c++) {
        await open('Genesis', c);
        advance(const Duration(milliseconds: 700));
      }
      final snap = await service.load();
      expect(snap.coverage, isEmpty);
      expect(snap.recent, isEmpty);
    });

    test('the chapter landed on after a swipe is counted once it is dwelt in',
        () async {
      for (var c = 1; c <= 5; c++) {
        await open('Genesis', c);
        advance(const Duration(milliseconds: 700));
      }
      advance(dwelt);
      final snap = await service.load();
      expect(snap.coverage['Genesis'], {5});
    });

    test('the reader page re-announcing the same chapter does not restart '
        'its dwell clock', () async {
      // `setCurrentChapter` fires several times during one navigation —
      // the route sync, the pager settling. If each one reset the clock,
      // a chapter could be open for a minute and never qualify.
      await open('Psalms', 23);
      advance(const Duration(seconds: 4));
      await open('Psalms', 23);
      advance(const Duration(seconds: 5));
      final snap = await service.load();
      expect(snap.coverage['Psalms'], {23});
    });
  });

  group('what gets stored', () {
    test('a chapter opened in Chinese is filed under its English name',
        () async {
      // MainProvider.currentBook carries the reading version's own book
      // title. Filing '约翰福音' beside 'John' would report one book as
      // two and put both in the by-book list.
      await open('约翰福音', 1, version: 'cuvs-yhwh');
      advance(dwelt);
      await open('John', 2);
      advance(dwelt);
      final snap = await service.load();
      expect(snap.coverage.keys, ['John']);
      expect(snap.coverage['John'], {1, 2});
      expect(snap.booksTouched, 1);
    });

    test('re-reading a chapter in another version does not count twice',
        () async {
      await open('John', 3, version: 'kjv');
      advance(dwelt);
      await open('Matthew', 1);
      advance(dwelt);
      await open('约翰福音', 3, version: 'cuvs-yhwh');
      advance(dwelt);
      final snap = await service.load();
      expect(snap.coverage['John'], {3});
      expect(snap.chaptersOpened, 2, reason: 'John 3 and Matthew 1');
    });

    test('the recent list is most-recent first and carries the version',
        () async {
      await open('John', 3, version: 'kjv');
      advance(dwelt);
      await open('Romans', 8, version: 'nasb');
      advance(dwelt);
      final snap = await service.load();
      expect([for (final e in snap.recent) '${e.book} ${e.chapter}'],
          ['Romans 8', 'John 3']);
      expect(snap.recent.first.version, 'nasb');
    });

    test('the same chapter is not logged twice for one visit', () async {
      // load() commits the chapter on screen and clears the pending
      // slot; the reader page then re-announces it. Without a guard,
      // leaving the chapter would log it a second time in a row.
      await open('Acts', 2);
      advance(dwelt);
      await service.load();
      await open('Acts', 2);
      advance(dwelt);
      final snap = await service.load();
      expect(snap.recent.length, 1);
    });

    test('the recent list is capped while coverage is kept whole', () async {
      // 205 chapters, past the 200-entry log cap: all of Psalms, then
      // enough of Isaiah to overflow it.
      for (var c = 1; c <= 150; c++) {
        await open('Psalms', c);
        advance(dwelt);
      }
      for (var c = 1; c <= 55; c++) {
        await open('Isaiah', c);
        advance(dwelt);
      }
      final snap = await service.load();
      expect(snap.recent.length, ReadingHistoryService.maxLogEntries);
      expect(snap.recent.first.book, 'Isaiah');
      expect(snap.recent.first.chapter, 55);
      expect(
        snap.chaptersOpened,
        205,
        reason: 'coverage survives the log being trimmed — that is exactly '
            'why the two are stored under separate keys',
      );
    });

    test('the period starts at the first chapter actually recorded', () async {
      final firstOpen = clock;
      await open('John', 3);
      advance(dwelt);
      await open('John', 4);
      advance(dwelt);
      final snap = await service.load();
      expect(snap.since, firstOpen);
    });
  });

  group('surviving bad data', () {
    test('a corrupt store reads as "nothing recorded" rather than throwing',
        () async {
      SharedPreferences.setMockInitialValues({
        ProfileService.instance
            .scopedKey(ReadingHistoryService.coverageBaseKey): 'not json{',
        ProfileService.instance.scopedKey(ReadingHistoryService.logBaseKey):
            '{"not":"a list"}',
      });
      final snap = await service.load();
      expect(snap.coverage, isEmpty);
      expect(snap.recent, isEmpty);
    });

    test('a log entry missing its timestamp is dropped, the rest survive',
        () async {
      SharedPreferences.setMockInitialValues({
        ProfileService.instance.scopedKey(ReadingHistoryService.logBaseKey):
            jsonEncode([
          {'b': 'John', 'c': 3, 'v': 'kjv', 't': 1757000000000},
          {'b': 'John', 'c': 4, 'v': 'kjv'},
          {'b': '', 'c': 5, 'v': 'kjv', 't': 1757000000000},
        ]),
      });
      final snap = await service.load();
      expect(snap.recent.length, 1);
      expect(snap.recent.single.chapter, 3);
    });
  });

  test('clearing removes everything this device recorded', () async {
    await open('John', 3);
    advance(dwelt);
    await service.load();
    await service.clear();
    final snap = await service.load();
    expect(snap.isEmpty, isTrue);
    expect(snap.since, isNull);
  });

  test('the reading record is never uploaded to the cloud', () {
    // A per-device reading log merged newest-wins across devices would
    // either double-count or silently drop days, and the reader can see
    // neither error. `RealtimeDbSyncService` uploads an explicit
    // allowlist of key names; if any of these three ever appears in that
    // file, someone has put the reading record on the wire.
    final syncSource =
        File('lib/services/realtime_db_sync_service.dart').readAsStringSync();
    for (final key in [
      ReadingHistoryService.coverageBaseKey,
      ReadingHistoryService.logBaseKey,
      ReadingHistoryService.sinceBaseKey,
    ]) {
      expect(syncSource.contains("'$key'"), isFalse,
          reason: '$key must stay local to this device');
    }
  });
}
