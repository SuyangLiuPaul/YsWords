import 'dart:convert';

import 'package:flutter/services.dart';

/// One block of public-domain commentary, covering verses [verse]..[endVerse]
/// of [chapter].
///
/// JFB is section-based, not verse-based: a single block may cover a whole
/// pericope ("Mt 8:5-13. Healing of the Centurion's Servant"). The blocks for
/// a book tile it exactly — every verse falls inside exactly one block, with
/// no gaps and no overlaps — which is asserted at build time by
/// `tools/build_commentary_jfb.py` and again at test time by
/// `test/jfb_commentary_test.dart`.
class CommentaryBlock {
  /// Chapter this block belongs to.
  final int chapter;

  /// First verse covered.
  final int verse;

  /// Last verse covered. Equal to [verse] for a single-verse comment.
  final int endVerse;

  /// The section heading JFB prints above this block, e.g.
  /// "Mt 5:1-16. The Sermon on the Mount." Empty when the block is a plain
  /// verse note with no heading of its own.
  final String heading;

  /// The commentary text. `**` delimits a bold run — that is the ONLY markup
  /// in the string, so [CommentaryText] is the whole renderer it needs.
  final String text;

  const CommentaryBlock({
    required this.chapter,
    required this.verse,
    required this.endVerse,
    required this.heading,
    required this.text,
  });

  /// True when this block is the one to show for [v].
  bool covers(int v) => v >= verse && v <= endVerse;

  /// "5:3" or "8:5-13" — the range this block actually covers.
  String get rangeLabel =>
      endVerse == verse ? '$chapter:$verse' : '$chapter:$verse-$endVerse';

  static CommentaryBlock? _fromJson(Object? raw) {
    if (raw is! Map) return null;
    final c = raw['c'], v = raw['v'], e = raw['e'], t = raw['t'];
    if (c is! int || v is! int || e is! int || t is! String) return null;
    if (c <= 0 || v <= 0 || e < v || t.isEmpty) return null;
    final h = raw['h'];
    return CommentaryBlock(
      chapter: c,
      verse: v,
      endVerse: e,
      heading: h is String ? h : '',
      text: t,
    );
  }
}

/// A whole commentary book, plus the provenance we are obliged to show.
class CommentaryBook {
  final String id;
  final String book;
  final String title;
  final String authors;
  final int firstPublished;

  /// The book-level introduction JFB prints before chapter 1.
  final String intro;

  final List<CommentaryBlock> blocks;

  const CommentaryBook({
    required this.id,
    required this.book,
    required this.title,
    required this.authors,
    required this.firstPublished,
    required this.intro,
    required this.blocks,
  });

  /// The block covering [chapter]:[verse], or null when this book has none.
  CommentaryBlock? forVerse(int chapter, int verse) {
    for (final b in blocks) {
      if (b.chapter == chapter && b.covers(verse)) return b;
    }
    return null;
  }

  /// Every block belonging to [chapter], in verse order.
  List<CommentaryBlock> forChapter(int chapter) =>
      blocks.where((b) => b.chapter == chapter).toList(growable: false);
}

/// Public-domain commentary, loaded lazily one book at a time.
///
/// Only the Gospel of Matthew ships today (`assets/commentary/jfb-matthew.json`,
/// ~526 KB). The per-book file layout is deliberate: the full JFB is ~5.7 MB of
/// source and the whole-Bible import would be a multi-megabyte add to a bundle
/// that is already large, so books arrive one at a time and are only read when
/// a reader actually opens the commentary on that book.
///
/// Licence: the text is Robert Jamieson, A. R. Fausset and David Brown,
/// *Commentary Critical and Explanatory on the Whole Bible* (1871). All three
/// authors died before 1911 and the work was published in 1871, so it is public
/// domain both by publication date (US) and by life+70. The digital text is the
/// CrossWire SWORD module `JFB` 3.0, whose own `.conf` states
/// `DistributionLicense=Public Domain`. The full evidence, with verbatim
/// source statements and dates, is in `docs/jfb-commentary-licence.md` — read
/// it before adding a second module rather than assuming this one generalises.
class CommentaryService {
  /// Books that have a commentary file on disk. Keyed by canonical English
  /// book name, exactly as `bookNameToEnglish` produces it.
  static const Set<String> supportedBooks = {'Matthew'};

  /// The module shipped for every supported book.
  static const String moduleId = 'jfb';

  static final Map<String, CommentaryBook?> _cache = {};
  static final Map<String, Future<CommentaryBook?>> _inflight = {};

  /// `assets/commentary/jfb-matthew.json` for "Matthew".
  static String assetPathFor(String englishBook) =>
      'assets/commentary/$moduleId-'
      '${englishBook.toLowerCase().replaceAll(' ', '_').replaceAll("'", '')}'
      '.json';

  /// Loads (once) and returns the commentary for [englishBook], or null when
  /// no module ships for it.
  ///
  /// [englishBook] must be the canonical English name — "Matthew",
  /// "1 Corinthians". Callers holding a localised name must run it through
  /// `toEnglish()` first, the same way the cross-reference sheet does.
  static Future<CommentaryBook?> forBook(String englishBook) {
    if (!supportedBooks.contains(englishBook)) return Future.value(null);
    if (_cache.containsKey(englishBook)) {
      return Future.value(_cache[englishBook]);
    }
    return _inflight[englishBook] ??= _load(englishBook);
  }

  /// True when [englishBook] has a commentary, without loading it. Safe to
  /// call from a build method.
  static bool hasBook(String englishBook) =>
      supportedBooks.contains(englishBook);

  static Future<CommentaryBook?> _load(String englishBook) async {
    CommentaryBook? parsed;
    try {
      final raw = await rootBundle.loadString(assetPathFor(englishBook));
      final json = jsonDecode(raw);
      if (json is Map<String, dynamic>) {
        final blocks = <CommentaryBlock>[];
        final entries = json['entries'];
        if (entries is List) {
          for (final e in entries) {
            final b = CommentaryBlock._fromJson(e);
            if (b != null) blocks.add(b);
          }
        }
        if (blocks.isNotEmpty) {
          parsed = CommentaryBook(
            id: json['id'] as String? ?? moduleId,
            book: json['book'] as String? ?? englishBook,
            title: json['title'] as String? ?? '',
            authors: json['authors'] as String? ?? '',
            firstPublished: json['firstPublished'] as int? ?? 0,
            intro: json['intro'] as String? ?? '',
            blocks: blocks,
          );
        }
      }
    } catch (_) {
      // A missing pubspec entry, a corrupt file or a stripped web build all
      // land here. Cache the null so a reader scrolling a chapter does not
      // retry the load on every verse.
      parsed = null;
    }
    _cache[englishBook] = parsed;
    _inflight.remove(englishBook);
    return parsed;
  }

  /// Test-only: forget everything loaded so far.
  static void resetForTest() {
    _cache.clear();
    _inflight.clear();
  }
}
