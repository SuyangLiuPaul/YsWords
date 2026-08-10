import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/widgets/remote_image.dart';

/// Pins the behaviour that a crash report asked for.
///
/// v1.4.39, from an iPhone: `SocketException: Operation timed out
/// (errno = 60)` out of `NetworkImage._loadAsync`, one per song row,
/// because fydt.org — the only source that publishes artwork — was
/// refusing connections and `NetworkImage` has no timeout.
///
/// In a widget test every HTTP request fails by design (flutter_test
/// installs an HttpClient that returns 400), which makes it exactly the
/// right harness for the failure path.
void main() {
  setUp(RemoteImage.clearFailureMemo);

  Widget host(String? url, {Key? fallbackKey}) => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 40,
            height: 40,
            child: RemoteImage(
              url: url,
              cacheWidth: 120,
              fallback: (_) =>
                  ColoredBox(key: fallbackKey ?? const Key('fb'),
                      color: const Color(0xFF123456)),
            ),
          ),
        ),
      );

  testWidgets('a null url renders the fallback and never touches the '
      'network', (tester) async {
    await tester.pumpWidget(host(null));
    expect(find.byKey(const Key('fb')), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(RemoteImage.failureCount, 0);
  });

  testWidgets('the fallback is what shows while loading — no spinner, no '
      'layout shift', (tester) async {
    await tester.pumpWidget(host('https://example.invalid/a.jpg'));
    // First frame: request in flight, nothing decoded yet.
    expect(find.byKey(const Key('fb')), findsOneWidget);
  });

  testWidgets('a failed url is remembered, so the next row does not '
      'reopen a socket to a dead host', (tester) async {
    const url = 'https://example.invalid/cover.jpg';
    await tester.pumpWidget(host(url));
    await tester.pumpAndSettle();

    expect(RemoteImage.failureCount, 1,
        reason: 'the failure should be memoised on the first attempt');

    // A second widget for the SAME url must short-circuit to the
    // fallback without constructing an Image at all — that is the
    // difference between one dead socket and one per visible row.
    await tester.pumpWidget(host(url, fallbackKey: const Key('fb2')));
    await tester.pump();
    expect(find.byKey(const Key('fb2')), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('clearing the memo gives a recovered host another chance',
      (tester) async {
    const url = 'https://example.invalid/cover.jpg';
    await tester.pumpWidget(host(url));
    await tester.pumpAndSettle();
    expect(RemoteImage.failureCount, 1);

    RemoteImage.clearFailureMemo();
    expect(RemoteImage.failureCount, 0);

    await tester.pumpWidget(host(url, fallbackKey: const Key('fb3')));
    await tester.pump();
    // Attempted again: an Image widget exists this time.
    expect(find.byType(Image), findsOneWidget);
  });
}
