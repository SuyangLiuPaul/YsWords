import 'package:flutter/material.dart';

import 'package:yswords/constants/bible_versions.dart'
    show bibleVersionFullCanonFallback, bibleVersions, BibleVersionInfo;
import 'package:yswords/models/verse.dart';
import 'package:yswords/providers/main_provider.dart';
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
  mp.setCurrentChapter(book: verse.book, chapter: verse.chapter);
  mp.updateCurrentVerse(verse: verse);
  // Find the verse's index within its (book, chapter) ordering.
  // Sort defensively in case mp.verses isn't strictly ordered.
  final chapterVerses = mp.verses
      .where((v) => v.book == verse.book && v.chapter == verse.chapter)
      .toList()
    ..sort((a, b) => a.verse.compareTo(b.verse));
  final relIdx = chapterVerses.indexWhere((v) => v.verse == verse.verse);
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
