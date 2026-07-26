// 2026-05-20 (v1.2.67): web impl of `clearCacheAndReload`. Calls
// the `yswordsClearCacheAndReload()` function defined in
// `web/index.html` which unregisters all service workers, nukes
// the browser cache buckets, and hard-reloads the page.

import 'dart:js_interop';

import 'package:web/web.dart' as web;

@JS('yswordsClearCacheAndReload')
external void _yswordsClearCacheAndReload();

void clearCacheAndReload() {
  _yswordsClearCacheAndReload();
}

/// sessionStorage key for the once-per-tab auto-recovery latch below.
const String _kBootRecoveryKey = 'yswords.bootRecoveryTried';

/// 2026-07-26 (v1.3.145): the splash's AUTOMATIC hard reload must fire
/// at most ONCE per browser tab-session.
///
/// Why a latch is mandatory, not just tidy: `clearCacheAndReload()`
/// wipes every HTTP/SW cache bucket and reloads. If the reason boot
/// hadn't finished was simply that the ~1.9 MB of boot assets were
/// still downloading over a slow link, the reload aborts that transfer
/// AND throws away the bytes already fetched, so the next boot restarts
/// from zero — and hits the same deadline again. That's a reload loop
/// the app can never escape, and it gets strictly worse the slower the
/// connection is. Exactly the pathology `FetchVerses`' escalating-
/// timeout comment describes at the request layer, one level up at the
/// page layer.
///
/// sessionStorage (not localStorage) is the right scope: it survives
/// the reload we're about to perform but resets when the tab closes,
/// so a genuinely-stale-cache user still gets one free auto-heal on
/// their next visit.
bool bootRecoveryAlreadyTried() {
  try {
    return web.window.sessionStorage.getItem(_kBootRecoveryKey) != null;
  } catch (_) {
    // Private-mode Safari can throw on storage access. Fail CLOSED —
    // pretend we already tried, so we never risk the loop.
    return true;
  }
}

void markBootRecoveryTried() {
  try {
    web.window.sessionStorage.setItem(_kBootRecoveryKey, '1');
  } catch (_) {/* best-effort */}
}
