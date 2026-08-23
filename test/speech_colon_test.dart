import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Five verses opened a quotation with a **semicolon**: 耶穌說；「你們以為…」,
/// 他們對差役說；「你們為什麽沒有帶他來呢？」, 我就在怒中起誓說；『他們斷不可
/// 進入我的安息』。 A semicolon joins two independent clauses; it cannot
/// introduce direct speech, and this edition introduces it with the full-width
/// colon 3,236 other times.
///
/// The defect stood in the Simplified file, the Traditional file **and** the
/// tagged Strong's corpus that renders the word-tap sheet, so a reader saw it
/// twice over the same verse.
///
/// **Ten of the fifteen 「說；」 in the corpus are CORRECT and are pinned below
/// so no later pass turns this into a blanket substitution.** 約伯記 28:27
/// 「而且述說；他堅定」 and 加拉太書 2:2 「對弟兄們陳說；卻是背地裏…」 are a
/// clause ending in 說 followed by a legitimate semicolon.
///
/// Settled on three lines that are not the same line twice — the separately
/// imported 和合本 Traditional (git blob `7a2dc43`), which reads `：` at
/// exactly these five and `；` at the other ten; our own tagged corpus, which
/// shares the `；` but carries an opening quotation mark straight after it at
/// all five, including 列王紀上 22:13 where the running text has no quotation
/// marks at all; and the frequency above. The printed 1919 cannot arbitrate —
/// it has no `：` and no quotation marks anywhere — and was not used as if it
/// could. `tools/repair_speech_colon.py` applies it.
void main() {
  const simplified = 'assets/cuvs-yhwh.json';
  const traditional = 'assets/cuvs-yhwh-tr.json';

  /// id → (Simplified, Traditional). Every one fails on the pre-fix data.
  const opened = <String, List<String>>{
    '011022013': ['对米该雅说：众先知', '對米該雅說：眾先知'],
    '042013002': ['耶稣说：“你们以为', '耶穌說：「你們以為'],
    '043007045': ['对差役说：“你们为什么', '對差役說：「你們為什麽'],
    '043009009': ['又有人说：“不是', '又有人說：「不是'],
    '058003011': ['起誓说：‘他们断不可', '起誓說：『他們斷不可'],
  };

  /// The ten legitimate 「說；」. Each is a clause ending in the verb 說,
  /// not a speech introduction, and none carries an opening quotation mark
  /// in the tagged corpus either. Two sit inside a translator's note.
  const keepSemicolon = <String, List<String>>{
    '001032019': ['也要这样对他说；', '也要這樣對他說；'],
    '003025025': ['是指本国人说；下同', '是指本國人說；下同'],
    '007008008': ['也是这样说；', '也是這樣說；'],
    '011002019': ['要为亚多尼雅提说；', '要為亞多尼雅提說；'],
    '018028027': ['而且述说；', '而且述說；'],
    '018029022': ['他们就不再说；', '他們就不再說；'],
    '018033033': ['你就听我说；', '你就聽我說；'],
    '018037019': ['我们愚昧不能陈说；', '我們愚昧不能陳說；'],
    '037002009': ['原文有“万军之雅伟说；”', '原文有「萬軍之雅偉說；」'],
    '048002002': ['对弟兄们陈说；', '對弟兄們陳說；'],
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

  test('the five quotations open with a colon, in both editions', () {
    final wrong = <String>[];
    opened.forEach((id, forms) {
      if (!zhHans[id]!.contains(forms[0])) wrong.add('$id simplified');
      if (!zhHant[id]!.contains(forms[1])) wrong.add('$id traditional');
    });
    expect(wrong, isEmpty,
        reason: 'a quotation opens with a semicolon again: ${wrong.join(', ')}');
  });

  test('the ten legitimate 說； are untouched', () {
    keepSemicolon.forEach((id, forms) {
      expect(zhHans[id], contains(forms[0]),
          reason: '$id: this semicolon ends a clause, it does not open speech');
      expect(zhHant[id], contains(forms[1]), reason: '$id: same, Traditional');
    });
  });

  test('no 說 anywhere introduces a quotation with a semicolon', () {
    // The count that matters. `；「` and `；『` survive elsewhere — 哥林多前書
    // 1:12 lists four quoted claims separated by semicolons — so this asks
    // only about the mark that follows the verb 說.
    for (final entry in {simplified: zhHans, traditional: zhHant}.entries) {
      final offenders = <String>[];
      entry.value.forEach((id, text) {
        if (RegExp('[說说]；[「『“‘]').hasMatch(text)) offenders.add(id);
      });
      expect(offenders, isEmpty,
          reason: '${entry.key}: ${offenders.join(', ')}');
    }
  });

  test('the tagged corpus reads the same as the verse it renders', () {
    // The word-tap sheet renders its own copy, so the defect was on screen
    // twice. 列王紀上 22:13 is the one that matters most here: the tagged
    // corpus carries the quotation marks the running text lacks, which is
    // how we know the mark introduces speech at all.
    const refs = {
      '1_kings': '22:13',
      'luke': '13:2',
      'john': '7:45',
      'hebrews': '3:11',
    };
    refs.forEach((book, ref) {
      final data = json.decode(
              File('assets/tagged/cuvs-yhwh/$book.json').readAsStringSync())
          as Map<String, dynamic>;
      final text = (data[ref] as List)
          .map((r) => (r as Map<String, dynamic>)['w'] as String)
          .join();
      expect(text, isNot(contains('说；')),
          reason: '$book $ref still opens speech with a semicolon');
      expect(text, contains('说：'), reason: '$book $ref lost its colon');
    });
  });

  test('約翰福音 9:9 keeps the other semicolon it has', () {
    // Only the SECOND 說 was repaired. Ours reads 「是他；」 where the witness
    // reads 「是他」； — that MOVES a mark rather than substituting one, so it
    // is filed for the user, not swept in here.
    expect(zhHant['043009009'], contains('有人說：「是他；」又有人說：「不是'));
    expect(zhHans['043009009'], contains('有人说：“是他；”又有人说：“不是'));
  });
}
