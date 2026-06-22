import 'dart:async';

import 'package:flutter/material.dart';

import 'package:yswords/constants/bible_versions.dart'
    show bibleVersionFullCanonFallback, bibleVersions, BibleVersionInfo;
import 'package:yswords/models/verse.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/fetch_books.dart' show bookNameToEnglish;
import 'package:yswords/services/fetch_verses.dart';
import 'package:yswords/utils/reference_parser.dart';
import 'package:yswords/utils/version_mapper.dart' show translateBookName;

/// Result of a [resolveAndPrepareJump] call. Carries everything the
/// caller needs to navigate (or knows enough to abort + tell the user
/// why) without re-doing the lookup.
class JumpResolution {
  /// True when we found the verse and prepared `MainProvider` (set
  /// current chapter/verse, set pendingJump). Caller should now
  /// `Get.to(HomePage)` or equivalent.
  final bool ready;

  /// True when [resolveAndPrepareJump] switched the user's reading
  /// version to a full-canon fallback to find the verse. UI can
  /// surface this as "switched to {label}" so the user isn't
  /// surprised when the reader header changes.
  final bool switchedVersion;

  /// Human-readable label of the version we switched to (null when
  /// no switch happened).
  final String? switchedToLabel;

  /// Reason we couldn't navigate, suitable for a SnackBar. Null when
  /// [ready] is true.
  final String? errorMessage;

  const JumpResolution._({
    required this.ready,
    this.switchedVersion = false,
    this.switchedToLabel,
    this.errorMessage,
  });
}

/// Look up [reference] in [mp]'s current Bible version. If the book
/// isn't there (most often: user is on an NT-only translation like
/// LJK1/LJK2 and the reference is OT), transparently switch to the
/// full-canon companion (CUVS-YHWH for Simplified, CUVS-YHWH-TR for
/// Traditional, ESV for English), reload, and retry.
///
/// Why this exists: every cross-link surface (Bible Evidence detail,
/// News article body, Library "Go to verse", Dashboard daily-verse
/// card) used to silently `return` when the verse wasn't in the
/// current version. The link looked dead. This helper centralises
/// the fallback so all four surfaces behave consistently.
///
/// Side effects on success:
///   - calls `mp.setCurrentChapter(...)`
///   - calls `mp.updateCurrentVerse(...)`
///   - calls `mp.setPendingJump(chapterVerseIndex: ...)` so
///     `bible_reading_pane.dart` scrolls + highlights once it's ready
///   - may call `mp.setVersion(...)` + `FetchVerses.execute(...)` if
///     fallback fired
///
/// Caller is responsible for the actual `Get.to(HomePage)` navigation
/// after this returns `ready: true`.
Future<JumpResolution> resolveAndPrepareJump({
  required BibleReference reference,
  required MainProvider mp,
}) async {
  List<Verse> findMatches() {
    final localBook = translateBookName(reference.englishBook, mp.currentVersion);
    return mp.verses
        .where((v) => v.book == localBook && v.chapter == reference.chapter)
        .toList()
      ..sort((a, b) => a.verse.compareTo(b.verse));
  }

  var matches = findMatches();
  bool switched = false;
  String? switchedLabel;

  // If the current version's verses haven't been loaded yet (e.g.
  // user navigated straight from dashboard → timeline → ref tap
  // before the bootstrap FetchVerses settled), force-load now
  // before declaring failure.
  if (matches.isEmpty && mp.verses.isEmpty) {
    await FetchVerses.execute(mainProvider: mp);
    matches = findMatches();
  }

  if (matches.isEmpty) {
    final fallback = bibleVersionFullCanonFallback(mp.currentVersion);
    if (fallback != null && fallback != mp.currentVersion) {
      mp.setVersion(fallback);
      await FetchVerses.execute(mainProvider: mp);
      matches = findMatches();
      if (matches.isNotEmpty) {
        switched = true;
        final info = bibleVersions.firstWhere(
          (v) => v.value == fallback,
          orElse: () => BibleVersionInfo(
            value: fallback,
            shortLabel: fallback,
            menuLabel: fallback,
            language: 'zh-Hans',
          ),
        );
        switchedLabel = info.menuLabel;
      }
    }
  }

  if (matches.isEmpty) {
    return JumpResolution._(
      ready: false,
      errorMessage: "Couldn't find ${reference.toString()} in any "
          'available Bible version.',
    );
  }

  final target = reference.verseStart ?? matches.first.verse;
  final hit = matches.firstWhere(
    (v) => v.verse == target,
    orElse: () => matches.first,
  );
  final relIdx = matches.indexWhere((v) => v.verse == hit.verse);
  mp.setCurrentChapter(book: hit.book, chapter: hit.chapter);
  mp.updateCurrentVerse(verse: hit);
  if (relIdx >= 0) {
    mp.setPendingJump(chapterVerseIndex: relIdx);
  }

  return JumpResolution._(
    ready: true,
    switchedVersion: switched,
    switchedToLabel: switchedLabel,
  );
}

/// Capture the topmost-visible verse NUMBER (1-based) for [mp]'s
/// current chapter. Returns null when no positions are tracked yet
/// (cold mount race), or when the topmost item is the chapter
/// header (returns 1 for "user is at the top of chapter").
///
/// Used by version-switch and split-view-open paths to preserve
/// scroll position across BibleReadingPane re-mounts.
int? captureCurrentVerseNum(MainProvider mp) {
  try {
    final positions = mp.itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return null;
    final visible = positions
        .where((p) => p.itemTrailingEdge > 0 && p.itemLeadingEdge < 1)
        .toList()
      ..sort((a, b) => a.itemLeadingEdge.compareTo(b.itemLeadingEdge));
    if (visible.isEmpty) return null;
    final itemIdx = visible.first.index;
    if (itemIdx == 0) return 1; // chapter header → "at the top"
    final book = mp.currentBook;
    final chapter = mp.currentChapter;
    if (book == null || chapter == null) return null;
    final verses = mp.verses
        .where((v) => v.book == book && v.chapter == chapter)
        .toList()
      ..sort((a, b) => a.verse.compareTo(b.verse));
    if (verses.isEmpty) return null;
    final relIdx = (itemIdx - 1).clamp(0, verses.length - 1);
    return verses[relIdx].verse;
  } catch (_) {
    return null;
  }
}

/// Schedule a robust scroll on [mp]'s reader to verse number
/// [verseNum] within the currently-loaded chapter. No-op when
/// [verseNum] doesn't exist (cross-version numbering edge cases).
///
/// Round 56 update: wraps the call in a `Timer.periodic(16ms)` loop
/// for up to ~1.5s. The previous one-shot post-frame callback fired
/// before the SPL had its controller attached + items measured (most
/// common after a version-switch — `setVerses` triggers a remount
/// of the verse list, and the controller takes 1-3 frames to attach
/// AND measure). Per-frame retry guarantees the jump lands as soon
/// as the SPL is ready, regardless of how long the rebuild takes.
void scrollToVerseNumInChapter(MainProvider mp, int verseNum) {
  final book = mp.currentBook;
  final chapter = mp.currentChapter;
  if (book == null || chapter == null) return;
  final verses = mp.verses
      .where((v) => v.book == book && v.chapter == chapter)
      .toList()
    ..sort((a, b) => a.verse.compareTo(b.verse));
  if (verses.isEmpty) return;
  var relIdx = verses.indexWhere((v) => v.verse == verseNum);
  if (relIdx < 0) {
    // Verse number doesn't exist — closest greater-than-or-equal.
    relIdx = verses.indexWhere((v) => v.verse >= verseNum);
    if (relIdx < 0) return;
  }
  // Per-frame retry. Stop as soon as a jumpTo lands successfully OR
  // ~1.5 s have elapsed (94 ticks × 16 ms).
  //
  // 2026-05-07 (v18 audit): also bail if the reader's loaded chapter
  // changes while we're still retrying. Without this guard, the
  // timer kept ticking for the full 1.5 s even after the user
  // navigated away, wasting frames and producing swallowed
  // exceptions when `jumpToIndex` ran against a stale controller.
  var attempts = 0;
  var settled = 0;
  Timer.periodic(const Duration(milliseconds: 16), (timer) {
    attempts++;
    if (attempts > 94) {
      timer.cancel();
      return;
    }
    // User moved to a different chapter (or cleared verses) — the
    // index we computed is no longer valid. Stop retrying.
    if (mp.currentBook != book ||
        mp.currentChapter != chapter ||
        mp.verses.isEmpty) {
      timer.cancel();
      return;
    }
    if (!mp.itemScrollController.isAttached) return;
    try {
      mp.jumpToIndex(index: relIdx);
      // Once we've successfully fired 3 jumps in a row, declare
      // settled and stop. Multiple jumps cover the case where the
      // SPL is mid-build: the first jumpTo might no-op silently,
      // the next frame succeeds, the one after locks it in.
      settled++;
      if (settled >= 3) {
        timer.cancel();
      }
    } catch (_) {
      settled = 0;
    }
  });
}

/// Set up [mp] to scroll to a specific [verse] when the reader pane
/// next builds with both a populated `verseToItemMap` and an attached
/// `itemScrollController`. Use this whenever you have a concrete
/// `Verse` object (highlights, bookmarks, notes, search results) —
/// it's the modern handshake-based equivalent of the old
/// `Future.delayed(300ms) → jumpToIndex` pattern.
///
/// Why this exists: the previous pattern would silently miss the
/// scroll on cold-start, after a version switch, or on slow devices
/// (the 300 ms wasn't always enough for the `ScrollablePositionedList`
/// controller to attach), and the user would land at the top of the
/// chapter. The pendingJump handshake (drained by
/// `bible_reading_pane.dart`'s post-frame consumer) waits for the
/// controller and the verse map to both be ready, so the scroll
/// always fires correctly.
void prepareJumpToVerse(Verse verse, MainProvider mp) {
  debugPrint('[YsWords prepareJumpToVerse] verse=${verse.book} '
      '${verse.chapter}:${verse.verse} '
      'currentVersion=${mp.currentVersion} '
      'mp.verses.length=${mp.verses.length}');
  // Round 56 fix: don't use `verse.book` directly. The verse may
  // have been captured against a Bible version whose book-name
  // language differs from what the user is currently reading
  // (e.g. note saved while on KJV with `book == "Genesis"`, but
  // user is now on cuvs-yhwh where the same book is `"创世纪"`).
  // The previous code used the raw English book name which had
  // zero matches in the loaded `mp.verses`, so `relIdx == -1` and
  // no pending jump fired — the reader just opened at the top of
  // whatever chapter was current. Fix: translate the verse's book
  // through `bookNameToEnglish → currentVersion`'s book name so
  // we land on the right verse regardless of which version the
  // annotation came from.
  final englishBook = bookNameToEnglish[verse.book] ?? verse.book;
  final localBook = translateBookName(englishBook, mp.currentVersion);
  // Try the localized book name first (current-version match),
  // fall back to the raw verse.book for older annotations made on
  // the same version, fall back finally to English.
  final candidates = <String>{
    localBook,
    verse.book,
    englishBook,
  };
  String? matchedBook;
  for (final book in candidates) {
    if (mp.verses.any((v) => v.book == book && v.chapter == verse.chapter)) {
      matchedBook = book;
      break;
    }
  }
  if (matchedBook == null) {
    debugPrint('[YsWords prepareJumpToVerse] BAIL: no matching book '
        'in mp.verses for ${verse.book} (candidates=$candidates)');
    // Couldn't find a matching book in the loaded version. Bail —
    // setting an invalid currentBook would leave the reader on a
    // broken state. Caller will see the unchanged scroll position
    // which is preferable to landing on an empty chapter.
    return;
  }
  debugPrint('[YsWords prepareJumpToVerse] matchedBook=$matchedBook');
  mp.setCurrentChapter(book: matchedBook, chapter: verse.chapter);
  // Find the canonical Verse in the loaded version that
  // corresponds to the same chapter:verse. updateCurrentVerse
  // wants a Verse from `mp.verses` so highlights line up; falling
  // back to the original `verse` would cause a mismatch on the
  // reader's selection state.
  Verse current = verse;
  final chapterVerses = mp.verses
      .where((v) => v.book == matchedBook && v.chapter == verse.chapter)
      .toList()
    ..sort((a, b) => a.verse.compareTo(b.verse));
  final hit = chapterVerses.where((v) => v.verse == verse.verse).toList();
  if (hit.isNotEmpty) current = hit.first;
  mp.updateCurrentVerse(verse: current);
  final relIdx = chapterVerses.indexWhere((v) => v.verse == verse.verse);
  debugPrint('[YsWords prepareJumpToVerse] '
      'relIdx=$relIdx chapterVerses.length=${chapterVerses.length}');
  if (relIdx >= 0) {
    mp.setPendingJump(chapterVerseIndex: relIdx);
  }
}

/// Convenience wrapper that surfaces the result of
/// [resolveAndPrepareJump] as a SnackBar via the messenger looked up
/// from [context]. Returns true if the caller should proceed with
/// navigation, false if they should abort.
Future<bool> showJumpResultSnackBar(
  BuildContext context,
  JumpResolution result,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (!result.ready) {
    if (result.errorMessage != null) {
      messenger?.showSnackBar(SnackBar(
        content: Text(result.errorMessage!),
        duration: const Duration(seconds: 3),
      ));
    }
    return false;
  }
  if (result.switchedVersion && result.switchedToLabel != null) {
    messenger?.showSnackBar(SnackBar(
      content: Text('Switched to ${result.switchedToLabel} for this verse.'),
      duration: const Duration(seconds: 3),
    ));
  }
  return true;
}
