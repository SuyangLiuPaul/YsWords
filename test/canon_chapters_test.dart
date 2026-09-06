import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:yswords/constants/canon_chapters.dart';
import 'package:yswords/utils/passage_localizer.dart';
import 'package:yswords/utils/reference_parser.dart';

/// `canonLastChapter` is the chapter-level canon check. Originally wired
/// only into the sermon body (`lib/pages/sermon_detail_page.dart`
/// `_buildSpans` and `_openPassagePopup`) so a transcription slip like
/// sermon 232's "阿摩司书第12章" (Amos has 9 chapters) or CP37's
/// "启示录三十七章十七节" (Revelation has 22) rendered as plain text
/// instead of a tappable, underlined promise of scripture that isn't
/// there — see `docs/autonomous-queue.md` line 7008.
///
/// 2026-08-31: moved into `parseReference`/`_buildRef` itself (queue
/// line 7042), after a corpus-wide sweep (60,426 parsed strings across
/// the 9 curated JSON assets, 12,502 `passageRefPattern` matches across
/// all 867 sermon transcripts) found no case where refusing an
/// out-of-canon chapter falls through to a DIFFERENT, still-wrong
/// reference — every caller passes the book part as a prefix of the
/// full input, so `parseReference`'s later patterns and its final
/// bare-book-name fallback re-run against the same full string
/// (chapter digits still attached) and fail to match. `parseReference`
/// now returns `null` for these two sites directly; the sermon page's
/// own `chapterExistsInCanon` checks are now redundant but harmless
/// (defence in depth against a future caller of `_buildRef` that
/// doesn't go through `parseReference`).
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

  test('232 and CP37 refuse to parse in both Chinese locales', () {
    // Identified by the exact matched text rather than by filtering on
    // `parseReference`'s result — that result is now null for both, so
    // a filter that reads it would find zero matches instead of one.
    const known232 = {'zh-CN': '阿摩司书第12章', 'zh-TW': '阿摩司書第12章'};
    // 2026-09-05: the Traditional spelling moved 啓→啟 when
    // `assets/sermons/zh-TW/` was normalised to the printed 和合本
    // (啟 425, 啓 0 in `assets/cuvs-yhwh-tr.json`). Revelation still has
    // 22 chapters, so this still refuses to parse — the glyph changed,
    // the verdict did not. Pinned by exact text on purpose, which is why
    // it had to be edited here rather than silently keeping up.
    const knownCp37 = {
      'zh-CN': '启示录三十七章十七节',
      'zh-TW': '啟示錄三十七章十七節',
    };
    for (final locale in const ['zh-CN', 'zh-TW']) {
      final text232 =
          File('assets/sermons/$locale/232.txt').readAsStringSync();
      final matches232 = passageRefPattern
          .allMatches(text232)
          .map((m) => m.group(0)!)
          .where((s) => s == known232[locale])
          .toList();
      expect(matches232, hasLength(1), reason: '232 $locale');
      expect(parseReference(matches232.single), isNull,
          reason: '232 $locale: ${matches232.single} — Amos has 9 chapters');

      final textCp37 =
          File('assets/sermons/$locale/CP37.txt').readAsStringSync();
      final matchesCp37 = passageRefPattern
          .allMatches(textCp37)
          .map((m) => m.group(0)!)
          .where((s) => s == knownCp37[locale])
          .toList();
      expect(matchesCp37, hasLength(1), reason: 'CP37 $locale');
      expect(parseReference(matchesCp37.single), isNull,
          reason: 'CP37 $locale: ${matchesCp37.single} — Revelation has '
              '22 chapters');

      // The nearby in-canon reference in the same sermon must NOT lose
      // its ability to parse — a check that this fix didn't widen.
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
      'sweep every passageRefPattern match over all 1117 transcripts: '
      'exactly the 9 known out-of-canon sites stopped parsing',
      () {
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
          if (parseReference(m.group(0)!) != null) totalParsed++;
        }
      }
    }

    // Measured, not assumed. Before this guard (queue line 7008):
    // 12,502 matches, 12,473 parsed — 9 of those out-of-canon but still
    // returned as a live `BibleReference`. `totalMatches` is unaffected
    // by this guard (it only changes what `parseReference` does with an
    // already-found match); `totalParsed` dropping by EXACTLY 9 — not
    // more, not fewer — is the proof that the guard caught precisely
    // the 9 known out-of-canon matches and nothing else. A regression
    // that made some OTHER, previously-parseable match newly fail (a
    // fallthrough side effect, or the guard catching something
    // unmeasured) would move this number past 12464 in either
    // direction; a regression that let one of the 9 through would
    // leave it at 12473.
    //
    // Deliberately not asserted as "no new null besides these 9",
    // because the corpus already has ~20 matches that never parsed for
    // unrelated reasons (numbered books cited without their leading
    // digit, e.g. `passageRefPattern` catching "Corinthians 5:21" out
    // of a transcript that actually reads "1 Corinthians 5:21") — a
    // blanket null-check would flag all of those as "new" on every run
    // and prove nothing about this guard specifically.
    // +3201 on 2026-09-06: the corpus went from 289 sermons to 414 when
    // 125 of Pastor Eric's messages were merged in from the fuyindiantai
    // staging library and 51 machine-translated bodies were replaced by
    // that library's human text. 867 transcript files became 1117 — 414
    // zh-CN, 414 zh-TW and still 289 English, because the library is
    // Chinese-only. The gap between the two totals is what carries the
    // argument and it moved by TWO, from 32 to 34, so both are asserted:
    // see the note on `totalParsed`.
    expect(totalMatches, 15729,
        reason: 'total passageRefPattern matches across all 1117 '
            'transcripts — pins the corpus this sweep covers. 12498 '
            'before queue-7296 (約拿記/约拿记 + 哥罗西书 added to the alias '
            'table and the pattern): 7 more matches, 6 for 約拿記/约拿记 in '
            'sermon 069 and 1 for 哥罗西书 in EC013, all previously '
            'unmatched prose. +23 on 2026-09-05: sermons 100, 369 and '
            '370 shipped a TRUNCATED Traditional translation (100: 6 331 '
            'characters against a Simplified 18 304) and were rebuilt from '
            'their Simplified bodies, so ~38 000 characters of transcript '
            'this sweep had never seen came into scope, carrying 23 more '
            'references with them.');
    // 12 496 = 12 473 + 23 — the SAME delta as totalMatches above, which
    // is the whole point of pinning both. Every one of the 23 references
    // the rebuilt bodies brought in parses; the rebuild introduced no new
    // out-of-canon site, and the gap between the two totals is still
    // exactly the 32 that were already known.
    // 15 695 = 15 729 − 34. The gap grew from 32 to 34 and BOTH new
    // members were read before this number was written: they are one
    // reading, in both scripts, in fy-nm10 — 「“住”字（menō）在約翰福音
    // 出現了40次，約翰一書24次」. That is a word COUNT, not a chapter, and
    // 1 John has five chapters, so `parseReference` refusing it is the
    // guard working rather than failing. It came in verbatim with the
    // library text and is not something this repo introduced. Every other
    // reference the 125 merged sermons brought in parses.
    expect(totalParsed, 15695,
        reason: '12464 before queue-7296: +7, matching the 7 new '
            'matches above — Jonah 2 and Colossians 1:19 are both '
            'in-canon, so every new match parses. +2 more on 2026-09-03: '
            '331\'s 「诗篇一一九篇103节」 in both Chinese bodies, which '
            'passageRefPattern already matched and cnNumber refused '
            'until it learned to read a run of three or more bare '
            'digits as 119. totalMatches is unchanged, because the '
            'pattern was not touched.');
  });

  test(
      'the 9 curated JSON assets that feed the other 15 `parseReference` '
      'call sites hold nothing out-of-canon',
      () {
    // Every string value in these assets — not just the fields callers
    // actually read as citations — so this catches a reference hiding
    // in a field none of today's 30 call sites happens to use yet.
    // Covers `bible_evidence.json`, `bible_timeline.json`,
    // `cross_references.json`, `family_tree.json`,
    // `gospel_synopsis.json`, `misconceptions.json`, `daily_verses.json`,
    // `book_introductions.json` and `section_titles.json` — the assets
    // named in `docs/autonomous-queue.md` line 7042's file list.
    void walk(dynamic node, void Function(String) onString) {
      if (node is String) {
        onString(node);
      } else if (node is Map) {
        for (final v in node.values) {
          walk(v, onString);
        }
      } else if (node is List) {
        for (final v in node) {
          walk(v, onString);
        }
      }
    }

    var parsedCount = 0;
    final outOfCanon = <String>[];
    final seen = <String>{};
    for (final asset in const [
      'assets/bible_evidence.json',
      'assets/bible_timeline.json',
      'assets/cross_references.json',
      'assets/family_tree.json',
      'assets/gospel_synopsis.json',
      'assets/misconceptions.json',
      'assets/daily_verses.json',
      'assets/book_introductions.json',
      'assets/section_titles.json',
    ]) {
      final data = jsonDecode(File(asset).readAsStringSync());
      walk(data, (s) {
        final trimmed = s.trim();
        if (trimmed.isEmpty || trimmed.length > 200) return;
        void check(String text, BibleReference? ref) {
          if (ref == null || !seen.add('$asset|||$text')) return;
          parsedCount++;
          if (!chapterExistsInCanon(ref.englishBook, ref.chapter)) {
            outOfCanon.add('$asset: "$text" → ${ref.englishBook} '
                '${ref.chapter}');
          }
        }

        check(trimmed, parseReference(trimmed));
        for (final seg in splitCitation(trimmed)) {
          check(seg.text, seg.target);
        }
      });
    }

    // Measured 2026-08-31: 60,426 distinct (asset, string) pairs parse
    // to a reference. Pinned so a future asset addition that introduces
    // an out-of-canon reference — rather than this guard regressing —
    // is what makes this test fail.
    expect(parsedCount, 60426);
    expect(outOfCanon, isEmpty,
        reason: 'a reference here would have rendered as a live tap '
            'target to scripture that does not exist, on every one of '
            'the 15 non-sermon call sites — see queue line 7042');
  });
}
