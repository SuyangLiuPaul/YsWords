import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'package:yswords/models/sermon.dart';

/// Loads and caches the Pastor Eric sermon corpus.
///
/// The full corpus is 289 sermons × 3 languages = 867 body files
/// (~27 MB). Bundling that as a single JSON would balloon the index
/// load. Instead:
///   - `assets/sermons/index.json` — small (~200 KB) array of metadata
///   - `assets/sermons/<lang>/<id>.txt` — one body file per sermon,
///     loaded on demand the first time the user opens that sermon in
///     that language
///
/// Both layers are cached in memory for the process lifetime; the
/// index in particular only needs to be loaded once on first visit
/// to the Sermons page.
class SermonService {
  SermonService._();
  static final SermonService instance = SermonService._();

  List<Sermon>? _index;
  final Map<String, String> _bodyCache = {};

  /// Load the metadata index, parsing the bundled JSON on first call.
  /// Subsequent calls are O(1).
  Future<List<Sermon>> loadIndex() async {
    if (_index != null) return _index!;
    final raw = await rootBundle.loadString('assets/sermons/index.json');
    final list = json.decode(raw) as List<dynamic>;
    _index = list
        .whereType<Map<String, dynamic>>()
        .map(Sermon.fromJson)
        .toList();
    return _index!;
  }

  /// Group the index by [Sermon.topic], preserving the order in which
  /// topics first appear in the index. Used by the Sermons page to
  /// render collapsible topic groups.
  Future<Map<String, List<Sermon>>> loadByTopic() async {
    final all = await loadIndex();
    final groups = <String, List<Sermon>>{};
    for (final s in all) {
      groups.putIfAbsent(s.topic, () => <Sermon>[]).add(s);
    }
    return groups;
  }

  /// Return a sermon's body text in the requested language, or null
  /// when the sermon doesn't carry a body for that language.
  ///
  /// [lang] is one of `'en'`, `'zh-CN'`, `'zh-TW'`. The asset path is
  /// `assets/sermons/<lang>/<id>.txt`. Misses are cached as the empty
  /// string so we don't re-attempt failed loads on every UI rebuild.
  Future<String?> loadBody({required String id, required String lang}) async {
    final key = '$lang/$id';
    final cached = _bodyCache[key];
    if (cached != null) return cached.isEmpty ? null : cached;
    try {
      final body = await rootBundle.loadString('assets/sermons/$key.txt');
      _bodyCache[key] = body;
      return body;
    } catch (_) {
      _bodyCache[key] = '';
      return null;
    }
  }

  /// Choose the best available body language for a sermon given the
  /// user's preferred [locale] (`'en'`, `'zh-CN'`, `'zh-TW'`).
  /// Falls back across languages so the user always sees something
  /// when only one translation exists for a particular sermon.
  Future<({String lang, String body})?> loadBestBody({
    required Sermon sermon,
    required String locale,
  }) async {
    final fallbacks = <String>[];
    switch (locale) {
      case 'zh-TW':
        fallbacks.addAll(['zh-TW', 'zh-CN', 'en']);
        break;
      case 'zh-CN':
        fallbacks.addAll(['zh-CN', 'zh-TW', 'en']);
        break;
      default:
        fallbacks.addAll(['en', 'zh-CN', 'zh-TW']);
    }
    for (final lang in fallbacks) {
      final has = lang == 'en'
          ? sermon.hasEn
          : lang == 'zh-CN'
              ? sermon.hasZhCn
              : sermon.hasZhTw;
      if (!has) continue;
      final body = await loadBody(id: sermon.id, lang: lang);
      if (body != null && body.trim().isNotEmpty) {
        return (lang: lang, body: body);
      }
    }
    return null;
  }
}
