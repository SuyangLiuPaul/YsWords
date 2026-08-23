import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The web build must stay INSTALLABLE, which means Flutter's own
/// service worker has to survive a page load.
///
/// 2026-08-24, from the user: 「网页版安装install也安不上」. Reproduced in
/// a browser against the live dev site: `getRegistrations()` returned 0
/// after a full load, so `beforeinstallprompt` never fired and the
/// in-app Install button — correctly — reported nothing available.
///
/// The cause was in web/index.html, not in the manifest. A self-heal
/// block written to evict a STALE shell worker had been widened to
/// `var stale = regs` — every worker, every load, including the current
/// Flutter one. Offline support died with it, silently, for the same
/// reason.
void main() {
  late final String indexHtml = File('web/index.html').readAsStringSync();

  test('the service-worker sweep spares the current Flutter worker', () {
    // The bug was the absence of a filter, so assert the filter exists
    // and names the worker it must not touch.
    expect(indexHtml, contains('flutter_service_worker.js'),
        reason: 'the sweep must recognise Flutter\'s own worker');
    expect(indexHtml.contains('var stale = regs;'), isFalse,
        reason: 'an unfiltered sweep is exactly the defect: it '
            'unregisters the worker that makes the app installable');
  });

  test('the manifest still meets the installability bar', () {
    // Chrome needs name, start_url, a standalone-ish display mode and
    // 192 + 512 icons. These were verified live and are cheap to keep
    // honest here, so a future manifest edit cannot quietly break
    // install a second way.
    final m = jsonDecode(File('web/manifest.json').readAsStringSync())
        as Map<String, dynamic>;
    expect(m['name'], isNotEmpty);
    expect(m['short_name'], isNotEmpty);
    expect(m['start_url'], isNotNull);
    expect(['standalone', 'fullscreen', 'minimal-ui'],
        contains(m['display']));

    final sizes = (m['icons'] as List)
        .map((i) => (i as Map)['sizes'] as String)
        .toSet();
    expect(sizes, containsAll(<String>['192x192', '512x512']));

    // orientation must stay absent — pinning it letterboxed the app on
    // Android tablets (fixed 2026-08-24).
    expect(m.containsKey('orientation'), isFalse);
  });
}
