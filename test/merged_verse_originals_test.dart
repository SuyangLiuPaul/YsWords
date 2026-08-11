import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/constants/book_names.dart';
import 'package:yswords/services/versification_service.dart';

/// The CUV folds some numbered verses into the one before them and
/// prints the vacated number as 「见上节」. 民数记 1:21 is one, and the
/// census total it should carry — 「四万六千五百」 — is printed at the end
/// of 1:20. The Originals sheet on 1:20 therefore showed the Hebrew of
/// 1:20 alone, without שִׁשָּׁה וְאַרְבָּעִים אֶלֶף וַחֲמֵשׁ מֵאוֹת: half the
/// verse the reader was looking at.
///
/// This is a DATA test. The evidence for every entry is the
/// translation's own marker, so the classification is re-derived here
/// from `assets/cuvs-yhwh.json` rather than copied from the tool that
/// wrote the overlay — a stale overlay fails.
void main() {
  late Map<String, Map<String, Map<String, List<String>>>> merged;

  /// Reading verses the translation says are printed in another verse.
  /// Returns book slug → "c:v" → 'prev' | 'next'.
  Map<String, Map<String, String>> pointers(String version) {
    final rows = json.decode(
        File('assets/$version.json').readAsStringSync()) as List;
    final note = RegExp(r'<note:[^>]*>');
    final out = <String, Map<String, String>>{};
    for (final row in rows.cast<Map<String, dynamic>>()) {
      final text = row['text'] as String;
      final body = text.replaceAll(note, '').trim();
      String? direction;
      if (body == '见上节' || body == '見上節') {
        direction = 'prev';
      } else if (body.isEmpty) {
        final notes = note.allMatches(text).map((m) => m[0]!).join(' ');
        if (notes.contains('见下节') || notes.contains('見下節')) {
          direction = 'next';
        } else if (notes.contains('上一节') || notes.contains('上一節')) {
          direction = 'prev';
        }
      }
      if (direction == null) continue;
      final english =
          bookNameToEnglish[row['book'] as String] ?? row['book'] as String;
      final slug =
          english.toLowerCase().replaceAll(' ', '_').replaceAll("'", '');
      out.putIfAbsent(slug, () => {})['${row['chapter']}:${row['verse']}'] =
          direction;
    }
    return out;
  }

  setUpAll(() {
    final raw =
        File('assets/originals_versification_merged.json').readAsStringSync();
    merged = (json.decode(raw) as Map<String, dynamic>).map((version, books) =>
        MapEntry(
            version,
            (books as Map<String, dynamic>).map((book, refs) => MapEntry(
                book,
                (refs as Map<String, dynamic>).map((ref, targets) =>
                    MapEntry(ref, (targets as List).cast<String>()))))));
  });

  test('both CUV editions mark the same verses as merged', () {
    expect(pointers('cuvs-yhwh'), pointers('cuvs-yhwh-tr'));
    expect(merged['cuvs-yhwh'], merged['cuvs-yhwh-tr']);
  });

  test('every merged verse is carried by the verse that prints it', () {
    final marks = pointers('cuvs-yhwh');
    final overlay = merged['cuvs-yhwh']!;
    // 71 folded into the previous verse, and 約翰福音 7:53 into the next.
    expect(marks.values.fold<int>(0, (n, m) => n + m.length), 72);

    final base = (json
            .decode(File('assets/originals_versification.json')
                .readAsStringSync()) as Map<String, dynamic>)
        .map((book, refs) => MapEntry(book, (refs as Map<String, dynamic>)
            .map((ref, t) => MapEntry(ref, (t as List).cast<String>()))));
    List<String> baseRefs(String book, String ref) =>
        base[book]?[ref] ?? [ref];

    final unaccounted = <String>[];
    for (final book in marks.entries) {
      final verses = (json.decode(
              File('assets/tagged/cuvs-yhwh/${book.key}.json')
                  .readAsStringSync()) as Map)
          .keys
          .cast<String>()
          .toList()
        ..sort((a, b) {
          int c(String r) => int.parse(r.split(':')[0]);
          int v(String r) => int.parse(r.split(':')[1]);
          return c(a) == c(b) ? v(a).compareTo(v(b)) : c(a).compareTo(c(b));
        });

      for (final mark in book.value.entries) {
        // Walk to the nearest verse that is not itself merged — 詩篇 8:6
        // absorbs both 8:7 and 8:8.
        final step = mark.value == 'prev' ? -1 : 1;
        var i = verses.indexOf(mark.key) + step;
        while (i >= 0 &&
            i < verses.length &&
            book.value.containsKey(verses[i])) {
          i += step;
        }
        if (i < 0 || i >= verses.length) {
          unaccounted.add('${book.key} ${mark.key}: nothing absorbs it');
          continue;
        }
        final carried = overlay[book.key]?[verses[i]] ?? const <String>[];
        for (final ref in baseRefs(book.key, mark.key)) {
          if (!carried.contains(ref)) {
            unaccounted.add('${book.key} ${mark.key} is printed inside '
                '${verses[i]}, whose Originals sheet omits $ref');
          }
        }
      }
    }
    expect(unaccounted, isEmpty, reason: unaccounted.join('\n'));
  });

  test('every target exists in the originals asset', () {
    for (final version in merged.entries) {
      for (final book in version.value.entries) {
        final file = File('assets/originals/${book.key}.json');
        expect(file.existsSync(), isTrue, reason: 'no originals for '
            '${book.key}');
        final verses = (json.decode(file.readAsStringSync()) as Map).keys
            .cast<String>()
            .toSet();
        for (final entry in book.value.entries) {
          expect(entry.value.length, greaterThan(1),
              reason: '${book.key} ${entry.key} is in the overlay but adds '
                  'nothing');
          for (final target in entry.value) {
            expect(verses.contains(target), isTrue,
                reason: '${book.key} ${entry.key} points at $target, which '
                    'assets/originals/${book.key}.json does not have');
          }
        }
      }
    }
  });

  test('the service widens a merged verse, and only for that version',
      () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    VersificationService.resetForTest();

    // 民数记 1:20 ends with the census total the Hebrew numbers 1:21.
    expect(
        await VersificationService.originalRefs('Numbers', 1, 20,
            version: 'cuvs-yhwh'),
        ['1:20', '1:21']);
    expect(
        await VersificationService.originalRefs('Numbers', 1, 20,
            version: 'cuvs-yhwh-tr'),
        ['1:20', '1:21']);

    // The KJV prints 1:21 as a verse of its own, so its verse 20 must
    // not be given a Hebrew clause it does not contain.
    expect(
        await VersificationService.originalRefs('Numbers', 1, 20,
            version: 'kjv'),
        ['1:20']);
    expect(await VersificationService.originalRefs('Numbers', 1, 20),
        ['1:20']);

    // 約翰福音 7:53 is printed inside 8:1 — the absorbing verse is in
    // the next chapter, and the Greek it carries comes first.
    expect(
        await VersificationService.originalRefs('John', 8, 1,
            version: 'cuvs-yhwh'),
        ['7:53', '8:1']);

    // 詩篇 8:6 absorbs two: 8:7 and 8:8 are both 「见上节」, and the
    // Hebrew numbers the psalm one verse ahead throughout.
    expect(
        await VersificationService.originalRefs('Psalms', 8, 6,
            version: 'cuvs-yhwh'),
        ['8:7', '8:8', '8:9']);

    // A verse neither merged nor renumbered is left alone.
    expect(
        await VersificationService.originalRefs('John', 3, 16,
            version: 'cuvs-yhwh'),
        ['3:16']);
    // And the base map still applies where there is no merge.
    expect(
        await VersificationService.originalRefs('Psalms', 3, 1,
            version: 'cuvs-yhwh'),
        ['3:1', '3:2']);
  });
}
