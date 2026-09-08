/// 2026-09-08: the Porter stemmer, against the vector Porter published.
///
/// The examples asserted here are not this project's. They are the
/// per-rule examples from the canonical description of the algorithm —
/// Porter, M. F. (1980), "An algorithm for suffix stripping", *Program*
/// 14(3), 130-137, republished with the same examples at
/// <https://snowballstem.org/algorithms/porter/stemmer.html> — and they
/// are asserted STEP BY STEP because that is the form they were
/// published in. Testing `porterStem('relational') == 'relat'` would be
/// testing a number this project computed; testing
/// `porterStep2('relational') == 'relate'` is testing the number Porter
/// printed.
///
/// The full 23,531-word vocabulary Porter also publishes (`voc.txt` /
/// `output.txt`, 0.19 MB) is deliberately NOT vendored: it would put a
/// large word list in this repository under no stated licence, to check
/// rules that a page of published examples already checks. The reasoning
/// is `porter_stemmer.dart`'s own, and it is the same rule that keeps
/// another app's dictionaries out of `assets/`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/utils/porter_stemmer.dart';

void main() {
  void published(String label, String Function(String) step,
      Map<String, String> vector) {
    test('$label matches every example Porter published for it', () {
      for (final entry in vector.entries) {
        expect(step(entry.key), entry.value,
            reason: '${entry.key} should give ${entry.value}');
      }
    });
  }

  group('the published per-rule vector', () {
    published('step 1a', porterStep1a, const {
      'caresses': 'caress',
      'ponies': 'poni',
      'ties': 'ti',
      'caress': 'caress',
      'cats': 'cat',
    });

    published('step 1b', porterStep1b, const {
      'feed': 'feed',
      'agreed': 'agree',
      'plastered': 'plaster',
      'bled': 'bled',
      'motoring': 'motor',
      'sing': 'sing',
      'conflated': 'conflate',
      'troubled': 'trouble',
      'sized': 'size',
      'hopping': 'hop',
      'tanned': 'tan',
      'falling': 'fall',
      'hissing': 'hiss',
      'fizzed': 'fizz',
      'failing': 'fail',
      'filing': 'file',
    });

    published('step 1c', porterStep1c, const {
      'happy': 'happi',
      'sky': 'sky',
    });

    published('step 2', porterStep2, const {
      'relational': 'relate',
      'conditional': 'condition',
      'rational': 'rational',
      'valenci': 'valence',
      'hesitanci': 'hesitance',
      'digitizer': 'digitize',
      'conformabli': 'conformable',
      'radicalli': 'radical',
      'differentli': 'different',
      'vileli': 'vile',
      'analogousli': 'analogous',
      'vietnamization': 'vietnamize',
      'predication': 'predicate',
      'operator': 'operate',
      'feudalism': 'feudal',
      'decisiveness': 'decisive',
      'hopefulness': 'hopeful',
      'callousness': 'callous',
      'formaliti': 'formal',
      'sensitiviti': 'sensitive',
      'sensibiliti': 'sensible',
    });

    published('step 3', porterStep3, const {
      'triplicate': 'triplic',
      'formative': 'form',
      'formalize': 'formal',
      'electriciti': 'electric',
      'electrical': 'electric',
      'hopeful': 'hope',
      'goodness': 'good',
    });

    published('step 4', porterStep4, const {
      'revival': 'reviv',
      'allowance': 'allow',
      'inference': 'infer',
      'airliner': 'airlin',
      'gyroscopic': 'gyroscop',
      'adjustable': 'adjust',
      'defensible': 'defens',
      'irritant': 'irrit',
      'replacement': 'replac',
      'adjustment': 'adjust',
      'dependent': 'depend',
      'adoption': 'adopt',
      'homologou': 'homolog',
      'communism': 'commun',
      'activate': 'activ',
      'angulariti': 'angular',
      'homologous': 'homolog',
      'effective': 'effect',
      'bowdlerize': 'bowdler',
    });

    published('step 5', porterStep5, const {
      'probate': 'probat',
      'rate': 'rate',
      'cease': 'ceas',
      'controll': 'control',
      'roll': 'roll',
    });
  });

  group("Porter's own definitions", () {
    test('a y is a consonant at the start of a word and a vowel after one',
        () {
      expect(porterIsConsonant('yes', 0), isTrue);
      expect(porterIsConsonant('happy', 4), isFalse);
      expect(porterIsConsonant('toy', 2), isTrue);
      expect(porterIsConsonant('sky', 2), isFalse);
    });

    test('the measure counts vowel-consonant pairs, as the paper says', () {
      for (final word in const ['tr', 'ee', 'tree', 'y', 'by']) {
        expect(porterMeasure(word), 0, reason: word);
      }
      for (final word in const ['trouble', 'oats', 'trees', 'ivy']) {
        expect(porterMeasure(word), 1, reason: word);
      }
      for (final word in const ['troubles', 'private', 'oaten', 'orrery']) {
        expect(porterMeasure(word), 2, reason: word);
      }
    });
  });

  group('the whole pipeline, on words this app will actually be asked for',
      () {
    test('every inflection of love lands on the same stem', () {
      for (final form in const ['love', 'loved', 'loves', 'loving']) {
        expect(porterStem(form), 'love', reason: form);
      }
    });

    test('a word with nothing to strip comes back unchanged', () {
      for (final word in const ['god', 'faith', 'walk', 'run', 'sky']) {
        expect(porterStem(word), word);
      }
    });

    test('a stem is not a word, and the caller must never show one', () {
      // Documented in the library comment, and pinned here so that a
      // future caller printing a stem breaks a test rather than a
      // reader's trust.
      expect(porterStem('happy'), 'happi');
      expect(porterStem('relational'), 'relat');
      expect(porterStem('ponies'), 'poni');
    });

    test('the y-alternation blind spot is real and is not papered over', () {
      // Porter cannot join these, this implementation does not pretend
      // to, and `fuzzy_search.dart` says so where a reader-facing claim
      // is made. If a future change fixes it, it also changed the
      // algorithm and this file no longer tests the published vector.
      expect(porterStem('flies'), isNot(porterStem('fly')));
      expect(porterStem('skies'), isNot(porterStem('sky')));
    });

    test('the KJV verb endings Porter never met are left alone', () {
      // -eth and -est are not in the 1980 rule set. `believeth` keeping
      // its ending is the honest outcome; inventing two rules would
      // silently fork somebody else's published algorithm.
      expect(porterStem('believeth'), 'believeth');
      expect(porterStem('doest'), 'doest');
    });

    test('anything that is not lower-case English is returned untouched',
        () {
      for (final word in const [
        '雅伟',
        'θεος',
        'Love',
        "god's",
        'H3068',
        'is',
      ]) {
        expect(porterStem(word), word, reason: word);
      }
    });
  });
}
