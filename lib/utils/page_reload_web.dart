// Web half of `page_reload.dart`.

import 'package:web/web.dart' as web;

/// Reload the current document. See `page_reload.dart` for why this is
/// a plain reload and not `clearCacheAndReload()`.
void reloadPage() {
  try {
    web.window.location.reload();
  } catch (_) {/* best-effort: a failed reload must never throw into the app */}
}

/// sessionStorage prefix for the once-per-tab-per-version auto-reload
/// latch.
const String _kUpdateReloadKey = 'yswords.updateReloadTried.';

/// True when this tab has ALREADY auto-reloaded itself trying to reach
/// [version].
///
/// This latch is what stops a reload loop, and it is not optional.
/// `version.json` and the JS bundle are two separate files behind a
/// CDN; for a short window after a deploy the manifest can report
/// 1.4.176 while the edge still answers `main.dart.js` from the 1.4.175
/// build. Without the latch the app would boot, see a mismatch it
/// cannot resolve, reload, and do it again forever — and the slower the
/// connection, the worse it gets, because every reload throws away
/// bytes already downloaded. Same pathology, and the same fix, as the
/// boot-recovery latch in `clear_cache_helper_web.dart`.
///
/// Per-version, so a genuinely newer deploy still gets its own single
/// attempt. sessionStorage, so it resets when the tab closes.
bool updateReloadAlreadyTried(String version) {
  try {
    return web.window.sessionStorage.getItem('$_kUpdateReloadKey$version') !=
        null;
  } catch (_) {
    // Private-mode Safari throws on storage access. Fail CLOSED —
    // report "already tried", so a browser that cannot hold the latch
    // never auto-reloads rather than risking the loop. The banner
    // still shows and the user can still tap it.
    return true;
  }
}

void markUpdateReloadTried(String version) {
  try {
    web.window.sessionStorage.setItem('$_kUpdateReloadKey$version', '1');
  } catch (_) {/* best-effort */}
}
