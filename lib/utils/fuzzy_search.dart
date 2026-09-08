/// 2026-09-08: the looser reading of a query that the reader has to ask
/// for by name.
///
/// Ported from SeekSparks, which wrote this file to be lifted: the code
/// below is that code, unchanged. Only this header is YsWords', because
/// every number in the original was measured against a different set of
/// editions and a different search engine.
///
/// ## The defect, measured
///
/// Every count below is over the real search key of a shipped edition —
/// `sanitizeForSearch(text)` with the spaces stripped and the rest
/// lower-cased, which is what `MainProvider.searchKeys` builds and what
/// a search actually compares against.
///
/// This app restores the divine name, in the assets and again in
/// `text_patterns.dart`: 耶和华 becomes 雅伟 and all-caps `LORD` becomes
/// `Yahweh` as the text is sanitised. Nothing did the same to the
/// query, so the spelling every Chinese Bible in print uses reached
/// nothing at all:
///
///     typed      cuvs-yhwh  cuvs-yhwh-tr    kjv
///     雅伟           6,106             0      —
///     雅偉               0         6,106      —
///     耶和华             0             0      —
///     yahweh         —             —      5,614
///     yhwh           —             —          0
///
/// That half is fixed on the query side rather than here —
/// `fuzzy_result_label.dart`'s `fuzzySearchQueryKey` puts the query
/// through the same sanitiser the index went through, which is a fix
/// this file's rungs should not have had to make. What is left for the
/// rungs is everything the sanitiser cannot reach.
///
/// The Traditional reader hits it a second way, one layer down: 磯法
/// finds 9 verses in `cuvs-yhwh-tr` and 0 in `cuvs-yhwh`; 愛 finds 823
/// and 0.
///
/// The English reader hits it a third way, and it cuts in both
/// directions. A plain query is a substring scan, so `love` reaches
/// "loved" — but not "loving", which does not contain the letters
/// l-o-v-e in a row — and `loved` reaches only the 200 verses that
/// spell it that way, never the 573 that say "love".
///
/// ## Why it is OFF by default, and why that is not timidity
///
/// A search that silently widened itself would be a view changing what
/// it shows without saying so, which is the defect this codebase keeps
/// fixing. So:
///
///   * [fuzzySearchEnabled] is **false** until something sets it, and
///     the setter is the only way in. One global rather than a flag
///     threaded through call sites, because the failure mode of
///     threading is a *silent asymmetry*, where one side of a
///     comparison is broadened and the other is not — which is exactly
///     the 耶和华 bug above, and one of it per feature is enough.
///   * Every broadened row can say so. `fuzzy_result_label.dart`'s
///     `fuzzySearchMatchKind` answers "was this hit literal?" for one
///     verse in the cost of one match, so a result list can mark the
///     rows that only the looser reading found.
///
/// ## The rungs, in the order they are tried
///
/// The first one that hits is the answer, and its name is what the row
/// is labelled with. They are ordered by how far each moves from what
/// the reader typed:
///
///   1. [FuzzyMatch.literal] — exactly what `search_page.dart` matched
///      before this file existed. Always tried first, so turning fuzzy
///      search ON can only ADD rows, never remove or reorder one.
///   2. [FuzzyMatch.script] — the same characters in the other Chinese
///      script. 磯法 → 矶法. Nothing about the query's meaning changed;
///      only the script the reader's keyboard is set to.
///   3. [FuzzyMatch.synonym] — another spelling of the same name or
///      word, from `search_synonyms.dart`, where every group carries
///      the in-repo evidence that licenses it.
///   4. [FuzzyMatch.stem] — English inflection, by Porter's algorithm.
///      `loved` goes from 200 KJV verses to 578. `flies` does NOT reach
///      "fly"; [stemSearchKey] says why, because a rung with a hole in
///      it should say where the hole is.
///   5. [FuzzyMatch.segmented] — the Chinese query's own words, in any
///      position in the verse rather than side by side. The loosest
///      rung and the last, because it is the only one that changes what
///      the query *asks*: 信心的祷告 occurs in no verse of the 和合本,
///      and its segments occur together in several.
///
/// ## What this does NOT do
///
///   * **It does not touch the other search modes.** A Strong's number,
///     a Bible reference, a lemma, a transliteration, the boolean
///     operator bar and the AI fallback all run through their own paths
///     in `search_page.dart` and are unaffected. Broadening any of them
///     is a separate piece of work with its own failure modes.
///   * **It does not fold case beyond what already happened.** The key
///     arrives lower-cased, so `lord` cannot be told from `LORD`.
///   * **It does not stem -eth or -est.** Porter is a 20th-century
///     algorithm and the KJV is not 20th-century English: `believeth`
///     stems to `believeth`, and a reader who types it gets the literal
///     rung only. Adding two rules would fix it and would also mean the
///     stemmer no longer matched the published vector it is tested
///     against, so the honest place for that is a separate, separately
///     tested layer — not a private fork of somebody's published
///     algorithm.
///
/// Pure Dart, and pure on purpose: this file, `porter_stemmer.dart`,
/// `chinese_segmentation.dart` and `search_synonyms.dart` import
/// nothing but each other. Nothing here imports Flutter, an asset, or
/// anything YsWords-shaped; `test/fuzzy_search_test.dart` parses the
/// imports and fails if that stops being true, so the layer can be
/// carried to a third repository the way it was carried to this one.
library;

import 'package:yswords/constants/search_synonyms.dart';
import 'package:yswords/utils/chinese_segmentation.dart';
import 'package:yswords/utils/porter_stemmer.dart';

// ── The switch ──────────────────────────────────────────────────────

bool _enabled = false;
int _generation = 0;

/// Whether a search may fall back to a looser reading of the query.
///
/// False until set. See the library comment for why that is not a
/// default anyone should quietly flip.
bool get fuzzySearchEnabled => _enabled;

/// Bumped whenever [fuzzySearchEnabled] changes, so anything caching a
/// derived form of the corpus can tell that its cache is stale.
/// [stemSearchKey]'s own memo is the only such cache today, and it is
/// keyed by word rather than by corpus, which is why it survives the
/// change; the counter exists so that the next one cannot be added
/// without meeting this comment.
int get fuzzySearchGeneration => _generation;

/// Turn the looser reading on or off. Returns true when the value
/// actually moved.
///
/// One writer, one global, no half-applied state. The writer is
/// `AppSettings.setFuzzySearch`, a persisted preference with a Settings
/// toggle in the Reading card, and `AppSettings._load` on start-up.
/// Both push the value in HERE before they notify their listeners — a
/// listener that re-runs its search on the notification must not read
/// the value that is about to be replaced.
bool setFuzzySearchEnabled(bool value) {
  if (_enabled == value) return false;
  _enabled = value;
  _generation++;
  return true;
}

/// Back to the shipped default. Tests only.
void resetFuzzySearchForTest() {
  _enabled = false;
  _generation++;
  _stems.clear();
}

// ── What a match was ────────────────────────────────────────────────

/// How a verse came to be in the result list.
///
/// Ordered from "what the reader typed" to "the loosest thing we would
/// still call the same search". A caller that shows the reader a label
/// should show one for everything except [literal]; [none] means the
/// verse is not a hit at all.
enum FuzzyMatch { none, literal, script, synonym, stem, segmented }

/// Whether this kind of hit needs to be marked as broadened.
bool fuzzyMatchIsBroadened(FuzzyMatch m) =>
    m != FuzzyMatch.none && m != FuzzyMatch.literal;

// ── Script conversion ───────────────────────────────────────────────

Map<int, int>? _toTrad;
Map<int, int>? _toSimp;

void _buildScriptTables() {
  final simp = <int, int>{};
  final trad = <int, int>{};
  for (var i = 0; i < kCuvSimplifiedChars.length; i++) {
    final s = kCuvSimplifiedChars.codeUnitAt(i);
    final t = kCuvTraditionalChars.codeUnitAt(i);
    // First listed wins: the table puts the more frequent Traditional
    // form first for the six Simplified characters that have two.
    trad.putIfAbsent(s, () => t);
    simp[t] = s;
  }
  _toTrad = trad;
  _toSimp = simp;
}

String _convert(String text, Map<int, int> table) {
  var changed = false;
  final out = List<int>.filled(text.length, 0);
  for (var i = 0; i < text.length; i++) {
    final c = text.codeUnitAt(i);
    final m = table[c];
    if (m == null) {
      out[i] = c;
    } else {
      out[i] = m;
      changed = true;
    }
  }
  return changed ? String.fromCharCodes(out) : text;
}

/// [text] with every Han character written in Traditional script.
///
/// Only the 1,111 characters the shipped 和合本 actually spells
/// differently are touched; everything else, Han or not, is left alone.
/// This is not a general Simplified-to-Traditional converter and must
/// not be used as one — it knows the vocabulary of one book.
String simplifiedToTraditional(String text) {
  if (_toTrad == null) _buildScriptTables();
  return _convert(text, _toTrad!);
}

/// [text] with every Han character written in Simplified script.
///
/// The safer of the two directions: measured over the two shipped
/// editions, no Traditional character in the 和合本 stands opposite two
/// different Simplified ones, so this conversion has no choices to make.
String traditionalToSimplified(String text) {
  if (_toSimp == null) _buildScriptTables();
  return _convert(text, _toSimp!);
}

// ── Stemming a whole key ────────────────────────────────────────────

final Map<String, String> _stems = {};

/// Largest number of distinct words kept in the stem memo.
///
/// The KJV's vocabulary is about 13,000 words and the largest English
/// edition here is not far past it, so one edition fits with room to
/// spare; the cap is there so
/// that a reader who searches across many editions in one session
/// cannot grow the map without end. Past the cap, stemming still works
/// and simply stops being remembered.
const int kStemMemoLimit = 40000;

/// The Porter stem of [word], remembered.
///
/// The memo is the reason this is affordable at all: a fuzzy scan stems
/// every word of every verse it did not already match, which is roughly
/// 800,000 words over the KJV, and the same 13,000 words over and over.
String memoizedStem(String word) {
  final hit = _stems[word];
  if (hit != null) return hit;
  final stem = porterStem(word);
  if (_stems.length < kStemMemoLimit) _stems[word] = stem;
  return stem;
}

/// [key] with every English word replaced by its Porter stem.
///
/// A `searchCorpusKey` in, a comparable key out: same spaces, same
/// non-Latin runs, same order, so `plainSearchMatchesLiteral`-style
/// contiguity still means what it meant. Runs that are not pure
/// `a`-`z` — Han, Greek, Hebrew, numbers, anything with an apostrophe —
/// are passed through untouched, because Porter has no claim on them.
///
/// **This is why `flies` does not reach `fly`.** Porter stems `flies`
/// to `fli` and `fly` to `fly`; they are different stems and no amount
/// of care here will join them. The algorithm's known y-alternation
/// blind spot is documented rather than patched, because patching it
/// means the implementation no longer matches the vector it is tested
/// against. `ponies`/`pony` and `skies`/`sky` fail the same way, and
/// `sky` is in the KJV 11 times.
String stemSearchKey(String key) {
  final buf = StringBuffer();
  var i = 0;
  final n = key.length;
  while (i < n) {
    final c = key.codeUnitAt(i);
    if (c < 0x61 || c > 0x7A) {
      buf.writeCharCode(c);
      i++;
      continue;
    }
    var j = i;
    while (j < n) {
      final d = key.codeUnitAt(j);
      if (d < 0x61 || d > 0x7A) break;
      j++;
    }
    buf.write(memoizedStem(key.substring(i, j)));
    i = j;
  }
  return buf.toString();
}

// ── The reading of a query ──────────────────────────────────────────

/// How many rewritten forms of one query are worth trying.
///
/// Synonym substitution is combinatorial — a two-word query where both
/// words are in nine-member groups is 81 forms — and past a dozen the
/// scan costs more than the rows are worth. Forms are generated
/// nearest-first (script before synonym, one substitution before two),
/// so the cap drops the least likely readings rather than an arbitrary
/// slice.
const int kMaxFuzzyVariants = 12;

/// One query, and every looser way of reading it.
///
/// Built once per search and matched against every verse, which is the
/// only reason the expansion can afford to be this thorough.
class FuzzyReading {
  const FuzzyReading({
    required this.literal,
    required this.variants,
    required this.stems,
    required this.conjuncts,
  });

  /// What the reader typed, in `plainSearchSegments` form.
  final List<String> literal;

  /// Rewritten segment lists, each with the rung that produced it.
  /// Matched exactly as [literal] is — same contiguity, same rules.
  final List<(FuzzyMatch, List<String>)> variants;

  /// [literal] with each English segment stemmed, for comparison
  /// against a [stemSearchKey]. Empty when no segment is English.
  final List<String> stems;

  /// Han fragments that may appear anywhere in the verse, in any order.
  /// Empty, or two or more — never one; see [segmentedConjuncts].
  final List<String> conjuncts;

  /// True when every rung beyond the literal one is empty, which is the
  /// ordinary case for a query fuzzy search has nothing to add to.
  bool get isLiteralOnly =>
      variants.isEmpty && stems.isEmpty && conjuncts.isEmpty;
}

Set<String>? _synonymVocabulary;

/// Every spelling any synonym group knows, for the segmenter to find
/// inside a longer query.
Set<String> synonymVocabulary() =>
    _synonymVocabulary ??= {
      for (final g in kSearchSynonymGroups) ...g.forms,
    };

List<String>? _formsFor(String term) {
  for (final g in kSearchSynonymGroups) {
    if (g.forms.contains(term)) return g.forms;
  }
  return null;
}

/// Rewrite [segment] every way the synonym groups allow, one term at a
/// time.
///
/// One at a time on purpose: a query holding two known terms is rare,
/// and the reading that swaps both at once is further from what the
/// reader typed than either single swap. Multi-term queries still reach
/// both spellings, because each single swap is tried.
List<String> _synonymRewrites(String segment) {
  final out = <String>[];
  final pieces = segmentHan(segment, vocabulary: synonymVocabulary());
  var offset = 0;
  for (final piece in pieces) {
    final forms = _formsFor(piece);
    if (forms != null) {
      for (final form in forms) {
        if (form == piece) continue;
        out.add(segment.substring(0, offset) +
            form +
            segment.substring(offset + piece.length));
      }
    }
    offset += piece.length;
  }
  // A whole segment that IS a form — the commonest case by far, since
  // most of these queries are one name — is covered by the loop above
  // only when the segmenter kept it whole. An English form never
  // reaches the Han segmenter, so it is handled here.
  final whole = _formsFor(segment);
  if (whole != null) {
    for (final form in whole) {
      if (form != segment && !out.contains(form)) out.add(form);
    }
  }
  return out;
}

/// Every looser reading of [segments], which must already be
/// `plainSearchSegments` output — folded, lower-cased, whitespace
/// collapsed.
///
/// Deterministic and side-effect free, so a caller may cache it against
/// the query it came from.
FuzzyReading fuzzyReading(List<String> segments) {
  if (segments.isEmpty) {
    return const FuzzyReading(
        literal: [], variants: [], stems: [], conjuncts: []);
  }
  final variants = <(FuzzyMatch, List<String>)>[];
  final seen = <String>{segments.join(' ')};

  void offer(FuzzyMatch kind, List<String> candidate) {
    if (variants.length >= kMaxFuzzyVariants) return;
    final key = candidate.join(' ');
    if (!seen.add(key)) return;
    variants.add((kind, candidate));
  }

  // Rung 2 — the other script, whole query at a time. A query is typed
  // on one keyboard, so a per-segment mix would be a reading nobody
  // wrote.
  final asTrad = [for (final s in segments) simplifiedToTraditional(s)];
  final asSimp = [for (final s in segments) traditionalToSimplified(s)];
  offer(FuzzyMatch.script, asTrad);
  offer(FuzzyMatch.script, asSimp);

  // Rung 3 — synonyms, over what the reader typed and over both script
  // readings of it, so 磯法 reaches 彼得 without the reader having to
  // switch keyboards first.
  for (final base in [segments, asSimp, asTrad]) {
    for (var i = 0; i < base.length; i++) {
      for (final rewrite in _synonymRewrites(base[i])) {
        final candidate = [...base];
        candidate[i] = rewrite;
        offer(FuzzyMatch.synonym, candidate);
      }
    }
  }

  // Rung 4 — English inflection, carried whenever the query holds an
  // English word at all.
  //
  // The first version of this skipped the rung when stemming left the
  // query unchanged, on the reasoning that comparing `love` against a
  // stemmed corpus is the literal search with extra steps. It is not:
  // `loving` stems to `love` and does NOT contain the string "love",
  // so the skip dropped two KJV verses from a search for the commonest
  // word in the New Testament. What matters is whether the VERSE's word
  // stems to the query's stem, and no property of the query alone can
  // answer that. Two rather than the 32 verses that say "loving",
  // because 29 of those say "lovingkindness" — a compound, which Porter
  // stems to `lovingkind` and this rung therefore does not reach.
  final stems = _hasStemmableWord(segments)
      ? [for (final s in segments) _stemSegment(s)]
      : const <String>[];

  // Rung 5 — the Chinese query's own words, anywhere in the verse.
  final conjuncts = segmentedConjuncts(
    segments.join(),
    vocabulary: synonymVocabulary(),
    commonChars: kCuvCommonHanChars,
  );

  return FuzzyReading(
    literal: segments,
    variants: variants,
    stems: stems,
    conjuncts: conjuncts.length < 2 ? const [] : conjuncts,
  );
}

String _stemSegment(String segment) {
  for (var i = 0; i < segment.length; i++) {
    final c = segment.codeUnitAt(i);
    if (c < 0x61 || c > 0x7A) return segment;
  }
  return memoizedStem(segment);
}

/// Whether any segment is a word Porter has rules for: three or more
/// letters, all of them lower-case `a`-`z`.
///
/// The gate exists so a Chinese search never pays for a stemmed corpus
/// it cannot match against. Below three letters Porter has no measure to
/// spend and returns the word untouched, so `to`, `of` and `is` do not
/// buy the rung either.
bool _hasStemmableWord(List<String> segments) {
  for (final segment in segments) {
    if (segment.length <= 2) continue;
    var latin = true;
    for (var i = 0; i < segment.length; i++) {
      final c = segment.codeUnitAt(i);
      if (c < 0x61 || c > 0x7A) {
        latin = false;
        break;
      }
    }
    if (latin) return true;
  }
  return false;
}
