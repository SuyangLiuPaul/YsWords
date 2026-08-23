import 'package:yswords/utils/reference_parser.dart';

/// The passage the Sermons list is filtered to, carried into the
/// sermon so the same passage can be highlighted where it appears.
///
/// 2026-08-23, from the user: "I filtered John 17 … I am wondering if
/// it is possible to have yellow highlight whenever John 17 appears
/// inside that specific sermon", and then "Right now, you only have the
/// chapter. Wonder whether it is possible to have also the verses."
///
/// Filtering to a passage and then hunting for it by eye through a
/// forty-minute sermon is the part that was missing: the list knew
/// exactly why each sermon qualified and then threw that away at the
/// moment the reader opened one.
class PassageFilter {
  /// Canonical English book name, as stored in the refs index and in
  /// [BibleReference.englishBook]. Never a localized name.
  final String book;

  /// Null means "anywhere in this book".
  final int? chapter;

  /// Null means "anywhere in this chapter". Only meaningful with a
  /// [chapter].
  final int? verse;

  const PassageFilter(this.book, {this.chapter, this.verse});

  bool get isWholeBook => chapter == null;

  PassageFilter withChapter(int? c) =>
      PassageFilter(book, chapter: c, verse: c == null ? null : verse);

  PassageFilter withVerse(int? v) =>
      PassageFilter(book, chapter: chapter, verse: v);

  /// Does a key from `refs.json` fall inside this filter?
  ///
  /// Keys are either `"John 17"` — the sermon cites the whole chapter —
  /// or `"John 17:3"`. There are no ranges in the index; the extractor
  /// writes one key per verse.
  ///
  /// A whole-chapter key satisfies a verse-level filter. Someone who
  /// preached through all of John 17 preached verse 3, and hiding that
  /// sermon from a "John 17:3" filter would be losing the best match in
  /// the corpus on a technicality.
  bool matchesRefKey(String key) {
    if (!key.startsWith('$book ')) return false;
    final tail = key.substring(book.length + 1);
    if (chapter == null) return true;

    final colon = tail.indexOf(':');
    final chPart = colon == -1 ? tail : tail.substring(0, colon);
    if (int.tryParse(chPart.trim()) != chapter) return false;
    if (verse == null) return true;
    if (colon == -1) return true; // whole-chapter citation — see above
    return int.tryParse(tail.substring(colon + 1).trim()) == verse;
  }

  /// Does a reference parsed out of a sermon's body fall inside this
  /// filter — i.e. should it be highlighted?
  ///
  /// Unlike [matchesRefKey] this sees ranges and verse lists, because
  /// the body says "John 17:20-23" where the index has stored four
  /// separate keys.
  bool covers(BibleReference ref) {
    if (ref.englishBook != book) return false;
    if (chapter == null) return true;
    if (ref.chapter != chapter) return false;
    if (verse == null) return true;

    // The body cites the whole chapter, which includes this verse.
    if (ref.isWholeChapter) return true;
    if (ref.hasExplicitVerses) return ref.verses.contains(verse);
    final start = ref.verseStart;
    if (start == null) return true;
    final end = ref.verseEnd ?? start;
    return verse! >= start && verse! <= end;
  }

  @override
  bool operator ==(Object other) =>
      other is PassageFilter &&
      other.book == book &&
      other.chapter == chapter &&
      other.verse == verse;

  @override
  int get hashCode => Object.hash(book, chapter, verse);

  @override
  String toString() => chapter == null
      ? book
      : verse == null
          ? '$book $chapter'
          : '$book $chapter:$verse';
}
