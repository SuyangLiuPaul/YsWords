import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/biblical_person.dart';
import 'package:yswords/pages/bible_timeline_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/utils/reference_parser.dart';
import 'package:yswords/widgets/person_detail_sheet.dart';

/// The timeline's `_RefChip` and the person sheet's `_refChip` wired
/// their tap the same unconditional way the evidence chip did before it
/// was fixed: every citation looked navigable, and one the parser
/// cannot resolve could only answer 「Couldn't parse reference」.
///
/// It was argued that this needs no fix because today's data resolves —
/// measured, 123 refs in `bible_timeline.json` and 665 in
/// `family_tree.json`, 0 unresolvable on either, and
/// `test/evidence_unresolvable_citation_test.dart` keeps it that way.
/// That is a guard on the DATA. This is the guard on the WIDGET, and it
/// is the cheaper of the two to hold: one null check per chip, and the
/// surface no longer depends on an import staying well behaved.
///
/// What is asserted is behaviour, not styling: an unresolvable citation
/// is still printed (the record cites it, and the app goes on saying
/// so) but carries no tap target, and building or tapping one cannot
/// throw.
BiblicalPerson _person(List<String> refs) => BiblicalPerson(
      id: 'test-person',
      name: 'Test Person',
      yearSystem: 'bc',
      summary: 'A person cited from somewhere the app cannot open.',
      refs: refs,
    );

Future<void> _pumpPersonSheet(WidgetTester tester, List<String> refs) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(402, 874);
  final controller = ScrollController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MainProvider()),
        ChangeNotifierProvider(create: (_) => AppSettings()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: PersonDetailSheet(
            person: _person(refs),
            locale: 'en',
            scrollController: controller,
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
}

/// Serve one timeline event to `TimelineService` instead of the real
/// asset, so the page can be pumped with a citation the parser rejects.
/// The bundled asset has none — that is the point of the data guard —
/// and this test is about what the widget does when one arrives.
void _mockTimelineAsset(WidgetTester tester, List<String> refs) {
  final payload = jsonEncode({
    'events': [
      {
        'id': 'test-event',
        'year': -1000,
        'era': 'monarchy',
        'titleEn': 'Test event',
        'descEn': 'Description.',
        'refs': refs,
        'personIds': <String>[],
      },
    ],
  });
  tester.binding.defaultBinaryMessenger.setMockMessageHandler(
    'flutter/assets',
    (ByteData? message) async {
      final key = utf8.decode(message!.buffer
          .asUint8List(message.offsetInBytes, message.lengthInBytes));
      if (key != 'assets/bible_timeline.json') return null;
      final bytes = Uint8List.fromList(utf8.encode(payload));
      return ByteData.view(bytes.buffer);
    },
  );
  addTearDown(() => tester.binding.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', null));
}

Future<void> _pumpTimeline(WidgetTester tester, List<String> refs) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(402, 874);
  _mockTimelineAsset(tester, refs);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MainProvider()),
        ChangeNotifierProvider(create: (_) => AppSettings()),
      ],
      child: const MaterialApp(home: BibleTimelinePage()),
    ),
  );
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 400));
}

/// The chip's tap target in the timeline: an `InkWell` with the chip's
/// 4pt corner radius.
Finder _timelineTapTargets() => find.byWidgetPredicate((w) =>
    w is InkWell &&
    w.onTap != null &&
    w.borderRadius == BorderRadius.circular(4));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('firstResolvableReference', () {
    test('answers null only when nothing in the citation opens', () {
      expect(firstResolvableReference('Genesis 1:1')!.englishBook, 'Genesis');
      expect(firstResolvableReference('Ecclesiasticus (Sirach) 39:1'), isNull);
      expect(firstResolvableReference('Various NT references'), isNull);
      expect(firstResolvableReference(''), isNull);
    });

    test('a chain opens at the first part that resolves', () {
      // The behaviour this must not narrow: `parseReference` truncates
      // at the first `;`, so on its own it calls this unresolvable even
      // though Exodus 14 is right there.
      expect(parseReference('Ecclesiasticus (Sirach) 44:1; Exodus 14:21-22'),
          isNull);
      expect(
        firstResolvableReference(
                'Ecclesiasticus (Sirach) 44:1; Exodus 14:21-22')!
            .englishBook,
        'Exodus',
      );
    });
  });

  group('the person detail sheet', () {
    testWidgets('an unresolvable citation is shown but not tappable',
        (tester) async {
      addTearDown(tester.view.reset);
      await _pumpPersonSheet(tester, ['Ecclesiasticus (Sirach) 39:1']);

      expect(tester.takeException(), isNull);
      // Still printed — the record cites it.
      expect(find.text('Ecclesiasticus (Sirach) 39:1'), findsOneWidget);

      final chips = tester.widgetList<ActionChip>(find.byType(ActionChip));
      expect(chips, hasLength(1));
      expect(chips.single.onPressed, isNull,
          reason: 'a chip that can only answer "Could not parse '
              'reference" must not be dressed as a link');
    });

    testWidgets('a resolvable citation keeps its jump', (tester) async {
      addTearDown(tester.view.reset);
      await _pumpPersonSheet(tester, ['Genesis 1:26-27']);

      expect(tester.takeException(), isNull);
      final chips = tester.widgetList<ActionChip>(find.byType(ActionChip));
      expect(chips, hasLength(1));
      expect(chips.single.onPressed, isNotNull);
    });

    testWidgets('a chain whose first part fails stays tappable',
        (tester) async {
      addTearDown(tester.view.reset);
      await _pumpPersonSheet(
          tester, ['Ecclesiasticus (Sirach) 44:1; Exodus 14:21-22']);

      final chips = tester.widgetList<ActionChip>(find.byType(ActionChip));
      expect(chips, hasLength(1));
      expect(chips.single.onPressed, isNotNull,
          reason: 'Exodus 14 is cited right there and opens');
    });
  });

  // One test, not two: `TimelineService` memoises the parsed asset for
  // the isolate's lifetime, so a second pump would silently reuse the
  // first one's events. Both cases therefore ride on one event, which
  // is also the more honest arrangement — the two chips are side by
  // side and only one of them is a link.
  testWidgets(
      'the bible timeline: an unresolvable citation is shown but not '
      'tappable, next to one that is', (tester) async {
    addTearDown(tester.view.reset);
    await _pumpTimeline(
        tester, ['Ecclesiasticus (Sirach) 39:1', 'Genesis 1:1']);

    // Nothing thrown while building either chip — including no
    // overflow from printing a long unparsed citation raw.
    expect(tester.takeException(), isNull);
    expect(find.text('Test event'), findsOneWidget,
        reason: 'the mocked asset should have loaded');

    // Still printed — the event cites it.
    expect(find.text('Ecclesiasticus (Sirach) 39:1'), findsOneWidget);

    // Pre-fix there were TWO tap targets and one of them could only
    // answer 「Couldn't parse reference」.
    expect(_timelineTapTargets(), findsOneWidget,
        reason: 'only the citation that opens should be tappable');
  });
}
