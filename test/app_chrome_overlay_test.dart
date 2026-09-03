import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/models/app_settings.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/song_player_service.dart';
import 'package:yswords/services/song_service.dart';
import 'package:yswords/widgets/global_mini_player.dart';
import 'package:yswords/widgets/update_banner.dart';

/// `No Overlay widget found`, reported twice.
///
/// | | report 1 | report 2 |
/// |---|---|---|
/// | when | 2026-08-17 | 2026-08-19 |
/// | version | 1.4.75 | 1.4.113 |
/// | platform | macOS native | web, Windows |
/// | window | 800x600 | 1920x1080 |
/// | route | /SongsPage | /minified:ag2 |
///
/// The first write-up blamed macOS and small windows and told whoever
/// picked it up to "size it down to find it". Two platforms and two
/// window geometries later that was wrong, and the shared variable is
/// not geometry at all: both reporters had a mouse, and both had the
/// app-wide playback strip on screen.
///
/// **The mechanism.** `main.dart` mounts the strip through
/// `MaterialApp.builder`: `UpdateBanner(child: GlobalMiniPlayer(child:
/// child))`. `child` there IS the Navigator, so everything the builder
/// adds around it sits ABOVE the Navigator — and the Navigator's
/// `Overlay` is the app's only one. A `Tooltip` is an `OverlayPortal`:
/// `RawTooltipState.build` asserts `debugCheckHasOverlay` on every
/// build in debug, and in release `_OverlayPortalState` throws
/// `No Overlay widget found` the moment the portal is shown — which on
/// a mouse platform is a hover. The strip's close button carried
/// `tooltip:`. `nav:pop` as the last breadcrumb is not the cause; it is
/// simply when this subtree last rebuilt.
///
/// The fix is `TooltipVisibility(visible: false)` around the whole
/// strip, which is the framework's own way to say "no overlay here":
/// `TooltipState` then never builds a `RawTooltip`, so nothing looks
/// for an `Overlay`. Accessible names moved to `Icon.semanticLabel`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The real app chrome, wrapped exactly the way `main.dart` wraps it.
  Widget appWithChrome({required Widget home}) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MainProvider()),
          ChangeNotifierProvider(create: (_) => AppSettings()),
        ],
        child: MaterialApp(
          builder: (context, child) =>
              UpdateBanner(child: GlobalMiniPlayer(child: child!)),
          home: home,
        ),
      );

  testWidgets(
      'the mechanism: a tooltip mounted by MaterialApp.builder has no '
      'Overlay to open into', (tester) async {
    // Not a test of app code — a test of the claim the fix rests on, so
    // that if a future Flutter gives builder-level widgets an Overlay
    // this fails and the workaround can be retired.
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => Stack(children: [
        child!,
        Positioned(
          left: 0,
          bottom: 0,
          child: Material(
            child: IconButton(
              tooltip: 'Close player',
              icon: const Icon(Icons.close),
              onPressed: () {},
            ),
          ),
        ),
      ]),
      home: const Scaffold(body: Text('home')),
    ));
    expect(
      tester.takeException().toString(),
      contains('No Overlay widget found'),
      reason: 'this is the crash, reproduced in three lines',
    );
  });

  testWidgets('the playback strip survives a burst of push and pop',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(402, 874);
    addTearDown(tester.view.reset);

    final catalogue = (await tester.runAsync(SongService.load))!;
    final playable =
        catalogue.where((s) => s.hasPlayableAudio).take(3).toList();
    expect(playable, hasLength(3), reason: 'need a queue for the strip');

    final player = SongPlayerService.instance;
    await tester.runAsync(() => player.playQueue(playable, label: 'test'));
    // audioplayers reaches for platform channels that do not exist in a
    // widget test and reports the failure through FlutterError. Drain it
    // here so an absent native side does not read as this test's crash.
    tester.takeException();

    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MainProvider()),
        ChangeNotifierProvider(create: (_) => AppSettings()),
      ],
      child: MaterialApp(
        navigatorKey: nav,
        builder: (context, child) =>
            UpdateBanner(child: GlobalMiniPlayer(child: child!)),
        home: const Scaffold(body: Center(child: Text('home'))),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    tester.takeException();

    // The strip is on screen — otherwise everything below passes for
    // the wrong reason.
    expect(find.byIcon(Icons.close_rounded), findsOneWidget,
        reason: 'the mini-player close button should be showing');

    // A hover over the close button is what armed the tooltip on the
    // two machines that reported this.
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await tester.pump();
    await mouse.moveTo(tester.getCenter(find.byIcon(Icons.close_rounded)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull,
        reason: 'hovering the strip must not look for an Overlay');

    // …and the same across the push/pop burst both breadcrumb trails
    // ended with.
    for (var i = 0; i < 3; i++) {
      nav.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Center(child: Text('pushed'))),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      nav.currentState!.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull,
          reason: 'pop #$i rebuilt the strip and it threw');
    }

    expect(find.byIcon(Icons.close_rounded), findsOneWidget,
        reason: 'the strip should still be there after the burst');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('tooltips are off for the whole strip, not just one button',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(402, 874);
    addTearDown(tester.view.reset);

    final catalogue = (await tester.runAsync(SongService.load))!;
    final player = SongPlayerService.instance;
    await tester.runAsync(() => player.playQueue(
        catalogue.where((s) => s.hasPlayableAudio).take(2).toList(),
        label: 'test'));
    tester.takeException();

    await tester.pumpWidget(appWithChrome(
      home: const Scaffold(body: Center(child: Text('home'))),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    tester.takeException();

    // Read the inherited flag from inside the strip. A control added
    // to the strip later inherits the same answer, so this cannot
    // regress one button at a time.
    final context = tester.element(find.byIcon(Icons.close_rounded));
    expect(TooltipVisibility.of(context), isFalse,
        reason: 'the strip has no Overlay, so it must claim no tooltips');

    // The page BELOW the chrome is inside the Navigator and does have
    // an Overlay, so its tooltips must keep working.
    final pageContext = tester.element(find.text('home'));
    expect(TooltipVisibility.of(pageContext), isTrue,
        reason: 'the app itself must not lose tooltips');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 400));
  });
}
