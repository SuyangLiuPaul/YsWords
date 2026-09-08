/// 2026-09-08 (SeekSparks): the Porter suffix-stripping algorithm, so an
/// English search can reach a word it did not spell.
///
/// ## Provenance and licence
///
/// **Algorithm:** Porter, M. F. (1980), "An algorithm for suffix
/// stripping", *Program* 14(3), pp. 130-137; canonical description and
/// per-rule examples republished at
/// <https://snowballstem.org/algorithms/porter/stemmer.html>.
///
/// **This file is an implementation written for this repository from
/// that published rule table.** No code and no data file was copied from
/// anywhere. Porter's own note on the algorithm is that it is free of
/// restriction, and the reference implementations are BSD; neither
/// matters here, because nothing of theirs is present. There is no
/// dictionary, no word list and no asset — the whole of English
/// inflection is in the rules below, which is exactly why a stemmer was
/// chosen over a shipped lemma table in the first place. See
/// `lib/constants/search_synonyms.dart` for the other half of that
/// argument.
///
/// ## Why Porter (1980) and not Porter2, and not a package
///
/// * **A published test vector exists per rule.** Porter's own examples
///   (`caresses -> caress`, `motoring -> motor`, `sensibiliti ->
///   sensible`) are given step by step, so `test/porter_stemmer_test.dart`
///   can assert against ground truth that was published rather than
///   against numbers this project made up. Porter2's rule set is better
///   at the margins and has no comparably compact published vector; a
///   stemmer nobody can check is not obviously better than one anybody
///   can.
/// * **Not `voc.txt` / `output.txt`.** Porter also publishes a 0.19 MB
///   sample vocabulary and its expected output. Vendoring them would put
///   23k words of Shakespeare-derived vocabulary in `assets/` under no
///   stated licence, to test 200 lines of rules. Rejected on the same
///   ground that keeps 微读's dictionaries out of this repo: if the
///   licence cannot be named, the file does not ship.
/// * **Not a pub dependency.** The algorithm is smaller than the
///   pubspec entry's review would be, it must stay Flutter-free and
///   portable (this file is going into YsWords unchanged), and a
///   dependency is a licence to re-audit on every upgrade.
///
/// BibleWorks reaches the same conclusion from the other end: its own
/// fuzzy search offers Porter stemming, and bwh16 calls it "more of a
/// curiosity than a refined tool". That is a fair verdict on Porter as a
/// *default*, and it is why this app's fuzzy mode is off until asked
/// for. It is not a verdict on Porter as an *option*: `loved` finding
/// "love" is the thing a reader wanted, and Porter delivers it.
///
/// ## What a stem is NOT
///
/// A Porter stem is not a word. `happy` stems to `happi`, `relational`
/// to `relat`, `ponies` to `poni`. Never show one to a reader, and never
/// search for one literally — a stem is only ever compared against
/// another stem. `fuzzy_search.dart` obeys this; anything else that
/// calls in here must too.
///
/// Pure Dart: no Flutter, no assets, no I/O, no global state.
library;

/// Whether the letter at [i] of [word] is a consonant.
///
/// `y` is the whole reason this is a function and not a set membership
/// test: it is a consonant at the start of a word and after a vowel
/// (`yes`, `toy`), and a vowel after a consonant (`happy`, `sky`). The
/// recursion is at most one level deep, because the character it looks
/// back at can only be `y` if that `y` was itself preceded by something.
///
/// [word] may be a prefix of the word being stemmed. The definition only
/// ever looks backwards, so truncating on the right cannot change an
/// answer — which is what lets [porterMeasure] be called on a candidate
/// stem rather than on the whole word.
bool porterIsConsonant(String word, int i) {
  switch (word.codeUnitAt(i)) {
    case 0x61: // a
    case 0x65: // e
    case 0x69: // i
    case 0x6F: // o
    case 0x75: // u
      return false;
    case 0x79: // y
      return i == 0 || !porterIsConsonant(word, i - 1);
    default:
      return true;
  }
}

/// Porter's *m*, the measure of [stem]: the number of vowel-consonant
/// pairs in `[C](VC){m}[V]`.
///
/// It is the algorithm's entire notion of "is there enough word left to
/// take something off it". `tr`, `ee`, `tree` measure 0; `trouble`,
/// `oats`, `ivy` measure 1; `troubles`, `private` measure 2.
int porterMeasure(String stem) {
  final len = stem.length;
  var i = 0;
  var m = 0;
  while (i < len && porterIsConsonant(stem, i)) {
    i++;
  }
  while (i < len) {
    while (i < len && !porterIsConsonant(stem, i)) {
      i++;
    }
    if (i >= len) break; // a trailing V closes no pair
    m++;
    while (i < len && porterIsConsonant(stem, i)) {
      i++;
    }
  }
  return m;
}

/// Porter's `*v*`: [stem] contains a vowel.
bool porterHasVowel(String stem) {
  for (var i = 0; i < stem.length; i++) {
    if (!porterIsConsonant(stem, i)) return true;
  }
  return false;
}

/// Porter's `*d`: [stem] ends in a doubled consonant (`fall`, `hiss`).
bool porterEndsDoubleConsonant(String stem) {
  final n = stem.length;
  if (n < 2) return false;
  if (stem.codeUnitAt(n - 1) != stem.codeUnitAt(n - 2)) return false;
  return porterIsConsonant(stem, n - 1);
}

/// Porter's `*o`: [stem] ends consonant-vowel-consonant where the final
/// consonant is not `w`, `x` or `y` (`hop`, `fil`, `-fail` fails it).
///
/// The three exclusions are Porter's, and they are exclusions because
/// the rule they gate re-adds a silent `e`: `snow`, `box` and `tray`
/// would become `snowe`, `boxe`, `traye`.
bool porterEndsCvc(String stem) {
  final n = stem.length;
  if (n < 3) return false;
  if (!porterIsConsonant(stem, n - 1)) return false;
  if (porterIsConsonant(stem, n - 2)) return false;
  if (!porterIsConsonant(stem, n - 3)) return false;
  final last = stem.codeUnitAt(n - 1);
  return last != 0x77 && last != 0x78 && last != 0x79; // w x y
}

/// Plurals and past participles. `caresses -> caress`, `ponies -> poni`,
/// `cats -> cat`.
String porterStep1a(String w) {
  if (w.endsWith('sses')) return w.substring(0, w.length - 2);
  if (w.endsWith('ies')) return w.substring(0, w.length - 2);
  if (w.endsWith('ss')) return w;
  if (w.endsWith('s')) return w.substring(0, w.length - 1);
  return w;
}

/// `-eed`, `-ed`, `-ing`, and the tidy-up that follows a removal.
///
/// The tidy-up is the interesting half: having taken `-ed` off
/// `hopping` we are left with `hopp`, which is not a word and would not
/// match `hop`. Porter's three repairs — restore the `e` after `at`,
/// `bl`, `iz`; undo a doubled consonant; restore a silent `e` after a
/// short CVC stem — are what make `hopping`, `tanned`, `filing` and
/// `sized` land on `hop`, `tan`, `file` and `size`.
String porterStep1b(String w) {
  var out = w;
  var removed = false;
  if (out.endsWith('eed')) {
    if (porterMeasure(out.substring(0, out.length - 3)) > 0) {
      out = out.substring(0, out.length - 1);
    }
  } else if (out.endsWith('ed')) {
    final stem = out.substring(0, out.length - 2);
    if (porterHasVowel(stem)) {
      out = stem;
      removed = true;
    }
  } else if (out.endsWith('ing')) {
    final stem = out.substring(0, out.length - 3);
    if (porterHasVowel(stem)) {
      out = stem;
      removed = true;
    }
  }
  if (!removed) return out;
  if (out.endsWith('at') || out.endsWith('bl') || out.endsWith('iz')) {
    return '${out}e';
  }
  if (porterEndsDoubleConsonant(out)) {
    final last = out.codeUnitAt(out.length - 1);
    // `fall`, `hiss`, `fizz` keep their pair; every other doubling was
    // an artefact of the suffix.
    if (last != 0x6C && last != 0x73 && last != 0x7A) {
      return out.substring(0, out.length - 1);
    }
    return out;
  }
  if (porterMeasure(out) == 1 && porterEndsCvc(out)) return '${out}e';
  return out;
}

/// Terminal `y` becomes `i` so that step 2 can see it: `happy -> happi`,
/// while `sky` (no vowel before the `y`) is left alone.
String porterStep1c(String w) {
  if (!w.endsWith('y')) return w;
  if (!porterHasVowel(w.substring(0, w.length - 1))) return w;
  return '${w.substring(0, w.length - 1)}i';
}

/// Longest first. Order is load-bearing in a way a map is not: `ational`
/// must be tried before `tional`, and `ization` before `ation`, or
/// `relational` stems to `relation` instead of `relate`.
const List<(String, String)> _step2 = [
  ('ational', 'ate'),
  ('tional', 'tion'),
  ('ization', 'ize'),
  ('iveness', 'ive'),
  ('fulness', 'ful'),
  ('ousness', 'ous'),
  ('biliti', 'ble'),
  ('entli', 'ent'),
  ('ousli', 'ous'),
  ('ation', 'ate'),
  ('alism', 'al'),
  ('aliti', 'al'),
  ('iviti', 'ive'),
  ('enci', 'ence'),
  ('anci', 'ance'),
  ('izer', 'ize'),
  ('abli', 'able'),
  ('alli', 'al'),
  ('ator', 'ate'),
  ('eli', 'e'),
];

const List<(String, String)> _step3 = [
  ('icate', 'ic'),
  ('ative', ''),
  ('alize', 'al'),
  ('iciti', 'ic'),
  ('ical', 'ic'),
  ('ness', ''),
  ('ful', ''),
];

const List<String> _step4 = [
  'ement',
  'ance',
  'ence',
  'able',
  'ible',
  'ment',
  'ant',
  'ent',
  'ism',
  'ate',
  'iti',
  'ous',
  'ive',
  'ize',
  'ion',
  'al',
  'er',
  'ic',
  'ou',
];

/// Derivational suffixes, one only, and only where a real stem remains
/// (`m > 0`).
String porterStep2(String w) {
  for (final (suffix, replacement) in _step2) {
    if (!w.endsWith(suffix)) continue;
    final stem = w.substring(0, w.length - suffix.length);
    if (porterMeasure(stem) > 0) return stem + replacement;
    return w;
  }
  return w;
}

/// A second derivational pass, over what step 2 leaves: `triplicate ->
/// triplic`, `hopeful -> hope`, `goodness -> good`.
String porterStep3(String w) {
  for (final (suffix, replacement) in _step3) {
    if (!w.endsWith(suffix)) continue;
    final stem = w.substring(0, w.length - suffix.length);
    if (porterMeasure(stem) > 0) return stem + replacement;
    return w;
  }
  return w;
}

/// The last suffix, removed outright, and only from a word with two
/// measures left over (`m > 1`) — the guard that keeps `revival ->
/// reviv` from also taking `al` off `rival`.
String porterStep4(String w) {
  for (final suffix in _step4) {
    if (!w.endsWith(suffix)) continue;
    final stem = w.substring(0, w.length - suffix.length);
    if (porterMeasure(stem) <= 1) return w;
    if (suffix == 'ion') {
      // `-ion` comes off only after `s` or `t`: `adoption -> adopt`,
      // but `legion` is not `leg`.
      if (stem.isEmpty) return w;
      final c = stem.codeUnitAt(stem.length - 1);
      if (c != 0x73 && c != 0x74) return w;
    }
    return stem;
  }
  return w;
}

/// Silent `e` (`probate -> probat`, `cease -> ceas`, `rate` kept) and a
/// doubled `l` (`controll -> control`, `roll` kept).
String porterStep5(String w) {
  var out = w;
  if (out.endsWith('e')) {
    final stem = out.substring(0, out.length - 1);
    final m = porterMeasure(stem);
    if (m > 1 || (m == 1 && !porterEndsCvc(stem))) out = stem;
  }
  if (porterMeasure(out) > 1 &&
      porterEndsDoubleConsonant(out) &&
      out.endsWith('l')) {
    out = out.substring(0, out.length - 1);
  }
  return out;
}

/// The stem of [word], or [word] unchanged when the algorithm has
/// nothing to say about it.
///
/// [word] must already be lower-cased — `fuzzy_result_label.dart` does
/// that to both the query and the verse before either reaches here.
/// Anything holding a
/// character outside `a`-`z` is returned untouched rather than mangled:
/// Porter's rules are about English letters, and a Greek, Hebrew or Han
/// string that fell in here would come back with a suffix stripped off a
/// word that never had one. Two letters or fewer are returned untouched
/// too, which is Porter's own floor (`is`, `by`, `to` have no measure to
/// spend).
String porterStem(String word) {
  if (word.length <= 2) return word;
  for (var i = 0; i < word.length; i++) {
    final c = word.codeUnitAt(i);
    if (c < 0x61 || c > 0x7A) return word;
  }
  var w = porterStep1a(word);
  w = porterStep1b(w);
  w = porterStep1c(w);
  w = porterStep2(w);
  w = porterStep3(w);
  w = porterStep4(w);
  w = porterStep5(w);
  return w;
}
