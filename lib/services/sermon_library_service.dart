import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;

import 'package:yswords/models/library_sermon.dart';

/// Reads one text file out of the sermon library.
///
/// [path] is always relative to the library root — `index.json`,
/// `refs.json`, `bodies/2444.txt` — never a full asset key. See
/// [SermonLibraryService.libraryRoot].
typedef LibraryTextLoader = Future<String> Function(String path);

/// The only duplicate tier this app acts on.
///
/// `refs.json`'s `duplicates.crossCorpus` grades every candidate pair
/// `confirmed` | `probable` | `possible` | `weak`. Only the first is
/// established; a separate pass is adjudicating the other 83 and will
/// promote or refute them in the same file, so everything here reads
/// the word at load time and nothing enumerates ids.
///
/// **Nothing is ever hidden, at any tier.** The rule that survives
/// every version of this question is the asymmetry: a record wrongly
/// shown is a duplicate a reader can see and complain about, and a
/// record wrongly hidden is a sermon that silently ceases to exist,
/// on no screen, with nobody to notice. So an unknown tier, a missing
/// tier and a missing `refs.json` all mean the same thing — show the
/// record — and the only thing `confirmed` buys is a LINK between the
/// two texts, which is information rather than a deletion.
const String kDuplicateTierConfirmed = 'confirmed';

/// One `duplicates.crossCorpus` row: this library record and the
/// sermon in `assets/sermons/` that is the same sermon.
///
/// **Not detected here, and it must not be.** Title matching finds 10
/// of these; matching on the scripture each sermon actually expounds
/// finds 105 candidates, 97 of them invisible to a title comparison —
/// library 4249「舍己：门徒的标记」 pairs with app 062「施与，成为世上
/// 的光」on a title similarity of about zero and a chapter Jaccard of
/// 0.929. Text similarity cannot rescue a title matcher either: these
/// are independent transcriptions rather than copies, and 6-gram
/// containment peaks at 0.153 across all pairs. So the grading is
/// produced upstream, with evidence, and read from here.
class LibraryDuplicatePair {
  /// The library record's post id.
  final int libId;

  /// The id of the sermon in `assets/sermons/` — "074", "CP37".
  final String appId;

  /// The tier verbatim, whatever it says. Never collapsed to a bool:
  /// a boolean would throw away the distinction the pass promoting
  /// `probable` pairs to `confirmed` is being run to establish.
  final String tier;

  /// The upstream `completeness` judgement, verbatim, or null when the
  /// row does not carry one — which is every row as this is written.
  ///
  /// **Parsed and carried; deliberately not rendered.** Two sermons
  /// can be the same sermon and still be a bad swap — a library body
  /// that is truncated, or that covers only part A of a message the
  /// app carries whole. The pass adjudicating the `probable` pairs is
  /// recording that alongside each verdict, and this field is where it
  /// arrives. What this app must not do is guess the vocabulary before
  /// it exists: a surface that decided for itself which values mean
  /// "whole" would be inventing the judgement it is supposed to be
  /// reading. So it round-trips, and the first version of the file
  /// that carries it settles what it says.
  final String? completeness;

  const LibraryDuplicatePair({
    required this.libId,
    required this.appId,
    required this.tier,
    this.completeness,
  });

  bool get isConfirmed => tier == kDuplicateTierConfirmed;

  static LibraryDuplicatePair? fromJson(Map<String, dynamic> j) {
    final lib = int.tryParse('${j['libId']}');
    final app = j['appId']?.toString();
    if (lib == null || app == null || app.isEmpty) return null;
    return LibraryDuplicatePair(
      libId: lib,
      appId: app,
      // A missing tier reads as the empty string, which is not
      // `confirmed`, which shows the record. See
      // [kDuplicateTierConfirmed].
      tier: j['tier']?.toString() ?? '',
      completeness: j['completeness']?.toString(),
    );
  }
}

/// `assets/sermon_library/refs.json` — the scripture index over this
/// corpus, plus the cross-corpus duplicate grading.
///
/// Same shape as `assets/sermons/refs.json` for [byVerse] and
/// [bySermon], so a caller that already knows one knows the other,
/// with [byBook] and [focus] on top. Ids are the library's integer
/// post ids; the JSON stores them as strings and they are parsed once
/// here so nothing downstream has to remember which they are.
class SermonLibraryRefs {
  /// "Matthew 5" / "Matthew 5:14" → the records citing it.
  final Map<String, List<int>> byVerse;

  /// Record id → every reference key found in it.
  final Map<int, List<String>> bySermon;

  /// "Matthew" → the records that touch it at all.
  final Map<String, List<int>> byBook;

  /// Record id → the chapters the sermon is ABOUT, as distinct from
  /// the ones it quotes once in passing.
  final Map<int, List<String>> focus;

  /// Every graded cross-corpus pair, all tiers, in file order.
  final List<LibraryDuplicatePair> crossCorpus;

  const SermonLibraryRefs({
    required this.byVerse,
    required this.bySermon,
    required this.byBook,
    required this.focus,
    required this.crossCorpus,
  });

  static const SermonLibraryRefs empty = SermonLibraryRefs(
    byVerse: {},
    bySermon: {},
    byBook: {},
    focus: {},
    crossCorpus: [],
  );

  bool get isEmpty => byVerse.isEmpty && crossCorpus.isEmpty;

  /// The established pair for a library record, or null.
  ///
  /// `confirmed` only. An unadjudicated candidate is not a
  /// counterpart, and `MatthewMessage` in `sermon_service.dart`
  /// already ruled on that class of question: "a sermon with no
  /// confirmed counterpart shows no link rather than a plausible
  /// one". When the adjudicating pass promotes a `probable` pair, the
  /// link appears with no code change; when it refutes one, the link
  /// goes.
  LibraryDuplicatePair? confirmedPairFor(int libId) {
    for (final d in crossCorpus) {
      if (d.libId == libId && d.isConfirmed) return d;
    }
    return null;
  }
}

/// Everything [SermonLibraryService.load] returns, in one value.
class SermonLibrary {
  /// Every record a reader can open — text, audio or both.
  ///
  /// **No record is dropped for being a duplicate.** Where the two
  /// corpora hold the same sermon, both texts stay and the sermon
  /// page links them; see [kDuplicateTierConfirmed]. The only records
  /// missing from this list are the three with nothing behind them at
  /// all.
  final List<LibrarySermon> sermons;

  /// How many records the index contained before anything was
  /// dropped. Kept so the difference can be stated rather than
  /// quietly vanishing.
  final int fetchedCount;

  /// The speakers, by descending sermon count, ties broken by name.
  ///
  /// Count-descending rather than alphabetical because the head of
  /// this distribution is a handful of names with scores or hundreds
  /// of sermons and the tail is dozens with exactly one. A name-sorted
  /// list would bury the largest bodies of work in the middle of 71
  /// rows and give the reader no way to see the shape of the corpus.
  final List<LibrarySpeaker> speakers;

  /// Post id → record, for the records this app shows.
  final Map<int, LibrarySermon> byId;

  /// The scripture index. [SermonLibraryRefs.empty] when `refs.json`
  /// is absent or unreadable — the library still renders without it.
  final SermonLibraryRefs refs;

  /// `_meta.rights` — "© 福音电台 及各讲员 · 经授权使用" — and its
  /// English form, verbatim from the asset. Never hardcoded in the
  /// app: the rights line belongs to the corpus, so it travels with
  /// the corpus, and a re-ingest that changes it changes what the app
  /// prints.
  final String rights;
  final String rightsEn;

  const SermonLibrary({
    required this.sermons,
    required this.fetchedCount,
    required this.speakers,
    required this.byId,
    required this.refs,
    required this.rights,
    required this.rightsEn,
  });

  bool get isEmpty => sermons.isEmpty;

  /// How many of [sermons] have a body worth opening.
  int get withTextCount {
    var n = 0;
    for (final s in sermons) {
      if (s.hasText) n += 1;
    }
    return n;
  }

  /// The records of this library that expound a given chapter.
  ///
  /// Chapter-level, for the reason `SermonService.sermonsForVerse`
  /// gives: a sermon's natural unit is the chapter, and every Bible
  /// version numbers chapters the same way, so a chapter key is
  /// robust across versions and languages where a verse key is not.
  /// [book] is the English canonical name the refs index uses
  /// ("Matthew"), not the Chinese one the record's `book` field
  /// carries.
  List<LibrarySermon> sermonsForChapter(String book, int chapter) {
    final wholeChapter = '$book $chapter';
    final prefix = '$wholeChapter:';
    final hits = <int>{};
    refs.byVerse.forEach((key, ids) {
      if (key == wholeChapter || key.startsWith(prefix)) hits.addAll(ids);
    });
    return [
      for (final id in hits)
        if (byId[id] != null) byId[id]!,
    ];
  }

  /// The rights line for a UI locale. Chinese for both zh locales —
  /// the corpus ships one Chinese string and there is no Traditional
  /// edition of it to prefer.
  String rightsFor(String locale) {
    final zh = rights.trim();
    final en = rightsEn.trim();
    if (locale.startsWith('zh')) return zh.isNotEmpty ? zh : en;
    return en.isNotEmpty ? en : zh;
  }

  LibrarySpeaker? speakerByKey(String key) {
    for (final s in speakers) {
      if (s.key == key) return s;
    }
    return null;
  }
}

/// The one way into the 940-record 福音电台 sermon library.
///
/// **Where the bytes come from is one line, and this is that line:**
/// [_loader], which defaults to `rootBundle.loadString` under
/// [libraryRoot]. `assets/sermon_library/` is gitignored and is NOT
/// currently declared in `pubspec.yaml`; whether it ends up bundled
/// or fetched at runtime the way `songs.json` is (see
/// `RemoteDataService`) is an open decision. Nothing outside this file
/// knows which: every page calls [load] and [loadBody] and gets a
/// `Future`, so moving to HTTP is replacing the one assignment below
/// and nothing else.
///
/// **Caching is real and it matters.** [load] parses two JSON files
/// totalling 1.5 MB and buckets 900-odd records into 71 speakers;
/// doing that per rebuild would make every `FutureBuilder` on this
/// feature flash a spinner. The `Future` itself is memoised, not
/// merely its result, so two widgets that call in the same frame
/// share one parse.
class SermonLibraryService {
  SermonLibraryService._();
  static final SermonLibraryService instance = SermonLibraryService._();

  /// Asset directory the library lives in. Every path this service
  /// reads is this plus a relative path out of the index.
  static const String libraryRoot = 'assets/sermon_library';

  /// ── THE ONE LINE ──────────────────────────────────────────────
  /// Swap this for an HTTP fetcher and the whole feature moves off
  /// the bundle. Nothing else in the app reads these files.
  LibraryTextLoader _loader =
      (path) => rootBundle.loadString('$libraryRoot/$path');

  Future<SermonLibrary>? _library;
  final Map<String, String> _bodyCache = {};

  /// Point the service at a different transport. Drops every cache,
  /// so a test that installs a loader cannot be served a payload the
  /// previous test parsed.
  @visibleForTesting
  void useLoader(LibraryTextLoader loader) {
    _loader = loader;
    resetForTest();
  }

  /// Back to the bundle, caches cleared. Call in `tearDown` so one
  /// test's fake loader cannot leak into the next.
  @visibleForTesting
  void resetForTest() {
    _library = null;
    _bodyCache.clear();
  }

  /// The whole library, parsed once.
  ///
  /// Throws if `index.json` is missing or malformed, and that is
  /// deliberate. The alternative — degrading to an empty library —
  /// renders a page saying there are no sermons, which is exactly
  /// what a forgotten `pubspec.yaml` entry looks like from the
  /// outside and exactly the wrong thing to make look normal. The
  /// pages surface it the way `SermonsPage` does, through
  /// `snapshot.hasError`.
  ///
  /// `refs.json` is different and degrades instead: without it there
  /// is no scripture index and no cross-corpus links. It can never
  /// remove a record. See [kDuplicateTierConfirmed].
  Future<SermonLibrary> load() => _library ??= _load();

  Future<SermonLibrary> _load() async {
    final raw = await _loader('index.json');
    final doc = json.decode(raw) as Map<String, dynamic>;
    final meta = doc['_meta'] as Map<String, dynamic>? ?? const {};
    final rows = doc['sermons'] as List<dynamic>? ?? const [];

    final refs = await _loadRefs();

    var fetched = 0;
    final sermons = <LibrarySermon>[];
    for (final r in rows.whereType<Map<String, dynamic>>()) {
      fetched += 1;
      final s = LibrarySermon.fromJson(r);
      // The ONLY reason a record does not reach the list. Duplicate
      // grading does not filter anything — see
      // [kDuplicateTierConfirmed].
      if (!s.isOpenable) continue;
      sermons.add(s);
    }

    return SermonLibrary(
      sermons: sermons,
      fetchedCount: fetched,
      speakers: buildSpeakers(sermons),
      byId: {for (final s in sermons) s.id: s},
      refs: refs,
      rights: meta['rights'] as String? ?? '',
      rightsEn: meta['rightsEn'] as String? ?? '',
    );
  }

  /// `refs.json`, or [SermonLibraryRefs.empty] if it cannot be read.
  ///
  /// Silent degradation: without it there is no chapter lookup and no
  /// cross-corpus links, and the library still renders in full. A
  /// missing link is a thing the reader can live without; a missing
  /// sermon is not, which is why nothing in this file lets the refs
  /// file remove one.
  Future<SermonLibraryRefs> _loadRefs() async {
    try {
      final doc =
          json.decode(await _loader('refs.json')) as Map<String, dynamic>;
      Map<String, List<int>> idLists(Object? v) => {
            for (final e in (v as Map<String, dynamic>? ?? const {}).entries)
              e.key: [
                for (final x in (e.value as List? ?? const []))
                  if (int.tryParse('$x') != null) int.parse('$x'),
              ],
          };
      Map<int, List<String>> byIntKey(Object? v, String? field) => {
            for (final e in (v as Map<String, dynamic>? ?? const {}).entries)
              if (int.tryParse(e.key) != null)
                int.parse(e.key): [
                  for (final x in (e.value as List? ?? const []))
                    if (field == null)
                      x.toString()
                    else if (x is Map && x[field] != null)
                      x[field].toString(),
                ],
          };
      final dupes = ((doc['duplicates'] as Map<String, dynamic>?)?['crossCorpus']
              as List<dynamic>? ??
          const []);
      return SermonLibraryRefs(
        byVerse: idLists(doc['byVerse']),
        bySermon: byIntKey(doc['bySermon'], null),
        byBook: idLists(doc['byBook']),
        focus: byIntKey(doc['focus'], 'ref'),
        crossCorpus: [
          for (final d in dupes.whereType<Map<String, dynamic>>())
            if (LibraryDuplicatePair.fromJson(d) != null)
              LibraryDuplicatePair.fromJson(d)!,
        ],
      );
    } catch (_) {
      return SermonLibraryRefs.empty;
    }
  }

  /// Bucket by credit, order by count.
  ///
  /// **Identity is `LibrarySermon.credit`** — the raw `author`, or
  /// 福音电台 for the records that carry none, which is the asset's
  /// own `_meta.rightsNote` instruction and not this app's guess.
  /// That fold is the only one. The corpus also holds 小珊姊妹 and
  /// 小珊, which are very probably one person; merging those would be
  /// this app deciding who somebody is on the strength of a
  /// substring. If the church confirms the identity, the fix belongs
  /// in the fetcher where it can be recorded and reviewed.
  @visibleForTesting
  static List<LibrarySpeaker> buildSpeakers(List<LibrarySermon> sermons) {
    final buckets = <String, List<LibrarySermon>>{};
    final kinds = <String, String?>{};
    for (final s in sermons) {
      buckets.putIfAbsent(s.credit, () => <LibrarySermon>[]).add(s);
      kinds[s.credit] ??= s.authorKind;
    }
    final out = [
      for (final e in buckets.entries)
        LibrarySpeaker(
          name: e.key,
          kind: kinds[e.key],
          sermons: sortNewestFirst(e.value),
        ),
    ];
    out.sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      return byCount != 0 ? byCount : a.name.compareTo(b.name);
    });
    return out;
  }

  /// Newest publication first; **everything undated goes last**, in
  /// the order the fetcher wrote it.
  ///
  /// The undated rule is the point. One record's upstream date reads
  /// `0214-07-02`; sorted as a date it lands fifteen centuries before
  /// the rest of the corpus and pins itself to one end of every list.
  /// `LibrarySermon.publishedAt` returns null for it, and null sorts
  /// LAST here rather than to an epoch default — which would only
  /// have moved the same record to the other end.
  @visibleForTesting
  static List<LibrarySermon> sortNewestFirst(List<LibrarySermon> input) {
    final dated = <LibrarySermon>[];
    final undated = <LibrarySermon>[];
    for (final s in input) {
      (s.publishedAt == null ? undated : dated).add(s);
    }
    dated.sort((a, b) => b.publishedAt!.compareTo(a.publishedAt!));
    return [...dated, ...undated];
  }

  /// The body text of one sermon, or null when it has none.
  ///
  /// Returned verbatim. These bodies are paragraph-per-LINE — 843
  /// files, zero blank-line gaps — so a renderer must split on single
  /// newlines to keep the paragraphing the transcriber gave it.
  /// Nothing here trims, re-wraps, re-punctuates or re-paragraphs;
  /// `sermon_detail_page.dart` states that rule for the other corpus
  /// and it is the same rule and the same reason.
  ///
  /// Misses cache as the empty string so a missing file is not
  /// re-fetched on every rebuild.
  Future<String?> loadBody(LibrarySermon sermon) async {
    if (!sermon.hasText) return null;
    final path = sermon.bodyFile;
    final cached = _bodyCache[path];
    if (cached != null) return cached.isEmpty ? null : cached;
    try {
      final body = await _loader(path);
      _bodyCache[path] = body;
      return body.isEmpty ? null : body;
    } catch (_) {
      _bodyCache[path] = '';
      return null;
    }
  }
}
