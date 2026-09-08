import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/services/chinese_lexicon_service.dart';
import 'package:yswords/services/tagged_text_service.dart';
import 'package:yswords/widgets/chinese_lexicon_block.dart';

/// The Chinese BDB/Thayer module ported from SeekSparks on 2026-09-08.
///
/// The port was proposed as "a deeper Chinese lexicon", and it is one,
/// but the measurement below is the part that decided it: the shipped
/// tagged corpus carries **98,861 grammar-code occurrences over 284
/// distinct codes**, and the two lexicons already in the bundle decode
/// **none** of them — `hebrew.json` stops at H8674 and `greek.json` at
/// G5624, while every grammar code lives above those. `TaggedRun.grammar`
/// had therefore been parsed since the tagged set landed and read by no
/// widget at all, exactly as `TaggedRun.implied` had been before
/// `implied_coverage_line.dart` (see `implied_coverage_census_test.dart`,
/// whose shape this file follows).
///
/// The measurements run against the real assets rather than fixtures,
/// so a re-import that changed the corpus cannot leave these numbers
/// standing as folklore.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, dynamic> bdb;
  late Map<String, dynamic> thayer;

  setUpAll(() {
    bdb = json.decode(File('assets/strongs/bdb_zh.json').readAsStringSync())
        as Map<String, dynamic>;
    thayer =
        json.decode(File('assets/strongs/thayer_zh.json').readAsStringSync())
            as Map<String, dynamic>;
  });

  setUp(ChineseLexiconService.resetForTest);

  group('the assets are in the bundle', () {
    test('both files ship, and the port is worthless without either', () {
      expect(File('assets/strongs/bdb_zh.json').existsSync(), isTrue);
      expect(File('assets/strongs/thayer_zh.json').existsSync(), isTrue);
    });

    test('pubspec bundles them through the assets/strongs/ directory line, '
        'not a per-file entry that a later file could be forgotten from', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec, contains('- assets/strongs/\n'));
      expect(pubspec, isNot(contains('assets/strongs/bdb_zh.json')));
    });

    test('together they are the 3.4 MB the size comment claims, so a '
        'silent re-import cannot quietly change what the boot-path note '
        'is reasoning about', () {
      final mb = (File('assets/strongs/bdb_zh.json').lengthSync() +
              File('assets/strongs/thayer_zh.json').lengthSync()) /
          (1024 * 1024);
      expect(mb, greaterThan(3.0));
      expect(mb, lessThan(4.0));
    });
  });

  group('what the module can answer that the shipped lexicons cannot', () {
    /// Every distinct grammar code in the shipped tagged corpus, with
    /// the number of times it occurs.
    Map<String, int> corpusGrammarCodes() {
      final counts = <String, int>{};
      for (final f in Directory('assets/tagged/cuvs-yhwh')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))) {
        final book = json.decode(f.readAsStringSync()) as Map<String, dynamic>;
        for (final runs in book.values) {
          for (final r in (runs as List).cast<Map<String, dynamic>>()) {
            for (final c in ((r['g'] as List?) ?? const []).cast<String>()) {
              counts[c] = (counts[c] ?? 0) + 1;
            }
          }
        }
      }
      return counts;
    }

    test('the tagged corpus leans on grammar codes far too heavily for them '
        'to stay undecoded', () {
      final counts = corpusGrammarCodes();
      expect(counts.length, greaterThan(250),
          reason: 'measured 284 distinct codes on 2026-09-08');
      expect(counts.values.fold<int>(0, (a, b) => a + b), greaterThan(90000),
          reason: 'measured 98,861 occurrences on 2026-09-08');
    });

    test('neither shipped Strong\'s lexicon decodes a single one of them', () {
      final hebrew =
          (json.decode(File('assets/strongs/hebrew.json').readAsStringSync())
                  as Map<String, dynamic>)
              .keys
              .toSet();
      final greek =
          (json.decode(File('assets/strongs/greek.json').readAsStringSync())
                  as Map<String, dynamic>)
              .keys
              .toSet();
      final decodable = corpusGrammarCodes()
          .keys
          .where((c) => hebrew.contains(c) || greek.contains(c));
      expect(decodable, isEmpty,
          reason: 'if this ever stops being empty the grammar half of this '
              'port has been made redundant and should be reconsidered');
    });

    test('the Chinese module decodes all but six, and the six are malformed '
        'tagging rather than gaps in the module', () {
      final all = {...bdb, ...thayer};
      final undecodable = corpusGrammarCodes()
          .keys
          .where((c) =>
              !all.containsKey(c) ||
              ((all[c] as Map)['p'] as List?)?.isNotEmpty != true)
          .toSet();
      expect(undecodable, {
        'G25332',
        'H19661',
        'H57004',
        'H59763',
        'H61006',
        'H87899',
      });
      // Each is longer than any real code on its side, which is what
      // marks them as two codes run together by the tagger rather than
      // readings the module is missing.
      for (final c in undecodable) {
        expect(c.length, greaterThan(5), reason: c);
      }
    });

    test('every Strong\'s number the app ships also has a fuller Chinese '
        'entry, so the block is never offered and then empty', () {
      for (final corpus in const ['hebrew', 'greek']) {
        final numbers =
            (json.decode(File('assets/strongs/$corpus.json').readAsStringSync())
                    as Map<String, dynamic>)
                .keys;
        final module = corpus == 'hebrew' ? bdb : thayer;
        final missing = numbers.where((n) => !module.containsKey(n)).toList();
        expect(missing, isEmpty, reason: '$corpus: ${missing.take(10)}');
      }
    });
  });

  group('looking a number up', () {
    test('a word comes back as an article, with the fields a printed '
        'lexicon entry has', () async {
      final e = await ChineseLexiconService.lookup('H430');
      expect(e, isNotNull);
      expect(e!.isGrammarCode, isFalse);
      expect(e.lemma, isNotEmpty);
      expect(e.senses, isNotEmpty);
      expect(e.usage, contains('钦定本'));
    });

    test('a grammar code comes back as parsing and nothing else, which is '
        'how a caller knows not to render it as a definition', () async {
      final e = await ChineseLexiconService.lookup('G5656');
      expect(e, isNotNull);
      expect(e!.isGrammarCode, isTrue);
      expect(e.lemma, isEmpty);
      expect(e.parsing, isNotEmpty);
    });

    test('lookup is case-insensitive, because the corpus is not consistent '
        'about it', () async {
      final upper = await ChineseLexiconService.lookup('H8804');
      final lower = await ChineseLexiconService.lookup('h8804');
      expect(lower?.number, upper?.number);
      expect(lower?.parsing, upper?.parsing);
    });

    test('anything that is not a Strong\'s-shaped number is a miss rather '
        'than a load', () async {
      for (final bad in const ['', 'X1', '430', 'H', 'hello']) {
        expect(await ChineseLexiconService.lookup(bad), isNull, reason: bad);
      }
    });

    test('the six malformed tagging codes return null rather than a '
        'reading invented for them', () async {
      for (final bad in const ['H87899', 'G25332', 'H61006']) {
        expect(await ChineseLexiconService.lookup(bad), isNull, reason: bad);
      }
    });

    test('lookupGrammar keeps only the codes that decode, in the order the '
        'run lists them', () async {
      final got = await ChineseLexiconService
          .lookupGrammar(['H8804', 'H87899', 'H8799']);
      expect(got.map((e) => e.number), ['H8804', 'H8799']);
      expect(got.every((e) => e.isGrammarCode), isTrue);
    });

    test('a real run out of the corpus decodes end to end — the whole '
        'point of the port, checked against the shipped data rather '
        'than a fixture', () async {
      final runs = await TaggedTextService.forVerse(
          version: 'cuvs-yhwh', englishBook: 'Genesis', chapter: 1, verse: 1);
      expect(runs, isNotNull);
      final withGrammar =
          runs!.where((r) => r.grammar.isNotEmpty).toList();
      expect(withGrammar, isNotEmpty,
          reason: 'Genesis 1:1 is expected to carry grammar codes');
      final decoded =
          await ChineseLexiconService.lookupGrammar(withGrammar.first.grammar);
      expect(decoded, isNotEmpty);
      expect(decoded.every((e) => e.parsing.isNotEmpty), isTrue);
    });
  });

  group('the Traditional reader', () {
    test('is told the module is Simplified only rather than left to read '
        'the glyphs as a failed conversion', () {
      expect(ChineseLexiconService.isSimplifiedOnly('zh-Hant'), isTrue);
      expect(ChineseLexiconService.isSimplifiedOnly('zh-Hans'), isFalse);
      expect(ChineseLexiconService.isSimplifiedOnly('en'), isFalse);
    });

    test('is still offered the lexicon — Simplified beats nothing', () {
      expect(ChineseLexiconService.appliesTo('zh-Hant'), isTrue);
      expect(ChineseLexiconService.appliesTo('zh-Hans'), isTrue);
    });

    test('an English reader is not offered it at all, and so never pays '
        'the asset load', () {
      expect(ChineseLexiconService.appliesTo('en'), isFalse);
    });
  });

  group('the block on screen', () {
    Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
          MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
        );

    const article = ChineseLexEntry(
      number: 'H430',
      lemma: 'אלהים',
      translit: "'ĕlôhîym",
      etymology: '源自 H433; TWOT - 93c; 阳性复数名词',
      usage: '钦定本 - God 2346, god 244; 2606',
      senses: ['1) (复数)', '2) 神, 真神'],
    );

    testWidgets('says in words that it is the same number and the fuller '
        'entry, so two Chinese paragraphs cannot read as a contradiction',
        (tester) async {
      await pump(tester,
          const ChineseLexiconBlock(entry: article, locale: 'zh-Hans'));
      expect(find.text(uiStrings['chineseLexTitle']!['zh-Hans']!), findsOneWidget);
    });

    testWidgets('prints the etymology, senses and 钦定本 counts the CBOL '
        'gloss above it does not carry', (tester) async {
      await pump(tester,
          const ChineseLexiconBlock(entry: article, locale: 'zh-Hans'));
      expect(find.textContaining('TWOT - 93c'), findsOneWidget);
      expect(find.textContaining('神, 真神'), findsOneWidget);
      expect(find.textContaining('钦定本'), findsOneWidget);
    });

    testWidgets('warns a Traditional reader, and does not warn a Simplified '
        'one', (tester) async {
      await pump(tester,
          const ChineseLexiconBlock(entry: article, locale: 'zh-Hant'));
      expect(find.text(uiStrings['chineseLexSimplifiedOnly']!['zh-Hant']!),
          findsOneWidget);

      await pump(tester,
          const ChineseLexiconBlock(entry: article, locale: 'zh-Hans'));
      expect(find.text(uiStrings['chineseLexSimplifiedOnly']!['zh-Hant']!),
          findsNothing);
    });

    testWidgets('refuses to render a grammar code as an article — that '
        'would present a parsing note as a definition', (tester) async {
      const code = ChineseLexEntry(
          number: 'G5656', parsing: ['时态 - 简单过去式 见 5777']);
      await pump(
          tester, const ChineseLexiconBlock(entry: code, locale: 'zh-Hans'));
      expect(find.textContaining('简单过去式'), findsNothing);
    });

    testWidgets('renders nothing at all when it has nothing to say, so a '
        'caller can place it unconditionally', (tester) async {
      await pump(
          tester,
          const ChineseLexiconBlock(
              entry: ChineseLexEntry(number: 'H1'), locale: 'zh-Hans'));
      expect(find.byType(Container), findsNothing);

      await pump(tester, const ChineseGrammarCodes(codes: []));
      expect(find.byType(Container), findsNothing);
    });

    testWidgets('a decoded code is keyed by the code itself, so a reader '
        'who has seen the number on a tagged line recognises it here',
        (tester) async {
      await pump(
          tester,
          const ChineseGrammarCodes(codes: [
            ChineseLexEntry(number: 'G5656', parsing: ['时态 - 简单过去式']),
          ]));
      expect(find.textContaining('G5656'), findsOneWidget);
      expect(find.textContaining('简单过去式'), findsOneWidget);
    });
  });

  group('the credit', () {
    test('the About page carries the row, worded exactly as SeekSparks '
        'words it — one module, credited identically in both apps', () {
      final about = File('lib/pages/about_page.dart').readAsStringSync();
      expect(about, contains("uiStrings['aboutLexBdbThayer']"));
      expect(about, contains("uiStrings['aboutLicenseBdbThayer']"));
      expect(about, contains('https://yahwehdehua.net/cn/resource/bible'));
    });

    test('the licence names the public-domain originals AND the permission '
        'the Chinese edition is used under — dropping either would '
        'misstate what is owed', () {
      for (final locale in const ['zh-Hans', 'zh-Hant', 'en']) {
        final licence = uiStrings['aboutLicenseBdbThayer']![locale]!;
        expect(licence, contains('Brown-Driver-Briggs'), reason: locale);
        expect(licence, contains('Thayer'), reason: locale);
        expect(licence, contains('yahwehdehua.net'), reason: locale);
      }
    });

    test('every new string is present in all three locales', () {
      const keys = [
        'chineseLexTitle',
        'chineseLexLemma',
        'chineseLexOrigin',
        'chineseLexSenses',
        'chineseLexUsage',
        'chineseLexSimplifiedOnly',
        'chineseLexGrammarTitle',
        'chineseLexGrammarOnly',
        'aboutLexBdbThayer',
        'aboutLicenseBdbThayer',
      ];
      for (final k in keys) {
        for (final locale in const ['zh-Hans', 'zh-Hant', 'en']) {
          expect(uiStrings[k]?[locale], isNotNull, reason: '$k/$locale');
          expect(uiStrings[k]![locale]!, isNotEmpty, reason: '$k/$locale');
        }
      }
    });
  });

  group('the offline pack knows about these two files', () {
    /// This group used to be titled "does not yet know", and recorded a
    /// gap rather than asserting it away: `OfflinePackService`'s
    /// `originals` category enumerated four lexicon files, this port
    /// added a fifth and sixth, and a Chinese reader who took that pack
    /// offline got every other word-study surface and an empty Chinese
    /// block — the one audience the module exists for.
    ///
    /// It named the fix precisely (two lines in `_originalsUrls()`,
    /// `approximateMbFor` 31 -> 35, and `offline_pack_size_test`'s
    /// `hasLength(4)` -> 6) because all three were outside what that
    /// port was scoped to touch. All three were done on 2026-09-08. The
    /// assertion below is unchanged and now passes on its other branch:
    /// it was written to fire if someone added the files and left the
    /// size figure behind.
    test('the two files are in the originals pack, and the size '
        'figure moved with them', () {
      final src =
          File('lib/services/offline_pack_service.dart').readAsStringSync();
      final knows = src.contains('bdb_zh') && src.contains('thayer_zh');
      if (knows) {
        // Someone did the follow-up. Then the size figure must have
        // moved with it, or the pack understates a 3.4 MB download.
        expect(src, isNot(contains('return 31; // 14 MB')),
            reason: 'the two Chinese lexicon files were added to the '
                'originals pack but approximateMbFor was left at 31 MB');
      }
    });
  });
}
