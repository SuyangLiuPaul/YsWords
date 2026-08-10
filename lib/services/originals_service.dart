import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:yswords/models/original_word.dart';
import 'package:yswords/services/versification_service.dart';

/// Lazy loader for the tagged original-language Bible text.
///
/// Per-book JSON lives at `assets/originals/{slug}.json` with the shape
/// `{ "1:1": [{w, s, t?, m?}, ...], ... }`. A book that has no bundled
/// asset (e.g. while we are still rolling out coverage) is cached as an
/// empty map so the second lookup doesn't re-hit the bundle.
class OriginalsService {
  static final Map<String, Map<String, List<OriginalWord>>> _byBook = {};
  static final Map<String, Future<Map<String, List<OriginalWord>>>>
      _loading = {};

  static String _slug(String englishBook) {
    return englishBook
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll("'", '');
  }

  static Future<Map<String, List<OriginalWord>>> _load(String book) async {
    final slug = _slug(book);
    try {
      final raw =
          await rootBundle.loadString('assets/originals/$slug.json');
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final entry in map.entries)
          entry.key: (entry.value as List)
              .map((w) => OriginalWord.fromJson(w as Map<String, dynamic>))
              .toList(growable: false),
      };
    } catch (_) {
      return <String, List<OriginalWord>>{};
    }
  }

  /// The original-language words for a verse **as the reader numbers
  /// it**. The asset is numbered as the Hebrew and Greek editions
  /// number themselves, so the reference is translated first — see
  /// [VersificationService]. Skipping that step showed the reader a
  /// psalm's superscription labelled as verse 1.
  static Future<List<OriginalWord>?> forVerse(
    String englishBook,
    int chapter,
    int verse,
  ) async {
    if (!_byBook.containsKey(englishBook)) {
      _byBook[englishBook] =
          await (_loading[englishBook] ??= _load(englishBook));
    }
    final book = _byBook[englishBook];
    if (book == null) return null;
    final refs =
        await VersificationService.originalRefs(englishBook, chapter, verse);
    final words = [for (final ref in refs) ...?book[ref]];
    if (words.isEmpty) return null;
    return words;
  }

  /// Whether bundled original-language data exists for any verse in
  /// [englishBook]. Useful for showing/hiding the "Original" affordance
  /// without per-verse probing.
  static Future<bool> hasBook(String englishBook) async {
    if (!_byBook.containsKey(englishBook)) {
      _byBook[englishBook] =
          await (_loading[englishBook] ??= _load(englishBook));
    }
    return _byBook[englishBook]?.isNotEmpty ?? false;
  }
}
