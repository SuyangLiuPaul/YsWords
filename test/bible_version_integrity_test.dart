import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/constants/book_names.dart';
import 'package:yswords/constants/text_patterns.dart';

/// Structural audit of the five whole-Bible versions, the same way
/// `biblexg_verse_integrity_test.dart` audits the 梁家鏗譯本.
///
/// These files had only ever been checked for duplicates, empties and
/// mojibake. Running the remaining checks over them found 16 verses
/// carrying a character that is not in scripture — ten stray `|` in the
/// KJV, two of which split a word (`hide nothing from m|e`, `he that
/// c|alleth`), and a stray `{` and two stray `*` in each CUV edition.
/// Every one was settled against an independent import of the same
/// translation before being touched, never by rewriting the verse.
///
/// A test that only proves the app parses these files would have stayed
/// green through all of it.
void main() {
  const versions = [
    'kjv',
    'nasb',
    'leb',
    'cuvs-yhwh',
    'cuvs-yhwh-tr',
  ];

  /// Characters that are an import artefact in this version. What counts
  /// depends on the edition's own typography: the NASB brackets the
  /// passages the critical text disputes and marks the historical
  /// present with `*`; the LEB brackets supplied words and braces
  /// idiomatic renderings; both CUV editions bracket the divine name
  /// they restore (`[雅伟]`, `[基督]`). Those are the publisher speaking
  /// and are left alone. Nothing here is.
  const forbidden = <String, String>{
    'kjv': r'|{}[]*^~',
    'nasb': r'|{}^~',
    'leb': r'|^~',
    'cuvs-yhwh': r'|{}*^~',
    'cuvs-yhwh-tr': r'|{}*^~',
  };

  /// References the KJV has and this version does not, and vice versa.
  /// All of them are versification, not loss: the modern editions follow
  /// a critical text that omits these verses or merges them into their
  /// neighbour, and each is a well known variant rather than a hole in
  /// the data. Anything NOT on this list is a lost verse.
  const missingVsKjv = <String, List<String>>{
    'kjv': [],
    'nasb': [
      'Matthew 17:21', 'Matthew 18:11', 'Matthew 23:14', 'Mark 7:16',
      'Mark 9:44', 'Mark 9:46', 'Mark 15:28', 'John 5:4', 'Acts 8:37',
      'Acts 15:34', 'Acts 24:7', 'Acts 28:29', 'Romans 16:24',
    ],
    'leb': [
      'Nehemiah 7:68', 'Matthew 17:21', 'Matthew 18:11', 'Matthew 23:14',
      'Mark 7:16', 'Mark 9:44', 'Mark 9:46', 'Mark 11:26', 'Mark 15:28',
      'Luke 17:36', 'Luke 23:17', 'John 5:4', 'Acts 8:37', 'Acts 15:34',
      'Acts 19:41', 'Acts 24:7', 'Acts 28:29', 'Romans 16:25',
      'Romans 16:26', 'Romans 16:27', '2 Corinthians 13:14',
    ],
    'cuvs-yhwh': [],
    'cuvs-yhwh-tr': [],
  };

  /// Verses these editions have that the KJV does not — again
  /// versification. The KJV runs 3 John to 14 verses where the critical
  /// text splits the last into 14 and 15; the LEB numbers the line the
  /// KJV prints as Revelation 13:1a as 12:18.
  const extraVsKjv = <String, List<String>>{
    'kjv': [],
    'nasb': ['3 John 1:15'],
    'leb': ['3 John 1:15', 'Revelation 12:18'],
    'cuvs-yhwh': [],
    'cuvs-yhwh-tr': [],
  };

  List<Map<String, dynamic>> load(String version) =>
      (json.decode(File('assets/$version.json').readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();

  /// The key the app itself uses. `Verse.id` resolves the book through
  /// `bookNameToEnglish` so a highlight survives a version switch, so
  /// that is the key the cross-version checks have to compare on — not
  /// the `id` field, and not the localised book name.
  String appKey(Map<String, dynamic> v) =>
      '${bookNameToEnglish[v['book']] ?? v['book']}'
      ' ${v['chapter']}:${v['verse']}';

  for (final version in versions) {
    group('$version integrity', () {
      late List<Map<String, dynamic>> verses;

      setUpAll(() => verses = load(version));

      test('every reference is unique and no verse is empty', () {
        final seen = <String>{};
        final duplicates = <String>[];
        final empties = <String>[];
        for (final v in verses) {
          final ref = appKey(v);
          if (!seen.add(ref)) duplicates.add(ref);
          if ((v['text'] as String).trim().isEmpty) empties.add(ref);
        }
        expect(duplicates, isEmpty);
        expect(empties, isEmpty);
      });

      test('every book name resolves to an English name', () {
        // A book that falls through the map keeps its localised name in
        // `Verse.id`, which silently desyncs every highlight and note on
        // that book from the same verse in every other translation.
        final unmapped = <String>{
          for (final v in verses)
            if (!bookNameToEnglish.containsKey(v['book'])) v['book'] as String
        };
        expect(unmapped, isEmpty);
        expect(
          {for (final v in verses) bookNameToEnglish[v['book']]}, hasLength(66),
        );
      });

      test('no verse carries a character that is not in the text', () {
        final offenders = <String>[];
        for (final v in verses) {
          for (final c in forbidden[version]!.split('')) {
            if ((v['text'] as String).contains(c)) {
              offenders.add('${appKey(v)} — $c');
            }
          }
        }
        expect(offenders, isEmpty);
      });

      test('the id field addresses exactly one verse', () {
        // 歷代志上 and 歷代志下 both carried the prefix `000` in the
        // Traditional CUV, so all 1,764 of their verses collided with
        // each other. The app computes its own id and never read this
        // field, which is the only reason nothing broke.
        final byId = <String, String>{};
        final collisions = <String>[];
        final malformed = <String>[];
        for (final v in verses) {
          // The LEB ships 116 Psalm superscriptions as unnumbered rows
          // with a null id. They are part of the text, not damage — but
          // they are not addressable, so they sit outside these checks.
          if (v['verse'] == 'title') continue;
          final id = v['id'] as String;
          final ok = id.length == 9 &&
              int.tryParse(id) != null &&
              int.parse(id.substring(3, 6)) == int.parse(v['chapter']) &&
              int.parse(id.substring(6)) == int.parse(v['verse'] as String);
          if (!ok) malformed.add('${appKey(v)} — $id');
          final prior = byId[id];
          if (prior != null) collisions.add('$id: $prior / ${appKey(v)}');
          byId[id] = appKey(v);
        }
        expect(malformed, isEmpty);
        expect(collisions, isEmpty);
      });

      test('one book uses one id prefix', () {
        final prefixes = <String, Set<String>>{};
        for (final v in verses) {
          if (v['verse'] == 'title') continue;
          (prefixes[v['book'] as String] ??= <String>{})
              .add((v['id'] as String).substring(0, 3));
        }
        expect(
          prefixes.entries.where((e) => e.value.length != 1).toList(),
          isEmpty,
        );
        expect(prefixes.values.expand((s) => s).toSet(), hasLength(66));
      });
    });
  }

  group('cross-version alignment', () {
    late Set<String> kjv;
    setUpAll(() => kjv = {for (final v in load('kjv')) appKey(v)});

    for (final version in versions) {
      test('$version differs from the KJV only where versification does',
          () {
        final here = {
          for (final v in load(version))
            if (v['verse'] != 'title') appKey(v)
        };
        expect(
          (kjv.difference(here)).toList()..sort(),
          equals(missingVsKjv[version]!.toList()..sort()),
        );
        expect(
          (here.difference(kjv)).toList()..sort(),
          equals(extraVsKjv[version]!.toList()..sort()),
        );
      });
    }
  });

  group('nothing is hidden behind a footnote icon', () {
    /// A verse whose whole text is `<note: …>` passes every check above
    /// — it is unique, non-empty on disk, and carries no stray
    /// character — and still shows the reader NOTHING. The reading pane
    /// renders a note as a tappable book icon, and every sanitised path
    /// (copy, share, search, the Originals sheet's verse line) drops it
    /// outright.
    ///
    /// The CUV sets whole verses in parentheses — 以賽亞書 23:13,
    /// 約書亞記 2:6 and 13 others are narrative asides — and our
    /// importer turned every parenthesis into a note, so those verses
    /// were blank on screen in both CUV editions.
    ///
    /// The seven below are not that. Each is a place where the edition
    /// ITSELF says the text is not there — 「有古卷在此有」, 「見下節」,
    /// 「並入上一節」 — and the independent Eagle's View import of the
    /// same edition agrees, bracketing exactly these seven `〔…〕` and
    /// the other fifteen `（…）`. Promoting one of these into the verse
    /// body would put a disputed reading on screen as scripture.
    const editorialOnly = <String>{
      'Psalms 63:6',
      'Mark 7:16',
      'Mark 9:44',
      'Mark 9:46',
      'John 7:53',
      'Acts 8:37',
      'Acts 15:34',
    };

    for (final version in versions) {
      test('$version shows text for every verse it lists', () {
        final blank = <String>[
          for (final v in load(version))
            if (sanitizeVerseText(v['text'] as String).isEmpty &&
                !editorialOnly.contains(appKey(v)))
              appKey(v)
        ];
        expect(blank, isEmpty);
      });
    }

    test('the fifteen parenthetical verses read as scripture again', () {
      String textOf(String version, String ref) => load(version)
          .firstWhere((v) => appKey(v) == ref)['text'] as String;

      // 麻秸 (flax stalks), not 麻: our asset had dropped the character
      // and both independent copies — the Eagle's View tagging and
      // SeekSparks' cuvs-plus — read 所擺的麻秸中.
      expect(sanitizeVerseText(textOf('cuvs-yhwh', 'Joshua 2:6')),
          contains('所摆的麻秸中'));
      expect(sanitizeVerseText(textOf('cuvs-yhwh-tr', 'Joshua 2:6')),
          contains('所擺的麻秸中'));
      expect(sanitizeVerseText(textOf('cuvs-yhwh', 'Isaiah 23:13')),
          startsWith('（看哪'));
      expect(sanitizeVerseText(textOf('cuvs-yhwh-tr', 'Jeremiah 48:10')),
          contains('懶惰為雅偉行事的'));
    });
  });

  test('the sixteen verses an importer damaged now read as scripture', () {
    // Each was settled against an independent import of the same
    // translation — SeekSparks' `kjvs.json` and `cuvs-plus.json`, both
    // from different sources than ours — and not by writing the verse.
    String textOf(String version, String ref) => load(version)
        .firstWhere((v) => appKey(v) == ref)['text'] as String;

    expect(textOf('kjv', 'Jeremiah 38:14'), contains('hide nothing from me.'));
    expect(textOf('kjv', 'Amos 9:6'), contains('he that calleth for'));
    expect(textOf('kjv', 'Psalms 90:3'), startsWith('Thou turnest man'));
    expect(textOf('kjv', '1 Corinthians 10:3'), startsWith('And did all eat'));

    expect(textOf('cuvs-yhwh', 'Deuteronomy 15:15'), endsWith('这件事。'));
    expect(textOf('cuvs-yhwh', 'Matthew 9:28'), contains('“主啊，我们信。”'));
    expect(textOf('cuvs-yhwh', 'Luke 24:34'), contains('主果然复活'));

    expect(textOf('cuvs-yhwh-tr', 'Deuteronomy 15:15'), endsWith('這件事。'));
    expect(textOf('cuvs-yhwh-tr', 'Matthew 9:28'), contains('「主啊，我們信。」'));
    expect(textOf('cuvs-yhwh-tr', 'Luke 24:34'), contains('主果然復活'));
  });
}
