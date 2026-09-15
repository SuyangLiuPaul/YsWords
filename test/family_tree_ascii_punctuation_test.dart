import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `assets/family_tree.json` is our own editorial prose — the Adam→Jesus
/// family-tree summaries — not scripture and not one of the frozen
/// 和合本雅偉版 assets, so unlike `ascii_punctuation_test.dart` this is a
/// straight widen, not a per-position witness call.
///
/// A census of the four CJK-bearing fields (`nameZhHans`, `nameZhHant`,
/// `summaryZhHans`, `summaryZhHant`) across all 277 people found six ASCII
/// marks and, for each, whether the full-width twin already dominates the
/// same fields:
///
///   * `;` 178 vs `；` 348, `,` 56 vs `，` 120, `(`/`)` 22/22 vs `（）` 176 —
///     **widened** by `tools/repair_family_tree_ascii_punctuation.py`.
///   * `:` 100 — **left alone.** Every one is digit-adjacent, a scripture
///     reference like `馬太福音 1:13-16`, not a punctuation defect.
///   * `'` 10 — **left alone.** Convention is genuinely undecided: some
///     zh-Hans summaries pair `'…'` with a zh-Hant twin's `「…」`, while
///     `lib/pages/bible_trivia_page.dart` sets zh-Hans inner quotes as ASCII
///     `"`. That needs a call, not a sweep — filed as its own queue item.
///
/// This is what stops a future sweep from finishing the `:`/`'` classes by
/// mistake: both counts are pinned here, not just asserted absent, so a
/// change that widens either shows up as a failure instead of a silent
/// "improvement".
void main() {
  const fields = [
    'nameZhHans',
    'nameZhHant',
    'summaryZhHans',
    'summaryZhHant'
  ];

  late List<dynamic> people;

  setUpAll(() {
    final data = json.decode(
        File('assets/family_tree.json').readAsStringSync()) as Map;
    people = data['people'] as List<dynamic>;
  });

  int countMark(String mark) {
    var n = 0;
    for (final p in people) {
      final map = p as Map;
      for (final f in fields) {
        final v = map[f] as String?;
        if (v == null) continue;
        n += mark.allMatches(v).length;
      }
    }
    return n;
  }

  test('the four zh fields hold no half-width ; , ( )', () {
    for (final mark in const [';', ',', '(', ')']) {
      expect(countMark(mark), 0,
          reason: '$mark should have been widened by '
              'tools/repair_family_tree_ascii_punctuation.py');
    }
  });

  test('the widen did not touch the : or \' classes, left for a later call',
      () {
    // Pinned counts, not just "still present": a sweep that widened these
    // too would still pass an isEmpty-style check on the wrong mark, but
    // not this one.
    expect(countMark(':'), 100,
        reason: 'every : is a digit-adjacent scripture reference, e.g. '
            '馬太福音 1:13-16 — a different convention, not a defect');
    expect(countMark('\''), 10,
        reason: "convention is undecided between '…' and 「」 for zh-Hans "
            'inner quotes — filed in the queue, not swept here');
  });

  test('every : is digit-adjacent, the fact that keeps it out of scope', () {
    final offenders = <String>[];
    for (final p in people) {
      final map = p as Map;
      final id = map['id'] as String;
      for (final f in fields) {
        final v = map[f] as String?;
        if (v == null) continue;
        for (var i = 0; i < v.length; i++) {
          if (v[i] != ':') continue;
          final before = i > 0 ? v[i - 1] : '';
          final after = i + 1 < v.length ? v[i + 1] : '';
          final digits = RegExp(r'[0-9]');
          if (!digits.hasMatch(before) || !digits.hasMatch(after)) {
            offenders.add('$id.$f: …${v.substring((i - 5).clamp(0, v.length), (i + 5).clamp(0, v.length))}…');
          }
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'a : not between two digits would not be a scripture '
            'reference, and the case for leaving the class alone would not '
            'hold for it');
  });

  test('bible_chronology.json has no half-width ( ) in its zh fields', () {
    final chronology = json.decode(
        File('assets/bible_chronology.json').readAsStringSync()) as Map;
    final lifelines = chronology['lifelines'] as List<dynamic>;
    const zhFields = [
      'nameZhHans',
      'nameZhHant',
      'derivationZhHans',
      'derivationZhHant'
    ];
    for (final entry in lifelines) {
      final map = entry as Map;
      for (final f in zhFields) {
        final v = map[f] as String?;
        if (v == null) continue;
        expect(v.contains('(') || v.contains(')'), isFalse,
            reason: '${map['personId']}.$f still holds a half-width paren: '
                '$v');
      }
    }
  });
}
