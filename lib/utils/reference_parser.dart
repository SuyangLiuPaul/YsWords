import 'package:yswords/constants/book_name_mapping.dart' show zhToEn;

/// Result of parsing a string like "John 3:16", "约 3:16-18",
/// "1 Cor 13", "创 1:1" — a Bible reference resolved to its
/// canonical English book name plus chapter and optional verse range.
class BibleReference {
  /// Canonical English book name (e.g. "Genesis", "1 Corinthians",
  /// "John"). Always English so it indexes the lexicon and
  /// concordance correctly; the UI re-localizes via
  /// `localeAwareBookName` when displaying.
  final String englishBook;
  final int chapter;
  /// First verse in the range. Null when the user typed only a
  /// chapter (e.g. "John 3" → whole chapter).
  final int? verseStart;
  /// Last verse in the range. Equal to [verseStart] for single-verse
  /// references; greater for ranges like "John 3:16-18".
  final int? verseEnd;

  /// 2026-05-20 (v1.2.62): optional explicit verse list for non-
  /// contiguous compact refs like `[Gen 1:2,5,7,9-10]`. When set,
  /// callers (notably `VersePopupSheet`) should use this list as
  /// the canonical set of cited verses. When null/empty, fall back
  /// to the contiguous `[verseStart, verseEnd]` range — preserves
  /// the v1.2.61 BibleReference shape for every prior call site.
  ///
  /// Always sorted + deduplicated when set.
  final List<int> verses;

  const BibleReference({
    required this.englishBook,
    required this.chapter,
    this.verseStart,
    this.verseEnd,
    this.verses = const [],
  });

  /// Convenience for "this is the whole chapter" — true when only
  /// chapter was typed (no `:verse` part).
  bool get isWholeChapter => verseStart == null && verses.isEmpty;

  /// True when the reference covers non-contiguous verses (e.g.
  /// "1:2,5,7") that can't be expressed as a single start/end pair.
  bool get hasExplicitVerses => verses.isNotEmpty;

  @override
  String toString() {
    if (verses.isNotEmpty) {
      // Compact form: '1:2-3,5,7,9-10'
      final parts = <String>[];
      int start = verses.first;
      int end = start;
      for (var i = 1; i < verses.length; i++) {
        final v = verses[i];
        if (v == end + 1) {
          end = v;
        } else {
          parts.add(start == end ? '$start' : '$start-$end');
          start = v;
          end = v;
        }
      }
      parts.add(start == end ? '$start' : '$start-$end');
      return '$englishBook $chapter:${parts.join(',')}';
    }
    final v = verseStart == null
        ? ''
        : (verseEnd != null && verseEnd! > verseStart!
            ? ':$verseStart-$verseEnd'
            : ':$verseStart');
    return '$englishBook $chapter$v';
  }
}

/// Parse a free-form reference string and return a [BibleReference],
/// or null if the input doesn't look like a reference.
///
/// Recognises (case- and space-insensitive):
///   - Full English names ("Genesis", "1 Corinthians", "John")
///   - Common English abbreviations ("Gen", "1 Cor", "Jn", "Rev")
///   - Simplified + traditional Chinese full names ("创世记", "馬太福音")
///   - Single-character Chinese abbreviations ("创", "约", "罗", "来")
///   - Numbered books in any of: "1 John", "1John", "1Jn", "1 约", "1约"
///   - Chapter alone: "John 3", "约 3"
///   - Single verse: "John 3:16", "约 3:16"
///   - Verse range: "John 3:16-18", "约 3:16-18"
///   - Tightly typed: "jn3:16", "约3:16", "mt5:3"
BibleReference? parseReference(String input) {
  var raw = input.trim();
  if (raw.isEmpty) return null;

  // Multi-book chain: take the first reference only. Common in Bible-
  // Evidence entries like "Isaiah 53; Psalm 22; Micah 5:2; Zechariah
  // 11:12-13" — without this split, the trailing books would absorb
  // into the book name and the whole reference fails to parse.
  final semiIdx = raw.indexOf(';');
  if (semiIdx > 0) {
    raw = raw.substring(0, semiIdx).trim();
  }

  // Comma-separated verse spans (e.g. "John 18:31-33, 37-38") or
  // comma-separated chapters (e.g. "Daniel 2, 7, 8, 11"). Strip
  // everything after the first comma — navigating to the first
  // segment is the right UX.
  final commaIdx = raw.indexOf(',');
  if (commaIdx > 0) {
    raw = raw.substring(0, commaIdx).trim();
  }

  // Cross-chapter verse range: "Book Ch1:Vs1-Ch2:Vs2"
  // (e.g. "2 Kings 22:8-23:25", "Acts 27:27-28:1").
  // Must be tried before the single-chapter patterns because the
  // trailing "Ch2:Vs2" would otherwise absorb into the book name.
  final xc = RegExp(
    r'^\s*(.*?)\s+(\d+)\s*[:：.]\s*(\d+)\s*[-–—]\s*(\d+)\s*[:：.]\s*(\d+)\s*$',
  ).firstMatch(raw);
  if (xc != null) {
    final ref = _buildRef(
      xc.group(1)?.trim() ?? '',
      int.tryParse(xc.group(2)!) ?? 0,
      int.tryParse(xc.group(3)!),
      null,
    );
    if (ref != null) return ref;
  }

  // Fallback: <book> <chapter>-<chapterEnd> (whole-chapter range like
  // "Genesis 6-9" or "Mat 1-2"). Navigate to the start chapter.
  // **This is tried BEFORE the main pattern below** because the main
  // pattern's lazy `.*?` will otherwise greedily absorb the trailing
  // "-9" into the book part (so the ref looks like "Genesis 6-" with
  // chapter 9), then `_buildRef` fails the book lookup and we'd
  // return null instead of falling through.
  final cm = RegExp(
    r'^\s*(.*?)\s+(\d+)\s*[-–—]\s*(\d+)\s*$',
  ).firstMatch(raw);
  if (cm != null) {
    final ref = _buildRef(
      cm.group(1)?.trim() ?? '',
      int.tryParse(cm.group(2)!) ?? 0,
      null,
      null,
    );
    if (ref != null) return ref;
  }

  // Pattern: <book><whitespace?><chapter>(:<verseStart>(-<verseEnd>)?)?
  // Book is any non-digit prefix. Capture greedily then resolve.
  final m = RegExp(
    r'^\s*(.*?)\s*(\d+)(?:\s*[:：.]\s*(\d+)(?:\s*[-–—]\s*(\d+))?)?\s*$',
  ).firstMatch(raw);
  if (m != null) {
    final ref = _buildRef(
      m.group(1)?.trim() ?? '',
      int.tryParse(m.group(2)!) ?? 0,
      m.group(3) == null ? null : int.tryParse(m.group(3)!),
      m.group(4) == null ? null : int.tryParse(m.group(4)!),
    );
    if (ref != null) return ref;
  }

  // Last-ditch fallback: bare book name with no chapter (e.g.
  // "Leviticus" or "创世记") — default to chapter 1.
  final canonical = resolveBookName(raw.trim());
  if (canonical != null) {
    return BibleReference(englishBook: canonical, chapter: 1);
  }

  return null;
}

/// Books that have only one chapter. When a reference like "Jude 14-15"
/// is parsed as chapter 14 (because the chapter-range regex fires), the
/// chapter number actually refers to a verse in chapter 1.
const _singleChapterBooks = {
  'Obadiah', 'Philemon', '2 John', '3 John', 'Jude',
};

BibleReference? _buildRef(
    String bookPart, int chapter, int? verseStart, int? verseEnd) {
  if (chapter <= 0) return null;

  // Empty book part is invalid — "3:16" alone needs a book.
  if (bookPart.isEmpty) return null;

  final canonical = resolveBookName(bookPart);
  if (canonical == null) return null;

  // Single-chapter book: "Jude 14-15" parses as ch 14 ve 15, but Jude
  // has only 1 chapter — re-interpret as ch 1 vs 14-15.
  if (_singleChapterBooks.contains(canonical) && chapter > 1) {
    return BibleReference(
      englishBook: canonical,
      chapter: 1,
      verseStart: chapter,
      verseEnd: verseStart,
    );
  }

  return BibleReference(
    englishBook: canonical,
    chapter: chapter,
    verseStart: verseStart,
    verseEnd: (verseEnd != null && verseStart != null && verseEnd >= verseStart)
        ? verseEnd
        : verseStart,
  );
}

/// Lookup map from any normalized alias → canonical English book name.
/// Built lazily once per process.
Map<String, String>? _aliasIndexCache;

Map<String, String> _aliasIndex() {
  final cached = _aliasIndexCache;
  if (cached != null) return cached;

  final map = <String, String>{};

  void add(String alias, String canonical) {
    final key = _normalize(alias);
    if (key.isEmpty) return;
    map[key] = canonical;
  }

  // Full English book names.
  for (final book in _englishCanonical) {
    add(book, book);
  }

  // English abbreviations — common conventions used by lexica and
  // study tools. Multiple aliases per book are intentional.
  _englishAliases.forEach((canonical, aliases) {
    for (final a in aliases) {
      add(a, canonical);
    }
  });

  // Chinese single-character book aliases (most common when users
  // type a quick reference like "约 3:16" or "创 1:1").
  _chineseShortAliases.forEach((alias, canonical) {
    add(alias, canonical);
  });

  _aliasIndexCache = map;
  return map;
}

String? resolveBookName(String input) {
  final normalized = _normalize(input);
  if (normalized.isEmpty) return null;

  // First check the alias index (English full names + abbreviations
  // + Chinese short forms).
  final hit = _aliasIndex()[normalized];
  if (hit != null) return hit;

  // Fall back to the existing zh→en map for full Chinese book names
  // (handles every translation and traditional/simplified form).
  // We try both the raw input and a "1Sa"-style numbered prefix.
  final zhHit = zhToEn(input.trim());
  if (zhHit != null) return zhHit;

  // Numbered books typed without a space: "1John", "2Tim", "1约".
  // Split into number prefix + remainder, then re-resolve.
  final num = RegExp(r'^([1-3])\s*(.+)$').firstMatch(input.trim());
  if (num != null) {
    final n = num.group(1)!;
    final rest = num.group(2)!;
    final restCanon = resolveBookName(rest);
    if (restCanon != null) {
      // Map "1 John" / "2 John" / "3 John" / "1 Cor" etc.
      // The canonical book may already include a number — only
      // prepend if it doesn't.
      if (!restCanon.startsWith(RegExp(r'\d'))) {
        return _withNumberPrefix(n, restCanon);
      }
    }
  }
  return null;
}

/// Some books exist with numbered prefixes; when we resolve "Cor" /
/// "Corinthians" we need to know whether to return "1 Corinthians"
/// or "2 Corinthians" based on the number the user typed.
String? _withNumberPrefix(String n, String book) {
  // Books that exist with 1/2/3 prefixed forms in the canonical list.
  // The user typed e.g. "1 Cor" — we resolve "Cor" to "Corinthians",
  // then prepend the number.
  const numberedBookBases = {
    'Samuel', 'Kings', 'Chronicles',
    'Corinthians', 'Thessalonians', 'Timothy', 'Peter',
    // 'John' is intentionally NOT in this set — typing "1 John"
    // resolves correctly via the alias index, and treating "John"
    // here would also affect plain Gospel-of-John resolution.
  };
  if (numberedBookBases.contains(book)) {
    return '$n $book';
  }
  return book;
}

/// Normalize an alias for index lookup: lowercase, strip dots, strip
/// internal whitespace, collapse common Unicode punctuation.
String _normalize(String s) {
  return s
      .toLowerCase()
      .replaceAll(RegExp(r'[\s\. 　]+'), '')
      .replaceAll('‘', '')
      .replaceAll('’', '');
}

const List<String> _englishCanonical = [
  'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy',
  'Joshua', 'Judges', 'Ruth', '1 Samuel', '2 Samuel',
  '1 Kings', '2 Kings', '1 Chronicles', '2 Chronicles',
  'Ezra', 'Nehemiah', 'Esther', 'Job', 'Psalms', 'Proverbs',
  'Ecclesiastes', 'Song of Solomon', 'Isaiah', 'Jeremiah',
  'Lamentations', 'Ezekiel', 'Daniel', 'Hosea', 'Joel', 'Amos',
  'Obadiah', 'Jonah', 'Micah', 'Nahum', 'Habakkuk',
  'Zephaniah', 'Haggai', 'Zechariah', 'Malachi',
  'Matthew', 'Mark', 'Luke', 'John', 'Acts', 'Romans',
  '1 Corinthians', '2 Corinthians', 'Galatians', 'Ephesians',
  'Philippians', 'Colossians', '1 Thessalonians', '2 Thessalonians',
  '1 Timothy', '2 Timothy', 'Titus', 'Philemon', 'Hebrews',
  'James', '1 Peter', '2 Peter', '1 John', '2 John', '3 John',
  'Jude', 'Revelation',
];

/// Common English abbreviations used by Bible-study tools, lexica,
/// and study Bibles. Lowercased, dots-optional (the normalizer
/// strips dots before lookup).
const Map<String, List<String>> _englishAliases = {
  'Genesis': ['Gen', 'Gn'],
  'Exodus': ['Exo', 'Exod', 'Ex'],
  'Leviticus': ['Lev', 'Lv'],
  'Numbers': ['Num', 'Nm', 'Nu'],
  'Deuteronomy': ['Deu', 'Deut', 'Dt'],
  'Joshua': ['Jos', 'Josh', 'Jsh'],
  'Judges': ['Jdg', 'Judg', 'Jg'],
  'Ruth': ['Rut', 'Ru'],
  '1 Samuel': ['1Sam', '1 Sam', '1Sa', '1 Sa', 'I Sam', 'ISam'],
  '2 Samuel': ['2Sam', '2 Sam', '2Sa', '2 Sa', 'II Sam', 'IISam'],
  '1 Kings': ['1Kgs', '1 Kgs', '1Ki', '1 Ki', 'I Kings', 'IKings'],
  '2 Kings': ['2Kgs', '2 Kgs', '2Ki', '2 Ki', 'II Kings', 'IIKings'],
  '1 Chronicles': ['1Chr', '1 Chr', '1Ch', '1 Ch', 'I Chr', 'IChr'],
  '2 Chronicles': ['2Chr', '2 Chr', '2Ch', '2 Ch', 'II Chr', 'IIChr'],
  'Ezra': ['Ezr', 'Ez'],
  'Nehemiah': ['Neh', 'Ne'],
  'Esther': ['Est', 'Esth'],
  'Job': ['Jb'],
  'Psalms': ['Ps', 'Psa', 'Psalm'],
  'Proverbs': ['Prv', 'Prov', 'Pr'],
  'Ecclesiastes': ['Ecc', 'Eccl', 'Ec'],
  'Song of Solomon': ['Song', 'SoS', 'Sg', 'Cant', 'Canticles', 'Song of Songs'],
  'Isaiah': ['Isa', 'Is'],
  'Jeremiah': ['Jer', 'Je'],
  'Lamentations': ['Lam', 'La'],
  'Ezekiel': ['Eze', 'Ezk', 'Ezek'],
  'Daniel': ['Dan', 'Dn'],
  'Hosea': ['Hos', 'Ho'],
  'Joel': ['Jl'],
  'Amos': ['Am'],
  'Obadiah': ['Oba', 'Obd', 'Ob'],
  'Jonah': ['Jon', 'Jnh'],
  'Micah': ['Mic', 'Mc'],
  'Nahum': ['Nah', 'Na'],
  'Habakkuk': ['Hab', 'Hk'],
  'Zephaniah': ['Zep', 'Zeph'],
  'Haggai': ['Hag', 'Hg'],
  'Zechariah': ['Zec', 'Zech'],
  'Malachi': ['Mal'],
  'Matthew': ['Mat', 'Matt', 'Mt'],
  'Mark': ['Mar', 'Mrk', 'Mk'],
  'Luke': ['Luk', 'Lk'],
  'John': ['Joh', 'Jhn', 'Jn'],
  'Acts': ['Act', 'Ac'],
  'Romans': ['Rom', 'Ro'],
  '1 Corinthians': [
    '1Cor', '1 Cor', '1Co', '1 Co', 'I Cor', 'ICor', '1 Corinth',
  ],
  '2 Corinthians': [
    '2Cor', '2 Cor', '2Co', '2 Co', 'II Cor', 'IICor', '2 Corinth',
  ],
  'Galatians': ['Gal', 'Ga'],
  'Ephesians': ['Eph', 'Ep'],
  'Philippians': ['Phil', 'Php', 'Pp'],
  'Colossians': ['Col', 'Cl'],
  '1 Thessalonians': [
    '1Thess', '1 Thess', '1Th', '1 Th', 'I Thes', 'IThess'
  ],
  '2 Thessalonians': [
    '2Thess', '2 Thess', '2Th', '2 Th', 'II Thes', 'IIThess'
  ],
  '1 Timothy': ['1Tim', '1 Tim', '1Ti', '1 Ti', 'I Tim', 'ITim'],
  '2 Timothy': ['2Tim', '2 Tim', '2Ti', '2 Ti', 'II Tim', 'IITim'],
  'Titus': ['Tit', 'Ti'],
  'Philemon': ['Phlm', 'Phm', 'Phn'],
  'Hebrews': ['Heb', 'He'],
  'James': ['Jas', 'Jam', 'Jm'],
  '1 Peter': ['1Pet', '1 Pet', '1Pe', '1 Pe', 'I Pet', 'IPet'],
  '2 Peter': ['2Pet', '2 Pet', '2Pe', '2 Pe', 'II Pet', 'IIPet'],
  '1 John': ['1John', '1 Jn', '1Jn', 'I John', 'IJn', '1 Jo'],
  '2 John': ['2John', '2 Jn', '2Jn', 'II John', 'IIJn', '2 Jo'],
  '3 John': ['3John', '3 Jn', '3Jn', 'III John', 'IIIJn', '3 Jo'],
  'Jude': ['Jud', 'Jde'],
  'Revelation': ['Rev', 'Rv', 'Revelations', 'Apoc', 'Apocalypse'],
};

/// Single- or two-character Chinese abbreviations users commonly
/// type. The full Chinese names are already handled by zhToEn.
const Map<String, String> _chineseShortAliases = {
  // OT
  '创': 'Genesis', '出': 'Exodus', '利': 'Leviticus',
  '民': 'Numbers', '申': 'Deuteronomy',
  '书': 'Joshua', '士': 'Judges', '得': 'Ruth',
  '撒上': '1 Samuel', '撒下': '2 Samuel',
  '王上': '1 Kings', '王下': '2 Kings',
  '代上': '1 Chronicles', '代下': '2 Chronicles',
  '拉': 'Ezra', '尼': 'Nehemiah', '斯': 'Esther',
  '伯': 'Job', '诗': 'Psalms', '诗篇': 'Psalms', '箴': 'Proverbs',
  '传': 'Ecclesiastes', '歌': 'Song of Solomon', '雅歌': 'Song of Solomon',
  '赛': 'Isaiah', '耶': 'Jeremiah', '哀': 'Lamentations',
  '结': 'Ezekiel', '但': 'Daniel',
  '何': 'Hosea', '珥': 'Joel', '摩': 'Amos',
  '俄': 'Obadiah', '拿': 'Jonah', '弥': 'Micah',
  '鸿': 'Nahum', '哈': 'Habakkuk', '番': 'Zephaniah',
  '该': 'Haggai', '亚': 'Zechariah', '玛': 'Malachi',
  // NT
  '太': 'Matthew', '可': 'Mark', '路': 'Luke', '约': 'John',
  '徒': 'Acts', '罗': 'Romans',
  '林前': '1 Corinthians', '林后': '2 Corinthians',
  '加': 'Galatians', '弗': 'Ephesians', '腓': 'Philippians', '西': 'Colossians',
  '帖前': '1 Thessalonians', '帖后': '2 Thessalonians',
  '提前': '1 Timothy', '提后': '2 Timothy',
  '多': 'Titus', '门': 'Philemon', '来': 'Hebrews',
  '雅': 'James',
  '彼前': '1 Peter', '彼后': '2 Peter',
  '约一': '1 John', '约二': '2 John', '约三': '3 John',
  '1约': '1 John', '2约': '2 John', '3约': '3 John',
  '犹': 'Jude', '启': 'Revelation',
  // Traditional Chinese variants
  '書': 'Joshua', '師': 'Judges',
  '撒上記': '1 Samuel', '撒下記': '2 Samuel',
  '王上記': '1 Kings', '王下記': '2 Kings',
  '詩': 'Psalms', '詩篇': 'Psalms',
  '賽': 'Isaiah', '結': 'Ezekiel',
  '彌': 'Micah', '鴻': 'Nahum', '該': 'Haggai',
  '亞': 'Zechariah', '瑪': 'Malachi',
  '羅': 'Romans',
  '門': 'Philemon', '來': 'Hebrews', '雅各': 'James',
  '猶': 'Jude', '啟': 'Revelation',
};
