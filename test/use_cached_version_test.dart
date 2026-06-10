import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/providers/main_provider.dart';

/// 2026-06-11: regression coverage for `MainProvider.useCachedVersion`
/// — the warm-path version switch. Listed as an open coverage gap in
/// docs/priorities.md since v1.3.23, and the site of a real production
/// bug (v1.3.40): the warm switch didn't invalidate the
/// (book, chapter) → verses index, so switching from a partial-canon
/// version (LJK V2: Matthew only) to a full-canon one kept serving the
/// OLD version's index — `versesInChapter('Revelation', 2)` returned
/// empty on a version that has Revelation, and the page showed the
/// "switch to a full-canon version" empty state under a full-canon
/// header.
void main() {
  List<Verse> ntOnly() => const [
        Verse(book: 'Matthew', chapter: 1, verse: 1, text: 'mat 1:1'),
        Verse(book: 'Matthew', chapter: 1, verse: 2, text: 'mat 1:2'),
      ];

  List<Verse> fullCanon() => const [
        Verse(book: 'Matthew', chapter: 1, verse: 1, text: 'full mat 1:1'),
        Verse(book: 'Revelation', chapter: 2, verse: 1, text: 'rev 2:1'),
        Verse(book: 'Revelation', chapter: 2, verse: 2, text: 'rev 2:2'),
      ];

  MainProvider seeded() {
    final mp = MainProvider();
    mp.cacheVersionForTest('nt-only', ntOnly());
    mp.cacheVersionForTest('full', fullCanon());
    return mp;
  }

  test('returns false for an uncached version (caller falls back '
      'to the cold FetchVerses path)', () {
    final mp = MainProvider();
    expect(mp.useCachedVersion('nope'), isFalse);
  });

  test('swaps verses + currentVersion and notifies once', () {
    final mp = seeded();
    var notifies = 0;
    mp.addListener(() => notifies++);

    final ok = mp.useCachedVersion('full');

    expect(ok, isTrue);
    expect(mp.currentVersion, 'full');
    expect(mp.verses.map((v) => v.text).first, 'full mat 1:1');
    expect(notifies, 1);
  });

  test('v1.3.40 regression: partial → full switch refreshes the '
      'versesInChapter index', () {
    final mp = seeded();
    mp.useCachedVersion('nt-only');

    // Build the index against the NT-only version: Revelation absent.
    expect(mp.versesInChapter('Revelation', 2), isEmpty);
    expect(mp.versesInChapter('Matthew', 1), hasLength(2));

    // Warm switch to the full-canon version. Before the v1.3.40 fix
    // the stale index kept reporting Revelation as missing.
    mp.useCachedVersion('full');
    expect(mp.versesInChapter('Revelation', 2), hasLength(2));
  });

  test('full → partial switch also refreshes (true empty state on '
      'genuinely missing books)', () {
    final mp = seeded();
    mp.useCachedVersion('full');
    expect(mp.versesInChapter('Revelation', 2), hasLength(2));

    mp.useCachedVersion('nt-only');
    expect(mp.versesInChapter('Revelation', 2), isEmpty);
    expect(mp.versesInChapter('Matthew', 1), hasLength(2));
  });

  test('switching back and forth never serves a stale list '
      '(LRU touch keeps both cached)', () {
    final mp = seeded();
    expect(mp.useCachedVersion('full'), isTrue);
    expect(mp.useCachedVersion('nt-only'), isTrue);
    expect(mp.useCachedVersion('full'), isTrue);
    expect(mp.verses.first.text, 'full mat 1:1');
    expect(mp.versesInChapter('Matthew', 1).first.text, 'full mat 1:1');
  });
}
