import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:yswords/services/tagged_text_service.dart';

/// `assets/tagged/bsb-yhwh/` and `assets/tagged/asv-yhwh/`, built by
/// `tools/import_ydh_texts.py --tagged` on 2026-09-08.
///
/// Both editions were imported into this repo the same day, from the
/// 雅伟的话 export, by an importer that DROPPED the Strong's markup —
/// `<WH####>` / `<WG####>` — because nothing here read a tagged English
/// layer. The Exegesis picker reads one, so the same importer now takes
/// a second pass over the same source with the numbers kept.
///
/// **The assertion that matters is that the runs concatenate to the
/// verse this app ships.** The sheet prints the tagged runs INSTEAD of
/// the verse; if the two ever disagree, a reader is shown scripture that
/// is not the scripture in the pane behind them. The Chinese layer has a
/// runtime guard for exactly that (`TaggedTextService.coversVerse`,
/// written after 約伯記 10:20 lost a clause), and these two do not need
/// one, because they were built from the same `clean()` pass as the
/// reading asset and are checked against it here verse by verse, all
/// 31,086 of each.
void main() {
  const editions = {
    'bsb-yhwh': (
      runs: 388449,
      numbered: 381927,
      implied: 55633,
      // 16 -> 0, and the marker was not stripped to get there.
      //
      // The BSB edition used to print the publisher's own raw `Lord#`,
      // and `#` is one of the characters `carriesImporterMarkup` treats
      // as a leftover importer tag, so those 16 verses lost the tagged
      // line at load time and fell back to plain text. This entry named
      // that as a trade we were accepting: the text outranks the
      // gesture, and the marker is the publisher's, not ours to delete.
      //
      // `tools/expand_bsb_yhwh_markers.py` has since expanded the raw
      // `Lord#` / `Lord*` into `Lord [Christ]` / `Lord [Jesus]` — the
      // same notation this file already used for `Lord [Yahweh]`, so
      // the marker is still carried, in the form its siblings are
      // carried in. The two meanings are not read off the shape of the
      // mark: the publisher's own Chinese edition sets 主[基督] at 108
      // of the 111 `Lord#` verse ids and 主[耶稣] at 15 of the 16
      // `Lord*` ones, and that correspondence is what established them.
      //
      // With no `#` left in the corpus the guard stops firing, so the
      // count is 0 and all 16 verses have their tagged line back. A
      // rise above 0 still means what it always meant.
      markupVerses: 0,
    ),
    'asv-yhwh': (
      runs: 346832,
      numbered: 346817,
      implied: 0,
      markupVerses: 0,
    ),
  };

  late List<String> books;

  setUpAll(() {
    final kjv = json.decode(File('assets/kjv.json').readAsStringSync())
        as List<dynamic>;
    final seen = <String>{};
    books = [
      for (final r in kjv.cast<Map>())
        if (seen.add(r['book'] as String)) r['book'] as String,
    ];
    expect(books, hasLength(66));
  });

  String fileName(String book) => book.toLowerCase().replaceAll(' ', '_');

  for (final entry in editions.entries) {
    final code = entry.key;
    final want = entry.value;

    test('$code: the runs reproduce every shipped verse exactly', () {
      final reading = json.decode(File('assets/$code.json').readAsStringSync())
          as List<dynamic>;
      final byRef = {
        for (final r in reading.cast<Map>())
          '${r['book']}|${r['chapter']}:${r['verse']}': r['text'] as String,
      };

      var seen = 0;
      final failures = <String>[];
      for (final book in books) {
        final path = 'assets/tagged/$code/${fileName(book)}.json';
        expect(File(path).existsSync(), isTrue, reason: '$path is missing');
        final layer =
            json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;
        for (final v in layer.entries) {
          seen++;
          final want = byRef['$book|${v.key}'];
          expect(want, isNotNull,
              reason: '$code $book ${v.key} is tagged and is not in '
                  'assets/$code.json');
          final got =
              (v.value as List).map((r) => (r as Map)['w'] as String).join();
          if (got != want && failures.length < 5) {
            failures.add('$book ${v.key}\n  runs : $got\n  text : $want');
          }
        }
      }
      expect(failures, isEmpty,
          reason: 'the tagged runs are not the verse this app ships:\n'
              '${failures.join('\n')}');
      // The sixteen Received-Text verses the critical text omits are
      // absent from the reading asset, so they are absent here too.
      expect(seen, 31086);
      expect(byRef, hasLength(31086));
    });

    test('$code: run, number and implied counts are the ones the importer '
        'declared', () {
      var runs = 0;
      var numbered = 0;
      var implied = 0;
      var withGrammar = 0;
      for (final book in books) {
        final layer = json.decode(
                File('assets/tagged/$code/${fileName(book)}.json')
                    .readAsStringSync())
            as Map<String, dynamic>;
        for (final v in layer.values) {
          for (final r in (v as List).cast<Map>()) {
            runs++;
            if ((r['s'] as String).isNotEmpty) numbered++;
            implied += ((r['i'] as List?) ?? const []).length;
            if (r.containsKey('g')) withGrammar++;
          }
        }
      }
      expect(runs, want.runs);
      expect(numbered, want.numbered);
      expect(implied, want.implied);
      // Neither module carries a tense/voice/mood code anywhere, so the
      // key is not written at all rather than written empty. An empty
      // list would claim the question was asked and came back nothing.
      expect(withGrammar, 0);
    });

    test('$code: is offered as a tagged version', () {
      expect(TaggedTextService.supports(code), isTrue);
    });

    test('$code: the verses `carriesImporterMarkup` drops are the counted '
        'ones', () {
      var dropped = 0;
      for (final book in books) {
        final layer = json.decode(
                File('assets/tagged/$code/${fileName(book)}.json')
                    .readAsStringSync())
            as Map<String, dynamic>;
        for (final v in layer.values) {
          if (TaggedTextService.carriesImporterMarkup(v as List)) dropped++;
        }
      }
      expect(dropped, want.markupVerses,
          reason: 'these verses lose the tagged line at load time — a rise '
              'means the import let a Strong\'s tag through into the '
              'printed text, which the sheet would show a reader as '
              'scripture');
    });
  }
}
