import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Structural audit of the 梁家鏗譯本 (biblexg-v2 / -tr).
///
/// The defect this exists to catch: the publisher marks textually
/// doubtful passages with `<span class="affix"><sup>43</sup>…`, and our
/// importer flattened that superscript into body text. The result read
/// `…只要成就你的旨意。”43有一位使者從天上向他顯現…` — a stray "43" glued
/// into the sentence, and 路加福音 22:43 unfindable by reference. Three
/// affix spans hid five verses; two more were lost the same way in the
/// Traditional conversion.
///
/// 500+ green tests never noticed, because tests check that code runs,
/// not that data is true. So this one checks the data.
void main() {
  /// Every verse number with no entry of its own, and why. Three
  /// reasons, all legitimate: the publisher omits it as textually
  /// doubtful (each carries a footnote saying so), it is printed under
  /// a combined label like "1-4", or it is the one hole we know about
  /// and cannot honestly fill. A gap NOT on this list is a lost verse.
  const expectedGaps = <String, List<String>>{
    'assets/biblexg-v2.json': [
      '以弗所书 6: 20', '使徒行传 1: 22', '使徒行传 15: 34', '使徒行传 24: 7',
      '使徒行传 28: 29', '使徒行传 8: 37', '加拉太书 1: 2', '哥林多前书 15: 52',
      '哥林多后书 1: 14', '哥林多后书 13: 3', '希伯来书 6: 2', '提摩太前书 1: 19',
      '提摩太前书 2: 2', '歌罗西书 2: 21', '约翰一书 3: 20', '约翰二书 1: 2',
      '约翰福音 5: 4', '罗马书 15: 19', '路加福音 1: 2,3,4,75', '路加福音 17: 36',
      '路加福音 9: 31', '马可福音 11: 26', '马可福音 15: 28',
      // The one hole. 馬可福音 6:8-11 is missing from the publisher's own
      // Simplified webapp, which also truncates 6:7 mid-sentence at
      // 「並授予他們權能」. The printed Traditional 註釋本 has all five in
      // full and our Traditional matches it word for word, so the loss
      // is upstream and Simplified-only. Filling it needs the publisher
      // — see docs/梁家鏗譯本-請教出版方.md — not a 繁→简 guess. Pinning
      // it is what stops it spreading unnoticed.
      '马可福音 6: 8,9,10,11',
      '马太福音 17: 21', '马太福音 18: 11', '马太福音 23: 14',
    ],
    'assets/biblexg-v2-tr.json': [
      '以弗所書 6: 20', '使徒行傳 1: 22', '使徒行傳 15: 34', '使徒行傳 24: 7',
      '使徒行傳 28: 29', '使徒行傳 8: 37', '加拉太書 1: 2', '哥林多前書 15: 52',
      '哥林多後書 1: 14', '哥林多後書 13: 3', '希伯來書 6: 2', '提摩太前書 1: 19',
      '提摩太前書 2: 2', '歌羅西書 2: 21', '約翰一書 3: 20', '約翰二書 1: 2',
      '約翰福音 5: 4', '羅馬書 15: 19', '路加福音 1: 2,3,4,75', '路加福音 17: 36',
      '路加福音 9: 31', '馬可福音 11: 26', '馬可福音 15: 28', '馬太福音 17: 21',
      '馬太福音 18: 11', '馬太福音 23: 14',
    ],
  };

  List<Map<String, dynamic>> load(String path) =>
      (json.decode(File(path).readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();

  for (final path in expectedGaps.keys) {
    group('$path integrity', () {
      late List<Map<String, dynamic>> verses;

      setUpAll(() => verses = load(path));

      test('no verse number is stranded inside another verse', () {
        // `<note:…>` is stripped first: its scripture citations are full
        // of digits, and counting those is what once turned 5 defects
        // into a reported "117".
        final stranded = <String>[];
        for (final v in verses) {
          final text =
              (v['text'] as String).replaceAll(RegExp(r'<note:[^>]*>'), '');
          final hit = RegExp(r'(?<=[。”！？；、，])\d{1,3}[ab]?(?=[一-鿿“])')
              .firstMatch(text);
          if (hit != null) {
            stranded.add('${v['book']} ${v['chapter']}:${v['verse']}'
                ' swallowed ${hit.group(0)}');
          }
        }
        // 路加福音 23:33 still holds 34a. Splitting it needs a sub-verse
        // label — the 註釋本 prints 34a / 34b — and that changes a verse
        // id, so it is the user's call. See docs/autonomous-queue.md.
        expect(stranded, hasLength(1));
        expect(stranded.single, contains('23:33'));
        expect(stranded.single, contains('34a'));
      });

      test('every reference is unique and no verse is empty', () {
        final seen = <String>{};
        final duplicates = <String>[];
        final empties = <String>[];
        for (final v in verses) {
          final ref = '${v['book']} ${v['chapter']}:${v['verseLabel']}';
          if (!seen.add(ref)) duplicates.add(ref);
          if ((v['text'] as String).trim().isEmpty) empties.add(ref);
        }
        expect(duplicates, isEmpty);
        expect(empties, isEmpty);
      });

      test('no chapter has lost a verse', () {
        final byChapter = <String, Set<int>>{};
        for (final v in verses) {
          final key = '${v['book']} ${v['chapter']}';
          (byChapter[key] ??= <int>{})
              .add(int.parse(v['verse'] as String));
        }
        final gaps = <String>[];
        for (final entry in byChapter.entries) {
          final last = entry.value.reduce((a, b) => a > b ? a : b);
          final missing = [
            for (var n = 1; n <= last; n++)
              if (!entry.value.contains(n)) n
          ];
          if (missing.isNotEmpty) {
            gaps.add('${entry.key}: ${missing.join(',')}');
          }
        }
        expect(gaps..sort(), equals(expectedGaps[path]!.toList()..sort()));
      });
    });
  }

  test('the verses an affix once hid are addressable', () {
    for (final path in expectedGaps.keys) {
      final luke = {
        for (final v in load(path))
          if (v['book'].toString().endsWith('加福音'))
            '${v['chapter']}:${v['verse']}': v['text'] as String
      };
      expect(luke['22:43'], contains('使者'),
          reason: '$path — 路加福音 22:43, the angel in Gethsemane');
      expect(luke['22:44'], contains('汗珠如血'),
          reason: '$path — 路加福音 22:44, sweat like blood');
      expect(luke['23:17'], isNotNull, reason: '$path — 路加福音 23:17');
    }
  });

  test('羅馬書 3:10 still quotes the scripture it introduces', () {
    // The Simplified read only 「正如经上所记：」 and stopped. The publisher
    // sets the quotation as a poetry node with an EMPTY verseIndex, and
    // our importer kept only numbered nodes, so 「没有义人，一个也没有，」
    // never reached a reader. One such node exists in the publisher's
    // whole corpus, so this verse was the only casualty — counted, not
    // assumed. Restored from the publisher's own characters and checked
    // against the printed 註釋本; nothing here was written by hand.
    const wanted = {
      'assets/biblexg-v2.json': ['罗马书', '正如经上所记：没有义人，一个也没有，'],
      'assets/biblexg-v2-tr.json': ['羅馬書', '正如經上所記：沒有義人，一個也沒有，'],
    };
    wanted.forEach((path, want) {
      final verse = load(path).firstWhere((v) =>
          v['book'] == want[0] && v['chapter'] == '3' && v['verse'] == '10');
      expect((verse['text'] as String).replaceAll('\n', ''), want[1],
          reason: path);
    });
  });

  test('no verse body carries a critical-apparatus note', () {
    // 羅馬書 16:24 ended 「…兄弟也問候你們。按 NA28 及 UBS5，在此羅馬書完，
    // 但有抄本加插下面讚詞：」 — an editor's note about manuscripts, set as
    // though Paul had written it. Nothing looks wrong on screen, which is
    // exactly the danger: it reads plausibly and gets quoted.
    //
    // The publisher ships such notes as their own `type: "comment"` node,
    // and the printed 註釋本 prints this one as 「24-27節註：」. Our importer
    // already routes them to `blockNotes`, which renders in a separate
    // card below the verse; this one verse predated that and kept the
    // note inline. Counted across the corpus before fixing: exactly three
    // such notes exist, and the other two (馬可福音 16:8, 約翰福音 7:52)
    // were already correct — so this was the only casualty. The note was
    // moved, not rewritten; no scripture character changed.
    final apparatus = RegExp(
        r'節注：|节注：|按\s*NA28|參\s*NA28|参\s*NA28|UBS5|聯合聖經公會|联合圣经公会');
    // `<note:…>` is our own inline cross-reference markup and renders as a
    // popup, not as scripture, so it is stripped before looking.
    final inlineNote = RegExp(r'<note:.*?>');
    for (final path in expectedGaps.keys) {
      final offenders = [
        for (final v in load(path))
          if (apparatus.hasMatch((v['text'] as String).replaceAll(inlineNote, '')))
            '${v['book']} ${v['chapter']}:${v['verseLabel']}'
      ];
      expect(offenders, isEmpty,
          reason: '$path — apparatus text inside a verse body');
    }
  });

  test('no Simplified character survives in the Traditional edition', () {
    // Our Traditional is a conversion, and the conversion let a handful
    // of Simplified characters through: 使徒行傳 18:16 read 审判臺,
    // 羅馬書 10:8 read 這话, 提多書 2:3 read 纪律, 馬可福音 14:58 read
    // 拆毁 … 三天之内. Each was confirmed against the printed 註釋本 at
    // that verse before being changed — see tools/proofread_ljk_tr.py.
    //
    // Only characters with no Traditional reading at all are listed.
    // 温, 説, 着 and 满 are NOT here: the printed edition itself uses
    // them, and conforming to it outranks tidiness.
    const simplifiedOnly = '审话纪毁内劝议护辞对顿颠';
    // The printed 註釋本 sets 提多書 3:15 as 「在信仰内愛我們的各位」 —
    // Simplified 内, in the publisher's own Traditional edition. We
    // match it, and conforming to the printed text is the standing
    // instruction even where it looks like a slip. Asked in
    // docs/梁家鏗譯本-請教出版方.md; pinned here so it cannot spread.
    const printedItselfReadsSimplified = {'提多書 3:15 — 内'};
    final offenders = <String>[];
    for (final v in load('assets/biblexg-v2-tr.json')) {
      for (final c in simplifiedOnly.split('')) {
        if ((v['text'] as String).contains(c)) {
          offenders.add('${v['book']} ${v['chapter']}:${v['verseLabel']} — $c');
        }
      }
    }
    expect(offenders.toSet(), printedItselfReadsSimplified);
  });

  test('the Traditional still has the 馬可福音 6 that the Simplified lost', () {
    final mark6 = {
      for (final v in load('assets/biblexg-v2-tr.json'))
        if (v['book'] == '馬可福音' && v['chapter'] == '6')
          v['verse'] as String: v['text'] as String
    };
    expect(mark6['7'], endsWith('制服不潔的靈。'),
        reason: 'the Simplified truncates 6:7 at 並授予他們權能');
    expect(mark6['8'], contains('只帶一根手杖'));
    expect(mark6['11'], contains('把腳上的塵土跺落'));
  });
}
