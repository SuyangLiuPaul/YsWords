import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `android/app/src/main/AndroidManifest.xml` must declare INTERNET
/// itself, not inherit it.
///
/// Until 2026-09-05 it did not. The release APK had network anyway,
/// through the Android manifest merger: `google_sign_in_android`
/// declares INTERNET in its own manifest, and it is the ONLY Android
/// plugin this app resolves that does. The merge blame report says so
/// in one line —
/// `build/app/intermediates/manifest_merge_blame_file/intlRelease/processIntlReleaseMainManifest/manifest-merger-blame-intl-release-report.txt`
/// attributes merged line 42 to `[:google_sign_in_android]` and to
/// nothing else.
///
/// That made every network feature in the app — the songs catalogue,
/// the sermon MP3s, Firebase, the illustration CDN — a downstream
/// effect of keeping a sign-in plugin. Removing or swapping it takes
/// the whole network away on Android, and takes it away **silently**:
/// the build is green, `flutter analyze` is green (it does not read
/// manifests), and it does not reproduce while developing, because the
/// stock Flutter template already declares INTERNET in the `debug` and
/// `profile` manifests and only `main` was missing it.
///
/// The sibling app Yahweh's World shipped that failure three times.
/// This test is the pin so this app does not ship it once.
///
/// **The assertions run against comment-stripped XML on purpose.** The
/// manifest's own explanatory comment contains the word INTERNET, so a
/// plain substring search over the raw file would pass even if the
/// `<uses-permission>` element were deleted — a test that cannot fail
/// is not a test.
void main() {
  final mainManifest = File('android/app/src/main/AndroidManifest.xml');

  /// The manifest with every `<!-- … -->` block removed.
  String declarations(File f) {
    expect(f.existsSync(), isTrue,
        reason: '${f.path} moved — update this guard');
    return f
        .readAsStringSync()
        .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
  }

  /// Matches a real `<uses-permission>` element naming [permission],
  /// with attributes in either order and any whitespace.
  bool declares(String xml, String permission) => RegExp(
        '<uses-permission[^>]*android:name\\s*=\\s*'
        '"android\\.permission\\.$permission"[^>]*/?>',
      ).hasMatch(xml);

  test('the main manifest declares INTERNET itself', () {
    expect(
      declares(declarations(mainManifest), 'INTERNET'),
      isTrue,
      reason: 'android/app/src/main/AndroidManifest.xml no longer declares '
          'android.permission.INTERNET. Do not "fix" this by checking the '
          'merged manifest — the merged manifest gets it from '
          'google_sign_in_android, and that is exactly the dependency this '
          'declaration exists to remove.',
    );
  });

  test('INTERNET is declared at manifest level, not inside <application>', () {
    // A <uses-permission> nested in <application> is ignored by the
    // platform and warned about, not errored — so it would fail the
    // same way the missing declaration did: silently, at runtime, on a
    // green build.
    final xml = declarations(mainManifest);
    final appStart = xml.indexOf('<application');
    expect(appStart, greaterThan(-1),
        reason: 'no <application> element — manifest reshaped');
    expect(
      declares(xml.substring(0, appStart), 'INTERNET'),
      isTrue,
      reason: 'INTERNET moved below <application>; a nested '
          '<uses-permission> is not granted.',
    );
  });

  test('the permissions the app already relied on are still declared', () {
    // Guards the edit that added INTERNET: a hand-edit to the top of
    // this file is exactly where a sibling <uses-permission> gets lost.
    final xml = declarations(mainManifest);
    for (final p in const [
      'POST_NOTIFICATIONS',
      'FOREGROUND_SERVICE',
      'FOREGROUND_SERVICE_MEDIA_PLAYBACK',
      'WAKE_LOCK',
    ]) {
      expect(declares(xml, p), isTrue,
          reason: '$p was dropped from the main manifest');
    }
  });

  test('network permission does not depend on the sign-in plugin', () {
    // The property under test stated as the fact it protects: with
    // google_sign_in_android's contribution ignored, the app still
    // asks for INTERNET. `main` is the only source set that ships in
    // a release build — debug/ and profile/ do not — so it is the only
    // one that can carry this.
    final debug = File('android/app/src/debug/AndroidManifest.xml');
    final profile = File('android/app/src/profile/AndroidManifest.xml');
    for (final f in [debug, profile]) {
      if (!f.existsSync()) continue;
      expect(declares(declarations(f), 'INTERNET'), isTrue,
          reason: '${f.path} lost INTERNET; harmless for release, but it '
              'means the template layout changed — re-read this test.');
    }
    expect(declares(declarations(mainManifest), 'INTERNET'), isTrue,
        reason: 'release builds use only the main source set');
  });
}
