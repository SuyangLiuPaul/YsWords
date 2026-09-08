import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `assets/tagged/cuvs-yhwh-tr/` is DERIVED, and this is the check that
/// makes it shippable.
///
/// The Traditional 和合本雅偉版 had no tagged layer, so the Exegesis
/// sheet showed a 繁體 reader word cards and no numbered line at all —
/// the screenshot the owner filed on 2026-09-08. The layer that fixes it
/// was not tagged afresh; `tools/derive_tagged_traditional.py` reads the
/// Traditional character out of `assets/cuvs-yhwh-tr.json` at the
/// position the Simplified character stands in.
///
/// **The strongest available assertion is end-to-end and it is made
/// against the shipped asset rather than a fixture.** For every verse
/// where the Simplified tagged layer already reproduces the Simplified
/// reading text exactly, the derived runs must concatenate to the
/// Traditional reading text exactly — same characters, same length, no
/// normalisation, no allowance. That is 23,730 verses of real Bible.
///
/// It is not all 31,041, and the shortfall is notation rather than
/// scripture: the tagged import prints a publisher's note as
/// 〔原文作"天空的表面"〕 where the reading asset writes
/// `<note: 原文作"天空的表面">`. Those verses are covered by the weaker
/// checks below — the run boundaries, the numbers, and the absence of
/// any Simplified-only character the reading pair disagrees about.
///
/// The 61 verses the generator refuses are asserted to be exactly the
/// ones with no positional correspondence to refuse for.
void main() {
  const srcDir = 'assets/tagged/cuvs-yhwh';
  const outDir = 'assets/tagged/cuvs-yhwh-tr';

  late Map<String, String> simplifiedById;
  late Map<String, String> traditionalById;
  late Map<String, String> idByRef; // "书名|c|v" -> id, Simplified names
  late List<String> zhBooks;
  late List<String> enBooks;

  List<dynamic> readJson(String path) =>
      json.decode(File(path).readAsStringSync()) as List<dynamic>;

  setUpAll(() {
    final simplified = readJson('assets/cuvs-yhwh.json').cast<Map>();
    final traditional = readJson('assets/cuvs-yhwh-tr.json').cast<Map>();
    final kjv = readJson('assets/kjv.json').cast<Map>();

    simplifiedById = {
      for (final r in simplified) r['id'] as String: r['text'] as String,
    };
    traditionalById = {
      for (final r in traditional) r['id'] as String: r['text'] as String,
    };
    idByRef = {
      for (final r in simplified)
        '${r['book']}|${r['chapter']}|${r['verse']}': r['id'] as String,
    };
    List<String> order(List<Map> rows) {
      final seen = <String>{};
      final out = <String>[];
      for (final r in rows) {
        final b = r['book'] as String;
        if (seen.add(b)) out.add(b);
      }
      return out;
    }

    zhBooks = order(simplified);
    enBooks = order(kjv);
  });

  String fileName(String englishBook) =>
      englishBook.toLowerCase().replaceAll(' ', '_');

  Map<String, dynamic> book(String dir, String englishBook) =>
      json.decode(File('$dir/${fileName(englishBook)}.json').readAsStringSync())
          as Map<String, dynamic>;

  String joined(dynamic runs) =>
      (runs as List).map((r) => (r as Map)['w'] as String).join();

  test('the derived layer covers every book of the source layer', () {
    for (final en in enBooks) {
      expect(File('$outDir/${fileName(en)}.json').existsSync(), isTrue,
          reason: '$outDir is missing ${fileName(en)}.json');
    }
    expect(Directory(outDir).listSync().whereType<File>().length, 66);
  });

  test(
      'the derived runs reproduce the shipped Traditional verse, character '
      'for character, wherever the Simplified layer reproduces the '
      'Simplified one', () {
    var verified = 0;
    var derived = 0;
    final failures = <String>[];

    for (var i = 0; i < zhBooks.length; i++) {
      final src = book(srcDir, enBooks[i]);
      final out = book(outDir, enBooks[i]);
      for (final entry in out.entries) {
        derived++;
        final parts = entry.key.split(':');
        final id = idByRef['${zhBooks[i]}|${parts[0]}|${parts[1]}'];
        expect(id, isNotNull,
            reason: '${zhBooks[i]} ${entry.key} is in the derived layer and '
                'not in the reading asset');
        if (joined(src[entry.key]) != simplifiedById[id]) continue;
        verified++;
        final got = joined(entry.value);
        if (got != traditionalById[id]) {
          if (failures.length < 5) {
            failures.add('${zhBooks[i]} ${entry.key}\n'
                '  derived : $got\n'
                '  shipped : ${traditionalById[id]}');
          }
        }
      }
    }

    expect(failures, isEmpty,
        reason: 'the derived line is not the shipped Traditional verse:\n'
            '${failures.join('\n')}');
    expect(derived, 31041,
        reason: '31,102 verses less the 61 with no positional '
            'correspondence');
    // Not a floor. This number moving means the two imports of this
    // edition agree in a different number of places than they did, which
    // is a fact about the assets and has to be read before it is
    // accepted.
    expect(verified, 23730);
  });

  test('only the characters changed — every run boundary, number, implied '
      'number and grammar code is the source layer\'s', () {
    var runs = 0;
    for (var i = 0; i < zhBooks.length; i++) {
      final src = book(srcDir, enBooks[i]);
      final out = book(outDir, enBooks[i]);
      for (final entry in out.entries) {
        final a = src[entry.key] as List;
        final b = entry.value as List;
        expect(b.length, a.length,
            reason: '${zhBooks[i]} ${entry.key}: run count changed');
        for (var n = 0; n < a.length; n++) {
          final x = a[n] as Map;
          final y = b[n] as Map;
          expect((y['w'] as String).length, (x['w'] as String).length,
              reason: '${zhBooks[i]} ${entry.key} run $n: length changed, so '
                  'the conversion was not one character in, one out');
          expect(y['s'], x['s'] ?? '');
          expect(y['i'], x['i']);
          expect(y['g'], x['g']);
          runs++;
        }
      }
    }
    // Exact: this is the source layer's own run count over the 31,041
    // verses that survive, and a change to it means a boundary moved.
    expect(runs, 366682);
  });

  test('the 61 skipped verses are exactly the ones with no positional '
      'correspondence to derive from', () {
    final skipped = <String>[];
    for (var i = 0; i < zhBooks.length; i++) {
      final src = book(srcDir, enBooks[i]);
      final out = book(outDir, enBooks[i]);
      for (final ref in src.keys) {
        if (out.containsKey(ref)) continue;
        skipped.add('${zhBooks[i]} $ref');
        final parts = ref.split(':');
        final id = idByRef['${zhBooks[i]}|${parts[0]}|${parts[1]}']!;
        expect(simplifiedById[id]!.length == traditionalById[id]!.length,
            isFalse,
            reason: '${zhBooks[i]} $ref was skipped, but its two scripts are '
                'the same length — there was a position to read the '
                'Traditional character from and the generator did not use '
                'it');
      }
    }
    expect(skipped, hasLength(61));
  });

  test('no derived verse still reads in the Simplified script where the '
      'edition itself distinguishes the two', () {
    // Weaker than the reconstruction above, and it is the check that
    // reaches the ~7,300 verses the reconstruction cannot: a character
    // whose Traditional form the reading pair NEVER agrees with is a
    // conversion that did not happen. Built from the reading pair rather
    // than from `kCuvSimplifiedChars`, because that table lists 面 / 只 /
    // 后 / 干, which are also legitimate Traditional characters, and
    // asserting their absence would fail on correct data.
    final onlySimplified = <String>{};
    for (final id in simplifiedById.keys) {
      final s = simplifiedById[id]!;
      final t = traditionalById[id]!;
      if (s.length != t.length) continue;
      for (var n = 0; n < s.length; n++) {
        if (s[n] != t[n]) onlySimplified.add(s[n]);
      }
    }
    // A character that stands opposite ITSELF anywhere is script-neutral
    // in this edition and may legitimately survive.
    for (final id in simplifiedById.keys) {
      final s = simplifiedById[id]!;
      final t = traditionalById[id]!;
      if (s.length != t.length) continue;
      for (var n = 0; n < s.length; n++) {
        if (s[n] == t[n]) onlySimplified.remove(s[n]);
      }
    }
    expect(onlySimplified, isNotEmpty,
        reason: 'the two scripts differ somewhere; if this is empty the '
            'test below proves nothing');

    final offenders = <String, int>{};
    for (var i = 0; i < zhBooks.length; i++) {
      final out = book(outDir, enBooks[i]);
      for (final runs in out.values) {
        for (final ch in joined(runs).split('')) {
          if (onlySimplified.contains(ch)) {
            offenders[ch] = (offenders[ch] ?? 0) + 1;
          }
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'characters left in the Simplified script: $offenders');
  });
}
