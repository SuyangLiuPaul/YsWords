// 2026-08-12: the eager version pre-load must not run while the splash
// is on screen.
//
// User, twice, from an iPhone: "为什么每一次加载的时候都会加载中译本，但是
// iPhone不应该全部已经有了吗" and then "the loading page in iphone still
// have loading bible version which I feel no need right because it is
// iphone so it will be loaded in phone". Nothing was being downloaded —
// on native every version ships in the bundle — but the splash painted
// "Loading versions: 3/6" while six `json.decode`s of 2–9 MB strings
// blocked the main thread underneath it, which also delayed the 3 s
// timer that dismisses the splash.
//
// So the contract is now: the pre-load waits for the splash to hand
// over, and the splash has no version-progress line to paint at all.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/pages/loading_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/version_preloader.dart';

/// Records what the pre-loader asked for without touching an asset.
class _RecordingProvider extends MainProvider {
  final List<String> preloaded = <String>[];

  @override
  Future<void> preloadVersion(String version) async {
    preloaded.add(version);
  }
}

const _verses = <Verse>[
  Verse(book: 'Genesis', chapter: 1, verse: 1, text: 'In the beginning.'),
];

void main() {
  test('no version is decoded until the splash has been dismissed', () async {
    final provider = _RecordingProvider();
    // ignore: unawaited_futures
    eagerPreloadAllVersions(provider, isActive: () => true);

    // Generous room for the loop to get going if it were going to.
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(provider.preloaded, isEmpty,
        reason: 'the splash is still on screen — a decode here janks it '
            'and delays the advance timer that dismisses it');

    provider.markSplashDismissed();
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(provider.preloaded, isNotEmpty,
        reason: 'the pre-load is deferred, not removed — the user chose '
            'it in v1.2.25 so every version switch is instant');
    expect(provider.preloaded, isNot(contains(provider.currentVersion)),
        reason: 'the active version is already loaded');
  });

  test('markSplashDismissed is idempotent', () async {
    final provider = MainProvider();
    provider.markSplashDismissed();
    provider.markSplashDismissed();
    await provider.splashDismissed;
  });

  testWidgets('the splash paints no progress line for a healthy boot',
      (tester) async {
    final provider = MainProvider()
      ..setVerses(_verses)
      ..setBootInFlight(false);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<MainProvider>.value(value: provider),
          ChangeNotifierProvider<AppSettings>.value(value: AppSettings()),
        ],
        child: MaterialApp(
          home: LoadingPage(verses: _verses, onAdvance: () {}),
        ),
      ),
    );
    await tester.pump();

    // Every locale of the line the user objected to.
    for (final needle in const ['Loading versions', '正在加载译本', '正在載入譯本']) {
      expect(find.textContaining(needle), findsNothing);
    }
    expect(find.byType(LinearProgressIndicator), findsNothing,
        reason: 'a bar under the daily verse says "something is '
            'downloading"; on a healthy boot nothing is');
  });
}
