import 'package:flutter/foundation.dart';

@immutable
class BibleMap {
  final String id;
  final Map<String, String> title;
  final Map<String, String> description;
  final Map<String, List<int>> books;
  final String file;
  /// Illustration category: 'map' (default, geographic), 'scene'
  /// (narrative painting / event), 'parable' (parable illustration),
  /// 'prophecy' (apocalyptic / vision imagery), 'genealogy'.
  /// Renamed user-facing label is "Illustrations" — see ui_strings.dart.
  final String kind;

  const BibleMap({
    required this.id,
    required this.title,
    required this.description,
    required this.books,
    required this.file,
    this.kind = 'map',
  });

  factory BibleMap.fromJson(Map<String, dynamic> json) {
    final rawBooks = json['books'] as Map<String, dynamic>? ?? {};
    final books = <String, List<int>>{};
    for (final entry in rawBooks.entries) {
      final list = (entry.value as List).cast<int>();
      books[entry.key] = list;
    }

    return BibleMap(
      id: json['id'] as String? ?? '',
      title: (json['title'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, v as String? ?? '')),
      description: (json['description'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, v as String? ?? '')),
      books: books,
      file: json['file'] as String? ?? '',
      kind: json['kind'] as String? ?? 'map',
    );
  }

  bool matchesBookChapter(String englishBook, int chapter) {
    final range = books[englishBook];
    if (range == null || range.length != 2) return false;
    return chapter >= range[0] && chapter <= range[1];
  }

  String localizedTitle(String locale) =>
      title[locale] ?? title['en'] ?? id;

  String localizedDescription(String locale) =>
      description[locale] ?? description['en'] ?? '';
}
