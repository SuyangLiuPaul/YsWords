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
///
/// **Only the book name is rewritten; the cited chapter/verse text is
/// kept verbatim.** Re-rendering from the parsed [BibleReference] used
/// to print a NARROWER citation than the source gave, because
/// [parseReference] deliberately reduces a reference to a single
/// navigable target: it stops at the first comma and keeps only the
/// opening chapter of a range. Measured over `assets/bible_evidence.json`
/// that silently restated 20 of 225 entries — `2 Kings 19-20` appeared
/// as 「列王纪下 19」, `Acts 27:27-28:1` as 「使徒行传 27:27」,
/// `Daniel 2, 7, 8, 11` as 「但以理书 2」 and `Jude 14-15` as
/// 「犹大书 1:14」. Narrowing where to JUMP is right; narrowing what the
/// card SAYS is a misstated reference, and a reference is the one thing
/// on that card a reader will copy out.
String localizedReferenceLabel(
    String raw, String locale, [String? currentVersion]) {
  final segments = raw.contains(';') ? raw.split(';') : [raw];
  return segments.map((segment) {
    final trimmed = segment.trim();
    final inPlace = _localizeBookInPlace(trimmed, locale, currentVersion);
    if (inPlace != null) return inPlace;
    final ref = parseReference(trimmed);
    if (ref == null) return trimmed;
    return _localizedRefPart(ref, locale, currentVersion);
  }).join('; ');
}

/// Swap [segment]'s leading book name for its localized form and leave
/// everything after it untouched, or null when the split cannot be
/// established with confidence (the caller then falls back to the
/// re-rendering path).
///
/// The split point is the first digit that has a non-empty book name in
/// front of it — which is why a leading digit is skipped rather than
/// treated as the chapter: `1 Corinthians 13` splits at the `13`, not at
/// the `1`. It is only accepted once the prefix ALONE resolves to the
/// same book as the whole segment, so a stray number cannot silently
/// re-attribute a verse to another book.
String? _localizeBookInPlace(
    String segment, String locale, String? currentVersion) {
  for (var i = 0; i < segment.length; i++) {
    final c = segment.codeUnitAt(i);
    if (c < 0x30 || c > 0x39) continue;
    final prefix = segment.substring(0, i).trim();
    if (prefix.isEmpty) continue;
    final rest = segment.substring(i).trim();
    if (rest.isEmpty) return null;
    final whole = parseReference(segment);
    if (whole == null) return null;
    final byPrefix = parseReference('$prefix 1');
    if (byPrefix == null || byPrefix.englishBook != whole.englishBook) {
      continue;
    }
    return '${localeAwareBookName(whole.englishBook, locale, currentVersion)}'
        ' $rest';
  }
  return null;
}

String? toEnglish(String? book) {
  if (book == null || book.isEmpty) return null;

  final mapped = zhToEn(book);
  if (mapped != null) return mapped;

  return book;
}
