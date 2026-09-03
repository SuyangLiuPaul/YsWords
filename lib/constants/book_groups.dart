/// Old Testament (English + Chinese Simplified + Chinese Traditional)
const oldTestamentBooks = <String>{
  // English
  'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy',
  'Joshua', 'Judges', 'Ruth', '1 Samuel', '2 Samuel',
  '1 Kings', '2 Kings', '1 Chronicles', '2 Chronicles',
  'Ezra', 'Nehemiah', 'Esther', 'Job', 'Psalms', 'Proverbs',
  'Ecclesiastes', 'Song of Solomon', 'Isaiah', 'Jeremiah',
  'Lamentations', 'Ezekiel', 'Daniel', 'Hosea', 'Joel', 'Amos',
  'Obadiah', 'Jonah', 'Micah', 'Nahum', 'Habakkuk',
  'Zephaniah', 'Haggai', 'Zechariah', 'Malachi',
  // Chinese Simplified + Traditional
  '创世记', '創世紀',
  '出埃及记', '出埃及記',
  '利未记', '利未記',
  '民数记', '民數記',
  '申命记', '申命記',
  '约书亚记', '約書亞記',
  '士师记', '士師記',
  '路得记', '路得記',
  '撒母耳记上', '撒母耳記上',
  '撒母耳记下', '撒母耳記下',
  '列王纪上', '列王紀上',
  '列王纪下', '列王紀下',
  '历代志上', '歷代志上',
  '历代志下', '歷代志下',
  '以斯拉记', '以斯拉記',
  '尼希米记', '尼希米記',
  '以斯帖记', '以斯帖記',
  '约伯记', '約伯記',
  '诗篇', '詩篇',
  '箴言',
  '传道书', '傳道書',
  '雅歌',
  '以赛亚书', '以賽亞書',
  '耶利米书', '耶利米書',
  '耶利米哀歌',
  '以西结书', '以西結書',
  '但以理书', '但以理書',
  '何西阿书', '何西阿書',
  '约珥书', '約珥書',
  '阿摩司书', '阿摩司書',
  '俄巴底亚书', '俄巴底亞書',
  '约拿书', '約拿書',
  '弥迦书', '彌迦書',
  '那鸿书', '那鴻書',
  '哈巴谷书', '哈巴谷書',
  '西番雅书', '西番雅書',
  '哈该书', '哈該書',
  '撒迦利亚书', '撒迦利亞書',
  '玛拉基书', '瑪拉基書',
};

/// New Testament (English + Chinese Simplified + Chinese Traditional)
const newTestamentBooks = <String>{
  // English
  'Matthew', 'Mark', 'Luke', 'John', 'Acts', 'Romans',
  '1 Corinthians', '2 Corinthians', 'Galatians', 'Ephesians',
  'Philippians', 'Colossians', '1 Thessalonians', '2 Thessalonians',
  '1 Timothy', '2 Timothy', 'Titus', 'Philemon', 'Hebrews',
  'James', '1 Peter', '2 Peter', '1 John', '2 John', '3 John',
  'Jude', 'Revelation',
  // Chinese Simplified + Traditional
  '马太福音', '馬太福音',
  '马可福音', '馬可福音',
  '路加福音',
  '约翰福音', '約翰福音',
  '使徒行传', '使徒行傳',
  '罗马书', '羅馬書',
  '哥林多前书', '哥林多前書',
  '哥林多后书', '哥林多後書',
  '加拉太书', '加拉太書',
  '以弗所书', '以弗所書',
  '腓立比书', '腓立比書',
  '歌罗西书', '歌羅西書',
  '帖撒罗尼迦前书', '帖撒羅尼迦前書',
  '帖撒罗尼迦后书', '帖撒羅尼迦後書',
  '提摩太前书', '提摩太前書',
  '提摩太后书', '提摩太後書',
  '提多书', '提多書',
  '腓利门书', '腓利門書',
  '希伯来书', '希伯來書',
  '雅各书', '雅各書',
  '彼得前书', '彼得前書',
  '彼得后书', '彼得後書',
  '约翰一书', '約翰一書',
  '约翰二书', '約翰二書',
  '约翰三书', '約翰三書',
  '犹大书', '猶大書',
  '启示录', '啟示錄',
};

/// Canonical English book names in canonical order — used for the
/// distribution-table column order so books always appear left→right
/// in Bible order regardless of locale.
const canonicalOtBooks = <String>[
  'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy',
  'Joshua', 'Judges', 'Ruth', '1 Samuel', '2 Samuel',
  '1 Kings', '2 Kings', '1 Chronicles', '2 Chronicles',
  'Ezra', 'Nehemiah', 'Esther', 'Job', 'Psalms', 'Proverbs',
  'Ecclesiastes', 'Song of Solomon', 'Isaiah', 'Jeremiah',
  'Lamentations', 'Ezekiel', 'Daniel', 'Hosea', 'Joel', 'Amos',
  'Obadiah', 'Jonah', 'Micah', 'Nahum', 'Habakkuk',
  'Zephaniah', 'Haggai', 'Zechariah', 'Malachi',
];

const canonicalNtBooks = <String>[
  'Matthew', 'Mark', 'Luke', 'John', 'Acts', 'Romans',
  '1 Corinthians', '2 Corinthians', 'Galatians', 'Ephesians',
  'Philippians', 'Colossians', '1 Thessalonians', '2 Thessalonians',
  '1 Timothy', '2 Timothy', 'Titus', 'Philemon', 'Hebrews',
  'James', '1 Peter', '2 Peter', '1 John', '2 John', '3 John',
  'Jude', 'Revelation',
];

// ── NT sub-corpus groupings (analytical, not strict partitions) ──────

/// Gospels + Acts — narrative section.
const ntGospelsActs = <String>[
  'Matthew', 'Mark', 'Luke', 'John', 'Acts',
];

/// Pauline epistles (traditional 13).
const ntPauline = <String>[
  'Romans', '1 Corinthians', '2 Corinthians', 'Galatians',
  'Ephesians', 'Philippians', 'Colossians', '1 Thessalonians',
  '2 Thessalonians', '1 Timothy', '2 Timothy', 'Titus', 'Philemon',
];

/// Johannine corpus excluding the Gospel of John (already in G&A).
const ntJohannine = <String>[
  '1 John', '2 John', '3 John', 'Revelation',
];

/// Other apostolic writings — Hebrews, James, Peter, Jude.
const ntOtherApostolic = <String>[
  'Hebrews', 'James', '1 Peter', '2 Peter', 'Jude',
];

// ── OT sub-corpus groupings (Christian canon order) ─────────────────

const otPentateuch = <String>[
  'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy',
];

const otHistory = <String>[
  'Joshua', 'Judges', 'Ruth', '1 Samuel', '2 Samuel',
  '1 Kings', '2 Kings', '1 Chronicles', '2 Chronicles',
  'Ezra', 'Nehemiah', 'Esther',
];

const otWisdom = <String>[
  'Job', 'Psalms', 'Proverbs', 'Ecclesiastes', 'Song of Solomon',
];

const otMajorProphets = <String>[
  'Isaiah', 'Jeremiah', 'Lamentations', 'Ezekiel', 'Daniel',
];

const otMinorProphets = <String>[
  'Hosea', 'Joel', 'Amos', 'Obadiah', 'Jonah', 'Micah', 'Nahum',
  'Habakkuk', 'Zephaniah', 'Haggai', 'Zechariah', 'Malachi',
];

// ── The canonical divisions, for the book picker's table of contents ─
//
// 2026-09-03: the picker used to render the testament as 39 (or 27)
// identical rounded squares carrying a 1-2 character abbreviation —
// "创 出 利 民 申 书 士 得 …". User, 2026-08-16: 「我怎么看左边那个blocks
// 其实看起来很奇怪」. The reason it reads as a keypad and not as a table
// of contents is that a keypad is exactly what it is: every cell the
// same size, in an order the reader is assumed to already know.
//
// A reader does not scan the canon as 39 equal things. They scan it as
// Law / History / Poetry / Prophets, and inside a division they know
// roughly how long a book is. So the divisions are data, not decoration
// — the picker groups by them and labels each group.
//
// The NT split here is the traditional five (Gospels, Acts, Pauline,
// General, Revelation), NOT the analytical `ntGospelsActs` /
// `ntJohannine` / `ntOtherApostolic` groupings above — those exist for
// the word-distribution table and deliberately overlap. Do not merge
// the two sets; they answer different questions.
class BibleDivision {
  /// Key into `uiStrings` — 'divLaw', 'divHistory', …
  final String id;
  final bool oldTestament;

  /// Canonical ENGLISH titles, in canonical order. Localised titles are
  /// matched through `toEnglish` at the call site, so one table serves
  /// every locale and every version.
  final List<String> books;

  const BibleDivision({
    required this.id,
    required this.oldTestament,
    required this.books,
  });
}

const kBibleDivisions = <BibleDivision>[
  BibleDivision(id: 'divLaw', oldTestament: true, books: otPentateuch),
  BibleDivision(id: 'divHistory', oldTestament: true, books: otHistory),
  BibleDivision(id: 'divWisdom', oldTestament: true, books: otWisdom),
  BibleDivision(
      id: 'divMajorProphets', oldTestament: true, books: otMajorProphets),
  BibleDivision(
      id: 'divMinorProphets', oldTestament: true, books: otMinorProphets),
  BibleDivision(
    id: 'divGospels',
    oldTestament: false,
    books: <String>['Matthew', 'Mark', 'Luke', 'John'],
  ),
  BibleDivision(
    id: 'divActs',
    oldTestament: false,
    books: <String>['Acts'],
  ),
  BibleDivision(id: 'divPauline', oldTestament: false, books: ntPauline),
  BibleDivision(
    id: 'divGeneralEpistles',
    oldTestament: false,
    books: <String>[
      'Hebrews', 'James', '1 Peter', '2 Peter',
      '1 John', '2 John', '3 John', 'Jude',
    ],
  ),
  BibleDivision(
    id: 'divRevelation',
    oldTestament: false,
    books: <String>['Revelation'],
  ),
];

/// Division id for a canonical ENGLISH book title, or null when the
/// table does not know it. Callers must render the unknown ones anyway
/// — a picker that silently drops a book is worse than an ugly one.
String? divisionIdForEnglishBook(String englishTitle) {
  for (final d in kBibleDivisions) {
    if (d.books.contains(englishTitle)) return d.id;
  }
  return null;
}
