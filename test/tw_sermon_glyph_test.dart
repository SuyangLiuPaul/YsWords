import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Traditional sermon transcripts' spot glyph errors, pinned after
/// `tools/repair_tw_sermon_dry_glyph.py` (18 substitutions) and
/// `tools/repair_tw_sermon_spot_glyphs.py` (109), both applied 2026-09-03.
///
/// **This corpus does NOT have the CUV converter hole** and the tests below are
/// written so that nobody can conclude otherwise from them. `assets/sermons/
/// zh-TW/` was produced by a phrase-aware converter: it holds 隻 453, 淨 358,
/// 牆 257, 餘 190, 髮 121, 鬆 133 and zero 凈 / 墻 / 余. None of the
/// `tools/repair_tr_*.py` scripts applies here. What it had was spot errors in
/// four classes, and the counts on both sides are pinned so that a re-import
/// cannot silently undo them and a later sweep cannot silently widen them.
///
/// There is no witness edition for sermon text. Every repair rested either on
/// the corpus's own lopsided convention (恆 276:2, 採取 54:3, 麪包 41:8) or on
/// the sentence itself. So the KEEP side is pinned as hard as the fix side —
/// it is the only thing standing between this corpus and a blanket rule.
void main() {
  late String blob;
  late Map<String, String> files;

  setUpAll(() {
    files = <String, String>{};
    for (final f in Directory('assets/sermons/zh-TW').listSync()) {
      if (f is File) {
        files[f.uri.pathSegments.last] = f.readAsStringSync();
      }
    }
    blob = files.values.join();
  });

  int count(String s) => blob.split(s).length - 1;

  group('乾 / 干 / 幹 — the three-way split', () {
    test('142 幹 became 124, and every one that moved was dryness or offence',
        () {
      expect(count('幹'), 124);
      for (final gone in const [
        '嘴幹', '幹沙子', '幹擾', '幹淨', '凍幹', '水庫幹了', '溪也幹了',
        '哭幹了', '幹枯', '排幹了', '幹蘿蔔', '就是不幹',
      ]) {
        expect(count(gone), 0,
            reason: '$gone — re-run tools/repair_tw_sermon_dry_glyph.py');
      }
      expect(count('乾蘿蔔'), 4);
      expect(count('干擾'), greaterThanOrEqualTo(2));
    });

    test('幹 survives wherever it means a trunk, a cadre or doing', () {
      // The 發/髮 shape. The claim was never "幹 is wrong" — 124 of the
      // original 142 are right, and a blanket substitution fails here.
      for (final keep in const [
        '才幹', '幹什麼', '幹部', '幹活', '樹幹', '軀幹', '骨幹', '主幹道',
        '幹掉', '能幹', '幹得好', '幹嘛',
      ]) {
        expect(count(keep), greaterThan(0), reason: keep);
      }
      expect(files['098.txt'], contains('我不幹了'));
      expect(files['097.txt'], contains('幹了一整天'));
    });
  });

  group('斗 — a measuring bowl, not a fight', () {
    test('馬太福音 5:15 no longer puts the lamp under a 鬥', () {
      // The most serious defect in this corpus: scripture quoted with the
      // wrong glyph, ten times. 「放在鬥底下」 says the lamp is put under a
      // FIGHT.
      expect(count('鬥底下'), 0);
      expect(count('斗底下'), 10);
      // Nine quote 馬太福音 5:15; the tenth is 075.txt quoting 路加福音 8:16
      // as 「放在牀底下或鬥底下」, which the first draft of the repair missed
      // because its cue came from the Matthew wording alone.
      expect(count('三鬥面'), 0);
      expect(count('三斗麪'), 2, reason: '馬太福音 13:33');
    });

    test('every other 鬥 is a fight and stays', () {
      // 231 鬥 before, 219 after. An inventory count could never have found
      // the twelve; only the collocation could.
      expect(count('鬥'), 219);
      for (final keep in const ['戰鬥', '爭鬥', '搏鬥', '打鬥', '奮鬥', '好鬥']) {
        expect(count(keep), greaterThan(0), reason: keep);
      }
      expect(files['360.txt'], contains('斗篷'), reason: 'a cloak was already 斗');
      expect(files['371.txt'], contains('升斗'), reason: '路 6:38 was already 斗');
    });
  });

  group('麪 — flour, in this corpus never spelt 麵', () {
    test('the house form is 麪 and there is no 麵 anywhere', () {
      // Both are standard Traditional and this repo uses BOTH — cuvs-yhwh-tr
      // and biblexg-v2-tr set 麵, this corpus and assets/strongs set 麪. An
      // audit that counts only 麵 calls all 289 files a flour hole.
      expect(count('麪'), 164);
      expect(count('麵'), 0,
          reason: 'a sweep imported the other asset family\'s spelling');
    });

    test('no flour word is left spelt 面', () {
      for (final gone in const ['面酵', '麥面', '團面']) {
        expect(count(gone), 0, reason: gone);
      }
      expect(count('麪酵'), 63);
      expect(count('麥麪'), 4);   // 3 repaired + 1 that was already right
      expect(count('麪包'), 49);
    });

    test('079.txt sets 麪 for the dough where it stands alone', () {
      // Fifteen positions a collocation rule cannot reach. If these revert,
      // the sermon contradicts itself again — it already wrote 麪粉 and 麪包
      // 21 times in the same file.
      final leaven = files['079.txt']!;
      for (final reading in const [
        '神的國好像麪，有婦人', '你們既是無酵的麪', '一個要點。麪是由什麼做的',
        '麪酵在麪中做什麼', '它對麪沒有任何貢獻',
      ]) {
        expect(leaven, contains(reading), reason: reading);
      }
    });

    test('面 survives as a face, a side and an aspect', () {
      expect(count('面'), 5887);
      for (final keep in const ['裏面', '面前', '方面', '面對', '前面', '畫面']) {
        expect(count(keep), greaterThan(0), reason: keep);
      }
      expect(files['073.txt'], contains('它裏面包含了極大的真理'),
          reason: '裏面 + 包含 — the 面包 rule needs its negative lookbehind');
    });
  });

  group('採 — to pick or adopt', () {
    test('采取 and 采納 are gone', () {
      expect(count('采取'), 0);
      expect(count('采納'), 0);
      expect(count('採取'), 57);
      expect(count('採納'), 4);
    });

    test('采 survives in 風采, 興高采烈 and Nietzsche', () {
      // 尼采 is the trap: five occurrences of a philosopher's name that a
      // blanket 采→採 would have renamed.
      expect(count('尼采'), 5);
      expect(count('風采'), greaterThan(0));
      expect(count('興高采烈'), greaterThan(0));
      expect(count('尼採'), 0, reason: 'a blanket 采→採 ran');
    });
  });

  test('the Simplified twins were not touched', () {
    // assets/sermons/zh-CN/ writes 干 for all three of 干/乾/幹, 面 for both
    // 面/麪, 斗 for 斗, 采 for 采/採 — every one of those is the correct single
    // Simplified form. The twins are why each reading above could be read with
    // confidence; they are not themselves a defect.
    final cn = File('assets/sermons/zh-CN/751.txt').readAsStringSync();
    expect(cn, contains('干萝卜'));
    expect(cn.contains('乾'), isFalse);
    final cn079 = File('assets/sermons/zh-CN/079.txt').readAsStringSync();
    expect(cn079, contains('面酵'));
    expect(cn079.contains('麪'), isFalse);
  });
}
