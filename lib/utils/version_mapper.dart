import 'package:yswords/constants/book_name_mapping.dart' show zhToEn, toLocale;

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

String? toEnglish(String? book) {
  if (book == null || book.isEmpty) return null;

  final mapped = zhToEn(book);
  if (mapped != null) return mapped;

  return book;
}
