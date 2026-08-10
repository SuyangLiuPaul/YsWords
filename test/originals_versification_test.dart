import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/services/versification_service.dart';

/// The Originals sheet used to answer 詩篇 3:1 with מִזְמוֹר לְדָוִד —
/// the superscription, which the Hebrew numbers as verse 1 and the CUV
/// prints inside verse 1 without a number. The verse on screen read
/// 「雅伟啊，我的敌人何其加增」, so the app named a Hebrew word the verse
/// did not contain, in 1,626 verses across 91 chapters.
///
/// The cause was that `assets/originals/` and the concordance are
/// numbered as their source editions number themselves, and the app
/// looked both up by the reading text's numbering.
///
/// This is a DATA test on purpose. Every widget test in this repo stayed
/// green through the whole defect, because the code was doing exactly
/// what it was written to do — the map it needed did not exist.
void main() {
  late Map<String, Map<String, List<String>>> map;

  setUpAll(() {
    final raw = File('assets/originals_versification.json').readAsStringSync();
    map = (json.decode(raw) as Map<String, dynamic>).map(
      (book, refs) => MapEntry(book, (refs as Map<String, dynamic>).map(
          (ref, targets) => MapEntry(ref, (targets as List).cast<String>()))),
    );
  });

  /// Differences any reference Bible lists. If the generator ever stops
  /// reproducing these, it has stopped working — they are the control,
  /// not the point.
  const known = {
    'genesis': {'31:55': '32:1', '32:1': '32:2'},
    'exodus': {'8:1': '7:26', '22:1': '21:37'},
    'leviticus': {'6:1': '5:20'},
    'numbers': {'16:36': '17:1', '29:40': '30:1', '30:1': '30:2'},
    'deuteronomy': {'12:32': '13:1', '22:30': '23:1'},
    '1_samuel': {'23:29': '24:1', '24:1': '24:2'},
    '2_samuel': {'18:33': '19:1'},
    '1_kings': {'4:21': '5:1'},
    '2_kings': {'11:21': '12:1'},
    'nehemiah': {'4:1': '3:33', '9:38': '10:1'},
    'job': {'41:1': '40:25'},
    'ecclesiastes': {'5:1': '4:17'},
    'song_of_solomon': {'6:13': '7:1'},
    'isaiah': {'9:1': '8:23', '64:1': '63:19'},
    'jeremiah': {'9:1': '8:23'},
    'ezekiel': {'20:45': '21:1'},
    'daniel': {'4:1': '3:31', '5:31': '6:1'},
    'hosea': {'1:10': '2:1', '11:12': '12:1'},
    'joel': {'2:28': '3:1', '3:1': '4:1'},
    'jonah': {'1:17': '2:1'},
    'micah': {'5:1': '4:14'},
    'nahum': {'1:15': '2:1'},
    'zechariah': {'1:18': '2:1'},
    'malachi': {'4:1': '3:19'},
    '2_corinthians': {'13:14': '13:13'},
  };

  test('reproduces the versification differences a reference Bible lists', () {
    for (final book in known.entries) {
      for (final ref in book.value.entries) {
        expect(map[book.key]?[ref.key]?.first, ref.value,
            reason: '${book.key} ${ref.key} should be ${ref.value} '
                'in the original-language text');
      }
    }
  });

  test('every mapped reference exists in the originals asset', () {
    for (final book in map.entries) {
      final file = File('assets/originals/${book.key}.json');
      expect(file.existsSync(), isTrue, reason: 'no originals for ${book.key}');
      final verses = (json.decode(file.readAsStringSync()) as Map).keys.toSet();
      for (final entry in book.value.entries) {
        for (final target in entry.value) {
          expect(verses.contains(target), isTrue,
              reason: '${book.key} ${entry.key} points at $target, '
                  'which the originals asset does not have');
        }
      }
    }
  });

  test('every mapped reference exists in the reading text', () {
    for (final book in map.entries) {
      final file = File('assets/tagged/cuvs-yhwh/${book.key}.json');
      if (!file.existsSync()) continue;
      final verses = (json.decode(file.readAsStringSync()) as Map).keys.toSet();
      for (final ref in book.value.keys) {
        expect(verses.contains(ref), isTrue,
            reason: '${book.key} $ref is not a verse the reader can open');
      }
    }
  });

  test('a psalm superscription is kept, not dropped', () {
    // The Hebrew numbers 詩篇 51's two-line superscription 51:1 and
    // 51:2 and the poem opens at 51:3; the CUV prints all of it as
    // verse 1. Returning any one of the three would lose scripture.
    expect(map['psalms']?['51:1'], ['51:1', '51:2', '51:3']);
    expect(map['psalms']?['3:1'], ['3:1', '3:2']);
    // A psalm with no superscription must be left alone.
    expect(map['psalms']?['1:1'], isNull);
    expect(map['psalms']?['23:1'], isNull);
  });

  test('a reading verse spanning two original verses keeps both', () {
    // 1 Chronicles 12:4 is Hebrew 12:4 (Ishmaiah the Gibeonite) plus
    // 12:5. Mapping it to 12:5 alone would drop Ishmaiah.
    expect(map['1_chronicles']?['12:4'], ['12:4', '12:5']);
    expect(map['1_chronicles']?['12:5'], ['12:6']);
  });

  test('the service translates references in both directions', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    VersificationService.resetForTest();

    // Forward: what the Originals sheet asks for.
    expect(await VersificationService.originalRefs('Psalms', 3, 1),
        ['3:1', '3:2']);
    expect(await VersificationService.originalRefs('Joel', 2, 28), ['3:1']);
    // A verse the two editions agree on must be left alone.
    expect(await VersificationService.originalRefs('John', 3, 16), ['3:16']);

    // Backward: what the concordance needs.
    expect(await VersificationService.readingRef('Joel', '4:9'), '3:9');
    expect(await VersificationService.readingRef('Malachi', '3:21'), '4:3');
    expect(await VersificationService.readingRef('John', '3:16'), '3:16');
  });

  test('no concordance reference names a verse the app cannot open', () {
    final concordance = json.decode(
        File('assets/strongs/concordance.json').readAsStringSync()) as Map;
    final inverse = <String, Map<String, String>>{};
    for (final book in map.entries) {
      final table = <String, String>{};
      for (final entry in book.value.entries) {
        for (final original in entry.value) {
          table.putIfAbsent(original, () => entry.key);
        }
      }
      inverse[book.key] = table;
    }

    final valid = <String, Set<String>>{};
    for (final file in Directory('assets/tagged/cuvs-yhwh').listSync()) {
      if (file is! File || !file.path.endsWith('.json')) continue;
      final book = file.uri.pathSegments.last.replaceAll('.json', '');
      valid[book] = (json.decode(file.readAsStringSync()) as Map)
          .keys
          .cast<String>()
          .toSet();
    }

    final unopenable = <String>[];
    for (final entry in concordance.values) {
      if (entry is! Map) continue;
      for (final raw in (entry['r'] as List? ?? const [])) {
        if (raw is! String) continue;
        final m = RegExp(r'^(.+?)\s+(\d+:\d+)$').firstMatch(raw);
        if (m == null) continue;
        final book = m
            .group(1)!
            .toLowerCase()
            .replaceAll(' ', '_')
            .replaceAll("'", '');
        final verses = valid[book];
        if (verses == null) continue;
        final reading = inverse[book]?[m.group(2)!] ?? m.group(2)!;
        if (!verses.contains(reading)) unopenable.add(raw);
      }
    }
    expect(unopenable, isEmpty,
        reason: '${unopenable.length} concordance references still point at '
            'verses this app has no page for, e.g. '
            '${unopenable.take(5).toList()}');
  });
}
