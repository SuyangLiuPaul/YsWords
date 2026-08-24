import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Two verses printed a closing bracket that nothing had opened.
///
/// 士師記 8:24 ended `…都是戴金耳環的。〕` and 耶利米書 10:11 ended
/// `…被除滅！〕`. `〕` matches no annotation pattern in
/// `build_verse_content_spans.dart`, so both were painted literally — a
/// closing bracket sitting in scripture, in both editions.
///
/// **They were removed rather than completed, and the first attempt got that
/// backwards.** Restoring a lost `〔` looks like the obvious repair: blob
/// `7a2dc43` brackets the aside at both verses and the tagged corpus agrees on
/// the scope at 士 8:24. Two measurements break it.
///
/// SeekSparks' `cuvs-plus.json` is not a second witness — it is this edition's
/// base text (23,845 of 31,102 verses character-identical once 雅伟→耶和华 and
/// 〔〕→（） are normalised), so the orphan was inherited, not independently
/// attested. And this edition has already ruled on the shape three times:
/// pairing brackets across the base text in verse order gives **9 unpaired
/// marks**, of which the editorial pass resolved 7. Every orphan OPENER was
/// completed — 路 8:45 gained its `〕`, 羅 2:13's aside gained a closer at
/// 2:15, 約 4:8's mistyped `〉` became `）`, 來 2:7 became a `<note: …>`. Every
/// orphan CLOSER had the mark taken out — 出 9:32 `…還沒有長成。）` became
/// `…還沒有長成。`, and 出 16:32 and 撒上 14:43 became notes. No completion
/// anywhere rested on a surviving closer alone, because a closer alone does
/// not say where the aside began.
///
/// `tools/repair_orphan_close_bracket.py` applies it.
void main() {
  const openers = '（〔';
  const closers = '）〕';

  List<Map<String, dynamic>> load(String name) =>
      (json.decode(File('assets/$name').readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();

  /// Per-verse balance is the wrong test: eleven of this edition's asides
  /// legitimately open at the end of one verse and close at the end of the
  /// next. Brackets have to be paired across the corpus in verse order.
  (List<String>, List<String>) pair(List<Map<String, dynamic>> verses) {
    final stack = <String>[];
    final orphanClosers = <String>[];
    for (final v in verses) {
      for (final ch in (v['text'] as String).split('')) {
        if (openers.contains(ch)) {
          stack.add(v['id'] as String);
        } else if (closers.contains(ch)) {
          if (stack.isNotEmpty) {
            stack.removeLast();
          } else {
            orphanClosers.add(v['id'] as String);
          }
        }
      }
    }
    return (orphanClosers, stack);
  }

  for (final asset in ['cuvs-yhwh.json', 'cuvs-yhwh-tr.json']) {
    group(asset, () {
      final verses = load(asset);
      final byId = {for (final v in verses) v['id'] as String: v};

      test('no bracket is left unpaired anywhere in the corpus', () {
        final (orphanClosers, orphanOpeners) = pair(verses);
        expect(orphanClosers, isEmpty,
            reason: 'a closing bracket with nothing to close is printed to '
                'the reader as scripture');
        expect(orphanOpeners, isEmpty,
            reason: 'an unclosed aside swallows the rest of the corpus');
      });

      test('士師記 8:24 and 耶利米書 10:11 now end on their own punctuation', () {
        // Fails on the pre-repair data, where both ended `〕`.
        expect(byId['007008024']!['text'] as String, endsWith('。'));
        expect(byId['024010011']!['text'] as String, endsWith('！'));
        for (final id in ['007008024', '024010011']) {
          final text = byId[id]!['text'] as String;
          for (final mark in ['〕', '〔', '（', '）']) {
            expect(text, isNot(contains(mark)),
                reason: '$id should carry no bracket at all');
          }
        }
      });

      test('the aside itself is untouched — only the mark went', () {
        expect(byId['007008024']!['text'] as String,
            contains(RegExp('原[來来]仇敵|原[來来]仇敌')));
        expect(byId['024010011']!['text'] as String,
            contains(RegExp('必從地上|必从地上')));
      });

      test('the 12 legitimate asides still pair, and are not swept', () {
        // Eleven cross-verse pairs plus the self-contained 路 8:45. A future
        // "tidy the brackets" pass must not take these.
        const openIds = [
          '004031043', '011021025', '024026020', '024027019', //
          '040018010', '040023013', '041015027', '042008045', //
          '042023016', '043005003', '044024006', '044028028',
        ];
        for (final id in openIds) {
          expect(byId[id]!['text'] as String, contains('〔'),
              reason: '$id opens a legitimate aside');
        }
      });
    });
  }

  test('the word-tap corpus has no unpaired bracket either', () {
    // Trap 25: a census of the reading assets is not a census of what the
    // reader sees. `assets/tagged/cuvs-yhwh/` is a second transcription and
    // `originals_sheet.dart` renders it verbatim in place of the verse.
    final files = Directory('assets/tagged/cuvs-yhwh')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'));
    for (final file in files) {
      final decoded =
          json.decode(file.readAsStringSync()) as Map<String, dynamic>;
      final stack = <String>[];
      final orphanClosers = <String>[];
      for (final entry in decoded.entries) {
        final text = (entry.value as List)
            .map((r) => (r as Map<String, dynamic>)['w'] as String? ?? '')
            .join();
        for (final ch in text.split('')) {
          if (openers.contains(ch)) {
            stack.add(entry.key);
          } else if (closers.contains(ch)) {
            if (stack.isNotEmpty) {
              stack.removeLast();
            } else {
              orphanClosers.add(entry.key);
            }
          }
        }
      }
      expect(orphanClosers, isEmpty, reason: '${file.path} orphan closer');
      expect(stack, isEmpty, reason: '${file.path} unclosed opener');
    }
  });
}
