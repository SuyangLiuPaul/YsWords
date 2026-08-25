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

  // "verses 20 and 21" is a range; "verses 12, 14 and 15" is a list,
  // and walking it would invent verse 13. `and` is admitted as a range
  // separator only between ADJACENT verses, which is the one case where
  // a two-item list and a two-verse range denote the same set — so this
  // rule cannot put a sermon under a verse nobody cited.
  test('"and" joins two verses only when they are adjacent', () {
    final bySermon = (refs['bySermon'] as Map).cast<String, dynamic>();
    List<String> keys(String id) => (bySermon[id] as List).cast<String>();

    // 2 Kings 13:21 — the corpse revived on Elisha's bones — is what
    // sermons 320 and 325 turn on, and "verses 20 and 21" reached only
    // 13:20 until 2026-08-25.
    for (final id in ['320', '325']) {
      expect(keys(id), containsAll(['2 Kings 13:20', '2 Kings 13:21']));
      expect(keys(id), isNot(contains('2 Kings 13:22')),
          reason: 'the range is exactly the two verses named');
    }

    // Sermon 012 says "1 Timothy, chapter 1, verses 13 and 16". 16 is
    // not 14, so this stays a list of two and 14/15 are NOT walked.
    expect(keys('012'), contains('1 Timothy 1:13'));
    for (final v in [14, 15, 16]) {
      expect(keys('012'), isNot(contains('1 Timothy 1:$v')),
          reason: '"verses 13 and 16" names two verses, not a span');
    }

    // The trap: an ordinal past the `and` belongs to the book that
    // follows it. "James 4:10 and 1 Peter 5:5" must not consume the 1 —
    // doing so both invents James 4:11 and loses 1 Peter 5:5. The
    // lookahead that refuses it is BOOK_RE rather than the full-name
    // NUMBERED_TAIL_RE used for the chapter position, because that one
    // does not know the abbreviations ("and 2 Sam 7:14").
    for (final trap in [
      ('057', 'James 4:10', 'James 4:11', '1 Peter 5:5'),
      ('108', 'Romans 9:33', 'Romans 9:34', '1 Peter 2:8'),
    ]) {
      expect(keys(trap.$1), contains(trap.$2));
      expect(keys(trap.$1), isNot(contains(trap.$3)),
          reason: '${trap.$3} was never cited — the number is an ordinal');
      expect(keys(trap.$1), contains(trap.$4),
          reason: 'the reference past the `and` must survive');
    }

    // A sentence stop is a member of the verse-separator class, so the
    // cross-chapter tail must be unreachable after `and`: in sermon
    // 009's "verses 7 and 8. 2 Peter 2, 7 and 8" it read the full stop
    // as a separator, made the 8 a far CHAPTER, and walked 2 Peter
    // 2:7-3:18 — 32 verses the sermon never opens.
    expect(keys('009'), containsAll(['2 Peter 2:7', '2 Peter 2:8']));
    for (final v in [9, 22]) {
      expect(keys('009'), isNot(contains('2 Peter 2:$v')));
    }
    expect(keys('009').where((k) => k.startsWith('2 Peter 3')), isEmpty);
  });

  // "Romans 13, 9" is how this preacher restates a reference he has
  // just read out, and until 2026-08-25 it reached only Romans 13. The
  // form has no word in it saying "verse", so it is admitted only under
  // four refusals — each one below is a real sentence in the corpus
  // that would otherwise file a sermon under a passage it never opens.
  test('a bare comma carries a verse, but only where nothing else fits',
      () {
    final bySermon = (refs['bySermon'] as Map).cast<String, dynamic>();
    List<String> keys(String id) => (bySermon[id] as List).cast<String>();

    // C174: "that is why in Romans 13, 9, when speaking about the
    // central issue of the law, Paul does not even mention the first
    // part" — Romans 13:9 lists only the neighbour-facing commandments,
    // which is exactly the point being made.
    expect(keys('C174'), contains('Romans 13:9'));
    expect(keys('C174'), contains('Galatians 5:14'));
    // EC013 verifies itself: "2 Corinthians 4, 18. The last verse of the
    // chapter" — and 2 Corinthians 4 ends at verse 18.
    expect(keys('EC013'),
        containsAll(['2 Corinthians 4:18', 'Deuteronomy 33:27']));

    // Refusal 1 — a third comma-number makes it a list of CHAPTERS.
    // 247: "Matthew 23, 24, 25. They are one unit of the Lord's
    // teaching." Matthew 23:24 exists, so the canon check cannot catch
    // this; only the lookahead can. The `(?!\d)` that stops `\d+`
    // backtracking is load-bearing here — without it the verse matched
    // as the bare `2` of "24" and the guard saw "4, 25" and passed.
    expect(keys('247'), isNot(contains('Matthew 23:24')));
    expect(keys('247'), isNot(contains('Matthew 23:2')));
    // The corpus's other instance of this shape — 356's "in Romans 6,
    // 7, and 8, we have three distinct categories" — is NOT asserted,
    // because that sermon says "chapter 6, verse 7" elsewhere and the
    // invention would be masked at index level. 247 is the one that
    // discriminates.

    // Refusal 2 — a spelled-out chapter word ahead of the number is
    // what makes a following bare number readable as another chapter.
    // 004: "which Jesus already acknowledges in John chapters 12, 14
    // and 16" — three chapters, and it became John 12:14.
    expect(keys('004'), isNot(contains('John 12:14')));
    // The refusal covers the singular too, deliberately: 356's "Romans
    // chapter 8, 1 and 2" has a singular word and a far number that IS
    // a plausible chapter of Romans, so nothing in its shape says which
    // it is. Those verses reach the index by their explicit citation
    // one sentence earlier, not by this branch.
    expect(keys('356'), containsAll(['Romans 8:1', 'Romans 8:2']));

    // Refusal 3 — a thousands separator is not a citation: EC010's "the
    // Apostle John 2,000 years ago said the day is coming". Not
    // asserted either, and deliberately so: the mandatory space after
    // the comma refuses it, but "2,000" would yield verse 0 and the
    // canon check would drop it anyway, so an index-level assertion
    // would pass with the space requirement deleted. The space earns
    // its place against "1,500"-shaped numbers, which do not occur.

    // Refusal 4 — "as we saw in Genesis 1, 2 Peter tells us…": the 2 is
    // the ordinal of the NEXT book. This one has zero occurrences in
    // the corpus, so no assertion over refs.json can pin it and a
    // corpus-only test would pass with the guard deleted. It is pinned
    // at source instead: the bare-comma branch must carry the same
    // ordinal lookahead the chapter position uses.
    final src = File('scripts/extract_sermon_refs.py').readAsStringSync();
    final start = src.indexOf(r'(?P<vbare>');
    expect(start, isNot(-1),
        reason: 'the bare-comma verse branch must still be named vbare');
    // The branch is spelled across two adjacent Python literals, so this
    // reads a window rather than trying to match balanced parentheses.
    final vbare = src.substring(start, start + 200);
    expect(vbare, contains(r'(?![1-3]\s+{NUMBERED_TAIL_RE}\b)'),
        reason: 'without this an ordinal is consumed as a verse and the '
            'book it introduces is lost');
  });

  // A book name is sometimes an ordinary word, and the number after it
  // is then an ordinal label rather than a chapter. Both members below
  // put a sermon under a passage it never opens, which is the one thing
  // this index must not do.
  //
  // The other half of the test is the two repairs that were REJECTED,
  // pinned by example so the next iteration does not re-derive them:
  //
  //  * "a bare chapter followed by a colon carrying no digit is a
  //    label" — 94 matches in the corpus fit that shape and only
  //    339's three are false. The other 91 are citations whose colon
  //    introduces the passage's words ("Paul says in Romans 11: …").
  //  * "ignore `# ` heading lines" — 22 keys come only from headings
  //    and 19 of them are genuine.
  //
  // Both rules are cheap to write and would each destroy an order of
  // magnitude more than they repair, so the fix is per-verse instead:
  // 339's editorial heading spells its numerals, and REF_RE reads a
  // chapter only as digits or a CJK numeral.
  test('a book name used as an ordinary word does not index a chapter',
      () {
    final bySermon = (refs['bySermon'] as Map).cast<String, dynamic>();
    final k339 = (bySermon['339'] as List).cast<String>();
    for (final wrong in ['Mark 5', 'Mark 6', 'Mark 7']) {
      expect(k339, isNot(contains(wrong)),
          reason: '339 is "Seven Marks of a Regenerated Christian" — '
              '$wrong is the Nth mark, and the sermon expounds 1 John');
    }
    expect(k339, contains('1 John 3:9'));

    // "How much obedience is sufficient? Is 50% enough?" — the verb,
    // plus a percentage. `%` used to sit inside a `\b` in the unit-word
    // guard, and `%` followed by a space is not a word boundary, so the
    // guard could not see it. Isaiah 100 and Isaiah 99 in the same
    // sentence were stopped only by the canon check.
    expect((bySermon['424'] as List).cast<String>(),
        isNot(contains('Isaiah 50')));

    final bv = (refs['byVerse'] as Map).cast<String, dynamic>();
    // The 91 the colon rule would have taken.
    for (final pair in [
      ('Romans 11', '007'), ('Acts 17', '116'), ('Matthew 7', '083'),
      ('Isaiah 53', '394'), ('John 18', '122'),
    ]) {
      expect(bv[pair.$1], contains(pair.$2),
          reason: '${pair.$1} is cited with a colon before a quotation, '
              'not labelled');
    }
    // The 19 the heading rule would have taken.
    for (final pair in [
      ('1 Thessalonians 5', '153'), ('John 15:1', '342'),
      ('Luke 9:23', '318'), ('Song of Solomon 1:2', '721'),
      ('Ephesians 4', '337'),
    ]) {
      expect(bv[pair.$1], contains(pair.$2),
          reason: '${pair.$1} reaches the index only through a heading');
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
