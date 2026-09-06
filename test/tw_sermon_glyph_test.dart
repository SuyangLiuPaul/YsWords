import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Traditional sermon transcripts' spot glyph errors, pinned after
/// `tools/repair_tw_sermon_dry_glyph.py` (18 substitutions) and
/// `tools/repair_tw_sermon_spot_glyphs.py` (109), both applied 2026-09-03.
///
/// **This corpus does NOT have the CUV converter hole** and the tests below are
/// written so that nobody can conclude otherwise from them. `assets/sermons/
/// zh-TW/` was produced by a phrase-aware converter: it holds 淨 526, 牆 384,
/// 餘 323, 髮 191, 鬆 178 (re-measured 2026-09-07 against the 429-file
/// corpus; these five are illustrative and not pinned by an `expect` below)
/// and zero 凈 / 墻 / 余. None of the
/// `tools/repair_tr_*.py` scripts applies here. What it had was spot errors in
/// four classes, and the counts on both sides are pinned so that a re-import
/// cannot silently undo them and a later sweep cannot silently widen them.
///
/// **One line of that paragraph was WRONG and has been removed: 隻.** It used
/// to read "it holds 隻 453 …" as evidence that the converter is good, and
/// the opposite is true — s2t writes the measure word 隻 where the sense is
/// 只 (only), so the corpus reads 「這隻能治標不治本」, 「就是隻要擯棄」 and
/// 「是不是隻有主耶穌在世的那個世代」. Measured 2026-09-06: roughly 81 such
/// positions were already in the shipped 289 and roughly 63 came in with the
/// merge, against 250-odd correct 隻 (一隻羊, 兩隻手, 隻字未提, 形單影隻,
/// 船隻). Separating them is a per-occurrence adjudication over ~144
/// positions and is NOT done here; it is named so that the next reader finds
/// it instead of finding a sentence saying it is fine.
///
/// **2026-09-06 — the corpus is 429 sermons, not 289.** 125 of Pastor Eric's
/// messages were merged in from the fuyindiantai staging library and 51
/// machine-translated Chinese bodies were replaced by that library's human
/// text, both converted by the same `opencc -c s2t`
/// (`scripts/merge_sermon_library.py`), taking the corpus to 414 that day;
/// 15 more, transcribed from audio-only sermons later the same day, took it
/// to 429. Every count below moved, and every
/// one was decomposed into new-file / lost-with-the-replaced /
/// gained-with-the-replacement before it was rewritten. The repairs the
/// merge needed are in `tools/repair_tw_sermon_merged_glyphs.py`, 87
/// substitutions across 48 files.
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
      // 124 → 216 with the merge. Decomposed first: +59 in the 125 new
      // files, −11 lost with the machine text of the 51 replaced bodies,
      // +44 in their replacements. Every one of the 92 was read in context
      // and they are 才幹 71, 樹幹 23, 幹什麼 21, 幹活 15, 能幹 10, 幹掉 8,
      // 幹部 8, 幹革命 3, 幹嘛 3, 軀幹 3, 骨幹 2, 幹得好 2, 幹道/幹線 2 and
      // the like. The seventeen that were NOT are repaired one anchored
      // reading at a time: five drynesses (淚始乾 ×2, 乾河牀, 溼了又乾,
      // 裝乾穀物), four doings that s2t wrote 乾 (奴隸幹的活 ×2, 仇敵幹的,
      // 幹沒幹壞事), two offences it wrote 幹 (親自干預, 干犯主的身), and
      // 乾脆 spelt three different ways across five files.
      // 216 → 220 on 2026-09-06 with the 15 transcribed sermons. All four
      // were read: 幹嘛 ×3 (fy-cm03 「你幹嘛還要相信他呢」 ×2, fy-rms07-03
      // 「幹嘛還有一條不守呢」) and fy-rms07-03's 「什麼活都不能幹」 — a
      // doing in every case, which is what 幹 is for.
      expect(count('幹'), 220);
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
      // 10 → 19. Twelve new 「鬥底下」 arrived with the merge — 018, 080 ×2,
      // fy-sm12a ×2, fy-sm12b ×6, fy-sm28, every one of them quoting
      // 馬太福音 5:15 or its parallels — and three left with the machine
      // bodies of 018, 080 and 075's twins. Read before the number moved.
      expect(count('斗底下'), 19);
      // Nine quote 馬太福音 5:15; the tenth is 075.txt quoting 路加福音 8:16
      // as 「放在牀底下或鬥底下」, which the first draft of the repair missed
      // because its cue came from the Matthew wording alone.
      expect(count('三鬥面'), 0);
      expect(count('三斗麪'), 2, reason: '馬太福音 13:33');
    });

    test('every other 鬥 is a fight and stays', () {
      // 231 鬥 before, 219 after. An inventory count could never have found
      // the twelve; only the collocation could.
      //
      // 220 from 2026-09-05: sermons 100, 369 and 370 had shipped a
      // separate, TRUNCATED Traditional translation and were rebuilt from
      // their Simplified bodies with `opencc -c s2t`, adding ~38 000
      // characters this number had never seen. The four new 鬥 were read
      // first — 369 has three 戰鬥 and 370 one — so the collocation rule
      // still holds and only the total moved.
      // 220 → 257 with the merge, and the increase was not merely counted.
      // EVERY 鬥 in all 414 files was classified: 256 sit in 戰鬥 105,
      // 爭鬥 46, 搏鬥 32, 奮鬥 25, 好鬥 5, 打鬥 2, 格鬥, 決鬥, 鬥爭, 鬥拳,
      // 角鬥士, 鉤心鬥角, 單打獨鬥, 內鬥, 鬥智鬥勇, 纏鬥, 鬥下去 — and the
      // 257th is fy-sm43's 「以狼鬥狼」, a wolf fighting a wolf. That sweep
      // is what found the seven below.
      // 257 → 260 on 2026-09-06 with the 15 transcribed sermons. All three
      // are fights and all three are in fy-rms07-04: 爭鬥 ×2 (「還是充滿
      // 爭鬥呢」, 「完全沒有任何的爭鬥」) and 鬥爭 (「除非我們放棄鬥爭」).
      // Not one is a measuring bowl.
      expect(count('鬥'), 260);
      for (final keep in const ['戰鬥', '爭鬥', '搏鬥', '打鬥', '奮鬥', '好鬥']) {
        expect(count(keep), greaterThan(0), reason: keep);
      }
      expect(files['fy-sm43.txt'], contains('以狼鬥狼'),
          reason: 'the one 鬥 outside a named fight collocation');
      expect(files['360.txt'], contains('斗篷'), reason: 'a cloak was already 斗');
      expect(files['371.txt'], contains('升斗'), reason: '路 6:38 was already 斗');
    });

    test('075 names the bowl outside the quotation, and now spells it 斗', () {
      // 075 was HALF-repaired on 2026-09-03: the sweep fixed its
      // 「或鬥底下」 because that is the collocation the rule carried, and
      // left the six places where the same message names the bowl on its
      // own. So for three days it read 「鬥——裏面裝著穀物。它是量穀物的
      // 量器」 — a FIGHT with grain inside it — while the test above
      // asserted that every 鬥 outside 鬥底下 was a fight. Its own
      // Simplified body is the control and writes 斗 at all six.
      final f = files['075.txt']!;
      for (final reading in const [
        '馬可提到了斗：', '不要用斗把它蓋上', '被斗蓋上',
        '斗——裏面裝著穀物', '讓你用斗蓋上', '斗裝的是乾貨',
      ]) {
        expect(f, contains(reading), reason: reading);
      }
      expect(f.contains('鬥'), isFalse,
          reason: '075 is a message about the measure and holds no fight');
      // fy-sm12b is the same message in the merged corpus and names the
      // bowl seven times outside the quotation.
      final g = files['fy-sm12b.txt']!;
      for (final reading in const [
        '第一樣是“斗”，斗是裝穀子的器具', '斗是什麼呢', '1、斗（太5：15',
        '就是斗、器皿', '斗用來裝乾穀物', '跟“斗”字不同',
      ]) {
        expect(g, contains(reading), reason: reading);
      }
      expect(g, contains('格鬥廝殺'),
          reason: 'and the one real fight in that file survives');
    });
  });

  group('麪 — flour, in this corpus never spelt 麵', () {
    test('the house form is 麪 and there is no 麵 anywhere', () {
      // Both are standard Traditional and this repo uses BOTH — cuvs-yhwh-tr
      // and biblexg-v2-tr set 麵, this corpus and assets/strongs set 麪. An
      // audit that counts only 麵 calls all 429 files a flour hole.
      // 158, not 164. The refuter pass of 2026-09-05 found this number was
      // pinning SIX WRONG CHARACTERS in place: 093 「物質層麪包裹」 (an
      // aspect that WRAPS — created here, by a 面包 rule whose lookbehind
      // lacked 層), plus 109 「愛裏麪包含」, 318 「明白麪前」, 194-1
      // 「眼睛和麪容」 ×2 and 194-2 「摩西的麪皮發光」 — that last a
      // quotation of Exodus 34:35. Four were inherited from T7 rather
      // than made here, but this test asserted they were fine.
      //
      // Each was settled by its own Simplified body, which is the
      // control: 093 zh-CN reads 层面包裹, 194-2 reads 摩西的面皮.
      // 158 → 162. Six 麪 came in with the 125 merged files and seven with
      // the 51 replacements, against nine that left with the machine text
      // they replaced. All thirteen were read: 麪包 in 118 ×2, 407,
      // fy-sm16, fy-sm51, 麪粉 in fy-mt67_pb03 and 長壽麪 in fy-mt59 —
      // noodles, flour and bread. Two more that s2t got backwards, 麪對
      // in fy-bp03 and fy-bp07, are repaired to 面對 rather than counted:
      // the Simplified bodies read 面对 and are the control.
      expect(count('麪'), 162);
      for (final wrong in const [
        '層麪包裹', '裏麪包含', '明白麪前', '和麪容', '麪皮發光',
        '麪對真理',
      ]) {
        expect(count(wrong), 0, reason: '$wrong is 面, not flour');
      }
      expect(count('麵'), 0,
          reason: 'a sweep imported the other asset family\'s spelling');
    });

    test('no flour word is left spelt 面', () {
      for (final gone in const ['面酵', '麥面', '團面']) {
        expect(count(gone), 0, reason: gone);
      }
      expect(count('麪酵'), 63);
      expect(count('麥麪'), 4);   // 3 repaired + 1 that was already right
      // 47 from 2026-09-05: two of the 49 were not bread at all —
      // 093's 層麪包裹 and 109's 愛裏麪包含, both 面 + 包-heading-its-
      // own-word. Corrected, and the rule now carries a lookahead.
      // 47 → 49: 011's 「一片面包」 and 「你是有面包了」, a slice of BREAD,
      // arrived with its replacement body. The rule that caught them is
      // `repair_tw_sermon_spot_glyphs.py`'s regex reused character for
      // character — it has to be, because fy-im21 「裏面包含許多內容」 came
      // in on the same merge and is the exact trap the lookbehind and the
      // lookahead exist for.
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
      // 5926 from the three rebuilt sermons, then 5932 later the same day
      // when six over-converted 麪 were restored to 面 (093, 109, 318,
      // 194-1 ×2, 194-2). Checked before either number was changed: none
      // of the three rebuilt bodies contains 面包, 面粉, 面糰 or 面酵, so
      // nothing that should be flour is hiding in the increase, and all
      // six restorations were settled against their Simplified bodies.
      // 5932 → 7480 with the merge. What was checked before the number
      // moved is what has always been checked here: that nothing which
      // should be flour is hiding in the increase. 面酵 0, 面包 1, 麥面 0,
      // 團面 0, 面粉 0, 面糰 0 across all 414 files — the single 面包 is
      // fy-im21's 「裏面包含許多內容」, which is an INSIDE that CONTAINS.
      // 7480 → 7594 on 2026-09-06 with the 15 transcribed sermons. All 114
      // new ones were censused by bigram rather than sampled, and every one
      // is a face, a side, an aspect or the name 西面 (Simeon, Luke 2):
      // 裏面 ×19, 面前 ×16, 面對 ×15, 方面 ×9, 表面 ×8, 西面 ×12, 外面 ×5,
      // 層面 ×4, 字面 ×4, 前面 ×3, 全面 ×3 and the like. The flour check
      // that carries this claim is unchanged: 面酵 0, 麥面 0, 團面 0,
      // 面粉 0, 面糰 0 across all 429 files.
      expect(count('面'), 7594);
      for (final keep in const ['裏面', '面前', '方面', '面對', '前面', '畫面']) {
        expect(count(keep), greaterThan(0), reason: keep);
      }
      // 073's 「它裏面包含了極大的真理」 was this anchor until 2026-09-06,
      // when 073 became one of the 51 bodies replaced by the library's
      // human text, which does not contain that sentence. fy-im21 carries
      // the same trap and came in on the same merge.
      expect(files['fy-im21.txt'], contains('裏面包含許多內容'),
          reason: '裏面 + 包含 — the 面包 rule needs its negative lookbehind');
    });
  });

  group('採 — to pick or adopt', () {
    test('采取 and 采納 are gone', () {
      expect(count('采取'), 0);
      expect(count('采納'), 0);
      expect(count('採取'), 88);
      expect(count('採納'), 7);
    });

    test('采 survives in 興高采烈, 無精打采 and Nietzsche — all 21 of them', () {
      // 尼采 is the trap: a philosopher's name that a blanket 采→採 would
      // have renamed, and the merge brought eight more of him — one in
      // fy-im03's biography of him (「尼采（Nietzsche）」, 「尼采的父親是位
      // 牧師」) and the rest in 398's exposition of the Übermensch. All
      // thirteen were read.
      // 13 → 19 on 2026-09-06: fy-ws04 (ws04, 無往不克的生命) spends a
      // long stretch on Nietzsche's Übermensch and names him six times.
      // The trap is unchanged — a blanket 采→採 would rename the
      // philosopher — and the audit of the new bodies found the one real
      // 採 this corpus was missing, fy-ws04's 「原文采用的文法」, now swept
      // by `repair_tw_sermon_merged_glyphs.py`.
      expect(count('尼采'), 19);
      // 風采 is GONE, and that is not a regression: its one occurrence was
      // 018's 「特別的風采」, in the machine-translated body that the merge
      // replaced with the library's human text. Removing the assertion is
      // the honest move; replacing it with 無精打采 keeps the class covered
      // by a reading that actually exists.
      expect(count('風采'), 0);
      expect(count('興高采烈'), 7);
      expect(count('無精打采'), 1);
      // With 763's 「舉手可採」 repaired, every 采 in the corpus is one of
      // exactly three words, so this side can be enumerated rather than
      // merely asserted non-empty — which is what makes a widened 采→採
      // impossible to hide.
      expect(count('采'), 27, reason: '19 + 7 + 1, and nothing else');
      expect(count('尼採'), 0, reason: 'a blanket 采→採 ran');
      expect(files['763.txt'], contains('舉手可採'),
          reason: 'fruit within reach, to be PICKED');
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
