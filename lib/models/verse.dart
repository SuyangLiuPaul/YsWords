import 'package:flutter/widgets.dart';
// 2026-05-19 (v1.2.60): import directly from the dependency-free
// `book_names.dart` (not via `fetch_books.dart`, which pulls in
// `MainProvider` → `cloud_sync_service` → `dart:js_interop` and
// blocks any test that touches Verse from compiling on the VM).
import 'package:yswords/constants/book_names.dart';

@immutable
class Verse {
  final String book;
  final int chapter;
  final int verse;
  final String verseLabel;
  final String text;
  final bool isParagraphStart;
  final String paragraphType;

  /// 2026-05-19 (v1.2.57): block-level editorial footnotes that
  /// belong to this verse (e.g. LJK2 Matt 1:16's "16节注：「基督」是
  /// 希伯来语「弥赛亚」的希腊文译音…参约1.41-49"). Rendered as a
  /// small indented paragraph BELOW the verse, distinct from the
  /// inline `<note: …>` popup. Empty list when the verse has no
  /// block notes (the common case across every translation except
  /// LJK2 / biblexg-v2).
  final List<String> blockNotes;

  /// 2026-08-10 (v1.4.37): a psalm superscription — the unnumbered
  /// heading the LEB prints above verse 1 ("A psalm of David at his
  /// fleeing from the presence of Absalom, his son."). It is
  /// scripture, but it is NOT a verse, so it deliberately gets no
  /// verse number and no [id]: numbering it would invent a verse this
  /// translation does not have, and an id would make a highlight on it
  /// collide with a real verse in every other version. It rides on
  /// verse 1 and renders immediately above it. Empty everywhere except
  /// 116 psalms in the LEB.
  final String superscription;

  /// 2026-09-02: reading order among verses that share a [verse] number.
  ///
  /// 梁家鏗譯本 prints 路加福音 23:34 in two halves, and until now the app
  /// showed the publisher's own affix as literal characters in the middle
  /// of 23:33 — `…右手一個，左手一個。34a耶穌說：父親啊…`. Splitting it out
  /// gives two entries that both hold `verse: 34`: the supplied
  /// `verseLabel: '34a'` and the existing `verseLabel: '34'` (which is
  /// really 34b). `compareTo` on the number alone returns 0 for that pair,
  /// and **Dart's sort is not stable**, so without an explicit ordinal the
  /// two halves could render in either order.
  ///
  /// 0 for every verse in every other edition, which is why it is not
  /// simply the array index: a default of 0 keeps 31,102 unchanged verses
  /// out of the asset, and only the second half of Luke 23:34 carries a 1.
  final int subVerseOrder;

  const Verse({
    required this.book,
    required this.chapter,
    required this.verse,
    String? verseLabel,
    required this.text,
    this.isParagraphStart = false,
    this.paragraphType = 'inline',
    this.blockNotes = const [],
    this.superscription = '',
    this.subVerseOrder = 0,
  }) : verseLabel = verseLabel ?? '$verse';

  // Always use the English book name so the ID is the same regardless of
  // which translation is loaded — enables cross-version highlight persistence.
  String get id {
    final en = bookNameToEnglish[book] ?? book;
    return '$en-$chapter-$verseLabel';
  }

  /// Returns a new Verse with the given fields replaced.
  /// Used to apply cross-version paragraph metadata after JSON parsing.
  Verse copyWith({
    String? book,
    int? chapter,
    int? verse,
    String? verseLabel,
    String? text,
    bool? isParagraphStart,
    String? paragraphType,
    List<String>? blockNotes,
    String? superscription,
    int? subVerseOrder,
  }) {
    return Verse(
      book: book ?? this.book,
      chapter: chapter ?? this.chapter,
      verse: verse ?? this.verse,
      verseLabel: verseLabel ?? this.verseLabel,
      text: text ?? this.text,
      isParagraphStart: isParagraphStart ?? this.isParagraphStart,
      paragraphType: paragraphType ?? this.paragraphType,
      blockNotes: blockNotes ?? this.blockNotes,
      superscription: superscription ?? this.superscription,
      subVerseOrder: subVerseOrder ?? this.subVerseOrder,
    );
  }

  // Factory constructor to create a Verse object from a JSON map
  factory Verse.fromJson(Map<String, dynamic> json) {
    final chapterStr = json['chapter']?.toString() ?? '';
    final verseStr = json['verse']?.toString() ?? '';
    final chapterNum = int.tryParse(chapterStr);
    final verseNum = int.tryParse(verseStr);
    if (chapterNum == null || verseNum == null) {
      throw FormatException(
          'Skipping non-numeric entry: chapter="$chapterStr", verse="$verseStr"');
    }
    // 2026-05-19 (v1.2.57): blockNotes parses as List<String>. Tolerant:
    // accepts null / missing (most versions have none) and also tolerates
    // a single string by wrapping it.
    final blockNotesRaw = json['blockNotes'];
    final List<String> blockNotes;
    if (blockNotesRaw is List) {
      blockNotes = blockNotesRaw.map((e) => e.toString()).toList();
    } else if (blockNotesRaw is String && blockNotesRaw.isNotEmpty) {
      blockNotes = [blockNotesRaw];
    } else {
      blockNotes = const [];
    }
    return Verse(
      book: (json['book'] as String?) ?? '',
      chapter: chapterNum,
      verse: verseNum,
      verseLabel: (json['verseLabel'] as String?) ?? verseStr,
      text: (json['text'] as String?) ?? '',
      isParagraphStart: json['isParagraphStart'] as bool? ?? false,
      paragraphType: (json['paragraphType'] as String?) ?? 'inline',
      blockNotes: blockNotes,
      superscription: (json['superscription'] as String?) ?? '',
      subVerseOrder: (json['subVerseOrder'] as num?)?.toInt() ?? 0,
    );
  }
}
