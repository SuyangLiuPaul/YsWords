// 2026-05-24 (v1.2.97): web favicon swap. The conditional import in
// app_icon_service.dart pulls this on web only (the `dart.library.io`
// branch falls through to the stub on native). Updates the live
// <link rel="icon"> hrefs so the browser tab + bookmark icon track
// the user's primaryColor.
//
// PWA install caveat: the manifest.json's `icons` field is read at
// install time and snapshotted. After install, swapping the manifest
// or favicon does NOT update the home-screen icon — that's a Service
// Worker / browser behaviour we can't override. So:
//   - Browser tab favicon: tracks theme ✓
//   - Bookmark icon: tracks theme ✓
//   - Pinned tab favicon: tracks theme ✓
//   - PWA home-screen icon (installed): static after install ✗
//
// File layout: web/icons/Icon-<Variant>-{192,512}.png shipped by
// gen_icons_all.py. variant=null → revert to the default
// web/favicon.png + Icon-{192,512}.png.

import 'package:web/web.dart' as web;

void setFaviconForVariant(String? variant) {
  final doc = web.document;
  // Resolve every <link rel="icon"> in the document head and rewrite
  // its href based on the link's `sizes` attribute. For un-sized
  // (legacy) icons we point at the default favicon path so behaviour
  // matches a fresh tab open.
  final links = doc.querySelectorAll('link[rel="icon"]');
  for (var i = 0; i < links.length; i++) {
    final el = links.item(i);
    if (el == null) continue;
    final link = el as web.HTMLLinkElement;
    final sizes = link.getAttribute('sizes') ?? '';
    if (variant == null) {
      // Revert
      if (sizes.startsWith('192')) {
        link.href = 'icons/Icon-192.png';
      } else if (sizes.startsWith('512')) {
        link.href = 'icons/Icon-512.png';
      } else {
        link.href = 'favicon.png';
      }
    } else {
      if (sizes.startsWith('192')) {
        link.href = 'icons/Icon-$variant-192.png';
      } else if (sizes.startsWith('512')) {
        link.href = 'icons/Icon-$variant-512.png';
      } else {
        // Default un-sized favicon — pick the 192 variant for
        // browsers that ignore sized hints.
        link.href = 'icons/Icon-$variant-192.png';
      }
    }
  }
}
