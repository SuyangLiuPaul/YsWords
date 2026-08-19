import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 那鴻書 3:4 renders one Hebrew verb with two Chinese ones, and the
/// 「原文是賣」 note can only sit on one of them:
///
///     藉淫行誘惑<note: 原文是賣>列國，用邪術誘惑多族。
///
/// Three external digital witnesses put that note on the SECOND 誘惑 instead.
/// It was read on 2026-08-19 and **deliberately left where it is**, because
/// nothing available settles it: the printed 1919 sets 「誘惑原文作賣」 at the
/// END of the verse, naming the word rather than pointing at an occurrence,
/// and the Hebrew has a single gapped הַמֹּכֶרֶת governing both objects — so
/// the note is true on either one and false on neither.
///
/// This test exists to stop the verse drifting while it is unsettled. Moving
/// the note is a decision for the user, not a tidy-up, and it should cost a
/// deliberate edit here. `tools/audit_note_placement.py` holds the same verse
/// in its UNSETTLED set with the full argument on both sides.
void main() {
  test('那鴻書 3:4 keeps its 原文是賣 note on the first 誘惑', () {
    const files = {
      'assets/cuvs-yhwh.json': '借淫行诱惑<note: 原文是卖>列国，用邪术诱惑多族。',
      'assets/cuvs-yhwh-tr.json': '藉淫行誘惑<note: 原文是賣>列國，用邪術誘惑多族。',
    };

    files.forEach((path, expected) {
      final rows = (jsonDecode(File(path).readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();
      final verse = rows.firstWhere((r) => r['id'] == '034003004');
      expect(
        verse['text'] as String,
        endsWith(expected),
        reason: '$path — see UNSETTLED in tools/audit_note_placement.py before '
            'moving this note',
      );
    });
  });
}
