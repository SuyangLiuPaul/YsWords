import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Nine ASCII question marks sat inside running scripture in **both** CUV
/// editions at the same five positions — 「在耶斯列??平原安營」,
/// 「將這血染了??腰間束的帶」, 「也沒有??用布裹你」, 「向我發烈怒??，」 and
/// 「他們所住?的列國人」 — from the very first import of the asset.
///
/// They were held back from the punctuation sweep that preceded them because
/// `??` is the classic signature of a **lost double-byte character**, and
/// deleting a mark that stands in for a dropped word conceals a textual loss.
/// Three witnesses say nothing is missing: the plain Traditional 和合本 (git
/// blob `7a2dc43`), an independently digitised Simplified 和合本 outside this
/// repo, and — decisively, because it is the same 雅偉 edition — this repo's
/// own tagged Strong's corpus, which carries four of the five verses with no
/// character at the slot at all. The Hebrew leaves no room for a word either.
///
/// Characters really are dropped elsewhere in this corpus (士師記 12:13 reads
/// 「作以色的士師」 for 以色列), but those losses leave **no marker**. That is a
/// different defect and is queued separately; this test must not be read as
/// evidence about it.
///
/// The assertion is an absolute rather than a count: an ASCII `?` has no place
/// in Chinese scripture at all, so any future import that reintroduces one —
/// stray or mojibake — fails here and gets read rather than swept.
void main() {
  const editions = {
    'Simplified': 'assets/cuvs-yhwh.json',
    'Traditional': 'assets/cuvs-yhwh-tr.json',
  };

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

  for (final edition in editions.keys) {
    group(edition, () {
      test('no verse carries a half-width question mark', () {
        final offenders = <String>[];
        for (final v in loaded[edition]!) {
          if ((v['text'] as String).contains('?')) {
            offenders.add('${v['book']} ${v['chapter']}:${v['verse']}');
          }
        }
        expect(offenders, isEmpty,
            reason: 'Chinese scripture sets ？, never ?. Re-run '
                'tools/repair_question_mark_artifacts.py — and read the verse '
                'against a witness first, because a `??` can also mean a '
                'character was lost.');
      });

      test('the five repaired verses read whole', () {
        expect(textOf(edition, '007006033'),
            contains('在耶斯列平原安營'.chars(edition)));
        expect(textOf(edition, '011002005'),
            contains('染了腰間束的帶'.chars(edition)));
        expect(
            textOf(edition, '026016004'), contains('也沒有用布裹你'.chars(edition)));
        expect(textOf(edition, '026016043'),
            contains('向我發烈怒，所以'.chars(edition)));
        expect(textOf(edition, '026020009'),
            contains('他們所住的列國人'.chars(edition)));
      });
    });
  }

  test('the tagged Strong\'s corpus carries no half-width question mark', () {
    final dir = Directory('assets/tagged/cuvs-yhwh');
    final offenders = <String>[];
    for (final file in dir.listSync().whereType<File>()) {
      if (!file.path.endsWith('.json')) continue;
      final data = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
      for (final entry in data.entries) {
        for (final run in (entry.value as List).cast<Map<String, dynamic>>()) {
          if ((run['w'] as String? ?? '').contains('?')) {
            offenders.add('${file.uri.pathSegments.last} ${entry.key}');
          }
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'the interlinear renders these words too — 以西結書 16:43 '
            'carried the same stray, and 約伯記 15:12/15:16 ended a clause '
            'with ? where the verse sets ，and ！');
  });

  test('約伯記 15:12 and 15:16 end as the verse does', () {
    final job =
        json.decode(File('assets/tagged/cuvs-yhwh/job.json').readAsStringSync())
            as Map<String, dynamic>;
    String joined(String ref) => (job[ref] as List)
        .cast<Map<String, dynamic>>()
        .map((r) => r['w'] as String? ?? '')
        .join();
    expect(joined('15:12'), endsWith('冒出火星，'));
    expect(joined('15:16'), endsWith('的世人呢！'));
  });
}

extension on String {
  /// The two editions differ in script, so a Traditional probe has to be
  /// written in Simplified to be looked for in the Simplified asset. Only the
  /// characters used by the probes above need mapping.
  String chars(String edition) {
    if (edition != 'Simplified') return this;
    const map = {
      '斯': '斯',
      '營': '营',
      '帶': '带',
      '們': '们',
      '國': '国',
      '發': '发',
      '烈': '烈',
      '沒': '没',
      '裹': '裹',
      '間': '间',
      '束': '束',
      '住': '住',
    };
    return split('').map((c) => map[c] ?? c).join();
  }
}
