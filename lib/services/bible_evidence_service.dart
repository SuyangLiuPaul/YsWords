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

  /// 2026-06-12 (v1.3.63 perf): the evidence archive is a static-ish
  /// 225-entry corpus that changes maybe monthly, yet the dashboard's
  /// single "Today's Evidence" card used to re-download the whole
  /// ~420 KB dataset from yswords-data on EVERY cold start. Throttle
  /// the background refresh to twice a day; the bundled/cached copy
  /// still loads instantly, and the Evidence page's pull-to-refresh
  /// forces a fresh pull.
  @override
  Duration get minRefreshInterval => const Duration(hours: 12);

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

  /// Explicit refresh (e.g. Evidence-page pull-to-refresh) — always
  /// hits the network, bypassing the [minRefreshInterval] throttle.
  static Future<void> refresh() => _impl.refresh(force: true);
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

  /// Single-chapter books, where references like "Jude 14-15" mean
  /// verses 14-15 of the only chapter — NOT chapters 14 to 15. Used to
  /// disambiguate the parser's output before chapter matching.
  static const Set<String> _singleChapterBooks = {
    'Obadiah',
    'Philemon',
    '2 John',
    '3 John',
    'Jude',
  };

  /// Return entries whose [scriptureReference] covers the specific
  /// [chapter] of [englishBook]. Honours chapter ranges in references
  /// like "Genesis 6-9" or "Genesis 1:1-2:3".
  ///
  /// Was the reason "Evidence for this chapter" used to show pictures
  /// from chapters the user wasn't reading: the previous filter only
  /// matched the BOOK (so reading Genesis 1 showed a Mt-Sinai entry
  /// belonging to Exodus 19's territory). Now we narrow to the actual
  /// chapter when the reference is precise enough; entries whose
  /// reference is just the book name (no chapter) still match every
  /// chapter, which is the right thing for archive-wide finds like
  /// the Dead Sea Scrolls or Multiple-Books archaeological eras.
  static List<BibleEvidence> forChapter(
      List<BibleEvidence> source, String englishBook, int chapter) {
    final bookFiltered = forBook(source, englishBook);
    final singleChapterBook = _singleChapterBooks.contains(englishBook);
    return bookFiltered.where((e) {
      // Single-chapter books: any reference is implicitly "chapter 1".
      // The parser would otherwise misread "Jude 14-15" as a chapter
      // range (chapters 14-15) instead of verses 14-15 of the only
      // chapter.
      if (singleChapterBook) return chapter == 1;

      final chapters = chaptersInReference(e.scriptureReference);
      // No parseable chapter info → treat as book-wide match.
      if (chapters.isEmpty) return true;
      return chapters.contains(chapter);
    }).toList();
  }

  /// Parse the chapter (or chapter range) out of a scripture reference
  /// string. Returns the inclusive list of chapter numbers covered,
  /// or empty when no chapter is parseable (e.g. "Multiple Books").
  ///
  /// Handles every format observed in the 225-entry corpus:
  ///   "Isaiah 40:8"                -> [40]
  ///   "2 Samuel 7:11-16"           -> [7]     (verse range tail ignored)
  ///   "Genesis 1:1-2:3"            -> [1, 2]  (cross-chapter range)
  ///   "John 18:31-33, 37-38"       -> [18]    (two verse spans, one ch)
  ///   "Acts 19:11-20, 23-41"       -> [19]
  ///   "1 Samuel 17:1-3, 52"        -> [17]
  ///   "Exodus 14:21-22; 1 Kings 5-7" -> [14]  (multi-book; first ch wins)
  ///   "Numbers 22-24"              -> [22, 23, 24]
  ///   "Leviticus 23"               -> [23]
  ///   "Multiple Books"             -> []
  ///
  /// Strategy:
  /// - If the string has any "chapter:verse" pair (the colon disambiguates
  ///   chapter prefixes from verse ranges), enumerate every such pair and
  ///   return the inclusive range from the smallest to the largest chapter
  ///   prefix. Verse-only dashes ("31-33") never match `\d+:\d+`, so they
  ///   can't accidentally pollute the chapter set.
  /// - Otherwise, fall through to bare chapter / chapter-range parsing
  ///   ("Numbers 22-24" -> [22..24]).
  static List<int> chaptersInReference(String reference) {
    if (reference.isEmpty) return const [];

    if (reference.contains(':')) {
      final chapters = RegExp(r'(\d+):\d+')
          .allMatches(reference)
          .map((m) => int.tryParse(m.group(1) ?? ''))
          .whereType<int>()
          .toList();
      if (chapters.isEmpty) return const [];
      final lo = chapters.reduce((a, b) => a < b ? a : b);
      final hi = chapters.reduce((a, b) => a > b ? a : b);
      return [for (var i = lo; i <= hi; i++) i];
    }

    // No colon → bare chapter or chapter range.
    final range = RegExp(r'(\d+)-(\d+)\s*$').firstMatch(reference);
    if (range != null) {
      final first = int.tryParse(range.group(1) ?? '');
      final second = int.tryParse(range.group(2) ?? '');
      if (first != null && second != null && second >= first) {
        return [for (var i = first; i <= second; i++) i];
      }
    }
    final single = RegExp(r'(\d+)\s*$').firstMatch(reference);
    if (single != null) {
      final first = int.tryParse(single.group(1) ?? '');
      if (first != null) return [first];
    }
    return const [];
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
