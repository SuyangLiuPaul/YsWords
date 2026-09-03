import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/widgets/remote_image.dart';

/// The 2026-08-12 crash report, reproduced — and its stated cause
/// corrected.
///
///     SocketException: Operation timed out (OS Error: ..., errno = 60)
///       #10 NetworkImage._loadAsync
///       #15 ScrollAwareImageProvider.resolveStreamForKey
///     route: /NowPlayingPage
///
/// The queue read this as "the first attempt still costs 75s and still
/// reports". The second half is false, and the first half was worse than
/// written. Both are pinned below.
///
/// **It does not still report.** `ScrollAwareImageProvider` is
/// constructed in exactly one place in the framework —
/// `_ImageState._resolveImage` — so the report came from an `Image`
/// widget. Since flutter/flutter#97077, `_stopListeningToStream` adds a
/// blank ephemeral error listener whenever `errorBuilder != null`, and
/// `ImageStreamCompleter.reportError` reaches `FlutterError` only when
/// the listener list comes back empty. The first two tests here fire the
/// real errno-60 at a mounted page and at a disposed one and show
/// nothing escapes either way. The 08-12 report came from a build older
/// than the 08-11 conversion to `RemoteImage`.
///
/// **The 75 seconds were real, and were being paid over and over.** The
/// memo that exists to stop that was written from `errorBuilder` — a
/// widget hook — while errno 60 is a ~75-second OS connect timeout that
/// no page survives. Test three is the actual defect: leave the page
/// mid-connect and the failure was recorded nowhere, so the next song
/// opened another 75-second socket. Test four is the other half: the
/// memo was keyed by URL, so a host that answers nothing at all still
/// cost one dead socket per song.
class _GatedHttpClient extends Fake implements HttpClient {
  _GatedHttpClient(this.gate);

  final Completer<HttpClientRequest> gate;

  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> getUrl(Uri url) => gate.future;
}

/// Per-host behaviour. A host with no entry never answers at all, which
/// is what a 75-second connect looks like from inside a widget test.
class _ScriptedHttpClient extends Fake implements HttpClient {
  _ScriptedHttpClient(this.byHost);

  final Map<String, Future<HttpClientRequest>> byHost;

  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> getUrl(Uri url) =>
      byHost[url.host] ?? Completer<HttpClientRequest>().future;
}

Widget host(String? url) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 40,
          height: 40,
          child: RemoteImage(
            url: url,
            cacheWidth: 120,
            fallback: (_) => const ColoredBox(color: Color(0xFF123456)),
          ),
        ),
      ),
    );

/// The real errno-60 shape, as the OS raises it.
const _errno60 = SocketException(
  'Operation timed out',
  osError: OSError('Operation timed out', 60),
);

void main() {
  setUp(() {
    RemoteImage.clearFailureMemo();
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  });

  testWidgets('the socket failure is silent while the page is on screen',
      (tester) async {
    final gate = Completer<HttpClientRequest>();
    debugNetworkImageHttpClientProvider = () => _GatedHttpClient(gate);

    await tester.pumpWidget(host('https://fydt.org/art/mounted.jpg'));
    gate.completeError(_errno60);
    await tester.pumpAndSettle();
    // Unset inside the body: flutter_test asserts that no painting debug
    // variable outlives the test, and that check runs before tearDown.
    debugNetworkImageHttpClientProvider = null;

    expect(tester.takeException(), isNull,
        reason: 'the errorBuilder is an error listener, so reportError '
            'finds the error handled and never reaches FlutterError');
  });

  testWidgets('and still silent once the page is gone — this is the half '
      'of the report that was never true', (tester) async {
    final gate = Completer<HttpClientRequest>();
    debugNetworkImageHttpClientProvider = () => _GatedHttpClient(gate);

    await tester.pumpWidget(host('https://fydt.org/art/orphaned.jpg'));
    // The user leaves Now Playing while the 75-second connect is still
    // outstanding — the only thing that changes between this test and
    // the one above.
    await tester.pumpWidget(const SizedBox());
    gate.completeError(_errno60);
    await tester.pumpAndSettle();
    debugNetworkImageHttpClientProvider = null;

    expect(tester.takeException(), isNull,
        reason: 'Image installs a blank ephemeral error listener on '
            'dispose when it has an errorBuilder (flutter#97077), and '
            'RemoteImage now installs one of its own in the provider — '
            'an unreachable artwork host must not produce a crash '
            'report, from either direction');
  });

  testWidgets('a failure that lands after the page is gone is still '
      'remembered', (tester) async {
    final gate = Completer<HttpClientRequest>();
    debugNetworkImageHttpClientProvider = () => _GatedHttpClient(gate);

    const url = 'https://fydt.org/art/left-early.jpg';
    await tester.pumpWidget(host(url));
    await tester.pumpWidget(const SizedBox());
    gate.completeError(_errno60);
    await tester.pumpAndSettle();
    debugNetworkImageHttpClientProvider = null;

    // The defect: the memo used to be written from errorBuilder, which
    // no longer exists by the time a 75-second timeout expires, so
    // nothing was recorded and the next song paid the full 75s again.
    expect(RemoteImage.failureCount, 1,
        reason: 'the memo hangs off the provider now, not the widget');
    expect(RemoteImage.hostFailureCount, 1,
        reason: 'a socket timeout is the HOST being unreachable');
  });

  testWidgets('one dead host costs one dead socket, not one per song',
      (tester) async {
    final gate = Completer<HttpClientRequest>();
    debugNetworkImageHttpClientProvider = () => _GatedHttpClient(gate);

    await tester.pumpWidget(host('https://fydt.org/art/song-1.jpg'));
    gate.completeError(_errno60);
    await tester.pumpAndSettle();
    debugNetworkImageHttpClientProvider = null;

    // A DIFFERENT url on the same host — never tried, never failed.
    // 199 fydt songs used to mean 199 first attempts at 75 seconds each.
    await tester.pumpWidget(host('https://fydt.org/art/song-2.jpg'));
    await tester.pump();
    expect(find.byType(Image), findsNothing,
        reason: 'the host is known unreachable; no Image, no socket');

    // But a host nobody has heard from is still tried.
    await tester.pumpWidget(host('https://cgdc.org.au/art/song-3.jpg'));
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('the song that just failed does not get the next song\'s host '
      'muted', (tester) async {
    // Now Playing swaps one URL for another in the same widget position
    // every time the track changes. `_ImageState` clears `_lastException`
    // on a frame or a listener rebuild — NOT on a provider change — so
    // the first build after the swap calls `errorBuilder` with the OLD
    // song's exception while carrying the NEW song's URL. Recording the
    // memo from there muted a host on the strength of a different
    // host's failure; recording it from the provider cannot.
    final dead = Completer<HttpClientRequest>();
    debugNetworkImageHttpClientProvider =
        () => _ScriptedHttpClient({'fydt.org': dead.future});

    await tester.pumpWidget(host('https://fydt.org/art/prev.jpg'));
    dead.completeError(_errno60);
    await tester.pumpAndSettle();
    expect(RemoteImage.hostFailureCount, 1);

    // Track change: same widget slot, artwork on a healthy host.
    await tester.pumpWidget(host('https://cgdc.org.au/art/next.jpg'));
    await tester.pump();
    debugNetworkImageHttpClientProvider = null;

    expect(RemoteImage.hostFailureCount, 1,
        reason: 'cgdc.org.au has not failed — it has not even answered '
            'yet. Muting it here would blank every cgdc cover for ten '
            'minutes because a fydt cover timed out.');
    expect(RemoteImage.failureCount, 1);
  });

  group('a 404 stays scoped to its own url', () {
    testWidgets('one missing cover does not blank the whole host',
        (tester) async {
      // flutter_test's own HttpClient answers 400 for everything, which
      // is a NetworkImageLoadException — the file is wrong, the host is
      // fine. Muting fydt.org because one song's cover moved would hide
      // artwork that works.
      await tester.pumpWidget(host('https://fydt.org/art/moved.jpg'));
      await tester.pumpAndSettle();

      expect(RemoteImage.failureCount, 1);
      expect(RemoteImage.hostFailureCount, 0,
          reason: 'an HTTP status is not a host-level failure');

      await tester.pumpWidget(host('https://fydt.org/art/present.jpg'));
      await tester.pump();
      expect(find.byType(Image), findsOneWidget,
          reason: 'other covers on that host must still be attempted');
    });
  });
}
