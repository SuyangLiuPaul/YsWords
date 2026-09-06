import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/providers/main_provider.dart';

/// 2026-09-06: the "switching the Bible version doesn't switch" bug,
/// reported twice from an iPad and reproduced in headless Chrome against
/// a release web build the same day.
///
/// **The rule this pins.** The paragraph-groups cache holds a grouping of
/// `verses`. `verses` came from `renderedVersion`. Therefore the cache
/// key must name `renderedVersion` — never `currentVersion`, which moves
/// the instant a switch STARTS and stays ahead of the verses for as long
/// as the load takes.
///
/// **What went wrong when it named `currentVersion`.** The reading pane
/// rebuilds during the switch window — `setVersionSwitching(true)` and
/// `setVersion()` each call `notifyListeners`, so at least one rebuild is
/// guaranteed — and `_ChapterPage.build` then computed the OLD
/// translation's paragraph groups and filed them under the NEW version's
/// key. When the new text finally landed, the next build got a cache HIT
/// on that entry and rendered the old translation under a chip that
/// correctly named the new one. It is sticky: the poisoned entry answers
/// every later build, so the switch stays broken until something else
/// evicts it, and re-picking the same version is a no-op because the
/// picker (correctly) reads `renderedVersion` and believes it is already
/// there.
///
/// **Why `versesLength` did not save it.** It is the only other
/// discriminator in the key, and 229 of the 260 chapters that
/// 和合本雅伟版 and 梁家铿译本 share have identical verse counts (measured
/// 2026-09-06 over the two assets). 约翰福音 3 — the chapter it was
/// reported on — is 36 verses in both.
///
/// The two texts below are the real first verse of 约翰福音 3:1 in each
/// edition, kept verbatim so a reader of this test can see that the two
/// translations share no substring at that verse and the oracle is not
/// arbitrary.
void main() {
  const book = '约翰福音';
  const cuvsFirst = '有一个法利赛人，名叫尼哥底母，是犹太人的官。';
  const ljkFirst = '有个法利赛人，名叫尼哥底姆，是犹太人一位首领，';

  List<Verse> cuvsJohn3() => const [
        Verse(book: book, chapter: 3, verse: 1, text: cuvsFirst),
        Verse(book: book, chapter: 3, verse: 2, text: 'cuvs 3:2'),
      ];

  List<Verse> ljkJohn3() => const [
        Verse(book: book, chapter: 3, verse: 1, text: ljkFirst),
        Verse(book: book, chapter: 3, verse: 2, text: 'ljk 3:2'),
      ];

  /// Exactly what `_ChapterPage.build` does on a cache miss: group the
  /// verses it is holding and store them under the current key.
  void cacheGroupingOf(MainProvider mp, List<Verse> verses) {
    mp.setCachedParagraphGrouping(
      book: book,
      chapter: 3,
      paragraphMode: true,
      versesLength: verses.length,
      groups: [verses],
      verseToItem: const {0: 1},
      itemToVerseIndex: const {0: 0, 1: 0},
    );
  }

  ({
    List<List<Verse>> groups,
    Map<int, int> verseToItem,
    Map<int, int> itemToVerseIndex,
  })? lookup(MainProvider mp, int versesLength) =>
      mp.cachedParagraphGrouping(
        book: book,
        chapter: 3,
        paragraphMode: true,
        versesLength: versesLength,
      );

  // A pane that is NOT mid-switch must still get its cache hit. Without
  // this the test above could pass for the useless reason that caching
  // stopped working altogether — which is the shape of decorative
  // assertion this repo keeps finding.
  test('a rebuild with no switch in flight still hits the cache', () {
    final mp = MainProvider(storagePrefix: 'test');
    mp.currentVersion = 'cuvs-yhwh';
    mp.setVerses(cuvsJohn3());
    cacheGroupingOf(mp, cuvsJohn3());

    final hit = lookup(mp, 2);
    expect(hit, isNotNull,
        reason: 'the cache must still answer a same-version rebuild');
    expect(hit!.groups.first.first.text, cuvsFirst);
  });

  test('a rebuild DURING a switch cannot poison the target version\'s '
      'cache slot', () {
    final mp = MainProvider(storagePrefix: 'test');
    mp.currentVersion = 'cuvs-yhwh';
    mp.setVerses(cuvsJohn3());

    // 1. The reader is on 和合本雅伟版 and the pane has cached its grouping.
    cacheGroupingOf(mp, cuvsJohn3());
    expect(lookup(mp, 2)!.groups.first.first.text, cuvsFirst);

    // 2. The reader taps 梁家铿译本. `currentVersion` moves NOW; the
    //    verses will not arrive for another 1-3 s (longer on a slow link).
    mp.setVersion('biblexg-v2');
    expect(mp.currentVersion, 'biblexg-v2');
    expect(mp.renderedVersion, 'cuvs-yhwh',
        reason: 'the verses on screen are still the old translation — this '
            'gap is the whole bug and the test is meaningless without it');

    // 3. The pane rebuilds inside that gap — `setVersionSwitching` and
    //    `setVersion` both notify — and caches what it is HOLDING, which
    //    is still 和合本雅伟版.
    cacheGroupingOf(mp, cuvsJohn3());

    // 4. The 梁家铿译本 verses land.
    mp.setVerses(ljkJohn3());
    expect(mp.renderedVersion, 'biblexg-v2');

    // 5. The next build looks the grouping up. Whatever comes back must
    //    be the text that is actually on screen. Before the fix this
    //    returned the 和合本雅伟版 groups written in step 3, and the reader
    //    saw 和合本雅伟版 under a chip reading 梁简.
    final hit = lookup(mp, 2);
    if (hit != null) {
      expect(hit.groups.first.first.text, ljkFirst,
          reason: 'the cache answered with a grouping built from a '
              'different translation than the one now in `verses`');
    }
    expect(hit, isNull,
        reason: 'nothing was ever grouped from 梁家铿译本 verses, so the only '
            'honest answer is a miss — a hit here can only be the old '
            'translation wearing the new version\'s key');
  });

  test('switching back does not resurrect the other version\'s grouping',
      () {
    final mp = MainProvider(storagePrefix: 'test');
    mp.currentVersion = 'biblexg-v2';
    mp.setVerses(ljkJohn3());
    cacheGroupingOf(mp, ljkJohn3());
    // Non-vacuity: without this the test below passes for the useless
    // reason that the cache never answers anything at all.
    expect(lookup(mp, 2)?.groups.first.first.text, ljkFirst);

    mp.setVersion('cuvs-yhwh');
    cacheGroupingOf(mp, ljkJohn3()); // rebuild inside the window
    mp.setVerses(cuvsJohn3());

    final hit = lookup(mp, 2);
    if (hit != null) {
      expect(hit.groups.first.first.text, cuvsFirst);
    }
    expect(hit, isNull);
  });
}
