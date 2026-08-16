/// 2026-08-16 — regression tests for a P0 the user reported twice, on
/// macOS and on iPhone: "从雅伟版换成梁版的时候，为什么没有切换我试多几次就
/// 可以了" / "一定要在 iphone ios version 上面换 version 几次才切换过去".
///
/// The screenshots showed the header chip reading 梁简 over 和合本雅伟版
/// text. That is not a cosmetic lag — it is the app naming a translation
/// the reader is not reading, on a screen they may well quote from.
///
/// Mechanism: `MainProvider.currentVersion` moves the instant a switch
/// starts (it is the input `FetchVerses.execute` uses to pick an asset),
/// but `verses` only moves when the decode commits. The header chip read
/// `currentVersion`, so any switch that took a while — or failed outright,
/// which it could, because `FetchVerses.execute` rethrows after its last
/// attempt and the reading pane's `try` had only a `finally` — left the
/// two disagreeing with no way back.
///
/// The invariant these tests defend: **the label follows the verses.**
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/providers/main_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // `setVersion` persists the choice, so the plugin has to answer.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('renderedVersion never leads the verses on screen', () {
    test('an optimistic setVersion does NOT move the label', () {
      final mp = MainProvider();
      mp.currentVersion = 'cuvs-yhwh';
      mp.setVerses(_versesFor('cuvs-yhwh'));
      expect(mp.renderedVersion, 'cuvs-yhwh');

      // The tap: currentVersion moves so FetchVerses knows what to load.
      mp.setVersion('biblexg-v2');

      expect(mp.currentVersion, 'biblexg-v2');
      expect(mp.renderedVersion, 'cuvs-yhwh',
          reason: 'the decode has not landed — the reader is still in '
              'cuvs-yhwh and the chip must still say so');
      expect(mp.verses.first.text, contains('cuvs-yhwh'),
          reason: 'sanity: the verses really are still the old ones');
    });

    test('the label moves only when the new verses commit', () {
      final mp = MainProvider();
      mp.currentVersion = 'cuvs-yhwh';
      mp.setVerses(_versesFor('cuvs-yhwh'));

      mp.setVersion('biblexg-v2');
      mp.setVerses(_versesFor('biblexg-v2'));

      expect(mp.renderedVersion, 'biblexg-v2');
      expect(mp.verses.first.text, contains('biblexg-v2'));
    });

    test('a switch that THROWS mid-load leaves label and verses agreeing '
        'once the pane reverts', () {
      // Reproduces the reported failure end-to-end at provider level:
      // tap → optimistic setVersion → FetchVerses.execute throws (asset
      // fetch exhausted its 3 attempts) → the pane's new catch reverts.
      final mp = MainProvider();
      mp.currentVersion = 'cuvs-yhwh';
      mp.setVerses(_versesFor('cuvs-yhwh'));
      const prevVersion = 'cuvs-yhwh';

      mp.setVersion('biblexg-v2');
      // ...load throws; nothing calls setVerses...
      expect(mp.renderedVersion, prevVersion,
          reason: 'even BEFORE the revert the chip must not have lied');

      // What the reading pane's catch block now does.
      mp.setVersion(prevVersion);

      expect(mp.currentVersion, prevVersion);
      expect(mp.renderedVersion, prevVersion);
      expect(mp.verses.first.text, contains(prevVersion));
    });

    test('the warm-cache fast path moves both together, atomically', () {
      final mp = MainProvider();
      mp.currentVersion = 'cuvs-yhwh';
      mp.setVerses(_versesFor('cuvs-yhwh'));
      mp.cacheVersionForTest('biblexg-v2', _versesFor('biblexg-v2'));

      // The listener runs while the swap is observable — assert the
      // invariant from inside the notification, not just after it.
      String? labelSeen;
      String? textSeen;
      void listener() {
        labelSeen = mp.renderedVersion;
        textSeen = mp.verses.first.text;
      }

      mp.addListener(listener);
      expect(mp.useCachedVersion('biblexg-v2'), isTrue);
      mp.removeListener(listener);

      expect(labelSeen, 'biblexg-v2');
      expect(textSeen, contains('biblexg-v2'),
          reason: 'listeners must never observe a state where the label '
              'and the verses name different translations');
    });

    test('a cache MISS changes nothing at all', () {
      final mp = MainProvider();
      mp.currentVersion = 'cuvs-yhwh';
      mp.setVerses(_versesFor('cuvs-yhwh'));

      expect(mp.useCachedVersion('biblexg-v2'), isFalse);
      expect(mp.currentVersion, 'cuvs-yhwh');
      expect(mp.renderedVersion, 'cuvs-yhwh');
      expect(mp.verses.first.text, contains('cuvs-yhwh'));
    });

    test('label and verses agree after a switch away and back', () {
      final mp = MainProvider();
      mp.currentVersion = 'cuvs-yhwh';
      mp.setVerses(_versesFor('cuvs-yhwh'));
      mp.cacheVersionForTest('biblexg-v2', _versesFor('biblexg-v2'));

      expect(mp.useCachedVersion('biblexg-v2'), isTrue);
      expect(mp.useCachedVersion('cuvs-yhwh'), isTrue,
          reason: 'setVerses cached the original list on the way out');
      expect(mp.renderedVersion, 'cuvs-yhwh');
      expect(mp.verses.first.text, contains('cuvs-yhwh'));
    });
  });
}

/// Verses stamped with the version they belong to, so a test can tell
/// which translation is actually on screen rather than trusting a label.
List<Verse> _versesFor(String version) => [
      Verse(book: 'John', chapter: 3, verse: 16, text: 'text of $version'),
      Verse(book: 'John', chapter: 3, verse: 17, text: 'more of $version'),
    ];
