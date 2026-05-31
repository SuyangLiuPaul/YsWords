import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/widgets/left_accent_card.dart';

void main() {
  // Regression guard for the "A borderRadius can only be given on
  // borders with uniform colors" crash (reported as
  // InkDecoration.paintFeature on the dashboard daily-verse card,
  // v1.3.47). LeftAccentCard must render a rounded surface with a
  // left accent stripe — and optionally a uniform outline — WITHOUT
  // ever pairing a non-uniform Border with a borderRadius.

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: Center(child: child))),
    );
  }

  testWidgets('renders with rounded corners + accent, no exception',
      (tester) async {
    await pump(
      tester,
      const LeftAccentCard(
        accentColor: Color(0xFF884444),
        background: Color(0xFFEEEEEE),
        borderRadius: BorderRadius.all(Radius.circular(12)),
        padding: EdgeInsets.all(12),
        child: Text('verse'),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('verse'), findsOneWidget);
  });

  testWidgets('with a uniform outline still paints cleanly',
      (tester) async {
    await pump(
      tester,
      const LeftAccentCard(
        accentColor: Color(0xFF884444),
        outlineColor: Color(0x66999999),
        borderRadius: BorderRadius.all(Radius.circular(12)),
        padding: EdgeInsets.all(8),
        child: Text('outlined'),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('outlined'), findsOneWidget);
    // The outline path wraps the content in a DecoratedBox with a
    // uniform Border.all — that one is legal with a radius.
    expect(find.byType(DecoratedBox), findsWidgets);
  });

  testWidgets('asymmetric radius (right corners only) is safe',
      (tester) async {
    await pump(
      tester,
      const LeftAccentCard(
        accentColor: Color(0xFF884444),
        background: Color(0x11884444),
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(4),
          bottomRight: Radius.circular(4),
        ),
        padding: EdgeInsets.all(8),
        child: Text('note'),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('note'), findsOneWidget);
  });

  testWidgets('the accent stripe is an actual painted child',
      (tester) async {
    await pump(
      tester,
      const LeftAccentCard(
        accentColor: Color(0xFF112233),
        accentWidth: 3,
        child: SizedBox(height: 40, width: 100),
      ),
    );
    expect(tester.takeException(), isNull);
    // ClipRRect clips the stripe + content to the rounded shape.
    expect(find.byType(ClipRRect), findsOneWidget);
  });

  // REGRESSION (v1.3.x): the dashboard "Verse of the Day" card is a
  // LeftAccentCard whose child is a mainAxisSize.max Column, and it
  // lives in a ListView (unbounded height). The first implementation
  // used Row(crossAxisAlignment: stretch) + Expanded(child) which threw
  // during layout in exactly this configuration — blanking the
  // dashboard from that card downward. This must render cleanly.
  testWidgets('mainAxisSize.max Column child inside a ListView does NOT '
      'throw (the dashboard-blank regression)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              Material(
                color: const Color(0xFFEEEEEE),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () {},
                  borderRadius: BorderRadius.circular(12),
                  child: LeftAccentCard(
                    borderRadius: BorderRadius.circular(12),
                    accentColor: const Color(0xFF884444),
                    accentWidth: 3,
                    outlineColor: const Color(0x66999999),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      // The dashboard card's Column has no explicit
                      // mainAxisSize → defaults to max. Reproduce that.
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('In the beginning God created the heavens'),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: Text('— Genesis 1:1')),
                            Icon(Icons.arrow_forward, size: 16),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // A sibling AFTER the card — must still render (the bug
              // blanked everything below the failing card).
              const Text('SECTION BELOW'),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.textContaining('In the beginning'), findsOneWidget);
    expect(find.text('SECTION BELOW'), findsOneWidget);
  });
}
