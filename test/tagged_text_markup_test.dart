import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/services/tagged_text_service.dart';

/// The Originals sheet prints the tagged runs *instead of* the verse —
/// `originals_sheet.dart` renders `_taggedVerseLine(vo.tagged!)` for any
/// verse that has tagging. So the translation text in
/// `assets/tagged/cuvs-yhwh/` is scripture on screen, and 185 verses of
/// it carried the importer's own Strong's markers:
///
///   詩篇 7:5      `使<WH7931s>我的荣耀归于灰尘`
///   創世記 3:16   `又对<WH413<女人说`
///   列王紀上 21:8 `送给<WH5612x那些与拿伯同城居住的长老>贵胄`
///   路加福音 20:42 对我主# 说
///
/// The last two are the reason this is a scripture-accuracy defect and
/// not a cosmetic one. In 列王紀上 21:8 the marker swallows twelve
/// characters of the verse, so a reader cannot tell which part is the
/// text; and `主#` stands where the edition prints 主[基督] — its own
/// referent gloss, the same bracket it kept intact for 主[雅伟] two
/// words earlier in 使徒行傳 2:34.
///
/// A DATA test on purpose. Every widget test stayed green throughout:
/// the code rendered exactly the runs it was given.
void main() {
  /// `<`, `>`, the `#`, and a bare `WH853x` that lost both brackets.
  /// ASCII appears nowhere else in this asset except inside the CUV's
  /// own 〔創10:3作"利法"〕 cross-reference notes, which carry no `WH`.
  final markup = RegExp(r'[<>#]|[Ww][HhGgJjMm][0-9]+');

  late Map<String, Map<String, List<dynamic>>> tagged;

  setUpAll(() {
    tagged = {};
    for (final f
        in Directory('assets/tagged/cuvs-yhwh').listSync().whereType<File>()) {
      if (!f.path.endsWith('.json')) continue;
      final book = f.uri.pathSegments.last.replaceAll('.json', '');
      tagged[book] = (json.decode(f.readAsStringSync()) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v as List<dynamic>));
    }
  });

  test('the tagged text carries no importer markup', () {
    // 歷代志上 21:17 stores 「行了恶<WH的8687>」 and 耶利米書 4:22 stores
    // 「愚昧无知<WH873我7>的儿女」. Both markers ate a Chinese character,
    // and `assets/cuvs-yhwh.json` shows both belong in a different
    // clause — 「吩咐數點百姓**的**不是我嗎」, 「不認識**我**」. Deleting
    // the marker would strand the character where it does not belong
    // and moving it would be reconstruction, so they are listed here
    // rather than guessed at, and the loader drops them so neither is
    // printed to a reader.
    const unsettled = {'1_chronicles 21:17', 'jeremiah 4:22'};

    final found = <String>[];
    tagged.forEach((book, verses) {
      verses.forEach((ref, runs) {
        final text = runs
            .map((r) => (r as Map<String, dynamic>)['w'] as String? ?? '')
            .join();
        if (markup.hasMatch(text)) found.add('$book $ref');
      });
    });

    expect(found.toSet(), unsettled,
        reason: 'a Strong\'s marker left in the printed text is shown to '
            'the reader as scripture');
  });

  test('every verse the marker touched still reads as the edition prints it',
      () {
    // The 15 verses where `主#` stood. The gloss is restored from the
    // reading asset's own characters, never written by hand.
    const glossVerses = {
      'matthew': ['22:43', '22:44', '22:45'],
      'mark': ['12:36', '12:37'],
      'luke': ['20:42', '20:44'],
      'acts': ['2:34'],
      'romans': ['14:9'],
      '1_corinthians': ['11:20', '11:26', '11:27'],
      '1_thessalonians': ['4:15', '4:16', '4:17'],
    };

    glossVerses.forEach((book, refs) {
      for (final ref in refs) {
        final text = tagged[book]![ref]!
            .map((r) => (r as Map<String, dynamic>)['w'] as String? ?? '')
            .join();
        expect(text, contains('主[基督]'),
            reason: '$book $ref should print the edition\'s own referent '
                'gloss, not a placeholder');
        expect(text, isNot(contains('#')));
      }
    });
  });

  test('a verse whose runs still carry markup is not offered as text', () {
    expect(
      TaggedTextService.carriesImporterMarkup([
        {'w': '使<WH7931s>我的荣耀', 's': 'H3519'},
      ]),
      isTrue,
    );
    expect(
      TaggedTextService.carriesImporterMarkup([
        {'w': '对我主# ', 's': 'G2962'},
      ]),
      isTrue,
    );
    expect(
      TaggedTextService.carriesImporterMarkup([
        {'w': '仆人WH853x和婢女', 's': 'H5650'},
      ]),
      isTrue,
    );
    // The edition's own cross-reference note has digits in it and is
    // ordinary text — 〔創10:3作"利法"〕 must survive.
    expect(
      TaggedTextService.carriesImporterMarkup([
        {'w': '〔创10:3作"利法"〕、陀迦玛。', 's': 'H8425'},
      ]),
      isFalse,
    );
    expect(
      TaggedTextService.carriesImporterMarkup([
        {'w': '主[基督]', 's': 'G2962'},
      ]),
      isFalse,
    );
  });
}
