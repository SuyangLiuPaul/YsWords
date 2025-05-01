import 'package:yswords/models/book.dart';
import 'package:yswords/models/chapter.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/models/app_settings.dart';

const List<String> standardBookOrder = [
  'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy',
  'Joshua', 'Judges', 'Ruth',
  '1 Samuel', '2 Samuel', '1 Kings', '2 Kings',
  '1 Chronicles', '2 Chronicles', 'Ezra', 'Nehemiah', 'Esther',
  'Job', 'Psalms', 'Proverbs', 'Ecclesiastes', 'Song of Solomon',
  'Isaiah', 'Jeremiah', 'Lamentations', 'Ezekiel', 'Daniel',
  'Hosea', 'Joel', 'Amos', 'Obadiah', 'Jonah', 'Micah',
  'Nahum', 'Habakkuk', 'Zephaniah', 'Haggai', 'Zechariah', 'Malachi',
  'Matthew', 'Mark', 'Luke', 'John', 'Acts',
  'Romans', '1 Corinthians', '2 Corinthians', 'Galatians', 'Ephesians',
  'Philippians', 'Colossians', '1 Thessalonians', '2 Thessalonians',
  '1 Timothy', '2 Timothy', 'Titus', 'Philemon',
  'Hebrews', 'James', '1 Peter', '2 Peter',
  '1 John', '2 John', '3 John', 'Jude', 'Revelation',
  // Add Chinese Simplified and Traditional names afterwards if needed separately.
];

const Map<String, String> bookNameToEnglish = {
  // Genesis
  'Genesis': 'Genesis', '创世纪': 'Genesis', '創世紀': 'Genesis',
  // Exodus
  'Exodus': 'Exodus', '出埃及记': 'Exodus', '出埃及記': 'Exodus',
  // Leviticus
  'Leviticus': 'Leviticus', '利未记': 'Leviticus', '利未記': 'Leviticus',
  // Numbers
  'Numbers': 'Numbers', '民数记': 'Numbers', '民數記': 'Numbers',
  // Deuteronomy
  'Deuteronomy': 'Deuteronomy', '申命记': 'Deuteronomy', '申命記': 'Deuteronomy',
  // Joshua
  'Joshua': 'Joshua', '约书亚记': 'Joshua', '約書亞記': 'Joshua',
  // Judges
  'Judges': 'Judges', '士师记': 'Judges', '士師記': 'Judges',
  // Ruth
  'Ruth': 'Ruth', '路得记': 'Ruth', '路得記': 'Ruth',
  // 1 Samuel
  '1 Samuel': '1 Samuel', '撒母耳记上': '1 Samuel', '撒母耳記上': '1 Samuel',
  // 2 Samuel
  '2 Samuel': '2 Samuel', '撒母耳记下': '2 Samuel', '撒母耳記下': '2 Samuel',
  // 1 Kings
  '1 Kings': '1 Kings', '列王纪上': '1 Kings', '列王紀上': '1 Kings',
  // 2 Kings
  '2 Kings': '2 Kings', '列王纪下': '2 Kings', '列王紀下': '2 Kings',
  // 1 Chronicles
  '1 Chronicles': '1 Chronicles', '历代志上': '1 Chronicles', '歷代志上': '1 Chronicles',
  // 2 Chronicles
  '2 Chronicles': '2 Chronicles', '历代志下': '2 Chronicles', '歷代志下': '2 Chronicles',
  // Ezra
  'Ezra': 'Ezra', '以斯拉记': 'Ezra', '以斯拉記': 'Ezra',
  // Nehemiah
  'Nehemiah': 'Nehemiah', '尼希米记': 'Nehemiah', '尼希米記': 'Nehemiah',
  // Esther
  'Esther': 'Esther', '以斯帖记': 'Esther', '以斯帖記': 'Esther',
  // Job
  'Job': 'Job', '约伯记': 'Job', '約伯記': 'Job',
  // Psalms
  'Psalms': 'Psalms', '诗篇': 'Psalms', '詩篇': 'Psalms',
  // Proverbs
  'Proverbs': 'Proverbs', '箴言': 'Proverbs',
  // Ecclesiastes
  'Ecclesiastes': 'Ecclesiastes', '传道书': 'Ecclesiastes', '傳道書': 'Ecclesiastes',
  // Song of Solomon
  'Song of Solomon': 'Song of Solomon', '雅歌': 'Song of Solomon',
  // Isaiah
  'Isaiah': 'Isaiah', '以赛亚书': 'Isaiah', '以賽亞書': 'Isaiah',
  // Jeremiah
  'Jeremiah': 'Jeremiah', '耶利米书': 'Jeremiah', '耶利米書': 'Jeremiah',
  // Lamentations
  'Lamentations': 'Lamentations', '耶利米哀歌': 'Lamentations', 
  // Ezekiel
  'Ezekiel': 'Ezekiel', '以西结书': 'Ezekiel', '以西結書': 'Ezekiel',
  // Daniel
  'Daniel': 'Daniel', '但以理书': 'Daniel', '但以理書': 'Daniel',
  // Hosea
  'Hosea': 'Hosea', '何西阿书': 'Hosea', '何西阿書': 'Hosea',
  // Joel
  'Joel': 'Joel', '约珥书': 'Joel', '約珥書': 'Joel',
  // Amos
  'Amos': 'Amos', '阿摩司书': 'Amos', '阿摩司書': 'Amos',
  // Obadiah
  'Obadiah': 'Obadiah', '俄巴底亚书': 'Obadiah', '俄巴底亞書': 'Obadiah',
  // Jonah
  'Jonah': 'Jonah', '约拿书': 'Jonah', '約拿書': 'Jonah',
  // Micah
  'Micah': 'Micah', '弥迦书': 'Micah', '彌迦書': 'Micah',
  // Nahum
  'Nahum': 'Nahum', '那鸿书': 'Nahum', '那鴻書': 'Nahum',
  // Habakkuk
  'Habakkuk': 'Habakkuk', '哈巴谷书': 'Habakkuk', '哈巴谷書': 'Habakkuk',
  // Zephaniah
  'Zephaniah': 'Zephaniah', '西番雅书': 'Zephaniah', '西番雅書': 'Zephaniah',
  // Haggai
  'Haggai': 'Haggai', '哈该书': 'Haggai', '哈該書': 'Haggai',
  // Zechariah
  'Zechariah': 'Zechariah', '撒迦利亚书': 'Zechariah', '撒迦利亞書': 'Zechariah',
  // Malachi
  'Malachi': 'Malachi', '玛拉基书': 'Malachi', '瑪拉基書': 'Malachi',
  // Matthew
  'Matthew': 'Matthew', '马太福音': 'Matthew', '馬太福音': 'Matthew',
  // Mark
  'Mark': 'Mark', '马可福音': 'Mark', '馬可福音': 'Mark',
  // Luke
  'Luke': 'Luke', '路加福音': 'Luke',
  // John
  'John': 'John', '约翰福音': 'John', '約翰福音': 'John',
  // Acts
  'Acts': 'Acts', '使徒行传': 'Acts', '使徒行傳': 'Acts',
  // Romans
  'Romans': 'Romans', '罗马书': 'Romans', '羅馬書': 'Romans',
  // 1 Corinthians
  '1 Corinthians': '1 Corinthians', '哥林多前书': '1 Corinthians', '哥林多前書': '1 Corinthians',
  // 2 Corinthians
  '2 Corinthians': '2 Corinthians', '哥林多后书': '2 Corinthians', '哥林多後書': '2 Corinthians',
  // Galatians
  'Galatians': 'Galatians', '加拉太书': 'Galatians', '加拉太書': 'Galatians',
  // Ephesians
  'Ephesians': 'Ephesians', '以弗所书': 'Ephesians', '以弗所書': 'Ephesians',
  // Philippians
  'Philippians': 'Philippians', '腓立比书': 'Philippians', '腓立比書': 'Philippians',
  // Colossians
  'Colossians': 'Colossians', '歌罗西书': 'Colossians', '歌羅西書': 'Colossians',
  // 1 Thessalonians
  '1 Thessalonians': '1 Thessalonians', '帖撒罗尼迦前书': '1 Thessalonians', '帖撒羅尼迦前書': '1 Thessalonians',
  // 2 Thessalonians
  '2 Thessalonians': '2 Thessalonians', '帖撒罗尼迦后书': '2 Thessalonians', '帖撒羅尼迦後書': '2 Thessalonians',
  // 1 Timothy
  '1 Timothy': '1 Timothy', '提摩太前书': '1 Timothy', '提摩太前書': '1 Timothy',
  // 2 Timothy
  '2 Timothy': '2 Timothy', '提摩太后书': '2 Timothy', '提摩太後書': '2 Timothy',
  // Titus
  'Titus': 'Titus', '提多书': 'Titus', '提多書': 'Titus',
  // Philemon
  'Philemon': 'Philemon', '腓利门书': 'Philemon', '腓利門書': 'Philemon',
  // Hebrews
  'Hebrews': 'Hebrews', '希伯来书': 'Hebrews', '希伯來書': 'Hebrews',
  // James
  'James': 'James', '雅各书': 'James', '雅各書': 'James',
  // 1 Peter
  '1 Peter': '1 Peter', '彼得前书': '1 Peter', '彼得前書': '1 Peter',
  // 2 Peter
  '2 Peter': '2 Peter', '彼得后书': '2 Peter', '彼得後書': '2 Peter',
  // 1 John
  '1 John': '1 John', '约翰一书': '1 John', '約翰一書': '1 John',
  // 2 John
  '2 John': '2 John', '约翰二书': '2 John', '約翰二書': '2 John',
  // 3 John
  '3 John': '3 John', '约翰三书': '3 John', '約翰三書': '3 John',
  // Jude
  'Jude': 'Jude', '犹大书': 'Jude', '猶大書': 'Jude',
  // Revelation
  'Revelation': 'Revelation', '启示录': 'Revelation', '啟示錄': 'Revelation',
};

// Class repsonsible for fetching books based on the provided verses

class FetchBooks {
  // Static method to execute the fetching process
  static Future<void> execute({required MainProvider mainProvider, required AppSettings settings}) async {
    if (!settings.allowUpdates) {
      return; 
    }
    List<Verse> verses = mainProvider.verses;

    // Collect unique book titles mapped to English
    final Set<String> _seen = {};
    final List<String> foundBookTitles = [];
    for (final v in verses) {
      final englishBook = bookNameToEnglish[v.book] ?? v.book;
      if (_seen.add(englishBook)) foundBookTitles.add(englishBook);
    }

    // Sort book titles according to standard biblical order
    final List<String> bookTitles = [
      ...standardBookOrder.where((b) => foundBookTitles.contains(b))
    ];

    // Iterate through each unique book title to organize chapters and verses
    for (var bookTitle in bookTitles) {
      // Filter verses based on the current book title mapped to English
      List<Verse> availableVerses =
          verses.where((v) => (bookNameToEnglish[v.book] ?? v.book) == bookTitle).toList();

      // Collect unique chapter numbers *and* sort them so UI lists 1, 2, 3… in order.
      List<int> availableChapters = availableVerses
          .map((e) => e.chapter)
          .toSet()
          .toList()
        ..sort();

      List<Chapter> chapters = [];

      // Iterate through each unique chapter number to organize verses
      for (var element in availableChapters) {
        // Create a Chapter object for each unique chapter
        Chapter chapter = Chapter(
          title: element,
          verses: (availableVerses.where((v) => v.chapter == element).toList()
            ..sort((a, b) => a.verse.compareTo(b.verse))),
        );

        chapters.add(chapter);
      }

      // Use the localized book name from the first verse for display
      final localizedBookName = availableVerses.first.book;
      Book book = Book(title: localizedBookName, chapters: chapters);

      // Add the created Book to the mainProvider's ist of books
      mainProvider.addBook(book: book);
    }
  }

}
