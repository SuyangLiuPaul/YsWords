/// 2026-09-08: the looser reading of a search — that it is off, that
/// turning it off puts the engine back where it was, and that every row
/// it adds can be told from a row the reader typed.
///
/// Every count in this file was measured against the shipped editions,
/// through the same two functions the real scan calls. If one moves,
/// the engine changed and the tables in `fuzzy_search.dart` and
/// `search_synonyms.dart` are now lies as well.
///
/// The counts are YsWords' own and do not match the repository this was
/// ported from, for a reason worth stating once: this app's search key
/// has every ASCII space removed from it, so a query reaches across a
/// word boundary. `forth` finds 3,419 verses of the KJV here and 877
/// there, because "for the" becomes "forthe". That is a property of the
/// engine this feature was added to, not of the feature; it is the same
/// before and after, and no rung below touches it.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/constants/fuzzy_search_strings.dart';
import 'package:yswords/constants/text_patterns.dart' show sanitizeForSearch;
import 'package:yswords/utils/fuzzy_result_label.dart';
import 'package:yswords/utils/fuzzy_search.dart';

void main() {
  late List<String> kjv;
  late List<String> kjvText;
  late List<String> cuvs;
  late List<String> cuvsText;
  late Map<String, String> cuvsById;

  List<Map<String, dynamic>> load(String asset) => [
        for (final e in jsonDecode(File(asset).readAsStringSync()) as List)
          (e as Map).cast<String, dynamic>(),
      ];

  setUpAll(() {
    final k = load('assets/kjv.json');
    final c = load('assets/cuvs-yhwh.json');
    kjvText = [for (final v in k) v['text'] as String];
    cuvsText = [for (final v in c) v['text'] as String];
    kjv = [for (final t in kjvText) fuzzySearchCorpusKey(t)];
    cuvs = [for (final t in cuvsText) fuzzySearchCorpusKey(t)];
    cuvsById = {for (final v in c) v['id'] as String: v['text'] as String};
  });

  tearDown(() {
    resetFuzzySearchForTest();
    resetFuzzyResultLabelForTest();
  });

  Map<FuzzyMatch, int> byKind(
      List<String> keys, List<String> texts, String query) {
    final segments = fuzzySearchSegments(query);
    final out = <FuzzyMatch, int>{};
    for (var i = 0; i < keys.length; i++) {
      final kind = fuzzySearchMatchKind(keys[i], segments,
          scriptureText: texts[i]);
      if (kind == FuzzyMatch.none) continue;
      out[kind] = (out[kind] ?? 0) + 1;
    }
    return out;
  }

  int hits(List<String> keys, List<String> texts, String query) {
    final segments = fuzzySearchSegments(query);
    var n = 0;
    for (var i = 0; i < keys.length; i++) {
      if (fuzzySearchMatches(keys[i], segments, scriptureText: texts[i])) n++;
    }
    return n;
  }

  group('the key this feature compares against', () {
    test('is built exactly the way MainProvider builds the array the scan '
        'actually walks', () {
      // `fuzzySearchCorpusKey` is a second copy of one expression, and
      // a second copy is a thing that drifts. The row builder calls in
      // here while the scan reads `MainProvider.searchKeys`, so a
      // divergence would draw a row as literal that the scan found on a
      // looser rung. Read as source because the provider is another
      // file's business; this fails loudly the day that expression
      // changes, which is the point.
      final source =
          File('lib/providers/main_provider.dart').readAsStringSync();
      // Line breaks and their indentation only — a blanket
      // whitespace strip would eat the space INSIDE `replaceAll(' ',
      // '')`, which is the one character this expression turns on.
      final unwrapped = source.replaceAll(RegExp(r'\n\s*'), '');
      expect(
        unwrapped,
        contains("sanitizeForSearch(verses[i].text).replaceAll(' ', '')"
            '.toLowerCase()'),
      );
      for (final text in cuvsText.take(200)) {
        expect(fuzzySearchCorpusKey(text),
            sanitizeForSearch(text).replaceAll(' ', '').toLowerCase());
      }
    });
  });

  group('the divine name, which was broken before any of this and is '
      'fixed whether or not the switch is on', () {
    test('the spelling every Chinese Bible in print uses stops finding '
        'nothing', () {
      // The bug: `MainProvider.searchKeys` runs the verse through
      // `sanitizeForSearch`, which rewrites 耶和华 to 雅伟, and the query
      // went through nothing. One side normalised, the other not.
      expect(fuzzySearchEnabled, isFalse);
      expect(byKind(cuvs, cuvsText, '耶和华'), {FuzzyMatch.literal: 6106});
      expect(byKind(cuvs, cuvsText, '雅伟'), {FuzzyMatch.literal: 6106});
    });

    test('is a LITERAL hit, not a broadened one, so no row is labelled for '
        'it', () {
      // It is the query finally being asked the same question the index
      // was — not a looser reading of it. A reader who types the only
      // name they were ever taught is owed the verses, not an
      // explanation.
      setFuzzySearchEnabled(true);
      expect(byKind(cuvs, cuvsText, '耶和华'), {FuzzyMatch.literal: 6106});
    });

    test('cannot have taken a row away, because the key never held the '
        'unnormalised spelling in the first place', () {
      expect(cuvs.where((k) => k.contains('耶和华')), isEmpty);
      expect(cuvs.where((k) => k.contains('耶和華')), isEmpty);
    });
  });

  group('the switch', () {
    test('is off, and stays off until something turns it on', () {
      expect(fuzzySearchEnabled, isFalse);
    });

    test('reports whether it actually moved, so a caller can skip an '
        'invalidation it does not need', () {
      final start = fuzzySearchGeneration;
      expect(setFuzzySearchEnabled(false), isFalse);
      expect(fuzzySearchGeneration, start);
      expect(setFuzzySearchEnabled(true), isTrue);
      expect(fuzzySearchGeneration, greaterThan(start));
    });
  });

  group('with the switch off, the engine is the engine it was', () {
    test('every verse of the KJV gets the same answer as the bare '
        'substring scan this replaced, for queries of every shape', () {
      for (final query in const [
        'love',
        'loved',
        'yahweh',
        'in the beginning',
        'for the',
        'forth',
        'jehovah',
        'faith',
      ]) {
        final segments = fuzzySearchSegments(query);
        final old = query.replaceAll(' ', '').toLowerCase();
        for (var i = 0; i < kjv.length; i++) {
          expect(fuzzySearchMatches(kjv[i], segments, scriptureText: kjvText[i]),
              kjv[i].contains(old),
              reason: '$query at verse $i');
        }
      }
    });

    test('the Chinese probes are untouched too, except the divine name, '
        'which only gains', () {
      for (final query in const ['爱', '爱神', '这诫命', '雅伟']) {
        final segments = fuzzySearchSegments(query);
        final old = query.replaceAll(' ', '').toLowerCase();
        for (var i = 0; i < cuvs.length; i++) {
          expect(
              fuzzySearchMatches(cuvs[i], segments,
                  scriptureText: cuvsText[i]),
              cuvs[i].contains(old),
              reason: '$query at verse $i');
        }
      }
      // And the one query whose answer did move, moved from nothing.
      expect(cuvs.where((k) => k.contains('耶和华')).length, 0);
      expect(hits(cuvs, cuvsText, '耶和华'), 6106);
    });

    test('the counts this engine has always produced still come out', () {
      expect(hits(kjv, kjvText, 'forth'), 3419);
      expect(hits(kjv, kjvText, 'faith'), 339);
      expect(hits(kjv, kjvText, 'for the'), 2029);
      expect(hits(kjv, kjvText, 'love'), 573);
      expect(hits(cuvs, cuvsText, '爱'), 822);
      expect(hits(cuvs, cuvsText, '这诫命'), 4);
      expect(hits(cuvs, cuvsText, '神'), 3995);
    });

    test('a query the looser rungs exist for still finds nothing', () {
      // 磯法 shares no character with 矶法, so nothing but a rung could
      // ever reach it. This is the row that appears when the reader
      // turns the switch on, and it must be absent until they do.
      expect(hits(cuvs, cuvsText, '磯法'), 0);
      expect(hits(cuvs, cuvsText, '上帝'), 0);
    });
  });

  group('with the switch on', () {
    setUp(() => setFuzzySearchEnabled(true));

    test('the 上帝版 reader reaches the 神版 this app ships', () {
      expect(byKind(cuvs, cuvsText, '上帝'), {FuzzyMatch.synonym: 3995});
    });

    test('a Traditional query reaches a Simplified edition, by script '
        'first and by synonym after', () {
      // 磯法 shares no character with 矶法, so no substring rule could
      // ever have found it. The script rung finds the 9 verses that
      // spell it, the synonym rung the 175 more that call the same man
      // 彼得, and the order is what the labels report.
      expect(byKind(cuvs, cuvsText, '磯法'),
          {FuzzyMatch.script: 9, FuzzyMatch.synonym: 175});
      expect(byKind(cuvs, cuvsText, '愛'), {FuzzyMatch.script: 822});
      expect(byKind(cuvs, cuvsText, '彌賽亞'),
          {FuzzyMatch.script: 2, FuzzyMatch.synonym: 540});
    });

    test('an English query reaches the other forms of its own verb', () {
      // `loved` found 200 verses and missed the 573 that say "love",
      // because a substring scan reaches forwards and not back.
      expect(byKind(kjv, kjvText, 'loved'),
          {FuzzyMatch.literal: 200, FuzzyMatch.stem: 383});
    });

    test('a verb form sharing no substring with the query is reachable at '
        'last', () {
      // "loving" does not hold the letters l-o-v-e in a row, so no
      // substring rule was ever going to reach it from `love`. This is
      // the case that killed the first version of the stem rung, which
      // skipped the stemmed pass whenever stemming left the QUERY
      // unchanged — as it does for `love`, whose stem is itself.
      expect(byKind(kjv, kjvText, 'love'),
          {FuzzyMatch.literal: 573, FuzzyMatch.stem: 12});
    });

    test('a Chinese phrase in no verse falls back to its own words, apart',
        () {
      // The loosest rung, and the only one that drops adjacency.
      expect(byKind(cuvs, cuvsText, '信心的祷告'), {FuzzyMatch.segmented: 4});
    });

    test('a query with nothing looser about it is left exactly alone', () {
      expect(byKind(kjv, kjvText, 'faith'), {FuzzyMatch.literal: 339});
      expect(byKind(cuvs, cuvsText, '神'), {FuzzyMatch.literal: 3995});
    });

    test('turning it on only ever ADDS rows: every literal hit is still a '
        'hit, and is still labelled literal', () {
      for (final probe in const [
        ('kjv', 'loved'),
        ('kjv', 'love'),
        ('kjv', 'forth'),
        ('cuvs', '爱'),
        ('cuvs', '矶法'),
        ('cuvs', '这诫命'),
        ('cuvs', '耶和华'),
      ]) {
        final keys = probe.$1 == 'kjv' ? kjv : cuvs;
        final texts = probe.$1 == 'kjv' ? kjvText : cuvsText;
        final segments = fuzzySearchSegments(probe.$2);
        final literal = segments.join();
        for (var i = 0; i < keys.length; i++) {
          if (!keys[i].contains(literal)) continue;
          expect(
              fuzzySearchMatchKind(keys[i], segments, scriptureText: texts[i]),
              FuzzyMatch.literal,
              reason: probe.$2);
        }
      }
    });

    test('the stem rung is skipped, not guessed at, when the caller has no '
        'verse text to give it', () {
      // The one rung that cannot work from the space-stripped key. A
      // caller without the raw text gets the literal answer rather than
      // a wrong one.
      final segments = fuzzySearchSegments('loved');
      var withText = 0;
      var without = 0;
      for (var i = 0; i < kjv.length; i++) {
        if (fuzzySearchMatchKind(kjv[i], segments,
                scriptureText: kjvText[i]) ==
            FuzzyMatch.stem) {
          withText++;
        }
        if (fuzzySearchMatchKind(kjv[i], segments) == FuzzyMatch.stem) {
          without++;
        }
      }
      expect(withText, 383);
      expect(without, 0);
    });
  });

  group('what the result row says', () {
    String label(String query, String verseId) => fuzzyLabelledReference(
          '约翰福音 1:42',
          query: query,
          scriptureText: cuvsById[verseId]!,
          locale: 'zh-Hans',
        );

    test('says nothing at all while the switch is off', () {
      // 马太福音 4:18 says 彼得 and does not say 矶法, so this row would
      // be labelled if anything were going to be.
      expect(label('矶法', '040004018'), '约翰福音 1:42');
    });

    test('says nothing on a row that holds what the reader typed', () {
      setFuzzySearchEnabled(true);
      expect(label('彼得', '040004018'), '约翰福音 1:42');
    });

    test('says nothing on a row the divine-name fix found, because that '
        'row holds what the reader asked for', () {
      setFuzzySearchEnabled(true);
      // The first verse of the edition to say 雅伟.
      final id = cuvsById.entries
          .firstWhere((e) => e.value.contains('雅伟'))
          .key;
      expect(label('耶和华', id), '约翰福音 1:42');
    });

    test('names the rung that found a row the reader did not type', () {
      setFuzzySearchEnabled(true);
      expect(label('矶法', '040004018'), '约翰福音 1:42 · 同名异写');
      expect(label('磯法', '043001042'), '约翰福音 1:42 · 异体字');
    });

    test('answers in the reader\'s own script, all three of them', () {
      setFuzzySearchEnabled(true);
      String at(String locale) => fuzzyLabelledReference(
            'John 1:42',
            query: '磯法',
            scriptureText: cuvsById['043001042']!,
            locale: locale,
          );
      expect(at('zh-Hans'), 'John 1:42 · 异体字');
      expect(at('zh-Hant'), 'John 1:42 · 異體字');
      expect(at('en'), 'John 1:42 · other script');
    });

    test('falls back to English rather than to nothing for a locale the '
        'table has never heard of', () {
      setFuzzySearchEnabled(true);
      expect(
        fuzzyLabelledReference('John 1:42',
            query: '磯法',
            scriptureText: cuvsById['043001042']!,
            locale: 'ms'),
        'John 1:42 · other script',
      );
    });

    test('says nothing about a blank query', () {
      setFuzzySearchEnabled(true);
      expect(label('   ', '040004018'), '约翰福音 1:42');
    });
  });

  group('every string this feature says out loud', () {
    test('carries all three locales, on every key', () {
      expect(fuzzySearchStrings, isNotEmpty);
      for (final entry in fuzzySearchStrings.entries) {
        for (final locale in const ['zh-Hans', 'zh-Hant', 'en']) {
          final value = entry.value[locale];
          expect(value, isNotNull, reason: '${entry.key} has no $locale');
          expect(value!.trim(), isNotEmpty, reason: '${entry.key} $locale');
        }
      }
    });

    test('names one label per broadened rung, and none for the two that '
        'need no label', () {
      for (final m in FuzzyMatch.values) {
        final key = fuzzyMatchStringKey(m);
        if (m == FuzzyMatch.literal || m == FuzzyMatch.none) {
          expect(key, isNull, reason: '$m');
        } else {
          expect(key, isNotNull, reason: '$m');
          expect(fuzzySearchStrings.containsKey(key), isTrue,
              reason: '$m names $key, which the string table does not hold');
        }
      }
    });
  });

  group('the pure layer, which came from another repository and may go to '
      'a third', () {
    test('imports nothing but dart and its own four files', () {
      // The portability claim in `fuzzy_search.dart`'s header, made
      // checkable. `fuzzy_result_label.dart` is deliberately not in
      // this list: it is the YsWords glue, and it is a separate file so
      // that this list can stay short.
      const portable = [
        'lib/utils/fuzzy_search.dart',
        'lib/utils/porter_stemmer.dart',
        'lib/utils/chinese_segmentation.dart',
        'lib/constants/search_synonyms.dart',
        'lib/constants/fuzzy_search_strings.dart',
      ];
      const allowed = {
        'package:yswords/constants/search_synonyms.dart',
        'package:yswords/utils/chinese_segmentation.dart',
        'package:yswords/utils/porter_stemmer.dart',
        'package:yswords/utils/fuzzy_search.dart',
      };
      final importLine = RegExp(r"^import '([^']+)'", multiLine: true);
      for (final path in portable) {
        for (final m in importLine.allMatches(File(path).readAsStringSync())) {
          final uri = m.group(1)!;
          expect(uri.startsWith('dart:') || allowed.contains(uri), isTrue,
              reason: '$path imports $uri, which does not travel');
        }
      }
    });

    test('the glue is the only file that reaches into the rest of the app',
        () {
      // The other half of the same claim. If a second file starts
      // importing `text_patterns.dart` or `app_settings.dart` to do
      // fuzzy work, the layer is no longer liftable and this fails
      // before anyone finds that out by trying.
      final glue = File('lib/utils/fuzzy_result_label.dart').readAsStringSync();
      expect(glue, contains("package:yswords/constants/text_patterns.dart"));
      expect(glue, isNot(contains('package:flutter/')));
    });
  });
}
