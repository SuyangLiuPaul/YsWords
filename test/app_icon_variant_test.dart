// 2026-06-14 (v1.3.70): guards the iOS/Android/macOS themed-icon mapping.
//
// Regression: variantForColor used `color == Colors.red` (identity).
// The picker passes a MaterialColor const, but the colour restored from
// SharedPreferences on every launch is a plain `Color` whose `==` against
// a MaterialColor is false — so the startup icon re-apply mapped every
// colour to "no variant" and silently reverted the icon to primary.
// The fix compares by ARGB value, which must work for BOTH forms.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/services/app_icon_service.dart';

void main() {
  group('AppIconService.variantForColor', () {
    test('maps MaterialColor consts (the picker path)', () {
      expect(AppIconService.variantForColor(Colors.red), 'Red');
      expect(AppIconService.variantForColor(Colors.deepOrange), 'Red');
      expect(AppIconService.variantForColor(Colors.orange), 'Orange');
      expect(AppIconService.variantForColor(Colors.teal), 'Green');
      expect(AppIconService.variantForColor(Colors.indigo), 'Purple');
      expect(AppIconService.variantForColor(Colors.pink), 'Pink');
      expect(AppIconService.variantForColor(Colors.grey), 'Dark');
    });

    test('maps plain Colors restored from prefs (the startup path)', () {
      // Simulate SharedPreferences round-trip: store toARGB32(), reload
      // as a plain Color. This is what broke before the value-compare fix.
      Color restored(Color c) => Color(c.toARGB32());
      expect(AppIconService.variantForColor(restored(Colors.red)), 'Red');
      expect(AppIconService.variantForColor(restored(Colors.amber)), 'Orange');
      expect(AppIconService.variantForColor(restored(Colors.green)), 'Green');
      expect(
          AppIconService.variantForColor(restored(Colors.deepPurple)), 'Purple');
      expect(AppIconService.variantForColor(restored(Colors.pink)), 'Pink');
      expect(AppIconService.variantForColor(restored(Colors.blueGrey)), 'Dark');
    });

    test('blue family maps to the primary icon (no variant)', () {
      expect(AppIconService.variantForColor(Colors.lightBlue), isNull);
      expect(AppIconService.variantForColor(Colors.blue), isNull);
      expect(AppIconService.variantForColor(Colors.cyan), isNull);
      // Plain-Color form too.
      expect(AppIconService.variantForColor(Color(Colors.blue.toARGB32())),
          isNull);
    });
  });
}
