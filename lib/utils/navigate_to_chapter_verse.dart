/// One place that answers "put the reader at book/chapter[:verse]".
///
/// 2026-08-07. BooksPage and the desktop sidebar each carried their own
/// copy of this sequence, and both had the same latent bug: the picker
/// set a pending jump BEFORE the chapter changed, so the reading pane
/// resolved the verse index against the chapter it was still showing.
/// Picking 创世纪 31 while reading 创世纪 28 left the reader on 28's text
/// under a header that said 31.
///
/// Ordering is the whole point of this function, so it is stated once:
/// commit the chapter, THEN resolve the verse against that chapter's
/// verse list, THEN queue the scroll. `setPendingJump` notifies
/// synchronously (round 52, on purpose), so anything queued before the
/// chapter is committed is resolved against the old chapter.
library;

import 'package:yswords/providers/main_provider.dart';

/// The verses of one chapter in verse order. Exposed for tests — the
/// index a jump uses is a position in THIS list, not a verse number, and
/// the two differ wherever a translation omits a verse.
List<dynamic> chapterVersesOf(
  MainProvider provider, {
  required String book,
  required int chapter,
}) =>
    provider.verses
        .where((v) => v.book == book && v.chapter == chapter)
        .toList()
      ..sort((a, b) => a.verse.compareTo(b.verse));

/// Returns the index of [verse] within [chapterVerses], or null when the
/// chapter does not contain it. Null means "no specific target" — the
/// caller should land at the top of the chapter rather than guess.
int? verseIndexIn(List<dynamic> chapterVerses, int? verse) {
  if (verse == null) return null;
  final i = chapterVerses.indexWhere((v) => v.verse == verse);
  return i >= 0 ? i : null;
}

/// Navigate [provider] to `book chapter`, optionally scrolling to
/// [verse]. Returns false when the chapter has no verses in the current
/// translation (partial-canon editions), leaving the reader where it was
/// rather than blanking the pane.
bool navigateToChapterVerse(
  MainProvider provider, {
  required String book,
  required int chapter,
  int? verse,
}) {
  final chapterVerses = chapterVersesOf(provider, book: book, chapter: chapter);
  if (chapterVerses.isEmpty) return false;

  // 1. Commit the chapter first. Everything below is resolved against it.
  provider.setCurrentChapter(book: book, chapter: chapter);

  final index = verseIndexIn(chapterVerses, verse);

  // 2. Point currentVerse at the real target so the header, the URL and
  //    any "continue reading" state agree with what gets scrolled to.
  provider.updateCurrentVerse(
      verse: index == null ? chapterVerses.first : chapterVerses[index]);

  // 3. Queue the scroll last. Index 0 is a legitimate target (verse 1 of
  //    a chapter), so this branches on null, not on truthiness.
  if (index == null) {
    provider.jumpToTop();
  } else {
    provider.setPendingJump(chapterVerseIndex: index);
  }
  return true;
}
