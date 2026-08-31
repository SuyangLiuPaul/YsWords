// IndexNow ownership — `tools/indexnow_submit.dart` and the key file it
// depends on.
//
// The failure this guards is the protocol's worst one: if the key file
// stops matching, every submission comes back a bare **403 Forbidden**
// with no message saying which of the three possible causes it was (file
// missing, file unreadable, key not in the file). Nothing else in the
// app changes, nothing in a browser looks different, and the URLs simply
// stop being pushed — silently, for as long as nobody re-runs the tool
// by hand.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tools/indexnow_submit.dart' show kKey, kSitemaps, kHost;
import '../tools/prerender_bible.dart' show prerenderVersions;

void main() {
  group('the IndexNow key file', () {
    test('exists, is named after itself, and contains exactly the key', () {
      final f = File('web/$kKey.txt');
      expect(f.existsSync(), isTrue,
          reason: 'web/$kKey.txt is gone — every IndexNow submission will '
              '403 with no explanation');
      // Content must equal the FILENAME, byte for byte. A trailing
      // newline is the classic way this breaks; the tool trims before
      // comparing, but the spec asks for the bare key, so ship the bare
      // key.
      expect(f.readAsStringSync().trim(), kKey);
    });

    test('there is exactly one key file, not a graveyard of old ones', () {
      // Rotating the key means replacing the file. Leaving the previous
      // one behind still validates, so the mistake never surfaces — but
      // it publishes a stale ownership token indefinitely.
      final keys = Directory('web')
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last)
          .where((n) => RegExp(r'^[0-9a-f]{8,128}\.txt$').hasMatch(n))
          .toList();
      expect(keys, ['$kKey.txt']);
    });

    test('the key is a shape the protocol accepts', () {
      // IndexNow: 8–128 characters, [a-zA-Z0-9-] only. A key outside
      // that range is rejected as 422, which reads like a URL problem.
      expect(kKey.length, inInclusiveRange(8, 128));
      expect(RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(kKey), isTrue);
    });
  });

  group('what it submits', () {
    test('one sitemap per prerendered edition, plus home', () {
      // The submit tool holds its own literal list because it talks to
      // the LIVE site, not the source tree. That independence is the
      // point — and it is also exactly how the two drift apart, so pin
      // them here.
      final expected = <String>{
        'sitemap-home.xml',
        for (final v in prerenderVersions) 'sitemap-$v.xml',
      };
      expect(kSitemaps.toSet(), expected);
    });

    test('the static sitemap index names the same children', () {
      final index = File('web/sitemap.xml').readAsStringSync();
      for (final name in kSitemaps) {
        expect(index, contains('https://$kHost/$name'),
            reason: '$name is submitted to IndexNow but is not in '
                'web/sitemap.xml — one of the two is wrong');
      }
    });
  });
}
