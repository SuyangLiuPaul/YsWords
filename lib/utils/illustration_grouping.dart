import 'package:yswords/models/bible_map.dart';

/// Span threshold for the browse-all catalogue grouping: an
/// illustration tagged to this many books or fewer is listed under
/// EVERY one of them (a "Paul leaves Ephesus" scene tagged
/// Acts+Ephesians genuinely belongs to both); one tagged to more is a
/// wide survey map and is listed under its FIRST canonical book only,
/// which is what kills the duplicate-spam (survey maps span up to 38
/// books and used to repeat group after group).
const int kIllustrationSpanThreshold = 4;

/// Build the [book → illustrations] map for the browse-all catalogue,
/// preserving the canonical order of [order].
///
/// 2026-07-07: replaces the v1.3.118 primary-book-only rule, which
/// silently EMPTIED 13 NT books (Romans, Ephesians, Philemon, …) —
/// every illustration touching them also touched an earlier book, so
/// the whole group vanished from browse and search. Three tiers:
///
///   1. span ≤ [kIllustrationSpanThreshold] → listed under every
///      tagged book (small spans are genuinely about each book);
///   2. span > threshold → listed under the first canonical book only
///      (wide survey maps, the original duplicate-spam source);
///   3. any book left EMPTY that is referenced by at least one
///      illustration gets all its referencing illustrations back —
///      a few extra survey-map tiles beat an invisible book.
///
/// Guarantee: every book referenced by any illustration has a
/// non-empty group (regression-tested against the real bundled index
/// in test/illustration_grouping_test.dart).
Map<String, List<BibleMap>> groupIllustrationsByBook(
  List<BibleMap> all,
  List<String> order,
) {
  final groups = <String, List<BibleMap>>{
    for (final b in order) b: <BibleMap>[],
  };
  for (final m in all) {
    final books = [
      for (final b in order)
        if (m.books.containsKey(b)) b,
    ];
    if (books.isEmpty) continue;
    if (books.length <= kIllustrationSpanThreshold) {
      for (final b in books) {
        groups[b]!.add(m);
      }
    } else {
      groups[books.first]!.add(m);
    }
  }
  for (final b in order) {
    if (groups[b]!.isNotEmpty) continue;
    for (final m in all) {
      if (m.books.containsKey(b)) groups[b]!.add(m);
    }
  }
  return groups;
}
