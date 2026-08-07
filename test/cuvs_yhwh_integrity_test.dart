import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const expected = <String, Map<String, String>>{
    'assets/cuvs-yhwh.json': {
      '007013007':
          '却对我说：你要怀孕生一个儿子，所以清酒浓酒都不可喝，一切不洁之物也'
          '不可吃；因为这孩子从出胎一直到死，必归神作拿细耳人。',
      '007018010':
          '你们到了那里，必看见安居无虑的民，地也宽阔。神已将那地交在你们手'
          '中；那地百物俱全，一无所缺。',
    },
    'assets/cuvs-yhwh-tr.json': {
      '007013007':
          '卻對我說：你要懷孕生一個兒子，所以清酒濃酒都不可喝，一切不潔之物'
          '也不可吃；因為這孩子從出胎一直到死，必歸神作拿細耳人。',
      '007018010':
          '你們到了那裏，必看見安居無慮的民，地也寬闊。神已將那地交在你們手'
          '中；那地百物俱全，一無所缺。',
    },
  };

  for (final spec in expected.entries) {
    group('${spec.key} integrity', () {
      late List<dynamic> verses;

      setUpAll(() async {
        verses = json.decode(await rootBundle.loadString(spec.key))
            as List<dynamic>;
      });

      test('has 31,102 verses and no missing-glyph marker', () {
        expect(verses, hasLength(31102));
        expect(
          verses.where((verse) =>
              ((verse as Map<String, dynamic>)['text'] as String)
                  .contains('□')),
          isEmpty,
        );
      });

      for (final verse in spec.value.entries) {
        test('${verse.key} matches the verified source text', () {
          final match = verses.firstWhere(
            (item) => (item as Map<String, dynamic>)['id'] == verse.key,
          ) as Map<String, dynamic>;
          expect(match['text'], verse.value);
        });
      }
    });
  }
}
