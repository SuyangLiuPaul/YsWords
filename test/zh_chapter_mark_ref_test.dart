import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/utils/passage_localizer.dart';
import 'package:yswords/utils/reference_parser.dart';

/// The Chinese chapter-mark grammar — 「馬太福音第5章第7節」.
///
/// The sermon transcripts speak this form far more often than the digit
/// form the reader understood before 2026-08-26: measured over all 578
/// Chinese transcripts, **5,548 chapter-mark citations against 3,516
/// digit ones**. Every one of them was ordinary text on the page — the
/// Python extractor had learned the grammar long ago, so `refs.json`
/// held references the reader would not underline.
void main() {
  group('cnNumber', () {
    test('units, tens and hundreds', () {
      expect(cnNumber('一'), 1);
      expect(cnNumber('九'), 9);
      expect(cnNumber('十'), 10);
      expect(cnNumber('十四'), 14);
      expect(cnNumber('二十三'), 23);
      expect(cnNumber('一百一十九'), 119);
      expect(cnNumber('一百五十'), 150);
      expect(cnNumber('一百七十六'), 176);
    });

    // Structural, not accumulating. An accumulating parser answers 20
    // for 十十, which is not a numeral at all — and a number invented
    // out of a malformed run is exactly what must not reach a verse
    // link.
    test('malformed runs are rejected, not accumulated', () {
      expect(cnNumber('十十'), isNull);
      expect(cnNumber('百'), isNull);
      expect(cnNumber('二百三百'), isNull);
      expect(cnNumber(''), isNull);
      expect(cnNumber('五章'), isNull);
    });

    test('out of range', () {
      expect(cnNumber('二百'), isNull);
    });
  });

  group('parseReference — Chinese chapter mark', () {
    test('chapter only', () {
      final r = parseReference('馬太福音第13章')!;
      expect(r.englishBook, 'Matthew');
      expect(r.chapter, 13);
      expect(r.isWholeChapter, isTrue);
    });

    test('chapter and verse, both marked', () {
      final r = parseReference('羅馬書第五章第五節')!;
      expect(r.englishBook, 'Romans');
      expect(r.chapter, 5);
      expect(r.verseStart, 5);
    });

    test('verse without its own 第', () {
      final r = parseReference('馬可福音第4章19節')!;
      expect(r.englishBook, 'Mark');
      expect(r.chapter, 4);
      expect(r.verseStart, 19);
    });

    test('篇 marks a Psalm chapter', () {
      final r = parseReference('詩篇第23篇')!;
      expect(r.englishBook, 'Psalms');
      expect(r.chapter, 23);
    });

    test('verse range', () {
      final r = parseReference('以弗所書第六章第十節到第十八節')!;
      expect(r.chapter, 6);
      expect(r.verseStart, 10);
      expect(r.verseEnd, 18);
    });

    test('a malformed numeral yields nothing rather than a guess', () {
      expect(parseReference('馬太福音第十十章'), isNull);
    });
  });

  group('passageRefPattern', () {
    test('matches the chapter-mark form', () {
      const s = '我們讀馬太福音第5章第7節，主說。';
      final m = passageRefPattern.firstMatch(s);
      expect(m, isNotNull);
      expect(m!.group(0), '馬太福音第5章第7節');
    });

    test('stops at the sentence, does not run on', () {
      const s = '羅馬書第八章，保羅在羅馬書第八章第二十三節怎麼說？';
      final all = passageRefPattern.allMatches(s).map((m) => m.group(0));
      expect(all, ['羅馬書第八章', '羅馬書第八章第二十三節']);
    });

    // 節/节 on the second number is the whole guard, and it has to live
    // in the PATTERN: `parseReference` is anchored, so whatever the
    // pattern hands over is the whole of what a tap will act on.
    // Without the mark a restated chapter reads as a verse of itself,
    // and 「第二次」 — "a second TIME" — reads as verse 2.
    test('a restated chapter is not read as a verse of itself', () {
      final m = passageRefPattern.firstMatch('馬可福音第九章，第九章的最後部分');
      expect(m!.group(0), '馬可福音第九章');
      expect(parseReference(m.group(0)!)!.isWholeChapter, isTrue);
    });

    test('第二次 is a count of times, not a verse', () {
      final m = passageRefPattern.firstMatch('一次在哥林多前書第9章，第二次在加拉太書');
      expect(m!.group(0), '哥林多前書第9章');
      expect(parseReference(m.group(0)!)!.isWholeChapter, isTrue);
    });

    // `\s*` is not a sentence boundary — it crosses a newline. Nothing
    // in the corpus splits a citation that way, but the joins are
    // newline-free by construction so a paragraph cannot lend its first
    // number to the paragraph before it.
    test('a citation does not reach across a paragraph break', () {
      expect(passageRefPattern.firstMatch('馬太福音\n第五章第七節'), isNull);
      // An ideographic space inside the sentence is still a join.
      expect(passageRefPattern.firstMatch('馬太福音　第五章')?.group(0),
          '馬太福音　第五章');
    });

    test('the digit form still matches as it always did', () {
      expect(passageRefPattern.firstMatch('馬太福音 5:7')?.group(0),
          '馬太福音 5:7');
      expect(passageRefPattern.firstMatch('Mt 5:27-30')?.group(0),
          'Mt 5:27-30');
    });
  });

  group('usesChineseChapterMark', () {
    test('true only for the chapter-mark grammar', () {
      expect(usesChineseChapterMark('馬太福音第5章第7節'), isTrue);
      expect(usesChineseChapterMark('詩篇第23篇'), isTrue);
      // 詩篇 ends in 篇 but is a book name, not a chapter mark.
      expect(usesChineseChapterMark('詩篇 23:1'), isFalse);
      expect(usesChineseChapterMark('Mt 5:27-30'), isFalse);
    });

    // A chapter-mark citation is already in the reader's own language,
    // so localizing it would only restate a preacher's sentence in a
    // notation he did not use.
    test('localizePassage leaves the preacher\'s wording alone', () {
      expect(localizePassage('馬太福音第5章第7節', 'zh-Hant'), '馬太福音第5章第7節');
      // …while the English abbreviation it was written for still moves.
      expect(localizePassage('Mt 5:27', 'zh-Hant'), contains('馬太福音'));
    });
  });

  // The measurement that motivated the change, kept executable so a
  // later regex edit cannot quietly undo it.
  group('the Chinese corpus', () {
    test('every chapter-mark match resolves, and none is invented', () {
      var markMatches = 0;
      var unresolved = 0;
      for (final dir in ['assets/sermons/zh-CN', 'assets/sermons/zh-TW']) {
        for (final f in Directory(dir).listSync().whereType<File>()) {
          if (!f.path.endsWith('.txt')) continue;
          for (final m in passageRefPattern.allMatches(f.readAsStringSync())) {
            final s = m.group(0)!;
            if (!usesChineseChapterMark(s)) continue;
            markMatches++;
            if (parseReference(s) == null) unresolved++;
          }
        }
      }
      expect(markMatches, greaterThan(5000),
          reason: 'the form the transcripts actually speak');
      expect(unresolved, 0,
          reason: 'a match the parser cannot resolve underlines nothing');
    });
  });
}
