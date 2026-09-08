// 2026-09-08: what the reader has actually read, recorded locally.
//
// YouVersion and 微读圣经 both report the reader's own reading back to
// them; YsWords had nothing to report from. The app knew exactly one
// thing about reading — `lastRead`, a single synced slot naming the
// chapter you were last in — which answers "where do I resume", not
// "what have I covered". `lib/pages/stats_page.dart` looks like it might
// help and does not: it counts Hebrew and Greek vocabulary in the text,
// a fact about the Bible rather than about the reader.
//
// WHAT THIS DOES NOT DO
//
//  • No streak, and nothing that is a streak wearing another name — no
//    "days in a row", no "longest run", no badge. The owner has excluded
//    打卡 from this project, and a consecutive-days number is the thing
//    itself however it is labelled.
//  • No cloud. This is never added to `RealtimeDbSyncService`'s key
//    lists. A per-device reading log merged newest-wins across devices
//    would either double-count or silently drop days, and neither error
//    is visible to the reader who would then be reading a wrong number.
//    Local and correct beats synced and approximate.
//
// HONESTY ABOUT WHAT IS COUNTED
//
// The app can see a chapter being OPENED. It cannot see it being read.
// The gap between those is not small: the chapter pager makes a swipe
// through Genesis 1-6 look like six chapters in four seconds. So a
// chapter is committed only once it has been the current one for at
// least [minDwell]; anything abandoned faster is dropped as navigation
// rather than reading. That still over-counts a chapter left open on a
// desk, and the stats page says "opened", not "read", for exactly that
// reason.
//
// The dwell gate is implemented WITHOUT a timer: [noteChapterOpen] parks
// the new chapter as pending, and the pending one is committed by the
// next call (or by [flush]) only if enough time has passed. A timer
// would have to be cancelled on dispose, would fire during widget tests,
// and would need `fake_async` to test at all; this version needs only an
// injectable clock.
//
// STORAGE, and why it is two keys
//
//  • `readingCoverage` — every chapter ever opened, as `{"John": [1,3]}`.
//    Bounded by the canon at 1,189 numbers, so it can be kept forever and
//    is what the coverage figures are computed from.
//  • `readingHistory` — the recent log, capped at [maxLogEntries], each
//    entry carrying book, chapter, version and epoch ms. This is what
//    "recently read" renders. Capping it is why coverage cannot be
//    derived from it, which is why both exist.
//  • `readingHistorySince` — when recording began. The stats page prints
//    it, because a coverage figure with no period attached reads as a
//    lifetime record and this feature is days old.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/constants/book_names.dart' show bookNameToEnglish;
import 'package:yswords/services/profile_service.dart';

/// One chapter-open, as the recent-activity list renders it.
@immutable
class ReadingHistoryEntry {
  /// Canonical English book name, e.g. `'John'`. Normalised on the way
  /// in: `MainProvider.currentBook` holds the name in the READING
  /// VERSION's language ('约翰福音' on CUVS), and a log that mixed
  /// '约翰福音' with 'John' would count one book as two.
  final String book;
  final int chapter;

  /// The version the chapter was opened in, for display only. Coverage
  /// deliberately ignores it: reading John 3 in NASB and again in CUVS
  /// is one chapter covered, not two.
  final String version;
  final DateTime at;

  const ReadingHistoryEntry({
    required this.book,
    required this.chapter,
    required this.version,
    required this.at,
  });

  Map<String, dynamic> toJson() => {
        'b': book,
        'c': chapter,
        'v': version,
        't': at.millisecondsSinceEpoch,
      };

  static ReadingHistoryEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final book = raw['b'];
    final chapter = raw['c'];
    final at = raw['t'];
    if (book is! String || book.isEmpty) return null;
    if (chapter is! int || chapter < 1) return null;
    if (at is! int) return null;
    return ReadingHistoryEntry(
      book: book,
      chapter: chapter,
      version: raw['v'] is String ? raw['v'] as String : '',
      at: DateTime.fromMillisecondsSinceEpoch(at),
    );
  }
}

/// Everything the stats page needs, read in one pass.
@immutable
class ReadingHistorySnapshot {
  /// Chapters opened, per canonical English book name.
  final Map<String, Set<int>> coverage;

  /// Recent chapter-opens, most recent first, at most
  /// [ReadingHistoryService.maxLogEntries] of them.
  final List<ReadingHistoryEntry> recent;

  /// When this profile's recording began. Null when nothing has ever
  /// been recorded — the page shows its empty state rather than a zero.
  final DateTime? since;

  const ReadingHistorySnapshot({
    required this.coverage,
    required this.recent,
    required this.since,
  });

  static const ReadingHistorySnapshot empty = ReadingHistorySnapshot(
      coverage: <String, Set<int>>{}, recent: [], since: null);

  bool get isEmpty => coverage.isEmpty && recent.isEmpty;

  /// Distinct chapters opened across the whole canon.
  int get chaptersOpened {
    var n = 0;
    for (final chs in coverage.values) {
      n += chs.length;
    }
    return n;
  }

  /// Books with at least one chapter opened.
  int get booksTouched => coverage.values.where((c) => c.isNotEmpty).length;
}

class ReadingHistoryService {
  ReadingHistoryService._();
  static final ReadingHistoryService instance = ReadingHistoryService._();

  static const String coverageBaseKey = 'readingCoverage';
  static const String logBaseKey = 'readingHistory';
  static const String sinceBaseKey = 'readingHistorySince';

  /// How long a chapter must stay current before it counts. Eight
  /// seconds is long enough that a pager swipe on the way somewhere else
  /// does not register, and short enough that genuinely glancing at a
  /// cross-reference does. It is a judgement call, not a measurement,
  /// which is the other reason the page says "opened" rather than "read".
  static const Duration minDwell = Duration(seconds: 8);

  /// The recent-activity list is a list, not an archive. Two hundred
  /// entries is far more than anyone scrolls and keeps the blob under a
  /// few tens of kilobytes.
  static const int maxLogEntries = 200;

  /// Test seam for the clock. Never set outside tests.
  @visibleForTesting
  static DateTime Function() nowFn = DateTime.now;

  ({String book, int chapter, String version, DateTime at})? _pending;

  /// The last (book, chapter) written to the log. Guards the one way a
  /// duplicate row can appear: [flush] commits the chapter on screen and
  /// clears the pending slot, the reader page then re-announces that
  /// same chapter, and navigating away would log it a second time.
  /// Coverage is a set and never noticed; the recent list would have
  /// shown the same chapter twice in a row.
  String? _lastCommitted;

  /// Record that [book] chapter [chapter] became the current chapter.
  ///
  /// Cheap and synchronous in the common case: repeat calls naming the
  /// chapter already pending (the reader page emits several during one
  /// navigation) do nothing at all. Safe to call from
  /// `MainProvider.setCurrentChapter` on every emission.
  Future<void> noteChapterOpen({
    required String book,
    required int chapter,
    required String version,
  }) async {
    final english = bookNameToEnglish[book] ?? book;
    if (english.isEmpty || chapter < 1) return;
    final pending = _pending;
    if (pending != null &&
        pending.book == english &&
        pending.chapter == chapter) {
      // Same chapter, re-announced. Keep the ORIGINAL timestamp so the
      // dwell clock measures how long the reader has been here, not how
      // long since the last redundant announcement.
      return;
    }
    _pending = (
      book: english,
      chapter: chapter,
      version: version,
      at: nowFn(),
    );
    if (pending == null) return;
    await _commit(pending);
  }

  /// Commit anything that has dwelled long enough. Called before a read
  /// so the chapter currently on screen is included in its own figures.
  Future<void> flush() async {
    final pending = _pending;
    if (pending == null) return;
    if (await _commit(pending)) _pending = null;
  }

  /// Returns true when [pending] met the dwell bar and was written.
  Future<bool> _commit(
      ({String book, int chapter, String version, DateTime at}) pending) async {
    final now = nowFn();
    if (now.difference(pending.at) < minDwell) return false;
    final signature = '${pending.book}|${pending.chapter}';
    if (signature == _lastCommitted) return true;
    _lastCommitted = signature;
    try {
      final prefs = await SharedPreferences.getInstance();
      final coverage = _readCoverage(prefs);
      (coverage[pending.book] ??= <int>{}).add(pending.chapter);
      await prefs.setString(
        ProfileService.instance.scopedKey(coverageBaseKey),
        jsonEncode({
          for (final e in coverage.entries)
            if (e.value.isNotEmpty) e.key: (e.value.toList()..sort()),
        }),
      );

      final log = _readLog(prefs);
      log.insert(
        0,
        ReadingHistoryEntry(
          book: pending.book,
          chapter: pending.chapter,
          version: pending.version,
          at: pending.at,
        ),
      );
      if (log.length > maxLogEntries) log.removeRange(maxLogEntries, log.length);
      await prefs.setString(
        ProfileService.instance.scopedKey(logBaseKey),
        jsonEncode([for (final e in log) e.toJson()]),
      );

      final sinceKey = ProfileService.instance.scopedKey(sinceBaseKey);
      if (prefs.getInt(sinceKey) == null) {
        // Stamped with the chapter's own open time, not `now`, so the
        // "records since" line names the first thing actually recorded.
        await prefs.setInt(sinceKey, pending.at.millisecondsSinceEpoch);
      }
      return true;
    } catch (e) {
      debugPrint('[reading-history] commit failed: $e');
      // Report it as written anyway: retrying a failed prefs write on
      // every subsequent navigation would turn one bad write into a
      // permanent one.
      return true;
    }
  }

  /// Read everything the stats page needs. Flushes first so the chapter
  /// the reader just came from is counted.
  Future<ReadingHistorySnapshot> load() async {
    await flush();
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms =
          prefs.getInt(ProfileService.instance.scopedKey(sinceBaseKey));
      return ReadingHistorySnapshot(
        coverage: _readCoverage(prefs),
        recent: _readLog(prefs),
        since: ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms),
      );
    } catch (e) {
      debugPrint('[reading-history] load failed: $e');
      return ReadingHistorySnapshot.empty;
    }
  }

  /// Erase this profile's reading record. Offered on the stats page:
  /// data the app keeps about a person is data that person may delete.
  Future<void> clear() async {
    _pending = null;
    _lastCommitted = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs
          .remove(ProfileService.instance.scopedKey(coverageBaseKey));
      await prefs.remove(ProfileService.instance.scopedKey(logBaseKey));
      await prefs.remove(ProfileService.instance.scopedKey(sinceBaseKey));
    } catch (e) {
      debugPrint('[reading-history] clear failed: $e');
    }
  }

  /// Drop in-memory state. Tests only — the singleton outlives each
  /// case otherwise and a pending chapter leaks between them.
  @visibleForTesting
  void resetForTest() {
    _pending = null;
    _lastCommitted = null;
  }

  Map<String, Set<int>> _readCoverage(SharedPreferences prefs) {
    final raw =
        prefs.getString(ProfileService.instance.scopedKey(coverageBaseKey));
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final out = <String, Set<int>>{};
      for (final e in decoded.entries) {
        final chs = e.value;
        if (chs is! List) continue;
        final set = <int>{for (final c in chs) if (c is int && c >= 1) c};
        if (set.isNotEmpty) out[e.key.toString()] = set;
      }
      return out;
    } catch (_) {
      // A corrupt blob reads as "nothing recorded yet" rather than
      // throwing on the reader's stats page. The next commit rewrites it.
      return {};
    }
  }

  List<ReadingHistoryEntry> _readLog(SharedPreferences prefs) {
    final raw = prefs.getString(ProfileService.instance.scopedKey(logBaseKey));
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return [
        for (final r in decoded)
          if (ReadingHistoryEntry.fromJson(r) case final e?) e,
      ];
    } catch (_) {
      return [];
    }
  }
}
