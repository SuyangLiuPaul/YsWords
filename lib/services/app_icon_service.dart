// 2026-05-24 (v1.2.96): bridges the user's primaryColor pick in
// Settings to iOS's UIApplication.setAlternateIconName. The Swift
// side lives in ios/Runner/AppDelegate.swift; six alternate icon
// variants (Red / Orange / Green / Purple / Pink / Dark) ship as
// loose PNGs at ios/Runner/AppIcon-<Variant>{@2x,@3x,~ipad,
// @2x~ipad}.png and are declared in CFBundleIcons +
// CFBundleIcons~ipad in ios/Runner/Info.plist.
//
// Non-iOS platforms (web, macOS, Android, Linux, Windows) are a
// silent no-op: the channel just doesn't fire. Android does support
// adaptive icon variants via activity-alias swapping, but that's
// out of scope for v1.2.96 — the user's complaint was iOS-only.

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart' show Color, Colors;
import 'package:flutter/services.dart' show MethodChannel, PlatformException;

class AppIconService {
  AppIconService._();

  static const _channel = MethodChannel('yswords/ios_icon');

  /// Whether the current platform actually supports alternate icons.
  /// Only true on iOS / iPadOS. Web, macOS, Android, etc. return false
  /// so callers can short-circuit.
  static bool get isSupported {
    if (kIsWeb) return false;
    try {
      return Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  /// Maps a Material primary color picked by the user in Settings to
  /// the alternate-icon name shipped in the iOS bundle. Returns null
  /// for colors that should use the primary icon (light blue default,
  /// or colors that don't have a dedicated variant — yellow / lime /
  /// brown fall through to the closest match or to default).
  ///
  /// Variants shipped: Red, Orange, Green, Purple, Pink, Dark.
  /// Anything not in the map → primary icon (null).
  static String? iconNameForColor(Color color) {
    // Compare by underlying value so Color(0xff...) literals and the
    // Colors.X constants both work.
    final v = (color.r * 255).round() << 16 |
        (color.g * 255).round() << 8 |
        (color.b * 255).round();
    // ignore: deprecated_member_use
    final raw = color.value & 0xFFFFFF;
    final key = raw == 0 ? v : raw;

    // Red family
    if (color == Colors.red ||
        color == Colors.deepOrange ||
        key == (Colors.red.toARGB32() & 0xFFFFFF) ||
        key == (Colors.deepOrange.toARGB32() & 0xFFFFFF)) {
      return 'AppIcon-Red';
    }
    // Orange / amber / yellow / lime — all use the Orange variant
    if (color == Colors.orange ||
        color == Colors.amber ||
        color == Colors.yellow ||
        color == Colors.lime) {
      return 'AppIcon-Orange';
    }
    // Green family
    if (color == Colors.lightGreen ||
        color == Colors.green ||
        color == Colors.teal) {
      return 'AppIcon-Green';
    }
    // Purple family
    if (color == Colors.deepPurple ||
        color == Colors.purple ||
        color == Colors.indigo) {
      return 'AppIcon-Purple';
    }
    // Pink (Material) — closest to pink variant
    if (color == Colors.pink) {
      return 'AppIcon-Pink';
    }
    // Neutral palette (brown / grey / blueGrey) → dark variant
    if (color == Colors.brown ||
        color == Colors.grey ||
        color == Colors.blueGrey) {
      return 'AppIcon-Dark';
    }
    // Light blue / cyan / blue — default light-blue icon. Return
    // null to keep the primary icon.
    return null;
  }

  /// Swap the iOS home-screen icon to match [color]. Pass `null` or a
  /// color that maps to no variant (light blue, cyan, blue) to revert
  /// to the primary icon. iOS will show a system alert the first time
  /// the icon changes for a given session ("You have changed the
  /// icon for ..."). That alert is OS-controlled and can't be
  /// suppressed.
  ///
  /// Safe to call on non-iOS platforms (no-op).
  static Future<void> updateForColor(Color? color) async {
    if (!isSupported) return;
    final name = color == null ? null : iconNameForColor(color);
    try {
      // Read the current icon name so we don't fire setAlternateIconName
      // (which can trigger the OS alert) when nothing actually changes.
      final current = await _channel.invokeMethod<String?>('currentIconName');
      if (current == name) {
        debugPrint('[AppIconService] icon already $name — skipping');
        return;
      }
      debugPrint('[AppIconService] swap icon: $current → $name');
      await _channel
          .invokeMethod<bool>('setIcon', <String, dynamic>{'name': name});
    } on PlatformException catch (e) {
      // UNSUPPORTED on simulators / older devices is non-fatal.
      debugPrint('[AppIconService] setIcon failed: $e');
    } catch (e) {
      debugPrint('[AppIconService] unexpected error: $e');
    }
  }
}
