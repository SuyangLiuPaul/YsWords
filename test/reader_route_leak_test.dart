import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:yswords/utils/app_nav.dart';
import 'package:yswords/utils/navigate_to_reader.dart';

/// 2026-08-23, from the user: tapping a search result opens the right
/// chapter at verse 1 with no highlight.
///
/// The reader is a full route and search is pushed on top of it, so the
/// stack is `[Dashboard, HomePage, SearchPage]`. Every jump path in
/// `search_page.dart` then called `Get.off(() => const HomePage())`,
/// which is `pushReplacement` — it replaces only SearchPage and leaves
/// the original HomePage underneath.
///
/// Both readers then read the one `MainProvider` created in
/// `main.dart:100`, above the navigator. Each `_ChapterPage` mints its
/// own controllers, so nothing is double-attached; what they contend
/// for is `MainProvider._activeChapterControllers`, a single
/// last-writer-wins slot that `mp.itemScrollController` forwards
/// through. `_isLivePane` already stops the older pane CONSUMING the
/// jump — the live pane consumes it correctly and then scrolls the
/// slot, which the covered pane's chapter page can have registered
/// last. The right verse, scrolled on a list nobody can see.
///
/// `navigateToReader` already existed for exactly this — it was written
/// in v1.3.7 after the same defect was reported against Library
/// ("bible duplicate了"). Search, the AI reference cards, the
/// concordance refs and the Strong's lexicon were never moved onto it.
class _HomeStub extends StatelessWidget {
  const _HomeStub();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('READER')));
}

class _SearchStub extends StatelessWidget {
  const _SearchStub();
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Builder(
            builder: (inner) => TextButton(
              onPressed: () => navigateToReader(inner),
              child: const Text('RESULT'),
            ),
          ),
        ),
      );
}

Future<void> _pumpReaderThenSearch(WidgetTester tester) async {
  await tester.pumpWidget(
    const GetMaterialApp(
      home: Scaffold(body: Center(child: Text('DASHBOARD'))),
    ),
  );
  await tester.pumpAndSettle();
  pushPage(const _HomeStub(), routeName: kHomePageRouteName);
  await tester.pumpAndSettle();
  pushPage(const _SearchStub());
  await tester.pumpAndSettle();
}

void main() {
  group('the shape of the leak', () {
    testWidgets(
      'Get.off from above the reader leaves TWO readers in the stack',
      (tester) async {
        await _pumpReaderThenSearch(tester);
        // The reader is offstage under the search route, not gone — which
        // is the whole problem: it is still mounted and still holding the
        // provider's scroll controller.
        expect(find.text('READER', skipOffstage: false), findsOneWidget);

        // What every search jump path used to do.
        Get.off(() => const _HomeStub());
        await tester.pumpAndSettle();

        expect(
          find.text('READER', skipOffstage: false),
          findsNWidgets(2),
          reason: 'pushReplacement replaces only the top route, so the '
              'reader that was already underneath survives — this is the '
              'duplicate pane the jump lands on',
        );
      },
    );

    testWidgets(
      'and names the pushed route something navigateToReader cannot find',
      (tester) async {
        await _pumpReaderThenSearch(tester);
        Get.off(() => const _HomeStub());
        await tester.pumpAndSettle();

        // GetX derives an anonymous route's name from the BUILDER
        // CLOSURE (`routeName ??= "/${page.runtimeType}"`), so the name
        // is not `/HomePage` and does not end in `HomePage` either. The
        // second half of the damage: the canonical helper's stack search
        // walks straight past a reader pushed this way.
        final name = Get.currentRoute;
        expect(name, isNot(kHomePageRouteName));
        expect(name.endsWith('HomePage'), isFalse);
      },
    );
  });

  testWidgets(
    'navigateToReader returns to the existing reader instead of pushing one',
    (tester) async {
      await _pumpReaderThenSearch(tester);
      expect(find.text('RESULT'), findsOneWidget);

      await tester.tap(find.text('RESULT'));
      await tester.pumpAndSettle();

      expect(find.text('RESULT', skipOffstage: false), findsNothing,
          reason: 'the search route must be gone');
      expect(
        find.text('READER', skipOffstage: false),
        findsOneWidget,
        reason: 'exactly one reader — the one that was already mounted, '
            'so nothing else can overwrite the provider\'s active '
            'chapter-controller slot',
      );
    },
  );

  test(
    'no page in lib/ pushes a second reader with Get.off',
    () {
      // A source guard, because the defect is a call-site choice: the
      // helper cannot protect a path that does not use it. Written after
      // finding that Library was moved onto `navigateToReader` in v1.3.7
      // and search, the AI reference cards, the concordance refs and the
      // Strong's lexicon were left behind for three months.
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final src = entity.readAsStringSync();
        if (RegExp(r'Get\.off\w*\(\s*\(\)\s*=>\s*const\s+HomePage\(')
            .hasMatch(src)) {
          offenders.add(entity.path);
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'Get.off is pushReplacement — it leaves an existing '
            'HomePage below the route being replaced. Use '
            'navigateToReader(context), which pops back to the reader '
            'already in the stack.',
      );
    },
  );

  test(
    'every reader push names its route explicitly',
    () {
      // `navigateToReader` finds the existing reader by ROUTE NAME, so a
      // reader pushed under any other name is invisible to it — it gets
      // popped and a cold one mounted in its place.
      //
      // `pushPage` defaults to `'/${page.runtimeType}'`, which is
      // `/HomePage` on native and a MINIFIED symbol on release web (see
      // `_UrlRestoreObserver` in main.dart, which exists because the web
      // engine writes that minified name into the URL fragment). So the
      // default is correct on five of the six targets and silently wrong
      // on the one the user tests most. Four call sites already passed
      // the name explicitly; eight did not.
      // Read each call's arguments up to the statement's own `;` rather
      // than with one regex: a greedy `[^;]*` spans newlines, and
      // `allMatches` is non-overlapping, so one named call site could
      // swallow an unnamed one further down the file and the guard
      // would still pass.
      const marker = 'pushPage(const HomePage()';
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final src = entity.readAsStringSync();
        for (var at = src.indexOf(marker);
            at >= 0;
            at = src.indexOf(marker, at + marker.length)) {
          final end = src.indexOf(';', at);
          final call = src.substring(at, end < 0 ? src.length : end);
          if (!call.contains("'/HomePage'") &&
              !call.contains('kHomePageRouteName')) {
            offenders.add('${entity.path}: $call');
          }
        }
      }
      expect(offenders, isEmpty,
          reason: 'pass routeName: kHomePageRouteName so navigateToReader '
              'can find this reader on release web');
    },
  );
}
