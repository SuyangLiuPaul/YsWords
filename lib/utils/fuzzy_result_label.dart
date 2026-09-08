/// 2026-09-08: the part of the fuzzy search that is NOT portable, kept
/// in its own file so the rest can be carried in and out whole.
///
/// `fuzzy_search.dart`, `porter_stemmer.dart`, `chinese_segmentation.dart`
/// and `search_synonyms.dart` know nothing about this app: no Flutter,
/// no assets, no `Verse`, no locale. They arrived from SeekSparks as
/// pure Dart and they will leave the same way. This file is where they
/// meet YsWords — it knows how a verse becomes a search key, how a
/// query becomes one, and which of three locales the reader is in.
/// Every YsWords import this feature needs is in this file and in no
/// other, which is what "the rest is portable" has to mean to be worth
/// saying.
///
/// SeekSparks split the same job across two files, because it had a
/// `plain_search.dart` with a segment-contiguity matcher to hang the
/// rungs off. YsWords has no such file and needs none: its search key
/// has every ASCII space removed from it, so "next to each other" is
/// not a rule this engine can express and a match is one
/// `String.contains`. The ladder below is therefore the whole matcher,
/// and it is shorter than the one it was ported from because the
/// engine underneath it is simpler — not because anything was dropped.
///
/// ## The asymmetry this file exists to close, which was a real bug
///
/// `MainProvider.searchKeys` builds its key with `sanitizeForSearch`,
/// and `sanitizeForSearch` calls `_normalizeDivineNames`: 耶和华 → 雅伟,
/// 耶和華 → 雅偉, all-caps `LORD` → `Yahweh`. `search_page.dart` built
/// its query key with a bare `replaceAll(' ', '').toLowerCase()`, which
/// normalises nothing. One side of the comparison was rewritten and the
/// other was not, so a reader typing 耶和华 — the spelling in every
/// Chinese Bible in print — matched 0 of the 6,106 verses that are
/// about exactly what they asked for.
///
/// [fuzzySearchQueryKey] is the fix, and it is deliberately NOT gated
/// on the fuzzy switch: it is not a broadening, it is the query finally
/// being asked the same question the index was. Nor can it take a row
/// away. The key can never contain 耶和华 (the sanitiser rewrote it), so
/// the old query found nothing there and the new one can only add.
///
/// ## Why the label is built from the verse and not carried with it
///
/// The scan in `search_page.dart` collects a `List<Verse>` and no
/// provenance. Rather than widen that into a list of (verse, rung)
/// pairs and thread it through the sort, the counts and the four other
/// result modes that share the list, the question is asked again — per
/// VISIBLE row, at the moment the row is drawn. The query's expansion
/// is memoized, so the second ask costs one pass over one verse, and a
/// `ListView.builder` never draws more rows than fit on a screen.
///
/// The rule it serves: a view that changes what it shows must say so. A
/// reader who sees 约翰福音 1:42 in the results for 磯法 is owed the two
/// characters that say the verse actually spells it 矶法.
library;

import 'package:yswords/constants/fuzzy_search_strings.dart';
import 'package:yswords/constants/text_patterns.dart' show sanitizeForSearch;
import 'package:yswords/utils/fuzzy_search.dart';

// ── The two keys, which must be built the same way ──────────────────

/// The searchable form of [scriptureText].
///
/// **This must stay identical to `MainProvider.searchKeys`**, which is
/// `sanitizeForSearch(text).replaceAll(' ', '').toLowerCase()`. The scan
/// uses that cached array and the row builder calls in here, so a
/// divergence would let a row be drawn as literal that the scan found
/// on a looser rung, or the reverse. The two are not shared as one
/// function because the provider's array is another owner's file;
/// `test/fuzzy_search_test.dart` reads that file and fails if the
/// expression this comment quotes is no longer in it.
///
/// Note what it does NOT strip: `sanitizeForSearch` keeps `\n`, and
/// `replaceAll(' ', '')` removes only U+0020. A phrase the edition sets
/// across a line break was already unreachable before this file and
/// still is — a pre-existing hole, recorded here rather than widened,
/// because closing it would change what every existing search returns.
String fuzzySearchCorpusKey(String scriptureText) =>
    sanitizeForSearch(scriptureText).replaceAll(' ', '').toLowerCase();

final RegExp _whitespaceRun = RegExp(r'\s+');

/// The reader's query as the words they separated it into.
///
/// **The one place a query is normalised**, and therefore where the
/// divine-name fix lives: the `sanitizeForSearch` call is what puts the
/// query through the rewrite the verse already went through. There is
/// deliberately no second entry point that returns the query as one
/// run — the rungs join these pieces themselves, so the literal rung
/// and the looser ones cannot come to disagree about what was typed.
///
/// Split rather than concatenated because the looser rungs need the
/// WORDS: Porter has nothing to say about `godsolovedtheworld`, and a
/// synonym swap has to leave the rest of the query where it was. Every
/// rung joins the pieces back with `''` at the moment it compares,
/// which is exactly what the space-stripped corpus key did to the
/// verse.
///
/// Empty when the query is blank, which a caller must read as "cannot
/// match anything" rather than as "matches everything".
List<String> fuzzySearchSegments(String query) {
  final sanitized = sanitizeForSearch(query).toLowerCase();
  return [
    for (final s in sanitized.split(_whitespaceRun))
      if (s.isNotEmpty) s,
  ];
}

/// The sanitised query with its spacing kept — what the result row
/// should highlight.
///
/// The highlighter matches a literal substring against the sanitised
/// VERSE, so it has to be handed the sanitised query or it will fail to
/// mark the very words that matched: a reader who searches 耶和华 gets
/// rows whose text says 雅伟, and nothing in them would be bold.
String fuzzySearchHighlightQuery(String query) => sanitizeForSearch(query);

/// [scriptureText]'s key with every English word replaced by its Porter
/// stem.
///
/// Built from the SPACED sanitised text and space-stripped afterwards,
/// in that order, which is the only order that works: stemming the key
/// would hand Porter one 200-letter run per verse and get one nonsense
/// stem back. Stemming first and stripping after gives a key that lines
/// up with a query stemmed the same way, so the comparison stays the
/// `String.contains` it is everywhere else in this engine.
String fuzzySearchStemKey(String scriptureText) =>
    stemSearchKey(sanitizeForSearch(scriptureText).toLowerCase())
        .replaceAll(' ', '');

// ── The ladder ──────────────────────────────────────────────────────

/// A [FuzzyReading] with every segment list already concatenated.
///
/// `fuzzy_search.dart` speaks in segment LISTS, because the engine it
/// was written for could put a space between two of them. This one
/// cannot — the key has no spaces left in it — so every list is
/// compared as one run, and the joining has to happen once per SEARCH
/// rather than once per verse. Getting that wrong is not a rounding
/// error: a scan asks 31,102 times, and a `join` per rung per verse is
/// close to half a million string allocations per keystroke.
class _JoinedReading {
  _JoinedReading(FuzzyReading reading)
      : variants = [
          for (final (kind, segments) in reading.variants)
            (kind, segments.join()),
        ],
        stems = reading.stems.join(),
        conjuncts = reading.conjuncts;

  final List<(FuzzyMatch, String)> variants;
  final String stems;
  final List<String> conjuncts;
}

String? _readingKey;
_JoinedReading? _reading;
int _readingGeneration = -1;

/// The expansion of [segments], built once per query rather than once
/// per verse.
///
/// A one-entry memo, because a scan asks the same question 31,102 times
/// in a row and then never asks it again. Keyed on the generation too,
/// so a reading cannot outlive the switch that shaped it.
_JoinedReading _readingFor(List<String> segments) {
  final key = segments.join(' ');
  if (_reading != null &&
      _readingKey == key &&
      _readingGeneration == fuzzySearchGeneration) {
    return _reading!;
  }
  _readingKey = key;
  _readingGeneration = fuzzySearchGeneration;
  return _reading = _JoinedReading(fuzzyReading(segments));
}

List<String>? _literalFor;
String? _literalJoined;

/// [segments] as the one run the key is compared against.
///
/// The literal rung runs whether or not the switch is on, so it cannot
/// hide behind [_readingFor]'s memo and needs its own. Keyed on the
/// list's IDENTITY, which is exactly the shape of the caller that
/// matters: a scan builds the segments once and hands the same list
/// back 31,102 times, while a row builder makes a fresh one per row and
/// pays one join for it.
String _literalOf(List<String> segments) {
  if (segments.length == 1) return segments.first;
  if (identical(_literalFor, segments)) return _literalJoined!;
  _literalFor = segments;
  return _literalJoined = segments.join();
}

/// Drop the memoized reading. Tests only — a test that flips the switch
/// without it would be answered from the previous test's expansion.
void resetFuzzyResultLabelForTest() {
  _readingKey = null;
  _reading = null;
  _readingGeneration = -1;
  _literalFor = null;
  _literalJoined = null;
}

/// How [key] matched [segments] — literally, on one of the looser
/// rungs, or not at all.
///
/// [key] must be a [fuzzySearchCorpusKey]. [scriptureText] is the same
/// verse's raw text and is only ever touched by the stem rung, which is
/// the one rung that cannot work from the space-stripped key; pass it
/// whenever you have it, and the stem rung is skipped when you do not.
///
/// The literal rung is always tried first and always wins, so switching
/// fuzzy search on can only ADD rows to a result list: no verse that
/// matched before stops matching, and none is relabelled.
///
/// **Cost.** With the switch off this is the one `String.contains` the
/// scan always was, and it does not touch [scriptureText] at all. With
/// it on, a Chinese query stays cheap — `FuzzyReading.stems` is empty,
/// so nothing is stemmed and nothing is sanitised a second time. An
/// English query is the expensive case: every verse that did not match
/// literally has its stem key built, which is a `sanitizeForSearch` and
/// a walk per verse. That is paid only by a reader who turned the
/// feature on, only on the search they asked for, and it is what
/// `kStemMemoLimit` in `fuzzy_search.dart` exists to keep bounded. If
/// it ever needs to come down, the answer is a stemmed key array cached
/// beside `MainProvider.searchKeys` and invalidated on
/// [fuzzySearchGeneration] — which is what that counter is for.
FuzzyMatch fuzzySearchMatchKind(
  String key,
  List<String> segments, {
  String? scriptureText,
}) {
  if (segments.isEmpty) return FuzzyMatch.none;
  if (key.contains(_literalOf(segments))) return FuzzyMatch.literal;
  if (!fuzzySearchEnabled) return FuzzyMatch.none;
  final reading = _readingFor(segments);
  for (final (kind, variant) in reading.variants) {
    if (key.contains(variant)) return kind;
  }
  if (reading.stems.isNotEmpty && scriptureText != null) {
    if (fuzzySearchStemKey(scriptureText).contains(reading.stems)) {
      return FuzzyMatch.stem;
    }
  }
  // The loosest rung, and the only one that drops adjacency. Two
  // conjuncts minimum — `segmentedConjuncts` guarantees it — because
  // one fragment of a query is not a broader reading of it, it is a
  // different and shorter search.
  if (reading.conjuncts.length >= 2) {
    var all = true;
    for (final c in reading.conjuncts) {
      if (!key.contains(c)) {
        all = false;
        break;
      }
    }
    if (all) return FuzzyMatch.segmented;
  }
  return FuzzyMatch.none;
}

/// Whether [key] is a hit for [segments] at all.
///
/// The predicate the scan loop wants, and identical to the bare
/// `key.contains(query)` it replaced while the switch is off — which is
/// the shipped default.
bool fuzzySearchMatches(
  String key,
  List<String> segments, {
  String? scriptureText,
}) =>
    fuzzySearchMatchKind(key, segments, scriptureText: scriptureText) !=
    FuzzyMatch.none;

// ── What the row says ───────────────────────────────────────────────

/// The string key naming [match], or null when the row needs no label.
///
/// Null for [FuzzyMatch.literal] — the row holds what the reader typed,
/// and saying so on every row would drown the four rows that need
/// saying. Null for [FuzzyMatch.none] too, which is what a row from a
/// different engine looks like: a Strong's hit, a boolean-operator hit
/// and an AI-resolved reference never went through this matcher, and
/// labelling one "not a match" would be a lie about a verse that is
/// legitimately in the list.
String? fuzzyMatchStringKey(FuzzyMatch match) {
  switch (match) {
    case FuzzyMatch.script:
      return 'fuzzyLabelScript';
    case FuzzyMatch.synonym:
      return 'fuzzyLabelSynonym';
    case FuzzyMatch.stem:
      return 'fuzzyLabelStem';
    case FuzzyMatch.segmented:
      return 'fuzzyLabelSegmented';
    case FuzzyMatch.literal:
    case FuzzyMatch.none:
      return null;
  }
}

/// [reference] as the result row should print it: unchanged for a
/// literal hit, and with the rung's name appended for a broadened one.
///
/// Cheap enough to call from a row builder, and cheapest of all in the
/// case that matters: while `fuzzySearchEnabled` is false this returns
/// [reference] before touching the verse text at all, so a reader who
/// never turned the feature on pays one boolean read per drawn row.
///
/// [scriptureText] must be the same string the search ran over —
/// `Verse.text`, which is what `MainProvider.searchKeys` is built from.
/// Passing already-sanitised text instead would ask about a different
/// string than the one that matched, and the row would sometimes claim
/// a literal hit for a verse the looser rung found.
String fuzzyLabelledReference(
  String reference, {
  required String query,
  required String scriptureText,
  required String locale,
}) {
  if (!fuzzySearchEnabled) return reference;
  if (query.trim().isEmpty) return reference;
  final segments = fuzzySearchSegments(query);
  if (segments.isEmpty) return reference;
  final kind = fuzzySearchMatchKind(
    fuzzySearchCorpusKey(scriptureText),
    segments,
    scriptureText: scriptureText,
  );
  final key = fuzzyMatchStringKey(kind);
  if (key == null) return reference;
  final label =
      fuzzySearchStrings[key]?[locale] ?? fuzzySearchStrings[key]?['en'] ?? '';
  if (label.isEmpty) return reference;
  return '$reference · $label';
}
