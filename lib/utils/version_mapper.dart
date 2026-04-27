import 'package:yswords/constants/book_name_mapping.dart' show zhToEn, toLocale;

String translateBookName(String? book, String version) {
  if (book == null) return '';
  final en = zhToEn(book) ?? book;
  return toLocale(en, version);
}

/// Returns the book name to display anywhere a Bible verse reference
/// appears in the exegesis / search / highlight panels. Book names
/// follow the **reading version**, so they match the verse text shown
/// alongside them — reading KJV gives "Genesis 1:1", reading CUVS
/// gives "创世记 1:1", regardless of UI locale.
///
/// This is what the user expects: when the Strong's panel shows the
/// verse text in KJV English right above the "Used N times" list, the
/// list should also be in English; otherwise mixed-language refs feel
/// broken even when each label individually is "correct" by some rule.
///
/// Falls back to locale-driven naming only when [currentVersion] is
/// null/empty (rare — most call sites pass it).
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
