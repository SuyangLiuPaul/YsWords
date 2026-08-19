import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Seven more verses were short, and the two external witnesses could not find
/// them because at least one of the two shares each defect — and at 以斯帖記
/// 6:7 and 瑪拉基書 2:3, both of them do.
///
/// 士師記 12:7 read 「耶弗他作以色列的士師年」 — the number was gone, so the
/// verse states no length at all for a judgeship the Hebrew gives as six years.
/// 以賽亞書 23:1 read 「因為羅變為荒場」, half of Tyre's name. 士師記 9:57 read
/// 「歸到們身上了」, which is not a word. 撒母耳記下 5:17 read 「非利士人就上
/// 來」 where the Hebrew has כָל, all of them. 以斯帖記 6:7 ended on a dangling
/// 「王所喜悅尊榮的，」 where 6:6 and 6:9 both print 尊榮的人. 瑪拉基書 2:3
/// read 「糞抹你們的臉上」 without the 在. 以賽亞書 41:16 read 「以雅偉為喜
/// 樂，以色列的聖者為誇耀」, leaving 為誇耀 without the preposition its verb
/// needs — the Hebrew prefixes ב to both objects.
///
/// The witness that found them is our OWN Strong's-tagged corpus,
/// `assets/tagged/cuvs-yhwh/`, whose runs concatenate back to the verse. It is
/// a different transcription line from either external witness, and its tags
/// name the missing word — 六 is H8337, 眾人 H3605, 人 H376 — so the word-tap
/// sheet was printing 「士師六年」 over a verse that read 「士師年」.
///
/// Confirmed against the Hebrew in `assets/originals/`, against git blob
/// `7a2dc43`, and against the Wikisource transcription of the printed 1919
/// text, which reads 「作以色列的士師六年」 and 「非利士衆人就上來尋索大衞」.
/// The print is not optional here: 創世記 39:22 and 41:30 looked identical and
/// turned out to be the printed reading with the witnesses carrying a later
/// expansion.
///
/// `tools/repair_tagged_witness_losses.py` applies it;
/// `tools/audit_tagged_running_text.py` re-measures the whole corpus.
void main() {
  const simplified = 'assets/cuvs-yhwh.json';
  const traditional = 'assets/cuvs-yhwh-tr.json';

  /// id → (Simplified, Traditional). Every one fails on the pre-fix data.
  const restored = <String, List<String>>{
    '007009057': ['咒诅归到他们身上了', '咒詛歸到他們身上了'],
    '007012007': ['作以色列的士师六年', '作以色列的士師六年'],
    '010005017': ['非利士众人就上来寻索', '非利士眾人就上來尋索'],
    '023023001': ['因为推罗变为荒场', '因為推羅變為荒場'],
    '017006007': ['王所喜悦尊荣的人', '王所喜悅尊榮的人'],
    '039002003': ['粪抹在你们的脸上', '糞抹在你們的臉上'],
    '023041016': ['以以色列的圣者为夸耀', '以以色列的聖者為誇耀'],
  };

  Map<String, String> load(String path) => {
        for (final v in (json.decode(File(path).readAsStringSync()) as List)
            .cast<Map<String, dynamic>>())
          v['id'] as String: v['text'] as String,
      };

  late Map<String, String> zhHans;
  late Map<String, String> zhHant;

  setUpAll(() {
    zhHans = load(simplified);
    zhHant = load(traditional);
  });

  test('the seven restored words are back, in both editions', () {
    final missing = <String>[];
    restored.forEach((id, forms) {
      if (!zhHans[id]!.contains(forms[0])) missing.add('$id simplified ${forms[0]}');
      if (!zhHant[id]!.contains(forms[1])) missing.add('$id traditional ${forms[1]}');
    });
    expect(missing, isEmpty,
        reason: 'characters dropped out of scripture again:\n${missing.join('\n')}');
  });

  test('士師記 12:7 gives Jephthah a length of judgeship', () {
    // The defect was a missing NUMBER, which reads as a complete sentence and
    // is the kind a reader quotes without noticing.
    expect(zhHant['007012007'], contains('士師六年'));
    expect(zhHant['007012007'], isNot(contains('士師年')));
  });

  test('the running text agrees with the tagged corpus on these verses', () {
    // The tagged corpus is what found them, so it must not drift back either:
    // the sheet prints its runs INSTEAD of the verse.
    final judges = json.decode(
        File('assets/tagged/cuvs-yhwh/judges.json').readAsStringSync()) as Map;
    final runs = (judges['12:7'] as List).cast<Map<String, dynamic>>();
    expect(runs.map((r) => r['w']).join(), contains('士师六年'));
    expect(runs.firstWhere((r) => r['w'] == '六')['s'], 'H8337');
  });

  test('以賽亞書 41:16 keeps both 以, and its neighbours keep one', () {
    // Hebrew gives BOTH verbs a ב-prefixed object — תָּגִיל בַּיהוָה,
    // בִּקְדוֹשׁ יִשְׂרָאֵל תִּתְהַלָּל — so the doubled 以 is grammar, not a
    // duplicated character. 41:14 and 41:20 carry the same phrase without a
    // preposition, so a "fix" that collapses 以以 corpus-wide fails here.
    expect(zhHant['023041016'], contains('以雅偉為喜樂，以以色列的聖者為誇耀'));
    expect(zhHant['023041014'], isNot(contains('以以色列')));
    expect(zhHant['023041020'], isNot(contains('以以色列')));
  });

  test('the repair inserted characters and replaced nothing', () {
    expect(zhHant['023023001'],
        contains('論推羅的默示：他施的船隻都要哀號；因為推羅變為荒場'));
    expect(zhHant['010005017'],
        contains('非利士人聽見人膏大衛作以色列王，非利士眾人就上來尋索大衛'));
  });
}
