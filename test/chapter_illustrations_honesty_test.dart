import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/bible_map.dart';
import 'package:yswords/services/map_service.dart';
import 'package:yswords/widgets/bible_reading_pane.dart';

/// Regression tests for the illustration sheet's "For this chapter"
/// tab.
///
/// Before 2026-09-05 the tab rendered every index entry whose range
/// covered the chapter, and the 55 bundled survey maps carry
/// whole-book ranges ("Jerusalem — Old City" is tagged `Psalms:
/// [1, 150]`). Measured over the real index: 5899 of 7602
/// (chapter, image) display pairs — 77.6% — came from ranges wider
/// than 3 chapters, 5843 of them from those 55 maps. The tab was
/// non-empty for all 1189 chapters, so the sheet's own "no
/// illustration for this chapter" strings were unreachable and the
/// count badge always advertised artwork that did not exist.
///
/// These tests run the REAL classification over the REAL bundled
/// index, so a future change that either re-inflates the chapter tab
/// or loses an entry from both tabs fails CI.
void main() {
  late List<BibleMap> all;
  late Map<String, int> chapterCount;

  /// Every index entry whose range covers (book, chapter) — i.e. what
  /// `MapService.mapsForBookChapter` returns.
  List<BibleMap> rawChapterMatches(String book, int chapter) =>
      all.where((m) => m.matchesBookChapter(book, chapter)).toList();

  /// What `MapService.mapsForBook` returns.
  List<BibleMap> rawBookMatches(String book) =>
      all.where((m) => m.books.containsKey(book)).toList();

  ChapterIllustrations split(String book, int chapter) =>
      MapService.partition(
        chapterMatches: rawChapterMatches(book, chapter),
        bookMatches: rawBookMatches(book),
      );

  setUpAll(() {
    final raw = File('assets/maps_index.json').readAsStringSync();
    final decoded = json.decode(raw);
    final list = decoded is Map<String, dynamic>
        ? (decoded['maps'] as List<dynamic>? ?? const [])
        : decoded as List<dynamic>;
    all = list
        .whereType<Map<String, dynamic>>()
        .map(BibleMap.fromJson)
        .toList();

    // Canonical chapter counts, derived from the bundled KJV rather
    // than hard-coded, so the sweep below covers the real canon.
    chapterCount = <String, int>{};
    final kjv = json.decode(File('assets/kjv.json').readAsStringSync())
        as List<dynamic>;
    for (final v in kjv.whereType<Map<String, dynamic>>()) {
      final b = v['book'] as String;
      final c = int.parse(v['chapter'] as String);
      final cur = chapterCount[b] ?? 0;
      if (c > cur) chapterCount[b] = c;
    }
  });

  test('sanity: the real index and the real canon loaded', () {
    expect(all.length, greaterThan(1000));
    expect(chapterCount.length, 66);
    expect(chapterCount.values.fold<int>(0, (a, b) => a + b), 1189);
  });

  group('chapters with no artwork of their own show the honest state', () {
    // Confirmed bare chapters: didactic / legal / wisdom text with no
    // narrative scene tagged to them. Each was previously offered
    // nothing but whole-book survey maps.
    const bare = <List<Object>>[
      ['Ezekiel', 18], // individual moral responsibility, no geography
      ['Proverbs', 15],
      ['Deuteronomy', 22], // civil ordinances — five route maps before
      ['Ecclesiastes', 3],
    ];

    for (final c in bare) {
      final book = c[0] as String;
      final chapter = c[1] as int;
      test('$book $chapter', () {
        final s = split(book, chapter);

        // The old behaviour: the raw match list was never empty, which
        // is exactly why the empty state was dead code.
        expect(rawChapterMatches(book, chapter), isNotEmpty,
            reason: 'precondition: this chapter DID match survey maps');

        // The new behaviour: the chapter tab is honestly empty, and
        // the book tab carries the fallback note.
        expect(s.chapterTabIsEmpty, isTrue,
            reason: 'chapter tab must be empty for $book $chapter, got '
                '${s.chapter.map((m) => m.id).toList()}');
        expect(s.showsFallbackNote, isTrue,
            reason: 'the "here are related ones" note must render');
        expect(s.book, isNotEmpty);
      });
    }

    test('Ezekiel 18 kept exactly its two survey maps in the book tab', () {
      final s = split('Ezekiel', 18);
      final ids = s.book.map((m) => m.id).toSet();
      expect(ids, containsAll(<String>{
        'babylonian_empire',
        'pef_old_testament_survey',
      }));
    });
  });

  test('Psalms 119 keeps its one real illustration, loses the street plan',
      () {
    // NOT a bare chapter: Sweet Publishing has a Psalms 119 plate
    // tagged `Psalms: [119, 119]`. What it must lose is the Old City
    // map, which is tagged `Psalms: [1, 150]`.
    final s = split('Psalms', 119);
    expect(s.chapter.map((m) => m.id).toList(),
        <String>['illus_sweet_psalms_119_1']);
    expect(s.chapter.any((m) => m.id == 'jerusalem_old_city'), isFalse,
        reason: 'a street plan of the Old City is not a Psalm 119 '
            'illustration');
    expect(s.book.any((m) => m.id == 'jerusalem_old_city'), isTrue,
        reason: 'but it must still be reachable from the book tab');
  });

  group('chapters with real artwork still show it', () {
    const withArt = <List<Object>>[
      ['Genesis', 1, 8], // Doré + 6 Schnorr + Tissot creation plates
      // 14 and 5 here were measured BEFORE the Tissot min/max collapse
      // was fixed. That fix removed exactly one bogus entry from each:
      // John 11 lost `illus_tissot_saint_philip` (catalogued John 1 and
      // John 14, min/max'd into 1-14) and Matthew 5 lost
      // `illus_tissot_saint_peter` (Matthew 4 and 16, min/max'd into
      // 4-16). Both were portraits of an apostle offered as the
      // illustration for a chapter he has nothing to do with, so the
      // count going down by one is the fix working, not a regression.
      ['John', 11, 13], // the raising of Lazarus
      ['Matthew', 5, 4], // Sermon on the Mount
    ];
    for (final c in withArt) {
      final book = c[0] as String;
      final chapter = c[1] as int;
      final count = c[2] as int;
      test('$book $chapter shows $count', () {
        final s = split(book, chapter);
        expect(s.chapter.length, count);
        expect(s.chapterTabIsEmpty, isFalse);
        expect(s.showsFallbackNote, isFalse);
      });
    }

    test('Genesis 1 keeps the named creation plates', () {
      final ids = split('Genesis', 1).chapter.map((m) => m.id).toSet();
      expect(ids, containsAll(<String>{
        'illus_dore_001thecreationofligh',
        'illus_schnorr_001_creation_of_light',
        'illus_tissot_tissot_the_creation',
      }));
    });
  });

  test('no survey map ever reaches the chapter tab, anywhere in the canon',
      () {
    final offenders = <String>[];
    chapterCount.forEach((book, n) {
      for (var ch = 1; ch <= n; ch++) {
        for (final m in split(book, ch).chapter) {
          if (m.kind == 'map') offenders.add('$book $ch → ${m.id}');
        }
      }
    });
    expect(offenders, isEmpty,
        reason: 'survey maps leaked into "For this chapter": '
            '${offenders.take(5).toList()}');
  });

  test('nothing vanishes and nothing is listed twice', () {
    // For every chapter in the canon: every entry that the old,
    // blunt matcher would have surfaced is still reachable from one
    // of the two tabs, and from exactly one of them.
    final lost = <String>[];
    final duped = <String>[];
    chapterCount.forEach((book, n) {
      for (var ch = 1; ch <= n; ch++) {
        final s = split(book, ch);
        final inChapter = s.chapter.map((m) => m.id).toSet();
        final inBook = s.book.map((m) => m.id).toSet();
        for (final m in rawChapterMatches(book, ch)) {
          final a = inChapter.contains(m.id);
          final b = inBook.contains(m.id);
          if (!a && !b) lost.add('$book $ch → ${m.id}');
          if (a && b) duped.add('$book $ch → ${m.id}');
        }
      }
    });
    expect(lost, isEmpty,
        reason: 'entries dropped from BOTH tabs: ${lost.take(5).toList()}');
    expect(duped, isEmpty,
        reason: 'entries listed in BOTH tabs: ${duped.take(5).toList()}');
  });

  test('every index entry is reachable from at least one tab', () {
    final reachable = <String>{};
    chapterCount.forEach((book, n) {
      for (var ch = 1; ch <= n; ch++) {
        final s = split(book, ch);
        reachable.addAll(s.chapter.map((m) => m.id));
        reachable.addAll(s.book.map((m) => m.id));
      }
    });
    final unreachable = [
      for (final m in all)
        if (!reachable.contains(m.id) &&
            m.books.keys.any(chapterCount.containsKey))
          m.id,
    ];
    expect(unreachable, isEmpty,
        reason: 'index entries no tab can show: '
            '${unreachable.take(5).toList()}');
  });

  test('honest coverage: 361 of 1189 chapters have real chapter artwork',
      () {
    var withArt = 0;
    var total = 0;
    chapterCount.forEach((book, n) {
      for (var ch = 1; ch <= n; ch++) {
        total++;
        if (!split(book, ch).chapterTabIsEmpty) withArt++;
      }
    });
    expect(total, 1189);
    expect(withArt, 361,
        reason: 'chapter-artwork coverage changed — if this is a real '
            'index addition, update the number; if not, the '
            'classification drifted');
  });

  test('range width alone would demote real paintings — hence `kind`', () {
    // The justification for MapService.isChapterIllustration using
    // `kind` rather than the range width, pinned so nobody "simplifies"
    // it into a width threshold later.
    final wideRealArt = <String>[];
    for (final m in all) {
      if (!MapService.isChapterIllustration(m)) continue;
      // `books` values became a LIST of ranges when the Tissot
      // min/max collapse was fixed, so a book can now carry several
      // disjoint spans. Width is per range: an entry covering John
      // 1 and John 14 is two width-1 spans, not one span of 14.
      for (final MapEntry<String, List<List<int>>> e in m.books.entries) {
        for (final List<int> r in e.value) {
          final int width = r.length == 1 ? 1 : (r[1] - r[0] + 1);
          if (width > 3) wideRealArt.add('${m.id} ${e.key} $r');
        }
      }
    }
    // Was 6 when this test was written, against the index BEFORE the
    // Tissot min/max collapse was fixed. Four of that six were the
    // bogus spans (Philip, Peter, Thomas, John the Evangelist) and the
    // fix split them into discrete ranges, so they are correctly no
    // longer wide. The two that remain are the Farewell Discourse
    // teachings, which genuinely do run John 13-17 — which makes the
    // point of this test better, not worse: a width threshold would
    // demote a real five-chapter discourse.
    expect(wideRealArt.length, 2,
        reason: 'genuine paintings with book-ranges wider than 3 chapters: '
            '$wideRealArt');
  });

  test('the two revived strings are localised in all three languages', () {
    for (final key in const ['noMapsForChapter',
        'mapsNoneForChapterFallback', 'mapsForThisChapter']) {
      for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
        final v = uiStrings[key]?[locale];
        expect(v, isNotNull, reason: '$key/$locale missing');
        expect(v!.trim(), isNotEmpty, reason: '$key/$locale blank');
      }
    }
  });

  group('the sheet actually renders both revived strings', () {
    // These used to be `expect(sourceFile, contains("..."))` assertions
    // over `bible_reading_pane.dart`'s own text. That guard did not
    // work: on 2026-09-06 the original dead-code bug was reintroduced —
    // `if (widget.chapterMaps.isEmpty) { } else { tabs.add(chapter) }`,
    // which drops the tab and makes `noMapsForChapter` unreachable
    // again — and all 18 tests in this file stayed green. The negative
    // assertion pinned one exact multi-line spelling of the old code
    // (down to its six-space indent) and the buggy rewrite is not that
    // spelling; the positive `contains("if (widget.chapterMaps.isEmpty)")`
    // was satisfied by the bug itself, and would anyway have been
    // satisfied by the fallback-note gate 100 lines further down.
    //
    // Rendering the widget is the assertion that cannot be fooled by a
    // rewrite: pump the sheet with a list and read what the user sees.
    const en = 'en';

    BibleMap plate(String id) => BibleMap(
          id: id,
          title: const {'en': 'A plate'},
          description: const {},
          books: const {'Genesis': [[1, 1]]},
          file: '$id.jpg',
          kind: 'scene',
          source: 'cdn',
        );

    Future<void> pump(
      WidgetTester tester, {
      required List<BibleMap> chapterMaps,
      required List<BibleMap> bookMaps,
    }) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MapPickerSheet(
            chapterMaps: chapterMaps,
            bookMaps: bookMaps,
            locale: en,
            version: 'kjv',
          ),
        ),
      ));
      await tester.pump();
    }

    String s(String key) => uiStrings[key]![en]!;

    testWidgets('the chapter tab is present, and says so, when empty',
        (tester) async {
      await pump(tester, chapterMaps: const [], bookMaps: [plate('a')]);

      // The tab itself must not silently disappear — this is the
      // assertion the reintroduced bug fails.
      expect(find.text(s('mapsForThisChapter')), findsOneWidget,
          reason: 'the "For this chapter" tab must be offered even when '
              'the chapter has no artwork; dropping it is the bug that '
              'made the empty state dead code');

      // initState opens on the book tab when there is no chapter
      // artwork, so the fallback note is what shows first.
      expect(find.text(s('mapsNoneForChapterFallback')), findsOneWidget,
          reason: 'the book tab must explain why it is being shown');

      // Switch to the chapter tab and read the empty state.
      await tester.tap(find.text(s('mapsForThisChapter')));
      await tester.pumpAndSettle();
      expect(find.text(s('noMapsForChapter')), findsOneWidget,
          reason: 'the empty chapter tab must give the honest answer');
    });

    testWidgets('neither string renders when the chapter has artwork',
        (tester) async {
      await pump(tester,
          chapterMaps: [plate('a')], bookMaps: [plate('b')]);

      expect(find.text(s('mapsForThisChapter')), findsOneWidget);
      expect(find.text(s('noMapsForChapter')), findsNothing,
          reason: 'the chapter tab has a plate — do not claim it is empty');
      expect(find.text(s('mapsNoneForChapterFallback')), findsNothing,
          reason: 'the fallback note is gated on an EMPTY chapter list');
    });

    testWidgets('with no book artwork either, the chapter tab still stands',
        (tester) async {
      // The book tab is the one that is conditional. With both lists
      // empty there is no book tab to fall back to, so the chapter tab
      // is the only thing standing between the user and a sheet that
      // says nothing at all.
      await pump(tester, chapterMaps: const [], bookMaps: const []);
      expect(find.text(s('mapsForThisChapter')), findsOneWidget);
      expect(find.text(s('mapsForThisBook')), findsNothing);
      expect(find.text(s('noMapsForChapter')), findsOneWidget);
    });
  });

  test('the pane builds its two lists through the classifier', () {
    // Not a behaviour of the sheet — the sheet is handed two lists. The
    // split happens in the pane's state, and there is no seam to pump.
    final src =
        File('lib/widgets/bible_reading_pane.dart').readAsStringSync();
    expect(src, contains('MapService.partition('));
  });
}
