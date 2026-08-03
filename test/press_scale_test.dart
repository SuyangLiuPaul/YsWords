import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/widgets/press_scale.dart';

/// Guards the property that makes [PressScale] safe to wrap around existing
/// tappable cards: it observes pointers via a `Listener` and must never join
/// the gesture arena, so the child's own `InkWell` / `onTap` keeps firing.
///
/// The v1.4.1 implementation used a `GestureDetector`, which WOULD compete —
/// the same failure mode that produced dead taps elsewhere in the app.
void main() {
  testWidgets('does not swallow the child\'s own onTap', (tester) async {
    var childTaps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PressScale(
              child: Material(
                child: InkWell(
                  onTap: () => childTaps++,
                  child: const SizedBox(
                    width: 200,
                    height: 80,
                    child: Text('CARD'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('CARD'));
    await tester.pumpAndSettle();
    expect(childTaps, 1, reason: 'child InkWell must still receive the tap');

    await tester.tap(find.text('CARD'));
    await tester.pumpAndSettle();
    expect(childTaps, 2);
  });

  testWidgets('scales down while pressed and restores on release',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: PressScale(
              child: SizedBox(width: 200, height: 80, child: Text('CARD')),
            ),
          ),
        ),
      ),
    );

    double currentScale() =>
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

    expect(currentScale(), 1.0);

    final gesture = await tester.startGesture(tester.getCenter(find.text('CARD')));
    await tester.pump();
    expect(currentScale(), lessThan(1.0));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(currentScale(), 1.0);
  });

  testWidgets('releases the pressed look once a drag becomes a scroll',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: PressScale(
              child: SizedBox(width: 200, height: 80, child: Text('CARD')),
            ),
          ),
        ),
      ),
    );

    double currentScale() =>
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

    final gesture = await tester.startGesture(tester.getCenter(find.text('CARD')));
    await tester.pump();
    expect(currentScale(), lessThan(1.0));

    // Move well past kTouchSlop — this is a scroll, not a tap.
    await gesture.moveBy(const Offset(0, 60));
    await tester.pump();
    expect(currentScale(), 1.0,
        reason: 'a card must not stay stuck looking pressed while scrolling');

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('honours reduce-motion by skipping the scale animation',
      (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: PressScale(
                child: SizedBox(width: 200, height: 80, child: Text('CARD')),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(AnimatedScale), findsNothing);
    expect(find.text('CARD'), findsOneWidget);
  });
}
