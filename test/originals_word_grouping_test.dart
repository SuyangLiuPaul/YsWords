import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 創世記 35:18 showed בֵּן and אוֹנִי as two chips, both numbered H1126
/// and both glossed 「拉结为便雅悯所取的名字」. The number is right —
/// H1126 is בֶּן־אוֹנִי — but a reader has no way to see that the two
/// chips are halves of one name, so the page said that בֵּן alone means
/// "the name Rachel gave Benjamin". It means "son". The user's reaction
/// was 「这让我觉得 YsWords 里面 exegesis 其实是不准的」.
///
/// `tools/build_originals.py` read only the `<w>` elements of the WLC
/// and so lost every marker that says "these are not two words":
///
///   * `lemma="1035+"` — OSHB's own mark for a non-final member of a
///     multi-word lexeme. This, not the maqqef, is the authority:
///     מוֹת־יוּמַת and קֹדֶשׁ־קָדָשִׁים carry a maqqef and are two words,
///     while בֵּית לָחֶם is one lexeme with no maqqef at all.
///   * `<w type="x-ketiv">` + `<note><rdg type="x-qere">` — a word
///     written one way and read another. Both were emitted as ordinary
///     words, so 1,229 places printed the same word twice, once
///     unpointed and once pointed, and 180 offered a Strong's number
///     for a form that is not read.
///
/// A DATA test on purpose. Every widget test stayed green throughout:
/// the code rendered exactly the tokens it was given.
void main() {
  // Every Hebrew point and cantillation mark EXCEPT the maqqef (U+05BE),
  // which joins words rather than marking one — it has to survive so the
  // shape of a compound stays visible.
  final marks = RegExp(r'[֑-ֽֿ-ׇ]');
  String skeleton(String w) => w.replaceAll(marks, '');

  late Map<String, Map<String, List<Map<String, dynamic>>>> hebrew;

  setUpAll(() {
    hebrew = {};
    for (final file in Directory('assets/originals').listSync().whereType<File>()) {
      if (!file.path.endsWith('.json')) continue;
      final book = file.uri.pathSegments.last.replaceAll('.json', '');
      final raw = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
      final verses = <String, List<Map<String, dynamic>>>{};
      for (final entry in raw.entries) {
        final words = (entry.value as List).cast<Map<String, dynamic>>();
        if (words.isEmpty) continue;
        // Greek books are built from a different source and have none of
        // this structure.
        if (!(words.first['s'] as String).startsWith('H')) {
          verses.clear();
          break;
        }
        verses[entry.key] = words;
      }
      if (verses.isNotEmpty) hebrew[book] = verses;
    }
    expect(hebrew.length, 39, reason: 'expected all 39 Hebrew books');
  });

  List<Map<String, dynamic>> verse(String book, String ref) {
    final words = hebrew[book]?[ref];
    expect(words, isNotNull, reason: '$book $ref missing from the asset');
    return words!;
  }

  group('multi-word lexemes are one word', () {
    // Every one of these is a single Strong's entry whose lemma spans
    // more than one written word, and every one used to be split into a
    // chip per word. Compared consonant-only, so the assertion is about
    // which words are joined and how the WLC joins them — maqqef where
    // it prints a maqqef, space where it prints none — rather than about
    // transcribing cantillation.
    const compounds = <String, List<Object>>{
      'genesis 35:18': ['H1126', ['בן־אוני']], // the reported verse
      'genesis 35:19': ['H1035', ['בית לחם']], // Bethlehem — no maqqef
      'genesis 4:22': ['H8423', ['תובל קין', 'תובל־קין']], // twice, both ways
      'isaiah 8:3': ['H4122', ['מהר שלל חש בז']], // four words, one name
      '1_kings 15:20': ['H62', ['אבל בית־מעכה']], // three words
      '2_samuel 21:16': ['H3430', ['וישבי בנב']], // a compound qere
    };

    for (final entry in compounds.entries) {
      final parts = entry.key.split(' ');
      test(entry.key, () {
        final number = entry.value[0] as String;
        final expected = (entry.value[1] as List).cast<String>();
        final matches =
            verse(parts[0], parts[1]).where((w) => w['s'] == number).toList();
        expect(matches, hasLength(expected.length),
            reason: '$number spans more than one written word, so it should '
                'be ${expected.length} word(s) of ${entry.key}, not '
                '${matches.length}: ${matches.map((w) => w['w']).join(' | ')}');
        expect([for (final w in matches) skeleton(w['w'] as String)], expected);
      });
    }
  });

  group('ketiv/qere is one word of the verse', () {
    test('a word is never printed twice, once unpointed and once pointed',
        () {
      // Six words are written and, by Masoretic direction, not read at
      // all — an empty `<rdg type="x-qere"/>` in the WLC. Two of them
      // sit beside the pointed word they duplicate, so they are the only
      // survivors of this check. They are a known hole, listed here so
      // it cannot quietly grow.
      const accountedFor = {'ezekiel 48:16', 'jeremiah 51:3'};
      final offenders = <String>[];
      hebrew.forEach((book, verses) {
        verses.forEach((ref, words) {
          for (var i = 0; i < words.length - 1; i++) {
            final a = words[i], b = words[i + 1];
            if (a['s'] != b['s']) continue;
            final aPointed = marks.hasMatch(a['w'] as String);
            final bPointed = marks.hasMatch(b['w'] as String);
            if (aPointed == bPointed) continue;
            if (accountedFor.contains('$book $ref')) continue;
            offenders.add('$book $ref  ${a['w']} / ${b['w']} (${a['s']})');
          }
        });
      });
      expect(offenders, isEmpty,
          reason: '${offenders.length} verses print the written form as a '
              'separate word:\n${offenders.take(10).join('\n')}');
    });

    test('the written-but-not-read words are exactly the six known ones', () {
      // Whatever else changes, an unpointed word standing on its own is
      // a word the reader is being shown without being told it is not
      // read. Pin the list so a regression adds to it visibly.
      final unpointed = <String>[];
      hebrew.forEach((book, verses) {
        verses.forEach((ref, words) {
          for (final w in words) {
            if (marks.hasMatch(w['w'] as String)) continue;
            if (w['q'] != null) continue; // read form named alongside it
            unpointed.add('$book $ref');
          }
        });
      });
      expect(unpointed..sort(), [
        '2_kings 5:18',
        'ezekiel 48:16',
        'jeremiah 38:16',
        'jeremiah 39:12',
        'jeremiah 51:3',
        'ruth 3:12',
      ]);
    });

    test('the headword and its Strong\'s number are always the same word',
        () {
      // `k` and `q` both mean "the other form", so a token carrying both
      // would leave it ambiguous which word `s` describes.
      var withKetiv = 0, withQere = 0;
      hebrew.forEach((book, verses) {
        verses.forEach((ref, words) {
          for (final w in words) {
            expect(w['k'] != null && w['q'] != null, isFalse,
                reason: '$book $ref ${w['w']} carries both forms');
            if (w['k'] != null) withKetiv++;
            if (w['q'] != null) withQere++;
          }
        });
      });
      expect(withKetiv, 1229);
      expect(withQere, 19);
    });
  });

  test('the concordance counts words, not halves of words', () {
    final raw = File('assets/strongs/concordance.json').readAsStringSync();
    final index = json.decode(raw) as Map<String, dynamic>;
    // Bethlehem was counted 82 times because both halves were tokens;
    // it occurs 41 times. בֶּן־אוֹנִי occurs once, in 創世記 35:18.
    expect((index['H1035'] as Map)['n'], 41);
    expect((index['H1126'] as Map)['n'], 1);
    expect((index['H4122'] as Map)['n'], 2);
  });
}
