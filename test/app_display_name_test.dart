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
///   macOS     macos/Runner/Info.plist    CFBundleDisplayName
///
/// macOS is deliberately fixed with CFBundleDisplayName rather than by
/// changing `PRODUCT_NAME` in AppInfo.xcconfig: PRODUCT_NAME also names
/// the built bundle, and `/Applications/yswords.app` is hard-coded in
/// `tools/yswords-ios-reinstall.sh`. Renaming it there would install to
/// a new path and leave the old app sitting on the Mac.
void main() {
  const wanted = "Yahweh's Words";

  String read(String path) => File(path).readAsStringSync();

  /// Pull `<string>` that follows a given plist key.
  String? plistValue(String xml, String key) {
    final i = xml.indexOf('<key>$key</key>');
    if (i < 0) return null;
    final open = xml.indexOf('<string>', i);
    final close = xml.indexOf('</string>', open);
    if (open < 0 || close < 0) return null;
    return xml.substring(open + '<string>'.length, close);
  }

  test('iOS shows 雅伟之言 on the home screen', () {
    // 2026-08-23, right after the rename: "Yahweh's Words" is 14
    // characters and the iOS home screen truncates it to "Yahweh's
    // Wo…", so the user chose the four-character Chinese name for the
    // icon label ("CFBundleDisplayName 改成雅伟之言吧"). iOS only —
    // macOS docks and menus do not truncate, so the Mac keeps the full
    // English name.
    final plist = read('ios/Runner/Info.plist');
    expect(plistValue(plist, 'CFBundleDisplayName'), '雅伟之言');
  });

  test('iOS CFBundleName carries the full English name', () {
    // The fallback shown where a display name cannot be used; the
    // Latin form is the safer of the two there.
    final plist = read('ios/Runner/Info.plist');
    expect(plistValue(plist, 'CFBundleName'), wanted);
  });

  test('macOS shows the new name, without renaming the bundle', () {
    final plist = read('macos/Runner/Info.plist');
    expect(plistValue(plist, 'CFBundleDisplayName'), wanted);

    // PRODUCT_NAME must stay as it is — see the note above.
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
    // Two flavours ship: the international one and the CN one. Both
    // must carry the same name.
    final gradle = read('android/app/build.gradle.kts');
    final labels = RegExp(r'resValue\("string", "app_name", "([^"]+)"\)')
        .allMatches(gradle)
        .map((m) => m.group(1)!)
        .toList();

    expect(labels, isNotEmpty, reason: 'no app_name resValue found');
    for (final raw in labels) {
      // The gradle source carries the apostrophe ESCAPED (\\') so it
      // survives AAPT's XML-style quoting — un-escape before comparing,
      // because the home screen shows the unescaped form.
      final label = raw.replaceAll("\\\\'", "'");
      expect(label.startsWith(wanted), isTrue,
          reason: 'Android flavour label "$label" is not capitalised '
              'like $wanted');
    }
  });
}
