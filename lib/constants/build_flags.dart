/// Compile-time build flags. Toggled via `--dart-define=KEY=VALUE`
/// at `flutter build` time so the flutter web bundle ships with
/// the constant baked in (tree-shaken; no runtime cost when off).
///
/// 2026-05-09 (v1.2.0 — China mode): introduced [kChinaMode] so we
/// can ship a second Netlify site (`yswords-cn.netlify.app`) tuned
/// for users behind the Great Firewall.  When `CHINA_MODE=true`:
///
///   • Firebase Auth + RTDB cloud-sync init is **skipped** entirely.
///     Boot is instant instead of waiting 4 s for the watchdog to
///     give up on `*.googleapis.com` / `*.firebaseio.com` (both
///     blocked in mainland China).
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
/// Build commands:
///   • International: `flutter build web --release`
///   • China:        `flutter build web --release --dart-define=CHINA_MODE=true`
const bool kChinaMode = bool.fromEnvironment(
  'CHINA_MODE',
  defaultValue: false,
);
