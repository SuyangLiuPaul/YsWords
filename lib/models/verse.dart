import 'package:flutter/widgets.dart';

@immutable
class Verse {
  final String book;
  final int chapter;
  final int verse;
  final String verseLabel;
  final String text;
  final bool isParagraphStart;
  final String paragraphType;

  const Verse({
    required this.book,
    required this.chapter,
    required this.verse,
    String? verseLabel,
    required this.text,
    this.isParagraphStart = false,
    this.paragraphType = 'inline',
  }) : verseLabel = verseLabel ?? '$verse';

  String get id => '$book-$chapter-$verseLabel';

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
  }) {
    return Verse(
      book: book ?? this.book,
      chapter: chapter ?? this.chapter,
      verse: verse ?? this.verse,
      verseLabel: verseLabel ?? this.verseLabel,
      text: text ?? this.text,
      isParagraphStart: isParagraphStart ?? this.isParagraphStart,
      paragraphType: paragraphType ?? this.paragraphType,
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
    return Verse(
      book: (json['book'] as String?) ?? '',
      chapter: chapterNum,
      verse: verseNum,
      verseLabel: (json['verseLabel'] as String?) ?? verseStr,
      text: (json['text'] as String?) ?? '',
      isParagraphStart: json['isParagraphStart'] as bool? ?? false,
      paragraphType: (json['paragraphType'] as String?) ?? 'inline',
    );
  }
}
