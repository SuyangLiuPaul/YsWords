import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:yswords/constants/canon_chapters.dart';
import 'package:yswords/utils/passage_localizer.dart';
import 'package:yswords/utils/reference_parser.dart';

/// `canonLastChapter` is the chapter-level canon check the sermon body
/// uses (`lib/pages/sermon_detail_page.dart` `_buildSpans` and
/// `_openPassagePopup`) so a transcription slip like sermon 232's
/// "阿摩司书第12章" (Amos has 9 chapters) or CP37's
/// "启示录三十七章十七节" (Revelation has 22) renders as plain text
/// instead of a tappable, underlined promise of scripture that isn't
/// there — see `docs/autonomous-queue.md` line 7008.
void main() {
  final derivedLastChapter = <String, int>{};

  setUpAll(() {
    // Re-derive the table from the bundled assets, independently of the
    // committed `canonLastChapter` constant — if a Bible asset ever
    // changes chapter counts, this catches the drift instead of the
    // compiled-in table silently going stale.
    for (final asset in const [
      'assets/kjv.json',
      'assets/nasb.json',
      'assets/leb.json',
    ]) {
      final rows =
          jsonDecode(File(asset).readAsStringSync()) as List<dynamic>;
      for (final row in rows.cast<Map<String, dynamic>>()) {
        final chapter = int.tryParse('${row['chapter']}');
        if (chapter == null) continue;
        final book = row['book'] as String;
        if (chapter > (derivedLastChapter[book] ?? 0)) {
          derivedLastChapter[book] = chapter;
        }
      }
    }
  });

  test('the compiled-in table matches the three shipped Bibles exactly', () {
    expect(derivedLastChapter.length, 66);
    expect(canonLastChapter.length, 66);
    expect(canonLastChapter, derivedLastChapter,
        reason: 'lib/constants/canon_chapters.dart is generated from these '
            'assets — regenerate it if this fails');
    // Trivially checkable, so check them rather than trusting the
    // queue's prose: this is the fact that makes 232 and CP37 defects.
    expect(canonLastChapter['Amos'], 9);
    expect(canonLastChapter['Revelation'], 22);
    // The load-bearing claim behind a chapter-only (not verse-only)
    // table: all three shipped Bibles agree on all 1,189 chapter
    // boundaries — re-derived here, not copied from another test's
    // comment.
    expect(canonLastChapter.values.fold<int>(0, (a, b) => a + b), 1189);
  });

  test('chapterExistsInCanon rejects what the queue says it should', () {
    expect(chapterExistsInCanon('Amos', 9), isTrue);
    expect(chapterExistsInCanon('Amos', 12), isFalse);
    expect(chapterExistsInCanon('Revelation', 22), isTrue);
    expect(chapterExistsInCanon('Revelation', 37), isFalse);
    // An unrecognised book name fails open — this check has no
    // opinion about it, so it must not newly refuse something that
    // used to render fine.
    expect(chapterExistsInCanon('Not A Book', 1), isTrue);
  });

  test('232 and CP37 lose their underline in both Chinese locales', () {
    for (final locale in const ['zh-CN', 'zh-TW']) {
      final text232 =
          File('assets/sermons/$locale/232.txt').readAsStringSync();
      final matches232 = passageRefPattern
          .allMatches(text232)
          .where((m) {
        final r = parseReference(m.group(0)!);
        return r?.englishBook == 'Amos' && r?.chapter == 12;
      }).toList();
      expect(matches232, hasLength(1), reason: '232 $locale');
      final match232 = matches232.single;
      final ref232 = parseReference(match232.group(0)!)!;
      expect(chapterExistsInCanon(ref232.englishBook, ref232.chapter), isFalse,
          reason: '232 $locale: ${match232.group(0)}');

      final textCp37 =
          File('assets/sermons/$locale/CP37.txt').readAsStringSync();
      final matchesCp37 = passageRefPattern
          .allMatches(textCp37)
          .where((m) {
        final r = parseReference(m.group(0)!);
        return r?.englishBook == 'Revelation' && r?.chapter == 37;
      }).toList();
      expect(matchesCp37, hasLength(1), reason: 'CP37 $locale');
      final refCp37 = parseReference(matchesCp37.single.group(0)!)!;
      expect(refCp37.englishBook, 'Revelation');
      expect(refCp37.chapter, 37);
      expect(chapterExistsInCanon(refCp37.englishBook, refCp37.chapter),
          isFalse,
          reason: 'CP37 $locale: ${matchesCp37.single.group(0)}');

      // The nearby in-canon reference in the same sermon must NOT lose
      // its underline — a byte-level check that this fix didn't widen.
      final inCanon = passageRefPattern
          .allMatches(textCp37)
          .where((m) => parseReference(m.group(0)!)?.chapter == 3)
          .toList();
      expect(inCanon, isNotEmpty, reason: 'CP37 $locale: Revelation 3 cites');
      for (final m in inCanon) {
        final ref = parseReference(m.group(0)!)!;
        expect(chapterExistsInCanon(ref.englishBook, ref.chapter), isTrue,
            reason: '${m.group(0)} must stay tappable');
      }
    }
  });

  test(
      'sweep every passageRefPattern match over all 867 transcripts: '
      'exactly the 9 measured out-of-canon sites, nothing else changed class',
      () {
    final outOfCanon = <String>[];
    var totalMatches = 0;
    var totalParsed = 0;
    for (final locale in const ['en', 'zh-CN', 'zh-TW']) {
      final dir = Directory('assets/sermons/$locale');
      final files = dir.listSync().whereType<File>().where(
          (f) => f.path.endsWith('.txt')).toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      for (final file in files) {
        final text = file.readAsStringSync();
        for (final m in passageRefPattern.allMatches(text)) {
          totalMatches++;
          final matched = m.group(0)!;
          final parsed = parseReference(matched);
          if (parsed == null) continue;
          totalParsed++;
          if (!chapterExistsInCanon(parsed.englishBook, parsed.chapter)) {
            outOfCanon.add('${file.path}: "$matched" → '
                '${parsed.englishBook} ${parsed.chapter}');
          }
        }
      }
    }

    // Measured, not assumed — the queue's own comment in
    // passage_localizer.dart pins "9,650" matches, but that count is
    // Chinese-locale only (zh-CN + zh-TW; verified separately: 4,836 +
    // 4,814 = 9,650). Across all three locales (en + zh-CN + zh-TW,
    // 867 files) the real total is higher.
    expect(totalMatches, 12502,
        reason: 'total passageRefPattern matches across all 867 '
            'transcripts — pins the corpus this sweep covers');
    expect(totalParsed, 12473);

    // The queue named 4 out-of-canon sites (232 and CP37, ×2 Chinese
    // locales). The sweep found 9: the other 5 are English prose the
    // regex matches syntactically but was never a citation —
    // "Deuteronomy 43 [times]", "[Numbers.] 400 [prophets]" (a match
    // that spans a paragraph break — a separate, pre-existing
    // `passageRefPattern` defect, queued separately rather than fixed
    // here), and "I am 100/21 [years old]" (Amos's abbreviation "Am"
    // plus an unrelated number). All 5 were rendered as tappable,
    // underlined non-references before this fix; the same canon check
    // silently corrects them because 43/400/100/21 land outside every
    // one of those books' chapter counts. Reporting the real number
    // rather than quietly narrowing back to 4.
    expect(outOfCanon, unorderedEquals(<String>[
      'assets/sermons/en/004.txt: "Deuteronomy 43" → Deuteronomy 43',
      'assets/sermons/en/134.txt: "numbers.\n\n400" → Numbers 400',
      'assets/sermons/en/369.txt: "am 100" → Amos 100',
      'assets/sermons/en/369.txt: "am 100" → Amos 100',
      'assets/sermons/en/CP70.txt: "am 21" → Amos 21',
      'assets/sermons/zh-CN/232.txt: "阿摩司书第12章" → Amos 12',
      'assets/sermons/zh-TW/232.txt: "阿摩司書第12章" → Amos 12',
      'assets/sermons/zh-CN/CP37.txt: "启示录三十七章十七节" → Revelation 37',
      'assets/sermons/zh-TW/CP37.txt: "啓示錄三十七章十七節" → Revelation 37',
    ]));
  });
}
