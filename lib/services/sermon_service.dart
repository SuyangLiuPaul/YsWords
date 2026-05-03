import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'package:yswords/models/sermon.dart';

/// Reverse-index payload loaded from `assets/sermons/refs.json`.
/// `byVerse` maps a canonical "Book chapter[:verse]" string to the
/// list of sermon ids that cite it; `bySermon` is the inverse.
class SermonRefs {
  final Map<String, List<String>> byVerse;
  final Map<String, List<String>> bySermon;
  const SermonRefs({required this.byVerse, required this.bySermon});

  bool get isEmpty => byVerse.isEmpty && bySermon.isEmpty;
}

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

  /// Cached reverse index from `assets/sermons/refs.json` — the
  /// output of `scripts/extract_sermon_refs.py`. Populated lazily on
  /// first call to [loadRefs] and shared across the rest of the
  /// service so both surfaces (sermon-detail body links + bible-pane
  /// "related sermons" chip) hit the same data.
  SermonRefs? _refs;

  /// Reverse index from "Book chapter[:verse]" → list of sermon ids,
  /// plus the inverse list per sermon. Loaded once per process.
  Future<SermonRefs> loadRefs() async {
    final cached = _refs;
    if (cached != null) return cached;
    try {
      final raw = await rootBundle.loadString('assets/sermons/refs.json');
      final j = json.decode(raw) as Map<String, dynamic>;
      final byVerse = <String, List<String>>{};
      final byVerseRaw = j['byVerse'] as Map<String, dynamic>? ?? {};
      byVerseRaw.forEach((k, v) {
        byVerse[k] = (v as List).cast<String>();
      });
      final bySermon = <String, List<String>>{};
      final bySermonRaw = j['bySermon'] as Map<String, dynamic>? ?? {};
      bySermonRaw.forEach((k, v) {
        bySermon[k] = (v as List).cast<String>();
      });
      _refs = SermonRefs(byVerse: byVerse, bySermon: bySermon);
    } catch (_) {
      // Refs file missing / corrupt — degrade gracefully (no chips,
      // no body links). Cache the empty index so we don't re-parse
      // on every UI rebuild.
      _refs = const SermonRefs(byVerse: {}, bySermon: {});
    }
    return _refs!;
  }

  /// Sermons whose body or passage hint cites the given canonical
  /// reference (`"Romans 8:1"`, `"Matthew 24"`). Resolves to actual
  /// `Sermon` objects via the loaded index. Returns empty when no
  /// match or when refs aren't loaded yet.
  Future<List<Sermon>> sermonsForReference(String canonical) async {
    final refs = await loadRefs();
    final all = await loadIndex();
    final ids = refs.byVerse[canonical];
    if (ids == null || ids.isEmpty) return const [];
    final byId = {for (final s in all) s.id: s};
    return [for (final id in ids) if (byId[id] != null) byId[id]!];
  }

  /// All verse references known for one sermon — used by the sermon
  /// detail page to make those refs tappable.
  Future<List<String>> referencesInSermon(String sermonId) async {
    final refs = await loadRefs();
    return refs.bySermon[sermonId] ?? const [];
  }

  /// Sermons that cite ANY verse in the same chapter as the given
  /// (book, chapter, verse). Uses chapter-level matching because:
  ///
  ///   1. A sermon's natural unit is the chapter, not the verse — a
  ///      sermon expounding Genesis 1:1-5 is just as relevant when
  ///      the user has selected Genesis 1:7 as when they've selected
  ///      Genesis 1:1. Verse-exact matching (the previous semantic)
  ///      meant most sermons were invisible: the refs index records
  ///      the verses *cited* in the body, but the user might be
  ///      reading any verse of that chapter.
  ///   2. Cross-version / cross-language coverage: every Bible
  ///      version uses the same chapter numbering, so chapter-level
  ///      lookup is robust regardless of whether the user is reading
  ///      ESV, NIV, CUVS-YHWH, LJK1/2 or anything else.
  ///
  /// Verse exactness is preserved as a *priority signal*: sermons
  /// whose refs include the exact `englishBook chapter:verse` come
  /// first in the returned list; chapter-only matches follow.
  Future<List<Sermon>> sermonsForVerse({
    required String englishBook,
    required int chapter,
    required int verse,
  }) async {
    final refs = await loadRefs();
    final all = await loadIndex();
    final byId = {for (final s in all) s.id: s};
    final exactVerseKey = '$englishBook $chapter:$verse';
    final wholeChapterKey = '$englishBook $chapter';
    final chapterPrefix = '$englishBook $chapter:';
    final exactHits = <Sermon>{};
    final chapterHits = <Sermon>{};
    refs.byVerse.forEach((key, ids) {
      bool exact = false;
      bool chapterMatch = false;
      if (key == exactVerseKey) {
        exact = true;
      } else if (key == wholeChapterKey || key.startsWith(chapterPrefix)) {
        chapterMatch = true;
      }
      if (!exact && !chapterMatch) return;
      for (final id in ids) {
        final s = byId[id];
        if (s == null) continue;
        if (exact) {
          exactHits.add(s);
        } else {
          chapterHits.add(s);
        }
      }
    });
    final out = <Sermon>[];
    out.addAll(exactHits);
    for (final s in chapterHits) {
      if (!exactHits.contains(s)) out.add(s);
    }
    return out;
  }

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
