import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/models/bible_map.dart';

/// Chapter-matching tests for [BibleMap].
///
/// 2026-09-05 defect: `tools/integrate_all_tissot.py` collapsed the
/// DISCRETE chapter lists in `tissot_catalog.json` into a min/max span
/// (`John [1, 14]` → the solid range John 1-14), because the model
/// could only express one `[start, end]` pair. Six entries in
/// `assets/maps_index.json` were affected and 38 false
/// (chapter, illustration) slots were manufactured — Saint Philip
/// showed up on John 2-13, Saint Peter on Matthew 5-15, and so on.
///
/// `books` values are now a LIST of inclusive ranges. The flat legacy
/// form is still read and still means exactly what it always meant.

BibleMap _map(String id, Map<String, dynamic> books) =>
    BibleMap.fromJson(<String, dynamic>{
      'id': id,
      'title': <String, dynamic>{'en': id},
      'description': <String, dynamic>{'en': ''},
      'books': books,
      'file': '$id.jpg',
    });

/// Every chapter [m] matches for [book], scanned over a generous span.
Set<int> _matchedChapters(BibleMap m, String book) => <int>{
      for (var c = 1; c <= 160; c++)
        if (m.matchesBookChapter(book, c)) c,
    };

void main() {
  group('matchesBookChapter — flat legacy range', () {
    final m = _map('flat', <String, dynamic>{
      'John': <int>[11, 20],
    });

    test('matches the whole inclusive span', () {
      expect(_matchedChapters(m, 'John'),
          <int>{11, 12, 13, 14, 15, 16, 17, 18, 19, 20});
    });

    test('boundaries are inclusive, just outside is not', () {
      expect(m.matchesBookChapter('John', 11), isTrue);
      expect(m.matchesBookChapter('John', 20), isTrue);
      expect(m.matchesBookChapter('John', 10), isFalse);
      expect(m.matchesBookChapter('John', 21), isFalse);
    });

    test('a book that is not tagged never matches', () {
      expect(m.matchesBookChapter('Mark', 11), isFalse);
    });

    test('degenerate flat range [n, n] matches exactly that chapter', () {
      final one = _map('one', <String, dynamic>{
        'Mark': <int>[1, 1],
      });
      expect(_matchedChapters(one, 'Mark'), <int>{1});
    });
  });

  group('matchesBookChapter — multi-range (the fix)', () {
    final m = _map('multi', <String, dynamic>{
      'John': <List<int>>[
        <int>[1, 1],
        <int>[14, 14],
      ],
    });

    test('matches each listed chapter and NOTHING in the gap', () {
      expect(_matchedChapters(m, 'John'), <int>{1, 14});
      for (var c = 2; c <= 13; c++) {
        expect(m.matchesBookChapter('John', c), isFalse,
            reason: 'John $c is in the gap and must not match');
      }
    });

    test('a run inside a multi-range value stays a span', () {
      final m2 = _map('run', <String, dynamic>{
        'John': <List<int>>[
          <int>[13, 13],
          <int>[19, 21],
        ],
      });
      expect(_matchedChapters(m2, 'John'), <int>{13, 19, 20, 21});
      expect(m2.matchesBookChapter('John', 18), isFalse);
      expect(m2.matchesBookChapter('John', 22), isFalse);
    });

    test('boundaries of every range are inclusive', () {
      final m3 = _map('bounds', <String, dynamic>{
        'Acts': <List<int>>[
          <int>[2, 4],
          <int>[9, 10],
        ],
      });
      expect(m3.matchesBookChapter('Acts', 2), isTrue);
      expect(m3.matchesBookChapter('Acts', 4), isTrue);
      expect(m3.matchesBookChapter('Acts', 9), isTrue);
      expect(m3.matchesBookChapter('Acts', 10), isTrue);
      expect(m3.matchesBookChapter('Acts', 1), isFalse);
      expect(m3.matchesBookChapter('Acts', 5), isFalse);
      expect(m3.matchesBookChapter('Acts', 8), isFalse);
      expect(m3.matchesBookChapter('Acts', 11), isFalse);
    });

    test('order of the ranges does not matter', () {
      final m4 = _map('unordered', <String, dynamic>{
        'Mark': <List<int>>[
          <int>[9, 9],
          <int>[2, 2],
        ],
      });
      expect(_matchedChapters(m4, 'Mark'), <int>{2, 9});
    });
  });

  group('matchesBookChapter — single chapter and empty values', () {
    test('flat single-element list means exactly that chapter', () {
      final m = _map('single', <String, dynamic>{
        'Mark': <int>[6],
      });
      expect(_matchedChapters(m, 'Mark'), <int>{6});
    });

    test('const-constructed single-element range keeps its meaning', () {
      // BibleMap is const-constructible, so `[6]` can reach the matcher
      // without going through fromJson. It must still mean chapter 6.
      const m = BibleMap(
        id: 'raw',
        title: <String, String>{},
        description: <String, String>{},
        books: <String, List<List<int>>>{
          'Mark': <List<int>>[
            <int>[6],
          ],
        },
        file: 'raw.jpg',
      );
      expect(m.matchesBookChapter('Mark', 6), isTrue);
      expect(m.matchesBookChapter('Mark', 5), isFalse);
      expect(m.matchesBookChapter('Mark', 7), isFalse);
    });

    test('nested single-element range is normalised to [n, n]', () {
      final m = _map('nested_single', <String, dynamic>{
        'Luke': <List<int>>[
          <int>[7],
          <int>[15, 15],
        ],
      });
      expect(_matchedChapters(m, 'Luke'), <int>{7, 15});
    });

    test('an empty chapter list keeps the book key but matches nothing', () {
      final m = _map('empty', <String, dynamic>{
        'Jude': <int>[],
      });
      // map_service.mapsForBook falls back on containsKey — the tag
      // must survive even when no chapter matches.
      expect(m.books.containsKey('Jude'), isTrue);
      expect(_matchedChapters(m, 'Jude'), isEmpty);
    });
  });

  group('the six collapsed entries in the real assets/maps_index.json', () {
    late Map<String, BibleMap> byId;

    setUpAll(() {
      final raw = File('assets/maps_index.json').readAsStringSync();
      final decoded = json.decode(raw);
      final list = decoded is Map<String, dynamic>
          ? (decoded['maps'] as List<dynamic>? ?? const <dynamic>[])
          : decoded as List<dynamic>;
      byId = <String, BibleMap>{
        for (final e in list.whereType<Map<String, dynamic>>())
          e['id'] as String: BibleMap.fromJson(e),
      };
      expect(byId.length, greaterThan(1000),
          reason: 'sanity: the real bundled index loaded');
    });

    // id → book → (chapters it MUST match, chapters it must NOT match).
    // "must match" is the discrete list in tissot_catalog.json; "must
    // not" is the gap the old min/max span manufactured.
    const truth = <String, Map<String, List<int>>>{
      'illus_tissot_saint_philip': <String, List<int>>{'John': <int>[1, 14]},
      'illus_tissot_saint_peter': <String, List<int>>{
        'Matthew': <int>[4, 16],
        'Mark': <int>[1],
      },
      'illus_tissot_saint_thomas': <String, List<int>>{'John': <int>[11, 20]},
      'illus_tissot_saint_john_the_evangelist': <String, List<int>>{
        'John': <int>[13, 19, 20, 21],
      },
      'illus_tissot_jesus_teaches_the_people_by_the_sea': <String, List<int>>{
        'Mark': <int>[2, 4],
      },
      'illus_tissot_david_returns_to_achish': <String, List<int>>{
        '1 Samuel': <int>[27, 29],
      },
    };

    const falseSlots = <String, Map<String, List<int>>>{
      'illus_tissot_saint_philip': <String, List<int>>{
        'John': <int>[2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13],
      },
      'illus_tissot_saint_peter': <String, List<int>>{
        'Matthew': <int>[5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
      },
      'illus_tissot_saint_thomas': <String, List<int>>{
        'John': <int>[12, 13, 14, 15, 16, 17, 18, 19],
      },
      'illus_tissot_saint_john_the_evangelist': <String, List<int>>{
        'John': <int>[14, 15, 16, 17, 18],
      },
      'illus_tissot_jesus_teaches_the_people_by_the_sea': <String, List<int>>{
        'Mark': <int>[3],
      },
      'illus_tissot_david_returns_to_achish': <String, List<int>>{
        '1 Samuel': <int>[28],
      },
    };

    test('each still matches every chapter the catalog actually cites', () {
      for (final e in truth.entries) {
        final m = byId[e.key];
        expect(m, isNotNull, reason: '${e.key} missing from the index');
        for (final b in e.value.entries) {
          for (final c in b.value) {
            expect(m!.matchesBookChapter(b.key, c), isTrue,
                reason: '${e.key} must still match ${b.key} $c');
          }
        }
      }
    });

    test('none matches a chapter the min/max collapse invented', () {
      final leaks = <String>[];
      for (final e in falseSlots.entries) {
        final m = byId[e.key]!;
        for (final b in e.value.entries) {
          for (final c in b.value) {
            if (m.matchesBookChapter(b.key, c)) leaks.add('${e.key} ${b.key} $c');
          }
        }
      }
      expect(leaks, isEmpty,
          reason: 'illustrations still leaking onto gap chapters: $leaks');
    });

    test('the six together account for exactly 15 chapter slots, not 53', () {
      var slots = 0;
      for (final id in truth.keys) {
        final m = byId[id]!;
        for (final b in m.books.keys) {
          for (var c = 1; c <= 160; c++) {
            if (m.matchesBookChapter(b, c)) slots++;
          }
        }
      }
      expect(slots, 15,
          reason: 'was 53 before the fix; the 38 extra slots were false');
    });
  });

  group('backwards compatibility against the real index', () {
    test('every flat [start, end] value still matches its whole span', () {
      final raw = File('assets/maps_index.json').readAsStringSync();
      final list = json.decode(raw) as List<dynamic>;

      var flatValues = 0;
      var nestedValues = 0;
      final mismatches = <String>[];

      for (final e in list.whereType<Map<String, dynamic>>()) {
        final m = BibleMap.fromJson(e);
        final rawBooks = e['books'] as Map<String, dynamic>? ?? const {};
        for (final entry in rawBooks.entries) {
          final value = entry.value as List<dynamic>;
          // Reference implementation of the ON-DISK semantics, written
          // straight off the raw JSON and independent of the model.
          final expected = <int>{};
          if (value.isNotEmpty && value.first is List) {
            nestedValues++;
            for (final r in value.cast<List<dynamic>>()) {
              final lo = r[0] as int;
              final hi = r.length == 1 ? lo : r[1] as int;
              for (var c = lo; c <= hi; c++) {
                expected.add(c);
              }
            }
          } else if (value.isNotEmpty) {
            flatValues++;
            // Pre-2026-09-05 meaning, verbatim.
            final ints = value.cast<int>();
            if (ints.length == 1) {
              expected.add(ints[0]);
            } else {
              for (var c = ints[0]; c <= ints[1]; c++) {
                expected.add(c);
              }
            }
          }
          final actual = <int>{
            for (var c = 1; c <= 160; c++)
              if (m.matchesBookChapter(entry.key, c)) c,
          };
          if (!setEquals(actual, expected)) {
            mismatches.add('${m.id} ${entry.key}: value $value '
                'matches ${actual.toList()..sort()}, '
                'expected ${expected.toList()..sort()}');
          }
        }
      }

      expect(flatValues, 1934,
          reason: 'the untouched legacy values; 6 of the original 1940 '
              'became multi-range in the 2026-09-05 fix');
      expect(nestedValues, 6);
      expect(mismatches, isEmpty,
          reason: 'on-disk meaning changed for:\n${mismatches.take(20).join('\n')}');
    });
  });

  group('index-wide regression guard', () {
    // An entry must not surface on a chapter its own English
    // description never cites. Every generated description enumerates
    // its chapters, so a future min/max-style collapse widens the data
    // past the prose and trips this immediately.
    //
    // Book-values whose book is not cited at all in the English
    // description are skipped: 576 of 1940 are hand-written prose maps
    // that name places, not references.
    const knownPreexisting = <String>{
      // Hand-authored floor-plan map, not a generated citation: it is
      // tagged to the whole temple-building narrative (1 Kings 5-9,
      // 2 Chronicles 2-7) while the prose only names 1 Kings 6.
      // Pre-dates the 2026-09-05 fix and is a separate question for
      // the owner — NOT a chapter-range collapse.
      'solomons_temple',
    };

    const bookNames = <String>[
      'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy', 'Joshua',
      'Judges', 'Ruth', '1 Samuel', '2 Samuel', '1 Kings', '2 Kings',
      '1 Chronicles', '2 Chronicles', 'Ezra', 'Nehemiah', 'Esther', 'Job',
      'Psalms', 'Proverbs', 'Ecclesiastes', 'Song of Solomon', 'Isaiah',
      'Jeremiah', 'Lamentations', 'Ezekiel', 'Daniel', 'Hosea', 'Joel',
      'Amos', 'Obadiah', 'Jonah', 'Micah', 'Nahum', 'Habakkuk', 'Zephaniah',
      'Haggai', 'Zechariah', 'Malachi', 'Matthew', 'Mark', 'Luke', 'John',
      'Acts', 'Romans', '1 Corinthians', '2 Corinthians', 'Galatians',
      'Ephesians', 'Philippians', 'Colossians', '1 Thessalonians',
      '2 Thessalonians', '1 Timothy', '2 Timothy', 'Titus', 'Philemon',
      'Hebrews', 'James', '1 Peter', '2 Peter', '1 John', '2 John', '3 John',
      'Jude', 'Revelation',
    ];

    /// Chapters the English description cites, per book. Understands
    /// "John 14" and "Genesis 19-19" / "1 Samuel 27–29".
    Map<String, Set<int>> citedChapters(String desc) {
      // Longest book name first so "1 John" never matches as "John".
      final ordered = [...bookNames]
        ..sort((a, b) => b.length.compareTo(a.length));
      final pattern = RegExp(
        '(${ordered.map(RegExp.escape).join('|')})'
        r'\s+(\d+)\s*(?:[-–]\s*(\d+))?',
      );
      final out = <String, Set<int>>{};
      for (final m in pattern.allMatches(desc)) {
        var lo = int.parse(m.group(2)!);
        var hi = m.group(3) == null ? lo : int.parse(m.group(3)!);
        if (hi < lo) {
          final t = lo;
          lo = hi;
          hi = t;
        }
        final set = out.putIfAbsent(m.group(1)!, () => <int>{});
        for (var c = lo; c <= hi; c++) {
          set.add(c);
        }
      }
      return out;
    }

    test('no entry matches a chapter its own description never cites', () {
      final raw = File('assets/maps_index.json').readAsStringSync();
      final decoded = json.decode(raw);
      final list = decoded is Map<String, dynamic>
          ? (decoded['maps'] as List<dynamic>? ?? const <dynamic>[])
          : decoded as List<dynamic>;

      final violations = <String>[];
      var checked = 0;
      for (final e in list.whereType<Map<String, dynamic>>()) {
        final m = BibleMap.fromJson(e);
        if (knownPreexisting.contains(m.id)) continue;
        final cited = citedChapters(m.description['en'] ?? '');
        for (final book in m.books.keys) {
          final allowed = cited[book];
          if (allowed == null) continue; // prose description, not a citation
          checked++;
          final extra = <int>[
            for (var c = 1; c <= 160; c++)
              if (m.matchesBookChapter(book, c) && !allowed.contains(c)) c,
          ];
          if (extra.isNotEmpty) {
            violations.add('${m.id} $book matches $extra, '
                'description cites ${allowed.toList()..sort()}');
          }
        }
      }
      expect(checked, greaterThan(1300),
          reason: 'sanity: the guard actually covered most of the index');
      expect(violations, isEmpty,
          reason: 'entries wider than their own description:\n'
              '${violations.join('\n')}');
    });
  });
}
