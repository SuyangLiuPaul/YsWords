import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The app is called **YsWords** — capital Y, capital W.
///
/// 2026-08-17, from the user after a fresh install: "app name应该是
/// YsWords不是Yswords". The home screen read "Yswords" on iOS and
/// "yswords" on macOS, while web and Android already had it right.
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
  const wanted = 'YsWords';

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

  test('iOS shows YsWords on the home screen', () {
    final plist = read('ios/Runner/Info.plist');
    expect(plistValue(plist, 'CFBundleDisplayName'), wanted);
  });

  test('iOS CFBundleName matches too', () {
    // Used where the display name is too long to fit; a lowercase
    // fallback there is exactly as visible as the wrong one was.
    final plist = read('ios/Runner/Info.plist');
    expect(plistValue(plist, 'CFBundleName'), wanted);
  });

  test('macOS shows YsWords, without renaming the bundle', () {
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

  test('every Android flavour label starts with YsWords', () {
    // Two flavours ship: the international one and "YsWords CN". Both
    // must carry the same capitalisation.
    final gradle = read('android/app/build.gradle.kts');
    final labels = RegExp(r'resValue\("string", "app_name", "([^"]+)"\)')
        .allMatches(gradle)
        .map((m) => m.group(1)!)
        .toList();

    expect(labels, isNotEmpty, reason: 'no app_name resValue found');
    for (final label in labels) {
      expect(label.startsWith(wanted), isTrue,
          reason: 'Android flavour label "$label" is not capitalised '
              'like $wanted');
    }
  });
}
