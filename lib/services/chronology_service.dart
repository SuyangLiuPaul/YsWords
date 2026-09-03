import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'package:yswords/models/chronology.dart';

/// Loads `assets/bible_chronology.json` — the lifeline layer behind the
/// chronology chart — and caches it for the process lifetime, matching
/// `TimelineService`.
class ChronologyService {
  ChronologyService._();
  static final ChronologyService instance = ChronologyService._();

  ChronologyData? _cache;

  Future<ChronologyData> load() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/bible_chronology.json');
    final j = json.decode(raw) as Map<String, dynamic>;
    final data = ChronologyData.fromJson(j);
    _cache = data;
    return data;
  }

  /// Test seam — lets a widget test hand in parsed data without going
  /// through the asset bundle.
  void primeForTest(ChronologyData data) => _cache = data;
}
