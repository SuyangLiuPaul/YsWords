// The behavioural half of 投影 (`lib/pages/projection_page.dart`) — the
// four properties that only exist once the page is on screen, plus the
// one cross-file fact it depends on and cannot import.
//
// `projection_cursor_test.dart` holds the arithmetic.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/book.dart';
import 'package:yswords/models/chapter.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/constants/projection_strings.dart';
import 'package:yswords/pages/projection_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/utils/font_catalog.dart' show kCjkFontFallback;
import 'package:yswords/widgets/projection_stage.dart';

// A two-chapter corpus with a boundary in the middle. The texts are
// distinguishable on sight so a failure names the verse it is looking
// at rather than an index.
const _g11 = Verse(
    book: 'Genesis', chapter: 1, verse: 1, text: 'In the beginning.');
const _g12 =
    Verse(book: 'Genesis', chapter: 1, verse: 2, text: 'And the earth.');
const _g21 =
    Verse(book: 'Genesis', chapter: 2, verse: 1, text: 'Thus the heavens.');
const _g22 =
    Verse(book: 'Genesis', chapter: 2, verse: 2, text: 'And on the seventh.');

const _corpus = [_g11, _g12, _g21, _g22];

/// A provider holding [_corpus], with the reader parked on [at].
///
/// Both halves have to be seeded: `chapterList` is derived from `books`
/// while `versesInChapter` is derived from `verses`, and the cursor
/// needs the two to agree.
MainProvider _readerAt(Verse at) {
  final mp = MainProvider();
  mp.books = [
    Book(title: 'Genesis', chapters: [
      Chapter(title: 1, verses: const [_g11, _g12]),
      Chapter(title: 2, verses: const [_g21, _g22]),
    ]),
  ];
  mp.setVerses(_corpus);
  mp.setCurrentChapter(book: at.book, chapter: at.chapter);
  mp.updateCurrentVerse(verse: at);
  return mp;
}

Widget _app(MainProvider mp, AppSettings settings) => MultiProvider(
      providers: [
        ChangeNotifierProvider<MainProvider>.value(value: mp),
        ChangeNotifierProvider<AppSettings>.value(value: settings),
      ],
      child: const MaterialApp(home: ProjectionPage()),
    );

/// The declared size of the verse currently on the wall.
double _declaredSize(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!.fontSize!;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets(
      'the verse keys carry the wall across a chapter boundary and back '
      'again', (tester) async {
    final mp = _readerAt(_g12);
    final settings = AppSettings();
    await tester.pumpWidget(_app(mp, settings));

    // The reader is parked on the last verse of Genesis 1, so it opens
    // there.
    expect(find.text(_g12.text), findsOneWidget);

    // Forward over the boundary: the next verse after Genesis 1:2 is
    // Genesis 2:1, which no arithmetic on a verse number would find.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text(_g21.text), findsOneWidget);
    expect(find.text(_g12.text), findsNothing);

    // And back over it, onto the LAST verse of the previous chapter
    // rather than its first.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(find.text(_g12.text), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('the blank key clears the wall and puts back the same verse',
      (tester) async {
    final mp = _readerAt(_g11);
    final settings = AppSettings();
    await tester.pumpWidget(_app(mp, settings));

    expect(find.text(_g11.text), findsOneWidget);

    // Blanking hides the reference too, not just the passage: a screen
    // that still names a verse tells the room where the sermon is while
    // the preacher is somewhere else.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.pump();
    expect(find.text(_g11.text), findsNothing);
    expect(find.textContaining('Genesis 1:1'), findsNothing);

    // The same key restores it — and restores the verse the operator was
    // on, not the one the reader started at.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.pump();
    expect(find.text(_g11.text), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'blanking preserves a cursor the operator has already moved',
      (tester) async {
    final mp = _readerAt(_g11);
    final settings = AppSettings();
    await tester.pumpWidget(_app(mp, settings));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(find.text(_g12.text), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.pump();

    // Not _g11: blanking is a curtain, not a reset. An operator who
    // blanks to change slides and unblanks to the wrong verse has been
    // given a worse tool than no blank key.
    expect(find.text(_g12.text), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'the wall does not move when the reader drives their own font size '
      'from one end of its range to the other', (tester) async {
    final mp = _readerAt(_g11);
    final settings = AppSettings();
    await tester.pumpWidget(_app(mp, settings));

    final declaredBefore = _declaredSize(tester, _g11.text);
    // The painted rect as well as the declared size, because a
    // `FittedBox` can make the first true and the second false — the
    // stage draws the passage inside a `BoxFit.scaleDown`, so a
    // regression that changed the fit rather than the size would slip
    // past a declared-size check alone.
    final paintedBefore = tester.getRect(find.text(_g11.text));

    // The page watches AppSettings, so these genuinely rebuild it. That
    // is the strong form of the test: not "the page ignores the change
    // because it never sees it", but "the page rebuilds and the wall
    // still does not move".
    settings.setFontSize(12);
    await tester.pump();
    expect(_declaredSize(tester, _g11.text), declaredBefore);

    settings.setFontSize(32);
    await tester.pump();
    expect(_declaredSize(tester, _g11.text), declaredBefore,
        reason: 'the size of scripture on a wall is set by the room, not by '
            'what the operator likes on their own laptop');
    expect(tester.getRect(find.text(_g11.text)), paintedBefore);

    // And the projection's own key still works, so the size is fixed
    // against the READER's control specifically, not frozen outright.
    await tester.sendKeyEvent(LogicalKeyboardKey.equal);
    await tester.pump();
    expect(_declaredSize(tester, _g11.text), greaterThan(declaredBefore));

    // Drain AppSettings' own 600 ms write debounce, which the two
    // setFontSize calls above armed. It belongs to the settings object
    // rather than to this page, so disposing the tree does not cancel
    // it and the harness would report it as a leak.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'leaving puts the reader back exactly where they were, however far '
      'the operator drove the wall', (tester) async {
    final mp = _readerAt(_g11);
    final settings = AppSettings();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<MainProvider>.value(value: mp),
          ChangeNotifierProvider<AppSettings>.value(value: settings),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ProjectionPage(),
                  ),
                ),
                child: const Text('project'),
              ),
            ),
          ),
        ),
      ),
    );

    final bookBefore = mp.currentBook;
    final chapterBefore = mp.currentChapter;
    final verseBefore = mp.currentVerse;
    final versionBefore = mp.currentVersion;

    await tester.tap(find.text('project'));
    await tester.pumpAndSettle();
    expect(find.text(_g11.text), findsOneWidget);

    // Drive the wall three verses on, across the chapter boundary and
    // then a whole chapter, so anything that wrote back would have
    // written something plainly different.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pump();

    // Still true WHILE the projection is open, not merely after it
    // closes: the reader's position is never touched at any point, so
    // there is no window in which a listener could observe it moved.
    expect(mp.currentBook, bookBefore);
    expect(mp.currentChapter, chapterBefore);
    expect(mp.currentVerse, same(verseBefore));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('project'), findsOneWidget,
        reason: 'Esc should have left the projection');
    expect(mp.currentBook, bookBefore);
    expect(mp.currentChapter, chapterBefore);
    expect(mp.currentVerse, same(verseBefore));
    expect(mp.currentVersion, versionBefore);
  });

  testWidgets(
      'every string the room can see pins the bundled CJK subset, so a wall '
      'of Chinese scripture cannot come up as tofu', (tester) async {
    // On Flutter web's CanvasKit an unresolved face draws as tofu, and
    // `NotoSansSC-YsWords` is the only entry in the chain Skia can
    // actually see — the rest are CSS names that need the OS. Inheriting
    // from the app theme would work today; this surface pins it anyway,
    // because 34 tofu boxes at 76 px in front of a congregation is not a
    // degraded reading, it is no reading at all.
    await tester.pumpWidget(MaterialApp(
      home: ProjectionStage(
        verses: const [Verse(
            book: '创世记', chapter: 1, verse: 1, text: '起初，神创造天地。')],
        reference: '创世记 1:1',
        versionCode: 'cuvs-yhwh',
        typeSize: 76,
        blank: false,
        locale: 'zh-Hans',
        scheme: projectionDarkScheme(Colors.lightBlue),
        // Second edition on, so the second block and its own fallback
        // are in the tree too — it is the block most likely to be the
        // Chinese one when the reading edition is English.
        secondOn: true,
        secondTexts: ['In the beginning God created.'],
        secondCode: 'kjv',
      ),
    ));

    final texts = tester.widgetList<Text>(find.byType(Text)).toList();
    expect(texts, isNotEmpty,
        reason: 'the stage drew nothing, so this test proved nothing');
    for (final t in texts) {
      expect(
        t.style?.fontFamilyFallback,
        contains(kCjkFontFallback.first),
        reason: 'the style on "${t.data}" does not pin the bundled CJK '
            'subset and would render as tofu on CanvasKit',
      );
    }
  });

  testWidgets(
      'both editions are on the wall at once, and the corner says which is '
      'which', (tester) async {
    // A bilingual congregation is this page's audience, and two
    // translations up with no way to tell them apart is worse than one.
    await tester.pumpWidget(MaterialApp(
      home: ProjectionStage(
        verses: const [Verse(
            book: '创世记', chapter: 1, verse: 1, text: '起初，神创造天地。')],
        reference: '创世记 1:1',
        versionCode: 'cuvs-yhwh',
        typeSize: 76,
        blank: false,
        locale: 'zh-Hans',
        scheme: projectionDarkScheme(Colors.lightBlue),
        secondOn: true,
        secondTexts: ['In the beginning God created.'],
        secondCode: 'kjv',
      ),
    ));

    expect(find.text('起初，神创造天地。'), findsOneWidget);
    expect(find.text('In the beginning God created.'), findsOneWidget);

    // One reference line carrying both edition tags, not two badges: the
    // room's question is a single question — where is this, and in what?
    expect(find.textContaining('创世记 1:1'), findsOneWidget);
    expect(find.textContaining('KJV'), findsOneWidget);

    // The second edition leads with the smaller size, so the room can
    // tell at a glance which one is the sermon's text.
    final primary = tester.widget<Text>(find.text('起初，神创造天地。'));
    final secondary =
        tester.widget<Text>(find.text('In the beginning God created.'));
    expect(secondary.style!.fontSize, lessThan(primary.style!.fontSize!));
  });

  testWidgets(
      'an edition with nothing to say here says so, in apparatus type '
      'rather than as scripture', (tester) async {
    // Several bundled editions are one Testament only, so a second
    // column with no verse at this reference is normal, not a fault.
    // What must not happen is the room reading the explanation as the
    // verse.
    await tester.pumpWidget(MaterialApp(
      home: ProjectionStage(
        verses: const [Verse(
            book: 'Genesis', chapter: 1, verse: 1, text: 'In the beginning.')],
        reference: 'Genesis 1:1',
        versionCode: 'kjv',
        typeSize: 76,
        blank: false,
        locale: 'en',
        scheme: projectionDarkScheme(Colors.lightBlue),
        secondOn: true,
        secondTexts: null,
        secondCode: 'biblexg-v2',
      ),
    ));

    final scheme = projectionDarkScheme(Colors.lightBlue);
    final missing =
        tester.widget<Text>(find.text('This edition has no text here'));
    expect(missing.style!.color, scheme.onSurfaceVariant);
    final scripture = tester.widget<Text>(find.text('In the beginning.'));
    expect(scripture.style!.color, scheme.onSurface);
    expect(missing.style!.color, isNot(scripture.style!.color));
  });

  test(
      'the second edition still reads the key split view actually writes',
      () {
    // A hand-kept cross-file fact: `kSplitSecondaryVersionKey` is the
    // string `MainProvider` composes at runtime from a PRIVATE
    // `_storagePrefix`, so the compiler cannot check the two agree and
    // the projection would silently fall back to its language default
    // if the write moved or was renamed. Read the source the way this
    // repo's other three-file sync tests do.
    final provider =
        File('lib/providers/main_provider.dart').readAsStringSync();
    final homePage = File('lib/pages/home_page.dart').readAsStringSync();

    expect(
      provider,
      contains("prefs.setString('\${_storagePrefix}version', currentVersion)"),
      reason: 'MainProvider no longer persists its edition under '
          '<prefix>version, so kSplitSecondaryVersionKey points at nothing',
    );
    expect(
      homePage,
      contains("MainProvider(storagePrefix: 'secondary_')"),
      reason: 'split view no longer uses the secondary_ prefix, so '
          'kSplitSecondaryVersionKey is not the second column any more',
    );
    expect(kSplitSecondaryVersionKey, 'secondary_version',
        reason: 'the two halves above compose to exactly this key');
  });

/// A route with no door is not a feature.
///
/// Added 2026-09-09, after the owner asked 「投影怎么做」 and the honest
/// answer was "type `#/project` in the address bar". `/project` had been
/// a registered GetX route since it shipped and nothing anywhere in the
/// UI pushed [ProjectionPage] — so on iOS and Android, which have no
/// address bar, the page could not be reached at all. SeekSparks hit the
/// identical gap a day earlier and found it the same way: by opening the
/// build and looking for it.
///
/// Neither repo had a test that could have caught it, because every test
/// either drove the page directly or checked the URL path. Both are
/// claims about the page; neither is a claim that a person can GET
/// there. This is that claim, and it is deliberately made against the
/// source rather than by pumping a 7,900-line reading pane: what went
/// wrong was structural — nobody wrote the call — and a grep for the
/// call is exactly the shape of the mistake.
  group('the door', () {
    test('some widget in lib/ actually opens the projection', () {
      final callers = <String>[];
      for (final f in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        if (f.path.endsWith('projection_page.dart')) continue;
        final src = f.readAsStringSync();
        // `main.dart`'s GetPage builder is the ROUTE, not a door — it is
        // what a typed URL lands on, and it is what was already there
        // while the feature was unreachable on two platforms.
        final withoutRoute =
            src.replaceAll(RegExp(r"page:\s*\(\)\s*=>\s*const ProjectionPage\(\)"), '');
        if (withoutRoute.contains('ProjectionPage()')) callers.add(f.path);
      }
      expect(callers, isNotEmpty,
          reason: 'no widget pushes ProjectionPage, so 投影 is reachable '
              'only by typing #/project — which iOS and Android cannot '
              'do. Put a door back in the reader\'s overflow menu.');
    });

    test('the door has a label in all three locales', () {
      final title = projectionStrings['projectionTitle'];
      expect(title, isNotNull);
      for (final locale in ['zh-Hans', 'zh-Hant', 'en']) {
        expect(title![locale], isNotNull,
            reason: '$locale has no label for the projection door');
        expect(title[locale], isNotEmpty);
      }
    });
  });

}