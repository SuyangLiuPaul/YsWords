import 'package:yswords/constants/book_name_mapping.dart' show zhToEn, toLocale;

String translateBookName(String? book, String version) {
  if (book == null) return '';
  final en = zhToEn(book) ?? book;
  return toLocale(en, version);
}

/// Returns a localized book name driven by [locale], not by the reading
/// version. This ensures Chinese-UI users see Chinese book names even when
/// they are reading an English version like KJV.
///
/// - `zh-Hant` → Traditional Chinese (any `-tr` version mapping)
/// - `zh-Hans` (or any `zh-*`) → Simplified Chinese
/// - otherwise → falls back to [translateBookName] with [currentVersion]
String localeAwareBookName(
    String englishBook, String locale, String? currentVersion) {
  if (locale == 'zh-Hant') {
    return toLocale(englishBook, 'cuvs-tr');
  } else if (locale.startsWith('zh')) {
    return toLocale(englishBook, 'cuvs-yhwh');
  }
  final v = currentVersion;
  if (v == null) return englishBook;
  return translateBookName(englishBook, v);
}

String? toEnglish(String? book) {
  if (book == null || book.isEmpty) return null;

  final mapped = zhToEn(book);
  if (mapped != null) return mapped;

  return book;
}
