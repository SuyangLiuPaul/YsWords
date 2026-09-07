/// The URL the app was opened at, snapshotted before the engine runs.
///
/// **Why this exists.** `main()` has snapshotted the boot *hash* since
/// v1.3.61, for a reason written on `captureBootHash`: "by first frame,
/// Flutter web reports the initial route and overwrites the URL
/// fragment, losing any shared link before UrlSyncService.init gets to
/// read it."
///
/// The share *queries* — `?song=`, `?sermon=`, `?verse=` — never got
/// the same treatment. `_handleDeepLink` reads a LIVE `Uri.base`, and
/// it reads it when the splash is dismissed, which is seconds into the
/// boot and after the engine's own history write, after
/// `restoreState`, and after `FetchVerses`/`FetchBooks` — 1.5 s of that
/// on the iPhone whose report prompted this. A URL rewrite anywhere in
/// that window takes the link with it, and the failure is silent: the
/// app opens on the Dashboard looking like a normal cold start.
///
/// That window is why this is a snapshot rather than a live read. It is
/// not a claim about which rewrite does it — it is the removal of the
/// window in which any of them could.
///
/// Kept separate from `url_sync_service_web.dart` so it needs no
/// conditional import: `Uri.base` is `window.location.href` on web and
/// the process's working directory on native, so the capture is
/// harmless off-web and the tests run on the VM.
library;

Uri? _bootUri;

/// Snapshot [Uri.base]. Call synchronously at the top of `main()`,
/// before `runApp`.
void captureBootUri() {
  try {
    _bootUri = Uri.base;
  } catch (_) {
    // A platform with no notion of a base URI. Callers fall back to
    // reading it live, which is what they did before this existed.
    _bootUri = null;
  }
}

/// The query the app was launched with.
///
/// Falls back to a live `Uri.base` when [captureBootUri] never ran (a
/// widget test that pumps a page directly, say) so this can only ever
/// be as good as the old behaviour, never worse.
Map<String, String> bootQueryParameters() {
  final captured = _bootUri;
  if (captured != null) return captured.queryParameters;
  try {
    return Uri.base.queryParameters;
  } catch (_) {
    return const {};
  }
}

/// Test-only: forget the snapshot, so a test can assert the fallback.
void resetBootUriForTest() => _bootUri = null;

/// Test-only: pretend the app was launched at [uri].
void setBootUriForTest(Uri uri) => _bootUri = uri;
