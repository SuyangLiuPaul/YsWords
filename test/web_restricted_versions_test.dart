import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/constants/bible_versions.dart';

/// NASB and LEB are licensed for quotation, not for redistribution of the
/// whole text as a file — and `flutter build web` writes every declared
/// asset into `build/web/assets/assets/`, which made both translations one
/// GET away on prod (measured 2026-09-02: nasb.json 200 / 7,215,432 and
/// leb.json 200 / 8,812,100).
///
/// The hold has **two halves and needs both**:
///
///   1. `kWebRestrictedVersions` — hides the editions from the picker on
///      web, so the app never asks for a file that is not there;
///   2. `strip_restricted_assets` in `tools/release_web.sh` — deletes the
///      files out of `build/web` after every `flutter build web`.
///
/// Half 1 without half 2 is theatre: the file is still there for anyone
/// who knows the URL. Half 2 without half 1 offers the reader an edition
/// that 404s. This test is here because the halves live in two languages
/// in two directories and nothing else connects them.
///
/// The 2026-08-31 prerender exclusion is NOT this. It was built for the
/// same concern and covers `/read/` pages only — it never touched the
/// asset bundle, which is why LEB sat there unnoticed through it.
void main() {
  final script = File('tools/release_web.sh').readAsStringSync();

  test('the script strips exactly the versions the app hides', () {
    final m = RegExp(r'WEB_RESTRICTED_ASSETS=\(([^)]*)\)').firstMatch(script);
    expect(m, isNotNull,
        reason: 'release_web.sh must declare WEB_RESTRICTED_ASSETS — '
            'without it nothing removes the files from build/web');
    final inScript = m!.group(1)!.trim().split(RegExp(r'\s+')).toSet();
    expect(inScript, kWebRestrictedVersions,
        reason: 'the shell list and kWebRestrictedVersions have drifted; '
            'a version in one and not the other is either offered with no '
            'asset, or shipped with no licence');
  });

  test('every `flutter build web` is followed by the strip', () {
    // Two builds run in this script (international, then CHINA_MODE) and
    // each rewrites build/web in place, putting the files back. One call
    // is not enough, and this is exactly how the prerender step is pinned
    // next door.
    // Anchored on the invocation, not the words: the script *discusses*
    // `flutter build web` in seven comments and only runs it twice, and
    // an earlier version of this test counted the prose.
    final builds = RegExp(r'^"\$FLUTTER" build web', multiLine: true)
        .allMatches(script)
        .length;
    expect(builds, greaterThan(0), reason: 'the invocation pattern moved');
    final strips =
        RegExp(r'^strip_restricted_assets$', multiLine: true)
            .allMatches(script)
            .length;
    expect(strips, greaterThanOrEqualTo(builds),
        reason: '$builds `flutter build web` calls but only $strips strip '
            'calls — a build with no strip ships the files');
  });

  test('the strip refuses to continue if the file survives', () {
    expect(script, contains('refusing to deploy'),
        reason: 'a silent rm that failed would deploy the asset anyway');
  });

  test('native builds still carry them — this is a web hold, not a removal',
      () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final v in kWebRestrictedVersions) {
      expect(File('assets/$v.json').existsSync(), isTrue,
          reason: '$v.json was deleted outright; that is the NIV treatment, '
              'and it is a bigger decision than this test guards');
      expect(pubspec, contains('assets/$v.json'));
    }
  });

  test('off web, the picker still offers them', () {
    // These tests run on the VM, where the const `dart.library.js_interop`
    // is false — so this asserts the gate is genuinely web-only and has
    // not accidentally hidden the editions everywhere.
    final codes = availableVersions.map((v) => v.value).toSet();
    for (final v in kWebRestrictedVersions) {
      expect(codes, contains(v));
    }
  });
}
