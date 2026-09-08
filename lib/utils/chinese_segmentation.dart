/// 2026-09-08 (SeekSparks): where a Chinese query's words begin and end.
///
/// ## Why maximum matching and not an HMM
///
/// 微读圣经 segments with `hmm_model.dict` — a trained Hidden Markov
/// model, which is to say a **data file**. An HMM is worthless without
/// its parameters, and those parameters are somebody's training run over
/// somebody's corpus. There is no version of "implement the algorithm
/// ourselves" that avoids shipping a table we cannot licence, so the
/// algorithm was never the choice to make.
///
/// Forward maximum matching needs a *vocabulary* and nothing else, and
/// the caller supplies it. That moves the licence question to the word
/// list, where this repository has an answer: the terms it already owns
/// (`search_synonyms.dart`, and `strongs_service.dart`'s
/// `_aliasToStrongs`). Everything the vocabulary does not cover falls
/// back to one
/// token per character, which is the honest floor — it says "I do not
/// know where the word boundary is" instead of guessing.
///
/// Backward maximum matching is the usual recommendation over forward
/// (Chinese compounds tend to be right-headed, so scanning from the
/// right guesses better). It is not used here because the difference
/// only shows up on the vocabulary's OWN ambiguities — two dictionary
/// terms overlapping in one string — and this vocabulary is small,
/// hand-checked and free of them. Forward matching reads in the
/// direction the query was typed, which makes the segmentation a reader
/// could predict.
///
/// ## What segmentation is FOR here, which is narrower than it sounds
///
/// A Chinese term in this app is already a **substring** search —
/// `MainProvider.searchKeys` strips every space out of the verse and
/// `search_page.dart` strips them out of the query, so 爱神 finds 爱神
/// without anybody segmenting anything. Segmentation
/// buys exactly two things:
///
///   1. **Finding a known term inside a longer query**, so 雅伟的话 can
///      have 雅伟 swapped for 耶和华 without 的话 being disturbed.
///   2. **The AND reading of a query that matched nothing.** 信心的祷告
///      occurs in no verse of the shipped 和合本; its segments, minus the
///      characters too common to narrow anything, occur together in 4.
///      That is a rung below the literal search and above "no results",
///      and it is a rung only a segmentation can find.
///
/// Both are broadenings, both are off unless the reader asked for them
/// (`fuzzy_search.dart`), and neither changes what a literal Chinese
/// search means.
///
/// Pure Dart: no Flutter, no assets, no I/O.
library;

/// Whether [c] is a Han character.
///
/// Declared here rather than imported so that this layer stays pure
/// Dart and portable. In SeekSparks, where this file was written, the
/// same four comparisons already existed in `related_verses.dart` and
/// a test held the two copies to each other; YsWords has no such
/// predicate to agree with, so `test/chinese_segmentation_test.dart`
/// checks the ranges against the ones this doc claims instead — the
/// only thing four comparisons realistically get wrong is a boundary.
bool isHanChar(int c) =>
    (c >= 0x4E00 && c <= 0x9FFF) ||
    (c >= 0x3400 && c <= 0x4DBF) ||
    (c >= 0xF900 && c <= 0xFAFF);

/// Split [text] into the units a fuzzy Chinese search reasons about.
///
/// Runs of Han characters are segmented by forward maximum matching
/// against [vocabulary]: at each position the longest vocabulary term
/// starting there wins, and where none does, one character is emitted.
/// Every other run — Latin words, digits, punctuation, whitespace — is
/// emitted whole and unexamined, because this function has nothing to
/// say about them.
///
/// An empty [vocabulary] is legitimate and gives one token per Han
/// character. That is the floor described in the library comment, and it
/// is what this app runs with today for everything outside its own
/// small term list.
List<String> segmentHan(String text, {Set<String> vocabulary = const {}}) {
  if (text.isEmpty) return const [];
  var longest = 1;
  for (final term in vocabulary) {
    if (term.length > longest) longest = term.length;
  }
  final out = <String>[];
  var i = 0;
  while (i < text.length) {
    if (!isHanChar(text.codeUnitAt(i))) {
      var j = i;
      while (j < text.length && !isHanChar(text.codeUnitAt(j))) {
        j++;
      }
      out.add(text.substring(i, j));
      i = j;
      continue;
    }
    var matched = 0;
    // Longest first: 雅伟 must beat 雅 even though both may be terms.
    final ceiling = i + longest > text.length ? text.length - i : longest;
    for (var len = ceiling; len >= 2; len--) {
      if (vocabulary.contains(text.substring(i, i + len))) {
        matched = len;
        break;
      }
    }
    if (matched == 0) matched = 1;
    out.add(text.substring(i, i + matched));
    i += matched;
  }
  return out;
}

/// The segments of [text] worth requiring a verse to contain, all of
/// them, in any position.
///
/// Three things are dropped, and each for its own reason:
///
///   * **Non-Han runs** — punctuation and whitespace carry no query, and
///     an alphabetic run is the other language's problem
///     (`porter_stemmer.dart` handles it, by a different rule).
///   * **Single characters listed in [commonChars]** — 的 occurs in
///     24,525 of the 和合本's 31,102 verses, so requiring it requires
///     nothing while making the reader believe the search was narrower
///     than it was.
///   * **Duplicates**, since an AND of a term with itself is the term.
///
/// The stop filter deliberately applies only to segments ONE character
/// long. A vocabulary term keeps every character it has: 雅伟 survives
/// even though 雅 is in [commonChars], and it is in [commonChars] only
/// because 雅伟 is so frequent.
///
/// Returns fewer than two conjuncts — including none — when the query
/// has nothing to say this way. A caller must treat that as "no
/// segmented reading exists", never as "matches everything": one
/// conjunct is not a broadening of a substring search, it is a shorter
/// substring search, and the whole corpus is not an answer.
List<String> segmentedConjuncts(
  String text, {
  Set<String> vocabulary = const {},
  String commonChars = '',
}) {
  final seen = <String>{};
  final out = <String>[];
  for (final seg in segmentHan(text, vocabulary: vocabulary)) {
    if (seg.isEmpty) continue;
    if (!isHanChar(seg.codeUnitAt(0))) continue;
    if (seg.length == 1 && commonChars.contains(seg)) continue;
    if (!seen.add(seg)) continue;
    out.add(seg);
  }
  return out;
}
