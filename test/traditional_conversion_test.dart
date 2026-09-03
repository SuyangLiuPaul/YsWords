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

  test('the seven MORE spellings a 2026-09-03 pass tried to "correct"', () {
    // This group exists because the two above were not enough. A Traditional
    // glyph audit reached this file, found seven further readings that look
    // exactly like one-to-many conversion errors, wrote a guarded and
    // idempotent repair for all ten, and applied it. The test above caught it
    // and the commit was reverted in full.
    //
    // Each was then checked against the source rather than argued about:
    // 讀_繁_註釋本 2025 第二版, five volumes, `pdftotext -enc UTF-8`. The
    // printed edition reads every one of them exactly as we carry them.
    // They are pinned individually so the next pass fails on the specific
    // reading it is about to change, not on a neighbour.
    expect(traditional, contains('兩只麻雀'),
        reason: '馬太福音 10:29 — the print reads 「兩只麻雀…牠一隻也不會掉在'
            '地上」, so 只 and 隻 are NINE CHARACTERS APART in the publisher\'s '
            'own verse. That inconsistency is theirs. It is a reason to ask '
            'them (docs/梁家鏗譯本-請教出版方.md), never a licence to edit them '
            '— and it is the argument the reverted pass found most convincing');
    expect(traditional, contains('五隻麻雀'),
        reason: '路加福音 12:6 — the parallel, and the print DOES set 隻 here. '
            'Two printed spellings of one word is not our defect to fix');
    expect(traditional, contains('把兩只船裝得滿滿的'),
        reason: '路加福音 5:7 — the reading the queue item named as '
            '"certainly wrong". The print has it verbatim');
    expect(traditional, contains('希斯侖'),
        reason: '馬太福音 1:3 and 路加福音 3:33, Hezron. The CUV writes 希斯崙 '
            '×17 — a different edition, not an authority over this one');
    expect(traditional, contains('疾病得到治愈的'),
        reason: '路加福音 8:2, printed 治愈 even though this file sets 治癒 / '
            '痊癒 26 times elsewhere');
    expect(traditional, contains('那致命傷又愈合了'), reason: '啟示錄 13:3');
    expect(traditional, contains('致命傷已得愈合的獸'), reason: '啟示錄 13:12');
  });

  test('路加福音 8:3\'s note quotes 8:2 with the printed spelling too', () {
    // The one place where a `text`-only pin would not have been enough: the
    // note repeats the verse text, and the print sets 治愈 in BOTH. A repair
    // that moved only one would have made the note misquote the verse.
    final rows = json.decode(
        File('assets/biblexg-v2-tr.json').readAsStringSync()) as List;
    final row = rows.cast<Map<String, dynamic>>()
        .firstWhere((r) => r['id'] == '42008003');
    expect((row['blockNotes'] as List).join(), contains('疾病得到治愈的'));
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
