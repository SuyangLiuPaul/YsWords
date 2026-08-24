import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every key in the sermon reverse index must name a passage that
/// actually exists — otherwise a sermon is filed under a reference
/// nobody can navigate to, and it is unreachable by that path.
///
/// 2026-08-23: seven keys failed this. Four were chapter/verse
/// confusions in one-chapter books ("Jude 6 confirms this" indexed as
/// Jude chapter 6); three were prose numbers read as chapters — the
/// Chinese conjunction 但 in 「但20分钟」/「但48小时」 taken as the
/// Daniel abbreviation, and "occurs in Deuteronomy 43 times" taken as
/// a chapter. All seven repaired IN refs.json directly, because the
/// shipped index was built by a richer extractor generation than the
/// one in scripts/ — a wholesale regeneration today would silently
/// drop dozens of prose-derived references (measured: −32 keys).
/// This test is what keeps the next bad key from shipping quietly.
void main() {
  late final Map<String, dynamic> refs = jsonDecode(
          File('assets/sermons/refs.json').readAsStringSync())
      as Map<String, dynamic>;

  // KJV is the resolution corpus: full canon, and its book names are
  // the same canonical English strings the extractor emits.
  late final Map<String, Map<int, Set<int>>> canon = () {
    final out = <String, Map<int, Set<int>>>{};
    final rows = jsonDecode(File('assets/kjv.json').readAsStringSync())
        as List<dynamic>;
    for (final r in rows) {
      final m = r as Map<String, dynamic>;
      final book = m['book'] as String;
      final ch = int.parse(m['chapter'] as String);
      final v = int.parse(m['verse'] as String);
      ((out[book] ??= {})[ch] ??= <int>{}).add(v);
    }
    return out;
  }();

  test('every byVerse key resolves to a real book, chapter and verse',
      () {
    final bad = <String>[];
    for (final key in (refs['byVerse'] as Map).keys.cast<String>()) {
      final space = key.lastIndexOf(' ');
      if (space == -1) {
        bad.add('$key (no chapter at all)');
        continue;
      }
      final book = key.substring(0, space);
      final tail = key.substring(space + 1);
      final colon = tail.indexOf(':');
      final ch =
          int.tryParse(colon == -1 ? tail : tail.substring(0, colon));
      final verse =
          colon == -1 ? null : int.tryParse(tail.substring(colon + 1));
      final chapters = canon[book];
      if (chapters == null) {
        bad.add('$key (unknown book "$book")');
      } else if (ch == null || !chapters.containsKey(ch)) {
        bad.add('$key ($book has ${chapters.length} chapters)');
      } else if (verse != null && !chapters[ch]!.contains(verse)) {
        bad.add('$key ($book $ch has ${chapters[ch]!.length} verses)');
      }
    }
    expect(bad, isEmpty,
        reason: 'unresolvable sermon references:\n  ${bad.join('\n  ')}');
  });

  test('the four one-chapter repairs landed, sermons intact', () {
    final bv = refs['byVerse'] as Map;
    expect(bv['Jude 1:6'], ['115']);
    expect(bv['Jude 1:11'], ['420']);
    // 238 joined 239 when the extractor learned 「約翰二書第7節」 —
    // the same one-chapter rule, reached through Chinese prose.
    expect(bv['2 John 1:7'], ['238', '239']);
    expect(bv['2 John 1:10'], ['056']);
    for (final gone in [
      'Jude 6', 'Jude 11', '2 John 7', '2 John 10',
      'Daniel 20', 'Daniel 48', 'Deuteronomy 43',
    ]) {
      expect(bv.containsKey(gone), isFalse, reason: '$gone should be gone');
    }
  });

  // The validity test above cannot see a regeneration that LOSES keys:
  // a smaller index is still an entirely valid one. That is how the
  // extractor came to be unable to rebuild its own output — the guard
  // stayed green while `verse` sat in the unit-word list throwing away
  // every "Jeremiah 12 verse 2" in the corpus.
  //
  // So this pins the prose forms by example. Each entry is a reference
  // that ONLY exists in the index because the extractor reads spoken
  // citations; none of them can be produced by matching "Book 12:2".
  test('the spoken citation forms survive a regeneration', () {
    final bv = (refs['byVerse'] as Map).cast<String, dynamic>();
    const spoken = <String, String>{
      'Jeremiah 12:2': '"Jeremiah 12 verse 2" — verse as separator',
      'Luke 10:19': '"Luke chapter 10, verse 19"',
      'Acts 27': '"Acts chapter 27" — chapter, no verse',
      'Judges 21:15': '"Judges 21 and verse 15"',
      '2 John 1:7': '「約翰二書第7節」 — 第N節 in a one-chapter book',
      'Romans 8:5': '「羅馬書八章五節」 — Chinese numerals, no separator',
      'Song of Solomon 1:2': '「雅歌一章二節」 — the whole title',
      'Revelation 21:4': '「啟示錄第二十一章第四節」',
    };
    final missing = [
      for (final e in spoken.entries)
        if (!bv.containsKey(e.key)) '${e.key} — ${e.value}',
    ];
    expect(missing, isEmpty,
        reason: 'the extractor stopped reading spoken citations:\n  '
            '${missing.join('\n  ')}');

    // "2 Kings, chapter 13" — a comma between the book and the chapter
    // word. Asserted per SERMON rather than by key, because the key
    // alone proves nothing: `2 Kings 13:20` is also sermon 320's, so a
    // regression here would leave it in the index pointing elsewhere.
    // Sermon 325 reads "2 Kings, chapter 13, verses 20 and 21" as its
    // central exposition and was filed under `2 Kings 13:5` — an aside
    // sixty lines away — for as long as the comma was unparsable.
    final bySermonComma = (refs['bySermon'] as Map).cast<String, dynamic>();
    expect(bySermonComma['325'], contains('2 Kings 13'));
    expect(bySermonComma['325'], contains('2 Kings 13:20'));
    expect(bySermonComma['366'], contains('Genesis 3'));

    // A floor, so wholesale loss is caught even in forms not listed
    // above. 2968 keys on 2026-08-25; the pre-restoration script
    // produced 1269 and the index it could not rebuild had 1294.
    expect(bv.length, greaterThanOrEqualTo(2800));
  });

  // A sentence can end on a book name and the next can open with the
  // ordinal of another: "…only in the letters of John. 1 John 2 and
  // verse 18". The book pattern tolerates an abbreviating full stop,
  // so the Gospel swallowed the 1 and the shipped index filed sermon
  // 237 under John 1 — a chapter that sermon never opens. Each pair
  // below is one sermon reachable under a book it does not expound,
  // together with the reference it should have had all along.
  test('an ordinal belongs to the book it precedes, not the one before',
      () {
    final bySermon = (refs['bySermon'] as Map).cast<String, dynamic>();
    const swallowed = <String, (List<String>, String)>{
      '237': (['John 1', 'John 2'], '1 John 2:18'),
      '765': (['1 Peter 1'], '1 Peter 4:1'),
      '238': (['Revelation 2'], '2 John 1:7'),
    };
    swallowed.forEach((id, pair) {
      final keys = (bySermon[id] as List).cast<String>();
      for (final wrong in pair.$1) {
        expect(keys, isNot(contains(wrong)),
            reason: '$id is not about $wrong — the number is the next '
                'book\'s ordinal');
      }
      expect(keys, contains(pair.$2));
    });

    // The appositive form of the same confusion: "the first letter of
    // John, chapter 2" is 1 John, and which of the three letters it is
    // cannot be recovered from the phrase, so nothing is indexed rather
    // than the Gospel. Sermon 343 states it plainly elsewhere.
    final k343 = (bySermon['343'] as List).cast<String>();
    expect(k343, isNot(contains('John 2:19')));
    expect(k343, contains('1 John 2:19'));
  });

  // A cited range is one key per verse. The extractor wrote only the
  // range's first verse until 2026-08-25 — harmless while the same
  // sentence also left a bare "Matthew 25" behind, because a chapter
  // key satisfies any verse filter, and fatal the moment the extractor
  // learned to read "verses 31 to 46" and narrowed that chapter key
  // away. Sermon 159 lost fifteen of its sixteen verses that way.
  test('a cited range reaches every verse in it', () {
    final bv = (refs['byVerse'] as Map).cast<String, dynamic>();
    for (final v in [31, 39, 46]) {
      expect(bv['Matthew 25:$v'], contains('159'),
          reason: 'Matthew 25:31-46 is sermon 159\'s whole passage');
    }
    for (final v in [21, 30, 35]) {
      expect(bv['Matthew 18:$v'], contains('034'),
          reason: '"verses 21 to 35" — the range spelled out in words');
    }
    for (final v in [32, 33, 34]) {
      expect(bv['Luke 12:$v'], contains('422'),
          reason: '「路加福音12章32到34节」 — 到 as the range word');
    }
    // "Matthew 24, verse 45, right up to Matthew 25, verse 30" is one
    // passage that the pattern can only ever see as two citations, so
    // the far end has to be recognised by what stands between them.
    for (final v in [1, 13, 30]) {
      expect(bv['Matthew 25:$v'], contains('158'));
    }
    // 「馬太福音11:30-12:1-8」 — the same passage written as numbers.
    // What makes the 12 a chapter rather than a verse is that it
    // carries a verse of its own on the far side of the colon.
    for (final v in [2, 5, 8]) {
      expect(bv['Matthew 12:$v'], contains('063'));
    }
  });

  // index.json's `passage` is written by an editor and the extractor
  // never reads it, so it is the one witness to coverage that cannot
  // agree with the extractor by construction. It is what caught the
  // range bug: 500+ declared verses were unreachable before 2026-08-25,
  // most of them the tails of ranges the extractor truncated to their
  // first verse. It only knows the abbreviations the field actually
  // uses; keep the map current or the test quietly checks nothing.
  const abbrev = <String, String>{
    '1Cor': '1 Corinthians', '1Pet': '1 Peter', '2Cor': '2 Corinthians',
    '2Pet': '2 Peter', 'Eph': 'Ephesians', 'Gal': 'Galatians',
    'Heb': 'Hebrews', 'Jn': 'John', 'Lk': 'Luke', 'Luke': 'Luke',
    'Mk': 'Mark', 'Mt': 'Matthew', 'Phil': 'Philippians',
    'Philippians': 'Philippians', 'Rom': 'Romans',
    'Songs': 'Song of Solomon', 'Titus': 'Titus',
  };

  // The extractor reads only the first verse of a non-contiguous list —
  // "verses 12, 14 and 15", 「第2、4、5節」 — so these declared verses
  // are still out of reach. Listed rather than waived so that the count
  // cannot grow unnoticed.
  const listGap = <String>{
    '034 Matthew 6:14', '034 Matthew 6:15',
    '077 Matthew 13:36', '077 Matthew 13:37', '077 Matthew 13:38',
    '077 Matthew 13:39', '077 Matthew 13:40', '077 Matthew 13:41',
    '077 Matthew 13:42', '077 Matthew 13:43',
    '398 2 Corinthians 12:8', '398 2 Corinthians 12:9',
  };

  test('every verse of every declared passage is in the index', () {
    final bySermon = (refs['bySermon'] as Map).cast<String, dynamic>();
    final index = jsonDecode(
        File('assets/sermons/index.json').readAsStringSync()) as List<dynamic>;
    final unreachable = <String>[];
    var checked = 0;
    for (final row in index.cast<Map<String, dynamic>>()) {
      final passage = (row['passage'] as String? ?? '').trim();
      final head = RegExp(r'^([1-3]?\s?[A-Za-z][A-Za-z\s]*?)\s+(\d.*)$')
          .firstMatch(passage);
      if (head == null) continue;
      final book = abbrev[head.group(1)!.trim()];
      if (book == null) continue;
      checked++;
      final keys = ((bySermon[row['id']] ?? []) as List).cast<String>();
      int? ch;
      final want = <List<int>>[];
      for (final part
          in head.group(2)!.replaceAll(RegExp(r'[–—]'), '-').split(
              RegExp(r'[;,]| and '))) {
        final full = RegExp(
                r'^(\d+)[:.](\d+)[ab]?(?:\s*-\s*(?:(\d+)[:.])?(\d+)[ab]?)?$')
            .firstMatch(part.trim());
        if (full != null) {
          ch = int.parse(full.group(1)!);
          final endCh = int.parse(full.group(3) ?? '$ch');
          final from = int.parse(full.group(2)!);
          final to = int.parse(full.group(4) ?? '$from');
          for (var c = ch; c <= endCh; c++) {
            final verses = canon[book]?[c];
            if (verses == null) continue;
            final lo = c == ch ? from : 1;
            final hi = c == endCh ? to : verses.length;
            for (var v = lo; v <= hi; v++) {
              if (verses.contains(v)) want.add([c, v]);
            }
          }
          continue;
        }
        final tail = RegExp(r'^(\d+)[ab]?(?:\s*-\s*(\d+)[ab]?)?$')
            .firstMatch(part.trim());
        if (tail != null && ch != null) {
          for (var v = int.parse(tail.group(1)!);
              v <= int.parse(tail.group(2) ?? tail.group(1)!);
              v++) {
            if (canon[book]?[ch]?.contains(v) ?? false) want.add([ch, v]);
          }
        }
      }
      for (final cv in want) {
        // A sermon the extractor never placed in this chapter at all is
        // a different failure, and one this test cannot tell from an
        // editor's typo in the passage field.
        if (!keys.any((k) => k.startsWith('$book ${cv[0]}'))) continue;
        if (keys.contains('$book ${cv[0]}')) continue;
        if (keys.contains('$book ${cv[0]}:${cv[1]}')) continue;
        final gap = '${row['id']} $book ${cv[0]}:${cv[1]}';
        if (!listGap.contains(gap)) unreachable.add('$gap (claims $passage)');
      }
    }
    expect(checked, greaterThan(150),
        reason: 'the abbreviation map has gone stale and this test is '
            'checking almost nothing');
    expect(unreachable, isEmpty,
        reason: 'declared passages the index cannot reach:\n  '
            '${unreachable.join('\n  ')}');
  });
}
