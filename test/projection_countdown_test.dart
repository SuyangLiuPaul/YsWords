import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yswords/models/verse.dart';
import 'package:yswords/widgets/projection_stage.dart';

/// The countdown before a service starts — VideoPsalm parity, and the
/// thing a hall that is filling actually needs on the wall.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the clock reads as a clock', () {
    test('minutes and seconds, hours only when there are some', () {
      expect(formatProjectionCountdown(const Duration(minutes: 5)), '5:00');
      expect(
          formatProjectionCountdown(
              const Duration(minutes: 12, seconds: 34)),
          '12:34');
      expect(
          formatProjectionCountdown(
              const Duration(hours: 1, minutes: 2, seconds: 3)),
          '1:02:03');
      expect(formatProjectionCountdown(const Duration(seconds: 9)), '0:09',
          reason: 'seconds are always two digits, so the number does not '
              'change width as it ticks');
    });

    test('a countdown that has run out reads 0:00, never a negative', () {
      expect(formatProjectionCountdown(Duration.zero), '0:00');
      expect(formatProjectionCountdown(const Duration(seconds: -30)), '0:00',
          reason: 'the room is not owed a minus sign');
    });
  });

  group('the wall', () {
    Future<void> pump(WidgetTester tester,
        {Duration? countdown, bool blank = false}) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: ProjectionStage(
          verses: const [
            Verse(book: 'Genesis', chapter: 1, verse: 1, text: 'In the beginning.')
          ],
          reference: 'Genesis 1:1',
          versionCode: 'kjv',
          typeSize: 64,
          blank: blank,
          locale: 'en',
          scheme: projectionDarkScheme(Colors.blue),
          countdownRemaining: countdown,
        ),
      ));
      await tester.pump();
    }

    testWidgets('a running countdown replaces the passage, not joins it',
        (tester) async {
      await pump(tester, countdown: const Duration(minutes: 5));
      expect(find.text('5:00'), findsOneWidget);
      expect(find.text('In the beginning.'), findsNothing,
          reason: 'a verse behind a clock is neither');
      expect(find.text('Genesis 1:1'), findsNothing,
          reason: 'and the reference belongs to the verse');
    });

    testWidgets('zero is a state of its own, and says so', (tester) async {
      await pump(tester, countdown: Duration.zero);
      expect(find.text('0:00'), findsOneWidget);
      expect(find.text('We are beginning'), findsOneWidget,
          reason: 'a countdown that vanished at zero would take the wall '
              'back to the passage at the exact moment everyone looks');
    });

    testWidgets('no countdown leaves the passage exactly as it was',
        (tester) async {
      await pump(tester);
      expect(find.text('In the beginning.'), findsOneWidget);
      expect(find.text('0:00'), findsNothing);
    });

    testWidgets('blanking still wins over a running countdown',
        (tester) async {
      await pump(tester, countdown: const Duration(minutes: 5), blank: true);
      expect(find.text('5:00'), findsNothing,
          reason: 'B is the key an operator hits when something has to '
              'come off the wall NOW');
    });
  });

  group('the wiring', () {
    test('the page keeps an end TIME, not a ticking number', () {
      final page = File('lib/pages/projection_page.dart').readAsStringSync();
      expect(page.contains('DateTime? _countdownEnd;'), isTrue,
          reason: 'a decrementing timer drifts, and one paused by a '
              'suspended tab comes back wrong');
      expect(page.contains('end.difference(DateTime.now())'), isTrue);
      expect(page.contains('_countdownTicker?.cancel();'), isTrue,
          reason: 'and it is cancelled on dispose');
    });

    test('the follower window shows it too', () {
      final html = File('web/stage.html').readAsStringSync();
      expect(html.contains('f.countdown'), isTrue);
      expect(html.contains('countdownLabel'), isTrue);
      final svc =
          File('lib/services/projection_broadcast.dart').readAsStringSync();
      expect(svc.contains("'countdown': countdown"), isTrue);
    });
  });
}
