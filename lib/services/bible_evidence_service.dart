import 'package:yswords/models/bible_evidence.dart';
import 'package:yswords/services/remote_data_service.dart';

/// Bundle wrapper so we can fit `BibleEvidence` data into the
/// [RemoteDataService] base class (which expects a generic `T`).
/// Existing callers operate on `List<BibleEvidence>`, so we keep the
/// public façade the same and unwrap inside the service.
class _EvidenceBundle {
  final List<BibleEvidence> entries;
  final DateTime? generatedAt;
  const _EvidenceBundle(this.entries, this.generatedAt);
}

class _BibleEvidenceServiceImpl extends RemoteDataService<_EvidenceBundle> {
  static const String _defaultRemote =
      'https://yswords-data.netlify.app/data/bible_evidence.json';

  static const String _envUrl = String.fromEnvironment(
    'BIBLE_EVIDENCE_URL',
    defaultValue: _defaultRemote,
  );

  @override
  String get bundledAssetPath => 'assets/bible_evidence.json';

  @override
  String get remoteUrl => _envUrl;

  /// `v2` because this round flattens paragraph-array fields into
  /// strings — old `v1` cached payloads from before the model fix
  /// could contain bracketed-list strings rendered to the user.
  @override
  String get cachePrefsKey => 'bibleEvidence.cachedJson.v2';

  @override
  _EvidenceBundle parse(Map<String, dynamic> json) {
    final entries = (json['evidences'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => BibleEvidence.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final meta = json['_meta'];
    DateTime? gen;
    if (meta is Map) {
      final s = meta['generatedAt'];
      if (s is String) gen = DateTime.tryParse(s);
    }
    return _EvidenceBundle(entries, gen);
  }

  @override
  DateTime? generatedAt(_EvidenceBundle bundle) => bundle.generatedAt;
}

/// Lazy loader + index for the Biblical Evidence Archive.
///
/// Source of truth: the central yswords-data site
/// (`https://yswords-data.netlify.app/data/bible_evidence.json`).
/// On first call we read the bundled snapshot from
/// `assets/bible_evidence.json`, then refresh from the network in
/// the background. The next caller sees the freshest copy. Override
/// the URL via `--dart-define=BIBLE_EVIDENCE_URL=…`.
class BibleEvidenceService {
  static final _BibleEvidenceServiceImpl _impl =
      _BibleEvidenceServiceImpl();

  /// Returns the cached entry list. Triggers a background refresh.
  static Future<List<BibleEvidence>> all() async {
    final b = await _impl.load();
    return b.entries;
  }

  static Future<void> refresh() => _impl.refresh();
  static Future<void> clearCache() => _impl.clearCache();

  /// Free-text search across title / summary / location / scripture
  /// reference / Bible books in the supplied [locale]. Case-
  /// insensitive substring match.
  static List<BibleEvidence> search(
      List<BibleEvidence> source, String query, String locale) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return source;
    return source.where((e) {
      final hay = [
        e.localizedTitle(locale),
        e.localizedSummary(locale),
        e.location,
        e.scriptureReference,
        e.bibleBooks.join(' '),
        e.category,
      ].join(' ').toLowerCase();
      return hay.contains(q);
    }).toList();
  }

  /// Return entries whose [scriptureReference] is in [book] (case-
  /// sensitive English book name) — used to surface "Evidence for
  /// this chapter" inside the reader.
  static List<BibleEvidence> forBook(
      List<BibleEvidence> source, String englishBook) {
    return source
        .where((e) =>
            e.scriptureReference
                .toLowerCase()
                .startsWith(englishBook.toLowerCase()) ||
            e.bibleBooks.contains(englishBook))
        .toList();
  }

  /// Picks today's "Daily Evidence" deterministically by day-of-year,
  /// like the daily-verse rotation. Two devices on the same calendar
  /// day see the same one.
  static BibleEvidence? todayEvidence(List<BibleEvidence> source,
      {DateTime? now}) {
    if (source.isEmpty) return null;
    final n = now ?? DateTime.now();
    final start = DateTime(n.year, 1, 1);
    final dayOfYear = n.difference(start).inDays;
    return source[dayOfYear % source.length];
  }
}
