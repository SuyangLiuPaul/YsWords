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

    // 第 is optional on the chapter: 章/篇 is already proof the number
    // is a chapter. Requiring it cost 260 cited verses in the corpus.
    test('chapter mark with no 第 in front of it', () {
      final r = parseReference('馬太福音3章15節')!;
      expect(r.englishBook, 'Matthew');
      expect(r.chapter, 3);
      expect(r.verseStart, 15);
    });

    test('chapter mark with no 第 and a Chinese numeral', () {
      final r = parseReference('以西結書三章十七節')!;
      expect(r.englishBook, 'Ezekiel');
      expect(r.chapter, 3);
      expect(r.verseStart, 17);
    });

    test('篇 with no 第 still marks a Psalm chapter', () {
      expect(parseReference('詩篇23篇')!.chapter, 23);
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

    // Measured 2026-08-31 (docs/autonomous-queue.md ~7164). The
    // book-name-to-chapter-mark join already used [^\S\n] (the "does
    // not reach across a paragraph break" case above); the English
    // digit tail and the Chinese digit fallback did not, and sermon
    // 134 shows why that is live: "...quoting those numbers." / blank
    // line / "400 prophets were consulted" matched as a single
    // reference "numbers.\n\n400" (Numbers 400) — caught only because
    // 400 is out of canon for Numbers (36 chapters). A same-shaped
    // join onto an in-canon chapter would not have been caught by
    // anything. `sermon_detail_page.dart` splits on `\n\s*\n` before
    // matching, so this specific case was never reachable through the
    // sermon reader — but the pattern itself is used elsewhere
    // (`localizePassage`) and should not depend on a caller happening
    // to pre-split its input.
    test('the English digit tail does not reach across a paragraph break',
        () {
      // Capitalized, so this isolates the newline fix from the
      // separate case-sensitivity fix below — sermon 134's actual
      // text is lower-case "numbers." and is refused for that reason
      // alone now, which the case-sensitivity test covers.
      expect(
          passageRefPattern
              .firstMatch('quoting those Numbers.\n\n400 prophets'),
          isNull);
      expect(passageRefPattern.firstMatch('Numbers 4:16')?.group(0),
          'Numbers 4:16');
    });

    test(
        'the Chinese digit fallback does not reach across a paragraph '
        'break', () {
      expect(passageRefPattern.firstMatch('詩篇\n\n23:1'), isNull);
      expect(
          passageRefPattern.firstMatch('詩篇 23:1')?.group(0), '詩篇 23:1');
    });

    // The only effect of matching case-insensitively, swept over all
    // 867 transcripts: 4 false matches where lower-case "am" ("I am
    // 100", "I am 21, 23" — self-reported ages) is read as the Amos
    // abbreviation "Am". No real reference in the corpus, and no
    // `index.json` `passage` field, is anything but Titlecase, so
    // nothing genuine depends on case-insensitivity. All four sites
    // were already inert before this fix too — `parseReference`
    // refuses Amos 100/21 internally (Amos has 9 chapters) — so this
    // pins that the match itself is gone, not just its canon check.
    test('lower-case "am" is not read as the Amos abbreviation', () {
      expect(passageRefPattern.firstMatch('I am 100 years old'), isNull);
      expect(passageRefPattern.firstMatch('I am 21, 23'), isNull);
      // The real abbreviation, properly cased, still matches.
      expect(passageRefPattern.firstMatch('Am 3:7')?.group(0), 'Am 3:7');
    });

    // Alternation is ordered. With the digit branch first, `\s*\d+`
    // wins on 「馬太福音3章15節」, the match ends at 「馬太福音3」 and the
    // verse behind it is prose — the tap landed on the chapter and lost
    // the verse. This assertion is what fails if the branches are ever
    // swapped back.
    test('the chapter-mark branch beats the digit branch', () {
      expect(passageRefPattern.firstMatch('讀馬太福音3章15節。')?.group(0),
          '馬太福音3章15節');
      expect(passageRefPattern.firstMatch('以西結書36章23節')?.group(0),
          '以西結書36章23節');
      // Chapter only, no verse — still the whole chapter mark.
      expect(passageRefPattern.firstMatch('哥林多前書15章')?.group(0),
          '哥林多前書15章');
    });

    // The 節/节 guard is the same guard whether or not 第 is present:
    // dropping 第 must not let a restated chapter read as a verse.
    test('a restated chapter with no 第 is still not a verse', () {
      final m = passageRefPattern.firstMatch('馬可福音9章，9章的最後部分');
      expect(m!.group(0), '馬可福音9章');
      expect(parseReference(m.group(0)!)!.isWholeChapter, isTrue);
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

    // 第 is optional here for the same reason it is optional in the
    // pattern. Were it still required, 「馬太福音3章15節」 would be
    // rewritten to 「馬太福音 3:15」 — a preacher's sentence restated in
    // a notation he did not use.
    test('the 第-less chapter mark is also the preacher\'s own notation',
        () {
      expect(usesChineseChapterMark('馬太福音3章15節'), isTrue);
      expect(usesChineseChapterMark('詩篇23篇'), isTrue);
      expect(localizePassage('馬太福音3章15節', 'zh-Hant'), '馬太福音3章15節');
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

  // Queue :7296 — two spellings the alias table missed. 約拿記/约拿记
  // (Jonah written with 記 instead of 書) and 哥罗西书 (Colossians with
  // 哥 instead of 歌) are both unambiguous — there is no other 約拿 or
  // 哥羅西 book — so this is a table gap, not a judgement call. Fixing
  // only `_zhAliasToEn` is not enough: `passageRefPattern`'s Chinese
  // branch is a separate hand-written alternation, so a spelling can
  // resolve via `parseReference` and still never be matched in text.
  group('約拿記 / 哥罗西书 aliases (queue :7296)', () {
    test('約拿記/约拿记 resolves like 約拿書/约拿书', () {
      expect(parseReference('約拿記第2章')!.englishBook, 'Jonah');
      expect(parseReference('约拿记第2章')!.englishBook, 'Jonah');
    });

    test('哥罗西书/哥羅西書 resolves like 歌罗西书/歌羅西書', () {
      expect(parseReference('哥罗西书1章19節')!.englishBook, 'Colossians');
      expect(parseReference('哥羅西書1章19節')!.englishBook, 'Colossians');
    });

    test('passageRefPattern matches the corpus sentence from sermon 069', () {
      const s = '正如我们在约拿记第2章那美丽的祷告中所看到的。';
      final m = passageRefPattern.firstMatch(s);
      expect(m, isNotNull);
      expect(m!.group(0), '约拿记第2章');
    });

    test('passageRefPattern matches the corpus sentence from EC013', () {
      const s = '哥罗西书1章19節都讲到神的整体的封城都是住在基督里面.';
      final m = passageRefPattern.firstMatch(s);
      expect(m, isNotNull);
      expect(m!.group(0), '哥罗西书1章19節');
    });
  });

  // The measurement that motivated the change, kept executable so a
  // later regex edit cannot quietly undo it.
  group('the Chinese corpus', () {
    test('every chapter-mark match resolves, and none is invented', () {
      var markMatches = 0;
      final unresolved = <String>{};
      for (final m in _corpusMatches()) {
        final s = m.value.group(0)!;
        if (!usesChineseChapterMark(s)) continue;
        markMatches++;
        if (parseReference(s) == null) unresolved.add(s);
      }
      expect(markMatches, greaterThan(5000),
          reason: 'the form the transcripts actually speak');
      // 一一九 is the digit-string reading of 119 and neither this
      // parser nor `cn_number` in the Python extractor admits it —
      // both are structural, which is what rejects 十十. The two sites
      // render as plain text, exactly as they did before the pattern
      // reached them, so nothing is underlined that does nothing when
      // tapped. Named rather than counted so that any NEW unresolvable
      // shape still fails here.
      //
      // The other four (2026-08-31): sermon 232's "阿摩司书第12章" (Amos
      // has 9 chapters) and CP37's "启示录三十七章十七节" (Revelation has
      // 22), in both zh-CN and zh-TW, now refuse to parse at all —
      // `parseReference` itself gained the chapter-canon check that used
      // to live only at the sermon page's own call sites (queue line
      // 7042). Same "underlines nothing" property as the 一一九 pair.
      expect(unresolved, {
        '诗篇一一九篇103节', '詩篇一一九篇103節',
        '阿摩司书第12章', '阿摩司書第12章',
        '启示录三十七章十七节', '啓示錄三十七章十七節',
      }, reason: 'a match the parser cannot resolve underlines nothing');
    });

    // The defect this pattern order was changed for. A match that stops
    // immediately in front of a 章/篇 has read the chapter number and
    // left the mark — and any verse behind it — as prose. There were
    // 674 of those, 260 carrying a cited verse.
    test('no match stops in front of a chapter mark', () {
      final stopped = <String>[];
      for (final e in _corpusMatches()) {
        final rest = e.key.substring(e.value.end);
        if (rest.startsWith(RegExp(r'[^\S\n]*[章篇]'))) {
          stopped.add(e.value.group(0)!);
        }
      }
      expect(stopped, isEmpty,
          reason: '${stopped.length} matches drop the chapter mark, '
              'e.g. ${stopped.take(3).toList()}');
    });
  });
}

/// Every [passageRefPattern] match in the Chinese sermon corpus, paired
/// with the text it was found in so a caller can look behind it.
Iterable<MapEntry<String, RegExpMatch>> _corpusMatches() sync* {
  for (final dir in ['assets/sermons/zh-CN', 'assets/sermons/zh-TW']) {
    for (final f in Directory(dir).listSync().whereType<File>()) {
      if (!f.path.endsWith('.txt')) continue;
      final text = f.readAsStringSync();
      for (final m in passageRefPattern.allMatches(text)) {
        yield MapEntry(text, m);
      }
    }
  }
}
