import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The web build must stay INSTALLABLE, which means a service worker
/// with a fetch handler has to survive a page load and control
/// start_url — that is Chrome's precondition for firing
/// `beforeinstallprompt` at all.
///
/// 2026-08-24, from the user: 「网页版安装install也安不上」. Reproduced in
/// a browser against the live dev site: `getRegistrations()` returned 0
/// after a full load, so `beforeinstallprompt` never fired and the
/// in-app Install button — correctly — reported nothing available.
///
/// The cause was never the manifest. It was two things in web/:
///   1. the self-heal sweep in index.html unregistered every worker on
///      every load, and
///   2. even once narrowed, the only worker in play was Flutter's —
///      and `flutter build web` on Flutter 3.44 overwrites
///      flutter_service_worker.js with a stub that unregisters itself
///      (offline-first generation was removed upstream; this Flutter
///      has no `--pwa-strategy` flag to bring it back).
///
/// So the app ships its own worker, web/app_shell_sw.js. These tests
/// pin the properties that make it correct — above all that it is
/// NETWORK FIRST. A cache-first or stale-while-revalidate shell is the
/// stale-worker incident this repo already lived through, and is the
/// reason the self-heal block exists at all.
void main() {
  late final String indexHtml = File('web/index.html').readAsStringSync();
  late final String bootstrap = codeOnly(
      File('web/flutter_bootstrap.js').readAsStringSync());
  // Comments stripped before anything is asserted about SHAPE. These
  // files document their own history at length — the worker's header
  // has to name `cache-first`, `unregister()` and `song-media` in order
  // to explain why it does none of them — and a test that cannot tell a
  // warning from an instruction would fail on the explanation itself.
  late final String sw =
      codeOnly(File('web/app_shell_sw.js').readAsStringSync());

  /// Everything from the fetch listener onward: the listener itself
  /// plus the two helpers it calls.
  String fetchRegion() {
    final int i = sw.indexOf("self.addEventListener('fetch'");
    expect(i, greaterThan(-1),
        reason: 'the worker must handle fetch — a worker with no fetch '
            'handler does not make an app installable');
    return sw.substring(i);
  }

  group('app-shell service worker', () {
    test('exists and is a real worker, not a tombstone', () {
      expect(File('web/app_shell_sw.js').existsSync(), isTrue);
      // The failure mode being fixed: Flutter's generated stub, whose
      // whole body is unregister-and-reload. Ours must never do that.
      expect(sw, isNot(contains('registration.unregister()')),
          reason: 'a worker that unregisters itself is exactly the stub '
              'that left the app uninstallable');
      expect(sw, contains("self.addEventListener('install'"));
      expect(sw, contains("self.addEventListener('activate'"));
    });

    test('is NETWORK FIRST: fetch is attempted before any cache read', () {
      final String region = fetchRegion();
      final int network = region.indexOf('await fetch(');
      final int cacheRead = region.indexOf(RegExp(r'caches?\.match\('));

      expect(network, greaterThan(-1),
          reason: 'the request must be attempted on the network');
      expect(cacheRead, greaterThan(-1),
          reason: 'the cache must still be the offline fallback');
      expect(network, lessThan(cacheRead),
          reason: 'NETWORK FIRST is the whole contract: an online user '
              'must never be handed a cached app shell. Reading the '
              'cache before the network is the stale-shell incident '
              'this repo already had.');

      // The cache read must be reachable only from the failure path.
      final int catchIdx = region.indexOf('} catch (err) {');
      expect(catchIdx, greaterThan(-1),
          reason: 'the fallback has to hang off a catch, not run '
              'unconditionally');
      expect(cacheRead, greaterThan(catchIdx),
          reason: 'the cache may only be consulted after fetch threw');

      for (final String banned in <String>[
        'stale-while-revalidate',
        'cachefirst',
        'cache-first',
      ]) {
        expect(sw.toLowerCase(), isNot(contains(banned)),
            reason: '$banned is the pattern that served users a stale '
                'shell; it must not come back');
      }
    });

    test('never intercepts cross-origin requests', () {
      final String region = fetchRegion();
      expect(region, contains('url.origin !== self.location.origin'),
          reason: 'the church media hosts, YouTube, gstatic/CanvasKit '
              'and Firebase must reach the network untouched');
      // The guard has to bail out of the handler entirely (no
      // respondWith), not fall through into caching.
      final int guard = region.indexOf('url.origin !== self.location.origin');
      final int respond = region.indexOf('event.respondWith(');
      expect(respond, greaterThan(-1));
      expect(guard, lessThan(respond),
          reason: 'cross-origin must be rejected before respondWith');
    });

    test('never touches /song-media/, the API, or the auth proxy', () {
      // /song-media/* is the netlify.toml proxy in front of the church
      // media hosts: ~5 MB mp3s, Range requests, and offline audio that
      // lib/services/song_download_web.dart manages by itself.
      expect(sw, contains("'/song-media/'"));
      expect(sw, contains("'/api/'"));
      expect(sw, contains("'/.netlify/'"));
      expect(sw, contains("'/__/auth/'"));

      final String region = fetchRegion();
      expect(region, contains('BYPASS_PREFIXES'),
          reason: 'the bypass list must actually be consulted in fetch');
      final int bypass = region.indexOf('BYPASS_PREFIXES');
      final int respond = region.indexOf('event.respondWith(');
      expect(bypass, lessThan(respond),
          reason: 'bypassed paths must never reach respondWith');

      // Range requests are partial content; Cache Storage cannot serve
      // them and must not see them.
      expect(region, contains("request.headers.has('range')"));
    });

    test('pre-caches a MINIMAL shell only', () {
      final int start = sw.indexOf('const SHELL_URLS = [');
      expect(start, greaterThan(-1));
      final String list = sw.substring(start, sw.indexOf('];', start));

      // The reason this list is short: a bloated precache fails
      // install, and a failed install means no worker at all.
      for (final String heavy in <String>[
        'main.dart.js',
        'canvaskit',
        'flutter_bootstrap.js',
        'assets/',
      ]) {
        expect(list, isNot(contains(heavy)),
            reason: '$heavy is far too large to pre-cache; install would '
                'fail and the app would go back to uninstallable');
      }
      expect(list, contains('index.html'));
      expect(list, contains('manifest.json'));
      expect("'".allMatches(list).length ~/ 2, lessThanOrEqualTo(8),
          reason: 'keep the shell minimal');
    });

    test('activate rotates only our own caches and claims clients', () {
      final int i = sw.indexOf("self.addEventListener('activate'");
      final String region =
          sw.substring(i, sw.indexOf("self.addEventListener('fetch'"));
      expect(region, contains('CACHE_PREFIX'));
      expect(region, contains('k !== CACHE_NAME'),
          reason: 'older builds of OUR cache go, the current one stays');
      expect(region, contains('self.clients.claim()'));
      // Deleting every bucket would take the song-media downloads with
      // it — the exemption the index.html sweep has always had.
      expect(region, isNot(contains('song-media')),
          reason: 'activate must not reach outside the shell prefix, so '
              'it has no business naming the media bucket');
      expect(region, isNot(contains('client.navigate')),
          reason: 'forced reloads on activate are the stub behaviour');
    });

    test('the cache name carries the build version', () {
      expect(sw, contains("searchParams.get('v')"),
          reason: 'the version arrives on the script URL from the '
              'registration in index.html');
      expect(sw, contains('CACHE_PREFIX + SHELL_VERSION'),
          reason: 'a deploy must rotate the cache name');
    });
  });

  group('web/index.html', () {
    test('registers the app-shell worker, chained AFTER the sweep', () {
      final int sweep =
          indexHtml.indexOf('Promise.all([swPromise, cachePromise])');
      final int register =
          indexHtml.indexOf('navigator.serviceWorker.register(');
      expect(sweep, greaterThan(-1));
      expect(register, greaterThan(-1),
          reason: 'nothing registered a worker — the original bug');
      expect(register, greaterThan(sweep),
          reason: 'registering in parallel with the sweep is a race the '
              'sweep can win, unregistering the worker we just asked for');
      expect(indexHtml, contains("'app_shell_sw.js?v='"),
          reason: 'the ?v= is what makes a deploy install the new worker');
      expect(indexHtml, contains("fetch('version.json'"),
          reason: 'the version comes from the build, not a hand-edit');
    });

    test('the sweep spares OUR worker and nothing else', () {
      expect(indexHtml, contains("var OUR_SW = 'app_shell_sw.js';"),
          reason: 'the sweep must recognise the worker it may not touch');
      expect(indexHtml, contains('url.indexOf(OUR_SW) === -1'),
          reason: 'everything that is not ours still gets unregistered — '
              'that is the stale-shell protection this block exists for');
      expect(indexHtml.contains('var stale = regs;'), isFalse,
          reason: 'an unfiltered sweep is the defect: it unregisters the '
              'worker that makes the app installable');
      // Flutter's stub must no longer be registered: it unregisters
      // itself, so nothing was ever gained by keeping it in play.
      expect(indexHtml,
          isNot(contains("register('flutter_service_worker.js")),
          reason: 'the self-unregistering stub must not be registered');
    });

    test('the cache sweep spares the shell bucket the worker fills', () {
      // Cross-file pin: index.html deletes every cache bucket on every
      // load, so it has to know the worker's prefix by its real value.
      final RegExpMatch? m =
          RegExp(r"CACHE_PREFIX = '([^']+)'").firstMatch(sw);
      expect(m, isNotNull);
      final String prefix = m!.group(1)!;
      expect(indexHtml, contains("SHELL_CACHE_PREFIX = '$prefix'"),
          reason: 'without this exemption the shell cache is deleted on '
              'every load and offline support silently never works');
      expect(indexHtml, contains('k.indexOf(SHELL_CACHE_PREFIX) !== 0'),
          reason: 'the exemption must be applied in the filter, not just '
              'declared');
      // The media bucket's exemption predates ours and stays.
      expect(indexHtml, contains('k.indexOf(MEDIA_CACHE_PREFIX) !== 0'));
    });
  });

  test("flutter_bootstrap.js does not register Flutter's stub", () {
    // Flutter's default bootstrap passes serviceWorkerSettings, which
    // registers /flutter_service_worker.js?v=… at scope '/' on every
    // load. One scope holds one script, so that registration would
    // replace ours (or be replaced by it) at random on every visit —
    // and when the stub wins it deletes every cache and reloads the
    // tab. Overriding the bootstrap is what keeps scope '/' ours.
    expect(bootstrap, isNot(contains('serviceWorkerSettings')));
    expect(bootstrap, contains('{{flutter_js}}'));
    expect(bootstrap, contains('{{flutter_build_config}}'));
    expect(bootstrap, contains('_flutter.loader.load();'));
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

    // Every icon the manifest promises must actually exist: the worker
    // pre-caches them, and a missing entry is one more way for install
    // to fail.
    for (final icon in m['icons'] as List) {
      final String src = (icon as Map)['src'] as String;
      expect(File('web/$src').existsSync(), isTrue,
          reason: 'manifest names $src but web/$src is missing');
    }
  });
}

/// Drops whole-line `//` comments. Deliberately naive: it does NOT try
/// to parse strings, which is safe only because web/app_shell_sw.js and
/// web/flutter_bootstrap.js keep every comment on its own line. Keep
/// them that way, or teach this helper to do better.
String codeOnly(String source) => source
    .split('\n')
    .where((String line) => !line.trimLeft().startsWith('//'))
    .join('\n');
