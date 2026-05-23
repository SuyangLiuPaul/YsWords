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
  static String? variantForColor(Color color) {
    if (color == Colors.red ||
        color == Colors.deepOrange) {
      return 'Red';
    }
    if (color == Colors.orange ||
        color == Colors.amber ||
        color == Colors.yellow ||
        color == Colors.lime) {
      return 'Orange';
    }
    if (color == Colors.lightGreen ||
        color == Colors.green ||
        color == Colors.teal) {
      return 'Green';
    }
    if (color == Colors.deepPurple ||
        color == Colors.purple ||
        color == Colors.indigo) {
      return 'Purple';
    }
    if (color == Colors.pink) {
      return 'Pink';
    }
    if (color == Colors.brown ||
        color == Colors.grey ||
        color == Colors.blueGrey) {
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
        final name = _iosNameForVariant(variant);
        final current =
            await _iosChannel.invokeMethod<String?>('currentIconName');
        if (current == name) return; // already set; skip OS alert
        await _iosChannel
            .invokeMethod<bool>('setIcon', <String, dynamic>{'name': name});
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
      debugPrint('[AppIconService] setIcon failed: $e');
    } catch (e) {
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
