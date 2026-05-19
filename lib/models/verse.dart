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

  const Verse({
    required this.book,
    required this.chapter,
    required this.verse,
    String? verseLabel,
    required this.text,
    this.isParagraphStart = false,
    this.paragraphType = 'inline',
    this.blockNotes = const [],
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
    );
  }
}
