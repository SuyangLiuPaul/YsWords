// `/logo` is a public, hotlinkable address for the app mark — it exists
// so an email signature can point at one stable URL.
//
// Everything it depends on fails SILENTLY, which is why it is pinned
// here rather than left to a manual check:
//
//   * Put the rule below the SPA catch-all and `/logo` still answers
//     200 — with `index.html`. Measured on yswords-dev before the rule
//     existed: `200 text/html`, the whole single-page app. A mail client
//     asked for a picture and got a web page; the recipient sees a
//     broken image, and nothing anywhere reports an error.
//   * Point the rule at a file that is not there and Netlify falls
//     through to the same catch-all, with the same silent result.
//   * Let the PNG grow and every recipient pays for it on every open.
//
// None of the three shows up in `flutter analyze`, in the app, or in a
// deploy log. They show up in somebody's inbox.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final netlifyToml = File('netlify.toml').readAsStringSync();

  group('/logo endpoint', () {
    test('netlify.toml rewrites /logo to a PNG', () {
      expect(
        netlifyToml,
        contains('from = "/logo"'),
        reason: 'the /logo rewrite rule is gone; /logo now serves index.html',
      );
      expect(
        netlifyToml,
        contains('to = "/logo/logo-256.png"'),
        reason: 'the /logo rule no longer targets the 256px PNG',
      );
    });

    test('the /logo rule sits ABOVE the SPA catch-all', () {
      // Netlify evaluates redirect rules top to bottom and takes the
      // first match. `/*` matches everything, so anything after it is
      // unreachable — and unreachable here means /logo quietly serves
      // the app instead of the image.
      final logoAt = netlifyToml.indexOf('from = "/logo"');
      final catchAllAt = netlifyToml.indexOf('from = "/*"');

      expect(logoAt, isNot(-1), reason: 'no /logo rule at all');
      expect(catchAllAt, isNot(-1),
          reason: 'the SPA catch-all is gone — that is a separate bug');
      expect(
        logoAt,
        lessThan(catchAllAt),
        reason: 'the /logo rule is below the /* catch-all, so it never '
            'matches and /logo serves index.html as text/html',
      );
    });

    test('every size the rule can reach actually exists, and is a PNG', () {
      for (final size in const [128, 256, 512]) {
        final f = File('web/logo/logo-$size.png');
        expect(f.existsSync(), isTrue,
            reason: 'web/logo/logo-$size.png is missing');

        // Not "is the extension .png" — the actual 8-byte PNG signature.
        // A rewrite to a file that is secretly something else would be
        // served with the wrong Content-Type and render as nothing.
        final header = f.readAsBytesSync().take(8).toList();
        expect(header, equals(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
            reason: 'web/logo/logo-$size.png is not a PNG');
      }
    });

    test('the signature default stays small enough to mail', () {
      // Re-fetched on every open of every message that embeds it. The
      // unoptimised sips resize of this same art was 82 KB; quantising
      // flat artwork to 64 colours took it to 7 KB with 0.5% mean error.
      // 20 KB leaves room to re-export without silently regressing an
      // order of magnitude.
      final bytes = File('web/logo/logo-256.png').lengthSync();
      expect(bytes, lessThan(20 * 1024),
          reason: 'logo-256.png is ${(bytes / 1024).round()} KB — too heavy '
              'for something every recipient downloads on every open');
    });
  });
}
