import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The app is called **Yahweh's Words** (雅伟之言).
///
/// Renamed 2026-08-23 at the user's instruction: "整个app要改名，叫做
/// Yahweh's Words雅伟之言". Before that it was "YsWords", and on
/// 2026-08-17 the same user had to correct the CAPITALISATION of that
/// name because it lived in five per-platform places that nothing
/// compared — which is why this test exists and why it now pins the
/// new name the same way.
///
/// It survived because the name lives in five different places, one per
/// platform, and nothing compared them:
///
///   web       web/manifest.json          name / short_name
///   Android   android/app/build.gradle.kts  resValue app_name, per flavour
///   iOS       ios/Runner/Info.plist      CFBundleDisplayName, CFBundleName
///   macOS     macos/Runner/Info.plist    CFBundleDisplayName, CFBundleName
///                    + macos/Runner/*.lproj/InfoPlist.strings
///
/// macOS is fixed through the Info.plist and per-locale
/// `InfoPlist.strings` rather than by changing `PRODUCT_NAME` in
/// AppInfo.xcconfig: PRODUCT_NAME also names the built bundle, and
/// `/Applications/yswords.app` is hard-coded in
/// `tools/yswords-ios-reinstall.sh`. Renaming it there would install to
/// a new path and leave the old app sitting on the Mac.
///
/// 2026-09-07: the `.lproj` half is new. Before it, macOS was the only
/// platform whose name did NOT follow the system language, which is how
/// one person's Mi Pad and MacBook ended up calling the same app two
/// different things.
void main() {
  const wanted = "Yahweh's Words";

  String read(String path) => File(path).readAsStringSync();

  /// The APP target's `files = (…)` list inside `PBXResourcesBuildPhase`.
  ///
  /// Two narrowings, each of which took a wrong assertion to find:
  ///
  /// 1. **Not `pbx.contains(...)`.** The string
  ///    `InfoPlist.strings in Resources` appears TWICE in a project
  ///    file: in the `PBXBuildFile` declaration, and in the build
  ///    phase's `files` list. Only the second ships the resource, so a
  ///    whole-file `contains` stays green with the resource removed
  ///    from the build phase — exactly the silent failure the
  ///    assertion claims to catch. Found 2026-09-07 by deleting the
  ///    build-phase line and watching the test pass; the iOS assertion
  ///    had the same hole and had never been able to fail.
  ///
  /// 2. **Not the whole section either.** A project has more than one
  ///    resources phase — iOS's RunnerTests target has an empty one
  ///    that appears FIRST. A resource attached to that target is not
  ///    in the app at all, and a section-wide search cannot tell. Found
  ///    minutes after (1), by restoring the deleted line into the wrong
  ///    phase and watching the just-fixed assertion pass anyway.
  ///
  /// So: the app's phase is the one carrying `Assets.xcassets`, and
  /// membership is checked inside that list.
  String appResourcesFiles(String pbx) {
    const begin = '/* Begin PBXResourcesBuildPhase section */';
    const end = '/* End PBXResourcesBuildPhase section */';
    final i = pbx.indexOf(begin);
    final j = pbx.indexOf(end);
    expect(i, greaterThanOrEqualTo(0), reason: 'no $begin');
    expect(j, greaterThan(i), reason: 'no $end after $begin');
    final section = pbx.substring(i + begin.length, j);

    final lists = RegExp(r'files = \(([^)]*)\)')
        .allMatches(section)
        .map((m) => m.group(1)!)
        .where((f) => f.contains('Assets.xcassets in Resources'))
        .toList();
    expect(lists, hasLength(1),
        reason: 'expected exactly one resources phase carrying '
            'Assets.xcassets — that is how the app target is identified');
    return lists.single;
  }

  /// Pull `<string>` that follows a given plist key.
  String? plistValue(String xml, String key) {
    final i = xml.indexOf('<key>$key</key>');
    if (i < 0) return null;
    final open = xml.indexOf('<string>', i);
    final close = xml.indexOf('</string>', open);
    if (open < 0 || close < 0) return null;
    return xml.substring(open + '<string>'.length, close);
  }

  test('iOS home-screen name follows the device language', () {
    // 2026-08-23, from the user, three requests in one evening that
    // ended here: rename to Yahweh's Words; then 雅伟之言 because 14
    // Latin characters truncate on the home screen; then "要根据客户
    // 手机语言" — follow the phone's language, don't pick for the user.
    // iOS does that through per-locale InfoPlist.strings, which only
    // ship if the Xcode project registers the .lproj variants — hence
    // the pbxproj assertions: an unregistered localization fails
    // SILENTLY, showing every user the fallback.
    String lproj(String locale) =>
        read('ios/Runner/$locale.lproj/InfoPlist.strings');
    expect(lproj('en'), contains('"CFBundleDisplayName" = "Yahweh\'s Words"'));
    expect(lproj('zh-Hans'), contains('"CFBundleDisplayName" = "雅伟之言"'));
    expect(lproj('zh-Hant'), contains('"CFBundleDisplayName" = "雅偉之言"'));

    final pbx = read('ios/Runner.xcodeproj/project.pbxproj');
    expect(appResourcesFiles(pbx), contains('InfoPlist.strings in Resources'),
        reason: 'the variant group must be in the Resources build phase');
    for (final region in ['"zh-Hans"', '"zh-Hant"']) {
      expect(pbx, contains(region),
          reason: 'knownRegions must list $region');
    }

    // The plist value is only the fallback for unmatched languages.
    final plist = read('ios/Runner/Info.plist');
    expect(plistValue(plist, 'CFBundleDisplayName'), wanted);
    expect(plistValue(plist, 'CFBundleName'), wanted);
  });

  test('Android app_name follows the device language too', () {
    expect(read('android/app/src/main/res/values-zh/strings.xml'),
        contains('雅伟之言'));
    expect(read('android/app/src/main/res/values-zh-rTW/strings.xml'),
        contains('雅偉之言'));
    expect(read('android/app/src/main/res/values-zh-rHK/strings.xml'),
        contains('雅偉之言'));
    // The CN flavour stays distinguishable on zh devices.
    expect(read('android/app/src/cn/res/values-zh/strings.xml'),
        contains('雅伟之言 CN'));
  });

  test('macOS follows the system language too, like iOS and Android', () {
    // Until 2026-09-07 macOS was the one platform with a FIXED name.
    // iOS had followed the device language since 2026-08-23 and Android
    // since 2026-08-24, so one person's three devices disagreed: the Mi
    // Pad said 雅伟之言 while the MacBook said "Yahweh's Words". The user
    // asked why. The 2026-08-23 ruling — 要根据客户手机语言 — never had a
    // macOS carve-out; macOS was simply missed.
    //
    // Two keys, not one. CFBundleDisplayName is Finder, the Dock and
    // Spotlight; CFBundleName is the bold menu-bar item next to  — the
    // xib writes APP_NAME and macOS substitutes CFBundleName into it.
    // Localizing only the first leaves the menu bar in English.
    String lproj(String locale) =>
        read('macos/Runner/$locale.lproj/InfoPlist.strings');
    for (final e in {
      'en': "Yahweh's Words",
      'zh-Hans': '雅伟之言',
      'zh-Hant': '雅偉之言',
    }.entries) {
      expect(lproj(e.key), contains('"CFBundleDisplayName" = "${e.value}"'));
      expect(lproj(e.key), contains('"CFBundleName" = "${e.value}"'));
    }

    // An unregistered localization fails SILENTLY — the .lproj sits in
    // the source tree, never reaches the bundle, and every reader gets
    // the fallback. Verified 2026-09-07 by building macOS and listing
    // Contents/Resources: Base, en, zh-Hans, zh-Hant.
    final pbx = read('macos/Runner.xcodeproj/project.pbxproj');
    expect(appResourcesFiles(pbx), contains('InfoPlist.strings in Resources'),
        reason: 'the variant group must be in the Resources build phase');
    for (final region in ['"zh-Hans"', '"zh-Hant"']) {
      expect(pbx, contains(region), reason: 'knownRegions must list $region');
    }

    // The plist values stay as the fallback for unmatched languages.
    final plist = read('macos/Runner/Info.plist');
    expect(plistValue(plist, 'CFBundleDisplayName'), wanted);
    expect(plistValue(plist, 'CFBundleName'), wanted);

    // PRODUCT_NAME must stay as it is — see the note above. It names the
    // BUNDLE (`yswords.app`); nothing a reader sees reads it any more.
    final cfg = read('macos/Runner/Configs/AppInfo.xcconfig');
    expect(cfg, contains('PRODUCT_NAME = yswords'),
        reason: 'renaming the macOS product also renames the .app, and '
            'tools/yswords-ios-reinstall.sh installs to a hard-coded '
            '/Applications/yswords.app');
  });

  test('the web manifest is capitalised the same way', () {
    final manifest = read('web/manifest.json');
    expect(manifest, contains('"name": "$wanted"'));
    expect(manifest, contains('"short_name": "$wanted"'));
  });

  test('every Android flavour label starts with the new name', () {
    // The labels moved from gradle resValues into res files on
    // 2026-08-24: lint does not count generated resources as the
    // default locale, so the values-zh translations failed the build
    // as ExtraTranslation orphans. The default-locale name and its
    // flavour override now live where lint looks.
    String label(String path) {
      final m = RegExp(r'<string name="app_name">([^<]+)</string>')
          .firstMatch(read(path));
      expect(m, isNotNull, reason: 'no app_name in $path');
      return m!.group(1)!.replaceAll("\\'", "'");
    }

    expect(label('android/app/src/main/res/values/strings.xml'), wanted);
    expect(label('android/app/src/cn/res/values/strings.xml'), '$wanted CN');
    final gradle = read('android/app/build.gradle.kts');
    expect(gradle.contains('resValue("string", "app_name"'), isFalse,
        reason: 'a resValue would collide with the res-file definition');
  });

}
