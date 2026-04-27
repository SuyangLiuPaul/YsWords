import 'package:yswords/constants/book_name_mapping.dart' show zhToEn, toLocale;

String translateBookName(String? book, String version) {
  if (book == null) return '';
  final en = zhToEn(book) ?? book;
  return toLocale(en, version);
}

/// Returns a book name to display in cross-reference / aggregate
/// panels (Top books chips, "Used N times" ref list, highlights
/// browser, Strong's search results). These are UI/index elements,
/// not verse-specific text, so they follow the UI [locale]:
///
/// - `zh-Hant` → Traditional Chinese
/// - `zh-Hans` (or any `zh-*`) → Simplified Chinese
/// - any other locale → English canonical name
///
/// The [currentVersion] parameter is intentionally unused for display
/// — the verse-specific ref at the top of each verse block already
/// uses `vo.verse.book` (version-driven) so verse text and its label
/// match. Use [translateBookName] directly when you need to look up
/// a verse against `provider.verses[].book` for navigation.
String localeAwareBookName(
    String englishBook, String locale, [String? currentVersion]) {
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
