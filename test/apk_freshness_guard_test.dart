import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 2026-08-24, from three Mi Pad bug reports that were all one stale APK.
///
/// `tools/yswords-ios-reinstall.sh` now refuses to install an APK whose
/// `lib/*/libapp.so` does not carry the current `kAppReleaseTime`. The
/// guard is shell, so nothing in `flutter analyze` or the widget suite
/// can see it break. What it depends on is a SHAPE in Dart source:
/// `kAppReleaseTime`'s `defaultValue` must stay a single-quoted ISO-8601
/// UTC instant, on a `defaultValue:` line following the
/// `String.fromEnvironment(` line. `tools/bump_version.sh` writes it
/// through the same two anchors.
///
/// Reformat that constant and the guard extracts an empty string, which
/// it treats as a failure — so every Android install would start
/// refusing. These tests fail first instead.
File _repoFile(String relative) {
  final file = File(relative);
  expect(file.existsSync(), isTrue, reason: '$relative is missing');
  return file;
}

/// Runs the shell script's OWN extraction, by sourcing the real file
/// under `sh -c` up to the point the variable is set.
///
/// A Dart reimplementation of the awk would only prove Dart agrees with
/// Dart. The failure that matters is the shell one — mangle the nested
/// `'\''` quoting (which is easy to do, and the file is copied to
/// `~/.config/yswords/scripts/` on every release) and
/// `expected_release_stamp` comes back empty, at which point the guard
/// refuses every Android install while every Dart assertion stays green.
String _extractReleaseStampViaShell() {
  final script = File('tools/yswords-ios-reinstall.sh').readAsStringSync();
  final start = script.indexOf('expected_release_stamp="\$(awk ');
  expect(start, greaterThan(-1),
      reason: 'the guard no longer assigns expected_release_stamp with awk');
  final end = script.indexOf('app_version.dart" 2>/dev/null)"', start);
  expect(end, greaterThan(start));
  final assignment =
      script.substring(start, end + 'app_version.dart" 2>/dev/null)"'.length);

  final result = Process.runSync('sh', [
    '-c',
    'PROJECT="\$PWD"\n$assignment\nprintf %s "\$expected_release_stamp"',
  ]);
  expect(result.exitCode, 0, reason: result.stderr.toString());
  return result.stdout as String;
}

/// The same extraction, reimplemented — used only to cross-check the
/// shell one, never on its own.
String? _extractReleaseStamp(String source) {
  var inBlock = false;
  for (final line in const LineSplitter().convert(source)) {
    if (line.contains('const String kAppReleaseTime = String.fromEnvironment(')) {
      inBlock = true;
    }
    if (inBlock && line.contains('defaultValue:')) {
      final match = RegExp("'([^']*)'").firstMatch(line);
      return match?.group(1);
    }
  }
  return null;
}

void main() {
  group('the APK freshness marker', () {
    late String versionSource;

    setUp(() {
      versionSource = _repoFile('lib/constants/app_version.dart').readAsStringSync();
    });

    test('kAppReleaseTime still parses out of the source', () {
      final stamp = _extractReleaseStamp(versionSource);
      expect(
        stamp,
        isNotNull,
        reason: 'the kAppReleaseTime block no longer matches the anchors '
            'that bump_version.sh writes and the reinstall guard reads',
      );
      expect(
        stamp,
        matches(RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$')),
        reason: 'the stamp must be an ISO-8601 UTC instant to the second — '
            'that second is what makes it unique per release, and the '
            'guard greps for it verbatim inside libapp.so',
      );
      expect(
        DateTime.tryParse(stamp!),
        isNotNull,
        reason: 'a stamp that is not a real instant would still grep, but '
            'formatReleaseTimeLocal() would fall back on the About page',
      );
    });

    test('is kept alive by a widget, so AOT cannot shake it out', () {
      // The guard greps libapp.so for the stamp. A const string that no
      // reachable code reads is dropped from the AOT snapshot — and the
      // guard would then refuse EVERY Android install, which is worse
      // than the stale APK it exists to catch. `kAppReleaseTime` is only
      // retained because `formatReleaseTimeLocal()` renders it.
      final callers = <String>[];
      for (final page in const ['lib/pages/about_page.dart',
                                'lib/pages/dashboard_page.dart']) {
        // Comment lines are stripped: both files discuss the constant at
        // length, and a commented-out call site is exactly the case
        // where AOT drops the const and the guard rejects every build.
        final live = const LineSplitter()
            .convert(_repoFile(page).readAsStringSync())
            .where((l) => !l.trimLeft().startsWith('//'))
            .join('\n');
        if (live.contains('formatReleaseTimeLocal()')) callers.add(page);
      }
      expect(
        callers,
        isNotEmpty,
        reason: 'nothing renders the release stamp any more, so the AOT '
            'snapshot may no longer contain it and the APK freshness '
            'guard in tools/yswords-ios-reinstall.sh would reject every '
            'build. Give the guard a different marker before removing '
            'the last call site.',
      );
      expect(versionSource, contains('String formatReleaseTimeLocal() =>'));
      expect(versionSource, contains('formatReleaseStamp(kAppReleaseTime'));
    });

    test("the script's own awk extracts it, not just Dart's copy", () {
      final fromShell = _extractReleaseStampViaShell();
      expect(
        fromShell,
        isNotEmpty,
        reason: 'the guard treats an empty stamp as a failure, so this '
            'would refuse every Android install',
      );
      expect(fromShell, _extractReleaseStamp(versionSource));
    });
  });

  group('the reinstall script', () {
    late String script;

    setUp(() {
      script = _repoFile('tools/yswords-ios-reinstall.sh').readAsStringSync();
    });

    test('defines the content assertion', () {
      expect(script, contains('apk_carries_release_stamp()'));
      expect(
        script,
        contains("unzip -Z1 \"\$apk_path\" 'lib/*/libapp.so'"),
        reason: 'the assertion must read the slices of the APK that will '
            'actually be installed, not build/ intermediates',
      );
    });

    test('no Android install can run without it passing', () {
      // The build and the assertion are one `if` condition, so the
      // install loop is unreachable when either fails.
      expect(
        script,
        contains(
          'if "\$FLUTTER" build apk --release --flavor intl "\${DEFINES[@]}" \\\n'
          '   && apk_carries_release_stamp "\$ANDROID_APK" "\$expected_release_stamp" \\\n'
          '   && aot_postdates_dart_source \\\n'
          '   && asset_bundle_matches_source; then',
        ),
        reason: 'all three guards must gate the install loop, not merely warn',
      );
      // And there is exactly one place the APK is pushed to a device,
      // inside that branch.
      expect('install -r "\$ANDROID_APK"'.allMatches(script).length, 1);
    });

    test('does not inject APP_RELEASE_TIME, which would override the marker',
        () {
      // `tools/build_web.py:89` still passes
      // `--dart-define=APP_RELEASE_TIME=<build moment>` for web. If the
      // native path ever did the same, the literal compiled into
      // libapp.so would be the build moment rather than the source
      // constant, and the guard — which reads the source constant —
      // would refuse every legitimately fresh Android build. That is a
      // worse outcome than the stale APK it exists to catch.
      // Comment lines are stripped first — the script's own 2026-06-09
      // note quotes the define it removed.
      final code = const LineSplitter()
          .convert(script)
          .where((l) => !l.trimLeft().startsWith('#'))
          .join('\n');
      expect(
        RegExp(r'--dart-define=.?APP_RELEASE_TIME=').hasMatch(code),
        isFalse,
        reason: 'the native builds must let kAppReleaseTime come from '
            'source, as the 2026-06-09 (v1.3.59) note in the script says',
      );
    });

    test('matches the installed package id exactly', () {
      // `pm list packages` prints `package:<id>` per line, and the cn
      // flavor is `com.example.yswords.cn` — a substring grep passes on
      // a device that only has the China build.
      expect(script, contains('grep -qx "package:com.example.yswords"'));
      expect(
        _repoFile('android/app/build.gradle.kts').readAsStringSync(),
        contains('applicationIdSuffix = ".cn"'),
        reason: 'the exact-match grep above exists because of this suffix',
      );
    });

    test('says so when Dart landed after the stamp it verified', () {
      // The marker only moves on a bump, and the 04:00 launchd job does
      // not bump — so between releases the ✓ would be an all-clear the
      // check has not earned.
      expect(
        script,
        contains('git rev-list --count --full-history "\$stamp_commit..HEAD"'),
        reason: 'without --full-history, path simplification drops merge '
            'parents and undercounts the drift',
      );
      expect(script, contains('NOTE: \$lib_drift commit(s) have touched lib/'));
      // bump_version.sh does not commit, so straight after a bump the
      // stamp is in no commit and the lookup returns empty. Staying
      // quiet there would leave the ✓ unqualified.
      expect(script, contains('is not in any commit yet (an'));
      expect(script, contains('git status --porcelain -- lib'));
    });

    test('reads the stamp through the anchors bump_version.sh writes', () {
      final bump = _repoFile('tools/bump_version.sh').readAsStringSync();
      const anchor =
          r'/const String kAppReleaseTime = String\.fromEnvironment\(/';
      expect(
        script,
        contains(anchor),
        reason: 'the reader and the writer must anchor on the same line, '
            'or a rename silently breaks only one of them',
      );
      expect(bump, contains(anchor));
    });
  });

  /// 2026-08-30: `bump_version.sh`'s version-update awk anchored on
  /// `const String kAppVersion = String\.fromEnvironment\(`, a line that
  /// `3c22efa` (2026-06-29) renamed away when it split the constant into
  /// `_envAppVersion` (the environment read) and `kAppVersion` (a ternary
  /// guarding the empty-dart-define case). The awk matched nothing from
  /// that commit onward — every bump since left `app_version.dart`'s
  /// fallback frozen at `1.3.113` while the script still printed a
  /// success message. `flutter analyze` and the widget suite cannot see
  /// this: the failure is entirely in the shell, so this test runs the
  /// real awk block under `sh`, mirroring `_extractReleaseStampViaShell`
  /// above for the release-time block.
  group('the version-fallback writer (bump_version.sh)', () {
    /// Runs the real "Update lib/constants/app_version.dart" awk block —
    /// lifted verbatim out of the script — against a scratch copy of the
    /// REAL app_version.dart, and returns the mutated content. A Dart
    /// reimplementation of the awk would only prove Dart agrees with
    /// Dart; the shell is what bump_version.sh actually runs at release
    /// time.
    String runBlock(String newVersion) {
      final script = File('tools/bump_version.sh').readAsStringSync();
      const startMarker = '# Update lib/constants/app_version.dart';
      final start = script.indexOf(startMarker);
      expect(start, greaterThan(-1),
          reason: 'bump_version.sh no longer has its version-update block '
              'at the anchor this test expects');
      const endMarker = 'mv "\$TMP" "\$APP_VERSION_DART"';
      final end = script.indexOf(endMarker, start);
      expect(end, greaterThan(start));
      final block = script.substring(start, end + endMarker.length);

      final scratch = File(
          '${Directory.systemTemp.path}/bump_version_awk_test_'
          '${DateTime.now().microsecondsSinceEpoch}.dart')
        ..writeAsStringSync(
            _repoFile('lib/constants/app_version.dart').readAsStringSync());
      addTearDown(() {
        if (scratch.existsSync()) scratch.deleteSync();
      });

      final result = Process.runSync('sh', [
        '-c',
        'APP_VERSION_DART="${scratch.path}"\nNEW="$newVersion"\n$block',
      ]);
      expect(result.exitCode, 0, reason: result.stderr.toString());
      return scratch.readAsStringSync();
    }

    test('anchors on _envAppVersion, which is what the source actually '
        'declares today', () {
      final source = _repoFile('lib/constants/app_version.dart')
          .readAsStringSync();
      expect(
        source,
        contains('const String _envAppVersion = String.fromEnvironment('),
        reason: 'if this constant is renamed again, update the anchor in '
            'the same commit — a bump that silently stops moving the '
            'fallback is exactly the defect this test exists to catch',
      );
    });

    test('a bump moves BOTH literals — the defaultValue and the ternary '
        'fallback', () {
      final after = runBlock('9.9.9');
      expect(after, contains("defaultValue: '9.9.9',"));
      expect(
        after,
        contains("_envAppVersion == '' ? '9.9.9' : _envAppVersion;"),
        reason: 'the ternary literal (3c22efa\'s empty-dart-define guard) '
            'must move too, or it silently re-drifts from pubspec.yaml '
            'the next time a build ships an empty APP_VERSION define',
      );
      // The guard from 3c22efa must survive the bump untouched in shape.
      expect(after, contains("_envAppVersion == '' ?"));
    });

    test('is idempotent under a second bump to the same version', () {
      final once = runBlock('9.9.9');
      final scratch2 = File(
          '${Directory.systemTemp.path}/bump_version_awk_test2_'
          '${DateTime.now().microsecondsSinceEpoch}.dart')
        ..writeAsStringSync(once);
      addTearDown(() {
        if (scratch2.existsSync()) scratch2.deleteSync();
      });
      final script = File('tools/bump_version.sh').readAsStringSync();
      const startMarker = '# Update lib/constants/app_version.dart';
      final start = script.indexOf(startMarker);
      const endMarker = 'mv "\$TMP" "\$APP_VERSION_DART"';
      final end = script.indexOf(endMarker, start);
      final block = script.substring(start, end + endMarker.length);
      final result = Process.runSync('sh', [
        '-c',
        'APP_VERSION_DART="${scratch2.path}"\nNEW="9.9.9"\n$block',
      ]);
      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(scratch2.readAsStringSync(), once);
    });
  });

  /// The second guard, added 2026-08-25 to cover the nightly — which the
  /// stamp above structurally cannot, because the stamp only moves when
  /// `bump_version.sh` runs and the 04:00 launchd job does not bump.
  ///
  /// These run the real shell function, lifted out of the real script,
  /// against synthetic trees. A Dart reimplementation would only prove
  /// Dart agrees with Dart, and the file is copied to
  /// `~/.config/yswords/scripts/` on every release, so the shell is what
  /// has to keep working.
  group('the AOT freshness guard', () {
    late String script;

    setUp(() {
      script = _repoFile('tools/yswords-ios-reinstall.sh').readAsStringSync();
    });

    /// Everything from the function header to its closing brace.
    String function() {
      const header = 'aot_postdates_dart_source() {';
      final start = script.indexOf('\n$header');
      expect(start, greaterThan(-1),
          reason: 'the script no longer defines aot_postdates_dart_source');
      final end = script.indexOf('\n}\n', start);
      expect(end, greaterThan(start));
      return script.substring(start + 1, end + 3);
    }

    /// Builds a fake `$PROJECT`, runs the function in it, returns
    /// (exit code, stdout).
    (int, String) runIn(Directory project) {
      final result = Process.runSync('sh', [
        '-c',
        "PROJECT='${project.path}'\n${function()}\naot_postdates_dart_source",
      ]);
      return (result.exitCode, result.stdout as String);
    }

    /// A fake `$PROJECT`: `lib/` holding [libFiles], an `<abi>/app.so`,
    /// and a depfile naming only [depNames] as lib/ inputs.
    ///
    /// [aotFirst] writes app.so BEFORE the lib/ files, so everything in
    /// lib/ post-dates the snapshot — the staleness this guard exists
    /// to catch.
    Directory scratch({
      required bool aotFirst,
      bool withAot = true,
      bool withDepfile = true,
      List<String> libFiles = const ['a.dart'],
      List<String> depNames = const ['a.dart'],
    }) {
      final dir = Directory.systemTemp.createTempSync('aotfresh');
      final variant =
          Directory('${dir.path}/build/app/intermediates/flutter/intlRelease')
            ..createSync(recursive: true);
      Directory('${dir.path}/lib').createSync(recursive: true);
      Directory('${variant.path}/arm64-v8a').createSync(recursive: true);

      if (withDepfile) {
        // The real shape: `<outputs>: <inputs>`, one space-separated
        // line, the separator glued to the last output token.
        final inputs = depNames.map((n) => '${dir.path}/lib/$n').join(' ');
        File('${variant.path}/flutter_build.d').writeAsStringSync(
            ' ${variant.path}/arm64-v8a/app.so: '
            '/pub-cache/some_package/lib/x.dart $inputs');
      }
      void writeAot() =>
          File('${variant.path}/arm64-v8a/app.so').writeAsStringSync('so');
      void writeDart() {
        for (final name in libFiles) {
          File('${dir.path}/lib/$name').writeAsStringSync('void');
        }
      }

      if (aotFirst) {
        if (withAot) writeAot();
        sleep(const Duration(seconds: 1));
        writeDart();
      } else {
        writeDart();
        sleep(const Duration(seconds: 1));
        if (withAot) writeAot();
      }
      return dir;
    }

    test('refuses when a build input post-dates the AOT snapshot', () {
      final dir = scratch(aotFirst: true);
      addTearDown(() => dir.deleteSync(recursive: true));
      final (code, out) = runIn(dir);
      expect(code, isNot(0),
          reason: 'a snapshot older than its own input cannot contain it');
      expect(out, contains('predates lib/a.dart'));
      expect(out, contains('Refusing to install'));
    });

    test('passes when the AOT snapshot post-dates every build input', () {
      final dir = scratch(aotFirst: false);
      addTearDown(() => dir.deleteSync(recursive: true));
      final (code, out) = runIn(dir);
      expect(code, 0);
      expect(out, contains('AOT freshness verified'));
    });

    test('ignores lib/ files that are not inputs to THIS build', () {
      // The reason this reads the depfile instead of `find lib`. 22 of
      // this repo's 234 lib/*.dart files are not Android inputs — 17 are
      // `*_web.dart` conditional-import stubs — and `lib/.DS_Store`
      // exists and is rewritten by Finder at arbitrary moments. A
      // `find`-based check refuses a correct build in both cases, every
      // night, until something unrelated forces a recompile.
      //
      // This has to DISCRIMINATE, or it proves nothing: the depfile
      // names a.dart, which is written BEFORE app.so, while the two
      // non-inputs are written AFTER it. A `find lib`-based guard sees
      // files newer than the snapshot and refuses; this one must pass.
      // An earlier version of this test passed `depNames: []`, which
      // exited on the "lists no lib/ inputs" branch and only duplicated
      // the disclosure test below.
      final dir = Directory.systemTemp.createTempSync('aotfresh');
      addTearDown(() => dir.deleteSync(recursive: true));
      final variant =
          Directory('${dir.path}/build/app/intermediates/flutter/intlRelease')
            ..createSync(recursive: true);
      Directory('${dir.path}/lib').createSync(recursive: true);
      Directory('${variant.path}/arm64-v8a').createSync(recursive: true);
      File('${variant.path}/flutter_build.d').writeAsStringSync(
          ' ${variant.path}/arm64-v8a/app.so: ${dir.path}/lib/a.dart');

      File('${dir.path}/lib/a.dart').writeAsStringSync('void');
      sleep(const Duration(seconds: 1));
      File('${variant.path}/arm64-v8a/app.so').writeAsStringSync('so');
      sleep(const Duration(seconds: 1));
      for (final name in const ['thing_web.dart', '.DS_Store']) {
        File('${dir.path}/lib/$name').writeAsStringSync('x');
      }

      final (code, out) = runIn(dir);
      expect(code, 0,
          reason: 'the only lib/ INPUT pre-dates the snapshot; the two '
              'files that post-date it went into no Android build');
      expect(out, contains('AOT freshness verified'));
      expect(out, isNot(contains('predates')));
    });

    test('discloses rather than refuses when it cannot measure', () {
      // Trap 43: a guard whose failure mode is refusing everything needs
      // its own test. A Flutter upgrade that moves the intermediates
      // layout must not block every Android install on a tooling detail.
      for (final dir in [
        scratch(aotFirst: false, withAot: false),
        scratch(aotFirst: false, withDepfile: false),
      ]) {
        addTearDown(() => dir.deleteSync(recursive: true));
        final (code, out) = runIn(dir);
        expect(code, 0, reason: 'an unrunnable check must not refuse');
        expect(out, contains('did not run'),
            reason: 'and it must say so, or the ✓ reads as an all-clear');
        expect(out, isNot(contains('verified')));
      }
    });

    test('measures app.so, not the jniLibs copy of it', () {
      // BOTH are copies — app.so is AndroidAotBundle's `copySync` out of
      // .dart_tool/flutter_build/<hash>/. What differs is the skip rule
      // of whatever does the copying. jniLibs/ is filled by Gradle's
      // `copyJniLibs<Variant>` Sync task, and Gradle is up-to-date per
      // TASK, so one changed input re-stamps the whole set: measured
      // 2026-08-25, jniLibs/arm64-v8a/libpdfium.so carried mtime
      // 01:00:18 over bytes byte-identical to a source last written
      // 2026-08-24T07:26:50. flutter's build_system skips per TARGET on
      // the input's content hash, and AndroidAotBundle's only input is
      // the AOT app.so — so that copy re-runs iff the AOT bytes changed.
      expect(script, contains(r'"$intermediates"/*/app.so'));
      final code = const LineSplitter()
          .convert(function())
          .where((l) => !l.trimLeft().startsWith('#'))
          .join('\n');
      expect(
        code.contains('jniLibs'),
        isFalse,
        reason: 'a jniLibs mtime records the Sync, not the compile',
      );
      expect(
        code.contains('flutter_build.d'),
        isTrue,
        reason: 'the sources compared must be the ones the build declared',
      );
    });
  });

  /// The third guard, added 2026-08-25. The two above only ever look at
  /// CODE, so a build carrying a stale asset bundle passes both — and
  /// this repo ships scripture corrections that touch no `lib/` file at
  /// all (9 of the 60 commits before this one), which is exactly the
  /// change a reader would notice missing on the tablet.
  group('the asset freshness guard', () {
    late String script;

    setUp(() {
      script = _repoFile('tools/yswords-ios-reinstall.sh').readAsStringSync();
    });

    String function() {
      const header = 'asset_bundle_matches_source() {';
      final start = script.indexOf('\n$header');
      expect(start, greaterThan(-1),
          reason: 'the script no longer defines asset_bundle_matches_source');
      final end = script.indexOf('\n}\n', start);
      expect(end, greaterThan(start));
      return script.substring(start + 1, end + 3);
    }

    /// Runs under zsh, which is the script's own `#!` line. The AOT
    /// group above uses `sh`, and that gap is worth closing here: the
    /// function reads `$?` through a `case`, splits on a literal tab via
    /// `IFS`, and reads a loop variable back out after the loop — all
    /// places the two shells could plausibly differ.
    (int, String) runIn(Directory project) {
      final result = Process.runSync('zsh', [
        '-c',
        "PROJECT='${project.path}'\n${function()}\nasset_bundle_matches_source",
      ]);
      return (result.exitCode, result.stdout as String);
    }

    /// A fake `$PROJECT` with one declared asset and one bundled copy.
    ///
    /// mtimes are SET rather than raced, because the shell compares
    /// whole seconds from `stat -f %m` and a sleep-based test would be
    /// both slow and flaky at the boundary.
    Directory scratch({
      String asset = 'psalms.json',
      String source = 'verse',
      String? copy = 'verse',
      int sourceEpoch = 2000000000,
      int copyEpoch = 2000000000,
      bool withBundleDir = true,
      bool withDepfile = true,
    }) {
      final dir = Directory.systemTemp.createTempSync('assetfresh');
      final variant =
          Directory('${dir.path}/build/app/intermediates/flutter/intlRelease')
            ..createSync(recursive: true);
      Directory('${dir.path}/assets').createSync(recursive: true);
      Directory('${dir.path}/lib').createSync(recursive: true);
      Directory('${variant.path}/arm64-v8a').createSync(recursive: true);

      if (withDepfile) {
        // The real shape, and deliberately mixed: a lib/ input, a
        // pub-cache input and an assets/ input on one line, so the
        // prefix filter has something to reject. Spaces are escaped the
        // way flutter_tools' depfile.dart writes them.
        File('${variant.path}/flutter_build.d').writeAsStringSync(
            ' ${variant.path}/arm64-v8a/app.so: '
            '/pub-cache/some_package/lib/x.dart ${dir.path}/lib/a.dart '
            '${dir.path}/assets/${asset.replaceAll(' ', r'\ ')}');
      }
      File('${dir.path}/lib/a.dart').writeAsStringSync('void');
      File('${dir.path}/assets/$asset')
        ..writeAsStringSync(source)
        ..setLastModifiedSync(
            DateTime.fromMillisecondsSinceEpoch(sourceEpoch * 1000));

      if (withBundleDir) {
        final bundled = Directory('${variant.path}/flutter_assets/assets')
          ..createSync(recursive: true);
        if (copy != null) {
          File('${bundled.path}/$asset')
            ..writeAsStringSync(copy)
            ..setLastModifiedSync(
                DateTime.fromMillisecondsSinceEpoch(copyEpoch * 1000));
        }
      }
      return dir;
    }

    test('refuses when the bundled copy holds the previous bytes', () {
      final dir = scratch(
          source: 'corrected', copy: 'stale', sourceEpoch: 2000000100);
      addTearDown(() => dir.deleteSync(recursive: true));
      final (code, out) = runIn(dir);
      expect(code, isNot(0),
          reason: 'the reader would see the uncorrected text');
      expect(out, contains('assets/psalms.json changed'));
      expect(out, contains('Refusing to install'));
    });

    test('refuses when a declared asset was never bundled', () {
      final dir = scratch(copy: null);
      addTearDown(() => dir.deleteSync(recursive: true));
      final (code, out) = runIn(dir);
      expect(code, isNot(0));
      expect(out, contains('never'));
    });

    test('passes when an mtime moved but the bytes did not', () {
      // The false-alarm class the lib/ check above has to live with, and
      // the reason this one runs `cmp`. flutter skips the asset target on
      // a content hash, so an edit-and-revert leaves a copy that is
      // correct and older. Refusing on that would block every nightly
      // until something unrelated forced a rebuild.
      final dir = scratch(sourceEpoch: 2000000100);
      addTearDown(() => dir.deleteSync(recursive: true));
      final (code, out) = runIn(dir);
      expect(code, 0, reason: 'the bundled bytes are the current bytes');
      expect(out, contains('Asset freshness verified'));
      expect(out, isNot(contains('changed')));
    });

    test('a correctly bundled asset newer than app.so passes BOTH guards',
        () {
      // This is the whole reason the check is a separate function rather
      // than a wider prefix on aot_postdates_dart_source. Nothing under
      // assets/ is an input to the target that writes app.so — measured
      // in the build directory .last_build_id names:
      // kernel_snapshot_program.d has 2780 inputs and zero under assets/,
      // android_aot_release_android-arm64 has five (engine and app.dill),
      // and android_aot_bundle_release_android-arm64 has one, the AOT
      // app.so it copies. So an asset-only commit leaves app.so older
      // than the asset while the build is perfectly correct, and a
      // widened prefix would refuse it — on 129 of this repo's 1266
      // commits over its life, and 9 of the 60 before this one.
      //
      // The asset here post-dates app.so by 100s and IS correctly
      // bundled, so both functions must pass.
      final dir = scratch(sourceEpoch: 2000000100, copyEpoch: 2000000100);
      addTearDown(() => dir.deleteSync(recursive: true));
      final variant =
          '${dir.path}/build/app/intermediates/flutter/intlRelease';
      File('$variant/arm64-v8a/app.so')
        ..writeAsStringSync('so')
        ..setLastModifiedSync(
            DateTime.fromMillisecondsSinceEpoch(2000000050 * 1000));
      File('${dir.path}/lib/a.dart').setLastModifiedSync(
          DateTime.fromMillisecondsSinceEpoch(2000000000 * 1000));

      final aot = Process.runSync('sh', [
        '-c',
        "PROJECT='${dir.path}'\n"
            '${_functionNamed(script, "aot_postdates_dart_source")}\n'
            'aot_postdates_dart_source',
      ]);
      expect(aot.exitCode, 0,
          reason: 'the only lib/ input pre-dates app.so: ${aot.stdout}');

      final (code, out) = runIn(dir);
      expect(code, 0, reason: out);
      expect(out, contains('Asset freshness verified'));
    });

    test('sees a stale asset whose path contains a space', () {
      // A refuter broke the first draft here, and the failure was the
      // dangerous kind: it printed a ✓. flutter_tools' depfile.dart
      // writes a literal space as `\ `, so splitting the depfile on every
      // space sheared `assets/Sea of Galilee.json` into three fragments,
      // none of which existed. The asset dropped out of the check
      // entirely while the summary line still counted it as matching.
      //
      // This repo has no declared asset with a space today — the six
      // that exist are under assets/fonts_backup/, which pubspec does
      // not declare, so the live tree could never have exercised it.
      final dir = scratch(
          asset: 'Sea of Galilee.json',
          source: 'corrected',
          copy: 'stale',
          sourceEpoch: 2000000100);
      addTearDown(() => dir.deleteSync(recursive: true));
      final (code, out) = runIn(dir);
      expect(code, isNot(0), reason: out);
      expect(out, contains('assets/Sea of Galilee.json changed'));
      expect(out, isNot(contains('verified')));
    });

    test('an unreadable source is disclosed and subtracted, not refused',
        () {
      // cmp exits >1 when it cannot read a side, and the first draft
      // folded that into "the bytes differ" — refusing the nightly and
      // naming the wrong cause. Not being able to read a file is not
      // evidence that the bundle is stale.
      final dir = scratch(sourceEpoch: 2000000100);
      addTearDown(() {
        File('${dir.path}/assets/psalms.json')
            .parent
            .listSync()
            .whereType<File>()
            .forEach((f) => Process.runSync('chmod', ['u+r', f.path]));
        dir.deleteSync(recursive: true);
      });
      Process.runSync('chmod', ['000', '${dir.path}/assets/psalms.json']);

      final (code, out) = runIn(dir);
      expect(code, 0, reason: 'an unreadable file must not block the '
          'nightly install: $out');
      expect(out, contains('could not be read'));
      expect(out, contains('0 of 1'),
          reason: 'and the ✓ must not count what it did not check');
    });

    test('discloses rather than refuses when it cannot measure', () {
      // Trap 43 again: a guard whose failure mode is refusing everything
      // is worse than the staleness it catches. A Flutter upgrade that
      // moves flutter_assets/ must not block every Android install.
      for (final dir in [
        scratch(withDepfile: false),
        scratch(withBundleDir: false),
      ]) {
        addTearDown(() => dir.deleteSync(recursive: true));
        final (code, out) = runIn(dir);
        expect(code, 0, reason: 'an unrunnable check must not refuse');
        expect(out, contains('did not run'));
        expect(out, isNot(contains('verified')));
      }
    });

    test('compares against flutter_assets, never against app.so', () {
      final code = const LineSplitter()
          .convert(function())
          .where((l) => !l.trimLeft().startsWith('#'))
          .join('\n');
      expect(code.contains('flutter_assets'), isTrue);
      expect(
        code.contains('app.so'),
        isFalse,
        reason: 'no asset is an input to the target that writes app.so, so '
            'comparing against it would refuse every asset-only build',
      );
      expect(
        code.contains('cmp -s'),
        isTrue,
        reason: 'the bytes decide, not the clock',
      );
    });
  });
}

/// Lifts a named shell function out of the script, header to closing
/// brace. Only the function's own `}` is unindented.
String _functionNamed(String script, String name) {
  final start = script.indexOf('\n$name() {');
  if (start < 0) throw StateError('$name is no longer defined');
  final end = script.indexOf('\n}\n', start);
  return script.substring(start + 1, end + 3);
}
