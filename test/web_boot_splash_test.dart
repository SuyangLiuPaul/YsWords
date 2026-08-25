import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The web shell must show something while Flutter boots.
///
/// 2026-08-25, from the user: "dev site我加在桌面上就打开一直是白的
/// webapp". The app was not broken. Measured on an iPhone 17 Pro
/// simulator against yswords-dev — first in Safari, then as a
/// home-screen web app — a cold first load takes over twenty seconds
/// (CanvasKit, main.dart.js, fonts) and until this change `<body>` held
/// nothing but scripts, so the page was a blank sheet of colour for all
/// of it. Twenty blank seconds is indistinguishable from broken, and in
/// standalone mode there is not even a browser progress bar to hint
/// otherwise, so people close it before it ever arrives.
///
/// The risk a splash introduces is the opposite one: a loading screen
/// that outlives the app it covers hides a working app completely. So
/// it has three independent ways out, and these tests pin all three.
void main() {
  late String html;

  setUpAll(() {
    html = File('web/index.html').readAsStringSync();
  });

  test('the shell paints a splash before any script runs', () {
    // In the markup, not injected by JS: it must be on screen at first
    // paint, which is the whole point.
    expect(html, contains('id="ys-boot"'));
    final bodyAt = html.indexOf('<body>');
    final splashAt = html.indexOf('id="ys-boot"');
    // The TAG, not the first mention: the filename also appears in the
    // comments above, which would make this assertion pass on the wrong
    // occurrence.
    final bootstrapAt = html.indexOf('<script src="flutter_bootstrap.js"');
    expect(bodyAt, greaterThan(-1));
    expect(splashAt, greaterThan(bodyAt));
    expect(splashAt, lessThan(bootstrapAt),
        reason: 'the splash must exist before the bootstrap tag, or the '
            'first paint is still blank');
  });

  test('it needs nothing from the network but a same-origin icon', () {
    final splash = html.substring(html.indexOf('id="ys-boot"'),
        html.indexOf('<script src="flutter_bootstrap.js"'));
    // A loading screen that waits on the network is the bug it fixes.
    expect(splash, isNot(contains('http://')));
    expect(splash, isNot(contains('https://')));
    expect(splash, contains('icons/Icon-192.png'));
  });

  group('three independent ways to dismiss it', () {
    test('1 — the engine first-frame event', () {
      expect(html, contains("addEventListener('flutter-first-frame'"));
    });

    test('2 — a poll for the rendered view, if that event ever changes', () {
      expect(html, contains('flutter-view, flt-glass-pane'));
      expect(html, contains('setInterval'));
    });

    test('3 — a hard deadline, so it can never outlive a working app', () {
      expect(html, contains('90000'),
          reason: 'the unconditional removal timeout is gone');
    });
  });

  test('a slow load explains itself and offers the existing escape hatch', () {
    expect(html, contains('15000'));
    // yswordsClearCacheAndReload already exists in this file for the
    // Settings "clear cache" action; the splash reuses it rather than
    // inventing a second recovery path that could drift from it.
    expect(html, contains('yswordsClearCacheAndReload'));
    // Said in the reader's own language — a stuck loader is precisely
    // when English-only text helps least.
    expect(html, contains('清除缓存并重试'));
  });
}
