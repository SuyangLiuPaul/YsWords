/// 2026-05-24 (v1.3.23): regression tests for
library;
//
/// `MainProvider.dropCachesOnMemoryPressure()` (added in v1.3.22).
/// The contract:
///   - currently-active version is preserved in the verses LRU
///   - every other cached version is evicted
///   - paragraph LRU is fully cleared
///   - no notifyListeners() fires (on-screen rendering must not
///     ripple from a cache drop)
///
/// We test by calling `preloadVersion` to populate the LRU, set
/// `currentVersion`, and assert hasCachedVersion() before/after.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/providers/main_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('dropCachesOnMemoryPressure', () {
    test('preserves the currently-active version', () {
      final mp = MainProvider();
      // Seed three versions directly into the cache via the public
      // `cacheVersion` helper. (Avoids the asset-load round-trip
      // that `preloadVersion` does.)
      mp.cacheVersionForTest('kjv', _fakeVerses());
      mp.cacheVersionForTest('cuvs-yhwh', _fakeVerses());
      mp.cacheVersionForTest('cnv', _fakeVerses());
      mp.currentVersion = 'kjv';

      expect(mp.hasCachedVersion('kjv'), isTrue);
      expect(mp.hasCachedVersion('cuvs-yhwh'), isTrue);
      expect(mp.hasCachedVersion('cnv'), isTrue);

      mp.dropCachesOnMemoryPressure();

      expect(mp.hasCachedVersion('kjv'), isTrue,
          reason: 'active version must survive memory pressure');
      expect(mp.hasCachedVersion('cuvs-yhwh'), isFalse,
          reason: 'inactive version must be evicted');
      expect(mp.hasCachedVersion('cnv'), isFalse,
          reason: 'inactive version must be evicted');
    });

    test('handles empty cache gracefully', () {
      final mp = MainProvider();
      mp.currentVersion = 'kjv';
      // Should not throw on an empty LRU.
      expect(() => mp.dropCachesOnMemoryPressure(), returnsNormally);
    });

    test('handles current version NOT in cache (no-op preserve)', () {
      final mp = MainProvider();
      mp.cacheVersionForTest('cuvs-yhwh', _fakeVerses());
      mp.currentVersion = 'kjv'; // not cached
      mp.dropCachesOnMemoryPressure();
      // All versions cleared because current wasn't in the LRU.
      expect(mp.hasCachedVersion('kjv'), isFalse);
      expect(mp.hasCachedVersion('cuvs-yhwh'), isFalse);
    });

    test('does NOT fire notifyListeners (avoids spurious rebuilds)', () {
      final mp = MainProvider();
      mp.cacheVersionForTest('kjv', _fakeVerses());
      mp.cacheVersionForTest('cnv', _fakeVerses());
      mp.currentVersion = 'kjv';

      var notifyCount = 0;
      void listener() => notifyCount++;
      mp.addListener(listener);

      mp.dropCachesOnMemoryPressure();

      expect(notifyCount, 0,
          reason: 'cache drop must not trigger on-screen rebuild');

      mp.removeListener(listener);
    });

    test('evicts ALL inactive versions even when many are cached', () {
      final mp = MainProvider();
      final versions = [
        'kjv', 'cuvs-yhwh', 'cuv', 'cnv', 'nasb',
        'cuv-tr', 'cuvs-yhwh-tr', 'cnv-tr',
      ];
      for (final v in versions) {
        mp.cacheVersionForTest(v, _fakeVerses());
      }
      mp.currentVersion = 'cuvs-yhwh';

      mp.dropCachesOnMemoryPressure();

      for (final v in versions) {
        final expected = v == 'cuvs-yhwh';
        expect(mp.hasCachedVersion(v), expected,
            reason: 'only the active version (cuvs-yhwh) survives');
      }
    });
  });
}

/// A short fake verse list to seed the LRU without bundling assets.
/// Three verses is enough to exercise the cache machinery; the
/// content is irrelevant.
List<Verse> _fakeVerses() {
  return [
    const Verse(book: 'Genesis', chapter: 1, verse: 1, text: 'fake1'),
    const Verse(book: 'Genesis', chapter: 1, verse: 2, text: 'fake2'),
    const Verse(book: 'Genesis', chapter: 1, verse: 3, text: 'fake3'),
  ];
}

// Test-only diagnostic if needed during refactor:
// ignore: unused_element
void _dump(MainProvider mp, List<String> versions) {
  for (final v in versions) {
    debugPrint('  $v cached=${mp.hasCachedVersion(v)}');
  }
}
