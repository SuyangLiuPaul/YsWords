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
///
/// **And presence of the element is not enough.** The first version of
/// this file matched `<uses-permission[^>]*android:name…"[^>]*/?>`,
/// which swallows any additional attribute — including the manifest
/// merger's own delete directive. Adding `tools:node="remove"` to the
/// INTERNET element left all four tests green while taking the
/// permission away, and the manifest already binds `xmlns:tools`, so
/// that edit is one attribute from where a maintainer is already
/// working. It is also the idiom people reach for when stripping a
/// permission a plugin injected, which is the very thing this manifest
/// is about.
///
/// That the directive really does strip it was MEASURED, not assumed,
/// on 2026-09-06 — `./gradlew :app:processIntlReleaseMainManifest`
/// (JDK 17) run twice over
/// `build/app/intermediates/merged_manifest/intlRelease/processIntlReleaseMainManifest/AndroidManifest.xml`:
///
/// | main manifest | INTERNET in the merged manifest |
/// |---|---|
/// | as shipped | present |
/// | `+ tools:node="remove"` | **absent** |
///
/// The other six permissions were identical in both runs, and
/// `google_sign_in_android` still contributed its own INTERNET in the
/// second run — the directive out-ranks it. So the merger obeys the
/// attribute, and a test that ignores it is testing the wrong thing.
/// [_declares] therefore reads the attributes rather than the element's
/// bare existence.
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

  /// Every `<uses-permission>` element in [xml], as its attribute map.
  /// Attribute order and whitespace are irrelevant; the element may be
  /// self-closing or not.
  List<Map<String, String>> usesPermissions(String xml) => [
        for (final e in RegExp(r'<uses-permission\b([^>]*?)/?>').allMatches(xml))
          {
            for (final a
                in RegExp(r'([\w:.-]+)\s*=\s*"([^"]*)"').allMatches(e.group(1)!))
              a.group(1)!: a.group(2)!,
          },
      ];

  /// `tools:node` values that leave the element standing in the merged
  /// manifest. Anything else — `remove`, `removeAll`, or a value this
  /// test has never heard of — is treated as fatal, because the whole
  /// point here is that the merged manifest is what the device sees.
  const survivingNodeOps = {'merge', 'mergeOnlyAttributes', 'replace', 'strict'};

  /// True when the app really asks for [permission] — i.e. some
  /// `<uses-permission>` element names it AND nothing instructs the
  /// merger to drop it or to strip the attribute that names it.
  ///
  /// The `tools:` prefix is not hard-coded: the check is on the
  /// attribute's LOCAL name, so rebinding the namespace to another
  /// prefix does not slip past.
  bool declares(String xml, String permission) {
    /// An attribute's local name — `android:name` and a `name` bound to
    /// some other prefix both read as `name`.
    String local(String key) => key.split(':').last;

    final wanted = 'android.permission.$permission';
    var kept = false;
    for (final attrs in usesPermissions(xml)) {
      final named = attrs.entries
          .where((e) => local(e.key) == 'name')
          .map((e) => e.value);
      if (named.isEmpty || named.first != wanted) continue;
      for (final e in attrs.entries) {
        // tools:node="remove" DELETES this element from the merged
        // manifest — measured, see the note above.
        if (local(e.key) == 'node' && !survivingNodeOps.contains(e.value)) {
          return false;
        }
        // tools:remove="android:name" strips the attribute that names
        // the permission, leaving an element that asks for nothing.
        if (local(e.key) == 'remove' &&
            e.value.split(RegExp(r'[,\s]+')).any((a) => local(a) == 'name')) {
          return false;
        }
      }
      kept = true;
    }
    return kept;
  }

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

  test('a merger directive that deletes the permission is caught', () {
    // The regression guard for this guard. Each of these is a real
    // edit somebody could make to the shipped manifest — it already
    // binds xmlns:tools, and it already uses tools:ignore twice — and
    // every one of them takes INTERNET off the device. `declares` must
    // say so.
    final shipped = declarations(mainManifest);
    expect(declares(shipped, 'INTERNET'), isTrue,
        reason: 'precondition: the real manifest passes');

    /// The shipped manifest with [attr] added to its INTERNET element.
    /// Found by pattern rather than by an exact string so that
    /// reformatting the line does not quietly turn this guard into a
    /// no-op — which is the class of failure the whole file is about.
    String withAttr(String attr) {
      final e = RegExp(
        r'<uses-permission\b[^>]*android:name\s*=\s*'
        r'"android\.permission\.INTERNET"[^>]*?(/?)>',
      ).firstMatch(shipped);
      expect(e, isNotNull,
          reason: 'no INTERNET <uses-permission> element to patch — the '
              'manifest was reshaped, re-read this test');
      final patched = e!.group(0)!.replaceFirst(
          RegExp(r'\s*/?>$'), '$attr ${e.group(1)!.isEmpty ? '>' : '/>'}');
      final out = shipped.replaceRange(e.start, e.end, patched);
      expect(out, isNot(shipped), reason: 'patch did not change anything');
      return out;
    }

    // Each of these is a real edit somebody could make: the manifest
    // already binds xmlns:tools and already uses tools:ignore twice.
    const lethal = <String, String>{
      'tools:node="remove"': ' tools:node="remove"',
      'tools:node="removeAll"': ' tools:node="removeAll"',
      'tools:remove on android:name': ' tools:remove="android:name"',
      'a tools:node value we do not know': ' tools:node="somethingNew"',
      'the namespace rebound to another prefix': ' t:node="remove"',
    };
    lethal.forEach((name, attr) {
      expect(declares(withAttr(attr), 'INTERNET'), isFalse,
          reason: '$name leaves INTERNET out of the MERGED manifest, and '
              'this test must fail when it is present');
    });

    // And the directives that are harmless must NOT trip it, or the
    // guard becomes a nuisance that gets deleted.
    for (final attr in const [' tools:node="replace"', ' tools:node="merge"']) {
      expect(declares(withAttr(attr), 'INTERNET'), isTrue,
          reason: '$attr keeps the element — do not fail on it');
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
