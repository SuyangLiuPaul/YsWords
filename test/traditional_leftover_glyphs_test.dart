import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Traditional CUV is a script conversion of the Simplified one, and the
/// converter that produced it had holes. The first was the classifier 隻
/// (see traditional_classifier_test.dart, which pins that one). Comparing the
/// whole corpus against an independently imported Traditional edition — git
/// blob `7a2dc43`, readable with `git cat-file -p 7a2dc43` — found ~1,100 more
/// simplified characters left standing in a Bible that claims to be
/// Traditional. So 詩篇 51:7 read 「潔凈」, 尼希米記 4:6 「城墻」 and
/// 歷代志上 11:8 「其余的」.
///
/// These nine were fixed first because they are the unambiguous ones: the
/// witness writes the Traditional form in every place ours writes the
/// simplified, and all 1,004 occurrences were confirmed one at a time
/// (tools/repair_tr_leftover_glyphs.py, which refuses if any cannot be).
///
/// STILL OUTSTANDING, and deliberately not asserted here: the one-to-many
/// classes, where one simplified glyph maps to several Traditional characters
/// and each occurrence needs its own decision — 幹 (乾 dry / 干 offend / the
/// names 亞幹, 亞多尼幹), 發 (發 issue / 髮 hair), 谷 (穀 grain / 谷 valley),
/// 松 (鬆 loosen / 松 pine), 采. That is why 詩篇 51:7 still reads 幹淨 rather
/// than 乾淨 — half of that phrase is fixed here and half is queued.
void main() {
  const path = 'assets/cuvs-yhwh-tr.json';

  /// Simplified form → the Traditional character this corpus always means,
  /// with the number of times it occurs. The counts come from the witness,
  /// which has 淨 518 / 牆 234 / 餘 230 / 鎔 12 and the rest identical; the two
  /// differences are edition differences that were read: 民數記 35:33 repeats
  /// the word inside an inline note here and not there, and 耶利米書 9:7 sets
  /// 融化 here where the witness sets 鎔化.
  const expected = <String, ({String traditional, int count})>{
    '凈': (traditional: '淨', count: 519),
    '墻': (traditional: '牆', count: 234),
    '余': (traditional: '餘', count: 230),
    '镕': (traditional: '鎔', count: 11),
    '鸮': (traditional: '鴞', count: 3),
    '飖': (traditional: '颻', count: 3),
    '腌': (traditional: '醃', count: 2),
    '珰': (traditional: '璫', count: 1),
    '鹯': (traditional: '鸇', count: 1),
  };

  late List<Map<String, dynamic>> verses;
  late String blob;

  setUpAll(() {
    verses = (json.decode(File(path).readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();
    blob = verses.map((v) => v['text'] as String).join();
  });

  test('no simplified-only glyph is left in the Traditional Bible', () {
    for (final entry in expected.entries) {
      final offenders = <String>[];
      for (final v in verses) {
        final text = v['text'] as String;
        final i = text.indexOf(entry.key);
        if (i < 0) continue;
        offenders.add('${v['book']} ${v['chapter']}:${v['verse']} — '
            '${text.substring((i - 4).clamp(0, text.length), (i + 4).clamp(0, text.length))}');
      }
      expect(offenders, isEmpty,
          reason: '${entry.key} has no Traditional reading in this corpus; it '
              'is ${entry.value.traditional}. Re-run '
              'tools/repair_tr_leftover_glyphs.py.');
    }
  });

  test('each Traditional form is present in the number the witness has', () {
    for (final entry in expected.entries) {
      final t = entry.value.traditional;
      expect(blob.split(t).length - 1, entry.value.count,
          reason: '$t should occur ${entry.value.count} times');
    }
  });

  test('the verses a reader would notice read correctly', () {
    String textOf(String book, String chapter, String verse) => verses
        .firstWhere((v) =>
            v['book'] == book &&
            '${v['chapter']}' == chapter &&
            '${v['verse']}' == verse)['text'] as String;

    expect(textOf('尼希米記', '4', '6'), contains('修造城牆'));
    expect(textOf('歷代志上', '11', '8'), contains('城牆，其餘的'));
    expect(textOf('詩篇', '51', '7'), contains('潔淨我'));
    expect(textOf('約伯記', '28', '2'), contains('銅從石中鎔化'));
    expect(textOf('利未記', '11', '17'), contains('鴞鳥'));
    expect(textOf('士師記', '9', '9'), contains('飄颻'));
    expect(textOf('馬可福音', '9', '49'), contains('鹽醃'));
    expect(textOf('以賽亞書', '3', '16'), contains('腳下玎璫'));
    expect(textOf('申命記', '14', '13'), contains('鸇'));
  });
}
