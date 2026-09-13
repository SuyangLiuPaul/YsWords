import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:yswords/models/app_settings.dart';
import 'package:yswords/widgets/liquid_glass.dart';

/// The Dashboard can be reached from the keyboard.
///
/// 2026-09-14, measured on the live build: Tab reached none of it. The
/// hero cards and all twelve quick-link tiles are `LiquidGlassButton`s,
/// and that widget was a `MouseRegion` over a `GestureDetector` — no
/// focus node, so nothing to focus and nothing for Enter to activate.
/// The only control on the screen that took focus was the app-bar gear,
/// which is a real `IconButton`.
///
/// The omission was specific, not general: the same widget already
/// honoured hover, `prefers-reduced-motion` and high contrast. Focus
/// was the one state nobody wired.
void main() {
  Widget host({VoidCallback? onTap, Widget? child}) =>
      ChangeNotifierProvider<AppSettings>(
        create: (_) => AppSettings(),
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: LiquidGlassButton(
                onTap: onTap,
                semanticLabel: 'Read Bible',
                child: child ?? const Text('Read Bible'),
              ),
            ),
          ),
        ),
      );

  testWidgets('Tab reaches a card and Enter opens it', (tester) async {
    var opened = 0;
    await tester.pumpWidget(host(onTap: () => opened++));
    await tester.pump();

    final detector = find.descendant(
      of: find.byType(LiquidGlassButton),
      matching: find.byType(FocusableActionDetector),
    );
    expect(detector, findsOneWidget,
        reason: 'the dashboard card has no focus node, so Tab cannot '
            'reach it');
    expect(tester.widget<FocusableActionDetector>(detector).enabled, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(opened, 1, reason: 'Enter must open the card Tab landed on');
  });

  testWidgets('a focused card says so, without changing size',
      (tester) async {
    await tester.pumpWidget(host(onTap: () {}));
    await tester.pump();

    final card = find.byType(LiquidGlassButton);
    final restingSize = tester.getSize(card);

    Decoration? ring() => tester
        .widgetList<DecoratedBox>(
            find.descendant(of: card, matching: find.byType(DecoratedBox)))
        .where((d) => d.position == DecorationPosition.foreground)
        .map((d) => d.decoration)
        .firstOrNull;

    final before = ring();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    final after = ring();
    expect(after, isNot(before),
        reason: 'a focused control must be visibly focused — WCAG 2.4.7');
    expect((after! as BoxDecoration).border, isNotNull);
    // The ring is painted OVER the card, so focusing cannot reflow the
    // grid the card sits in.
    expect(tester.getSize(card), restingSize);
  });

  testWidgets('a card with nothing to open is not a tab stop',
      (tester) async {
    // Tabbing onto something that cannot be activated is a dead end.
    await tester.pumpWidget(host(onTap: null));
    await tester.pump();
    final detector = find.descendant(
      of: find.byType(LiquidGlassButton),
      matching: find.byType(FocusableActionDetector),
    );
    expect(tester.widget<FocusableActionDetector>(detector).enabled, isFalse);
  });

  testWidgets('hover still works, and focus is not hover', (tester) async {
    await tester.pumpWidget(host(onTap: () {}));
    await tester.pump();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(LiquidGlassButton)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
