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

  test('netlify.toml answers a real 404 for each stripped asset', () {
    // Removing the file is not enough on its own: the SPA catch-all
    // answered /assets/assets/nasb.json with 200 + index.html (53,444
    // bytes of Flutter shell), measured on prod right after v1.4.193.
    // A 200 under a path naming an unlicensed translation is the exact
    // signal this whole change exists to stop sending.
    final toml = File('netlify.toml').readAsStringSync();
    for (final v in kWebRestrictedVersions) {
      final rule = RegExp(
        'from = "/assets/assets/$v\\.json"\\s+to = "[^"]+"\\s+status = 404',
      );
      expect(toml, matches(rule),
          reason: '$v has no 404 redirect in netlify.toml, so its URL '
              'falls through to the SPA fallback and answers 200');
    }
    final spa = toml.indexOf('from = "/*"');
    for (final v in kWebRestrictedVersions) {
      expect(toml.indexOf('from = "/assets/assets/$v.json"'), lessThan(spa),
          reason: 'first match wins — the $v rule must sit ABOVE the '
              'catch-all or it never runs');
    }
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

  group('the boot path — this is the half v1.4.193 shipped without', () {
    // Hiding the editions from the picker was not enough and cost a boot
    // crash: `restoreState` sets currentVersion from SharedPreferences or
    // from a locale default ('en' → 'nasb'), neither of which goes near
    // the picker. Boot reached rootBundle.loadString('assets/nasb.json'),
    // threw *Unable to load asset*, and the app never painted. Reported
    // from dev, cn-dev, cn-qat and prod within ten minutes.
    final provider = File('lib/providers/main_provider.dart').readAsStringSync();

    test('no bare restricted code is ever assigned as the version', () {
      for (final v in kWebRestrictedVersions) {
        // The exact shape of the original bug, both occurrences:
        //   currentVersion = 'nasb';
        //   v = 'nasb';
        final bare = RegExp(
          "(currentVersion|\\bv)\\s*=\\s*'$v'\\s*;",
        );
        expect(provider, isNot(matches(bare)),
            reason: "main_provider assigns '$v' directly. On web that "
                'asset is stripped and the app cannot boot. Wrap it in '
                'resolvableVersion().');
        expect(provider,
            isNot(contains("setString('\${_storagePrefix}version', '$v')")),
            reason: 'persisting an unloadable code makes one bad boot '
                'permanent');
      }
    });

    test('every version the boot path chooses goes through the guard', () {
      // The locale switch is where a fresh English install is decided.
      expect(provider, contains("resolvableVersion('nasb')"));
      expect(provider, contains('currentVersion = resolvableVersion(v)'),
          reason: 'a version restored from storage is the other half — a '
              'reader who last opened NASB on the web before the strip');
    });

    test('resolvableVersion is total: nothing escapes it', () {
      final available = availableVersions.map((v) => v.value).toSet();
      final probes = <String>[
        ...bibleVersions.map((v) => v.value),
        ...kWebRestrictedVersions,
        'niv', // removed outright in 2026-05
        'cuv', // removed in v1.4.5
        '', 'garbage', 'nasb-tr',
      ];
      for (final p in probes) {
        expect(available, contains(resolvableVersion(p)),
            reason: "resolvableVersion('$p') returned something this "
                'build cannot load');
      }
    });

    test('SIMULATING WEB: an English reader lands on KJV, not on Chinese',
        () {
      // The assertion the browser could not make. `availableVersions`
      // narrows on a compile-time const that is false under flutter
      // test, so this builds the web candidate list by hand and runs
      // the real rule over it.
      final webList = bibleVersions
          .where((v) => !kWebRestrictedVersions.contains(v.value))
          .toList();
      expect(resolvableVersionFrom('nasb', webList), 'kjv');
      expect(resolvableVersionFrom('leb', webList), 'kjv');
      // Chinese editions are untouched and must not be redirected.
      expect(resolvableVersionFrom('cuvs-yhwh', webList), 'cuvs-yhwh');
      expect(resolvableVersionFrom('cuvs-yhwh-tr', webList), 'cuvs-yhwh-tr');
      // And every result is something the web build can actually load.
      final webCodes = webList.map((v) => v.value).toSet();
      for (final v in bibleVersions.map((e) => e.value)) {
        expect(webCodes, contains(resolvableVersionFrom(v, webList)));
      }
    });

    test('an English restricted edition falls back to a loadable English one',
        () {
      // Not asserting "KJV" by name — asserting the property that makes
      // the fallback safe: same language, actually available, and public
      // domain so it can never itself be stripped.
      for (final v in kWebRestrictedVersions) {
        if (bibleVersionLanguage(v) != 'en') continue;
        final got = resolvableVersion(v);
        // On the VM nothing is restricted, so this returns v itself;
        // the assertion that matters is the language-family rule the
        // web path depends on.
        expect(bibleVersionLanguage(got), 'en',
            reason: 'falling back across language families would open an '
                'English reader into Chinese');
      }
      expect(versionsForLanguage('en').map((v) => v.value), contains('kjv'),
          reason: 'KJV is the public-domain floor the web fallback lands '
              'on; if it ever leaves the English list, revisit '
              'resolvableVersion');
    });

    test('the preloader does not queue an edition with no asset', () {
      final preloader =
          File('lib/services/version_preloader.dart').readAsStringSync();
      expect(preloader, contains('available.contains(v)'),
          reason: 'the preload queue names nasb and leb explicitly; '
              'without the filter every cold boot fires two 404s');
    });
  });

  group('the withheld editions are not named on web', () {
    // Three positions in one sitting, and this is the settled one.
    // v1.4.193 hid them silently; then the picker listed them disabled
    // with a caption so a reader would know where the edition went;
    // then the user cut the row itself — 「New American Standard Bible
    // 这些也不要写」. Naming a translation we cannot serve advertises it,
    // and a greyed-out row is still the app telling every visitor that
    // the NASB is something it has and is not giving them.
    test('no withheld-edition UI survives in the picker', () {
      final sheet =
          File('lib/widgets/version_picker_sheet.dart').readAsStringSync();
      expect(sheet, isNot(contains('withheldVersionsForLanguage')));
      expect(sheet, isNot(contains('versionWithheldWeb')));
    });

    test('and no caption string survives either', () {
      final strings = File('lib/constants/ui_strings.dart').readAsStringSync();
      expect(strings, isNot(contains('versionWithheldWeb')),
          reason: 'a dangling string is how a reverted feature comes '
              'back by accident');
    });

    test('the reader is moved on silently instead', () {
      // What replaced the notice: resolvableVersion carries a stale
      // NASB/LEB preference onto KJV with no message at all. Pinned in
      // the boot-path group above; asserted here as the intended
      // behaviour, so deleting that guard fails two groups, not one.
      final webList = bibleVersions
          .where((v) => !kWebRestrictedVersions.contains(v.value))
          .toList();
      expect(resolvableVersionFrom('nasb', webList), 'kjv');
    });
  });

  test('off web, the picker still offers them', () {
    // These tests run on the VM, where the const `dart.library.js_interop`
    // is false — so this asserts the gate is genuinely web-only and has
    // not accidentally hidden the editions everywhere.
    final codes = availableVersions.map((v) => v.value).toSet();
    for (final v in kWebRestrictedVersions) {
      // 2026-09-04: skip anything ALSO in `disabledVersions`. The NASB
      // is now hidden on every platform by that separate mechanism, so
      // it is no longer evidence either way about whether THIS gate is
      // web-only — the property here is still worth pinning, but the
      // LEB is what pins it now. If that set ever empties, this test
      // stops testing anything and should be revisited rather than
      // deleted quietly.
      if (disabledVersions.contains(v)) continue;
      expect(codes, contains(v));
    }
    expect(kWebRestrictedVersions.difference(disabledVersions), isNotEmpty,
        reason: 'every web-restricted edition is now disabled outright, '
            'so this test no longer proves the web gate is web-only');
  });
}
