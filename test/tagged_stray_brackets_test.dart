import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/services/tagged_text_service.dart';

/// The word-tap corpus printed brackets that are not in this Bible.
///
/// `assets/tagged/cuvs-yhwh/` is rendered verbatim by `originals_sheet.dart`
/// in place of the reader's verse, so 詩篇 115:17 read 「死人不能)讚美雅偉」,
/// 馬可福音 15:13 opened on a bare 「)」 and 利未記 11:7 read
/// 「因為{蹄分兩瓣」. Fourteen verses in all, and every one was on screen for
/// a reader of the Simplified 和合本雅偉版 — `coversVerse` compares
/// ideographs, so the guard that hides a tagged line which has LOST a word
/// cannot see a character that was never in the verse. Only that one version
/// is tagged, so a Traditional reader was never affected.
///
/// The rule is measured, not chosen — `(`, `)`, `{` and `}` occur zero times
/// in the 62,204 verses of the two reading assets, so in the second
/// transcription they are import damage. 創世記 48:7's balanced ASCII pair is
/// converted rather than deleted, and not because every witness agrees on the
/// mark — git blob `7a2dc43`, an import unrelated to the shipped files, sets
/// this gloss `〈以法他就是伯利恆〉`, and the printed 1919 brackets it not at
/// all. What settles it is narrower: this run is rendered in place of
/// `cuvs-yhwh.json`'s line, and both shipped reading assets write `（）` here.
///
/// Two more verses had the mirror fault — importer markup that had swallowed
/// a real character, so the tagged corpus was MISSING scripture. 耶利米書
/// 4:22 read 「不認識；」 for 「不認識我；」 and 歷代志上 21:17 read
/// 「數點百姓不是我嗎」 for 「數點百姓的不是我嗎」. Both were dropped whole by
/// `carriesImporterMarkup`, so no reader saw the markup — the cost was the
/// word-tap gesture on two verses, and an asset that was wrong.
///
/// `tools/repair_tagged_stray_brackets.py` and the `SWALLOWED_PLACEMENT`
/// table in `tools/repair_tagged_markup.py` apply the two halves.
void main() {
  final files = Directory('assets/tagged/cuvs-yhwh')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  Map<String, List<TaggedRun>> load(String slug) {
    final file = files.firstWhere((f) => f.path.endsWith('/$slug.json'));
    final decoded = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
    return decoded.map((ref, runs) => MapEntry(
          ref,
          (runs as List)
              .map((r) => TaggedRun.fromJson(r as Map<String, dynamic>))
              .toList(growable: false),
        ));
  }

  String verse(String slug, String ref) =>
      load(slug)[ref]!.map((r) => r.text).join();

  test('no ASCII bracket survives anywhere in the word-tap corpus', () {
    expect(files, hasLength(66));
    final offenders = <String>[];
    for (final file in files) {
      final slug = file.uri.pathSegments.last.replaceAll('.json', '');
      final decoded =
          json.decode(file.readAsStringSync()) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        final text =
            (entry.value as List).map((r) => (r as Map)['w'] as String).join();
        if (text.contains(RegExp(r'[(){}]'))) {
          offenders.add('$slug ${entry.key}');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'the reading assets use none of ( ) { } in 62,204 verses, so '
            'these are import damage printed as scripture: '
            '${offenders.join(', ')}');
  });

  test('the CUV variant brackets pair, apart from the one that spans verses',
      () {
    var open = 0;
    var close = 0;
    final unbalanced = <String>[];
    for (final file in files) {
      final slug = file.uri.pathSegments.last.replaceAll('.json', '');
      final decoded =
          json.decode(file.readAsStringSync()) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        final text =
            (entry.value as List).map((r) => (r as Map)['w'] as String).join();
        final o = '〔'.allMatches(text).length;
        final c = '〕'.allMatches(text).length;
        open += o;
        close += c;
        if (o != c) unbalanced.add('$slug ${entry.key}');
      }
    }
    expect(open, close,
        reason: '路加福音 8:45 was the only unmatched 〔 in the corpus; its '
            'note was closed by an ASCII ) instead of 〕');
    // 使徒行傳 28:28 opens 〔有古卷在此有 and 28:29 closes it — the CUV's own
    // way of bracketing a variant that is a whole verse.
    expect(unbalanced, ['acts 28:28', 'acts 28:29']);
    expect(verse('luke', '8:45'), endsWith('你还问摸我的是谁吗？"〕'));
  });

  test('創世記 48:7 sets its gloss in the brackets this edition uses', () {
    expect(verse('genesis', '48:7'), contains('（以法他就是伯利恒）'));
  });

  test('the swallowed characters are back in the clause the verse puts them in',
      () {
    expect(verse('jeremiah', '4:22'), contains('不认识我；'));
    expect(verse('jeremiah', '4:22'), contains('愚昧无知的儿女'));
    expect(verse('1_chronicles', '21:17'), contains('数点百姓的不是我吗'));
    expect(verse('1_chronicles', '21:17'), contains('行了恶，但这群羊'));
  });

  test('the runs left holding a number and no word are counted', () {
    // Deleting a stray bracket that WAS a whole run leaves the run empty —
    // 耶利米書 38:16's `}` was run 17, tagged H1245, and 利未記 11:7's `{`
    // was run 2, tagged H1931. Ten such runs already shipped: the importer
    // numbered a Hebrew word this translation does not render. The numbers
    // are kept rather than thrown away in a repair pass, and
    // `_taggedVerseLine` skips empty runs so none of the twelve can render
    // as a zero-width span with a tap recognizer on it. This pins the data;
    // growth here means a new import is dropping words.
    final empty = <String>[];
    for (final file in files) {
      final slug = file.uri.pathSegments.last.replaceAll('.json', '');
      final decoded =
          json.decode(file.readAsStringSync()) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        for (final run in (entry.value as List).cast<Map>()) {
          if ((run['w'] as String).isEmpty) empty.add('$slug ${entry.key}');
        }
      }
    }
    expect(empty, hasLength(12));
    expect(empty, containsAll(<String>['jeremiah 38:16', 'leviticus 11:7']));
  });

  test('and so both verses now reach the word-tap sheet', () {
    final reading = <String, String>{};
    for (final row
        in (json.decode(File('assets/cuvs-yhwh.json').readAsStringSync())
            as List)
            .cast<Map<String, dynamic>>()) {
      reading['${row['book']} ${row['chapter']}:${row['verse']}'] =
          row['text'] as String;
    }
    expect(
        TaggedTextService.coversVerse(
            load('jeremiah')['4:22']!, reading['耶利米书 4:22']!),
        isTrue);
    expect(
        TaggedTextService.coversVerse(
            load('1_chronicles')['21:17']!, reading['历代志上 21:17']!),
        isTrue);
  });
}
