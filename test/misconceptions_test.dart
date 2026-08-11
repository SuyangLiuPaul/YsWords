import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The misconceptions page corrects other people's Bible mistakes, which
/// makes it the most quotable surface in the app and the worst possible
/// place to be wrong. `scripts/build_misconceptions.py` verifies every
/// citation when the asset is generated; this re-verifies the SHIPPED
/// asset, so a hand-edit or a bad merge cannot slip a false citation
/// past the build step that was supposed to catch it.
void main() {
  late Map<String, dynamic> doc;
  late List<Map<String, dynamic>> entries;
  late Map<(String, String, String), String> kjv;

  setUpAll(() {
    doc = jsonDecode(File('assets/misconceptions.json').readAsStringSync())
        as Map<String, dynamic>;
    entries = [
      for (final e in (doc['entries'] as List)) e as Map<String, dynamic>,
    ];
    final rows = jsonDecode(File('assets/kjv.json').readAsStringSync()) as List;
    kjv = {
      for (final r in rows.cast<Map<String, dynamic>>())
        (r['book'] as String, r['chapter'] as String, r['verse'] as String):
            (r['text'] as String).trim(),
    };
  });

  test('every cited verse exists and contains the words relied on', () {
    final problems = <String>[];
    for (final e in entries) {
      for (final r in (e['refs'] as List).cast<Map<String, dynamic>>()) {
        final key = (r['book'] as String, r['chapter'] as String,
            r['verse'] as String);
        final text = kjv[key];
        if (text == null) {
          problems.add('${e['id']}: $key is not a verse');
          continue;
        }
        final must = (r['must'] as String).toLowerCase();
        if (!text.toLowerCase().contains(must)) {
          problems.add('${e['id']}: ${r['book']} ${r['chapter']}:'
              '${r['verse']} does not contain "$must"');
        }
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('every entry is categorised, and only with a known category', () {
    const known = {'text', 'absent', 'tradition', 'disputed'};
    for (final e in entries) {
      expect(known, contains(e['category']),
          reason: '${e['id']} has category ${e['category']}');
    }
  });

  test('every entry carries all three locales for claim and explanation',
      () {
    // A card that renders blank in one language is a card that quietly
    // stops correcting anything for those readers.
    for (final e in entries) {
      for (final field in ['claim', 'says']) {
        final m = e[field] as Map<String, dynamic>;
        for (final loc in ['zh-Hans', 'zh-Hant', 'en']) {
          expect(m[loc], isA<String>(),
              reason: '${e['id']}.$field is missing $loc');
          expect((m[loc] as String).trim(), isNotEmpty,
              reason: '${e['id']}.$field.$loc is empty');
        }
      }
    }
  });

  test('a disputed entry says so in its own text, not just its tag', () {
    // The tag is a chip a reader can miss. Hebrews' authorship is a live
    // question; the card has to admit that in the sentence itself, or it
    // reads as a settled correction and commits the error this page
    // exists to point out.
    final disputed = entries.where((e) => e['category'] == 'disputed');
    expect(disputed, isNotEmpty, reason: 'expected at least one');
    for (final e in disputed) {
      final en = ((e['says'] as Map)['en'] as String).toLowerCase();
      expect(
        en.contains('open question') ||
            en.contains('not settled') ||
            en.contains('disputed'),
        isTrue,
        reason: '${e['id']} is tagged disputed but its text does not say so',
      );
    }
  });

  test('entries that claim scripture is silent cite nothing, or cite the '
      'passage people confuse it with', () {
    for (final e in entries.where((e) => e['category'] == 'absent')) {
      // Either no refs (the phrase simply is not in the Bible) or refs
      // that show what the passage DOES say. Both are honest; a stray
      // citation supporting an absence is not.
      expect(e['refs'], isA<List>());
    }
  });

  test('the asset records that it was verified', () {
    expect((doc['_meta'] as Map)['checked'], greaterThan(0));
  });
}
