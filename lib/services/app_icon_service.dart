// Themed app-icon swap across iOS / Android / macOS / Web.
//
// v1.2.96 shipped iOS-only via UIApplication.setAlternateIconName.
// v1.2.97 extends to:
//
//   Android: each variant is an <activity-alias> in
//     android/app/src/main/AndroidManifest.xml. MainActivity.kt
//     handles the yswords/android_icon channel and toggles aliases
//     via PackageManager.setComponentEnabledSetting. Launcher icon
//     swap may take 1-3 s and the app can briefly disappear from
//     the launcher grid while the system re-indexes — Android-OS
//     behaviour, not avoidable.
//     2026-06-16 (v1.3.85): the channel's setIcon now only QUEUES
//     the swap; MainActivity applies it in onStop() (when the app is
//     backgrounded). Applying it in the foreground disabled the
//     component the task is rooted on, which Android tears down even
//     with DONT_KILL_APP — that made the app "quit" on every colour
//     change. So on Android the home-screen icon updates once the
//     user leaves the app, not the instant the colour is picked.
//
//   macOS: dock-only. NSApplication.applicationIconImage is the
//     only public API; Finder / Launchpad / Get-Info icons are
//     read from AppIcon.icns at install time and CAN'T be changed
//     at runtime. We ship variant PNGs as Flutter assets at
//     assets/themed_icons/<Variant>.png, load bytes via
//     rootBundle.load, and send to MainFlutterWindow.swift's
//     yswords/macos_icon channel.
//
//   Web: favicon-only. document.querySelector('link[rel="icon"]')
//     swap updates the browser tab. PWA "Add to Home Screen" icon
//     is captured at install time and not changeable runtime. We
//     ship variant PNGs at web/icons/Icon-<Variant>-<size>.png and
//     update the live <link> hrefs.

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart' show Color, Colors;
import 'package:flutter/services.dart'
    show MethodChannel, PlatformException, rootBundle;

import 'package:yswords/services/app_icon_service_web.dart'
    if (dart.library.io) 'package:yswords/services/app_icon_service_web_stub.dart'
    as web_impl;

class AppIconService {
  AppIconService._();

  static const _iosChannel = MethodChannel('yswords/ios_icon');
  static const _androidChannel = MethodChannel('yswords/android_icon');
  static const _macosChannel = MethodChannel('yswords/macos_icon');

  /// True on platforms where we know how to swap *something* (Dock,
  /// favicon, launcher, home-screen). Used by Settings UI to gate
  /// any "icon follows theme" toggle in the future.
  static bool get isSupported {
    if (kIsWeb) return true; // favicon swap works in every browser
    try {
      return Platform.isIOS || Platform.isAndroid || Platform.isMacOS;
    } catch (_) {
      return false;
    }
  }

  /// Returns the variant suffix (Red / Orange / Green / Purple /
  /// Pink / Dark) for a given Material primaryColor, or null when
  /// the colour maps to the primary (light-blue) icon.
  ///
  /// 2026-06-14 (v1.3.70): compare by ARGB VALUE, not `==`. The picker
  /// hands us a `MaterialColor` const (e.g. `Colors.red`), but the value
  /// restored from SharedPreferences on every launch is a plain `Color`
  /// — and `Color(0xFFF44336) == Colors.red` is FALSE (different
  /// runtimeType). The old identity check meant the startup re-apply
  /// (and any post-restart call) mapped every colour to "no variant",
  /// silently reverting the icon to primary. Value comparison works for
  /// both the const swatch and the restored plain colour.
  static String? variantForColor(Color color) {
    final v = color.toARGB32();
    bool isVal(Color c) => v == c.toARGB32();
    if (isVal(Colors.red) || isVal(Colors.deepOrange)) {
      return 'Red';
    }
    if (isVal(Colors.orange) ||
        isVal(Colors.amber) ||
        isVal(Colors.yellow) ||
        isVal(Colors.lime)) {
      return 'Orange';
    }
    if (isVal(Colors.lightGreen) ||
        isVal(Colors.green) ||
        isVal(Colors.teal)) {
      return 'Green';
    }
    if (isVal(Colors.deepPurple) ||
        isVal(Colors.purple) ||
        isVal(Colors.indigo)) {
      return 'Purple';
    }
    if (isVal(Colors.pink)) {
      return 'Pink';
    }
    if (isVal(Colors.brown) ||
        isVal(Colors.grey) ||
        isVal(Colors.blueGrey)) {
      return 'Dark';
    }
    // light blue / cyan / blue → primary (no variant)
    return null;
  }

  /// iOS naming: `AppIcon-<Variant>` (matches CFBundleAlternateIcons
  /// key). Null = primary icon.
  static String? _iosNameForVariant(String? variant) =>
      variant == null ? null : 'AppIcon-$variant';

  /// Swap the home-screen / dock / favicon to match [color]. No-op
  /// on unsupported platforms.
  static Future<void> updateForColor(Color? color) async {
    if (color == null) return _revertToPrimary();
    final variant = variantForColor(color);

    if (kIsWeb) {
      try {
        web_impl.setFaviconForVariant(variant);
      } catch (e) {
        debugPrint('[AppIconService] web favicon swap failed: $e');
      }
      return;
    }

    try {
      if (Platform.isIOS) {
        // Apply immediately in the foreground. v1.3.90 tried deferring this
        // to the app-background transition (to work around iOS 26/27 only
        // repainting the icon on the FIRST foreground change), but that
        // REGRESSED working devices: on iOS the app suspends before the
        // background platform-channel round-trip completes, so the swap
        // often never ran at all — the iPad (which used to change every
        // time) stopped changing. Immediate apply restores the iPad and the
        // iPhone's first change; the iPhone's subsequent-change-not-
        // repainting is an OS-side SpringBoard bug we can't fix from Dart.
        final name = _iosNameForVariant(variant);
        developer.log('iOS updateForColor variant=$variant target=$name',
            name: 'yswords.icon');
        final current =
            await _iosChannel.invokeMethod<String?>('currentIconName');
        developer.log('iOS currentIconName=$current', name: 'yswords.icon');
        if (current == name) {
          developer.log('iOS icon already $name — skip', name: 'yswords.icon');
          return; // already set; skip OS alert
        }
        final ok = await _iosChannel
            .invokeMethod<bool>('setIcon', <String, dynamic>{'name': name});
        developer.log('iOS setIcon($name) -> $ok', name: 'yswords.icon');
      } else if (Platform.isAndroid) {
        final name = _iosNameForVariant(variant); // same string key
        final current =
            await _androidChannel.invokeMethod<String?>('currentIconName');
        if (current == name) return;
        await _androidChannel
            .invokeMethod<bool>('setIcon', <String, dynamic>{'name': name});
      } else if (Platform.isMacOS) {
        Uint8List? bytes;
        if (variant != null) {
          final data = await rootBundle
              .load('assets/themed_icons/$variant.png');
          bytes = data.buffer.asUint8List();
        }
        await _macosChannel.invokeMethod<bool>(
            'setIconBytes', <String, dynamic>{'bytes': bytes});
      }
    } on PlatformException catch (e) {
      developer.log('setIcon PlatformException: $e', name: 'yswords.icon');
      debugPrint('[AppIconService] setIcon failed: $e');
    } catch (e) {
      // A MissingPluginException lands here — the channel handler wasn't
      // reachable. This is exactly the v1.3.72 symptom; the device log
      // makes it visible in a release build.
      developer.log('setIcon unexpected (channel unreachable?): $e',
          name: 'yswords.icon');
      debugPrint('[AppIconService] unexpected: $e');
    }
  }

  static Future<void> _revertToPrimary() async {
    if (kIsWeb) {
      try {
        web_impl.setFaviconForVariant(null);
      } catch (_) {}
      return;
    }
    try {
      if (Platform.isIOS) {
        await _iosChannel
            .invokeMethod<bool>('setIcon', <String, dynamic>{'name': null});
      } else if (Platform.isAndroid) {
        await _androidChannel
            .invokeMethod<bool>('setIcon', <String, dynamic>{'name': null});
      } else if (Platform.isMacOS) {
        await _macosChannel.invokeMethod<bool>(
            'setIconBytes', <String, dynamic>{'bytes': null});
      }
    } catch (e) {
      debugPrint('[AppIconService] revert failed: $e');
    }
  }
}
