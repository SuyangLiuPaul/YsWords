// 2026-07-26 (v1.3.146): regression guard for the FROZEN SPLASH bug.
//
// Field report (iPhone, zh-Hans, prod web): the app sat on the branded
// splash — logo + daily verse, no spinner, no error, no "Reload page"
// button — indefinitely, on a boot that had actually SUCCEEDED.
//
// Cause: LoadingPage.build spent its `_advanceScheduledOnce` latch on
// the first build even when `_scheduleAdvanceIfReady()` could not arm
// the advance timer yet (it early-returns while `verses.isEmpty`). On
// any boot slower than main.dart's 4 s splash watchdog, LoadingPage is
// mounted with empty verses, burns the latch, and then never re-arms
// once verses finally arrive — so it never navigates to HomePage.
//
// These tests drive that exact ordering: mount with NO verses, let the
// first build + post-frame run, THEN deliver verses (as FetchVerses
// does on a slow link) and assert the page still advances.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/pages/loading_page.dart';
import 'package:yswords/providers/main_provider.dart';

const _verses = <Verse>[
  Verse(book: 'Genesis', chapter: 1, verse: 1, text: 'In the beginning.'),
  Verse(book: 'Genesis', chapter: 1, verse: 2, text: 'And the earth.'),
];

Future<bool> _pumpAndSeeIfAdvances(
  WidgetTester tester, {
  required bool versesArriveLate,
}) async {
  final mainProvider = MainProvider();
  final settings = AppSettings();
  var advanced = false;

  if (!versesArriveLate) {
    mainProvider.setVerses(_verses);
    mainProvider.setBootInFlight(false);
  }

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<MainProvider>.value(value: mainProvider),
        ChangeNotifierProvider<AppSettings>.value(value: settings),
      ],
      child: MaterialApp(
        home: LoadingPage(
          verses: const [],
          onAdvance: () => advanced = true,
        ),
      ),
    ),
  );

  // First build + its post-frame callback. This is where the latch
  // used to be spent while verses were still empty.
  await tester.pump();

  if (versesArriveLate) {
    // The slow-boot path: FetchVerses finally resolves well after the
    // splash watchdog already mounted this page.
    mainProvider.setVerses(_verses);
    mainProvider.setBootInFlight(false);
    await tester.pump();
  }

  // The advance timer is 3 s; give it room, then settle.
  await tester.pump(const Duration(seconds: 4));
  await tester.pump();
  return advanced;
}

void main() {
  testWidgets('advances when verses are present from the first build',
      (tester) async {
    // Fast-boot control case — this always worked.
    final advanced =
        await _pumpAndSeeIfAdvances(tester, versesArriveLate: false);
    expect(advanced, isTrue,
        reason: 'fast boot should advance off the splash');
  });

  testWidgets('advances when verses arrive AFTER the first build', (tester) async {
    // THE REGRESSION. Before the fix this stayed false forever: the
    // latch was already consumed, so nothing re-armed the advance and
    // the user was parked on a static splash with no way forward.
    final advanced =
        await _pumpAndSeeIfAdvances(tester, versesArriveLate: true);
    expect(advanced, isTrue,
        reason: 'slow boot must still advance once verses arrive — '
            'this is the frozen-splash regression');
  });
}
