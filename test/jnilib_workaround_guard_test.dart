import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 2026-09-06. Guards the workaround for flutter/flutter#191801.
///
/// THE DEFECT. On Flutter 3.44.x, in a build WITH PRODUCT FLAVORS (this
/// app declares `flavorDimensions += "region"` with intl + cn, so it is
/// exposed), Gradle's jniLib merge stays "up-to-date" while the Flutter
/// plugin rewrites its input directory. `merged_jni_libs`,
/// `merged_native_libs` and `stripped_native_libs` go stale, and the
/// stale `stripped_native_libs` is byte-identical to the APK's shipped
/// `libapp.so`. The APK therefore carries a NEW version string over OLD
/// Dart code — the worst shape a build bug can take, because every
/// surface you would check to notice it says the right number.
///
/// The workaround — delete the merge OUTPUTS before building — lives in
/// `tools/clear_stuck_jnilib_merge.sh`. These tests exist because that
/// script is shell: nothing in `flutter analyze` or the widget suite can
/// see it stop being called.
///
/// TWO DISTINCT JOBS, and they fail for opposite reasons:
///
///   1. COVERAGE — a new APK-producing path that forgets to call the
///      workaround. Fails when a build invocation appears in a file that
///      does not reference the script.
///   2. RETIREMENT — the workaround outliving its need. Fails when the
///      Flutter version pinned in `.github/workflows/` reaches 3.47.1,
///      where `addGeneratedSourceDirectory` fixes this upstream. The
///      same pull request that lifts the pin lands red until the
///      workaround is deleted.
///
/// Job 2 is deliberately a TEST rather than a runtime warning. The
/// script does warn at runtime, but the path that matters most runs
/// unattended at 04:00 and has nobody in front of it — this repo has
/// already lost nine days of device installs to a guard that only
/// printed advice.

/// Files that can plausibly invoke a build. Documents are excluded on
/// purpose: `PROJECT_STATE.md` and `HANDOFF.md` are full of pasted build
/// commands, and matching them would force an allowlist, which is how
/// this kind of test rots into a permanent pass.
const _scannedExtensions = {'.sh', '.zsh', '.bash', '.yml', '.yaml'};
const _scannedNames = {'Makefile', 'makefile', 'Fastfile'};

/// Directories that never contain a source-controlled build path.
bool _skipDir(String path) => const [
      '/build/',
      '/.git/',
      // Other sessions' scratch git worktrees. This checkout is shared,
      // and a sibling agent's mid-edit copy is not a path this repo
      // ships — matching them made this test fail on files that are not
      // ours and will vanish on their own.
      '/.claude/',
      '/node_modules/',
      '/.dart_tool/',
      '/ios/Pods/',
      '/build-cn/',
      '/build-wasm/',
    ].any(path.contains);

/// An Android *release* build invocation, in any form these repos use:
/// `flutter build apk`, `"$FLUTTER" build appbundle`, and the Gradle
/// task names those wrap.
///
/// Deliberately broad on the left of `build` — the binary is spelled
/// `flutter`, `"$FLUTTER"`, and `$FLUTTER` across the call sites, and
/// pinning any one of them would let the other two through.
final _buildInvocation = RegExp(
  r'build\s+(apk|appbundle)\b|assemble\w*Release\b|bundle\w*Release\b',
);

/// The call that makes a path safe.
final _workaroundCall = RegExp(r'clear_stuck_jnilib_merge');

/// Strips whole-line `#` comments. Both shell and YAML use `#`, and
/// without this the prose block at the top of every script in this repo
/// — which quotes the build command it is describing — reads as an
/// invocation.
///
/// This is the one soft spot in the coverage test and it is worth naming:
/// it only strips comments that start a line. A trailing `# flutter build
/// apk` after real code would still match, and a build invocation
/// assembled from variables (`"$FLUTTER" build "$TARGET"`) would not
/// match at all. Neither is a false PASS for an existing path — the first
/// over-reports and the second is a shape nothing here uses — but a
/// future path written that way would slip by.
String _stripComments(String source) => source
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('#'))
    .join('\n');

List<File> _scannableFiles() {
  final root = Directory.current;
  return root
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .where((f) => !_skipDir(f.path))
      .where((f) {
        final name = f.uri.pathSegments.last;
        final dot = name.lastIndexOf('.');
        final ext = dot < 0 ? '' : name.substring(dot);
        return _scannedExtensions.contains(ext) || _scannedNames.contains(name);
      })
      .toList();
}

/// Parses `3.44.2` into a comparable integer. Zero-padded, so 3.5.0 does
/// not sort above 3.47.1 — the bug a naive string or double compare has.
int _versionKey(String v) {
  final parts = v.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  while (parts.length < 3) {
    parts.add(0);
  }
  return parts[0] * 1000000 + parts[1] * 1000 + parts[2];
}

/// The release this workaround stops being necessary in.
const _fixedIn = '3.47.1';

void main() {
  final script = File('tools/clear_stuck_jnilib_merge.sh');

  group('flutter#191801 workaround — the rule itself', () {
    test('the one shared entrypoint exists and is executable', () {
      expect(script.existsSync(), isTrue,
          reason: 'tools/clear_stuck_jnilib_merge.sh is the single place the '
              'workaround lives. If it was deleted on purpose because the '
              'toolchain moved past $_fixedIn, delete this test too.');
      // A non-executable script fails only at 04:00, on the one path
      // nobody is watching.
      final mode = script.statSync().mode;
      expect(mode & 0x40, isNot(0),
          reason: 'tools/clear_stuck_jnilib_merge.sh is not user-executable; '
              'every call site invokes it directly, so it would fail at run '
              'time with a permission error');
    });

    test('it still targets all three stale intermediate directories', () {
      final body = script.readAsStringSync();
      for (final dir in const [
        'merged_jni_libs',
        'merged_native_libs',
        'stripped_native_libs',
      ]) {
        expect(body, contains(dir),
            reason: 'the workaround no longer clears $dir. All three go '
                'stale together, and stripped_native_libs is the one that '
                'is byte-identical to the shipped libapp.so.');
      }
    });

    test('its obsolescence threshold is still $_fixedIn', () {
      expect(script.readAsStringSync(), contains(_fixedIn),
          reason: 'the runtime obsolescence check no longer names $_fixedIn, '
              'so it can no longer tell when it has become unnecessary');
    });
  });

  group('flutter#191801 workaround — coverage', () {
    test('every file that builds an Android release also clears the merge',
        () {
      final offenders = <String>[];

      for (final file in _scannableFiles()) {
        // The entrypoint is the workaround; it does not call itself.
        if (file.path.endsWith('tools/clear_stuck_jnilib_merge.sh')) continue;
        // This test names both patterns by construction.
        if (file.path.contains('/test/')) continue;

        final String raw;
        try {
          raw = file.readAsStringSync();
        } on FileSystemException {
          continue; // unreadable / binary
        }
        final source = _stripComments(raw);
        if (!_buildInvocation.hasMatch(source)) continue;
        if (_workaroundCall.hasMatch(source)) continue;

        offenders.add(file.path.replaceFirst('${Directory.current.path}/', ''));
      }

      expect(
        offenders,
        isEmpty,
        reason: 'These paths build an Android release APK/AAB but never call '
            'tools/clear_stuck_jnilib_merge.sh, so each can ship an APK '
            'carrying a new version string over old Dart code '
            '(flutter/flutter#191801):\n'
            '  ${offenders.join('\n  ')}\n'
            'Add, before the build:\n'
            '  FLUTTER="\$FLUTTER" '
            '"\$PROJECT/tools/clear_stuck_jnilib_merge.sh" "\$PROJECT"',
      );
    });

    test('the scan actually finds the known build paths', () {
      // Without this, deleting every call site OR breaking the regex
      // would leave the coverage test above passing over an empty set —
      // the exact false pass this file is meant to prevent.
      final withBuilds = _scannableFiles()
          .where((f) => !f.path.endsWith('tools/clear_stuck_jnilib_merge.sh'))
          .where((f) => !f.path.contains('/test/'))
          .where((f) {
            try {
              return _buildInvocation.hasMatch(_stripComments(
                f.readAsStringSync(),
              ));
            } on FileSystemException {
              return false;
            }
          })
          .toList();

      expect(withBuilds.length, greaterThanOrEqualTo(2),
          reason: 'the scanner found ${withBuilds.length} Android build '
              'paths. This repo has at least two (a release script and '
              '.github/workflows/release-android.yml). Finding fewer means '
              'the regex or the file filter stopped matching, and the '
              'coverage test above is passing over nothing.');
    });
  });

  group('flutter#191801 workaround — retirement', () {
    test('fails once the pinned Flutter reaches $_fixedIn', () {
      final workflows = Directory('.github/workflows');
      expect(workflows.existsSync(), isTrue);

      final pinPattern = RegExp(r"flutter-version:\s*'([0-9]+\.[0-9]+\.[0-9]+)'");
      final pins = <String, String>{};

      for (final f in workflows.listSync().whereType<File>()) {
        for (final m in pinPattern.allMatches(f.readAsStringSync())) {
          pins[f.uri.pathSegments.last] = m.group(1)!;
        }
      }

      expect(pins, isNotEmpty,
          reason: 'no flutter-version pin found in .github/workflows/. This '
              'test reads the pin to know when the workaround can go; with '
              'no pin it can never fire, so it fails now instead.');

      final past = pins.entries
          .where((e) => _versionKey(e.value) >= _versionKey(_fixedIn))
          .toList();

      expect(
        past,
        isEmpty,
        reason: 'The Flutter pin has reached $_fixedIn '
            '(${past.map((e) => '${e.key} -> ${e.value}').join(', ')}), which '
            'carries the upstream fix for flutter/flutter#191801 '
            '(addGeneratedSourceDirectory). The workaround is now dead '
            'weight and an unattended `rm -rf` with no reason to exist.\n'
            'DELETE, in one commit:\n'
            '  1. tools/clear_stuck_jnilib_merge.sh\n'
            '  2. every call site — run this suite\'s coverage test to list '
            'them\n'
            '  3. this test file',
      );
    });
  });
}
