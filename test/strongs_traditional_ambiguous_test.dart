import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Strong's lexicon's Traditional fields, pinned after
/// `tools/repair_strongs_tw_ambiguous.py` (applied 2026-09-03, 89
/// substitutions across 84 fields).
///
/// This is NOT the converter-hole defect the `traditional_*_glyph_test.dart`
/// family pins. Those files ask "does this asset hold zero of a Traditional
/// character it needs" — an inventory question. `assets/strongs/hebrew.json`
/// and `greek.json` have no holes at all: their `glossZhTw` / `defZhTw` are
/// `opencc -c s2t` of `glossZh` / `defZh`. opencc never fails to convert; it
/// fails by choosing the WRONG expansion where one Simplified character maps
/// to several Traditional ones, and the character it writes is always a
/// perfectly good Traditional character. **An inventory count can never find
/// these**, which is why this test pins readings rather than totals.
///
/// The evidence for every substitution is the Simplified twin sitting in the
/// same entry, so this file also pins the twins: if a re-import changes what
/// the source says, that must fail here rather than quietly making the
/// Traditional field wrong again.
///
/// Both directions are pinned. A revert fails the "repaired" groups; a blanket
/// substitution of any of these rules fails the "must survive" group, which is
/// the half that matters — five of the seven 複合 and six of the ten 回覆
/// would have been corrupted by the obvious rule.
void main() {
  late Map<String, dynamic> hebrew;
  late Map<String, dynamic> greek;
  late String tw;
  late String sc;

  setUpAll(() {
    hebrew = json.decode(File('assets/strongs/hebrew.json').readAsStringSync())
        as Map<String, dynamic>;
    greek = json.decode(File('assets/strongs/greek.json').readAsStringSync())
        as Map<String, dynamic>;
    final twBuf = StringBuffer();
    final scBuf = StringBuffer();
    for (final doc in [hebrew, greek]) {
      for (final entry in doc.values.cast<Map<String, dynamic>>()) {
        for (final f in ['glossZhTw', 'defZhTw']) {
          if (entry[f] != null) twBuf.write(entry[f]);
        }
        for (final f in ['glossZh', 'defZh']) {
          if (entry[f] != null) scBuf.write(entry[f]);
        }
      }
    }
    tw = twBuf.toString();
    sc = scBuf.toString();
  });

  int inTw(String s) => tw.split(s).length - 1;
  int inSc(String s) => sc.split(s).length - 1;

  String field(String id, String name) {
    final doc = id.startsWith('H') ? hebrew : greek;
    return (doc[id] as Map<String, dynamic>)[name] as String;
  }

  group('the wrong expansions are gone', () {
    test('no name is spelt with 乾 or 幹 where the syllable is gan', () {
      // 亞干 (Achan, 書 7) used to be printed THREE ways — 亞乾, 亞幹, and
      // never 亞干 — so a reader looking the name up was shown a spelling the
      // Bible text itself does not use.
      for (final wrong in const [
        '亞多尼幹', '亞多尼乾', '亞乾', '亞幹', '瑪拉幹', '雅幹', '伯・哈幹',
      ]) {
        expect(inTw(wrong), 0, reason: '$wrong — re-run '
            'tools/repair_strongs_tw_ambiguous.py');
      }
      expect(inTw('亞干'), greaterThanOrEqualTo(4));
      expect(inTw('亞多尼干'), 3);
    });

    test('dryness reads 乾, interference reads 干', () {
      for (final wrong in const [
        '幹物', '幹河', '變幹', '幹掉', '被幹涸', '被幹擾',
      ]) {
        expect(inTw(wrong), 0, reason: wrong);
      }
      expect(inTw('乾物'), 6);
      expect(inTw('乾河'), 5);
      expect(inTw('被干擾'), 1);
    });

    test('the remaining single readings', () {
      const gone = <String, String>{
        '被髮出': '被發出',      // 髮 is hair, not sending
        '徵服': '征服',
        '莫丘裏': '莫丘里',      // Mercurius is a name
        '睏倦': '困倦',          // 睏 is drowsiness
        '疲睏': '疲困',
        '闢拉': '辟拉',          // Bilhah
        '併成為': '並成為',
        '被複興': '被復興',
        '蔘加': '參加',          // 蔘 is ginseng
        '細面': '細麪',
        '新谷': '新穀',
        '葡萄藤的須': '葡萄藤的鬚',
        '帶須的兀鷹': '帶鬚的兀鷹',
      };
      gone.forEach((wrong, right) {
        expect(inTw(wrong), 0, reason: wrong);
        expect(inTw(right), greaterThan(0), reason: right);
      });
    });

    test('併為 became 並為 everywhere except the one real merger', () {
      expect(inTw('併為'), 2, reason: 'only 合併為 at G2957 may remain');
      expect(inTw('合併為'), 2);
      expect(inTw('並為'), greaterThanOrEqualTo(19));
    });

    test('the locative 里 became 裏; names and distances did not', () {
      for (final wrong in const [
        '谷里的', '文本里', '公會里', '聖經里', '抄本里', '丟入海里',
      ]) {
        expect(inTw(wrong), 0, reason: wrong);
      }
      expect(inTw('公會裏'), 2);
      expect(inTw('抄本裏'), 2);
    });
  });

  group('the readings a blanket rule would have corrupted', () {
    test('複合字 is a COMPOUND WORD and keeps 複', () {
      // Five of the seven 複合 in the file are 複合字 / 複合介詞 and are
      // right. Only G604 — reconciliation, twin 和好, 复合 — moved.
      expect(inTw('複合字'), greaterThanOrEqualTo(3));
      expect(field('G604', 'glossZhTw'), contains('和好, 復合'));
      expect(field('H3050', 'defZhTw'), contains('複合字'));
      expect(inTw('復合字'), 0, reason: 'a blanket 複合→復合 ran');
    });

    test('回覆 survives where the SIMPLIFIED source also wrote 回覆', () {
      // G611, G612, G627 read 回覆 in their Simplified fields too, so opencc
      // never chose it and there is nothing to repair. Six of the ten 回覆
      // would have been corrupted by the obvious rule.
      for (final id in const ['G611', 'G612', 'G627']) {
        expect(field(id, 'glossZhTw'), contains('回覆'), reason: id);
        expect(field(id, 'glossZh'), contains('回覆'),
            reason: '$id: the twin is the witness — if the SOURCE stopped '
                'saying 回覆, this repair needs re-deciding, not re-running');
      }
      expect(field('G330', 'glossZhTw'), contains('回復與先前'));
    });

    test('里 stays 里 in names and in distances', () {
      for (final keep in const [
        '底格里斯', '克里特', '西西里', '暗妃波里', '西里西亞', '萬里晴空',
      ]) {
        expect(inTw(keep), greaterThan(0), reason: keep);
      }
      expect(inTw('裏海'), 4,
          reason: '裏海/裡海 IS the Traditional name for the Caspian — the '
              '裏海→里海 rule was REFUTED and must stay disarmed');
    });

    test('幹 survives where it means a trunk or doing', () {
      for (final keep in const ['樹幹', '枝幹', '主幹', '幹活']) {
        expect(inTw(keep), greaterThan(0), reason: keep);
      }
      expect(inTw('卷鬚'), greaterThan(0),
          reason: 'opencc got this one right on its own');
    });
  });

  test('not one Simplified field was touched', () {
    // The Simplified twin is the evidence for every substitution above. If a
    // repair pass ever edits it, the evidence and the conclusion move
    // together and nothing can be checked afterwards.
    expect(inSc('亚干'), greaterThan(0));
    expect(inSc('辟拉'), greaterThan(0));
    expect(inSc('干物'), 6);
    expect(inSc('细面'), 2);
    // 辟拉 is deliberately NOT in this list: 辟 and 拉 are the same character
    // in both scripts, so the Simplified field reads 辟拉 too — that identity
    // is exactly why the repair was safe, not evidence of a leak.
    for (final leaked in const ['亞干', '乾物', '細麪']) {
      expect(inSc(leaked), 0,
          reason: '$leaked reached a Simplified field — the repair leaked');
    }
  });
}
