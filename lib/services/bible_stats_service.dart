import 'package:yswords/constants/text_patterns.dart' show sanitizeForSearch;
import 'package:yswords/models/verse.dart';

/// Whole-Bible vocabulary + structural statistics computed from the
/// currently-loaded version's verses. The compute is O(n) over every
/// verse so it's run once per version (keyed by version code) and
/// memoised for the lifetime of the process.
class BibleStatsService {
  static final Map<String, BibleStats> _cache = {};

  /// Compute (or return cached) stats for [verses]. [versionKey] is
  /// any string that uniquely identifies the current Bible version
  /// (e.g. 'kjv', 'cuvs') so different versions don't collide.
  static BibleStats compute(String versionKey, List<Verse> verses) {
    final cached = _cache[versionKey];
    if (cached != null) return cached;

    final byBook = <String, _BookAccum>{};
    final globalCounts = <String, int>{};
    int totalWords = 0;
    int totalChars = 0;
    int totalVerses = 0;
    final allChapters = <String, Set<int>>{};

    for (final v in verses) {
      final cleaned = sanitizeForSearch(v.text);
      final tokens = _tokenize(cleaned);
      final acc = byBook.putIfAbsent(v.book, () => _BookAccum());
      acc.chapters.add(v.chapter);
      acc.verses += 1;
      acc.words += tokens.length;
      acc.chars += cleaned.length;
      for (final t in tokens) {
        acc.counts[t] = (acc.counts[t] ?? 0) + 1;
        globalCounts[t] = (globalCounts[t] ?? 0) + 1;
      }
      totalWords += tokens.length;
      totalChars += cleaned.length;
      totalVerses += 1;
      allChapters.putIfAbsent(v.book, () => {}).add(v.chapter);
    }

    final perBook = byBook.entries
        .map((e) => BookStats(
              book: e.key,
              chapters: e.value.chapters.length,
              verses: e.value.verses,
              words: e.value.words,
              chars: e.value.chars,
              counts: e.value.counts,
            ))
        .toList()
      ..sort((a, b) => a.book.compareTo(b.book));

    // Filter common stop-words (EN + zh) from the global vocabulary.
    final filteredGlobal = Map<String, int>.fromEntries(globalCounts.entries
        .where((e) => !_stopWords.contains(e.key)));
    final topGlobal = filteredGlobal.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final hapax = globalCounts.entries
        .where((e) => e.value == 1)
        .map((e) => e.key)
        .toList()
      ..sort();

    final stats = BibleStats(
      totalBooks: byBook.length,
      totalChapters: allChapters.values.fold(0, (a, s) => a + s.length),
      totalVerses: totalVerses,
      totalWords: totalWords,
      totalChars: totalChars,
      books: perBook,
      topGlobal: topGlobal,
      hapaxLegomena: hapax,
    );
    _cache[versionKey] = stats;
    return stats;
  }

  /// Public access to the same tokenization the service uses, so other
  /// widgets (e.g. an in-page "search this stat" filter) tokenize the
  /// same way.
  static List<String> tokenize(String text) =>
      _tokenize(sanitizeForSearch(text));
}

/// Tokenize a string into lowercase word tokens suitable for vocab
/// frequency stats. Latin words become single tokens (`don't`,
/// `loved`); each Chinese character becomes its own token (Chinese
/// proper word segmentation needs NLP — character frequency is
/// the closest approximation that doesn't require shipping a
/// segmentation library).
List<String> _tokenize(String cleaned) {
  final out = <String>[];
  // Latin word OR single CJK ideograph.
  final re = RegExp(r"[a-zA-Z]+(?:'[a-zA-Z]+)*|[一-鿿]");
  for (final m in re.allMatches(cleaned)) {
    out.add(m.group(0)!.toLowerCase());
  }
  return out;
}

/// English + Chinese function words to suppress from "top words"
/// charts so the view actually shows content vocabulary instead of
/// articles, conjunctions, and pronouns. Conservative list — true
/// content words (e.g. "lord", "god", "Israel") stay.
const _stopWords = <String>{
  // English function words
  'the', 'a', 'an', 'and', 'or', 'but', 'of', 'in', 'on', 'to', 'for',
  'with', 'by', 'at', 'from', 'as', 'is', 'are', 'was', 'were', 'be',
  'been', 'being', 'am', 'have', 'has', 'had', 'do', 'does', 'did',
  'will', 'would', 'shall', 'should', 'may', 'might', 'can', 'could',
  'must', 'i', 'me', 'my', 'mine', 'we', 'us', 'our', 'ours', 'you',
  'your', 'yours', 'he', 'him', 'his', 'she', 'her', 'hers', 'it',
  'its', 'they', 'them', 'their', 'theirs', 'this', 'that', 'these',
  'those', 'who', 'whom', 'whose', 'which', 'what', 'when', 'where',
  'why', 'how', 'not', 'no', 'so', 'if', 'then', 'than', 'because',
  'though', 'although', 'while', 'until', 'unless', 'into', 'unto',
  'upon', 'thou', 'thee', 'thy', 'thine', 'ye', 'shalt', 'wilt',
  'doth', 'hath', 'art', 'wast', 'wert', 'all', 'any', 'some', 'such',
  // Chinese function characters / particles. Tokeniser splits on
  // single CJK chars, so multi-char tokens like '我们' wouldn't match
  // anyway — these single-char entries cover what the tokeniser
  // actually emits.
  '的', '了', '是', '在', '也', '有', '不', '又', '都', '与', '及', '和',
  '或', '而', '于', '从', '到', '把', '被', '使', '将', '自', '它', '其',
  '此', '那', '这', '我', '你', '他', '她', '们', '之', '乎', '者', '所',
  '以', '为', '若', '如', '何', '当', '故', '矣', '兮', '焉', '盖', '因',
  '但', '却', '过', '一', '二', '三', '上', '下', '中', '前', '後', '后',
  '里', '内', '外', '已',
};

class BibleStats {
  final int totalBooks;
  final int totalChapters;
  final int totalVerses;
  final int totalWords;
  final int totalChars;
  final List<BookStats> books;
  final List<MapEntry<String, int>> topGlobal;
  final List<String> hapaxLegomena;

  const BibleStats({
    required this.totalBooks,
    required this.totalChapters,
    required this.totalVerses,
    required this.totalWords,
    required this.totalChars,
    required this.books,
    required this.topGlobal,
    required this.hapaxLegomena,
  });

  /// Reading time at 200 words per minute, in minutes.
  int readingTimeMinutes() => (totalWords / 200).round();
}

class BookStats {
  final String book;
  final int chapters;
  final int verses;
  final int words;
  final int chars;
  final Map<String, int> counts;

  const BookStats({
    required this.book,
    required this.chapters,
    required this.verses,
    required this.words,
    required this.chars,
    required this.counts,
  });

  double get avgWordsPerVerse => verses == 0 ? 0 : words / verses;
  double get avgWordsPerChapter => chapters == 0 ? 0 : words / chapters;
  int readingTimeMinutes() => (words / 200).round();

  /// Words appearing exactly once in THIS book (book-level hapax).
  /// Different from BibleStats.hapaxLegomena which is whole-canon.
  List<String> hapaxInBook() {
    final out = <String>[];
    counts.forEach((w, n) {
      if (n == 1) out.add(w);
    });
    out.sort();
    return out;
  }

  /// Top [n] frequency words in this book, with stop-words filtered.
  List<MapEntry<String, int>> topWords([int n = 30]) {
    final filtered = counts.entries
        .where((e) => !_stopWords.contains(e.key))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return filtered.take(n).toList();
  }
}

class _BookAccum {
  final Set<int> chapters = {};
  int verses = 0;
  int words = 0;
  int chars = 0;
  final Map<String, int> counts = {};
}
