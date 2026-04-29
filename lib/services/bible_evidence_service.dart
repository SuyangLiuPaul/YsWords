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
  /// Handles all of these formats observed in the corpus:
  ///   "Isaiah 40:8"           -> [40]
  ///   "2 Samuel 7:11-16"      -> [7]            (verse range, single ch)
  ///   "Genesis 1:1-2:3"       -> [1, 2]         (multi-chapter range)
  ///   "Numbers 22-24"         -> [22, 23, 24]
  ///   "Leviticus 23"          -> [23]
  ///   "Multiple Books"        -> []             (no parseable number)
  ///
  /// Branches on whether the reference contains a colon. With a colon
  /// the dashed tail can be either verses ("7:11-16" → still ch 7) or
  /// a multi-chapter range ("1:1-2:3" → chs 1 + 2). Without a colon
  /// any dashed tail is unambiguously a chapter range.
  static List<int> chaptersInReference(String reference) {
    if (reference.isEmpty) return const [];

    if (reference.contains(':')) {
      // Try a cross-chapter colon range first: "1:1-2:3".
      final cross = RegExp(r'(\d+):\d+-(\d+):\d+\s*$').firstMatch(reference);
      if (cross != null) {
        final first = int.tryParse(cross.group(1) ?? '');
        final second = int.tryParse(cross.group(2) ?? '');
        if (first != null && second != null && second >= first) {
          return [for (var i = first; i <= second; i++) i];
        }
      }
      // Single chapter:verse, optionally with a verse range
      // ("Isaiah 40:8", "2 Samuel 7:11-16"). The verse range tail is
      // intentionally ignored — those still resolve to one chapter.
      final single = RegExp(r'(\d+):\d+(?:-\d+)?\s*$').firstMatch(reference);
      if (single != null) {
        final first = int.tryParse(single.group(1) ?? '');
        if (first != null) return [first];
      }
      return const [];
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
