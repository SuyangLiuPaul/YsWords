// The boot splash repairs itself now. These are the guarantees that
// `tools/check_boot_autorecover.js` cannot make, because they are about
// the page around the decision rather than the decision itself.
//
// 2026-08-31, from the user, with a photo of a phone parked on the
// splash and the recovery link circled in red: 「even some people don't
// know they need to click here」. The link stays — this is a supplement
// to it, not a replacement, and it deliberately fails closed in any
// browser that cannot hold the loop latch.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final html = File('web/index.html').readAsStringSync();

  test('the recovery decision exists and is actually driven', () {
    // If the function is renamed, check_boot_autorecover.js exits 2 and
    // says so; this makes `flutter test` alone notice too.
    expect(html, contains('function ysShouldAutoRecover(s)'),
        reason: 'the extracted decision the node harness tests is gone');
    // A pure function nothing calls is not a recovery.
    expect(html, contains('ysShouldAutoRecover({'),
        reason: 'nothing calls ysShouldAutoRecover — the splash will sit '
            'there exactly as it did before');
  });

  test('one attempt per tab: the latch is set before the reload', () {
    final latchAt = html.indexOf("sessionStorage.setItem(LATCH");
    final reloadAt = html.indexOf('yswordsClearCacheAndReload();',
        html.indexOf('function ysShouldAutoRecover'));
    expect(latchAt, greaterThan(0), reason: 'the loop latch is not written');
    expect(reloadAt, greaterThan(latchAt),
        reason: 'the page reloads before recording that it tried — the '
            'latch would never survive, and a page this cannot fix '
            'would reload forever');
  });

  test('the manual link survives', () {
    // Auto-recovery fails CLOSED where sessionStorage throws (private
    // Safari). Those users have nothing but the link.
    expect(html, contains('清除缓存并重试'));
    expect(html, contains('clear the cache and retry'));
  });

  test("clearing the cache does not delete the user's downloaded songs",
      () {
    // This helper used to wipe EVERY Cache Storage bucket. That was
    // defensible while it only ran on a deliberate tap; it is now the
    // automatic boot recovery too, and silently destroying someone's
    // offline music to repair an app shell — which the music has
    // nothing to do with — is a harm they never agreed to and would
    // never connect to what they did.
    // Anchor on the assignment, not the name: the name also appears in
    // a comment further up the file, and matching that would read the
    // wrong block entirely.
    final start =
        html.indexOf('window.yswordsClearCacheAndReload = async function');
    expect(start, greaterThan(0));
    final body = html.substring(start, html.indexOf('</script>', start));
    expect(body, contains("k.indexOf('song-media-') !== 0"),
        reason: 'yswordsClearCacheAndReload no longer spares song-media-, '
            'so automatic boot recovery now wipes downloaded songs');
  });

  test('the boot-time self-heal still spares downloads and the shell', () {
    // Unchanged by this work, and worth pinning next to the above so the
    // two sweeps cannot drift apart again.
    expect(html, contains("var MEDIA_CACHE_PREFIX = 'song-media-';"));
    expect(html, contains("var SHELL_CACHE_PREFIX = 'yswords-shell-';"));
  });
}
