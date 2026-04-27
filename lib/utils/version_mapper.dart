import 'package:yswords/constants/book_name_mapping.dart' show zhToEn, toLocale;

String translateBookName(String? book, String version) {
  if (book == null) return '';
  final en = zhToEn(book) ?? book;
  return toLocale(en, version);
}

/// Returns a localized book name driven by [locale] alone — the reading
/// version is intentionally ignored so exegesis panels always match the
/// UI language regardless of which Bible the user has open.
///
/// - `zh-Hant` → Traditional Chinese
/// - `zh-Hans` (or any `zh-*`) → Simplified Chinese
/// - any other locale → English canonical name
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
