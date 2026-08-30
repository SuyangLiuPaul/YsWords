/// Last chapter number for each of the 66 canonical books, from the
/// union of the three shipped English Bibles (`assets/kjv.json`,
/// `assets/nasb.json`, `assets/leb.json`) — the same ruler
/// `test/citation_target_in_canon_test.dart` already uses for verse
/// bounds. All three carry the same 66 books and the same 1,189
/// chapters (re-derived and pinned in `test/canon_chapters_test.dart`,
/// which fails if a bundled asset ever disagrees with this table).
///
/// GENERATED from the assets, not hand-typed — see the test above for
/// how to re-derive it if a Bible asset changes.
const Map<String, int> canonLastChapter = {
  'Genesis': 50,
  'Exodus': 40,
  'Leviticus': 27,
  'Numbers': 36,
  'Deuteronomy': 34,
  'Joshua': 24,
  'Judges': 21,
  'Ruth': 4,
  '1 Samuel': 31,
  '2 Samuel': 24,
  '1 Kings': 22,
  '2 Kings': 25,
  '1 Chronicles': 29,
  '2 Chronicles': 36,
  'Ezra': 10,
  'Nehemiah': 13,
  'Esther': 10,
  'Job': 42,
  'Psalms': 150,
  'Proverbs': 31,
  'Ecclesiastes': 12,
  'Song of Solomon': 8,
  'Isaiah': 66,
  'Jeremiah': 52,
  'Lamentations': 5,
  'Ezekiel': 48,
  'Daniel': 12,
  'Hosea': 14,
  'Joel': 3,
  'Amos': 9,
  'Obadiah': 1,
  'Jonah': 4,
  'Micah': 7,
  'Nahum': 3,
  'Habakkuk': 3,
  'Zephaniah': 3,
  'Haggai': 2,
  'Zechariah': 14,
  'Malachi': 4,
  'Matthew': 28,
  'Mark': 16,
  'Luke': 24,
  'John': 21,
  'Acts': 28,
  'Romans': 16,
  '1 Corinthians': 16,
  '2 Corinthians': 13,
  'Galatians': 6,
  'Ephesians': 6,
  'Philippians': 4,
  'Colossians': 4,
  '1 Thessalonians': 5,
  '2 Thessalonians': 3,
  '1 Timothy': 6,
  '2 Timothy': 4,
  'Titus': 3,
  'Philemon': 1,
  'Hebrews': 13,
  'James': 5,
  '1 Peter': 5,
  '2 Peter': 3,
  '1 John': 5,
  '2 John': 1,
  '3 John': 1,
  'Jude': 1,
  'Revelation': 22,
};

/// Whether [chapter] is a chapter that actually exists in [englishBook]
/// (the canonical name `resolveBookName` returns). Chapter-level only —
/// deliberately not verse-level: the shipped versions disagree on where
/// five chapters end (see `citation_target_in_canon_test.dart`), so a
/// verse bound taken from one of them would refuse a citation a reader
/// really can open. Chapter counts do not have that problem.
///
/// An [englishBook] this table doesn't recognise returns true (fails
/// open) rather than refusing a reference this check has no opinion
/// about — every book `resolveBookName` can produce is in the table,
/// so this only matters if that ever stops being true.
bool chapterExistsInCanon(String englishBook, int chapter) {
  final last = canonLastChapter[englishBook];
  if (last == null) return true;
  return chapter >= 1 && chapter <= last;
}
