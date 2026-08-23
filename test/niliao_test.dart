import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Two readings that look like defects, are not, and must be left alone.
///
/// BOTH were "repaired" by an autonomous iteration on 2026-08-23 and both
/// repairs were wrong. This file exists so the next one cannot repeat them.
///
/// 以賽亞書 64:3 and 使徒行傳 25:18 read 意料 where the printed 1919 和合本,
/// both external witnesses, our own tagged corpus and the publisher's own
/// site all read 逆料. That is four independent lines against our reading
/// text, which is normally decisive — and it is still the wrong conclusion,
/// because the reading text is not a witness at these two verses. It is an
/// EDIT. Commit `81db105` (Paul Liu, 2025-08-10, "Updated verses in 和合本
/// and fixed text selection") changed 逆料 → 意料 in exactly these two verses
/// in both editions, in the same pass that normalised 汙 → 污 across 210
/// verses of the Traditional file. A targeted two-verse substitution in a
/// hand-made editorial commit is a decision by the repo's owner, not
/// corruption to be undone — whatever the other four lines read.
///
/// The lesson, and the reason this comment is long: five lines of external
/// evidence cannot tell you whether a difference is a corruption or an
/// intentional change. Only the history can, and `git log -S` over the asset
/// is the cheap way to ask. Run it before touching scripture.
///
/// What IS genuinely open is that the edit never reached the tagged corpus:
/// `assets/tagged/cuvs-yhwh/` still reads 逆料, so the word-tap sheet prints
/// one word over a verse that reads another. That inconsistency is real and
/// is queued for the user, who is the only person entitled to say which side
/// should move.
///
/// 帖撒羅尼迦前書 5:19 is a different case and the one unopposed guard here.
/// 銷滅 occurs in exactly one verse of 31,102 against 43 reading 消滅, so a
/// frequency argument — which this repo has used elsewhere — marks it as
/// contamination. It is not: the print reads 銷滅, our tagged corpus reads
/// 銷滅, and it is both external witnesses that modernised it. Across the
/// whole printed text 銷 appears only in 銷化 (彼後 3:10-12, of fire melting)
/// and here, a fire/quench field, so these are two words in this edition and
/// not orthographic variants of one.
void main() {
  Map<String, String> load(String path) => {
        for (final v in (json.decode(File(path).readAsStringSync()) as List)
            .cast<Map<String, dynamic>>())
          v['id'] as String: v['text'] as String,
      };

  late Map<String, String> zhHans;
  late Map<String, String> zhHant;

  setUpAll(() {
    zhHans = load('assets/cuvs-yhwh.json');
    zhHant = load('assets/cuvs-yhwh-tr.json');
  });

  test('以賽亞書 64:3 and 使徒行傳 25:18 keep the editorial 意料', () {
    // Do NOT "restore" 逆料 here on the strength of the print or the
    // witnesses. See the commit named above; ask the user first.
    expect(zhHant['023064003'], contains('不能意料可畏的事'));
    expect(zhHans['023064003'], contains('不能意料可畏的事'));
    expect(zhHant['044025018'], contains('我所意料的那等惡事'));
    expect(zhHans['044025018'], contains('我所意料的那等恶事'));
  });

  test('帖撒羅尼迦前書 5:19 keeps 銷滅 — a hapax that is CORRECT', () {
    // 1 occurrence against 43 of 消滅, and the print reads 銷滅. Any future
    // sweep that normalises rare spellings towards common ones fails here,
    // which is the entire point of pinning it.
    expect(zhHant['052005019'], '不要銷滅聖靈的感動；');
    expect(zhHans['052005019'], '不要销灭圣灵的感动；');

    final thess = json.decode(
            File('assets/tagged/cuvs-yhwh/1_thessalonians.json').readAsStringSync())
        as Map<String, dynamic>;
    final runs = (thess['5:19'] as List).cast<Map<String, dynamic>>();
    expect(runs.map((r) => r['w'] as String).join(), contains('销灭'));
  });
}
