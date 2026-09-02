/// Builds the `33–35` / `7, 9` / `34a` half of a citation.
///
/// Extracted from `bible_reading_pane.dart` 2026-09-02, where it was a
/// private static in a 6,000-line widget and therefore unreachable from
/// any test. It got extracted because it had a bug that shipped: see
/// [formatVerseRangeLabels].
library;

import 'package:yswords/models/verse.dart';

/// Collapses consecutive verse numbers: `[3,4,5,7]` → `3–5, 7`.
String formatVerseRange(List<int> nums) {
  if (nums.isEmpty) return '';
  final sorted = [...nums]..sort();
  final parts = <String>[];
  int start = sorted[0];
  int end = start;
  for (int i = 1; i < sorted.length; i++) {
    if (sorted[i] == end + 1) {
      end = sorted[i];
    } else {
      parts.add(start == end ? '$start' : '$start–$end');
      start = sorted[i];
      end = start;
    }
  }
  parts.add(start == end ? '$start' : '$start–$end');
  return parts.join(', ');
}

/// The citation for a selection of verses, sub-verses included.
///
/// Sub-verses are the whole reason this is not just [formatVerseRange].
/// 路加福音 23:34 is carried as two entries — `34a` (「父親啊，赦免他們…」)
/// and `34` (「然後，他們抓鬮分了耶穌的衣袍。」) — because the publisher's
/// own data marks the first half `34a` and leaves the second unlettered.
/// (Checked against the publisher's source, not inferred: `34a` is the
/// only lettered verse number in the entire corpus and there is no `34b`
/// anywhere in it. See `tools/repair_biblexg_luke_23_34a.py`.)
///
/// **The bug this function exists to fix:** selecting the whole of Luke
/// 23:34 in 灵修 copy mode cited it as `路加福音 23:34a, 34`. The reader
/// had selected one verse, all of it, and the app named it twice — it
/// reads like a defect even though the underlying data is right.
///
/// The rule: a verse whose parts are ALL in the selection is cited by
/// its number. A letter survives only when the selection really is a
/// fragment, which is the one case where it tells the reader something
/// they could not otherwise work out.
String formatVerseRangeLabels(List<Verse> verses) {
  if (verses.isEmpty) return '';
  final groups = <int, List<Verse>>{};
  for (final v in verses) {
    (groups[v.verse] ??= <Verse>[]).add(v);
  }
  final whole = <int>[];
  final tokens = <int, String>{};
  for (final e in groups.entries) {
    // More than one part present → the verse is fully covered.
    // A lone part whose label is already the plain number is an
    // ordinary, unsplit verse.
    if (e.value.length > 1 || e.value.first.verseLabel == '${e.key}') {
      whole.add(e.key);
      tokens[e.key] = '${e.key}';
    } else {
      tokens[e.key] = e.value.first.verseLabel;
    }
  }
  // Every verse fully covered → the plain range-collapse applies, so a
  // selection spanning the split verse still reads `33–35`.
  if (whole.length == groups.length) return formatVerseRange(whole);
  final nums = groups.keys.toList()..sort();
  return nums.map((n) => tokens[n]!).join(', ');
}
