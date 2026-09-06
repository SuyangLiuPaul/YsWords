import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/constants/sermon_credit.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/pages/sermon_library_page.dart';
import 'package:yswords/pages/sermon_library_sermon_page.dart';
import 'package:yswords/pages/sermon_library_speaker_page.dart';
import 'package:yswords/services/sermon_library_service.dart';

/// The three screens of the 福音电台 library, mounted against the real
/// 940-record corpus.
///
/// **These are written against a specific way of lying.** Ten tests in
/// this codebase were found passing while the thing they claimed to
/// test was deliberately broken. Two mechanisms did it: rows sitting
/// inside a collapsed `ExpansionTile`, which the framework never
/// builds, so `find` matched nothing whatever was inserted; and a page
/// still showing its spinner at the moment of the assertion, because
/// the service behind it did not cache and the future never resolved
/// inside `pump`.
///
/// Both are answered here rather than hoped away. The first by
/// construction — this feature uses `ListView.builder`, and the first
/// assertion below is that a speaker row is on screen with no
/// expansion needed. The second by warming the service inside
/// `runAsync` (the only place a widget test may do real I/O) so the
/// memoised future resolves on a microtask `pump` can flush, and then
/// by asserting on real corpus content, which a spinner cannot
/// produce.
void main() {
  final svc = SermonLibraryService.instance;
  final hasCorpus =
      File('${SermonLibraryService.libraryRoot}/index.json').existsSync();
  const corpusSkipReason =
      'assets/sermon_library/ is deliberately untracked (see .gitignore) — '
      'run scripts/sync_sermon_library.py to regenerate it locally. On a '
      'fresh clone this whole file SKIPS, mirroring '
      "test_sermon_library.py's TestSnapshot.";

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // `assets/sermon_library/` is gitignored and not declared in
    // `pubspec.yaml`, so `rootBundle` cannot reach it. Reading it off
    // disk is the same substitution the app would make to fetch the
    // corpus over HTTP.
    // readAsStringSync, deliberately. A `Future` completed inside
    // `tester.runAsync` belongs to that zone, and the microtask it
    // schedules for a `FutureBuilder`'s listener is never drained by
    // `pump` — so the page sits on its spinner and every assertion
    // measures a `CircularProgressIndicator`. Observed here before
    // this line was written, and it is one of the two mechanisms
    // behind the ten decorative tests. A synchronous read keeps the
    // whole load on microtasks in the TEST zone, which `pump` does
    // drain, so nothing below needs `runAsync` at all.
    svc.useLoader((p) async =>
        File('${SermonLibraryService.libraryRoot}/$p').readAsStringSync());
  });

  tearDown(() {
    svc.resetForTest();
    Get.reset();
  });

  Future<void> mount(WidgetTester tester, Widget page,
      {String locale = 'zh-Hans'}) async {
    final settings = AppSettings();
    await settings.setLocale(locale);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppSettings>.value(
        value: settings,
        child: GetMaterialApp(home: page),
      ),
    );
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  // ── The index ──────────────────────────────────────────────────

  group('speaker index', skip: hasCorpus ? null : corpusSkipReason, () {
    testWidgets('rows are BUILT — no expansion, no spinner', (tester) async {
      await mount(tester, const SermonLibraryPage());
      expect(find.byType(CircularProgressIndicator), findsNothing,
          reason: 'an assertion made over a spinner is worthless');
      // The top speaker by count, on screen, with nothing tapped.
      expect(find.text('张成牧师'), findsOneWidget);
      expect(find.text('小珊姊妹'), findsOneWidget);
    });

    test('and the row order is the count order, derived', () async {
      final lib = await svc.load();
      expect(lib.speakers.first.name, '张成牧师');
      expect(lib.speakers.first.count, 201);
      expect(lib.speakers[1].count, 198);
    });

    testWidgets('each row carries its own count', (tester) async {
      await mount(tester, const SermonLibraryPage());
      // 201 is the head of the distribution; it is the fact the reader
      // is choosing on, so it is on the row rather than in the header.
      expect(find.text('201 篇'), findsOneWidget);
    });

    testWidgets('the corpus summary is derived from what loaded',
        (tester) async {
      await mount(tester, const SermonLibraryPage());
      final lib = await svc.load();
      expect(
        find.text('${lib.speakers.length} 位讲员 · ${lib.sermons.length} 篇讲道'),
        findsOneWidget,
      );
      // …and it is really 71 and 937, so the assertion above is not
      // just comparing the page to itself.
      expect(lib.speakers.length, 71);
      expect(lib.sermons.length, 937);
    });

    testWidgets('the language notice appears once, not per row',
        (tester) async {
      await mount(tester, const SermonLibraryPage());
      expect(find.text(uiStrings['sermonLibraryChineseOnly']!['zh-Hans']!),
          findsOneWidget);
    });

    testWidgets('the one programme is labelled, and it is the only one',
        (tester) async {
      await mount(tester, const SermonLibraryPage());
      // '奇妙', not the full name — typing the whole name into the
      // search box puts the string in the EditableText too, and
      // `find.text` would match the box as well as the row.
      await tester.enterText(find.byType(TextField), '奇妙');
      await tester.pump();
      expect(find.text('奇妙恩典'), findsOneWidget);
      expect(find.text(uiStrings['sermonLibraryProgramme']!['zh-Hans']!),
          findsOneWidget);
      // Clear the filter: still exactly one programme label in 71 rows
      // that the list has built so far.
      await tester.enterText(find.byType(TextField), '牧师');
      await tester.pump();
      expect(find.text(uiStrings['sermonLibraryProgramme']!['zh-Hans']!),
          findsNothing);
    });

    testWidgets('an English reader sees English chrome and Chinese names',
        (tester) async {
      await mount(tester, const SermonLibraryPage(), locale: 'en');
      expect(
        find.text('These sermons are in Chinese. No English text exists.'),
        findsOneWidget,
      );
      // Verbatim, not romanised: there is no English form of this name
      // and inventing one is the same error as a plausible link.
      expect(find.text('小珊姊妹'), findsOneWidget);
      expect(find.text('201 sermons'), findsOneWidget);
    });

    testWidgets('the app-corpus preacher is spelled the way the app '
        'already spells him', (tester) async {
      await mount(tester, const SermonLibraryPage(), locale: 'zh-Hant');
      // Every other name renders Simplified — there is no Traditional
      // edition of this corpus and nothing converts at runtime. This
      // one name is different because its Traditional spelling is
      // already owner-ruled and shipped in `sermon_credit.dart`, and
      // the Sermons page two taps away prints it.
      expect(find.text(sermonPreacher('zh-Hant')), findsOneWidget);
      expect(find.text('張成牧師'), findsNothing);
      expect(find.text('张成牧师'), findsOneWidget);
    });

    testWidgets('a search that matches nobody says so', (tester) async {
      await mount(tester, const SermonLibraryPage());
      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pump();
      expect(find.text(uiStrings['sermonLibraryNoSpeakers']!['zh-Hans']!),
          findsOneWidget);
    });
  });

  // ── One speaker ────────────────────────────────────────────────

  group('a speaker\'s sermons', skip: hasCorpus ? null : corpusSkipReason,
      () {
    testWidgets('the name is in the AppBar and on none of the rows',
        (tester) async {
      await mount(tester, const SermonLibrarySpeakerPage(speakerKey: '辛岚'));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('辛岚'), findsOneWidget,
          reason: 'constant down every row, so it belongs in the header '
              'exactly once — repeating it 76 times would be an advert');
      // Real rows, built.
      expect(find.text('76 篇'), findsOneWidget);
    });

    testWidgets('the date is labelled published, never bare',
        (tester) async {
      await mount(tester, const SermonLibrarySpeakerPage(speakerKey: '辛岚'));
      final lib = await svc.load();
      final newest = lib.speakerByKey('辛岚')!.sermons.first;
      expect(newest.publishedAt, isNotNull);
      expect(find.text('发布于 ${newest.displayDate}'), findsOneWidget,
          reason: 'these are WordPress publication dates and the app\'s '
              'other sermon list prints PREACHING dates in the same slot');
    });

    testWidgets('the undated record shows no date at all', (tester) async {
      // 约书亚(2), the year-214 record, is 辛岚's. Sorted last, and
      // rendered with no date line rather than a wrong one.
      await mount(tester, const SermonLibrarySpeakerPage(speakerKey: '辛岚'));
      final lib = await svc.load();
      expect(lib.speakerByKey('辛岚')!.sermons.last.id, 2967);
      expect(find.textContaining('0214'), findsNothing);
      expect(find.textContaining('214-'), findsNothing);
    });

    testWidgets('the station page says how many named nobody upstream',
        (tester) async {
      await mount(
          tester, const SermonLibrarySpeakerPage(speakerKey: '福音电台'));
      final lib = await svc.load();
      final speaker = lib.speakerByKey('福音电台')!;
      expect(speaker.count, 28);
      expect(speaker.unattributedCount, 27);
      expect(find.text('其中 27 篇上游未署讲员，按版权说明归于本台。'),
          findsOneWidget);
    });

    testWidgets('a speaker page for nobody says so instead of pretending',
        (tester) async {
      await mount(tester,
          const SermonLibrarySpeakerPage(speakerKey: '没有这个人'));
      expect(find.text(uiStrings['sermonNotFound']!['zh-Hans']!),
          findsOneWidget);
    });
  });

  // ── One sermon ─────────────────────────────────────────────────

  group('one sermon', skip: hasCorpus ? null : corpusSkipReason, () {
    testWidgets('the body keeps every paragraph break the corpus gave it',
        (tester) async {
      await mount(tester, const SermonLibrarySermonPage(sermonId: 2444));
      expect(find.byType(CircularProgressIndicator), findsNothing);
      final raw =
          File('${SermonLibraryService.libraryRoot}/bodies/2444.txt')
              .readAsStringSync();
      final expected = raw
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .length;
      expect(expected, greaterThan(20),
          reason: 'a one-paragraph fixture would prove nothing');
      expect(find.byType(SelectableText), findsNWidgets(expected),
          reason: 'these bodies are paragraph-per-LINE — zero of the 843 '
              'contain a blank-line gap — so splitting on blank lines the '
              'way the other corpus\'s renderer does would collapse the '
              'whole sermon into one block and delete every break the '
              'transcriber made');
    });

    testWidgets('and not one character of it is changed', (tester) async {
      await mount(tester, const SermonLibrarySermonPage(sermonId: 2444));
      final raw =
          File('${SermonLibraryService.libraryRoot}/bodies/2444.txt')
              .readAsStringSync();
      final first = raw.split('\n').firstWhere((l) => l.trim().isNotEmpty);
      final rendered = tester
          .widgetList<SelectableText>(find.byType(SelectableText))
          .first
          .data!;
      // The only addition is the two-em first-line indent, which is
      // two real U+3000 characters so that a copy out of the selection
      // is a copy of spaces rather than of U+FFFC.
      expect(rendered, '　　${first.trim()}');
      expect(rendered.substring(2), isNot(contains('  ')),
          reason: 'nothing re-wraps or re-punctuates a preacher');
    });

    testWidgets('the speaker is credited once, on the page itself',
        (tester) async {
      await mount(tester, const SermonLibrarySermonPage(sermonId: 2444));
      expect(find.text('小珊姊妹'), findsOneWidget,
          reason: 'a reader arriving by deep link has passed under no '
              'header, so the credit is here — once');
    });

    testWidgets('a duplicated sermon offers the app\'s other text',
        (tester) async {
      // 4024 八福与圣灵的果子: 10 617 characters here against 14 199 in
      // `assets/sermons/zh-CN/016.txt`. Same sermon, two texts.
      await mount(tester, const SermonLibrarySermonPage(sermonId: 4024));
      expect(find.text(uiStrings['sermonLibraryAlsoInApp']!['zh-Hans']!),
          findsOneWidget);
      expect(find.text(uiStrings['sermonLibraryOpenCounterpart']!['zh-Hans']!),
          findsOneWidget);
    });

    testWidgets('a sermon that merely shares a title with one does not',
        (tester) async {
      // 3320 新造的人 is 李马可牧师's and has nothing to do with the
      // 李马可-titled sermon in the app's one-preacher corpus.
      await mount(tester, const SermonLibrarySermonPage(sermonId: 3320));
      expect(find.text(uiStrings['sermonLibraryAlsoInApp']!['zh-Hans']!),
          findsNothing);
    });

    testWidgets('an audio-only record says it has no transcript',
        (tester) async {
      // 6012 活着就是基督 — two recordings, zero characters of body.
      await mount(tester, const SermonLibrarySermonPage(sermonId: 6012));
      expect(find.text(uiStrings['sermonLibraryNoText']!['zh-Hans']!),
          findsOneWidget);
      expect(find.byType(SelectableText), findsNothing);
    });

    testWidgets('the rights line is printed at the foot, off the asset',
        (tester) async {
      await mount(tester, const SermonLibrarySermonPage(sermonId: 2444));
      final lib = await svc.load();
      expect(lib.rightsFor('zh-Hans'), contains('经授权使用'));
      expect(find.text(lib.rightsFor('zh-Hans')), findsOneWidget,
          reason: 'the rights line belongs to the corpus and is read out '
              'of `_meta.rights`, never composed in the app');
    });

    testWidgets('an id in no corpus says so', (tester) async {
      await mount(tester, const SermonLibrarySermonPage(sermonId: 999999));
      expect(find.text(uiStrings['sermonNotFound']!['zh-Hans']!),
          findsOneWidget);
    });
  });
}
