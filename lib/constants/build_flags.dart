/// Compile-time build flags. Toggled via `--dart-define=KEY=VALUE`
/// at `flutter build` time so the flutter web bundle ships with
/// the constant baked in (tree-shaken; no runtime cost when off).
///
/// 2026-05-09 (v1.2.0 — China mode): introduced [kChinaMode] so we
/// can ship a second Netlify site (`yswords-cn.netlify.app`) tuned
/// for users behind the Great Firewall.  When `CHINA_MODE=true`:
///
///   • Firebase Auth + RTDB cloud-sync init is **skipped at boot**.
///     Boot is instant instead of waiting 4 s for the watchdog to
///     give up on `*.googleapis.com` / `*.firebaseio.com` (both
///     blocked in mainland China).
///
///     ⚠️ Read "skipped at boot" literally — it is NOT "cloud sync
///     is unavailable in this build". See the 2026-09-06 entry at
///     the bottom of this comment.
///   • Google Fonts options are **hidden from the font picker**.
///     The bundled Roboto + the OS-native CSS font stack already
///     cover every realistic case; downloading from
///     `fonts.googleapis.com` can never succeed in mainland China,
///     and showing dead options just confuses users.
///   • A small "中国版 / China build" badge surfaces on the
///     AboutPage so support requests aren't ambiguous about which
///     build the user is on.
///
/// Things that DO still work in China mode (no flag-gating needed,
/// because the Netlify edge handles them server-side or the data
/// is bundled):
///
///   • All 14 bundled Bibles, search, exegesis, Strong's lexicon,
///     reading plans, sermons, Bible Trivia, Bible Timeline,
///     Family Tree, Songs — all 100% offline.
///   • AI features that run via `/api/aiBibleSearch` etc. — those
///     hit Netlify functions which call Gemini server-to-server,
///     bypassing the GFW.  As long as Netlify itself is reachable
///     (variable in mainland China but usually OK), AI works.
///   • Daily News + Bible Evidence: their JSON lives on
///     `yswords-data.netlify.app` which is the same Netlify
///     infrastructure as the app, so reachability is identical.
///   • BYOK Gemini API key (Settings → YsWords AI) — saves to
///     localStorage exactly like the international build.
///
/// ## 2026-09-06 — email/password sign-in SHIPS in the China build
///
/// This reverses the earlier reading of this flag, and the reason is
/// specific enough to be worth writing down at the point of use.
///
/// The owner verified that **email sign-in works from mainland
/// China**. The two sign-in methods do not share a network surface:
///
///   • **Google sign-in** needs `accounts.google.com` plus the
///     `/__/auth/*` handler that `netlify.toml` reverse-proxies. The
///     account chooser is Google's own page and cannot be proxied,
///     so this method stays gated off in China builds.
///   • **Email/password** never touches that handler. It is one HTTPS
///     call to `identitytoolkit.googleapis.com`, whose reachability
///     from mainland China is *inconsistent* rather than reliably
///     blocked — which is a question to ask the network at the moment
///     the reader asks to sign in, not one to answer by fiat at
///     compile time.
///
/// So `kChinaMode` no longer decides whether a reader may have an
/// account. What it still decides:
///
///   • **Boot cost — unchanged.** `main.dart:538`'s `if (!kChinaMode)`
///     is deliberately untouched. The China build still calls neither
///     `CloudAuthService.init()` nor `RealtimeDbSyncService.init()` at
///     boot, so a reader who never signs in pays zero Firebase
///     latency, exactly as before. Firebase is initialised lazily by
///     `CloudAuthService.ensureInitialized()`, called from the
///     email sign-in form itself and bounded by
///     [CloudAuthService.kLazyInitTimeout]. Boot was measured both
///     ways when this landed; see the handover note for the numbers.
///   • **Google sign-in stays hidden** (`settings_page.dart` gates the
///     Google button, and only that button, on `!kChinaMode`).
///   • **RTDB is still not assumed.** `firebaseio.com` is a different
///     host family from `identitytoolkit.googleapis.com`, so the
///     owner's observation is evidence about Auth and about nothing
///     else. `RealtimeDbSyncService` is started lazily *after* a
///     successful sign-in and the UI never claims sync is working
///     before a round trip has actually completed — it reports a real
///     "Last synced …" timestamp, or it says plainly that the sync
///     server could not be reached and offers Retry. Local storage
///     remains the source of truth either way.
///
/// Two strings that used to assert the opposite —
/// `chinaCloudUnavailable` and `onboardCustomizeBodyChina` — became
/// false for exactly the readers who get this working and no longer
/// drive off this flag.
///
/// Build commands:
///   • International: `flutter build web --release`
///   • China:        `flutter build web --release --dart-define=CHINA_MODE=true`
const bool kChinaMode = bool.fromEnvironment(
  'CHINA_MODE',
  defaultValue: false,
);
