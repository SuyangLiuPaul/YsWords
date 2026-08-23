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

  test('the deployed per-site manifests do not lock portrait either', () {
    // The first pass at this fix removed the key from web/manifest.json
    // and stopped. That changed nothing a user could see: deploy_site.py
    // overlays tools/site-icons/<flavour>-<tier>/manifest.json onto every
    // Netlify deploy, so all six sites kept serving
    // "orientation": "portrait-primary" and the Xiaomi Pad stayed
    // letterboxed. The overlay files are what actually ship — sweep them
    // all so neither a hand edit nor a regeneration from a stale
    // generate_site_icons.py template can bring the lock back unseen.
    final variantDirs = Directory('tools/site-icons')
        .listSync()
        .whereType<Directory>()
        .toList();
    // Guard the sweep itself: if the site-icons layout ever moves, an
    // empty listing must fail loudly instead of passing over nothing.
    expect(
      variantDirs.length,
      greaterThanOrEqualTo(6),
      reason: 'expected the 6 per-site icon variants under '
          'tools/site-icons; did the layout move?',
    );
    for (final dir in variantDirs) {
      final file = File('${dir.path}/manifest.json');
      expect(file.existsSync(), isTrue,
          reason: '${dir.path} has no manifest.json to overlay');
      final m = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final orientation = m['orientation'];
      expect(
        orientation == null || orientation == 'any',
        isTrue,
        reason: '${file.path} has orientation ${jsonEncode(orientation)}; '
            'deploy_site.py ships this exact file, so the Android '
            'letterbox comes straight back.',
      );
    }
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
