import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 2026-08-25 — the major/minor prophets misconception, pinned.
///
/// The user reported that this entry's argument was wrong. It had said the
/// length rule "is not even applied consistently", offering Lamentations
/// (154 verses, filed Major) as shorter than Zechariah (211, filed Minor).
/// Every number was right; the inference was not. Lamentations travels with
/// the Major Prophets because tradition assigns it to Jeremiah and the Greek
/// and Latin orderings place it directly after his book — whose own scroll,
/// at 1,364 verses, is the longest of the group. The classifiers were not
/// being careless about length, and the entry was accusing them of an
/// inconsistency they did not commit.
///
/// These tests exist because the numbers are the load-bearing part of the
/// corrected answer, and because the discarded inference is easy to
/// re-derive from the same two figures. They count verses out of the app's
/// own scripture asset rather than trusting the prose.
void main() {
  late Map<String, int> verses;
  late Map<String, dynamic> entry;

  setUpAll(() {
    final bible = jsonDecode(File('assets/cuvs-yhwh.json').readAsStringSync())
        as List<dynamic>;
    verses = <String, int>{};
    for (final v in bible) {
      final b = (v as Map<String, dynamic>)['book'] as String;
      verses[b] = (verses[b] ?? 0) + 1;
    }
    final doc =
        jsonDecode(File('assets/misconceptions.json').readAsStringSync())
            as Map<String, dynamic>;
    entry = (doc['entries'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .firstWhere((e) => e['id'] == 'major-minor-prophets');
  });

  test('every verse count the entry quotes matches the scripture asset', () {
    expect(verses['耶利米哀歌'], 154);
    expect(verses['撒迦利亚书'], 211);
    expect(verses['以赛亚书'], 1292);
    expect(verses['耶利米书'], 1364);

    const twelve = [
      '何西阿书', '约珥书', '阿摩司书', '俄巴底亚书', '约拿书', '弥迦书',
      '那鸿书', '哈巴谷书', '西番雅书', '哈该书', '撒迦利亚书', '玛拉基书',
    ];
    expect(twelve.fold<int>(0, (a, b) => a + (verses[b] ?? 0)), 1050);

    for (final n in ['154', '211', '1,050', '1,292', '1,364']) {
      expect(entry['says']['zh-Hans'], contains(n));
      expect(entry['says']['zh-Hant'], contains(n));
      expect(entry['says']['en'], contains(n));
    }
  });

  test('Jeremiah really is the longest of the prophetic scrolls', () {
    // The corrected answer leans on this: Lamentations did not slip past a
    // length rule, it arrived attached to the longest book in the group.
    for (final b in ['以赛亚书', '以西结书', '但以理书', '撒迦利亚书']) {
      expect(verses['耶利米书']!, greaterThan(verses[b]!), reason: b);
    }
  });

  test('the refuted inconsistency argument has not come back', () {
    // Not a style rule — this exact claim was the defect. An edit that
    // reintroduces it is re-asserting something shown to be false.
    expect(entry['says']['en'], isNot(contains('not even applied')));
    expect(entry['says']['zh-Hans'], isNot(contains('没有严格执行')));
    expect(entry['says']['zh-Hant'], isNot(contains('沒有嚴格執行')));
  });

  test("the answer says the division is not the Bible's, in all three", () {
    expect(entry['says']['zh-Hans'], contains('不是圣经本身作的'));
    expect(entry['says']['zh-Hant'], contains('不是聖經本身作的'));
    expect(entry['says']['en'], contains('Scripture does not make this'));
    // The Writings point is what makes it concrete rather than assertion.
    expect(entry['says']['zh-Hans'], contains('Ketuvim'));
    expect(entry['says']['en'], contains('Ketuvim'));
  });
}
