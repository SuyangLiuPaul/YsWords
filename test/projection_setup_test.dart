// The 投影 SETUP — the half the owner said was missing on 2026-09-09
// (「projector setting怎么没做好背景也不能set或者preset两个经文也不能调整
// 这个功能要完整」).
//
// `projection_cursor_test.dart` holds the arithmetic and
// `projection_page_test.dart` the wall's own behaviour. This file holds
// the four claims those two cannot make:
//
//   * what the operator sets up is still there next Sunday, and what
//     they blanked is not;
//   * every ground on offer is dark, and blanking lands on the one the
//     verse was already sitting on;
//   * the projector's second edition is the projector's, after one look
//     at split view's;
//   * a named setup comes back whole, including when it names an
//     edition this build cannot load.
//
// ## WHY NOTHING HERE WAITS FOR A CORPUS
//
// `FetchVerses.loadVerseList` reads an 8 MB asset through the platform
// channel, and that future does not complete inside `testWidgets`'
// fake-async zone — measured, not assumed: a probe that awaited it timed
// out at two minutes while `pumpAndSettle` returned immediately with
// nothing loaded. So every assertion below is made against the SETTING
// (which goes through the mocked SharedPreferences and does complete) or
// against the widget tree, never against the second edition's text. That
// is the right seam anyway: what was broken was the operator's setup not
// being remembered, not the corpus loader.

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/constants/bible_versions.dart'
    show fullBibleVersionLabel;
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/book.dart';
import 'package:yswords/models/chapter.dart';
import 'package:yswords/models/projection_preset.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/pages/projection_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/widgets/overflow_hint_scroll.dart';
import 'package:yswords/widgets/projection_stage.dart';

const _g11 =
    Verse(book: 'Genesis', chapter: 1, verse: 1, text: 'In the beginning.');
const _g12 =
    Verse(book: 'Genesis', chapter: 1, verse: 2, text: 'And the earth.');

MainProvider _reader() {
  final mp = MainProvider();
  mp.books = [
    Book(title: 'Genesis', chapters: [
      Chapter(title: 1, verses: const [_g11, _g12]),
    ]),
  ];
  mp.setVerses(const [_g11, _g12]);
  mp.setCurrentChapter(book: _g11.book, chapter: _g11.chapter);
  mp.updateCurrentVerse(verse: _g11);
  return mp;
}

/// A host with a door, so the projection can be OPENED and CLOSED.
///
/// Half of this file's subject is what survives the page being closed,
/// and a test that pumps `ProjectionPage` directly can only ever observe
/// one lifetime of it.
Widget _host(MainProvider mp, AppSettings settings) => MultiProvider(
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
    );

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('project'));
  await tester.pumpAndSettle();
}

Future<void> _close(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pumpAndSettle();
}

/// Re-read the store into a NEW settings object.
///
/// The point of every persistence assertion here: keeping the same
/// `AppSettings` instance across a close-and-reopen would prove only
/// that an object in memory still holds a value.
Future<AppSettings> _reloaded() async {
  final settings = AppSettings();
  await settings.loadSettings();
  return settings;
}

ProjectionStage _stage(WidgetTester tester) =>
    tester.widget<ProjectionStage>(find.byType(ProjectionStage));

double _declaredSize(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!.fontSize!;

/// The ground the stage is actually painting — read off the single
/// `DecoratedBox` both branches of its `build` go through.
BoxDecoration _painted(WidgetTester tester) => tester
    .widget<DecoratedBox>(find
        .descendant(
          of: find.byType(ProjectionStage),
          matching: find.byType(DecoratedBox),
        )
        .first)
    .decoration as BoxDecoration;

/// AppSettings' own 600 ms sync-blob debounce, armed by every
/// `notifyListeners`. It belongs to the settings object rather than to
/// the page, so disposing the tree does not cancel it and the harness
/// reports it as a leak.
Future<void> _drain(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 1));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('the setup persists', () {
    test(
        'the settings default step is the ladder default the page '
        'declares', () {
      // A hand-kept cross-file fact: `AppSettings` cannot import
      // `pages/projection_page.dart` for one integer without pointing
      // the layering the wrong way round, so the number is written twice
      // and held equal here instead.
      expect(AppSettings().projectionTypeStep, kProjectionTypeDefaultStep,
          reason: 'a fresh install must open the projection on the same '
              'rung the ladder says it opens on');
    });

    testWidgets('the type size the operator sets is still there next week',
        (tester) async {
      final mp = _reader();
      await tester.pumpWidget(_host(mp, AppSettings()));
      await _open(tester);

      final opened = _declaredSize(tester, _g11.text);
      await tester.sendKeyEvent(LogicalKeyboardKey.equal);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.equal);
      await tester.pump();
      final chosen = _declaredSize(tester, _g11.text);
      expect(chosen, greaterThan(opened),
          reason: 'the resize key did nothing, so this test proves '
              'nothing about what survives');

      await _close(tester);
      final next = await _reloaded();
      await tester.pumpWidget(_host(mp, next));
      await _open(tester);

      expect(_declaredSize(tester, _g11.text), chosen,
          reason: 'the operator set the type for THIS hall and the wall '
              'came back at the factory size');
      await _drain(tester);
    });

    testWidgets(
        'the second edition being on survives, and the blank does not',
        (tester) async {
      final mp = _reader();
      await tester.pumpWidget(_host(mp, AppSettings()));
      await _open(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.pumpAndSettle();
      expect(_stage(tester).secondOn, isTrue);

      // Blank the wall, and leave it blanked — the operator who walks
      // away mid-blank is exactly the case.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.pump();
      expect(find.text(_g11.text), findsNothing);

      await _close(tester);

      final store = await SharedPreferences.getInstance();
      expect(
        store.getKeys().where((k) => k.toLowerCase().contains('blank')),
        isEmpty,
        reason: 'nothing may write the curtain to disk: reopening onto a '
            'wall somebody blanked last Sunday is a service that starts '
            'black with nobody knowing why',
      );

      final next = await _reloaded();
      expect(next.projectionSecondOn, isTrue);

      await tester.pumpWidget(_host(mp, next));
      await _open(tester);
      expect(_stage(tester).secondOn, isTrue,
          reason: 'a bilingual congregation is bilingual next week too');
      expect(_stage(tester).blank, isFalse);
      expect(find.text(_g11.text), findsOneWidget,
          reason: 'the projection reopened onto a blank wall');
      await _drain(tester);
    });
  });

  group('the ground', () {
    test('every ground is dark, and none is brighter than the default', () {
      // The rule as a property of the SET, so a fifth ground added
      // without a test of its own still has to pass it. `seeded` is both
      // the default and the ceiling: a projector ADDS light, so no
      // choice offered here may put more of it on a wall than the
      // ground this page already shipped with.
      const seeds = <Color>[
        Colors.lightBlue,
        Colors.red,
        Colors.yellow,
        Colors.green,
        Colors.purple,
        Colors.white,
      ];
      for (final seed in seeds) {
        final scheme = projectionDarkScheme(seed);
        final ceiling = projectionGroundColors(ProjectionGround.seeded, scheme)
            .map((c) => c.computeLuminance())
            .reduce(math.max);
        expect(ceiling, lessThan(kProjectionGroundMaxLuminance),
            reason: 'the DEFAULT ground under seed $seed is already too '
                'bright for a wall, which breaks the premise every other '
                'ground is measured against');

        for (final ground in ProjectionGround.values) {
          for (final colour in projectionGroundColors(ground, scheme)) {
            expect(colour.computeLuminance(),
                lessThan(kProjectionGroundMaxLuminance),
                reason: '$ground paints $colour under seed $seed, which is '
                    'not a dark ground');
            expect(colour.computeLuminance(), lessThanOrEqualTo(ceiling),
                reason: '$ground paints $colour, brighter than the default '
                    'ground under seed $seed — a projector adds light, so '
                    'no ground may add more than the one already shipped');
            expect(colour.a, 1.0,
                reason: '$ground is translucent, so whatever is behind the '
                    'stage shows through the ground');
          }
        }
      }
    });

    testWidgets('blanking lands on the very ground the verse was on',
        (tester) async {
      // The whole reason a gradient ground is legal. If blanking picked
      // its own black, `spotlight` would flash on every press of B.
      final scheme = projectionDarkScheme(Colors.lightBlue);
      for (final ground in ProjectionGround.values) {
        Widget stage(bool blank) => MaterialApp(
              home: ProjectionStage(
                verses: [_g11],
                reference: 'Genesis 1:1',
                versionCode: 'kjv',
                typeSize: 76,
                blank: blank,
                locale: 'en',
                scheme: scheme,
                ground: ground,
              ),
            );

        await tester.pumpWidget(stage(false));
        final lit = _painted(tester);
        await tester.pumpWidget(stage(true));
        final blanked = _painted(tester);

        expect(blanked, lit,
            reason: 'pressing B on the $ground ground changes the ground '
                'as well as the text, which is a flash across the whole '
                'wall — the one thing the blank key must not be');
      }
    });

    testWidgets(
        'the strip button opens a picker, and the picker is dark even when '
        'the reader\'s app is light', (tester) async {
      final mp = _reader();
      final settings = AppSettings();
      await tester.pumpWidget(_host(mp, settings));
      await _open(tester);

      // The premise: `_host` uses a stock MaterialApp, whose theme is
      // light. That is the case that matters — a white dialog thrown
      // across a dark wall in front of a congregation is the very flash
      // the ground rules exist to prevent, arriving through the one
      // surface those rules do not reach.
      expect(Theme.of(tester.element(find.byType(ProjectionStage))).brightness,
          Brightness.light,
          reason: 'the ambient theme is not light, so this test is not '
              'exercising the case it is named for');

      await tester.tap(find.byIcon(Icons.gradient));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget,
          reason: 'the ground button on the strip should name the grounds, '
              'not step the ring — stepping is what the key is for');
      expect(_stage(tester).ground, ProjectionGround.seeded,
          reason: 'opening the picker changed the ground behind it');

      final dialog = tester.element(find.byType(AlertDialog));
      expect(Theme.of(dialog).colorScheme.brightness, Brightness.dark);
      final background =
          tester.widget<AlertDialog>(find.byType(AlertDialog)).backgroundColor;
      expect(background, isNotNull);
      expect(background!.computeLuminance(), lessThan(0.2),
          reason: 'the picker is a light panel on a dark wall');

      // And it is a picker, so picking works.
      await tester.tap(find.text(
          projectionGroundLabel(ProjectionGround.black, settings.locale)));
      await tester.pumpAndSettle();
      expect(_stage(tester).ground, ProjectionGround.black);
      await _drain(tester);
    });

    testWidgets('the G key steps the ring, and the choice is still there '
        'next week', (tester) async {
      final mp = _reader();
      await tester.pumpWidget(_host(mp, AppSettings()));
      await _open(tester);

      expect(_stage(tester).ground, ProjectionGround.seeded,
          reason: 'an operator who never opens the picker must see '
              'exactly what they saw before grounds existed');

      await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
      await tester.pump();
      final stepped = _stage(tester).ground;
      expect(stepped, isNot(ProjectionGround.seeded));
      expect(stepped, projectionGroundAfter(ProjectionGround.seeded));

      await _close(tester);
      final next = await _reloaded();
      expect(next.projectionGround, stepped.name,
          reason: 'the ground is stored by NAME, so a ground inserted '
              'later cannot reassign this choice');

      await tester.pumpWidget(_host(mp, next));
      await _open(tester);
      expect(_stage(tester).ground, stepped);
      await _drain(tester);
    });
  });

  group('the second edition is the projector\'s own', () {
    testWidgets(
        'it is seeded from split view once and then stops following it',
        (tester) async {
      // The borrow the owner could not see: before this, the wall's
      // second edition WAS split view's, live, forever, with no picker
      // anywhere on the projection to say so.
      SharedPreferences.setMockInitialValues(<String, Object>{
        kSplitSecondaryVersionKey: 'leb',
      });
      final mp = _reader();
      expect(mp.currentVersion, isNot('leb'),
          reason: 'the seed has to differ from the reading edition or it '
              'is indistinguishable from the language fallback');

      await tester.pumpWidget(_host(mp, AppSettings()));
      await _open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.pumpAndSettle();

      final seeded = await _reloaded();
      expect(seeded.projectionSecondVersion, 'leb',
          reason: 'the first run should inherit the operator\'s own second '
              'column rather than invent a rule');

      // Split view moves on. The projection must not.
      final store = await SharedPreferences.getInstance();
      await store.setString(kSplitSecondaryVersionKey, 'kjv');

      await _close(tester);
      await tester.pumpWidget(_host(mp, await _reloaded()));
      await _open(tester);
      await tester.pumpAndSettle();

      final after = await _reloaded();
      expect(after.projectionSecondVersion, 'leb',
          reason: 'changing the second column beside a reading moved the '
              'edition on the wall — which is the invisible coupling '
              'this stopped being');
      await _drain(tester);
    });

    testWidgets('the picker on the projection page changes it, and keeps it',
        (tester) async {
      final mp = _reader();
      final settings = AppSettings();
      await tester.pumpWidget(_host(mp, settings));
      await _open(tester);

      // Straight off the control strip, not from another feature's page.
      await tester.tap(find.byIcon(Icons.translate));
      await tester.pumpAndSettle();

      const wanted = 'leb';
      final row = find.text(fullBibleVersionLabel(wanted));
      expect(row, findsOneWidget,
          reason: 'the picker does not offer the editions this build has');
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();

      expect(settings.projectionSecondVersion, wanted);
      expect(settings.projectionSecondOn, isTrue,
          reason: 'choosing an edition is the operator saying they want '
              'it — making them find the toggle afterwards is two steps '
              'for one intention');
      expect(_stage(tester).secondOn, isTrue);

      await _close(tester);
      expect((await _reloaded()).projectionSecondVersion, wanted);
      await _drain(tester);
    });

    testWidgets('the picker leaves out the edition already on top',
        (tester) async {
      final mp = _reader();
      await tester.pumpWidget(_host(mp, AppSettings()));
      await _open(tester);
      await tester.tap(find.byIcon(Icons.translate));
      await tester.pumpAndSettle();

      // Not a second edition — the same words twice. Offering the row
      // would be offering one that does something else when tapped,
      // because `projectionSecondVersionFrom` replaces it.
      expect(find.text(fullBibleVersionLabel(mp.currentVersion)), findsNothing,
          reason: '${mp.currentVersion} is the edition being read');
      await _drain(tester);
    });
  });

  group('presets', () {
    test('an edition this build cannot load resolves instead of blanking '
        'the wall', () {
      // `nasb` is in `disabledVersions`, so it is exactly the case: a
      // code that was legal when the preset was written and is not
      // loadable now. The answer has to be a real edition, because the
      // alternative in front of a congregation is an empty wall.
      final landed = projectionSecondVersionFrom('nasb', 'cuvs-yhwh');
      expect(landed, isNot('nasb'));
      expect(landed, 'kjv',
          reason: 'the same rule the second edition\'s loader uses: fall '
              'back inside the language family');
      // And the two other shapes of "nothing usable stored".
      expect(projectionSecondVersionFrom(null, 'cuvs-yhwh'), 'kjv');
      expect(projectionSecondVersionFrom('cuvs-yhwh', 'cuvs-yhwh'), 'kjv',
          reason: 'the same edition twice is not a second edition');
    });

    testWidgets('a named setup is saved once and comes back whole',
        (tester) async {
      final mp = _reader();
      final settings = AppSettings();
      await tester.pumpWidget(_host(mp, settings));
      await _open(tester);

      // Set the hall up: bigger type, a different ground.
      await tester.sendKeyEvent(LogicalKeyboardKey.equal);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.equal);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
      await tester.pump();
      final wantedStep = settings.projectionTypeStep;
      final wantedGround = settings.projectionGround;

      // Save it under a name, from the keyboard.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'morning service');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextButton));
      await tester.pumpAndSettle();

      // ONE key holds the lot, as JSON.
      final store = await SharedPreferences.getInstance();
      final raw = store.getString('projectionPresets');
      expect(raw, isNotNull,
          reason: 'the preset was not written under its own single key');
      final decoded = jsonDecode(raw!) as List<dynamic>;
      expect(decoded, hasLength(1));
      expect((decoded.first as Map)['name'], 'morning service');

      // Wednesday: a different setup entirely.
      await tester.sendKeyEvent(LogicalKeyboardKey.minus);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.minus);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.minus);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
      await tester.pump();
      expect(settings.projectionTypeStep, isNot(wantedStep));
      expect(settings.projectionGround, isNot(wantedGround));

      // Sunday again: one tap.
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.pumpAndSettle();
      await tester.tap(find.text('morning service'));
      await tester.pumpAndSettle();

      expect(settings.projectionTypeStep, wantedStep);
      expect(settings.projectionGround, wantedGround);
      expect(_stage(tester).ground, projectionGroundFromName(wantedGround));

      // And the preset itself outlives the page it was made on.
      await _close(tester);
      final next = await _reloaded();
      expect(next.projectionPresets.map((p) => p.name), ['morning service']);
      expect(next.projectionPresets.single.typeStep, wantedStep);
      await _drain(tester);
    });

    testWidgets(
        'applying a preset that names a withdrawn edition still puts a '
        'verse on the wall', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'projectionPresets': jsonEncode([
          const ProjectionPreset(
            name: 'from an older build',
            typeStep: 6,
            secondOn: true,
            secondVersion: 'nasb',
            groundName: 'black',
          ).toJson(),
        ]),
      });
      final mp = _reader();
      final settings = await _reloaded();
      expect(settings.projectionPresets, hasLength(1),
          reason: 'the stored preset did not survive the round trip, so '
              'the rest of this test is about nothing');

      await tester.pumpWidget(_host(mp, settings));
      await _open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.pumpAndSettle();
      await tester.tap(find.text('from an older build'));
      await tester.pumpAndSettle();

      expect(settings.projectionSecondVersion, 'kjv',
          reason: 'a preset naming an edition this build strips must land '
              'on one it can load, the way every other stale version '
              'preference in this app does');
      expect(settings.projectionGround, 'black');
      expect(settings.projectionTypeStep, 6);
      expect(find.text(_g11.text), findsOneWidget,
          reason: 'the wall went empty applying a preset');
      await _drain(tester);
    });
  });

  group('the control strip', () {
    test('the three setup keys go through the one command map', () {
      // New commands go through `projectionCommandFor` like every
      // existing one, so the bar and the keyboard cannot drift apart.
      expect(projectionCommandFor(LogicalKeyboardKey.keyG),
          ProjectionCommand.cycleGround);
      expect(projectionCommandFor(LogicalKeyboardKey.keyV),
          ProjectionCommand.chooseSecondVersion);
      expect(projectionCommandFor(LogicalKeyboardKey.keyS),
          ProjectionCommand.presets);
    });

    test('and none of them took a key that already meant something else',
        () {
      // The bindings a projectionist already has in their fingers.
      expect(projectionCommandFor(LogicalKeyboardKey.keyB),
          ProjectionCommand.blank);
      expect(projectionCommandFor(LogicalKeyboardKey.keyP),
          ProjectionCommand.toggleSecondVersion);
      expect(projectionCommandFor(LogicalKeyboardKey.escape),
          ProjectionCommand.leave);
      expect(projectionCommandFor(LogicalKeyboardKey.arrowRight),
          ProjectionCommand.nextVerse);
      expect(projectionCommandFor(LogicalKeyboardKey.space),
          ProjectionCommand.nextVerse);
      expect(projectionCommandFor(LogicalKeyboardKey.pageDown),
          ProjectionCommand.nextChapter);
      expect(projectionCommandFor(LogicalKeyboardKey.equal),
          ProjectionCommand.biggerType);
      expect(projectionCommandFor(LogicalKeyboardKey.minus),
          ProjectionCommand.smallerType);
    });

    testWidgets('on a narrow window the bar scrolls instead of shrinking',
        (tester) async {
      // The bar is 621 px of buttons and dividers; a 360-px window
      // leaves it 328, so `scaleDown` would draw every 20-px glyph at
      // 10.6. A ten-pixel target is not a control an operator can hit
      // from the back of a hall — it is a picture of one. The closing
      // assertion below re-derives those numbers off the live tree
      // rather than trusting this comment.
      tester.view.physicalSize = const Size(360 * 3, 640 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(_reader(), AppSettings()));
      await _open(tester);

      expect(find.byType(OverflowHintScroll), findsOneWidget,
          reason: 'the strip has no way to say there is more behind its '
              'edge, so the operator never swipes');
      expect(tester.takeException(), isNull,
          reason: 'a RenderFlex overflow is a yellow-and-black stripe on '
              'a church wall');

      // `getRect` is in global coordinates, so a `FittedBox` scaling the
      // whole bar down would show up here and a scroller does not.
      final painted = tester.getRect(find.byIcon(Icons.close)).width;
      expect(painted, closeTo(20, 0.5),
          reason: 'the leave button is being drawn at ${painted}px, so the '
              'bar is being shrunk to fit rather than scrolled');

      // What `scaleDown` WOULD do here, in numbers, so the reasoning in
      // `projection_page.dart`'s comment is a measurement rather than a
      // memory — and so it stops being true the moment the bar becomes
      // small enough that shrinking would have been fine after all.
      final natural = tester
          .getSize(find.descendant(
            of: find.byType(OverflowHintScroll),
            matching: find.byType(Row),
          ))
          .width;
      final available = tester.getSize(find.byType(Card)).width - 8;
      final wouldBe = 20 * (available / natural);
      expect(wouldBe, lessThan(14),
          reason: 'a scaled-down bar would draw its 20px glyphs at '
              '${wouldBe.toStringAsFixed(1)}px, which is no longer small '
              'enough to justify scrolling instead');
    });

    testWidgets('and on a laptop it is still the same compact pill',
        (tester) async {
      // The scroll view hugs its child when the child fits, so the
      // window this page is actually driven from sees no change: no
      // fade, no chevron, and a bar that does not span the wall.
      await tester.pumpWidget(_host(_reader(), AppSettings()));
      await _open(tester);

      final barWidth = tester.getSize(find.byType(Card)).width;
      final wallWidth = tester.getSize(find.byType(ProjectionStage)).width;
      expect(barWidth, lessThan(wallWidth),
          reason: 'the control strip grew to the full width of the wall');
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing,
          reason: 'a scroll hint on a bar that fits points at nothing');
    });
  });
}
