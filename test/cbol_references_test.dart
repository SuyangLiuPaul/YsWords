import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/utils/cbol_references.dart';
import 'package:yswords/utils/reference_parser.dart';

/// Every source string below is copied verbatim out of the bundled
/// lexicon assets — `assets/strongs/{greek,hebrew,bdb_zh,thayer_zh}.json`
/// — so the grammar is tested against what CBOL actually wrote rather
/// than against what its notation looks like it ought to be.
void main() {
  List<CbolRun> refs(String s) =>
      parseCbolRuns(s).where((r) => r.kind == CbolRunKind.reference).toList();

  group('parseCbolRuns — the shapes the corpus uses', () {
    test('the canonical gloss block: (#book c:v-v|)', () {
      final r = refs('结束, 完成 (#路 14:19-30|)');
      expect(r.single.text, '路 14:19-30');
      expect(r.single.reference, 'Luke 14:19');
    });

    test('a hyphen is a span, so the link opens its FIRST verse only', () {
      expect(refs('(#提后 1:16-18; 4:19|)').map((r) => r.reference),
          ['2 Timothy 1:16', '2 Timothy 4:19']);
    });

    test('the book token is inherited by later citations', () {
      expect(refs('(#林后 10:13,15,16|)').single.reference,
          '2 Corinthians 10:13');
      expect(refs('(#但 10:21;12:1| )').map((r) => r.reference),
          ['Daniel 10:21', 'Daniel 12:1']);
    });

    test('a semicolon starts a new citation, a comma does not', () {
      expect(refs('(#徒 25:15; 帖后 1:9; 犹7)').map((r) => r.reference),
          ['Acts 25:15', '2 Thessalonians 1:9', 'Jude 1:7']);
      expect(refs('(#太 1:13, 14)').single.text, '太 1:13, 14');
    });

    test('bdb_zh writes the same block bare, with no parentheses', () {
      expect(refs('1) 犹大境内地方 #代上 2:51 |').single.reference,
          '1 Chronicles 2:51');
      expect(refs('2) 在亚设的大衮庙 (#书19:27)').single.reference, 'Joshua 19:27');
      expect(refs('1) 位于巴勒斯坦的一个地方 ( #尼12:28 |)').single.reference,
          'Nehemiah 12:28');
    });

    test('two bare blocks in running prose', () {
      final r = refs('#可 5:2 | 和 #路 8:27 | 则用该区的首府 "革拉森" 称之.');
      expect(r.map((x) => x.reference), ['Mark 5:2', 'Luke 8:27']);
    });

    test('a c:v item inside a verse list changes chapter', () {
      // `伯 8:12,9:11` is Job 8:12 and Job 9:11 — one citation whose
      // list crosses a chapter, not the malformed `8:12,9` + `:11` a
      // naive verse-list regex produces.
      final r = refs('(#伯 8:12,9:11|)');
      expect(r.single.text, '伯 8:12,9:11');
      expect(r.single.reference, 'Job 8:12');
    });

    test('half-verse letters and chapter-only citations', () {
      expect(refs('(#创 19:12a)').single.reference, 'Genesis 19:12');
      expect(refs('(#士 4)').single.reference, 'Judges 4');
      expect(refs('(#徒 10章)').single.reference, 'Acts 10');
    });

    test('a note after the pipe stays, as text', () {
      final runs = parseCbolRuns('(#代上 3:5|译作 拔书亚)');
      expect(runs.map((r) => r.text).join(), '(代上 3:5 译作 拔书亚)');
      expect(refs('(#代上 3:5|译作 拔书亚)').single.reference, '1 Chronicles 3:5');
    });

    test('约伯 is Job, and is now read as Job', () {
      // This test asserted the opposite until 2026-09-08, and said why:
      // the whole 1-5 character token is looked up and never a prefix
      // of it, so `约伯` fell between the `伯` and the full `约伯记`
      // that `reference_parser.dart` indexed, and resolved to nothing —
      // while the prefix `约` is John, a different book on the other
      // side of the canon. It ended: "Adding `约伯` to
      // `_chineseShortAliases` would fix it, in a file this change does
      // not own; failing visibly is the correct behaviour until then."
      //
      // It was added. So this is the fix arriving, not the gap being
      // re-recorded, and it was the ONE resolvable reference in the
      // corpus the gap cost. The two book tokens the corpus still
      // cannot read, `代` and `撒`, are each genuinely ambiguous
      // between two books and are not this kind of problem.
      expect(refs('(#约伯10:22|)').single.reference, 'Job 10:22');
      expect(cbolPlainText('1) 安排, 有序 (#约伯10:22 |)'),
          contains('约伯10:22'));
      // The prefix it must still not shadow.
      expect(refs('(#约 10:22|)').single.reference, 'John 10:22');
    });
  });

  group('the Traditional column resolves exactly as the Simplified does',
      () {
    // This is the half of the port YsWords needed and SeekSparks did
    // not: `reference_parser.dart` here indexes Simplified short forms
    // only, so 創/約/林後/啓/傳 and the formal numerals in 約壹/约参 all
    // came back null. Measured before the fix, 1,904 of the corpus's
    // 39,596 `#` sites failed on nothing but the script — the map
    // brought the total that will not parse down from 1,973 to 69.
    test('a Traditional book token names the same book', () {
      for (final pair in const [
        ['(#創 1:1|)', '(#创 1:1|)'],
        ['(#約 3:16|)', '(#约 3:16|)'],
        ['(#林後 8:20|)', '(#林后 8:20|)'],
        ['(#提後 3:8|)', '(#提后 3:8|)'],
        ['(#彼後 2:16|)', '(#彼后 2:16|)'],
        ['(#帖後 1:5|)', '(#帖后 1:5|)'],
        ['(#傳 1:2|)', '(#传 1:2|)'],
        ['(#啓 3:18|)', '(#启 3:18|)'],
      ]) {
        expect(refs(pair[0]).single.reference, refs(pair[1]).single.reference,
            reason: '${pair[0]} and ${pair[1]} are the same book');
      }
    });

    test('John\'s letters are numbered with formal numerals too', () {
      expect(refs('(#約壹 1:1|)').single.reference, '1 John 1:1');
      expect(refs('(# 约参1:9|)').single.reference, '3 John 1:9');
      expect(refs('(#約參 1:9|)').single.reference, '3 John 1:9');
    });

    test('the retry is a book-token lookup, not a script conversion', () {
      // The Simplified form is tried first and wins, so a token that
      // already resolves never reaches the map. `後` outside a book
      // token is untouched — the parser only ever sees the 1-5
      // characters `_citation` isolated as a candidate book.
      expect(refs('(#后 1:1|)'), isEmpty,
          reason: '后 alone is not a book and must not become 2 Timothy');
    });
  });

  group('what the parser refuses to read', () {
    // These are real defects in the source data. The rule is that an
    // unreadable reference must LOOK unreadable: no silent drop, and
    // above all no link to a plausible wrong verse.
    test('a block with no book at all stays text', () {
      expect(refs('1b3) 认同, 赞同 (#119:128|)'), isEmpty);
      expect(parseCbolRuns('1b3) 认同, 赞同 (#119:128|)').single.text,
          '1b3) 认同, 赞同 (#119:128|)');
    });

    test('an ambiguous book abbreviation is left unresolved', () {
      // `代` could be 1 or 2 Chronicles and `撒` either book of Samuel.
      // Guessing would be a fabricated fact, and the reader has no way
      // to tell a guessed link from a sound one.
      expect(refs('9) 暗利的父亲或先祖 (#代 27:18|)'), isEmpty);
      expect(refs("1) 大卫王的一位谋士(参见 #撒 11:3;23:34|)"), isEmpty);
    });

    test('prose behind the hash is not a reference', () {
      expect(refs('1) 重担, 担负 (#喻意用法)'), isEmpty);
      expect(refs('1) (亡命者) 漫无目标的流浪 (#)'), isEmpty);
      expect(refs('1) 年岁, 一生的时间 (#路 )'), isEmpty);
    });

    test('a stray colon before the chapter is not silently repaired', () {
      expect(refs('1c) (Hiphil) 喃喃自语 (#赛:19)'), isEmpty);
      expect(refs('1a) 围城的器械, 撞城槌 (#结:26:9|)'), isEmpty);
    });

    test('a missing colon between chapter and verse is not invented', () {
      // `徒 2713` is Acts 27:13 in the printed lexicon, but reading it
      // that way means choosing where to put a colon the source did not
      // write. It stays as text.
      expect(refs('接近, 贴近 (#徒 2713|)'), isEmpty);
    });
  });

  group('cbolPlainText — delimiters go, citations stay', () {
    test('the gloss reads as Chinese again', () {
      expect(cbolPlainText('结束, 完成 (#路 14:19-30|)'), '结束, 完成 (路 14:19-30)');
      expect(cbolPlainText('1) 犹大境内地方 #代上 2:51 |'), '1) 犹大境内地方 代上 2:51');
      expect(cbolPlainText('( #尼12:28 |)'), '( 尼12:28)');
    });

    test('indentation survives — the senses are laid out with it', () {
      expect(cbolPlainText('     1a1) 直走 (#撒上6:12|)'),
          '     1a1) 直走 (撒上6:12)');
    });

    test('no readable string keeps a delimiter', () {
      for (final s in const [
        '结束, 完成 (#路 14:19-30|)',
        '(在#代上8:3 |是便雅悯家的一员)',
        '(#徒 25:15; 帖后 1:9; 犹7)',
        '#可 5:2 | 和 #路 8:27 | 则用',
        '豐厚(#林後 8:20|)',
      ]) {
        final out = cbolPlainText(s);
        expect(out.contains('#'), isFalse, reason: s);
        expect(out.contains('|'), isFalse, reason: s);
      }
    });
  });

  group('stripCbolReferences — for one-line glosses only', () {
    test('the parenthetical goes with the citation', () {
      expect(stripCbolReferences('结束, 完成 (#路 14:19-30|)'), '结束, 完成');
      expect(stripCbolReferences('豐厚(#林後 8:20|)'), '豐厚');
      expect(stripCbolReferences('1) 犹大境内地方 #代上 2:51 |'), '1) 犹大境内地方');
    });

    test('an unreadable block is left exactly as it was', () {
      expect(stripCbolReferences('1) 重担, 担负 (#喻意用法)'), '1) 重担, 担负 (#喻意用法)');
    });

    test(
        'a gloss that is nothing but a reference does not become empty '
        'punctuation', () {
      expect(stripCbolReferences('(#路 14:19|)'), '');
    });
  });

  group('every reference the parser emits is one the app can navigate to',
      () {
    test('parseReference agrees with the run', () {
      for (final s in const [
        '(#路 14:19-30|)',
        '(#徒 25:15; 帖后 1:9; 犹7)',
        '(#創 1:1|)',
        '(#士 4)',
        '(#約壹 1:1|)',
        '1) 犹大境内地方 #代上 2:51 |',
      ]) {
        for (final run in refs(s)) {
          final parsed = parseReference(run.reference!);
          expect(parsed, isNotNull, reason: '${run.reference} from $s');
          expect(parsed!.englishBook, run.englishBook);
          expect(parsed.chapter, run.chapter);
          if (run.verse != null) expect(parsed.verseStart, run.verse);
        }
      }
    });
  });
}
