import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:yswords/services/projection_broadcast.dart';
import 'package:yswords/services/projection_broadcast_io.dart';

/// The desktop follower — `projection_broadcast_io.dart`.
///
/// The web half gets a BroadcastChannel between two windows of one
/// origin. A desktop has no second window (Flutter has no multi-window
/// API, and the engine it would need is the one the projector page
/// rejected), so the app becomes the origin: a loopback socket serving
/// the very same `web/stage.html`, pushing the very same frames.
///
/// These exercise the real server over a real socket. It is a listening
/// socket inside a Bible app, so the security shape is pinned as hard as
/// the behaviour.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProjectionFrame frame(String reference) => ProjectionFrame(
        blank: false,
        typeSize: 76,
        reference: reference,
        tags: const <String>[],
        verses: const <Map<String, String>>[
          {'label': '4', 'text': '他被挂在木头上'},
        ],
        second: null,
        secondNote: null,
        groundColors: const <String>['#000000'],
        radial: false,
        ink: '#ffffff',
        muted: '#888888',
      );

  // flutter_test installs an HttpOverrides that answers every request
  // with 400 and never opens a socket — the right default for a widget
  // test, and the wrong one for a test whose subject IS a socket. These
  // talk to a server in this same process, on loopback.
  late HttpOverrides? saved;
  setUp(() {
    saved = HttpOverrides.current;
    HttpOverrides.global = null;
  });
  tearDown(() {
    HttpOverrides.global = saved;
    ProjectionBroadcast.close();
  });

  test('the desktop half is what this platform resolves to', () {
    expect(ProjectionBroadcast.isSupported, isTrue,
        reason: 'these tests run on a desktop');
  });

  test('serves the page the web build publishes, byte for byte', () async {
    final url = await projectionBroadcastStart();
    expect(url, isNotNull);
    final res = await _get(Uri.parse(url!));
    expect(res.statusCode, 200);
    expect(res.body, File('web/stage.html').readAsStringSync(),
        reason: 'one follower page, not a native copy of it to drift');
    expect(url, contains('?ws=ws'),
        reason: 'the page decides its wire from how it was opened');
  });

  test('binds loopback only', () async {
    await projectionBroadcastStart();
    expect(Uri.parse(projectionStageUrl!).host, '127.0.0.1');
  });

  test('a caller without the token gets nothing', () async {
    final url = Uri.parse((await projectionBroadcastStart())!);
    final origin = Uri.parse('http://${url.host}:${url.port}');
    for (final path in <String>[
      '/stage.html',
      '/${'0' * 32}/stage.html',
      '/ws',
    ]) {
      expect((await _get(origin.replace(path: path))).statusCode, 404,
          reason: '$path should not be reachable');
    }
  });

  test('serves the font it needs and nothing else out of the bundle',
      () async {
    final url = Uri.parse((await projectionBroadcastStart())!);
    final token = url.pathSegments.first;
    expect(
        (await _get(url.replace(
                path: '/$token/assets/assets/fonts/NotoSansSC-YsWords.otf',
                query: '')))
            .statusCode,
        200);
    // The whitelist is the point: a projector page is not a file server.
    for (final path in <String>[
      '/$token/assets/assets/cuvs-yhwh.json',
      '/$token/pubspec.yaml',
      '/$token/../../etc/passwd',
    ]) {
      expect((await _get(url.replace(path: path, query: ''))).statusCode, 404,
          reason: path);
    }
  });

  test('a follower that arrives late is sent the wall it missed', () async {
    final url = Uri.parse((await projectionBroadcastStart())!);
    ProjectionBroadcast.post(frame('加拉太书 3:13'));

    final sock = await WebSocket.connect(
        'ws://${url.host}:${url.port}/${url.pathSegments.first}/ws');
    final first = await sock.first.timeout(const Duration(seconds: 5));
    expect(jsonDecode(first as String)['reference'], '加拉太书 3:13');
    await sock.close();
  });

  test('every later frame reaches the follower, and only changed ones',
      () async {
    final url = Uri.parse((await projectionBroadcastStart())!);
    final sock = await WebSocket.connect(
        'ws://${url.host}:${url.port}/${url.pathSegments.first}/ws');
    final seen = <String>[];
    sock.listen((Object? m) => seen.add(
        jsonDecode(m! as String)['reference'] as String));

    ProjectionBroadcast.post(frame('彼得前书 2:24'));
    ProjectionBroadcast.post(frame('彼得前书 2:24'));
    ProjectionBroadcast.post(frame('以赛亚书 53:5'));
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(seen, <String>['彼得前书 2:24', '以赛亚书 53:5'],
        reason: 'a repeated frame is a repaint nobody asked for');
    await sock.close();
  });

  test('closing takes the socket down with it', () async {
    final url = Uri.parse((await projectionBroadcastStart())!);
    ProjectionBroadcast.close();
    expect(projectionStageUrl, isNull);
    await expectLater(
        _get(url), throwsA(isA<SocketException>()));
  });
}

Future<({int statusCode, String body})> _get(Uri url) async {
  final client = HttpClient();
  try {
    final req = await client.getUrl(url);
    final res = await req.close();
    // allowMalformed: one of these responses is an OpenType font.
    final bytes = <int>[for (final chunk in await res.toList()) ...chunk];
    final body = const Utf8Decoder(allowMalformed: true).convert(bytes);
    return (statusCode: res.statusCode, body: body);
  } finally {
    client.close(force: true);
  }
}
