// Tests for v1.2.54's URL slug map.
//
// `book_slugs.dart` powers the hash-based deep-link URL format
// (`/#/<slug>/<chapter>[:<verse>]?v=<version>`). The map and its
// reverse must round-trip for every canonical book in the
// standard 66-book OT/NT order, AND accept common short aliases
// so users typing `/rev` / `/1sam` / `/sos` still land on the
// right book.

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/constants/book_slugs.dart';

void main() {
  group('book slug round-trip', () {
    test('every canonical English book has a slug', () {
      // List from `standardBookOrder` in `fetch_books.dart`.
      const canonicalOrder = <String>[
        'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy',
        'Joshua', 'Judges', 'Ruth',
        '1 Samuel', '2 Samuel', '1 Kings', '2 Kings',
        '1 Chronicles', '2 Chronicles', 'Ezra', 'Nehemiah', 'Esther',
        'Job', 'Psalms', 'Proverbs', 'Ecclesiastes',
        'Song of Solomon',
        'Isaiah', 'Jeremiah', 'Lamentations', 'Ezekiel', 'Daniel',
        'Hosea', 'Joel', 'Amos', 'Obadiah', 'Jonah', 'Micah',
        'Nahum', 'Habakkuk', 'Zephaniah', 'Haggai', 'Zechariah',
        'Malachi',
        'Matthew', 'Mark', 'Luke', 'John', 'Acts', 'Romans',
        '1 Corinthians', '2 Corinthians', 'Galatians', 'Ephesians',
        'Philippians', 'Colossians', '1 Thessalonians',
        '2 Thessalonians', '1 Timothy', '2 Timothy', 'Titus',
        'Philemon', 'Hebrews', 'James', '1 Peter', '2 Peter',
        '1 John', '2 John', '3 John', 'Jude', 'Revelation',
      ];
      for (final book in canonicalOrder) {
        final slug = slugForBook(book);
        expect(slug, isNotNull,
            reason: '$book should have a URL slug.');
        // Round-trip via reverse map.
        final back = bookForSlug(slug!);
        expect(back, book,
            reason: 'slug $slug should round-trip to $book.');
      }
      // Sanity: every entry in `bookToSlug` corresponds to a book
      // in the standard 66 order.
      expect(bookToSlug.length, 66);
    });

    test('numbered-book slugs collapse the space', () {
      expect(slugForBook('1 Samuel'), '1samuel');
      expect(slugForBook('2 Kings'), '2kings');
      expect(slugForBook('1 Chronicles'), '1chronicles');
      expect(slugForBook('1 Thessalonians'), '1thessalonians');
      expect(slugForBook('1 John'), '1john');
      expect(slugForBook('3 John'), '3john');
    });

    test('Song of Solomon collapses both spaces', () {
      expect(slugForBook('Song of Solomon'), 'songofsolomon');
    });
  });

  group('alias reverse lookups', () {
    test('canonical full slugs resolve', () {
      expect(bookForSlug('genesis'), 'Genesis');
      expect(bookForSlug('revelation'), 'Revelation');
      expect(bookForSlug('songofsolomon'), 'Song of Solomon');
      expect(bookForSlug('1samuel'), '1 Samuel');
    });

    test('common short aliases resolve to canonical', () {
      expect(bookForSlug('gen'), 'Genesis');
      expect(bookForSlug('ex'), 'Exodus');
      expect(bookForSlug('exo'), 'Exodus');
      expect(bookForSlug('lev'), 'Leviticus');
      expect(bookForSlug('rev'), 'Revelation');
      expect(bookForSlug('1sam'), '1 Samuel');
      expect(bookForSlug('2ki'), '2 Kings');
      expect(bookForSlug('ps'), 'Psalms');
      expect(bookForSlug('psa'), 'Psalms');
      expect(bookForSlug('psalm'), 'Psalms');
      expect(bookForSlug('sos'), 'Song of Solomon');
      expect(bookForSlug('song'), 'Song of Solomon');
      expect(bookForSlug('matt'), 'Matthew');
      expect(bookForSlug('jn'), 'John');
      expect(bookForSlug('mt'), 'Matthew');
      expect(bookForSlug('phil'), 'Philippians');
      expect(bookForSlug('phlm'), 'Philemon');
      expect(bookForSlug('phm'), 'Philemon');
      expect(bookForSlug('jas'), 'James');
    });

    test('input is normalised — uppercase + spaces tolerated', () {
      expect(bookForSlug('GENESIS'), 'Genesis');
      expect(bookForSlug(' 1Samuel '), '1 Samuel');
      expect(bookForSlug('Rev'), 'Revelation');
      expect(bookForSlug('  REV  '), 'Revelation');
    });

    test('unknown slug returns null (no exception)', () {
      expect(bookForSlug('foobar'), isNull);
      expect(bookForSlug(''), isNull);
      expect(bookForSlug('jesus'), isNull);
    });
  });
}
