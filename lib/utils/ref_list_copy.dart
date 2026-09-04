import 'package:yswords/constants/text_patterns.dart';

/// Formats a LIST of single verses drawn from different books for the
/// clipboard — cross-references, search hits, any "here are some verses
/// from all over" panel.
///
/// One `[Book C:V] text` line per row. That is the app's existing
/// `withRef` shape, and it is deliberately NOT routed through
/// `AppSettings.copyFormat`. The three formats that setting offers are
/// all built for ONE passage: `plain` prints a single `Book Chapter`
/// heading and then bare verse numbers beneath it, and `devotional`
/// flows the verses into one paragraph with a single trailing citation.
/// Applied to a list spanning several books, both produce something
/// actively wrong — verse numbers filed under a book they did not come
/// from. `withRef` is the only one of the three whose meaning survives.
///
/// [rawText] is the verse as stored, NOT a display preview: this runs
/// [sanitizeForCopy] itself. That matters and is easy to get wrong,
/// because the on-screen preview beside these rows is built with
/// `sanitizeForSearch` instead. Since v1.2.57 a single verse can
/// contain real `\n` poetry line breaks (the LJK2 OT-quote verses); the
/// reading pane moved its copy path to `sanitizeForCopy` in v1.2.58 so
/// those cannot split one verse across several clipboard lines. A list
/// that is one-verse-per-line by construction has exactly the same
/// problem, and the difference never shows on screen because the
/// preview is clipped to two lines.
///
/// A row whose text is missing or blank still copies its label. The
/// text is usually absent only because that book is not in the loaded
/// verse index, and a bare reference is still worth pasting — dropping
/// the row entirely would silently shorten the list instead.
String formatRefListForCopy(
  Iterable<({String label, String? rawText})> rows,
) {
  final out = <String>[];
  for (final row in rows) {
    final raw = row.rawText;
    final clean = raw == null ? '' : sanitizeForCopy(raw).trim();
    out.add(clean.isEmpty ? '[${row.label}]' : '[${row.label}] $clean');
  }
  return out.join('\n');
}
