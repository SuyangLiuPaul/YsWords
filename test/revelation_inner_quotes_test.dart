import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Five of Revelation's seven letters opened their second-level quotation with
/// the FIRST-level mark: 啟示錄 2:1 read 「你要寫信給以弗所教會的使者，說：「那
/// 右手拿著七星…的，說： — a 「 opening while the 「 it sits inside, opened in
/// the same verse, was still open. This edition's second-level mark is 『』,
/// which it uses 660 times, including inside Revelation itself at 18:7.
///
/// **Five substitutions, and the scope of the claim behind them matters.**
/// Counted per VERSE these are the only five in all 31,102 verses; counted per
/// chapter the figure is 603, but those are the paragraph-reopener convention
/// (144 verses where ours opens 「 and the witness begins with an ordinary
/// character). Within one verse there is no paragraph break to explain it.
///
/// The 『 is deliberately left UNCLOSED. A draft of this repair also inserted
/// 』 at 2:7, 2:11, 2:17, 2:29 and 3:6 and the refuter broke it: 申命記 32:20,
/// 路加福音 15:17, 使徒行傳 7:6 and the 申命記 5 Decalogue block all leave a
/// 說：『 running with no closer. The substitution is independent of that
/// question — it neither creates nor removes an unclosed quotation, it only
/// puts the right mark on the level that was already nested.
/// `tools/repair_revelation_inner_quotes.py` applies it.
void main() {
  const simplified = 'assets/cuvs-yhwh.json';
  const traditional = 'assets/cuvs-yhwh-tr.json';

  /// id → (Simplified, Traditional). Every one fails on the pre-fix data.
  const openers = <String, List<String>>{
    '066002001': ['说：‘那右手拿着七星', '說：『那右手拿著七星'],
    '066002008': ['说：‘那首先的', '說：『那首先的'],
    '066002012': ['说：‘那有两刃利剑的', '說：『那有兩刃利劍的'],
    '066002018': ['说：‘那眼目如火焰', '說：『那眼目如火焰'],
    '066003001': ['说：‘那有神的七灵', '說：『那有神的七靈'],
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

  test('the five letters open their inner quotation with 『', () {
    openers.forEach((id, forms) {
      expect(zhHans[id], contains(forms[0]),
          reason: '$id simplified: inner quotation opened with the outer mark');
      expect(zhHant[id], contains(forms[1]), reason: '$id traditional: same');
    });
  });

  test('no verse in the corpus nests 「 directly inside 「', () {
    // The measurement the repair rests on, kept as a live invariant rather
    // than a sentence in a docstring. Per-verse scope, deliberately: a 「 that
    // reopens across verses is the paragraph convention, not this defect.
    // Notes are stripped first — a note may quote scripture and carry its own
    // marks.
    //
    // FAILING 2026-09-09 at 撒母耳記上 16:11 and 列王紀下 10:13, and
    // deliberately left failing. This is not the Revelation defect
    // recurring; it is a closing mark the publisher sync lost. Their
    // 撒上 16:11 ships 說：「你的兒子都在這裏嗎？他回答說：「還有個小的
    // — Samuel's question is never closed, so Jesse's answer opens
    // while Samuel is still speaking. 王下 10:13 is the same shape at
    // 你們是誰？回答說：. The official (blob 7a2dc43) closes both:
    // 「你的兒子都在這裡嗎？」他回答說：「… and 「你們是誰？」回答說：「….
    // One 」 per verse, in both scripts. Note that our own tagged
    // corpus has read it the official's way since 2026-08-24 — see
    // 'the word-tap sheet no longer answers its own questions' in
    // speaker_attribution_test.dart, which pins these two verses at
    // exactly this reading and still passes. So the reading text has
    // regressed BEHIND the word-tap sheet that renders over it, and
    // the same verse now says two different things in one app. That
    // is scripture, so it is the owner's edit; do not relax this.
    final note = RegExp('<note:[^>]*>');
    for (final entry in {simplified: zhHans, traditional: zhHant}.entries) {
      final open = entry.key == simplified ? '“' : '「';
      final close = entry.key == simplified ? '”' : '」';
      final offenders = <String>[];
      entry.value.forEach((id, raw) {
        final text = raw.replaceAll(note, '');
        var depth = 0;
        for (final ch in text.split('')) {
          if (ch == open) {
            if (depth > 0) {
              offenders.add(id);
              break;
            }
            depth++;
          } else if (ch == close && depth > 0) {
            depth--;
          }
        }
      });
      expect(offenders, isEmpty,
          reason: '${entry.key}: the first-level mark is being used for a '
              'nested quotation at ${offenders.join(', ')}');
    }
  });

  test('the tagged corpus reads the same as the verse it renders', () {
    // The word-tap sheet renders its own copy of the verse, so the defect was
    // on screen twice over. This corpus is a separate transcription line and
    // has been missed before by detectors that only read the reading text.
    final data = json.decode(
            File('assets/tagged/cuvs-yhwh/revelation.json').readAsStringSync())
        as Map<String, dynamic>;
    String textOf(String ref) => (data[ref] as List)
        .map((r) => (r as Map<String, dynamic>)['w'] as String)
        .join();

    for (final ref in ['2:1', '2:8', '2:12', '2:18', '3:1']) {
      expect(textOf(ref), contains('说：‘'),
          reason: 'revelation $ref: inner quotation opened with the outer mark');
      expect(textOf(ref), isNot(contains('说：“')),
          reason: 'revelation $ref: the outer mark is back');
    }
  });

  test('the readings this repair deliberately did not touch are pinned', () {
    // Each was in a draft and each was dropped after a corpus measurement said
    // our reading is this edition's own convention. Pinned so a later sweep
    // cannot do them silently while they wait on the user.

    // The five 『 are left unclosed: this edition leaves 說：『 running with no
    // closer at 申 32:20, 路 15:17, 徒 7:6 and through the 申 5 Decalogue.
    expect(zhHant['066002007'], endsWith('賜給他吃。」'));
    // FAILING 2026-09-09 at 2:29 and 3:6, and deliberately left
    // failing. The refrain that closes each of the seven letters —
    // 聖靈向眾教會所說的話，凡有耳的，就應當聽！ — lost its ！ in six of
    // the seven. 2:7, 2:11, 2:29, 3:6, 3:13 and 3:22 now read 就應當聽。
    // and 2:17 alone still reads 就應當聽！, so the publisher's own text
    // now punctuates one formula two ways within twenty-two verses.
    // The official (blob 7a2dc43) prints ！ at all seven, and so did
    // our text before the sync: 就應當聽！ was 16 in the corpus and is
    // now 10, with 6 of them turned into 就應當聽。. Six marks, one
    // repeated sentence, and the odd one out proves it was not a
    // decision. Owner's edit — the class is small enough for
    // tools/repair_by_official_cuv.py.
    expect(zhHant['066002029'], endsWith('就應當聽！」'));
    expect(zhHant['066003006'], endsWith('就應當聽！」'));

    // 3:7 and 3:14 leave the level-2 speech after 說： unmarked altogether.
    // That happens in 331 verses where the witness marks it, so these two are
    // ordinary members of a house-style class.
    expect(zhHant['066003007'], contains('說：那聖潔、真實'));
    expect(zhHant['066003014'], contains('說：那為阿們的'));

    // 2:13's leading 「 is a paragraph reopener — 144 verses where ours opens
    // and the witness begins with an ordinary character, five of them in
    // Revelation alone (2:13, 4:11, 18:14, 18:16, 22:14).
    expect(zhHant['066002013'], startsWith('「我知道你的居所'));
    expect(zhHant['066022014'], startsWith('「那些洗淨自己衣服的'));
  });
}
