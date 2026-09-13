// The projection's second screen, without a second Flutter engine.
//
// `projection_page.dart`'s library doc records why the page is one
// window: a second browser window is a second document, so it boots
// its own Flutter engine, re-parses main.dart.js and re-decodes the
// corpora — a four-second splash in front of a congregation. That
// argument is right, and it is an argument against a second FLUTTER
// window. The follower does not need Flutter. It needs a dark ground,
// a font and some text.
//
// So the follower is `web/stage.html` — a static page a few kilobytes
// long — and this service is the wire between them: a same-origin
// `BroadcastChannel`, which needs no handle, no auth and no CORS. The
// page posts a FRAME (the resolved text, the reference, the ground's
// colours, the type size) every time the wall changes; the follower
// paints it. When a follower opens it says hello and the last frame is
// re-sent, so opening the window late costs nothing.
//
// Native desktops get the same follower by a different wire: the app
// serves that very page from a loopback socket and pushes the same
// frames down a WebSocket — see `projection_broadcast_io.dart`, which
// also says why a second Flutter window is not the answer there either.
// Mobile keeps the one-window design, and the stub keeps the symbols
// resolvable wherever neither half applies.
//
// This is the door `projection_page.dart` said it was leaving open,
// walked through.

import 'projection_broadcast_stub.dart'
    if (dart.library.js_interop) 'projection_broadcast_web.dart'
    if (dart.library.io) 'projection_broadcast_io.dart';

/// What the follower paints. Plain data so it serialises as JSON and so
/// a test can assert on it without a browser.
class ProjectionFrame {
  const ProjectionFrame({
    required this.blank,
    required this.typeSize,
    required this.reference,
    required this.tags,
    required this.verses,
    required this.second,
    required this.secondNote,
    this.countdown,
    this.countdownLabel,
    required this.groundColors,
    required this.radial,
    required this.ink,
    required this.muted,
  });

  final bool blank;
  final double typeSize;
  final String reference;
  final List<String> tags;

  /// `{label, text}` per verse on the wall.
  final List<Map<String, String>> verses;

  /// The second edition, verse for verse, or null when off.
  final List<Map<String, String?>>? second;

  /// One line of apparatus in place of [second] — loading, or missing.
  final String? secondNote;

  /// The countdown, already formatted (`5:00`), when one is running —
  /// the follower shows it INSTEAD of the passage, as the wall does.
  final String? countdown;

  /// The line under it: 「聚会还有」 or 「就要开始了」.
  final String? countdownLabel;

  /// One colour for a flat ground; more for a gradient, centre first.
  final List<String> groundColors;
  final bool radial;
  final String ink;
  final String muted;

  Map<String, Object?> toJson() => {
        'v': 1,
        'blank': blank,
        'typeSize': typeSize,
        'reference': reference,
        'countdown': countdown,
        'countdownLabel': countdownLabel,
        'tags': tags,
        'verses': verses,
        'second': second,
        'secondNote': secondNote,
        'ground': {'colors': groundColors, 'radial': radial},
        'ink': ink,
        'muted': muted,
      };
}

/// The wire. See the library doc.
class ProjectionBroadcast {
  ProjectionBroadcast._();

  /// Whether a follower window is possible at all — true on the web.
  static bool get isSupported => projectionBroadcastSupported;

  /// Open (or focus) the follower window. The operator then drags it
  /// onto the projector's display, exactly as they did with the whole
  /// app before; now the app stays on the laptop.
  static void openStage() => projectionBroadcastOpenStage();

  /// Send the wall's current state. Cheap enough to call from `build`:
  /// a frame that is identical to the last one is not re-sent.
  static void post(ProjectionFrame frame) => projectionBroadcastPost(frame);

  /// Stop listening for followers. Called from the page's dispose.
  static void close() => projectionBroadcastClose();
}
