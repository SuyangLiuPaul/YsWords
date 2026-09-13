// Native half of `projection_broadcast.dart`. See that file's doc for
// why the follower is a static page rather than a second Flutter window.
//
// The web half has a BroadcastChannel: two windows of one origin, no
// handle, no server. A native desktop has neither the second window nor
// the channel — Flutter desktop has no multi-window API, and the one it
// would need is the second engine the projector page rejected in
// writing. So the app becomes the origin: a socket on LOOPBACK ONLY
// serves `web/stage.html` verbatim — the same file, the same painter —
// and pushes the same JSON frames down a WebSocket. The operator's
// browser opens on the projector's display; the app stays on the
// laptop, which is the whole point of a follower.
//
// Three things this is careful about, because "the app starts a web
// server" deserves care:
//
//   * It binds `127.0.0.1` and port 0. Nothing off this machine can
//     reach it, and nothing has to be configured.
//   * Every URL carries a 128-bit token generated per run. Another
//     process on the same machine cannot guess the path, so it cannot
//     read what is on the wall.
//   * It serves a WHITELIST of two files out of the asset bundle, never
//     a path the request supplies. A projector page is not a file
//     server.
//
// Mobile is not supported: a phone has no second display to drag a
// window onto, and starting a listening socket there buys nothing.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;

import 'projection_broadcast.dart' show ProjectionFrame;

/// The follower's page, and the one asset it asks for. The font path is
/// spelled as a Flutter WEB build serves it (`assets/assets/…`) because
/// the page is written for that build; serving the same spelling here
/// means one file works in both places.
const String _kStageAsset = 'web/stage.html';
const String _kFontUrlPath = 'assets/assets/fonts/NotoSansSC-YsWords.otf';
const String _kFontAsset = 'assets/fonts/NotoSansSC-YsWords.otf';

HttpServer? _server;
String? _token;
String? _lastJson;
final Set<WebSocket> _followers = <WebSocket>{};

/// Desktop only — see the header.
bool get projectionBroadcastSupported =>
    Platform.isMacOS || Platform.isWindows || Platform.isLinux;

/// The URL the follower is at, or null before [projectionBroadcastOpenStage].
/// Exposed for tests; the operator never types it.
String? get projectionStageUrl {
  final server = _server;
  final token = _token;
  if (server == null || token == null) return null;
  return 'http://${server.address.address}:${server.port}/$token/stage.html'
      '?ws=ws';
}

/// Start the socket if it is not up, and return the follower's URL.
Future<String?> projectionBroadcastStart() async {
  if (!projectionBroadcastSupported) return null;
  if (_server == null) {
    final rand = Random.secure();
    _token = <String>[
      for (var i = 0; i < 16; i++)
        rand.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen(_serve, onError: (Object _) {});
  }
  return projectionStageUrl;
}

Future<void> _serve(HttpRequest req) async {
  final seg = req.uri.pathSegments;
  final token = _token;
  // The token is the whole of the authorisation. A request without it
  // gets the same 404 as a request for a file that does not exist —
  // nothing here tells a caller which of the two they got wrong.
  if (token == null || seg.isEmpty || seg.first != token) {
    await _notFound(req);
    return;
  }
  final path = seg.skip(1).join('/');

  if (path == 'ws') {
    if (!WebSocketTransformer.isUpgradeRequest(req)) {
      await _notFound(req);
      return;
    }
    final sock = await WebSocketTransformer.upgrade(req);
    _followers.add(sock);
    // The follower that opens after the wall is already up gets the wall
    // it missed, which is what 'hello' does on the web side.
    final last = _lastJson;
    if (last != null) sock.add(last);
    sock.listen(
      (_) {},
      onDone: () => _followers.remove(sock),
      onError: (Object _) => _followers.remove(sock),
      cancelOnError: true,
    );
    return;
  }

  final asset = switch (path) {
    'stage.html' => (_kStageAsset, 'text/html; charset=utf-8'),
    _kFontUrlPath => (_kFontAsset, 'font/otf'),
    _ => null,
  };
  if (asset == null) {
    await _notFound(req);
    return;
  }
  final bytes = (await rootBundle.load(asset.$1)).buffer.asUint8List();
  req.response
    ..statusCode = HttpStatus.ok
    ..headers.set(HttpHeaders.contentTypeHeader, asset.$2)
    ..headers.set(HttpHeaders.cacheControlHeader, 'no-store')
    ..add(bytes);
  await req.response.close();
}

Future<void> _notFound(HttpRequest req) async {
  req.response.statusCode = HttpStatus.notFound;
  await req.response.close();
}

void projectionBroadcastOpenStage() {
  unawaited(() async {
    final url = await projectionBroadcastStart();
    if (url == null) return;
    // No url_launcher in this app — see `link_opener.dart` — and the
    // platform's own opener is one process call.
    final (String exe, List<String> args) = Platform.isMacOS
        ? ('open', <String>[url])
        : Platform.isWindows
            ? ('cmd', <String>['/c', 'start', '', url])
            : ('xdg-open', <String>[url]);
    try {
      await Process.run(exe, args);
    } catch (_) {
      // A desktop with no handler for http is not a crash: the wall in
      // the app window still works, which is where it was before.
    }
  }());
}

void projectionBroadcastPost(ProjectionFrame frame) {
  final json = jsonEncode(frame.toJson());
  if (json == _lastJson) return;
  _lastJson = json;
  for (final sock in _followers.toList()) {
    try {
      sock.add(json);
    } catch (_) {
      _followers.remove(sock);
    }
  }
}

void projectionBroadcastClose() {
  for (final sock in _followers.toList()) {
    unawaited(sock.close());
  }
  _followers.clear();
  unawaited(_server?.close(force: true));
  _server = null;
  _token = null;
  _lastJson = null;
}
