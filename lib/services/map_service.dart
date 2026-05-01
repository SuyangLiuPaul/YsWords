import 'dart:convert';
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

  static void clearCache() {
    _cache = null;
  }
}
