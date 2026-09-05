import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:yswords/models/bible_map.dart';

class MapService {
  static List<BibleMap>? _cache;
  static Future<List<BibleMap>>? _loading;

  static Future<List<BibleMap>> loadMaps() {
    if (_cache != null) return Future.value(_cache!);
    _loading ??= _doLoad();
    return _loading!;
  }

  static Future<List<BibleMap>> _doLoad() async {
    final jsonString = await rootBundle.loadString('assets/maps_index.json');
    final list = jsonDecode(jsonString) as List;
    _cache = list
        .map((e) => BibleMap.fromJson(e as Map<String, dynamic>))
        .toList();
    return _cache!;
  }

  static List<BibleMap> get cached => _cache ?? [];

  static Future<List<BibleMap>> mapsForBookChapter(
      String englishBook, int chapter) async {
    final all = await loadMaps();
    return all.where((m) => m.matchesBookChapter(englishBook, chapter)).toList();
  }

  /// All maps that mention the given book, regardless of chapter range.
  /// Used as a fallback when no chapter-specific map matches — e.g. on
  /// Acts 22 we still want to surface Paul's journeys / NT World.
  static Future<List<BibleMap>> mapsForBook(String englishBook) async {
    final all = await loadMaps();
    return all.where((m) => m.books.containsKey(englishBook)).toList();
  }

  /// True when this entry is a genuine CHAPTER illustration — a scene,
  /// a parable, a teaching plate — rather than a geographic survey map.
  ///
  /// 2026-09-05: the illustration sheet's "For this chapter" tab was
  /// claiming more than it could deliver. Matching is `book + chapter
  /// within [start, end]` ([BibleMap.matchesBookChapter]) and the 55
  /// bundled survey maps carry WHOLE-BOOK ranges — "Jerusalem — Old
  /// City" is tagged `Psalms: [1, 150]`, so Psalms 119 was offered a
  /// street plan of the Old City, and Ezekiel 18 (individual moral
  /// responsibility, no geography at all) was offered nothing but
  /// "Babylonian Empire" and "Western Palestine — OT Survey".
  /// Measured over the real index: 5899 of 7602 (chapter, image)
  /// display pairs — 77.6% — came from ranges wider than 3 chapters,
  /// and 5843 of those were the 55 survey maps. The tab was never
  /// empty for any of the 1189 chapters, which is why the sheet's
  /// own "no illustration for this chapter" strings were dead code.
  ///
  /// The signal is [BibleMap.kind], not [BibleMap.source] and not the
  /// range width:
  ///   - `kind` is the only SEMANTIC field: 'scene' / 'parable' /
  ///     'teaching' say the picture depicts something happening in
  ///     the text; the default 'map' says it is a survey plate. That
  ///     is exactly the distinction the tab label promises.
  ///   - `source` ('asset' vs 'cdn') partitions the index identically
  ///     TODAY — all 55 survey maps are bundled, all 1137 paintings
  ///     are remote — but it records where a file is HOSTED, i.e.
  ///     migration state. Bundling one painting, or moving one map to
  ///     the CDN, would flip the classification with no change in
  ///     meaning.
  ///   - range width is measurably wrong. Six book-ranges belonging to
  ///     real paintings are wider than 3 chapters (Tissot's Saint
  ///     Philip `John [1, 14]`, Saint Peter `Matthew [4, 16]`, Saint
  ///     Thomas `John [11, 20]`, Saint John the Evangelist `John
  ///     [13, 21]`, and both Farewell Discourse plates `John
  ///     [13, 17]`). No width threshold separates those from `Psalms
  ///     [1, 150]` without demoting genuine artwork.
  ///
  /// What this DOES misclassify, on purpose: `kind` defaults to 'map'
  /// when the field is absent, so any future index entry that forgets
  /// to declare a kind is demoted to the "For this book" tab. That is
  /// the safe direction — the app under-promises rather than showing
  /// a confident count it cannot back — but a new painting that shows
  /// up only in the related tab is the first thing to check.
  /// It also keeps the six wide painting ranges above in the chapter
  /// tab: broad, but real artwork about a figure who genuinely
  /// appears in those chapters, which is what the tab claims.
  static bool isChapterIllustration(BibleMap m) => m.kind != 'map';

  /// Chapter matches, narrowed to genuine chapter illustrations.
  static Future<List<BibleMap>> chapterIllustrationsFor(
      String englishBook, int chapter) async {
    final matches = await mapsForBookChapter(englishBook, chapter);
    return matches.where(isChapterIllustration).toList();
  }

  /// The exact split the illustration sheet renders, as a pure
  /// function so it can be tested without pumping the reader.
  ///
  /// [chapterMatches] is the output of [mapsForBookChapter];
  /// [bookMatches] the output of [mapsForBook]. Survey maps that
  /// matched the chapter are DEMOTED into [ChapterIllustrations.book]
  /// rather than dropped — they are already in [bookMatches] (a
  /// chapter match implies the book key is present), and the
  /// subtraction below is by id, so nothing vanishes and nothing is
  /// listed twice.
  static ChapterIllustrations partition({
    required List<BibleMap> chapterMatches,
    required List<BibleMap> bookMatches,
  }) {
    final chapter = chapterMatches.where(isChapterIllustration).toList();
    final book = bookMatches
        .where((m) => !chapter.any((c) => c.id == m.id))
        .toList();
    return ChapterIllustrations(chapter: chapter, book: book);
  }

  static void clearCache() {
    _cache = null;
  }
}

/// What the illustration sheet shows for one (book, chapter).
@immutable
class ChapterIllustrations {
  /// The "For this chapter" tab — genuine chapter artwork only.
  final List<BibleMap> chapter;

  /// The "For this book" tab — everything else that mentions this
  /// book, including survey maps demoted out of [chapter].
  final List<BibleMap> book;

  const ChapterIllustrations({required this.chapter, required this.book});

  /// The chapter tab renders "No illustrations for this chapter".
  bool get chapterTabIsEmpty => chapter.isEmpty;

  /// The book tab renders the "no illustration specifically for this
  /// chapter — here are related ones" note above its list.
  bool get showsFallbackNote => chapter.isEmpty && book.isNotEmpty;
}
