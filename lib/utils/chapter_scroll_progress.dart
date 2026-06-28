/// 2026-06-15 (v1.3.80/81/83): pure helpers for the reading pane's right-edge
/// progress pill — used for BOTH paragraph and verse-by-verse mode.
///
/// Paragraph mode groups many verses into one scrollable item; verse-by-verse
/// mode is just the degenerate case of one verse per group. The OLD
/// `(verseIndex + 1) / total` formula stepped by whole items, so the bar jumped
/// group-to-group (and didn't move at all while scrolling inside one long
/// paragraph) and only ticked at item boundaries. These interpolate the verse
/// index across the visible item using the within-item scroll fraction, so the
/// bar position reflects the proportion of the chapter remaining and the number
/// reflects the verse you've actually scrolled to — smoothly, in either mode.
///
/// [itemPos] is the CONTINUOUS visible-item position: the first visible item's
/// index plus the fraction of that item already scrolled past the top of the
/// viewport.
///
/// [itemToVerseIndex] maps an item index → that item's leading verse index.
/// Layout: item 0 is the chapter header (→ verse 0), items `1..groupCount` are
/// the paragraph groups (→ each group's first verse), and item `groupCount + 1`
/// is the footer (absent from the map → treated as the end of the chapter).
library;

/// Continuous 0-based verse index at the current scroll position. Shared core
/// of both public helpers so the bar and the number can never disagree.
double _interpolatedVerse({
  required double itemPos,
  required Map<int, int> itemToVerseIndex,
  required int groupCount,
  required int totalVerses,
}) {
  final maxItem = groupCount + 1;
  final clampedPos = itemPos.clamp(0.0, maxItem.toDouble());
  final itemIndex = clampedPos.floor().clamp(0, maxItem).toInt();
  final frac = (clampedPos - itemIndex).clamp(0.0, 1.0);
  // Leading verse of the visible item, and of the next item. The footer
  // (item index > groupCount) sits past the last group → it maps to the END of
  // the chapter, so the last group interpolates all the way to the bottom and a
  // fully-scrolled chapter reads 100% (not 0).
  final vHere = itemIndex > groupCount
      ? totalVerses.toDouble()
      : (itemToVerseIndex[itemIndex] ?? 0).toDouble();
  final vNext = (itemToVerseIndex[itemIndex + 1] ?? totalVerses).toDouble();
  return vHere + frac * (vNext - vHere);
}

/// 2026-06-28: even, monotonic 0.0–1.0 scroll fraction for the right-edge BAR,
/// decoupled from the verse number. This is `extentBefore / (extentBefore +
/// extentAfter)` measured in VERSE units (NOT item units):
///   • [topPos]    = content position at the viewport TOP (first visible item's
///     index + the fraction of it scrolled past the top).
///   • [bottomPos] = content position at the viewport BOTTOM (last visible
///     item's index + the fraction of it above the viewport bottom; clamps to
///     `index + 1` once the chapter's final item is fully on screen).
///
/// We convert both to a continuous VERSE position via [_interpolatedVerse], then
/// `above = topVerse`, `below = totalVerses − bottomVerse`, progress =
/// above/(above+below).
///
/// Why verse units, not item units (v1.3.108 → v1.3.109 fix): in item units the
/// tiny header + footer spacers each count as a whole item, so the bar lurched
/// FAST past them at the very start and very end (user: "开始和最后都加快"), and
/// tall-vs-short paragraphs moved it unevenly. In verse units the header maps to
/// verse 0 and the footer to the last verse, so those distortions vanish and the
/// bar advances uniformly per verse — while still hitting exactly 0.0 at the top
/// and 1.0 the instant the chapter bottom is reached. The NUMBER still uses
/// [paragraphCurrentVerseIndex] (top-of-screen verse), so e.g. at the bottom the
/// bar is full while the number reads "19/24".
double chapterScrollFraction({
  required double topPos,
  required double bottomPos,
  required Map<int, int> itemToVerseIndex,
  required int groupCount,
  required int totalVerses,
}) {
  if (totalVerses <= 0) return 0.0;
  final topVerse = _interpolatedVerse(
    itemPos: topPos,
    itemToVerseIndex: itemToVerseIndex,
    groupCount: groupCount,
    totalVerses: totalVerses,
  );
  final bottomVerse = _interpolatedVerse(
    itemPos: bottomPos,
    itemToVerseIndex: itemToVerseIndex,
    groupCount: groupCount,
    totalVerses: totalVerses,
  );
  final above = topVerse.clamp(0.0, totalVerses.toDouble());
  final below = (totalVerses - bottomVerse).clamp(0.0, totalVerses.toDouble());
  final denom = above + below;
  if (denom <= 0) return 0.0;
  return (above / denom).clamp(0.0, 1.0).toDouble();
}

/// Clamped 0.0–1.0 scroll progress through the chapter (drives the bar fill +
/// pill position).
double paragraphScrollProgress({
  required double itemPos,
  required Map<int, int> itemToVerseIndex,
  required int groupCount,
  required int totalVerses,
}) {
  if (totalVerses <= 0) return 0.0;
  final interp = _interpolatedVerse(
    itemPos: itemPos,
    itemToVerseIndex: itemToVerseIndex,
    groupCount: groupCount,
    totalVerses: totalVerses,
  );
  return (interp / totalVerses).clamp(0.0, 1.0).toDouble();
}

/// 0-based verse index currently at the reading position — the number shown in
/// the pill. Updates smoothly verse-by-verse as you scroll through a paragraph
/// (instead of freezing on the group's first verse). Add 1 for the 1-based
/// label.
int paragraphCurrentVerseIndex({
  required double itemPos,
  required Map<int, int> itemToVerseIndex,
  required int groupCount,
  required int totalVerses,
}) {
  if (totalVerses <= 0) return 0;
  final interp = _interpolatedVerse(
    itemPos: itemPos,
    itemToVerseIndex: itemToVerseIndex,
    groupCount: groupCount,
    totalVerses: totalVerses,
  );
  return interp.floor().clamp(0, totalVerses - 1).toInt();
}
