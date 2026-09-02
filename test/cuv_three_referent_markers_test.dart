import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/utils/scripture_markup.dart';

/// 和合本雅偉版 marks the referent of 主 in THREE ways, not two.
///
/// From the user, 2026-09-02:
///
///     主[雅偉]  → Yahweh
///     主#       → 基督
///     主*       → 耶穌
///
/// The third had never reached a reader. It was deleted from both
/// reading assets on 2025-05-17 (b1dbb96a, titled "remove 主*", 121
/// occurrences in one go), the last two on 2026-08-10 as "a character
/// that is not in scripture", and the tagged corpus lost its own 124 on
/// 2026-08-24. Every removal read the asterisk as importer noise.
///
/// The 2026-08-24 reasoning is worth keeping visible because it was
/// confidently backwards: *"All 115 being NT kills the reading that the
/// asterisk is a divine-name convention."* If `主*` means 耶穌 then
/// NT-only is precisely the distribution it must have — the fact was
/// evidence FOR the convention and was recorded as evidence against it.
///
/// So this test pins the census. It is cheap and it is the only thing
/// standing between a future audit and a fourth deletion.
void main() {
  final assets = {
    'assets/cuvs-yhwh.json': '[耶稣]',
    'assets/cuvs-yhwh-tr.json': '[耶穌]',
  };

  group('all three markers are present in the reading assets', () {
    assets.forEach((path, jesus) {
      test(path, () {
        final rows = json.decode(File(path).readAsStringSync()) as List;
        final blob = rows
            .map((r) => (r as Map)['text'] as String? ?? '')
            .join('\n');
        int count(String needle) =>
            needle.allMatches(blob).length;
        // Deliberately exact. A drift in any of the three means either
        // an edit to a frozen asset or another sweep at the notation,
        // and both should stop the build rather than pass quietly.
        expect(count(jesus), 123, reason: 'the restored 主* marker');
        expect(count('[基督]'), 17, reason: 'the 主# marker');
        expect(
            count(path.endsWith('-tr.json') ? '[雅偉]' : '[雅伟]'), 212,
            reason: 'the 主[雅偉] marker, which was never lost');
      });
    });

    test('每一个 restored bracket sits immediately after 主', () {
      // The bracket names the word printed in FRONT of it. One that has
      // drifted off its 主 is not a referent gloss any more, it is a
      // supplied word sitting in the middle of a sentence.
      for (final entry in assets.entries) {
        final rows = json.decode(File(entry.key).readAsStringSync()) as List;
        for (final r in rows) {
          final text = (r as Map)['text'] as String? ?? '';
          var from = 0;
          while (true) {
            final at = text.indexOf(entry.value, from);
            if (at < 0) break;
            // `reason:` is evaluated eagerly, so this snippet has to be
            // in range even when the assertion passes — the first draft
            // threw RangeError on a bracket near the end of a verse and
            // reported a data fault that did not exist.
            final from0 = (at - 6).clamp(0, at);
            final to0 = (at + 6).clamp(0, text.length);
            expect(at > 0 && text[at - 1] == '主', isTrue,
                reason: '${r['id']} — ${entry.value} not preceded by 主: '
                    '${text.substring(from0, to0)}');
            from = at + 1;
          }
        }
      }
    });
  });

  group('the renderer classifies the third marker like the other two', () {
    test('耶穌 is a referent gloss, not a supplied word', () {
      // Without this the 123 restored brackets read as words the
      // translators ADDED — the opposite of what they are, and the doc
      // comment in scripture_markup.dart warns it moves Strong's
      // numbers onto the wrong word.
      for (final token in ['耶稣', '耶穌', 'Jesus']) {
        expect(bracketSpanKind(token), ScriptureSpanKind.gloss,
            reason: token);
        expect(isReferentGloss(token), isTrue, reason: token);
      }
    });

    test('the other two are unchanged', () {
      expect(bracketSpanKind('雅偉'), ScriptureSpanKind.divineName);
      expect(bracketSpanKind('基督'), ScriptureSpanKind.gloss);
      // And the default still holds for genuine supplied words.
      expect(bracketSpanKind('is'), ScriptureSpanKind.supplied);
    });
  });

  test('約翰福音 4:1 — the verse the user reported', () {
    // "in Yahweh's Word, 主* is not yet covered. eg .../john/4:4"
    // The chapter opens 主 知道法利賽人…, and the publisher prints 主*.
    final rows = json
        .decode(File('assets/cuvs-yhwh-tr.json').readAsStringSync()) as List;
    final v = rows.firstWhere((r) => (r as Map)['id'] == '043004001') as Map;
    expect(v['text'], startsWith('主[耶穌]知道法利賽人'));
  });
}
