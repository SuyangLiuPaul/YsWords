import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Three verses opened a quotation in the MIDDLE of the scripture it quotes,
/// so the first half read as the narrator's own words:
///
///     如經上所記：我們為你的緣故終日被殺；「人看我們如將宰的羊。」
///
/// Both halves are 詩篇 44:22. As it stood, the verse said on screen that only
/// the second half is what is written — a false statement about scripture, not
/// a typographic preference, which is why it was P0.
///
/// The repair MOVES the existing mark to just after the introducing colon;
/// nothing is added or deleted. `tools/repair_citation_quote_scope.py`.
///
/// The class is bounded: the Traditional text holds `；「`/`；『` at 7 positions
/// in 5 verses. Three were these; the other two are correct and are pinned
/// below so no later pass sweeps them.
///
/// Evidence, four lines and deliberately not the same line three times — the
/// witness blob `7a2dc43` settles 馬太福音 16:14 outright; our own tagged
/// corpus settles 馬太福音 1:23, where it DISAGREES with our reading text and
/// already reads 说：“必有童女…; 羅馬書 8:36 rests on our own 詩篇 44:22
/// reading both halves as one sentence and on 18 of 20 `所記：` being followed
/// by 「; and 梁家鏗's independent NT corroborates the unit boundary at all
/// three.
void main() {
  const simplified = 'assets/cuvs-yhwh.json';
  const traditional = 'assets/cuvs-yhwh-tr.json';

  /// id → (Simplified, Traditional). Every one fails on the pre-fix data.
  const scoped = <String, List<String>>{
    '040001023': ['说：“必有童女怀孕生子；人要称', '說：「必有童女懷孕生子；人要稱'],
    '040016014': ['说：“有人说是施洗的约翰；', '說：「有人說是施洗的約翰；'],
    '045008036': ['如经上所记：“我们为你的缘故', '如經上所記：「我們為你的緣故'],
  };

  /// The two legitimate `；「`. 哥林多前書 1:12 puts the semicolon after a
  /// CLOSING mark, so each quote already opens where it should; 15:33 quotes a
  /// proverb with no introducing colon anywhere in the verse, so there is
  /// nowhere for the mark to move to.
  const keepAsIs = <String, List<String>>{
    '046001012': ['“我是属保罗的”；“我是属亚波罗的”', '「我是屬保羅的」；「我是屬亞波羅的」'],
    '046015033': ['你们不要自欺；“滥交是败坏善行。”', '你們不要自欺；「濫交是敗壞善行。」'],
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

  test('the quotation opens at the citation, not inside it', () {
    final wrong = <String>[];
    scoped.forEach((id, forms) {
      if (!zhHans[id]!.contains(forms[0])) wrong.add('$id simplified');
      if (!zhHant[id]!.contains(forms[1])) wrong.add('$id traditional');
    });
    expect(wrong, isEmpty,
        reason: 'a citation opens its quote mid-way again: ${wrong.join(', ')}');
  });

  test('the two legitimate ；「 are untouched', () {
    keepAsIs.forEach((id, forms) {
      expect(zhHans[id], contains(forms[0]),
          reason: '$id: this quote already opens where it should');
      expect(zhHant[id], contains(forms[1]), reason: '$id: same, Traditional');
    });
  });

  test('no character was added, removed or otherwise reordered', () {
    // The repair is a permutation of the verse with one mark relocated, so
    // stripping the quote marks must leave the two editions exactly as the
    // rest of the corpus has them. 詩篇 44:22 is the internal witness for
    // 羅馬書 8:36 and must keep reading as one sentence.
    expect(zhHant['045008036']!.replaceAll('「', '').replaceAll('」', ''),
        '如經上所記：我們為你的緣故終日被殺；人看我們如將宰的羊。');
    expect(zhHant['019044022'], '我們為你的緣故終日被殺；人看我們如將宰的羊。');
    expect(zhHant['040016014']!.replaceAll('「', '').replaceAll('」', ''),
        '他們說：有人說是施洗的約翰；有人說是以利亞；又有人說是耶利米或是先知裏的一位。');
  });

  test('所記： is followed by an opening quote wherever the verse quotes', () {
    // The convention this repair restores. 哥林多前書 1:31 is the one verse
    // that introduces a citation without quoting it at all; it is pinned so
    // nobody "completes" the convention by writing marks into it.
    final offenders = <String>[];
    zhHant.forEach((id, text) {
      for (final m in RegExp('所記：').allMatches(text)) {
        final next = text.substring(m.end, m.end + 1);
        if (next != '「' && id != '046001031') offenders.add('$id → $next');
      }
    });
    expect(offenders, isEmpty, reason: offenders.join(', '));
    expect(zhHant['046001031'], isNot(contains('「')));
  });

  test('the tagged corpus reads the same as the verse it renders', () {
    // The word-tap sheet renders its own copy, so the defect was on screen
    // twice at 馬太福音 16:14 and 羅馬書 8:36. 馬太福音 1:23 was already right
    // there — that disagreement is what settled the reading text.
    const expected = {
      'matthew|16:14':
          '他们说：“有人说是施洗的约翰；有人说是以利亚；又有人说是耶利米或是先知里的一位。”',
      'matthew|1:23':
          '说：“必有童女怀孕生子；人要称他的名为以马内利。”（以马内利翻出来就是“神与我们同在。”）',
      'romans|8:36': '如经上所记：“我们为你的缘故终日被杀；人看我们如将宰的羊。”',
    };
    expected.forEach((key, want) {
      final parts = key.split('|');
      final data = json.decode(
              File('assets/tagged/cuvs-yhwh/${parts[0]}.json').readAsStringSync())
          as Map<String, dynamic>;
      final text = (data[parts[1]] as List)
          .map((r) => (r as Map<String, dynamic>)['w'] as String)
          .join();
      expect(text, want, reason: '${parts[0]} ${parts[1]}');
    });
  });
}
