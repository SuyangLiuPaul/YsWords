/// Is this build running on a developer emulator rather than someone's
/// phone?
///
/// 2026-08-25: the user was emailed the same SQLITE_BUSY crash report
/// four times in one evening and asked why it kept arriving. None of
/// them came from a device they own. The autonomous loop had installed
/// the PRE-FIX build (1.4.147) on a headless Android emulator on the
/// developer's own Mac to reproduce the bug — which it did, exactly as
/// intended — and every one of those deliberate reproductions fired a
/// real report at the production reporter, which emails the developer
/// inbox. The reports were correct, actionable, and already acted on;
/// they were simply addressed to someone who had no way to tell test
/// traffic from a user in trouble.
///
/// Dropping rather than tagging: on an emulator the loop reads logcat
/// directly and never needed the email, so tagging would preserve the
/// noise for no gain. The report is not lost, only unmailed.
///
/// Kept free of `dart:io` so the predicate can be unit-tested; the
/// platform files supply the raw strings.
library;

/// Android's `Platform.operatingSystemVersion` carries the build
/// fingerprint, e.g.
///
///     android sdk_phone64_arm64-userdebug 14 UE1A.230829.036.A1 112288
///
/// A shipping device is `-user`; `-userdebug` and `-eng` are developer
/// builds, and the AOSP emulator images additionally name themselves
/// `sdk_*` or `generic_*`. Matching any of those is deliberately broad:
/// a false positive costs one unmailed report from a build no customer
/// runs, a false negative costs the inbox.
bool isSyntheticAndroidOs(String operatingSystemVersion) {
  final s = operatingSystemVersion.toLowerCase();
  return s.contains('sdk_') ||
      s.contains('generic') ||
      s.contains('emulator') ||
      s.contains('-userdebug') ||
      s.contains('-eng ') ||
      s.endsWith('-eng');
}
