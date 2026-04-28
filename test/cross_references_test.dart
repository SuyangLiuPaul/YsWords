// Smoke tests for the cross-reference dataset + lookup. Pins the
// expanded coverage so a future shrink (e.g. accidentally re-running
// the converter with a stale dataset) surfaces immediately.

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/services/cross_reference_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every canonical book has at least one curated source verse', () async {
    const books = [
      'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy',
      'Joshua', 'Judges', 'Ruth', '1 Samuel', '2 Samuel',
      '1 Kings', '2 Kings', '1 Chronicles', '2 Chronicles', 'Ezra',
      'Nehemiah', 'Esther', 'Job', 'Psalms', 'Proverbs',
      'Ecclesiastes', 'Song of Solomon', 'Isaiah', 'Jeremiah',
      'Lamentations', 'Ezekiel', 'Daniel', 'Hosea', 'Joel', 'Amos',
      'Obadiah', 'Jonah', 'Micah', 'Nahum', 'Habakkuk', 'Zephaniah',
      'Haggai', 'Zechariah', 'Malachi', 'Matthew', 'Mark', 'Luke',
      'John', 'Acts', 'Romans', '1 Corinthians', '2 Corinthians',
      'Galatians', 'Ephesians', 'Philippians', 'Colossians',
      '1 Thessalonians', '2 Thessalonians', '1 Timothy', '2 Timothy',
      'Titus', 'Philemon', 'Hebrews', 'James', '1 Peter', '2 Peter',
      '1 John', '2 John', '3 John', 'Jude', 'Revelation',
    ];
    for (final b in books) {
      // Look up chapter 1, verse 1 — every book has one. Use
      // forVerseOrNearby so we get the chapter-level fallback for
      // edge cases (e.g. Obadiah's only chapter is "1").
      final refs = await CrossReferenceService.forVerseOrNearby(b, 1, 1);
      expect(refs, isNotEmpty, reason: '$b 1:1 returned no refs');
    }
  });

  test('John 3:16 has its expected high-vote refs', () async {
    final refs = await CrossReferenceService.forVerse('John', 3, 16);
    expect(refs.length, greaterThanOrEqualTo(8));
    // Romans 5:8 is consistently the highest-voted cross-ref for
    // John 3:16 across every TSK build — pin it.
    final hasRomans5_8 = refs.any((r) =>
        r.englishBook == 'Romans' && r.chapter == 5 && r.verseStart == 8);
    expect(hasRomans5_8, isTrue,
        reason: 'Romans 5:8 should be among John 3:16 cross-refs');
    // 1 John 4:9 (or its 4:9-10 range parsed to start verse 9) is the
    // second-most-voted; if neither shows up, the data is wrong.
    final has1John4 = refs.any((r) =>
        r.englishBook == '1 John' && r.chapter == 4 && (r.verseStart ?? 0) == 9);
    expect(has1John4, isTrue,
        reason: '1 John 4:9 (or 4:9-10) should be among John 3:16 cross-refs');
  });

  test(
      'forVerseOrNearby falls back to merged nearby refs when exact '
      'verse has none', () async {
    // Pick a verse that's reasonably likely to have NO direct entry
    // but live in a chapter that does. Use Psalms 23:6 — most
    // datasets have refs for 23:1-4 but not always 23:6.
    final atSix = await CrossReferenceService.forVerseOrNearby('Psalms', 23, 6);
    expect(atSix, isNotEmpty,
        reason: 'Psalms 23 should yield neighbour-merged refs');
  });

  test('returns empty for nonsense book', () async {
    final refs = await CrossReferenceService.forVerse('Bogus', 1, 1);
    expect(refs, isEmpty);
  });

  test('coverage exceeds 25 thousand source verses', () async {
    final n = await CrossReferenceService.sourceCount();
    expect(n, greaterThan(25000),
        reason: 'expanded TSK dataset should cover ~29k source verses');
  });
}
