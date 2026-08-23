import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Nine verses put one speaker's words inside ANOTHER speaker's quotation
/// marks, so the app attributed them to the wrong person and read perfectly
/// well while doing it.
///
/// 馬太福音 15:34 read 耶穌說：「你們有多少餅？他們說：有七個…」 — the
/// disciples' answer sat inside Jesus's quotation. 約翰福音 2:7 read
/// 耶穌對用人說：「把缸倒滿了水。他們就倒滿了，直到缸口。」 — that second
/// clause is the narrator, and Jesus cannot be its speaker.
/// 哥林多前書 15:45 ran the citation past its end, so 經上記著說 introduced
/// 末後的亞當成了叫人活的靈 — which is Paul, not the Old Testament.
///
/// **Only quotation marks moved.** No Chinese character was added, deleted or
/// reordered, in any of the nine, in any of the three files that carry them:
/// both reading editions and the tagged Strong's corpus behind the word-tap
/// sheet, which renders its own copy of the verse.
///
/// Settled on lines that are not the same line twice: the separately imported
/// 和合本 Traditional (git blob `7a2dc43`); 梁家鏗's independently produced
/// Traditional NT (`assets/biblexg-v2-tr.json`), which quotes both speakers
/// separately at every NT verse here; LEB (`assets/leb.json`), an independent
/// English translation with modern quotation marks; and — for 創世紀 30:6 —
/// this edition's own ten parallel naming formulas in the same passage, every
/// one of which sets the naming OUTSIDE the quotation.
///
/// **Where the evidence is not symmetric, and it should be said.** The witness
/// 7a2dc43 matches the new reading at all nine — but it also disagrees with us
/// at two of the three verses left alone (創 26:7 and 啟 19:10), where LEB and
/// 梁家鏗 side with us instead. So the nearest-relative witness was decisive
/// for nine and overruled for two. That is defensible only because those two
/// are clauses with no speech verb, which either speaker could plausibly own,
/// while the nine put a NAMED second speaker inside the first one's marks.
///
/// `tools/audit_speaker_attribution.py` carries both detectors and the triage
/// of every position deliberately left alone; `tools/repair_speaker_attribution.py`
/// applies the fix and is idempotent.
void main() {
  const simplified = 'assets/cuvs-yhwh.json';
  const traditional = 'assets/cuvs-yhwh-tr.json';

  /// id → [Simplified, Traditional] fragment. Every one fails on pre-fix data.
  const repaired = <String, List<String>>{
    '001030006': ['赐我一个儿子”，因此给他起名叫但', '賜我一個兒子」，因此給他起名叫但'],
    '040015034': ['多少饼？”他们说：“有七个', '多少餅？」他們說：「有七個'],
    '040017026': ['是向外人。”耶稣说：“既然如此', '是向外人。」耶穌說：「既然如此'],
    '041006037': ['他们吃吧。”门徒说：“我们可以', '他們吃吧。」門徒說：「我們可以'],
    '043002007': ['倒满了水。”他们就倒满了', '倒滿了水。」他們就倒滿了'],
    '043002008': ['管筵席的。”他们就送了去。', '管筵席的。」他們就送了去。'],
    '043013029': ['应用的东西”，或是叫他', '應用的東西」，或是叫他'],
    '043013036': ['那里去？”耶稣回答说：“我所去', '那裏去？」耶穌回答說：「我所去'],
    '046015045': ['的活人”；末后的亚当', '的活人」；末後的亞當'],
  };

  /// Three verses the same two detectors flagged and that were deliberately
  /// NOT changed. Pinned so a later sweep cannot quietly take them: in each,
  /// an independent line sides with our reading, so they are editorial splits
  /// rather than defects.
  const leftAlone = <String, List<String>>{
    // The witness has no speech quotation here at all — its 「」 mark the
    // words 「女人」/「男人」 themselves.
    '001002023': ['因为她是从男人身上取出来的。”', '因為她是從男人身上取出來的。」'],
    // 因為她容貌俊美 — LEB puts it inside Isaac's thought, as we do.
    '001026007': ['缘故杀我，因为她容貌俊美。”', '緣故殺我，因為她容貌俊美。」'],
    // 因為預言中的靈意… — LEB and 梁家鏗 both keep it inside the angel's
    // speech, as we do; only the witness puts it outside.
    '066019010': ['你要敬拜神。因为预言中的灵意', '你要敬拜神。因為預言中的靈意'],
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

  test('the nine quotations close before the next speaker, in both editions',
      () {
    final wrong = <String>[];
    repaired.forEach((id, forms) {
      if (!zhHans[id]!.contains(forms[0])) wrong.add('$id simplified');
      if (!zhHant[id]!.contains(forms[1])) wrong.add('$id traditional');
    });
    expect(wrong, isEmpty,
        reason: 'a second speaker is inside the first one\'s quotation '
            'again: ${wrong.join(', ')}');
  });

  test('the three editorial splits are left exactly as they were', () {
    leftAlone.forEach((id, forms) {
      expect(zhHans[id], contains(forms[0]),
          reason: '$id: an independent witness reads it our way — this is a '
              'choice, not a defect, and must not be swept with the nine');
      expect(zhHant[id], contains(forms[1]), reason: '$id: same, Traditional');
    });
  });

  test('not one Chinese character moved — only quotation marks', () {
    // The dangerous direction. If a later edit to these verses changes a
    // word, this catches it even though the quotation marks still look right.
    const expectedHant = <String, String>{
      '001030006': '拉結說：神伸了我的冤，也聽了我的聲音，賜我一個兒子，因此給他'
          '起名叫但。',
      '040015034': '耶穌說：你們有多少餅？他們說：有七個，還有幾條小魚。',
      '041006037': '耶穌回答說：你們給他們吃吧。門徒說：我們可以去買二十兩銀子的'
          '餅，給他們吃嗎？',
      '043002007': '耶穌對用人說：把缸倒滿了水。他們就倒滿了，直到缸口。',
      '043002008': '耶穌又說：現在可以舀出來，送給管筵席的。他們就送了去。',
      '043013036': '西門彼得問耶穌說：主往那裏去？耶穌回答說：我所去的地方，你'
          '現在不能跟我去，後來卻要跟我去。',
    };
    final notes = RegExp(r'<note:[^>]*>');
    expectedHant.forEach((id, want) {
      final got = zhHant[id]!
          .replaceAll(notes, '')
          .replaceAll(RegExp('[「」『』]'), '');
      expect(got, want, reason: '$id: the wording changed, not just the marks');
    });
  });

  test('every repaired verse still balances its quotation marks', () {
    // 馬太福音 17:26 deliberately does not: its quotation opens in v.26 and
    // closes in v.27, which is why a balanced-span check never found it.
    for (final id in repaired.keys) {
      if (id == '040017026') continue;
      final text = zhHant[id]!.replaceAll(RegExp(r'<note:[^>]*>'), '');
      expect('「'.allMatches(text).length, '」'.allMatches(text).length,
          reason: '$id: unbalanced 「」 after the repair');
    }
    // 17:26 opens one that 17:27 closes.
    final v26 = zhHant['040017026']!.replaceAll(RegExp(r'<note:[^>]*>'), '');
    final v27 = zhHant['040017027']!.replaceAll(RegExp(r'<note:[^>]*>'), '');
    expect('「'.allMatches(v26).length - '」'.allMatches(v26).length, 1,
        reason: '馬太福音 17:26 should leave exactly one quotation open');
    expect('」'.allMatches(v27).length - '「'.allMatches(v27).length, 1,
        reason: '馬太福音 17:27 should close it');
  });

  test('the tagged corpus reads the same as the verse it renders', () {
    // The word-tap sheet renders its own copy, so the misattribution was on
    // screen twice over the same verse.
    const refs = <String, Map<String, String>>{
      'genesis': {'30:6': '一个儿子”，因此'},
      'matthew': {'15:34': '多少饼？”他们说：“有七个', '17:26': '外人。”耶稣说：“既然'},
      'mark': {'6:37': '吃吧。”门徒说：“我们可以'},
      'john': {
        '2:7': '水。”他们就',
        '2:8': '管筵席的。”他们',
        '13:29': '的东西”，或',
        '13:36': '去？”耶稣回答说：“我所去',
      },
      '1_corinthians': {'15:45': '人”；末后'},
    };
    refs.forEach((book, verses) {
      final data = json.decode(
              File('assets/tagged/cuvs-yhwh/$book.json').readAsStringSync())
          as Map<String, dynamic>;
      verses.forEach((ref, want) {
        final text = (data[ref] as List)
            .map((r) => (r as Map<String, dynamic>)['w'] as String)
            .join();
        expect(text, contains(want),
            reason: '$book $ref still attributes the words to the wrong '
                'speaker on the word-tap sheet');
      });
    });
  });

  test('哥林多前書 15:45 no longer puts Paul inside the citation', () {
    // The one where the wrong speaker is SCRIPTURE. 經上記著說 introduces a
    // quotation of Genesis 2:7, which ends at 活人; 末後的亞當 is Paul's own
    // sentence. LEB and 梁家鏗 both close the citation at the same place.
    // The note must be stripped first: it reads <note: 「靈」：或作「血氣」>
    // and its own 「」 sit before 末後的亞當, so an unstripped indexOf('」')
    // passes on the pre-fix data too.
    final text =
        zhHant['046015045']!.replaceAll(RegExp(r'<note:[^>]*>'), '');
    expect(text.indexOf('」'), lessThan(text.indexOf('末後的亞當')),
        reason: 'the citation must close before 末後的亞當');
  });
}
