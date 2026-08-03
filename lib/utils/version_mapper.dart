import 'package:yswords/constants/book_name_mapping.dart' show zhToEn, toLocale;
import 'package:yswords/utils/reference_parser.dart' show BibleReference, parseReference;

String translateBookName(String? book, String version) {
  if (book == null) return '';
  final en = zhToEn(book) ?? book;
  return toLocale(en, version);
}

/// Returns the book name to display in cross-reference / aggregate
/// panels (Top books chips, "Used N times" refs, highlight browser,
/// Strong's search results). Driven by the reading [currentVersion]
/// so book names match the verse text the user is reading — KJV /
/// NASB / NIV / LEB → "Genesis"; CUVS / CNV / CUV → "创世记"; the
/// `-tr` variants → "創世記".
///
/// The English-version detection (kjv/leb/nasb/niv) lives in
/// `book_name_mapping.dart`'s `toLocale`; English versions not on
/// that list will be misclassified as Chinese — add new ones there.
///
/// Falls back to locale-driven naming when no version is provided.
String localeAwareBookName(
    String englishBook, String locale, [String? currentVersion]) {
  if (currentVersion != null && currentVersion.isNotEmpty) {
    return translateBookName(englishBook, currentVersion);
  }
  if (locale == 'zh-Hant') {
    return toLocale(englishBook, 'cuvs-tr');
  } else if (locale.startsWith('zh')) {
    return toLocale(englishBook, 'cuvs-yhwh');
  }
  return englishBook;
}

/// Formats a single parsed [BibleReference] as `book chapter[:verse]`
/// with the book name localized via [localeAwareBookName]. Mirrors
/// `BibleReference.toString()`'s chapter/verse suffix logic (including
/// the compact non-contiguous-verses form) but swaps in the
/// locale-aware book name instead of the always-English one.
String _localizedRefPart(
    BibleReference ref, String locale, String? currentVersion) {
  final book = localeAwareBookName(ref.englishBook, locale, currentVersion);
  if (ref.verses.isNotEmpty) {
    final parts = <String>[];
    int start = ref.verses.first;
    int end = start;
    for (var i = 1; i < ref.verses.length; i++) {
      final v = ref.verses[i];
      if (v == end + 1) {
        end = v;
      } else {
        parts.add(start == end ? '$start' : '$start-$end');
        start = v;
        end = v;
      }
    }
    parts.add(start == end ? '$start' : '$start-$end');
    return '$book ${ref.chapter}:${parts.join(',')}';
  }
  final v = ref.verseStart == null
      ? ''
      : (ref.verseEnd != null && ref.verseEnd! > ref.verseStart!
          ? ':${ref.verseStart}-${ref.verseEnd}'
          : ':${ref.verseStart}');
  return '$book ${ref.chapter}$v';
}

/// Locale-aware display label for a raw scripture-reference string
/// (e.g. from `BibleEvidence.scriptureReference`, always stored in
/// English — "2 Samuel 5:9"). Parses the reference and re-renders its
/// book name via [localeAwareBookName], so Bible Evidence cards show
/// "撒母耳记下 5:9" in Chinese locales instead of the raw English
/// string every other reference-display surface in the app already
/// localizes (`VersePopupSheet._refLabel`, notes, highlights, search).
///
/// Handles `;`-separated multi-book references (e.g. "Matthew 5:3-12;
/// Luke 6:20-23") by localizing each segment independently. Segments
/// that fail to parse (e.g. "Multiple Books") are passed through
/// unchanged rather than dropped, so the label never loses content.
String localizedReferenceLabel(
    String raw, String locale, [String? currentVersion]) {
  final segments = raw.contains(';') ? raw.split(';') : [raw];
  return segments.map((segment) {
    final trimmed = segment.trim();
    final ref = parseReference(trimmed);
    if (ref == null) return trimmed;
    return _localizedRefPart(ref, locale, currentVersion);
  }).join('; ');
}

String? toEnglish(String? book) {
  if (book == null || book.isEmpty) return null;

  final mapped = zhToEn(book);
  if (mapped != null) return mapped;

  return book;
}
