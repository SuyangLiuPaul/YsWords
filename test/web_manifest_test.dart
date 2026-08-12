import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The installed web app must not refuse landscape.
///
/// 2026-08-12, from a Xiaomi Pad: "webapp打开两边是黑的不能像ipad
/// webapp一样吗" — the PWA opened as a portrait-shaped window with black
/// bars either side, while the identical build filled the screen on an
/// iPad.
///
/// The cause was `"orientation": "portrait-primary"` in the manifest.
/// Android honours that lock for an installed PWA; **iOS and iPadOS
/// ignore the manifest `orientation` field entirely** — Safari does not
/// implement it — so the setting was invisible on every device the app
/// was being tested on and broke only the one it wasn't.
///
/// That asymmetry is why this is a test and not a fixed comment: a
/// future edit re-adding the lock would look correct on an iPad, and
/// nobody would find out until an Android tablet user said so.
void main() {
  late Map<String, dynamic> manifest;

  setUpAll(() {
    manifest = jsonDecode(File('web/manifest.json').readAsStringSync())
        as Map<String, dynamic>;
  });

  test('the manifest does not lock the app to portrait', () {
    final orientation = manifest['orientation'];
    // Absent is the intended state. "any" is equally fine — what must
    // never come back is a lock to one orientation.
    expect(
      orientation == null || orientation == 'any',
      isTrue,
      reason: 'orientation is ${jsonEncode(orientation)}. An installed '
          'PWA on Android is letterboxed with black bars when this is '
          'locked, and iOS ignores the field, so the damage is only '
          'visible on Android tablets.',
    );
  });

  test('the manifest is still a valid installable PWA', () {
    // Removing a key by hand is exactly the kind of edit that can drop
    // a comma and leave the file parseable-but-wrong, so check that the
    // fields an install depends on all survived.
    expect(manifest['name'], isNotEmpty);
    expect(manifest['short_name'], isNotEmpty);
    expect(manifest['start_url'], isNotEmpty);
    expect(manifest['display'], 'standalone');

    final icons = manifest['icons'] as List;
    expect(icons, isNotEmpty);
    final sizes = icons.map((i) => (i as Map)['sizes']).toSet();
    expect(sizes, containsAll(['192x192', '512x512']),
        reason: 'Android needs both to build a WebAPK');
  });
}
