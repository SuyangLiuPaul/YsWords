import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/models/verse.dart';

/// 路加福音 23:34a — the publisher's doubtful-passage affix used to be
/// printed at readers as three literal characters in the middle of 23:33:
///
///   「…右手一個，左手一個。34a耶穌說：父親啊，赦免他們…」
///
/// User, 2026-09-02: 「34a这些能够也做成像经文可以选择的节吗」. It is now a
/// verse of its own, labelled `34a`, and `tools/repair_biblexg_luke_23_34a.py`
/// re-applies the split (it is idempotent) after the Traditional rebuild
/// that is still waiting on the publisher.
///
/// The thing most likely to break this silently is the SORT. 34a and the
/// existing 34 both hold `verse: 34`, `compareTo` on the number returns 0
/// for that pair, and **Dart's sort is not stable** — so the two halves
/// would render in whatever order the implementation happened to produce.
/// `Verse.subVerseOrder` is the tiebreak, and the tests below are written
/// against the real comparator rather than against the asset's array
/// order, because the asset's order is not what the reader sees.
void main() {
  List<Map<String, dynamic>> load(String path) =>
      (json.decode(File(path).readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();

  const editions = {
    'assets/biblexg-v2.json': '路加福音',
    'assets/biblexg-v2-tr.json': '路加福音',
  };

  editions.forEach((path, book) {
    group(path, () {
      List<Verse> chapter23() => load(path)
          .where((m) => m['book'] == book && m['chapter'] == '23')
          .map(Verse.fromJson)
          .toList();

      test('no literal sub-verse affix survives anywhere in the edition', () {
        // The whole class, not just the one verse: if a future import
        // reintroduces `12b` somewhere else, this is where it shows up.
        final affix = RegExp(r'\d{1,3}[a-dA-D](?![0-9a-zA-Z])');
        final hits = <String>[];
        for (final m in load(path)) {
          if (affix.hasMatch(m['text'] as String)) {
            hits.add('${m['book']} ${m['chapter']}:${m['verse']}');
          }
        }
        expect(hits, isEmpty,
            reason: 'a verse number is printed inside running text at $hits');
      });

      test('23:33 ends at the sentence, and 34a carries the rest', () {
        final vs = chapter23();
        final v33 = vs.firstWhere((v) => v.verseLabel == '33');
        final v34a = vs.firstWhere((v) => v.verseLabel == '34a');
        expect(v33.text, endsWith('。'));
        expect(v33.text, isNot(contains('34a')));
        expect(v34a.text, anyOf(contains('赦免他們'), contains('赦免他们')));
        expect(v34a.verse, 34,
            reason: 'the label is 34a but the NUMBER must stay 34 — '
                'everything numeric still keys off it');
      });

      test('34a and 34 are distinct selectable verses with distinct ids', () {
        final vs = chapter23();
        final ids = vs.map((v) => v.id).toList();
        expect(ids.toSet(), hasLength(ids.length),
            reason: 'two verses in one chapter share an id; a highlight on '
                'one would land on the other');
        final v34a = vs.firstWhere((v) => v.verseLabel == '34a');
        final v34 = vs.firstWhere((v) => v.verseLabel == '34');
        expect(v34a.id, endsWith('-34a'));
        // The load-bearing half of the design: verse 34's id is UNCHANGED,
        // so every existing highlight and note on Luke 23:34 — in this and
        // every other edition — stays exactly where it was. Relabelling it
        // 34b to match the print would have moved all of them.
        expect(v34.id, endsWith('-34'));
      });

      test('the real comparator puts 34a before 34b', () {
        final vs = chapter23()..shuffle();
        // Same comparator as main_provider._buildVersesByChapterIndex and
        // fetch_verses' canonical sort.
        vs.sort((a, b) {
          final n = a.verse.compareTo(b.verse);
          return n != 0 ? n : a.subVerseOrder.compareTo(b.subVerseOrder);
        });
        final labels = vs.map((v) => v.verseLabel).toList();
        expect(labels.indexOf('34a'), lessThan(labels.indexOf('34')),
            reason: 'the halves are out of reading order');
        expect(labels.indexOf('33'), lessThan(labels.indexOf('34a')));
        expect(labels.indexOf('34'), lessThan(labels.indexOf('35')));
      });

      test('the tiebreak is actually set, not accidentally passing', () {
        // A shuffle can put them in the right order by luck if BOTH hold
        // subVerseOrder 0 — assert the ordinal itself so the previous
        // test cannot pass for the wrong reason.
        final vs = chapter23();
        expect(vs.firstWhere((v) => v.verseLabel == '34a').subVerseOrder, 0);
        expect(vs.firstWhere((v) => v.verseLabel == '34').subVerseOrder, 1);
      });
    });
  });

  test('subVerseOrder defaults to 0 and is 0 in every other edition', () {
    // The field exists for exactly two verses. If an import ever starts
    // emitting it broadly, that is a change worth noticing.
    expect(const Verse(book: 'X', chapter: 1, verse: 1, text: 't').subVerseOrder,
        0);
    for (final path in ['assets/cuvs-yhwh.json', 'assets/kjv.json']) {
      final n = load(path)
          .where((m) => (m['subVerseOrder'] as num?) != null)
          .length;
      expect(n, 0, reason: '$path unexpectedly carries subVerseOrder');
    }
  });
}
