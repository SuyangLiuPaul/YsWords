import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 梁家鏗's Traditional NT, pinned after `tools/repair_biblexg_tr_glyphs.py`
/// (10 substitutions, 2026-09-03).
///
/// **The headline count was misleading and this test exists partly to say so.**
/// The queue filed this as "the same classifier defect, smaller" on the
/// strength of 445 只 against 51 隻. But 443 of those 只 are the adverb "only"
/// and all 51 隻 were already correct classifiers: the defect was TWO
/// positions. A ratio is not a measurement, and the next audit that sees
/// 443:53 here must not reopen this.
///
/// Three signatures in this file look exactly like a converter hole and are
/// not — they are pinned as keeps so nobody re-derives them:
///   鬚 0 / 須 158  — all 必須 / 無須 / 須知
///   罈 0 / 壇 37   — all 祭壇 / 香壇
///   鬍 0 / 胡 1    — 胡乍, Chuza (路 8:3)
///
/// The orthography follows the user's ruling of 2026-09-02, 「参考和合本最新版本
/// 的繁体版…用他们的」, which `docs/user-decisions-p0.md` records as applying to
/// THIS file now that cuvs-yhwh-tr is frozen.
void main() {
  late List<Map<String, dynamic>> rows;
  late Map<String, Map<String, dynamic>> byId;
  late String blob;

  setUpAll(() {
    rows = (json.decode(File('assets/biblexg-v2-tr.json').readAsStringSync())
            as List)
        .cast<Map<String, dynamic>>();
    byId = {for (final r in rows) r['id'] as String: r};
    blob = json.encode(rows);
  });

  int count(String s) => blob.split(s).length - 1;
  String text(String id) => byId[id]!['text'] as String;

  test('the classifier defect was two positions, and they are fixed', () {
    expect(text('40010029'), contains('兩隻麻雀'));
    expect(text('42005007'), contains('把兩隻船裝得滿滿的'));
    expect(count('兩只'), 0);
    expect(count('隻'), 53);
  });

  test('443 只 are the adverb and stay — a blanket rule fails here', () {
    expect(count('只'), 443);
    // 林前 6:20's study note. If a sweep ever "fixes" this the file starts
    // saying 「這隻適用於與法律有關的事情」, which is not Chinese.
    expect(blob, contains('但這只適用於'));
    expect(blob, contains('五隻麻雀'), reason: '路 12:6, the file\'s own parallel');
  });

  test('Hezron is 希斯崙 — the CUV verse spells it so twice', () {
    expect(text('42003033'), contains('希斯崙'));
    expect(count('侖'), 0);
    expect(count('崙'), 4);
  });

  test('the ox treads 穀, not a valley', () {
    // 林前 9:9 and 提前 5:18 both quote 申 25:4, where the CUV reads 踹穀 —
    // the CUV's own grain instalment names this verse and its two NT
    // citations explicitly.
    for (final id in const ['46009009', '54005018']) {
      expect(text(id), contains('使牛踹穀'), reason: id);
    }
    expect(text('44007012'), contains('仍有穀糧'), reason: '徒 7:12 — grain');
    expect(count('踹谷'), 0);
    expect(count('谷糧'), 0);
    // …and every remaining 谷 is a valley or Habakkuk.
    expect(count('谷'), 5);
    expect(blob, contains('哈巴谷'));
    expect(blob, contains('約旦河谷'));
  });

  test('healing is 癒, and the note moved with the verse it quotes', () {
    expect(count('愈'), 0);
    expect(count('癒'), 30);
    expect(text('42008002'), contains('疾病得到治癒的'));
    // 路 8:3's blockNotes quotes 8:2's verse text. If only one of the two ever
    // moves, the note misquotes the verse it annotates — and a `text`-only
    // repair pass would do exactly that.
    final notes = (byId['42008003']!['blockNotes'] as List).join();
    expect(notes, contains('疾病得到治癒的'));
    expect(notes.contains('治愈'), isFalse);
  });

  group('the three signatures that are NOT holes', () {
    test('須 is "must" — there is no beard in this file', () {
      expect(count('鬚'), 0);
      expect(count('須'), 158);
      expect(blob, contains('必須'));
      expect(count('胡須'), 0);
      expect(count('鬍須'), 0);
    });

    test('壇 is an altar — there is no jar in this file', () {
      expect(count('罈'), 0);
      expect(count('壇'), 37);
      expect(blob, contains('祭壇'));
      expect(count('酒壇'), 0);
    });

    test('the one 胡 is Chuza, a name', () {
      expect(count('胡'), 1);
      expect(blob, contains('希律的管家胡乍'));
    });
  });

  test('the two classes docs/user-decisions-p0.md deferred are untouched', () {
    // The doc records 8 stray 着 against 1058 著, and 兇 8 / 凶 8. Measured and
    // deliberately NOT swept, because the "rebuild the Traditional from the
    // corrected Simplified" item will regenerate this file once the publisher
    // answers. Pinned so that a sweep here is a decision, not a side effect.
    final verses = rows.map((r) => r['text'] as String).join();
    int inText(String s) => verses.split(s).length - 1;
    expect(inText('着'), 8);
    expect(inText('著'), 1058);
    expect(inText('兇'), 8);
    expect(inText('凶'), 8);

    // The doc's four numbers are VERSE TEXT ONLY. Over the whole file there
    // are two more 着 and one more 兇, all of them in notes — the same blind
    // spot that hid the 松開 leftover in this file until 2026-08-17, and the
    // reason the audit and every repair here walk all strings at all depths.
    // Pinned separately so that the discrepancy is a recorded fact rather than
    // something the next reader rediscovers as a contradiction.
    expect(count('着'), 10);
    expect(count('著'), 1166);
    expect(count('兇'), 9);
    expect(count('凶'), 8);
  });
}
