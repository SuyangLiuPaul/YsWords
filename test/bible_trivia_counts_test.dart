import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:yswords/pages/bible_trivia_page.dart';

/// Guards the mechanically-checkable numeric claims in
/// `bible_trivia_page.dart` — verse counts, chapter counts and
/// verse-range counts tied to a specific reference — against the same
/// reading asset the app displays (`assets/kjv.json`).
///
/// The trivia page had ZERO test coverage across 3,315 lines and ~80
/// factual claims before this file, despite `ui_strings.dart`'s much
/// smaller onboarding counts already needing two rounds of guards
/// (`onboarding_counts_test.dart`, `seo_meta_test.dart`) after both went
/// stale. A full audit (`tools/audit_trivia_claims.py`) found 36 of 36
/// mechanically-checkable claims correct, and ONE genuine error this
/// test also pins: the Luke 1:1–4 prologue was claimed as "36 Greek
/// words" and is actually 42 (two independent tokenizations agree; no
/// source anywhere cites 36).
///
/// Deliberately NOT pinned here: Hebrew/Greek word- or phrase-occurrence
/// counts (Mark's "euthus" 41×, 3 John's "219 Greek words", Ephesians'
/// "in Christ" 27×, etc.). `assets/originals/*.json` follows the
/// Textus-Receptus/Byzantine tradition behind the KJV, while these
/// widely-cited figures are conventionally quoted from the modern
/// critical text (NA27/28) — a few-word gap in that direction is an
/// edition difference, not a copy error, and asserting our own asset's
/// count would just swap one brittle number for another. See the audit
/// script's trailing report for the actual numbers.
void main() {
  final kjv = json.decode(File('assets/kjv.json').readAsStringSync()) as List;

  final versesOf = <String, Map<int, int>>{};
  for (final row in kjv) {
    final r = row as Map;
    final book = r['book'] as String;
    final chapter = int.parse(r['chapter'] as String);
    versesOf.putIfAbsent(book, () => {});
    versesOf[book]![chapter] = (versesOf[book]![chapter] ?? 0) + 1;
  }

  int chapterCount(String book) => versesOf[book]!.length;
  int versesInChapter(String book, int chapter) =>
      versesOf[book]![chapter] ?? 0;
  int totalVerses(String book) =>
      versesOf[book]!.values.fold(0, (a, b) => a + b);
  int verseRangeCount(String book, int chapter, int start, int end) => kjv
      .cast<Map>()
      .where((r) =>
          r['book'] == book &&
          int.parse(r['chapter'] as String) == chapter &&
          int.parse(r['verse'] as String) >= start &&
          int.parse(r['verse'] as String) <= end)
      .length;

  BibleTriviaEntry entryFor(String reference) => bibleTriviaEntries
      .firstWhere((e) => e.reference == reference, orElse: () {
    fail('no trivia entry with reference "$reference" — did it move or '
        'get renamed?');
  });

  List<int> numbersIn(String s) => RegExp(r'\d+')
      .allMatches(s)
      .map((m) => int.parse(m.group(0)!))
      .toList();

  void expectNumberInEveryLocale(
      String reference, int expected, String reason) {
    final entry = entryFor(reference);
    for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
      expect(numbersIn(entry.body[locale]!), contains(expected),
          reason: '$reference/$locale: $reason');
    }
  }

  void expectNumberInEveryLocaleTitle(
      String reference, int expected, String reason) {
    final entry = entryFor(reference);
    for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
      expect(numbersIn(entry.title[locale]!), contains(expected),
          reason: '$reference/$locale title: $reason');
    }
  }

  group('verse and chapter counts match assets/kjv.json', () {
    test('Psalm 119 — 176 verses (longest chapter in the Bible)', () {
      expect(versesInChapter('Psalms', 119), 176);
      expectNumberInEveryLocale('Psalm 119', 176, 'states the real count');
    });

    test('Lamentations 1/2/4 — 22 verses each, 3 — 66, 5 — 22 (broken '
        'acrostic)', () {
      expect(versesInChapter('Lamentations', 1), 22);
      expect(versesInChapter('Lamentations', 2), 22);
      expect(versesInChapter('Lamentations', 3), 66);
      expect(versesInChapter('Lamentations', 4), 22);
      expect(versesInChapter('Lamentations', 5), 22);
      expectNumberInEveryLocale('Lamentations 3', 22, 'ch 1/2/4 count');
      expectNumberInEveryLocale('Lamentations 3', 66, 'ch 3 count');
    });

    test('Proverbs 31:10-31 — exactly 22 verses', () {
      expect(verseRangeCount('Proverbs', 31, 10, 31), 22);
      expectNumberInEveryLocale('Proverbs 31:10', 22, 'the acrostic span');
    });

    test('Obadiah — 21 verses, the shortest OT book', () {
      expect(totalVerses('Obadiah'), 21);
      final otBooks = <String>[];
      for (final row in kjv) {
        final b = (row as Map)['book'] as String;
        if (b == 'Matthew') break;
        if (!otBooks.contains(b)) otBooks.add(b);
      }
      final shortest =
          otBooks.reduce((a, b) => totalVerses(a) <= totalVerses(b) ? a : b);
      expect(shortest, 'Obadiah',
          reason: 'copy claims Obadiah is the shortest OT book by verse '
              'count');
      expectNumberInEveryLocale('Obadiah 1:21', 21, 'the real verse count');
    });

    test('Isaiah — 66 chapters; splits 39 (OT books) + 27 (NT books)', () {
      expect(chapterCount('Isaiah'), 66);
      final books = <String>[];
      for (final row in kjv) {
        final b = (row as Map)['book'] as String;
        if (!books.contains(b)) books.add(b);
      }
      final otCount = books.indexOf('Matthew');
      expect(otCount, 39);
      expect(66 - otCount, 27);
      expectNumberInEveryLocale('Isaiah 40:1', 66, 'chapter count');
      expectNumberInEveryLocale('Isaiah 40:1', 39, 'OT book count');
      expectNumberInEveryLocale('Isaiah 40:1', 27, 'NT book count');
    });

    test('Ecclesiastes — 12 chapters', () {
      expect(chapterCount('Ecclesiastes'), 12);
      expectNumberInEveryLocale('Ecclesiastes 1:2', 12, 'chapter count');
    });

    test('Zephaniah — 3 chapters, 53 verses total', () {
      expect(chapterCount('Zephaniah'), 3);
      expect(totalVerses('Zephaniah'), 53);
      // "3 chapters" is stated in the entry's title, not its body.
      expectNumberInEveryLocaleTitle('Zephaniah 1:14', 3, 'chapter count');
      expectNumberInEveryLocale('Zephaniah 1:14', 53, 'total verse count');
    });

    test('Ephesians — 6 chapters', () {
      expect(chapterCount('Ephesians'), 6);
      expectNumberInEveryLocale('Ephesians 1:3', 6, 'chapter count');
    });

    test('Philippians — 4 chapters', () {
      expect(chapterCount('Philippians'), 4);
      expectNumberInEveryLocale('Philippians 4:4', 4, 'chapter count');
    });

    test('Romans — 16 chapters', () {
      expect(chapterCount('Romans'), 16);
      expectNumberInEveryLocale('Romans 1:16', 16, 'chapter count');
    });

    test('Philemon — 25 verses', () {
      expect(totalVerses('Philemon'), 25);
      expectNumberInEveryLocale('Philemon 16', 25, 'verse count');
    });

    test('1 Corinthians 13 — 13 verses', () {
      expect(versesInChapter('1 Corinthians', 13), 13);
      expectNumberInEveryLocale('1 Corinthians 13', 13, 'verse count');
    });

    test('James — 108 verses', () {
      expect(totalVerses('James'), 108);
      expectNumberInEveryLocale('James 2:17', 108, 'total verse count');
    });

    test('1 John — 5 chapters', () {
      expect(chapterCount('1 John'), 5);
      expectNumberInEveryLocale('1 John 5:13', 5, 'chapter count');
    });

    test('2 John — 13 verses', () {
      expect(totalVerses('2 John'), 13);
      expectNumberInEveryLocale('2 John 1:4', 13, 'verse count');
    });

    test('3 John — 14 verses (the reading asset the app shows, not the '
        'NA28 15-verse split in assets/originals/3_john.json)', () {
      expect(totalVerses('3 John'), 14);
      expectNumberInEveryLocale('3 John 1:13', 14, 'verse count');
    });

    test('Revelation — 22 chapters', () {
      expect(chapterCount('Revelation'), 22);
      expectNumberInEveryLocale('Revelation 1:4', 22, 'chapter count');
    });

    test('2 Samuel 1:19-27 — "how are the mighty fallen" repeats 3 times',
        () {
      final text = kjv
          .cast<Map>()
          .where((r) =>
              r['book'] == '2 Samuel' &&
              int.parse(r['chapter'] as String) == 1 &&
              int.parse(r['verse'] as String) >= 19 &&
              int.parse(r['verse'] as String) <= 27)
          .map((r) => r['text'] as String)
          .join(' ');
      final count =
          RegExp('how are the mighty fallen', caseSensitive: false)
              .allMatches(text)
              .length;
      expect(count, 3);
      expectNumberInEveryLocale('2 Samuel 1:19', 3, 'refrain repeat count');
    });

    test('Malachi\'s last verse ends with "curse"', () {
      final malachi =
          kjv.cast<Map>().where((r) => r['book'] == 'Malachi').toList()
            ..sort((a, b) {
              final ca = int.parse(a['chapter'] as String);
              final cb = int.parse(b['chapter'] as String);
              if (ca != cb) return ca.compareTo(cb);
              return int.parse(a['verse'] as String)
                  .compareTo(int.parse(b['verse'] as String));
            });
      final lastWords = RegExp(r"[A-Za-z']+")
          .allMatches(malachi.last['text'] as String)
          .map((m) => m.group(0)!)
          .toList();
      expect(lastWords.last.toLowerCase(), 'curse');
    });
  });

  group('original-language word counts match assets/originals/*.json', () {
    test('Genesis 1:1 — 7 Hebrew words', () {
      final genesis = json.decode(
          File('assets/originals/genesis.json').readAsStringSync()) as Map;
      expect((genesis['1:1'] as List).length, 7);
      expectNumberInEveryLocale('Genesis 1:1', 7, 'Hebrew word count');
    });

    test('Luke 1:1-4 — 42 Greek words (was miscited as 36; fixed here — '
        'two independent tokenizations of the Greek text agree on 42, '
        'and no source anywhere cites 36)', () {
      final luke = json.decode(
          File('assets/originals/luke.json').readAsStringSync()) as Map;
      final total = ['1:1', '1:2', '1:3', '1:4']
          .map((v) => (luke[v] as List).length)
          .fold(0, (a, b) => a + b);
      expect(total, 42);
      expectNumberInEveryLocale('Luke 1:1', 42, 'Greek word count');
    });
  });
}
