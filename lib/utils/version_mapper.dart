import 'package:yswords/constants/book_name_mapping.dart' show zhToEn, toLocale;

String translateBookName(String? book, String version) {
  if (book == null) return '';
  final en = zhToEn(book) ?? book;
  return toLocale(en, version);
}

/// Returns a book name driven by the UI [locale] only — the reading
/// Bible version is intentionally ignored. Used everywhere a Bible
/// reference book name appears in the exegesis / search / highlight
/// panels (Top books chips, "Used N times" refs, highlight browser,
/// Strong's search results).
///
/// - `zh-Hant` → Traditional Chinese
/// - `zh-Hans` (or any `zh-*`) → Simplified Chinese
/// - any other locale → English canonical name
///
/// The [currentVersion] parameter is kept in the signature for
/// existing call sites but is intentionally unused — per the user's
/// requirement, book names follow the system language, not the Bible
/// version. Use [translateBookName] directly when you need to match
/// the version's verse-data book naming for navigation lookups.
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
