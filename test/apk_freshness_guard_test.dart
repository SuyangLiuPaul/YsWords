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
          '   && apk_carries_release_stamp "\$ANDROID_APK" "\$expected_release_stamp"; then',
        ),
        reason: 'the guard must gate the install loop, not merely warn',
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
}
