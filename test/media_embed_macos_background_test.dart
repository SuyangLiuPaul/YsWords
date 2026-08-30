// A macOS user opening a song with an embedded video hit this, on a real
// install running 1.4.169 (reported 2026-08-27):
//
//   UnimplementedError: opaque is not implemented on macOS
//     #0 PlatformWebView.setOpaque
//     #1 WebKitWebViewController.setBackgroundColor
//     #2 WebViewController.setBackgroundColor
//     #3 _MediaEmbedState.initState   ← media_embed_io.dart:54
//
// The trap is that macOS is a LEGITIMATE webview platform — the runtime
// gate in mediaEmbed() admits it on purpose, and should. What it cannot
// know is that one method of that webview is iOS-only:
// webview_flutter_wkwebview implements setBackgroundColor via setOpaque,
// and its macOS half never implements setOpaque. So the call does not
// degrade or no-op; it throws, during initState, every time.
//
// This pins the rule rather than the fix's spelling. Asserting that the
// source contains `!Platform.isMacOS` would pass just as well if someone
// inverted it.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/widgets/media_embed_io.dart';

void main() {
  group('webviewSupportsBackgroundColor', () {
    test('macOS is excluded — setBackgroundColor throws there', () {
      expect(webviewSupportsBackgroundColor('macos'), isFalse,
          reason: 'calling setBackgroundColor on macOS throws '
              'UnimplementedError from PlatformWebView.setOpaque, which '
              'crashes every media embed on the Songs page');
    });

    test('iOS and Android keep it — it suppresses the pre-load white flash',
        () {
      // Not "everything else is true" for its own sake: these are the two
      // platforms where the call does real work, hiding the white frame
      // before _wrapper()'s own `background:#000` has painted.
      expect(webviewSupportsBackgroundColor('ios'), isTrue);
      expect(webviewSupportsBackgroundColor('android'), isTrue);
    });

    test('the string it compares against is the one Platform really emits',
        () {
      // The predicate is only correct if 'macos' is literally what
      // Platform.operatingSystem returns on a Mac — not 'macOS', not
      // 'darwin'. A wrong spelling there restores the crash while every
      // other assertion in this file still passes, which is exactly the
      // kind of silent hole worth closing.
      //
      // CI runs Linux, so this can only be checked when the host IS a
      // Mac. Skipping elsewhere rather than asserting something weaker:
      // a test that pretends to check this on Linux would be worse than
      // one that admits it cannot.
      if (!Platform.isMacOS) {
        markTestSkipped('host is not macOS; cannot observe the real value');
        return;
      }
      expect(Platform.operatingSystem, 'macos');
      expect(webviewSupportsBackgroundColor(Platform.operatingSystem), isFalse,
          reason: 'on this very machine the guard must exclude the call');
    });
  });
}
