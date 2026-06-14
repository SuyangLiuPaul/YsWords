/// 2026-06-15 (v1.3.80/81): pure helpers for the reading pane's right-edge
/// progress pill in PARAGRAPH mode.
///
/// Verse-by-verse mode tracks fine with the simple `(verseIndex + 1) / total`
/// formula because each scrollable item is a single verse. Paragraph mode
/// groups many verses into one item, so that formula made BOTH the bar AND
/// the number jump group-to-group (and not move at all while scrolling inside
/// one long paragraph). These interpolate the verse index across the visible
/// group using the within-item scroll fraction, so the bar position reflects
/// the proportion of the chapter remaining and the number reflects the verse
/// you've actually scrolled to.
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
