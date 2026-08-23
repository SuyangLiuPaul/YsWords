import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Fifty verses of both reading editions carried half-width ASCII punctuation
/// in their **running text** — 創世紀 6:11 「滿了強暴.。」 with both a period
/// and a 句號, 民數記 24:17 「毀壞擾亂.之子」 mid-phrase, 撒迦利亞書 14:1
/// opening with 「, 雅偉的日子」, 路加福音 18:37 「他們告訴他:「」.
///
/// It is import residue, not a punctuation choice: the corpus sets full-width
/// marks over 108,000 times, and 55 slots disagreed with all of them.
///
/// Four witnesses decided each position — the plain 和合本 Traditional (git
/// blob `7a2dc43`), the Simplified twin, SeekSparks' independent import, and
/// the Wikisource transcription of the printed 1919. Marks whose identity the
/// witnesses confirm were widened (`!`→！ `:`→： `;`→； `,`→， `()`→（）);
/// marks no witness has, in slots no Chinese punctuation can occupy — a comma
/// straight after 「 or ：, a `)` inside 「我為)我的名」 — were deleted.
///
/// **The ASCII double quote is deliberately left alone**, and the last test
/// here is what stops a future sweep from "finishing the job" — one already
/// tried. `"` is this corpus's 原文 apparatus quote: across the 528 notes that
/// cite 原文 it stands 157 to 7 against 「」, and the eight in running text sit
/// in the same apparatus, the inline （原文有 "…"）parentheticals of 撒迦利亞書.
/// Widening those eight would leave them disagreeing with 157 of their own
/// kind. The tempting counter-population — running-text parentheticals, which
/// read 6/6 「」 — is quoted speech and translation glosses, not 原文 notes.
///
/// The assertions are absolutes rather than counts. Half-width punctuation has
/// no place in Chinese running scripture, so any future import that
/// reintroduces one fails here and gets read against a witness rather than
/// swept. Repair: `tools/repair_ascii_punctuation.py`.
void main() {
  const editions = {
    'Simplified': 'assets/cuvs-yhwh.json',
    'Traditional': 'assets/cuvs-yhwh-tr.json',
  };

  // [雅偉] / [基督] mark where the divine name was restored; `<note: …>` is the
  // translators' apparatus. Neither is running scripture.
  final note = RegExp(r'<note:.*?>');
  final bracket = RegExp(r'\[[^\]]{1,6}\]');
  String running(String text) =>
      text.replaceAll(note, '').replaceAll(bracket, '');

  final loaded = <String, List<Map<String, dynamic>>>{};

  setUpAll(() {
    for (final entry in editions.entries) {
      loaded[entry.key] =
          (json.decode(File(entry.value).readAsStringSync()) as List)
              .cast<Map<String, dynamic>>();
    }
  });

  String textOf(String edition, String id) =>
      loaded[edition]!.firstWhere((v) => v['id'] == id)['text'] as String;

  // Traditional / Simplified readings of the same repaired position.
  const repaired = <String, List<String>>{
    // id            Traditional          Simplified
    '001006011': ['地上滿了強暴。', '地上满了强暴。'],
    '004024017': ['毀壞擾亂之子。', '毁坏扰乱之子。'],
    '029001015': ['哀哉！雅偉的日子', '哀哉！雅伟的日子'],
    '052002013': ['就領受了；不以為', '就领受了；不以为'],
    '042018037': ['他們告訴他：', '他们告诉他：'],
    '023048009': ['我為我的名暫且忍怒', '我为我的名暂且忍怒'],
    '038014001': ['雅偉的日子臨近，', '雅伟的日子临近，'],
    '001048007': ['路上（以法他就是伯利恆）', '路上（以法他就是伯利恒）'],
    '038005003': ['凡偷竊的，必按', '凡偷窃的，必按'],
    '041014045': ['「拉比！」', '“拉比！”'],
    // 路 8:12's period stood where the witnesses set 。— widened, not deleted.
    '042008012': ['信了得救。', '信了得救。'],
  };

  for (final edition in editions.keys) {
    group(edition, () {
      test('running scripture holds no half-width punctuation', () {
        final offenders = <String>[];
        for (final v in loaded[edition]!) {
          final text = running(v['text'] as String);
          for (final mark in const ['.', ',', '!', ';', ':', '(', ')']) {
            if (text.contains(mark)) {
              offenders.add(
                  '${v['book']} ${v['chapter']}:${v['verse']} holds $mark');
              break;
            }
          }
        }
        expect(offenders, isEmpty,
            reason: 'Chinese scripture sets 。，！；：（）, never their ASCII '
                'forms. Re-run tools/repair_ascii_punctuation.py — and read '
                'each position against a witness first, because a stray mark '
                'and a degraded one need opposite treatment.');
      });

      test('the repaired positions read as the witnesses do', () {
        final column = edition == 'Traditional' ? 0 : 1;
        repaired.forEach((id, readings) {
          expect(textOf(edition, id), contains(readings[column]), reason: id);
        });
        // 路 8:45 opens 〔有古卷在此有：…〕 and used to close it with `)`.
        expect(textOf(edition, '042008045'), endsWith('〕'));
      });

      test('no ideograph moved in the two positions that tempted otherwise',
          () {
        // A punctuation repair must never touch the text. 路 8:12's period sat
        // where a 句號 would go and 番 1:1's stray `)` sat where the witness
        // sets a comma, so both were the ones most likely to be "improved"
        // into a substitution. Pinned as text, not as punctuation.
        final cjk = RegExp(r'[一-鿿]');
        expect(cjk.allMatches(running(textOf(edition, '042008012'))).length, 34);
        expect(cjk.allMatches(running(textOf(edition, '036001001'))).length, 50);
      });
    });
  }

  test('the apparatus keeps its ASCII double quote — do not sweep it', () {
    // 336 inside <note: …>, 8 in the inline （原文有 "…"）parentheticals of
    // 撒迦利亞書 1:3, 8:14, 10:1 and 10:12. One convention, two placements.
    // Converting the 8 to 「」 sets them against the 157 ASCII 原文 notes,
    // which is why a first pass that did exactly that was reverted. Whether
    // the whole convention should be full-width is the user's call, not a
    // sweep's; until then this test fails the sweep.
    for (final edition in editions.keys) {
      var inNotes = 0;
      var inRunning = 0;
      for (final v in loaded[edition]!) {
        final text = v['text'] as String;
        for (final m in note.allMatches(text)) {
          inNotes += '"'.allMatches(m.group(0)!).length;
        }
        inRunning += '"'.allMatches(running(text)).length;
      }
      expect(inNotes, 336, reason: edition);
      expect(inRunning, 8, reason: edition);
    }
  });
}
