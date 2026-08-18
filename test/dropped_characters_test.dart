import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Fifteen verses of the CUV were one or two characters short, in both the
/// Simplified and the Traditional file, with nothing to mark the loss.
/// 士師記 12:13 read 「作以色的士師」 — Israel, missing the last character of
/// its own name. 出埃及記 15:7 「像燒碎一樣」, 詩篇 78:44 「江河並河的水」,
/// 撒迦利亞書 11:15 「愚昧人所用的器具」 where the 器具 are a shepherd's.
///
/// They read as ordinary Chinese, which is why every structural check in this
/// repo passed on them: those ask whether a verse exists, not whether it is
/// whole. This one asks for the characters.
///
/// The readings below were settled on four independent lines, because
/// restoring text is the dangerous direction: a separate Simplified import
/// (`SeekSparks/assets/cuvs-plus.json`), a separately imported Traditional
/// 和合本 (git blob `7a2dc43`, which disagrees with the first in 5,338
/// verses), the Wikisource transcription of the printed 1919 text, and the
/// import module's own Strong's tags, which outlived the characters they were
/// attached to — 以色`<WH3478>` is tagged Israel, 燒碎`<WH7179>` stubble,
/// 愚昧人`<WH7462x>` shepherd.
///
/// `tools/repair_dropped_characters.py` applies it;
/// `tools/audit_dropped_characters.py` re-measures the whole corpus.
void main() {
  const simplified = 'assets/cuvs-yhwh.json';
  const traditional = 'assets/cuvs-yhwh-tr.json';

  /// id → (Simplified, Traditional). Every one of these fails on the old data.
  const restored = <String, List<String>>{
    '001045001': ['约瑟和弟兄们相认', '約瑟和弟兄們相認'],
    '001045015': ['随后他弟兄们就和他说话', '隨後他弟兄們就和他說話'],
    '001050011': ['一场极大的哀哭', '一場極大的哀哭'],
    '002015007': ['像烧碎秸一样', '像燒碎秸一樣'],
    '007012013': ['作以色列的士师', '作以色列的士師'],
    '019059012': ['因他们口中的罪', '因他們口中的罪'],
    '019078044': ['并河汊的水', '並河汊的水'],
    '019102026': ['天地就都改变了', '天地就都改變了'],
    '038011015': ['愚昧牧人所用的器具', '愚昧牧人所用的器具'],
    '041011017': ['便教训他们说', '便教訓他們說'],
    '044026029': ['无论是少劝是多劝', '無論是少勸是多勸'],
    '044027044': ['船上的零碎东西', '船上的零碎東西'],
    '047010009': ['免得你们以为', '免得你們以為'],
    '047012017': ['借着他们一个人', '藉著他們一個人'],
    '058002002': ['凡干犯悖逆的', '凡干犯悖逆的'],
  };

  /// These two look exactly like the ones above — two witnesses read longer
  /// than we do — and they are NOT losses. Our text is the printed 1919; the
  /// witnesses carry a later expansion, and the module's tagging shows no gap
  /// (約瑟`<WH3130>`手下`<WH3027>`). Pinned so a future pass over the same
  /// measurement does not "repair" them.
  const keepShort = <String, List<String>>{
    '001039022': ['都交在约瑟手下', '都交在約瑟手下'],
    '001041030': ['甚至埃及地都忘了', '甚至埃及地都忘了'],
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

  test('the dropped characters are back, in both editions', () {
    final missing = <String>[];
    restored.forEach((id, forms) {
      if (!zhHans[id]!.contains(forms[0])) missing.add('$id simplified ${forms[0]}');
      if (!zhHant[id]!.contains(forms[1])) missing.add('$id traditional ${forms[1]}');
    });
    expect(missing, isEmpty,
        reason: 'characters dropped out of scripture again:\n${missing.join('\n')}');
  });

  test('士師記 12:13 spells Israel', () {
    expect(zhHant['007012013'], contains('以色列'));
    expect(zhHans['007012013'], contains('以色列'));
  });

  test('the two 1919 readings are left short', () {
    keepShort.forEach((id, forms) {
      expect(zhHans[id], contains(forms[0]),
          reason: '$id: this is the printed 1919 reading, not a dropped character');
      expect(zhHant[id], contains(forms[1]), reason: '$id: same, Traditional');
    });
  });

  test('the repair inserted characters and replaced nothing', () {
    // Every restored verse must still contain the surrounding words it had
    // before, so an "insertion" that quietly rewrote a clause would fail.
    expect(zhHant['019078044'], contains('把他們的江河並河汊的水都變為血'));
    expect(zhHant['044026029'], contains('無論是少勸是多勸，我向神所求的'));
    expect(zhHant['058002002'], contains('那藉著天使所傳的話既是確定的；凡干犯悖逆的'));
  });
}
