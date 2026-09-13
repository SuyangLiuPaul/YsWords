// Web half of `projection_broadcast.dart`. See that file's doc.

import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'projection_broadcast.dart' show ProjectionFrame;

/// One channel name for the app; the follower opens the same one.
const String kProjectionChannel = 'yswords-projection';

/// The follower's path, relative to the app's own origin. A static file
/// in `web/`, so it ships inside `build/web` and Netlify serves it
/// before the SPA fallback (a real file wins over `/* /index.html`).
const String kProjectionStagePath = 'stage.html';

web.BroadcastChannel? _channel;
String? _lastJson;

bool get projectionBroadcastSupported => true;

web.BroadcastChannel _open() {
  final existing = _channel;
  if (existing != null) return existing;
  final ch = web.BroadcastChannel(kProjectionChannel);
  // A follower that has just opened asks for the wall; answer with the
  // last frame so it never sits empty waiting for the next key press.
  ch.onmessage = ((web.MessageEvent e) {
    // Only strings ever travel on this channel (JSON frames and the
    // follower's 'hello'), so the cast is safe; it also stays inside the
    // SDK floor pubspec allows, which `isA<JSString>()` does not.
    final data = (e.data as JSString?)?.toDart;
    if (data == 'hello') {
      final last = _lastJson;
      if (last != null) ch.postMessage(last.toJS);
    }
  }).toJS;
  _channel = ch;
  return ch;
}

void projectionBroadcastOpenStage() {
  _open();
  // A named target, so a second press focuses the window that is
  // already there instead of opening another.
  web.window.open(kProjectionStagePath, 'yswords-stage');
}

void projectionBroadcastPost(ProjectionFrame frame) {
  final json = jsonEncode(frame.toJson());
  if (json == _lastJson) return;
  _lastJson = json;
  _open().postMessage(json.toJS);
}

void projectionBroadcastClose() {
  _channel?.close();
  _channel = null;
  _lastJson = null;
}
