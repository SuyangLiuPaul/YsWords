/// Single source of truth for the user-visible app version string.
///
/// Bumped manually in lockstep with `pubspec.yaml`'s `version:` field
/// when shipping a new build. Kept here (not derived from
/// `package_info_plus` at runtime) so the AboutPage footer renders a
/// version even before the package-info plugin has initialised, and
/// so tests can assert against a fixed string.
///
/// 2026-05-07 (v17): extracted from settings_page.dart when the
/// "Check for Updates" tile was removed; AboutPage now surfaces this
/// in its footer.
const String kAppVersion = '0.1.0';
