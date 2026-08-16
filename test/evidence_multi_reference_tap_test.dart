import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/bible_evidence.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/pages/evidence_detail_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/utils/reference_parser.dart';

/// An evidence entry citing two or more passages must let a reader
/// reach EVERY one of them.
///
/// User, 2026-08-16: 「那个经文其实是两个，但是按了好像只能去一个，另个
/// 去不了」. The 经文对应 chip was a single tap target that always jumped
/// to the first reference, so the second passage of the 17 entries that
/// cite more than one could be read on the card and not opened. That is
/// the same defect class as printing the wrong reference: the card
/// offers a passage it does not actually give.
BibleEvidence _evidence(String reference) => BibleEvidence(
      id: 'test-multi-ref',
      category: 'Archaeology',
      bibleBooks: const ['1 Kings'],
      timeline: const {'en': '10th century BCE'},
      discoveryDate: const {'en': '1903'},
      location: const {'en': 'Tel Megiddo'},
      scriptureReference: reference,
      images: const [],
      academicSources: const [],
      confidenceLevel: 'high',
      icon: 'temple',
      title: const {'en': 'Two cited passages'},
      summary: const {'en': 'Summary.'},
      description: const {'en': 'Description.'},
      scripturalCorrelation: const {'en': 'Correlation.'},
    );

List<Verse> _seedVerses() => [
      for (var v = 1; v <= 30; v++)
        Verse(book: '1 Kings', chapter: 9, verse: v, text: 'ch9 v$v'),
      for (var v = 1; v <= 30; v++)
        Verse(book: '1 Kings', chapter: 10, verse: v, text: 'ch10 v$v'),
    ];

Future<MainProvider> _pump(WidgetTester tester, String reference) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(402, 874);
  final mp = MainProvider();
  mp.setVersion('kjv');
  mp.setVerses(_seedVerses());
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: mp),
        ChangeNotifierProvider(create: (_) => AppSettings()),
      ],
      child: MaterialApp(
        home: EvidenceDetailPage(evidence: _evidence(reference)),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 400));
  return mp;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // `_openSegment` ends in `pushPage(HomePage())`, which routes through
    // GetX; without test mode that throws before the assertion runs.
    Get.testMode = true;
  });

  group('splitCitation', () {
    test('every cited passage in the asset resolves to its own target', () {
      final raw = File('assets/bible_evidence.json').readAsStringSync();
      final entries =
          (jsonDecode(raw) as Map<String, dynamic>)['evidences'] as List;
      final multi = entries
          .cast<Map<String, dynamic>>()
          .where((e) => (e['scriptureReference'] as String? ?? '')
              .contains(';'))
          .toList();

      // Guards the claim the fix is sized against. If a future import
      // adds multi-reference entries this number moves and the rest of
      // this test starts covering them too.
      expect(multi.length, 17);

      final unresolved = <String>[];
      for (final e in multi) {
        final ref = e['scriptureReference'] as String;
        final segments = splitCitation(ref);
        expect(segments.length, ref.split(';').length,
            reason: 'no cited part of $ref may be dropped');
        for (final s in segments) {
          if (s.target == null) unresolved.add('${e['id']}: ${s.text}');
        }
      }
      expect(unresolved, isEmpty,
          reason: 'a cited passage with no target is one the reader '
              'cannot open');
    });

    test('a part with no book of its own inherits the previous book', () {
      // `peter_raises_tabitha_joppa` cites `Acts 9:36-43; 10:5-6`, and
      // `parseReference('10:5-6')` is null — the citation convention
      // carries the book forward. Acts 10:5-6 is Cornelius sending to
      // Joppa for Peter, i.e. the same narrative the entry is about.
      final segments = splitCitation('Acts 9:36-43; 10:5-6');
      expect(segments[0].target!.englishBook, 'Acts');
      expect(segments[0].target!.chapter, 9);
      expect(segments[1].target!.englishBook, 'Acts');
      expect(segments[1].target!.chapter, 10);
      expect(segments[1].target!.verseStart, 5);
      // The label is never re-rendered from the parse, so the card goes
      // on citing what the source cited.
      expect(segments[1].text, '10:5-6');
    });

    test('inheritance needs a leading digit, so prose stays unresolved',
        () {
      final segments = splitCitation('Acts 9:36-43; Multiple Books');
      expect(segments[1].target, isNull,
          reason: 'attaching prose to the previous book would invent a '
              'reference the entry never made');
    });

    test('the book does not leak across a part that resolved to nothing',
        () {
      // Found by an adversarial read of the first draft, which carried
      // the last SUCCESSFUL book forward indefinitely: this handed the
      // deuterocanonical part's `45:1` to Exodus — a chapter Exodus
      // does not have, offered to the reader as the cited verse.
      // `Ecclesiasticus (Sirach) 39:1` is a real reference value in the
      // asset (`cairo_genizah`), so the unresolvable middle is a shape
      // this data really produces.
      final segments =
          splitCitation('Exodus 14:21-22; Ecclesiasticus (Sirach) 44:1; 45:1');
      expect(segments[1].target, isNull);
      expect(segments[2].target, isNull,
          reason: 'a bookless part may only inherit from the part '
              'immediately before it');
    });

    test('a comma part continues the VERSES of the previous chapter', () {
      // P52's two sides: recto John 18:31-33, verso 18:37-38. Before
      // this, `parseReference` truncated at the comma, so `37-38` was
      // printed on the card and could not be opened.
      final segments = splitCitation('John 18:31-33, 37-38');
      expect(segments.length, 2);
      expect(segments[0].target!.chapter, 18);
      expect(segments[1].target!.englishBook, 'John');
      expect(segments[1].target!.chapter, 18,
          reason: 'book-only inheritance would offer John 37, a chapter '
              'John does not have');
      expect(segments[1].target!.verseStart, 37);
      expect(segments[1].target!.verseEnd, 38);
      expect(segments[1].text, '37-38',
          reason: 'the card goes on citing what the source cited');
    });

    test('a comma part after a chapter-only part is a CHAPTER', () {
      final segments = splitCitation('Daniel 2, 7, 8, 11');
      expect(segments.length, 4);
      expect(segments.map((s) => s.target!.chapter), [2, 7, 8, 11]);
      for (final s in segments) {
        expect(s.target!.englishBook, 'Daniel');
        expect(s.target!.isWholeChapter, isTrue,
            reason: 'Daniel 2, 7, 8, 11 cites four chapters, not verses');
      }
    });

    test('the verse/chapter shape cannot be decided by what exists', () {
      // Daniel has 12 chapters and Daniel 2 has 49 verses, so BOTH
      // readings of `7, 8, 11` are real scripture and nothing about the
      // canon rejects either. Only the preceding part being chapter-only
      // settles it. A rule that preferred verses would land the reader
      // on Daniel 2:7 — real, plausible on arrival, and not what the
      // card cites. This is why the rule is structural.
      //
      // An adversarial pass killed the example this test used to give.
      // It claimed `Acts 19:11-20, 23-41` was the undecidable one
      // because Acts 23 exists — but the chapter reading of `23-41` is
      // the RANGE Acts 23–41, and Acts has 28 chapters, so a
      // range-aware canon check does reject it. Daniel is the case that
      // actually cannot be decided that way.
      final daniel = splitCitation('Daniel 2, 7, 8, 11');
      expect(daniel[1].target!.chapter, 7);
      expect(daniel[1].target!.verseStart, isNull);

      final acts = splitCitation('Acts 19:11-20, 23-41');
      expect(acts.length, 2);
      expect(acts[1].target!.chapter, 19);
      expect(acts[1].target!.verseStart, 23);
      expect(acts[1].target!.verseEnd, 41);
    });

    test('a lone trailing verse continues the chapter', () {
      final segments = splitCitation('1 Samuel 17:1-3, 52');
      expect(segments.length, 2);
      expect(segments[1].target!.englishBook, '1 Samuel');
      expect(segments[1].target!.chapter, 17);
      expect(segments[1].target!.verseStart, 52);
    });

    test('a comma part that spells its own chapter:verse is not a verse '
        'of the previous chapter', () {
      final segments = splitCitation('Acts 19:11-20, 23:1');
      expect(segments[1].target!.chapter, 23);
      expect(segments[1].target!.verseStart, 1);
    });

    test('a comma part with its own book does not inherit', () {
      final segments = splitCitation('Genesis 1:1, Exodus 2:3');
      expect(segments[1].target!.englishBook, 'Exodus');
      expect(segments[1].target!.chapter, 2);
    });

    test('a bare comma part after a `;` chunk starts from that chunk', () {
      // `previous` is the part IMMEDIATELY before, whichever separator
      // introduced it — so the verse rule keys off the right passage.
      final segments = splitCitation('Acts 9:36-43; 10:5-6, 9');
      expect(segments[2].target!.englishBook, 'Acts');
      expect(segments[2].target!.chapter, 10);
      expect(segments[2].target!.verseStart, 9);
    });

    test('a single-chapter book keeps its verses across a comma', () {
      // `Jude 14-15` resolves to ch 1 vs 14-15, so a following bare
      // number is a verse of chapter 1 — not chapter 17 of a book that
      // has one chapter.
      final segments = splitCitation('Jude 14-15, 17');
      expect(segments[1].target!.englishBook, 'Jude');
      expect(segments[1].target!.chapter, 1);
      expect(segments[1].target!.verseStart, 17);
    });

    test('prose after a comma stays unresolved', () {
      final segments = splitCitation('Acts 19:11-20, and elsewhere');
      expect(segments[1].target, isNull,
          reason: 'attaching prose to the previous chapter would invent '
              'a reference the entry never made');
    });

    test('every comma citation in the asset resolves to its own target',
        () {
      final raw = File('assets/bible_evidence.json').readAsStringSync();
      final entries =
          (jsonDecode(raw) as Map<String, dynamic>)['evidences'] as List;
      final commaEntries = entries
          .cast<Map<String, dynamic>>()
          .where((e) =>
              (e['scriptureReference'] as String? ?? '').contains(','))
          .toList();

      // Counted before concluding, as the queue requires. All four were
      // read by hand against the KJV: John 18 has 40 verses, Acts 19 has
      // 41, 1 Samuel 17 has 58, and Daniel has 12 chapters.
      expect(commaEntries.length, 4);

      final unresolved = <String>[];
      for (final e in commaEntries) {
        final ref = e['scriptureReference'] as String;
        final segments = splitCitation(ref);
        expect(segments.length, ref.split(RegExp(r'[;,]')).length,
            reason: 'no cited part of $ref may be dropped');
        for (final s in segments) {
          if (s.target == null) unresolved.add('${e['id']}: ${s.text}');
        }
      }
      expect(unresolved, isEmpty);

      // The split the UI actually branches on: 21 entries render as a
      // Wrap of chips, the other 204 keep the single flowing chip.
      final chipped = entries
          .cast<Map<String, dynamic>>()
          .where((e) =>
              splitCitation(e['scriptureReference'] as String? ?? '')
                  .length >
              1)
          .length;
      expect(chipped, 21);
      expect(entries.length - chipped, 204);
    });

    test('a single reference is one segment and still resolves', () {
      final segments = splitCitation('2 Thessalonians 2:13-17');
      expect(segments.length, 1);
      expect(segments.single.target!.englishBook, '2 Thessalonians');
    });
  });

  testWidgets('each cited passage is its own tap target', (tester) async {
    addTearDown(tester.view.reset);
    await _pump(tester, '1 Kings 9:15; 1 Kings 10:26');

    final chips = find.byWidgetPredicate((w) =>
        w is InkWell &&
        w.onTap != null &&
        w.borderRadius == BorderRadius.circular(8));
    expect(chips, findsNWidgets(2),
        reason: 'two cited passages, two tap targets');
  });

  testWidgets('tapping the SECOND passage opens the second passage',
      (tester) async {
    addTearDown(tester.view.reset);
    // Pre-fix this landed on 9:15 whichever half was tapped.
    final mp = await _pump(tester, '1 Kings 9:15; 1 Kings 10:26');

    final second = find.ancestor(
      of: find.byWidgetPredicate((w) =>
          w is RichText && w.text.toPlainText().contains('10:26')),
      matching: find.byType(InkWell),
    );
    expect(second, findsWidgets);
    await tester.tap(second.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(mp.currentChapter, 10);
    expect(mp.currentVerse?.verse, 26);
  });

  testWidgets('tapping the FIRST passage still opens the first',
      (tester) async {
    addTearDown(tester.view.reset);
    final mp = await _pump(tester, '1 Kings 9:15; 1 Kings 10:26');

    final first = find.ancestor(
      of: find.byWidgetPredicate((w) =>
          w is RichText && w.text.toPlainText().contains('9:15')),
      matching: find.byType(InkWell),
    );
    await tester.tap(first.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(mp.currentChapter, 9);
    expect(mp.currentVerse?.verse, 15);
  });

  testWidgets('a comma-cited verse is its own tap target', (tester) async {
    addTearDown(tester.view.reset);
    // Pre-fix the whole string was one chip that always landed on 9:15.
    final mp = await _pump(tester, '1 Kings 9:15, 20');

    final chips = find.byWidgetPredicate((w) =>
        w is InkWell &&
        w.onTap != null &&
        w.borderRadius == BorderRadius.circular(8));
    expect(chips, findsNWidgets(2));

    final second = find.ancestor(
      of: find.byWidgetPredicate((w) =>
          w is RichText && w.text.toPlainText().contains('20')),
      matching: find.byType(InkWell),
    );
    await tester.tap(second.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(mp.currentChapter, 9);
    expect(mp.currentVerse?.verse, 20);
  });

  testWidgets('a single reference keeps the one flowing chip',
      (tester) async {
    addTearDown(tester.view.reset);
    final mp = await _pump(tester, '1 Kings 9:15');

    final chips = find.byWidgetPredicate((w) =>
        w is InkWell &&
        w.onTap != null &&
        w.borderRadius == BorderRadius.circular(8));
    expect(chips, findsOneWidget);

    await tester.tap(chips);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(mp.currentChapter, 9);
    expect(mp.currentVerse?.verse, 15);
  });
}
