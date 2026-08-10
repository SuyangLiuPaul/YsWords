import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the Traditional 梁家鏗譯本 against 简→繁 conversion errors.
///
/// **This test asserts conformity to the publisher's own Traditional
/// edition, not to good Chinese.** That distinction cost something:
/// a first pass "corrected" 會堂里→會堂裡, 谷糧→穀糧 and 踹谷→踹穀 on the
/// reasoning that 里 is a distance unit and 谷 is a valley — all true,
/// and all wrong here, because the printed 註釋本 (2025 第二版) reads
/// 會堂里, 谷糧 and 踹谷 in exactly those places. Editing scripture to
/// match one's own sense of correctness is the failure mode this whole
/// area is about. Those spellings are now reported to the publisher
/// instead (`docs/梁家鏗譯本-缺陷報告.md`) and left as they print them.
///
/// What IS asserted: the conversion artefacts, where our text disagrees
/// with the printed edition and the printed edition is plainly right.
///   哥林多前書 4:9  一台戲 → 一臺戲  (the 註釋本 prints 臺)
///
/// Source of truth: `讀_繁_註釋本` volumes 1-5, the publisher's own
/// Traditional PDFs, which do have a clean text layer.
void main() {
  late String traditional;

  setUpAll(() {
    final rows = json.decode(
        File('assets/biblexg-v2-tr.json').readAsStringSync()) as List;
    traditional =
        rows.map((r) => (r as Map)['text'] as String? ?? '').join('\n');
  });

  test('matches the printed edition where we once diverged', () {
    expect(traditional, contains('一臺戲'),
        reason: '哥林多前書 4:9 — the 註釋本 prints 臺');
    expect(traditional.contains('一台戲'), isFalse);
  });

  test('leaves the publisher\'s own spellings alone', () {
    // Present in the printed edition. We report them; we do not "fix"
    // them. If the publisher revises, these expectations change WITH
    // the source — never ahead of it.
    expect(traditional, contains('會堂里'),
        reason: '馬可福音 1:23 prints 里 in the 註釋本, however odd it '
            'looks beside 會堂裡 elsewhere in the same volume');
    expect(traditional, contains('谷糧'), reason: '使徒行傳 7:12');
    expect(traditional, contains('踹谷'), reason: '哥林多前書 9:9 / 提摩太前書 5:18');
  });

  test('no simplified form survived the conversion', () {
    // These have no legitimate use in a Traditional text, so a single
    // occurrence means the converter missed one. Verified absent
    // against the printed edition too.
    for (final simplified in ['发', '复', '历', '尽', '云', '钟', '划', '后',
                              '汇', '虽', '样', '记', '门', '过', '书', '东']) {
      expect(traditional.contains(simplified), isFalse,
          reason: 'simplified 「$simplified」 survived into the Traditional '
              'text — the converter missed it');
    }
  });
}
