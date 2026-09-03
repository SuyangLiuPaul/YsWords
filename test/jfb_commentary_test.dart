import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/services/commentary_service.dart';
import 'package:yswords/widgets/commentary_sheet.dart';

/// Guards the public-domain commentary import (JFB 1871, Gospel of Matthew).
///
/// Three separate things can go wrong here and each has cost this repo real
/// time before, on other assets:
///
/// 1. **A missing `pubspec.yaml` entry is silent.** `CommentaryService`
///    catches the load failure and caches null, so the Commentary button
///    would open an empty sheet forever with nothing in the logs. The load
///    here goes through `rootBundle`, not `File`, because that is the only
///    thing that actually proves the asset ships — a file can sit in the
///    repo and still not be bundled.
///
/// 2. **A commentary block shown against the wrong verse** is the same class
///    of defect as a citation opening the wrong chapter, which this repo has
///    fought repeatedly. JFB prints its own verse number at the head of most
///    comments ("**18. And I say also unto thee--**"), so the asset carries
///    an independent statement of where each block belongs, and this test
///    checks the number against the range the block is filed under. That is
///    not a restatement of how the file was built: the builder derives the
///    verse from the SWORD module's binary index, and the printed number
///    comes from the 1871 text.
///
/// 3. **Shipping a text we have no right to.** NASB and LEB are already
///    withheld from the web build pending publisher answers. The evidence
///    for this one is written down, and this test fails if that file goes
///    away or the About-page credit is deleted.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const assetPath = 'assets/commentary/jfb-matthew.json';

  // Pinned 2026-09-03, from the build of CrossWire SWORD module JFB 3.0
  // (archive SHA-256 3d767dbf...f6aa, see docs/jfb-commentary-licence.md).
  // These move only when the module is deliberately rebuilt.
  const expectedBytes = 538530;
  const expectedBlocks = 610;
  const matthewChapters = 28;
  const matthewVerses = 1071; // KJV versification, as assets/kjv.json holds it

  late Map<String, dynamic> data;
  late List<dynamic> entries;

  setUpAll(() async {
    final raw = await rootBundle.loadString(assetPath);
    data = jsonDecode(raw) as Map<String, dynamic>;
    entries = data['entries'] as List<dynamic>;
  });

  group('the asset ships and parses', () {
    test('$assetPath loads through rootBundle', () async {
      final raw = await rootBundle.loadString(assetPath);
      expect(raw.isNotEmpty, isTrue,
          reason: 'Loaded but empty — check the pubspec entry '
              '`- assets/commentary/` still exists.');
      expect(() => jsonDecode(raw), returnsNormally,
          reason: '$assetPath is not valid JSON.');
    });

    test('its size is pinned', () {
      final bytes = File(assetPath).lengthSync();
      expect(bytes, expectedBytes,
          reason: 'CHANGED: $assetPath is now $bytes bytes, was '
              '$expectedBytes. This app ships its assets, so a growing '
              'commentary corpus is a deliberate decision, not a drive-by. '
              'If you rebuilt the module on purpose, re-run '
              'tools/build_commentary_jfb.py, confirm its alignment '
              'checks all passed, and update this number.');
      expect(bytes, lessThan(2 * 1024 * 1024),
          reason: 'Commentary is over 2 MB. The queue item budgeted '
              '20-60 MB for a whole-Bible import with lazy per-book '
              'loading; one book blowing past 2 MB means the per-book '
              'split is not doing its job.');
    });

    test('coverage is pinned', () {
      expect(entries.length, expectedBlocks, reason: 'block count changed');
      expect(data['book'], 'Matthew');
      expect(data['chapters'], matthewChapters);
      expect(data['verses'], matthewVerses);
      expect(data['license'], 'Public Domain',
          reason: 'The asset must keep declaring its own licence.');
      expect(data['firstPublished'], 1871);
      expect((data['intro'] as String).length, greaterThan(5000),
          reason: 'The book introduction went missing.');
    });
  });

  group('verse-to-commentary alignment', () {
    test('every block that prints its own verse number agrees with the '
        'range it is filed under', () {
      final lead = RegExp(r'^\*\*(\d+)(?:\s*[-,]\s*(\d+))?\s*\.');
      final wrong = <String>[];
      var declaring = 0;
      for (final e in entries.cast<Map<String, dynamic>>()) {
        final m = lead.firstMatch(e['t'] as String);
        if (m == null) continue;
        declaring++;
        final printed = int.parse(m.group(1)!);
        final v = e['v'] as int, end = e['e'] as int;
        if (printed < v || printed > end) {
          wrong.add('Matt ${e['c']}:$v-$end holds a comment the 1871 text '
              'prints as verse $printed');
        }
      }
      expect(declaring, greaterThan(500),
          reason: 'Almost every JFB comment opens with its verse number. '
              'Only $declaring of ${entries.length} blocks do, which means '
              'the converter is dropping the bold lead-ins that make this '
              'check possible.');
      expect(wrong, isEmpty,
          reason: 'MISPLACED COMMENTARY — ${wrong.length} blocks:\n'
              '${wrong.take(10).join('\n')}');
    });

    test('blocks tile Matthew exactly — no gaps, no overlaps', () {
      final seen = <String>{};
      final overlaps = <String>[];
      for (final e in entries.cast<Map<String, dynamic>>()) {
        for (var v = e['v'] as int; v <= (e['e'] as int); v++) {
          final k = '${e['c']}:$v';
          if (!seen.add(k)) overlaps.add(k);
        }
      }
      expect(overlaps, isEmpty,
          reason: 'Two blocks claim the same verse: $overlaps. The sheet '
              'shows the first match, so one of them is unreachable.');
      expect(seen.length, matthewVerses,
          reason: 'Blocks cover ${seen.length} of $matthewVerses verses. '
              'Every verse must reach exactly one block — JFB is '
              'section-based, and a reader on 8:9 needs the "Mt 8:5-13" '
              'block, not silence.');
    });

    test('known verses land on the right commentary', () async {
      CommentaryService.resetForTest();
      final book = await CommentaryService.forBook('Matthew');
      expect(book, isNotNull, reason: 'Matthew failed to load.');

      // Each of these is a phrase the 1871 text prints on that verse and
      // nowhere near it, so a one-verse shift breaks them.
      const samples = <List<Object>>[
        // Not just "Blessed" — every beatitude comment says that, so it
        // survives a one-verse shift. This clause is unique to 5:3.
        [5, 3, 'Of the two words which our translators render'],
        [6, 9, 'After this manner'],
        [16, 18, 'That thou art Peter'],
        [28, 19, 'Go ye therefore'],
      ];
      for (final s in samples) {
        final c = s[0] as int, v = s[1] as int, phrase = s[2] as String;
        final block = book!.forVerse(c, v);
        expect(block, isNotNull, reason: 'No block covers Matt $c:$v.');
        expect(block!.text, contains(phrase),
            reason: 'Matt $c:$v resolved to a block that does not mention '
                '"$phrase". Its text starts: '
                '${block.text.substring(0, 90)}');
      }

      // Matthew 24 and 26 carry no verse-level JFB comment at all — the
      // commentary defers them to Mark. That is real coverage, stored in
      // the module's chapter-heading slot, and an earlier version of the
      // converter dropped all 126 verses of it on the floor.
      final deferred = book!.forVerse(24, 36);
      expect(deferred, isNotNull,
          reason: 'Matthew 24 lost its deferral note.');
      expect(deferred!.text, contains('Mr 13:1-37'),
          reason: 'Matt 24 should point the reader at Mark 13.');
      expect(deferred.verse, 1);
      expect(deferred.endVerse, 51);
    });

    test('a section block reports the range it really covers', () async {
      final book = await CommentaryService.forBook('Matthew');
      final block = book!.forVerse(8, 9);
      expect(block!.rangeLabel, '8:5-13',
          reason: 'The centurion pericope is one JFB section; the sheet '
              'header must say so rather than claiming 8:9.');
      expect(block.heading, contains('Centurion'));
    });
  });

  group('alignment across the other shipped editions', () {
    // The commentary is keyed to KJV versification, which is what
    // assets/kjv.json and assets/cuvs-yhwh.json hold (1,071 verses in
    // Matthew). NASB, LEB and biblexg-v2 hold 1,068 — they drop the three
    // bracketed verses 17:21, 18:11 and 23:14.
    //
    // That is only safe because they drop them WITHOUT renumbering: verse 21
    // is simply absent and verse 22 is still verse 22. If any of them ever
    // renumbered instead, every commentary block after the gap would be one
    // verse out in that edition — invisibly, because the text would still
    // look plausible. This test is the tripwire for that.
    test('editions that omit 17:21 / 18:11 / 23:14 leave a gap rather than '
        'renumbering', () {
      const omitted = {17: 21, 18: 11, 23: 14};
      const lastVerse = {17: 27, 18: 35, 23: 39};
      for (final version in const ['nasb', 'leb', 'biblexg-v2']) {
        final rows = jsonDecode(File('assets/$version.json').readAsStringSync())
            as List<dynamic>;
        for (final entry in omitted.entries) {
          final chapter = entry.key;
          final numbers = rows
              .cast<Map<String, dynamic>>()
              .where((r) =>
                  const {'Matthew', '马太福音', '馬太福音'}
                      .contains(r['book'] as String) &&
                  int.parse(r['chapter'] as String) == chapter)
              .map((r) => int.parse(r['verse'] as String))
              .toSet();
          expect(numbers.contains(entry.value), isFalse,
              reason: '$version unexpectedly has Matthew $chapter:'
                  '${entry.value}; the pinned expectation is that it omits '
                  'it.');
          expect(numbers.reduce((a, b) => a > b ? a : b), lastVerse[chapter],
              reason: 'RENUMBERED: $version Matthew $chapter now ends at a '
                  'different verse. The JFB commentary is keyed to KJV '
                  'versification, so a renumbering here silently shifts '
                  'every block after ${entry.value} by one verse for '
                  'readers of $version.');
        }
      }
    });
  });

  group('service behaviour', () {
    test('an unsupported book returns null rather than throwing', () async {
      CommentaryService.resetForTest();
      expect(await CommentaryService.forBook('Obadiah'), isNull);
      expect(CommentaryService.hasBook('Obadiah'), isFalse);
      expect(CommentaryService.hasBook('Matthew'), isTrue);
    });

    test('asset paths are derived, not hand-written', () {
      expect(CommentaryService.assetPathFor('Matthew'), assetPath);
      expect(CommentaryService.assetPathFor('1 Corinthians'),
          'assets/commentary/jfb-1_corinthians.json',
          reason: 'Two-word book names must match the slug convention '
              'the rest of the app uses (originals/, tagged/).');
    });

    test('the bold-run parser is the only markup the text needs', () {
      expect(CommentaryText.parse('**3. Blessed--**of the two words'), [
        (true, '3. Blessed--'),
        (false, 'of the two words'),
      ]);
      expect(CommentaryText.parse('plain'), [(false, 'plain')]);
      // An unmatched delimiter must degrade to text, not swallow the rest.
      expect(CommentaryText.parse('a **b'), [(false, 'a '), (true, 'b')]);
    });

    test('no commentary text carries leftover markup', () {
      final bad = <String>[];
      for (final e in entries.cast<Map<String, dynamic>>()) {
        final t = e['t'] as String;
        if (t.contains('<') && RegExp(r'<[a-zA-Z/]').hasMatch(t)) {
          bad.add('Matt ${e['c']}:${e['v']}');
        }
        if ('**'.allMatches(t).length.isOdd) {
          bad.add('Matt ${e['c']}:${e['v']} has an unmatched **');
        }
      }
      expect(bad, isEmpty,
          reason: 'OSIS tags or unbalanced bold markers survived the '
              'conversion: ${bad.take(10)}');
    });
  });

  group('the sheet renders', () {
    testWidgets('shows the block for the selected verse, its heading and '
        'the credit', (tester) async {
      CommentaryService.resetForTest();
      // Warm the cache under runAsync: the load is real bundle I/O, and
      // pumpAndSettle cannot settle against the spinner while it is in
      // flight (the progress indicator animates forever).
      await tester.runAsync(() => CommentaryService.forBook('Matthew'));
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: CommentarySheetBody(
            englishBook: 'Matthew',
            displayBook: '馬太福音',
            chapter: 8,
            verse: 9,
            locale: 'en',
            fontSize: 16,
          ),
        ),
      ));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Centurion'), findsWidgets,
          reason: 'The section heading for Matt 8:5-13 did not render.');
      expect(find.textContaining('馬太福音 8:9'), findsOneWidget,
          reason: 'The header must echo the verse the reader selected, in '
              'the book name they are reading.');
      expect(find.textContaining('Jamieson'), findsOneWidget,
          reason: 'The attribution line is not optional.');
      expect(find.textContaining('1871'), findsOneWidget);
    });

    testWidgets('says so plainly when a book has no module', (tester) async {
      CommentaryService.resetForTest();
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: CommentarySheetBody(
            englishBook: 'Obadiah',
            displayBook: 'Obadiah',
            chapter: 1,
            verse: 1,
            locale: 'en',
            fontSize: 16,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('No commentary'), findsOneWidget);
    });
  });

  group('licence evidence', () {
    test('docs/jfb-commentary-licence.md exists and still says what it '
        'claimed', () {
      final f = File('docs/jfb-commentary-licence.md');
      expect(f.existsSync(), isTrue,
          reason: 'The public-domain evidence for a whole text we '
              'redistribute is not optional. If this file is gone, the '
              'commentary asset should come out until it is restored.');
      final s = f.readAsStringSync();
      for (final claim in const [
        'DistributionLicense=Public Domain',
        '1871',
        '1910', // Fausset, the last of the three authors to die
        '3d767dbf8d89608dffdc94e1dbd629ce37ee5bb5072e61accf1cb7a106d1f6aa',
      ]) {
        expect(s, contains(claim),
            reason: 'The licence note no longer records "$claim".');
      }
    });

    test('the About page still credits the source', () {
      final about = File('lib/pages/about_page.dart').readAsStringSync();
      expect(about, contains('aboutLexJfb'),
          reason: 'The queue item asks for the credit on the About page '
              'even though the copyright has expired.');
      final strings =
          File('lib/constants/ui_strings.dart').readAsStringSync();
      for (final key in const [
        'aboutLexJfb',
        'aboutLicenseJfb',
        'commentary',
        'commentaryNone',
      ]) {
        expect(strings, contains("'$key'"),
            reason: 'ui_strings is missing $key.');
      }
      // Trilingual or it is not shipped — this app has no .arb fallback.
      final jfbLicence = RegExp(
        r"'aboutLicenseJfb':\s*\{(.*?)\n  \},",
        dotAll: true,
      ).firstMatch(strings);
      expect(jfbLicence, isNotNull);
      for (final locale in const ['zh-Hans', 'zh-Hant', 'en']) {
        expect(jfbLicence!.group(1), contains("'$locale'"),
            reason: 'aboutLicenseJfb has no $locale text.');
      }
    });
  });
}
