import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Sixth instalment of the converter-hole defect (see
/// traditional_classifier_test.dart for 隻, traditional_leftover_glyphs_test
/// .dart for 淨/牆/餘, traditional_hair_glyph_test.dart for 髮,
/// traditional_beard_glyph_test.dart for 鬍/鬚/採 and
/// traditional_flour_glyph_test.dart for 麵). Simplified 坛 collapses two
/// Traditional characters — 壇 (altar) and 罈 (an earthenware jar) — and the
/// converter resolved every one of them to 壇, so the widow's jar of meal in the
/// Elijah narrative was an *altar*: 「壇內只有一把麵」.
///
/// Like 髮 and 麵, and unlike 淨/牆/餘, this could not be fixed by substitution:
/// 壇 is CORRECT 607 times here and wrong 6 times. Both directions are pinned
/// below — a blanket substitution fails the third test, a revert fails the first
/// two and the fourth.
void main() {
  const path = 'assets/cuvs-yhwh-tr.json';

  late List<Map<String, dynamic>> verses;
  late String blob;

  setUpAll(() {
    verses = (json.decode(File(path).readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();
    blob = verses.map((v) => v['text'] as String).join();
  });

  String textOf(String book, String chapter, String verse) => verses
      .firstWhere((v) =>
          v['book'] == book &&
          '${v['chapter']}' == chapter &&
          '${v['verse']}' == verse)['text'] as String;

  int count(String s) => blob.split(s).length - 1;

  test('jars are written 罈, in the number the witness has', () {
    expect(count('罈'), 6);
    expect(count('壇'), 607);
  });

  test('no reading that can only be a jar is left setting 壇', () {
    const cues = <String>['壇內只有', '壇內的麵', '各壇都要盛滿', '的壇子'];
    final offenders = <String>[];
    for (final v in verses) {
      final text = v['text'] as String;
      for (final cue in cues) {
        if (!text.contains(cue)) continue;
        offenders.add('${v['book']} ${v['chapter']}:${v['verse']} — $cue');
      }
    }
    expect(offenders, isEmpty, reason: 'Re-run tools/repair_tr_jar_glyph.py.');
  });

  test('altars still read 壇', () {
    // A blanket 壇→罈 substitution would break every one of these. The last two
    // are the trap: 「各壇」 occurs four times and only the two in 耶利米書 13:12
    // are jars, so a repair keyed on that string would desecrate both of these.
    expect(textOf('創世紀', '8', '20'), contains('挪亞為雅偉築了一座壇'));
    expect(textOf('出埃及記', '27', '1'), contains('你要用皂莢木做壇'));
    expect(textOf('列王紀上', '18', '30'), contains('重修已經毀壞雅偉的壇'));
    expect(textOf('列王紀上', '18', '35'), contains('水流在壇的四圍'));
    expect(textOf('使徒行傳', '17', '23'), contains('遇見一座壇'));
    expect(textOf('歷代志下', '33', '15'), contains('所築的各壇都拆毀'));
    expect(textOf('阿摩司書', '2', '8'), contains('他們在各壇旁鋪人所當的衣服'));
  });

  test('the verses a reader would notice read correctly', () {
    // KJV: "an handful of meal in a barrel", "the barrel of meal shall not
    // waste", "Every bottle shall be filled with wine", "break their bottles".
    expect(textOf('列王紀上', '17', '12'), contains('罈內只有一把麵'));
    expect(textOf('列王紀上', '17', '14'), contains('罈內的麵必不減少'));
    expect(textOf('列王紀上', '17', '16'), contains('罈內的麵果不減少'));
    expect(textOf('耶利米書', '13', '12'), contains('各罈都要盛滿了酒'));
    expect(textOf('耶利米書', '48', '12'), contains('打碎它的罈子'));
  });
}
