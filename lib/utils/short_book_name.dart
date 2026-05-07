// ignore: depend_on_referenced_packages
import 'package:characters/characters.dart';

import 'package:yswords/utils/version_mapper.dart' show toEnglish;

/// Standard 1-character (or 2-3 char for paired) Chinese-Bible
/// abbreviations. Same maps that `widgets/word_distribution_table.dart`
/// has had for a while; extracted here so other surfaces (the
/// reader's floating header, the dashboard, etc.) can use them
/// without duplicating the table.
///
/// English uses 3-letter abbreviations. Pass any localized book
/// name (Chinese / English) — [shortBookName] will reverse-map to
/// English via `toEnglish`, look up the abbreviation, and fall back
/// to the localized last character if no abbreviation exists.

/// Get a compact book name suitable for narrow surfaces (≤360px
/// AppBar titles, chip labels, etc.). 2026-05-07: added because the
/// AppBar on iPhone 12 mini was truncating "帖撒罗尼迦前书" to "帖..."
/// which is unhelpful — the abbreviation "帖前" reads cleanly in the
/// same width.
String shortBookName(String localizedBook, String locale) {
  if (localizedBook.isEmpty) return localizedBook;
  // Reverse-map to canonical English, then look up the abbreviation
  // map for the user's locale. If the input was already English,
  // toEnglish returns it unchanged.
  final englishBook = toEnglish(localizedBook) ?? localizedBook;
  if (locale.startsWith('zh')) {
    final hant = locale == 'zh-Hant';
    final m = hant ? _shortBooksHant : _shortBooksHans;
    final v = m[englishBook];
    if (v != null) return v;
    // Fallback: last character of the localized name. For
    // "腓利门书" (Philemon, no entry in the map) → "书" — not great
    // but stable.
    return localizedBook.isEmpty
        ? englishBook
        : localizedBook.characters.last;
  }
  // English / other locales — 3-letter abbreviation.
  final v = _shortBooksEn[englishBook];
  return v ??
      (englishBook.length >= 3 ? englishBook.substring(0, 3) : englishBook);
}

const Map<String, String> _shortBooksEn = {
  'Genesis': 'Gen', 'Exodus': 'Exo', 'Leviticus': 'Lev',
  'Numbers': 'Num', 'Deuteronomy': 'Deu', 'Joshua': 'Jos',
  'Judges': 'Jdg', 'Ruth': 'Rut', '1 Samuel': '1Sa',
  '2 Samuel': '2Sa', '1 Kings': '1Ki', '2 Kings': '2Ki',
  '1 Chronicles': '1Ch', '2 Chronicles': '2Ch', 'Ezra': 'Ezr',
  'Nehemiah': 'Neh', 'Esther': 'Est', 'Job': 'Job',
  'Psalms': 'Psa', 'Proverbs': 'Pro', 'Ecclesiastes': 'Ecc',
  'Song of Solomon': 'Sng', 'Isaiah': 'Isa', 'Jeremiah': 'Jer',
  'Lamentations': 'Lam', 'Ezekiel': 'Eze', 'Daniel': 'Dan',
  'Hosea': 'Hos', 'Joel': 'Joe', 'Amos': 'Amo', 'Obadiah': 'Oba',
  'Jonah': 'Jon', 'Micah': 'Mic', 'Nahum': 'Nah', 'Habakkuk': 'Hab',
  'Zephaniah': 'Zep', 'Haggai': 'Hag', 'Zechariah': 'Zec',
  'Malachi': 'Mal',
  'Matthew': 'Mat', 'Mark': 'Mar', 'Luke': 'Luk', 'John': 'Joh',
  'Acts': 'Act', 'Romans': 'Rom', '1 Corinthians': '1Co',
  '2 Corinthians': '2Co', 'Galatians': 'Gal', 'Ephesians': 'Eph',
  'Philippians': 'Phi', 'Colossians': 'Col',
  '1 Thessalonians': '1Th', '2 Thessalonians': '2Th',
  '1 Timothy': '1Ti', '2 Timothy': '2Ti', 'Titus': 'Tit',
  'Philemon': 'Phm', 'Hebrews': 'Heb', 'James': 'Jas',
  '1 Peter': '1Pe', '2 Peter': '2Pe', '1 John': '1Jn',
  '2 John': '2Jn', '3 John': '3Jn', 'Jude': 'Jud',
  'Revelation': 'Rev',
};

const Map<String, String> _shortBooksHans = {
  'Genesis': '创', 'Exodus': '出', 'Leviticus': '利', 'Numbers': '民',
  'Deuteronomy': '申', 'Joshua': '书', 'Judges': '士', 'Ruth': '得',
  '1 Samuel': '撒上', '2 Samuel': '撒下',
  '1 Kings': '王上', '2 Kings': '王下',
  '1 Chronicles': '代上', '2 Chronicles': '代下',
  'Ezra': '拉', 'Nehemiah': '尼', 'Esther': '斯', 'Job': '伯',
  'Psalms': '诗', 'Proverbs': '箴', 'Ecclesiastes': '传',
  'Song of Solomon': '歌', 'Isaiah': '赛', 'Jeremiah': '耶',
  'Lamentations': '哀', 'Ezekiel': '结', 'Daniel': '但',
  'Hosea': '何', 'Joel': '珥', 'Amos': '摩', 'Obadiah': '俄',
  'Jonah': '拿', 'Micah': '弥', 'Nahum': '鸿', 'Habakkuk': '哈',
  'Zephaniah': '番', 'Haggai': '该', 'Zechariah': '亚', 'Malachi': '玛',
  'Matthew': '太', 'Mark': '可', 'Luke': '路', 'John': '约', 'Acts': '徒',
  'Romans': '罗',
  '1 Corinthians': '林前', '2 Corinthians': '林后',
  'Galatians': '加', 'Ephesians': '弗', 'Philippians': '腓',
  'Colossians': '西',
  '1 Thessalonians': '帖前', '2 Thessalonians': '帖后',
  '1 Timothy': '提前', '2 Timothy': '提后',
  'Titus': '多', 'Philemon': '门', 'Hebrews': '来', 'James': '雅',
  '1 Peter': '彼前', '2 Peter': '彼后',
  '1 John': '约一', '2 John': '约二', '3 John': '约三',
  'Jude': '犹', 'Revelation': '启',
};

const Map<String, String> _shortBooksHant = {
  'Genesis': '創', 'Exodus': '出', 'Leviticus': '利', 'Numbers': '民',
  'Deuteronomy': '申', 'Joshua': '書', 'Judges': '士', 'Ruth': '得',
  '1 Samuel': '撒上', '2 Samuel': '撒下',
  '1 Kings': '王上', '2 Kings': '王下',
  '1 Chronicles': '代上', '2 Chronicles': '代下',
  'Ezra': '拉', 'Nehemiah': '尼', 'Esther': '斯', 'Job': '伯',
  'Psalms': '詩', 'Proverbs': '箴', 'Ecclesiastes': '傳',
  'Song of Solomon': '歌', 'Isaiah': '賽', 'Jeremiah': '耶',
  'Lamentations': '哀', 'Ezekiel': '結', 'Daniel': '但',
  'Hosea': '何', 'Joel': '珥', 'Amos': '摩', 'Obadiah': '俄',
  'Jonah': '拿', 'Micah': '彌', 'Nahum': '鴻', 'Habakkuk': '哈',
  'Zephaniah': '番', 'Haggai': '該', 'Zechariah': '亞', 'Malachi': '瑪',
  'Matthew': '太', 'Mark': '可', 'Luke': '路', 'John': '約', 'Acts': '徒',
  'Romans': '羅',
  '1 Corinthians': '林前', '2 Corinthians': '林後',
  'Galatians': '加', 'Ephesians': '弗', 'Philippians': '腓',
  'Colossians': '西',
  '1 Thessalonians': '帖前', '2 Thessalonians': '帖後',
  '1 Timothy': '提前', '2 Timothy': '提後',
  'Titus': '多', 'Philemon': '門', 'Hebrews': '來', 'James': '雅',
  '1 Peter': '彼前', '2 Peter': '彼後',
  '1 John': '約一', '2 John': '約二', '3 John': '約三',
  'Jude': '猶', 'Revelation': '啟',
};
