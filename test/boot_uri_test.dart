import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:yswords/utils/boot_uri.dart';

/// The share query has to survive the boot, the way the hash already does.
///
/// From the iPhone report on 2026-09-07 — a `?song=` link that ended on
/// the Dashboard, its breadcrumbs showing 1.5 s between
/// `mainProvider.restoreState` and `FetchBooks.execute` before the
/// splash was even dismissed:
///
///     2026-09-07T01:42:02.652Z nav:push   — /
///     2026-09-07T01:42:02.690Z boot:step  — mainProvider.restoreState
///     2026-09-07T01:42:02.691Z boot:step  — FetchVerses.execute
///     2026-09-07T01:42:04.130Z boot:step  — FetchBooks.execute
///
/// `_handleDeepLink` runs after all of that and used to read a LIVE
/// `Uri.base`. The hash has been snapshotted in `main()` since v1.3.61
/// for exactly this reason, written on `captureBootHash`: "by first
/// frame, Flutter web reports the initial route and overwrites the URL
/// fragment, losing any shared link before UrlSyncService.init gets to
/// read it." The query never got the same protection, so it spent that
/// whole window exposed.
void main() {
  tearDown(resetBootUriForTest);

  test('the snapshot wins over whatever the URL says later', () {
    // The whole point, and the VM makes it a real comparison rather than
    // a staged one: `Uri.base` here is the process's working directory,
    // which carries no query at all. So a live read genuinely returns
    // nothing while the snapshot returns the link — which is the shape
    // of the failure being fixed, not an imitation of it.
    expect(Uri.base.queryParameters, isEmpty,
        reason: 'the live read must be the empty one for this to prove '
            'anything');
    setBootUriForTest(Uri.parse('https://host/?song=cdc%3Ad0180'));
    expect(bootQueryParameters()['song'], 'cdc:d0180');
  });

  test('every share query the app knows survives, not just song', () {
    setBootUriForTest(Uri.parse(
        'https://host/?sermon=fy-cm03&verse=John:3:16&song=cgdc%3A2026-04'));
    final p = bootQueryParameters();
    expect(p['sermon'], 'fy-cm03');
    expect(p['verse'], 'John:3:16');
    expect(p['song'], 'cgdc:2026-04');
  });

  test('with no snapshot it falls back to the live read', () {
    // So this can only ever be as good as the old behaviour, never
    // worse — a widget test that pumps a page without going through
    // main() still gets an answer instead of an exception.
    resetBootUriForTest();
    expect(bootQueryParameters(), isEmpty);
  });

  test('main() takes the snapshot beside the hash one, before runApp', () {
    // Order is the assertion. A capture that runs after `runApp` is a
    // capture of whatever the engine left behind, which is the thing
    // this is defending against.
    final src = File('lib/main.dart').readAsStringSync();
    final hash = src.indexOf('UrlSyncService.captureBootHash();');
    final query = src.indexOf('captureBootUri();');
    final runApp = src.indexOf('runApp(');
    expect(hash, greaterThan(-1));
    expect(query, greaterThan(-1), reason: 'main() must snapshot the query');
    expect(runApp, greaterThan(-1));
    expect(query, greaterThan(hash),
        reason: 'the two captures belong together');
    expect(query, lessThan(runApp),
        reason: 'capturing after runApp captures the engine\'s rewrite, '
            'not the URL the user opened');
  });

  test('the deep-link handler reads the snapshot, not only the live URL',
      () {
    // The wiring, which the unit tests above cannot see: `_handleDeepLink`
    // built its `params` from `uri.queryParameters` alone until now.
    final src = File('lib/main.dart').readAsStringSync();
    final start = src.indexOf('Future<void> _handleDeepLink()');
    expect(start, greaterThan(-1));
    final body = src.substring(start, src.indexOf('final verse =', start));
    expect(body, contains('bootQueryParameters()'),
        reason: 'reading a live Uri.base here is what lost the link');
  });

  test('bootHasShareLink sees each kind, and stays false without one', () {
    for (final k in kShareLinkQueryKeys) {
      setBootUriForTest(Uri.parse('https://host/?$k=x'));
      expect(bootHasShareLink(), isTrue, reason: k);
    }
    setBootUriForTest(Uri.parse('https://host/'));
    expect(bootHasShareLink(), isFalse);
    setBootUriForTest(Uri.parse('https://host/?song='));
    expect(bootHasShareLink(), isFalse,
        reason: 'an empty value is not a link; `_handleDeepLink` ignores '
            'it too, and a tour stood down for it would be stood down '
            'for nothing');
    setBootUriForTest(Uri.parse('https://host/?utm_source=wechat'));
    expect(bootHasShareLink(), isFalse,
        reason: 'an ordinary tracking query is not a shared link');
  });

  test('the key set is exactly what _handleDeepLink branches on', () {
    // The two live far apart — one acts on these queries, the other
    // stands aside for them — so a fourth share link added to the
    // handler and forgotten here would silently put the onboarding
    // dialog back on top of it.
    final src = File('lib/main.dart').readAsStringSync();
    final start = src.indexOf('Future<void> _handleDeepLink()');
    final end = src.indexOf('@override', start);
    expect(start, greaterThan(-1));
    expect(end, greaterThan(start));
    final body = src.substring(start, end);
    final branched = RegExp(r"params\['(\w+)'\]")
        .allMatches(body)
        .map((m) => m.group(1)!)
        .toSet();
    expect(branched, kShareLinkQueryKeys);
  });

  test('the onboarding tour stands down before it checks "seen"', () {
    // Order matters and is the whole fix: asking `hasSeen()` first and
    // standing down second would still be correct, but standing down
    // AFTER the dialog is shown would not — and the seen-flag is
    // deliberately left unset either way, so the tour returns on the
    // next ordinary visit.
    final src = File('lib/pages/dashboard_page.dart').readAsStringSync();
    final start = src.indexOf('Future<void> _maybeShowOnboarding()');
    expect(start, greaterThan(-1));
    final body = src.substring(start, src.indexOf('\n  }', start));
    final gate = body.indexOf('bootHasShareLink()');
    final show = body.indexOf('showDialog');
    expect(gate, greaterThan(-1),
        reason: 'a shared link must not be met with the first-run tour');
    expect(gate, lessThan(show));
    expect(body, isNot(contains('markSeen')),
        reason: 'standing the tour down is not the same as consuming it');
  });
}
