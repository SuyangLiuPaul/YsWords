/// 2026-09-08: the provenance of every table in `search_synonyms.dart`,
/// re-established from scratch on every run.
///
/// This is not a test of a constant against itself. Two of the three
/// tables are DERIVED from `assets/cuvs-yhwh.json` and
/// `assets/cuvs-yhwh-tr.json`, and this file re-derives them from those
/// two files and fails if the constants no longer say what the shipped
/// scripture says. That is what makes "derived from data we already
/// own" a checkable claim rather than a comment.
///
/// It matters here more than it did in the repository this was ported
/// from, because the two repositories' copies of these assets are NOT
/// the same files and do not yield the same table — this edition makes
/// the semantic Traditional splits (发/髮, 面/麵, 谷/穀) that the other
/// one does not. A copied table would have been wrong in 38 places;
/// `search_synonyms.dart`'s header lists them. Hence: re-derive, never
/// copy, and let this file be the thing that enforces it.
///
/// The third table, the synonym groups, is hand-authored — so each
/// group is checked against the in-repo evidence its own `evidence`
/// field cites: a verse, a measurement, or the alias table in
/// `strongs_service.dart`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/constants/search_synonyms.dart';
import 'package:yswords/utils/chinese_segmentation.dart' show isHanChar;
import 'package:yswords/utils/fuzzy_result_label.dart'
    show fuzzySearchCorpusKey;

void main() {
  late List<String> simplified;
  late List<String> traditional;

  List<Map<String, dynamic>> load(String asset) => [
        for (final e in jsonDecode(File(asset).readAsStringSync()) as List)
          (e as Map).cast<String, dynamic>(),
      ];

  setUpAll(() {
    final s = load('assets/cuvs-yhwh.json');
    final t = load('assets/cuvs-yhwh-tr.json');
    expect(s.length, t.length);
    for (var i = 0; i < s.length; i++) {
      expect(s[i]['id'], t[i]['id'], reason: 'the two editions must align');
    }
    // Spaces removed from both sides, which is the alignment this
    // repo's data supports and the alignment the search itself uses;
    // the first test below is the one that establishes it.
    simplified = [for (final v in s) (v['text'] as String).replaceAll(' ', '')];
    traditional = [
      for (final v in t) (v['text'] as String).replaceAll(' ', '')
    ];
  });

  group('the Simplified-Traditional table, re-derived from the two shipped '
      'editions', () {
    test('every verse pair is the same length once the spaces come out, '
        'which is what makes the correspondence derivable at all', () {
      var mismatches = 0;
      for (var i = 0; i < simplified.length; i++) {
        if (simplified[i].length != traditional[i].length) mismatches++;
      }
      expect(mismatches, 0);
    });

    test('61 pairs need the spaces out first, so a raw length comparison '
        'would silently throw them away', () {
      // The reason the alignment is space-blind rather than raw. Those
      // 61 differ in nothing but a stray space beside a `<note:>` or a
      // closing quote — 民数记 10:29 and 士师记 1:16 among them — and
      // the repository this file was ported from had none of them, so
      // its derivation could afford to compare raw lengths and this one
      // cannot. Pinned, so that a data sweep which fixes them shows up
      // here as a number to re-check rather than as silence.
      final s = load('assets/cuvs-yhwh.json');
      final t = load('assets/cuvs-yhwh-tr.json');
      var raw = 0;
      for (var i = 0; i < s.length; i++) {
        if ((s[i]['text'] as String).length !=
            (t[i]['text'] as String).length) {
          raw++;
        }
      }
      expect(raw, 61);
    });

    test('the shipped table is exactly the correspondence the text shows',
        () {
      final counts = <String, Map<String, int>>{};
      for (var i = 0; i < simplified.length; i++) {
        final a = simplified[i];
        final b = traditional[i];
        for (var j = 0; j < a.length; j++) {
          final s = a.codeUnitAt(j);
          final t = b.codeUnitAt(j);
          if (s == t) continue;
          if (!isHanChar(s) || !isHanChar(t)) continue;
          final row = counts.putIfAbsent(String.fromCharCode(s), () => {});
          final key = String.fromCharCode(t);
          row[key] = (row[key] ?? 0) + 1;
        }
      }
      final expectedS = StringBuffer();
      final expectedT = StringBuffer();
      for (final s in counts.keys.toList()..sort()) {
        final forms = counts[s]!.entries.toList()
          ..sort((a, b) {
            final byCount = b.value.compareTo(a.value);
            return byCount != 0 ? byCount : b.key.compareTo(a.key);
          });
        for (final form in forms) {
          expectedS.write(s);
          expectedT.write(form.key);
        }
      }
      expect(kCuvSimplifiedChars, expectedS.toString());
      expect(kCuvTraditionalChars, expectedT.toString());
      expect(kCuvSimplifiedChars.length, 1115);
      expect(counts.length, 1111);
    });

    test('no Traditional character stands opposite two Simplified ones, so '
        'that direction has no choice to make', () {
      final back = <String, Set<String>>{};
      for (var i = 0; i < kCuvSimplifiedChars.length; i++) {
        back
            .putIfAbsent(kCuvTraditionalChars[i], () => {})
            .add(kCuvSimplifiedChars[i]);
      }
      expect(back.values.where((v) => v.length > 1), isEmpty);
    });

    test('the four Simplified characters with two Traditional forms list '
        'the commoner one first', () {
      // 发 → 發 1,287 times and 髮 88. Whichever way that is broken
      // decides what `simplifiedToTraditional` produces, so it is
      // pinned rather than left to map iteration order.
      final firstSeen = <String, String>{};
      for (var i = 0; i < kCuvSimplifiedChars.length; i++) {
        firstSeen.putIfAbsent(
            kCuvSimplifiedChars[i], () => kCuvTraditionalChars[i]);
      }
      expect(firstSeen['发'], '發');
      expect(firstSeen['坛'], '壇');
      expect(firstSeen['干'], '乾');
      expect(firstSeen['须'], '須');
    });

    test('this edition makes the semantic splits a one-to-one conversion '
        'cannot, which is why the table may not be shared with another '
        'repository', () {
      // The same characters `traditional_hair_glyph_test.dart`,
      // `traditional_flour_glyph_test.dart` and
      // `traditional_grain_glyph_test.dart` were written to enforce.
      // They are the visible half of a disagreement worth 38 pairs, and
      // a copied table would have lost every one of them.
      final pairs = {
        for (var i = 0; i < kCuvSimplifiedChars.length; i++)
          '${kCuvSimplifiedChars[i]}${kCuvTraditionalChars[i]}',
      };
      for (final p in const ['发髮', '面麵', '谷穀', '松鬆', '胡鬍', '须鬚']) {
        expect(pairs, contains(p), reason: p);
      }
      // And the variant forms this edition swept out stay out.
      for (final p in const ['么麼', '众衆', '吃喫', '症癥', '墙墻']) {
        expect(pairs, isNot(contains(p)), reason: p);
      }
    });
  });

  group('the common-character list, re-derived the same way', () {
    test('is exactly the Han characters in more than a fifth of the verses',
        () {
      final documentFrequency = <String, int>{};
      for (final text in simplified) {
        for (final c in text.split('').toSet()) {
          if (!isHanChar(c.codeUnitAt(0))) continue;
          documentFrequency[c] = (documentFrequency[c] ?? 0) + 1;
        }
      }
      final threshold = (simplified.length * 0.20).floor();
      final over = documentFrequency.entries
          .where((e) => e.value > threshold)
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      expect(over.map((e) => e.key).join(), kCuvCommonHanChars);
      expect(kCuvCommonHanChars.length, 17);
    });

    test('holds 的, which is in four verses out of five', () {
      expect(kCuvCommonHanChars, contains('的'));
    });

    test('holds 雅, because this edition spells the divine name 雅伟', () {
      // The reason the stop filter runs only AFTER vocabulary matching
      // and only on segments one character long: 雅伟 has to survive
      // whole even though 雅 alone narrows nothing.
      expect(kCuvCommonHanChars, contains('雅'));
    });
  });

  group('each synonym group against the evidence it cites', () {
    test('every group states its evidence and holds at least two spellings',
        () {
      for (final group in kSearchSynonymGroups) {
        expect(group.forms.length, greaterThanOrEqualTo(2),
            reason: group.forms.join('/'));
        expect(group.evidence.trim(), isNotEmpty,
            reason: group.forms.join('/'));
      }
    });

    test('no spelling belongs to two groups, or a rewrite would depend on '
        'which was found first', () {
      final seen = <String>{};
      for (final group in kSearchSynonymGroups) {
        for (final form in group.forms) {
          expect(seen.add(form), isTrue, reason: form);
        }
      }
    });

    test('the verse that licenses 彼得 and 矶法 says both of them', () {
      // 约翰福音 1:42, quoted in that group's evidence field. Found by
      // its words rather than by an index, so the check survives a
      // versification change and fails loudly if the sentence does not.
      final witness = simplified.firstWhere(
          (t) => t.contains('矶法翻出来就是彼得'),
          orElse: () => '');
      expect(witness, isNotEmpty,
          reason: 'the synonym group cites a verse the edition must contain');
      expect(witness, contains('彼得'));
    });

    test('the verse that licenses 基督 and 弥赛亚 says both of them', () {
      final witness = simplified.firstWhere(
          (t) => t.contains('弥赛亚') && t.contains('基督'),
          orElse: () => '');
      expect(witness, isNotEmpty);
    });

    test('the numbers the divine-name group quotes are the numbers the '
        'search key really holds', () {
      final keys = [for (final t in simplified) fuzzySearchCorpusKey(t)];
      int hits(String w) => keys.where((k) => k.contains(w)).length;
      // The whole argument for the group: the text says 雅伟, and the
      // spelling every Chinese Bible in print reaches nothing.
      expect(hits('雅伟'), 6106);
      expect(hits('耶和华'), 0);
      // And for the 神 / 上帝 group.
      expect(hits('神'), 3995);
      expect(hits('上帝'), 0);
      // And the two the scripture defines for itself.
      expect(hits('矶法'), 9);
      expect(hits('彼得'), 176);
      expect(hits('弥赛亚'), 2);
      expect(hits('基督'), 542);
    });

    test('the divine name agrees with the alias table in strongs_service, '
        'which is the table this one duplicates', () {
      // Read as source rather than called, because `_aliasToStrongs` is
      // private and this is a guard against the two DRIFTING, not a
      // test of lookup behaviour. Every spelling the fuzzy group will
      // rewrite to must already be one this app pins to the divine
      // name, or the two layers would answer the same query
      // differently.
      final source =
          File('lib/services/strongs_service.dart').readAsStringSync();
      final divine = kSearchSynonymGroups.first;
      expect(divine.forms, contains('雅伟'));
      for (final form in divine.forms) {
        expect(source, contains("'$form': 'H3068'"),
            reason: '$form is in the fuzzy divine-name group but is not '
                'pinned to H3068 in strongs_service.dart');
      }
    });
  });
}
