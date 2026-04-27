import 'package:yswords/constants/book_name_mapping.dart' show zhToEn, toLocale;

String translateBookName(String? book, String version) {
  if (book == null) return '';
  final en = zhToEn(book) ?? book;
  return toLocale(en, version);
}

/// Returns a book name to display in the exegesis / search / highlight
/// panels. The reading version takes priority so book names always
/// match the language of the verse text shown alongside them — reading
/// KJV gives "Genesis", reading CUVS gives "创世记", regardless of UI
/// locale. Falls back to locale-driven naming only when no version is
/// known (e.g. headless contexts).
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
