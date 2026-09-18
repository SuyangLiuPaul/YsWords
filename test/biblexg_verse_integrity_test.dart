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
    // v3 is the 梁简 edition a reader can actually select — v2 is the
    // hidden/superseded snapshot (bible_versions.dart:378-402). Same 24
    // publisher-side gaps as v2, minus 馬可福音 6:8-11 (restored, commit
    // `3cefcab7`), plus two that are NOT losses: 哥林多後書 13:3,13 (v3's
    // own 12-14節註 says verse 12 absorbs the old-13 clause, and the
    // publisher's cn-2co.json has no 13/14 split either — a renumbering,
    // not our importer dropping text) and 腓立比書 1:2 (v3's verse "1" is
    // the publisher's cn-phi.json verseIndex 1+2 concatenated verbatim;
    // text is fully present, only the combined label has no entry of
    // its own).
    // 2026-09-18: 約翰福音 5:4 is no longer a gap in v3. 梁牧師 ruled
    // (ruling 五) that it is printed as bracketed body text, from his own
    // note on 5:3, like 馬太福音 21:44 — tools/apply_ljk_2026_09_17.py.
    'assets/biblexg-v3.json': [
      '以弗所书 6: 20', '使徒行传 1: 22', '使徒行传 15: 34', '使徒行传 24: 7',
      '使徒行传 28: 29', '使徒行传 8: 37', '加拉太书 1: 2', '哥林多前书 15: 52',
      '哥林多后书 1: 14', '哥林多后书 13: 3,13', '希伯来书 6: 2',
      '提摩太前书 1: 19', '提摩太前书 2: 2', '歌罗西书 2: 21', '约翰一书 3: 20',
      '约翰二书 1: 2', '罗马书 15: 19', '腓立比书 1: 2',
      '路加福音 1: 2,3,4,75', '路加福音 17: 36', '路加福音 9: 31',
      '马可福音 11: 26', '马可福音 15: 28', '马太福音 17: 21',
      '马太福音 18: 11', '马太福音 23: 14',
    ],
    'assets/biblexg-v3-tr.json': [
      '以弗所書 6: 20', '使徒行傳 1: 22', '使徒行傳 15: 34', '使徒行傳 24: 7',
      '使徒行傳 28: 29', '使徒行傳 8: 37', '加拉太書 1: 2', '哥林多前書 15: 52',
      '哥林多後書 1: 14', '哥林多後書 13: 3,13', '希伯來書 6: 2',
      '提摩太前書 1: 19', '提摩太前書 2: 2', '歌羅西書 2: 21', '約翰一書 3: 20',
      '約翰二書 1: 2',  '羅馬書 15: 19', '腓立比書 1: 2',
      '路加福音 1: 2,3,4,75', '路加福音 17: 36', '路加福音 9: 31',
      '馬可福音 11: 26', '馬可福音 15: 28', '馬太福音 17: 21',
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
        // 2026-09-02: this used to assert hasLength(1) and pin 路加福音
        // 23:33's swallowed `34a` as a known, user-gated defect. The user
        // ruled (「34a这些能够也做成像经文可以选择的节吗」), 23:33 was split,
        // and 34a is now a verse of its own — so the expected count is
        // zero and this test is back to meaning what its name says.
        // tools/repair_biblexg_luke_23_34a.py re-applies the split after
        // the Traditional rebuild; test/luke_23_34a_test.dart pins the
        // result. If this ever fails at 1 again, that rebuild ran without
        // the repair.
        expect(stranded, isEmpty);
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
    //
    // v3 (the edition a reader can actually select) re-lost the same
    // clause; the v3 fetch re-ran the importer against the same
    // empty-verseIndex node in the publisher's cn-rom.json, and the fix
    // is the same restoration, by the same characters.
    const wanted = {
      'assets/biblexg-v2.json': ['罗马书', '正如经上所记：没有义人，一个也没有，'],
      'assets/biblexg-v2-tr.json': ['羅馬書', '正如經上所記：沒有義人，一個也沒有，'],
      'assets/biblexg-v3.json': ['罗马书', '正如经上所记：没有义人，一个也没有，'],
      'assets/biblexg-v3-tr.json': ['羅馬書', '正如經上所記：沒有義人，一個也沒有，'],
    };
    wanted.forEach((path, want) {
      final verse = load(path).firstWhere((v) =>
          v['book'] == want[0] && v['chapter'] == '3' && v['verse'] == '10');
      expect((verse['text'] as String).replaceAll('\n', ''), want[1],
          reason: path);
    });
  });

  test('約翰福音 12:36 still ends with the half-verse both editions lost', () {
    // 12:36b 「耶穌說完了這些話，便離開他們，隱藏起來了。」 was buried in the
    // note card under the 31節註 footnote, so the verse stopped at
    // 「使你們成為光明之子。」 and the missing sentence read as the editor's.
    //
    // Both editions lost it identically, which is why the cross-edition
    // length check below cannot see it, and why it is pinned by name. A
    // corpus-wide form would have to read the publisher's source, which
    // a test does not have — see tools/import_ljk2.py, where the cause
    // is fixed: a comment node's `{lineBreak, content}` dicts are body,
    // not footnote, and exactly two exist in the publisher's corpus.
    //
    // v3 re-lost the same two clauses (12:36b here, 4:16b below) the same
    // way — the fetch that built it re-ran into the same importer hole.
    // Restored by moving the clause out of blockNotes and back onto the
    // verse; no character invented. The publisher's own text has a stray
    // space in 12:36b's Simplified — 「隱藏起來 了。」 — that neither our
    // v2.json nor the printed 註釋本 carries; closed up here to match
    // both, and to match the Traditional (which the publisher never had
    // the space bug in to begin with).
    const wanted = {
      'assets/biblexg-v2.json': ['约翰福音', '耶稣说完了这些话，便离开他们，隐藏起来了。'],
      'assets/biblexg-v2-tr.json': ['約翰福音', '耶穌說完了這些話，便離開他們，隱藏起來了。'],
      'assets/biblexg-v3.json': ['约翰福音', '耶稣说完了这些话，便离开他们，隐藏起来了。'],
      // 2026-09-17: the translator revised his Traditional to end
      // 「隱藏起來。」; the Simplified still has 了.
      'assets/biblexg-v3-tr.json': ['約翰福音', '耶穌說完了這些話，便離開他們，隱藏起來。'],
    };
    wanted.forEach((path, want) {
      final verse = load(path).firstWhere((v) =>
          v['book'] == want[0] && v['chapter'] == '12' && v['verse'] == '36');
      expect(verse['text'] as String, endsWith(want[1]), reason: path);
      expect((verse['blockNotes'] as List).join(), isNot(contains(want[1])),
          reason: '$path — scripture is still sitting in a note card');
    });
  });

  test('約翰一書 4:16 still ends with the half-verse the Simplified lost', () {
    // 4:16b 「神就是愛，那住在愛裡的，就住在神裡面，神也住在他裡面。」 was the
    // other half of the same defect as 約翰福音 12:36b above — glued to the
    // end of the 13節註 footnote in a comment node, so it read as the
    // editor's aside rather than as John's sentence. Simplified-only in
    // both v2 and v3: the Traditional never lost it (see
    // tools/import_ljk2.py — the `tw-*.json` source feeding it is not the
    // node type that carried the bug).
    const wanted = {
      'assets/biblexg-v2.json': ['约翰一书', '神就是爱，那住在爱里的，就住在神里面，神也住在他里面。'],
      'assets/biblexg-v3.json': ['约翰一书', '神就是爱，那住在爱里的，就住在神里面，神也住在他里面。'],
    };
    wanted.forEach((path, want) {
      final verse = load(path).firstWhere((v) =>
          v['book'] == want[0] && v['chapter'] == '4' && v['verse'] == '16');
      expect(verse['text'] as String, endsWith(want[1]), reason: path);
      expect((verse['blockNotes'] as List?)?.join() ?? '',
          isNot(contains(want[1])),
          reason: '$path — scripture is still sitting in a note card');
    });
    // The Traditional never had the defect — assert it still doesn't,
    // and that it carries the same clause the Simplified now does.
    const traditionalWant = '神就是愛，那住在愛裡的，就住在神裡面，神也住在他裡面。';
    for (final path in ['assets/biblexg-v2-tr.json', 'assets/biblexg-v3-tr.json']) {
      final verse = load(path).firstWhere((v) =>
          v['book'] == '約翰一書' && v['chapter'] == '4' && v['verse'] == '16');
      expect(verse['text'] as String, endsWith(traditionalWant), reason: path);
    }
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

  test('the two editions carry the same amount of scripture per verse', () {
    // 約翰一書 4:16 read 「而神對我們的愛，我們已經明白，而且相信了。」 in
    // the Traditional and stopped one clause earlier in the Simplified:
    // 「神就是愛，那住在愛裡的，就住在神裡面，神也住在他裡面。」 was sitting
    // in a note card, glued to the end of the 13節註 footnote, where it
    // read as the editor's aside rather than as John's sentence. Both
    // editions lost 約翰福音 12:36b 「耶穌說完了這些話，便離開他們，隱藏
    // 起來了。」 the same way.
    //
    // Cause: a `type: "comment"` node's `contents` mixes plain footnote
    // strings with `{lineBreak, content}` dicts, and the dicts are the
    // preceding verse's own body. Our importer read both as footnote.
    // Exactly two such nodes exist in the publisher's whole corpus.
    //
    // The two editions are the same translation, so a verse should be
    // the same length in both give or take a character of punctuation.
    // Every reference that is not is listed with its reason, and a
    // clause going missing from one side lands far outside this bound.
    const knownDifferences = <String, String>{
      // Upstream: the publisher's own Simplified drops scripture the
      // printed Traditional 註釋本 has. Asked in the publisher letter;
      // filling either from the other side would be writing scripture.
      '提摩太后书 3:15': '简体缺「而且你自幼便明白神聖的經典，」',
      '马可福音 6:7': '简体在「並授予他們權能」处截断，缺「制服不潔的靈」',
      // The publisher's OWN Traditional sets a short editorial gloss as
      // body text where their Simplified marks it up as a note. Measured
      // against their `tw-*.json` rather than inferred from this diff —
      // see tools/audit_biblexg_notes.py. Not ours to reconcile.
      '马太福音 9:14': '繁体正文含「通常每逢週一週四」，简体无',
      '马太福音 27:48': '繁体正文含「士兵解渴的飲料」，简体作注',
      '马太福音 26:29': '繁体正文含「即葡萄酒」，简体作注',
      '使徒行传 8:41': '繁体正文含「即向北沿海」，简体作注',
      '路加福音 9:5': '繁体正文含「作為警告」，简体作注「意即警告」',
      // Wording: the two official editions differ, pending the publisher.
      '彼得后书 2:21': '用词不同',
      '哥林多后书 5:8': '用词不同',
      '使徒行传 20:4': '用词不同',
      '腓立比书 2:3': '用词不同',
      '马可福音 7:15': '用词不同',
      '罗马书 12:6': '用词不同',
    };
    final inlineNote = RegExp(r'<note:.*?>');
    String body(Map<String, dynamic> v) =>
        (v['text'] as String).replaceAll(inlineNote, '');
    final cn = {for (final v in load('assets/biblexg-v2.json')) v['id']: v};
    final tr = {for (final v in load('assets/biblexg-v2-tr.json')) v['id']: v};

    final offenders = <String>[];
    for (final entry in cn.entries) {
      final other = tr[entry.key];
      if (other == null) continue;
      final delta = body(entry.value).length - body(other).length;
      if (delta.abs() <= 3) continue;
      final ref = '${entry.value['book']} '
          '${entry.value['chapter']}:${entry.value['verseLabel']}';
      if (!knownDifferences.containsKey(ref)) offenders.add('$ref ($delta)');
    }
    expect(offenders, isEmpty,
        reason: 'a verse differs in length between the two editions by more '
            'than punctuation — one side may have lost a clause');
  });

  test('the selectable v3 pair carries the same amount of scripture per verse',
      () {
    // Same audit as the v2 pair above, run against v3/v3-tr — the editions
    // a reader can actually select. `ff226ddc` only added v3 to
    // expectedGaps and fixed three verses by name; the set test itself
    // was never ported. Re-derived at HEAD, not carried forward: 14
    // offenders, not the queue's stale carried-forward 16.
    const knownDifferences = <String, String>{
      // Carried from the v2/v2-tr table above; reasons are the
      // publisher's, not re-litigated here. 馬可福音 6:7 is not carried —
      // v3 restored it (commit `3cefcab7`, guarded by the test below).
      '提摩太后书 3:15': '简体缺「而且你自幼便明白神聖的經典，」',
      '马太福音 9:14': '繁体正文含「通常每逢週一週四」，简体无',
      '马太福音 27:48': '繁体正文含「士兵解渴的飲料」，简体作注',
      '马太福音 26:29': '繁体正文含「即葡萄酒」，简体作注',
      // v2's '使徒行传 8:41' — v3's versification carries the same
      // clause one verse earlier. Not chased further here; filed as a
      // by-product in the queue.
      '使徒行传 8:40': '繁体正文含「即向北沿海」，简体作注',
      '路加福音 9:5': '繁体正文含「作為警告」，简体作注「意即警告」',
      '彼得后书 2:21': '用词不同',
      '哥林多后书 5:8': '用词不同',
      '使徒行传 20:4': '用词不同',
      '腓立比书 2:3': '用词不同',
      '马可福音 7:15': '用词不同',
      '罗马书 12:6': '用词不同',
      // Not carried from v2 — checked directly against the publisher's
      // own source files (~/.cache/yswords/ljk-source/cn-rev.json,
      // tw-rev.json, chapter 5): their Simplified source ends verse 9
      // with 「使他们成为」; their Traditional source starts verse 10
      // with the same clause instead. Our v3 pair reproduces each
      // source's own boundary exactly — the publisher's two editions
      // disagree with each other, the same class as 馬可福音 6:7-11 and
      // 提摩太後書 3:15. Not ours to move; filed in
      // docs/梁家鏗譯本-請教出版方.md.
      '启示录 5:9': '两份官方来源就此边界互相不一致，各自照录',
      '启示录 5:10': '两份官方来源就此边界互相不一致，各自照录',
    };
    final inlineNote = RegExp(r'<note:.*?>');
    String body(Map<String, dynamic> v) =>
        (v['text'] as String).replaceAll(inlineNote, '');
    final cn = {for (final v in load('assets/biblexg-v3.json')) v['id']: v};
    final tr = {for (final v in load('assets/biblexg-v3-tr.json')) v['id']: v};

    final offenders = <String>[];
    for (final entry in cn.entries) {
      final other = tr[entry.key];
      if (other == null) continue;
      final delta = body(entry.value).length - body(other).length;
      if (delta.abs() <= 3) continue;
      final ref = '${entry.value['book']} '
          '${entry.value['chapter']}:${entry.value['verseLabel']}';
      if (!knownDifferences.containsKey(ref)) offenders.add('$ref ($delta)');
    }
    expect(offenders, isEmpty,
        reason: 'a verse differs in length between the v3 pair by more '
            'than punctuation — one side may have lost a clause');
  });

  test(
      'the selectable v3 pair disagrees about a note in a pinned set of '
      'verses', () {
    // Same audit as the v2 pair's note-count test below, run against
    // v3/v3-tr. Re-derived at HEAD: 73 verses, of which 30 carry across
    // from the v2 set (使徒行传 8:41 and 路加福音 9:17 do not — v3 either
    // renumbers or no longer disagrees there) and 43 are NEW to v3 and
    // have not been checked against the publisher yet.
    //
    // Pinned as an OBSERVED baseline, not an adjudicated one — unlike
    // the v2 set below, most of this list has not been run through
    // tools/audit_biblexg_notes.py. A future importer change should
    // show up here as a new reference, not silently. The 43 unchecked
    // ones are filed as a queue item; their presence in this set means
    // "seen", not "cleared".
    const knownNoteDifferences = <String>{
      // The 30 that carry across from the v2/v2-tr set below.
      '马太福音 10:8', '马太福音 13:21', '马太福音 22:45', '马太福音 26:29',
      '马太福音 27:48', '路加福音 6:3', '路加福音 9:46', '路加福音 10:5',
      '路加福音 19:38', '约翰福音 1:18', '约翰福音 6:45', '使徒行传 8:5',
      '罗马书 8:29', '罗马书 11:2', '罗马书 11:27', '罗马书 12:6',
      '哥林多前书 6:11', '哥林多前书 15:27', '哥林多后书 6:17',
      '哥林多后书 6:18', '以弗所书 2:8', '以弗所书 3:12', '以弗所书 4:25',
      '以弗所书 6:3', '歌罗西书 3:10', '帖撒罗尼迦前书 5:19',
      '提摩太后书 3:15', '启示录 3:1', '启示录 8:12', '启示录 12:17',
      // The 43 new to v3 — unadjudicated, see the queue item this test
      // files them under.
      '使徒行传 2:16', '使徒行传 3:13', '使徒行传 3:21', '使徒行传 5:37',
      '使徒行传 12:2', '使徒行传 13:6', '使徒行传 13:14', '使徒行传 20:32',
      '加拉太书 3:7', '加拉太书 3:9', '启示录 5:10', '启示录 5:12',
      '启示录 8:7', '哥林多前书 10:16', '哥林多前书 13:2', '哥林多前书 13:8',
      '哥林多前书 14:1', '哥林多后书 5:8', '希伯来书 10:26',
      '帖撒罗尼迦前书 3:2', '帖撒罗尼迦后书 2:7', '帖撒罗尼迦后书 2:8',
      '歌罗西书 1:9', '歌罗西书 3:9', '约翰一书 2:18', '约翰一书 3:9',
      '约翰一书 5:20', '约翰福音 1:14', '约翰福音 1:16', '约翰福音 12:25',
      '罗马书 10:8', '罗马书 10:13', '路加福音 9:5', '路加福音 11:9',
      '路加福音 11:23', '路加福音 12:20', '路加福音 23:43', '马可福音 5:2',
      '马可福音 9:42', '马可福音 9:43', '马太福音 7:11', '马太福音 8:19',
      '马太福音 8:20',
    };
    final note = RegExp(r'<note:.*?>');
    final cn = {for (final v in load('assets/biblexg-v3.json')) v['id']: v};
    final tr = {for (final v in load('assets/biblexg-v3-tr.json')) v['id']: v};

    final differing = <String>{};
    for (final entry in cn.entries) {
      final other = tr[entry.key];
      if (other == null) continue;
      final a = note.allMatches(entry.value['text'] as String).length;
      final b = note.allMatches(other['text'] as String).length;
      if (a == b) continue;
      differing.add('${entry.value['book']} '
          '${entry.value['chapter']}:${entry.value['verseLabel']}');
    }
    expect(differing.difference(knownNoteDifferences), isEmpty,
        reason: 'a verse newly disagrees about a note between the v3 pair. '
            'If our importer dropped an inline note, its words are now '
            'printed as scripture — run tools/audit_biblexg_notes.py '
            'against the publisher before assuming otherwise');
    expect(knownNoteDifferences.difference(differing), isEmpty,
        reason: 'a listed v3 note difference is gone — if that was a '
            'repair, take it off the list; if the note vanished from both '
            'editions, it was lost');
  });

  test('the two editions disagree about a note in exactly 32 verses', () {
    // An editor's gloss flattened out of its note and into the verse body
    // is the 羅馬書 16:24 defect, and it is invisible on screen: the verse
    // reads plausibly and gets quoted as the evangelist's words. The only
    // cheap signal for it is the two editions disagreeing about how many
    // notes a verse has.
    //
    // That signal does NOT say whose fault it is, and the difference
    // between the two answers matters. Checked against the publisher's
    // own `tw-*.json` and `cn-*.json` by tools/audit_biblexg_notes.py:
    // our Traditional carries every `<cite>` theirs carries and invents
    // none, and so does our Simplified. The rest are the publisher's own
    // difference between their two editions — their Traditional prints
    // 「即葡萄酒，」 inside 馬太福音 26:29 as body text, their Simplified
    // marks it up. Asked in docs/梁家鏗譯本-請教出版方.md; reconciling
    // them ourselves would be editing scripture on a guess.
    //
    // This comment used to say the printed 註釋本 could not arbitrate it,
    // because pdftotext renders a footnote inline and indistinguishable
    // from body text. That was a limitation of the extraction, not of the
    // book. `pdftohtml -xml` keeps each run's font size, and the 二版 sets
    // scripture at 17pt and the editor's voice at 12pt — per occurrence,
    // so 加拉太書 3:7 and 3:9 set 稱義 at 12pt while 3:8 and 3:11 set the
    // same two characters as body. That settled four of the 36:
    // 路加福音 9:5, 約翰福音 12:25, 加拉太書 3:7 and 3:9 are the editor's,
    // and our Traditional now marks them so (tools/audit_printed_typography.py).
    //
    // Pinned as a set rather than a count so that a future importer
    // change flattening a note shows up as a NEW reference here.
    const knownNoteDifferences = <String>{
      '马太福音 10:8', '马太福音 13:21', '马太福音 22:45', '马太福音 26:29',
      '马太福音 27:48', '路加福音 6:3', '路加福音 9:17',
      '路加福音 9:46', '路加福音 10:5', '路加福音 19:38', '约翰福音 1:18',
      '约翰福音 6:45', '使徒行传 8:5', '使徒行传 8:41',
      '罗马书 8:29', '罗马书 11:2', '罗马书 11:27', '罗马书 12:6',
      '哥林多前书 6:11', '哥林多前书 15:27', '哥林多后书 6:17',
      '哥林多后书 6:18', '以弗所书 2:8',
      '以弗所书 3:12', '以弗所书 4:25', '以弗所书 6:3', '歌罗西书 3:10',
      '帖撒罗尼迦前书 5:19', '提摩太后书 3:15', '启示录 3:1',
      '启示录 8:12', '启示录 12:17',
    };
    final note = RegExp(r'<note:.*?>');
    final cn = {for (final v in load('assets/biblexg-v2.json')) v['id']: v};
    final tr = {for (final v in load('assets/biblexg-v2-tr.json')) v['id']: v};

    final differing = <String>{};
    for (final entry in cn.entries) {
      final other = tr[entry.key];
      if (other == null) continue;
      final a = note.allMatches(entry.value['text'] as String).length;
      final b = note.allMatches(other['text'] as String).length;
      if (a == b) continue;
      differing.add('${entry.value['book']} '
          '${entry.value['chapter']}:${entry.value['verseLabel']}');
    }
    expect(differing.difference(knownNoteDifferences), isEmpty,
        reason: 'a verse newly disagrees about a note between the two '
            'editions. If our importer dropped an inline note, its words '
            'are now printed as scripture — run '
            'tools/audit_biblexg_notes.py against the publisher before '
            'assuming otherwise');
    expect(knownNoteDifferences.difference(differing), isEmpty,
        reason: 'a listed note difference is gone — if that was a repair, '
            'take it off the list; if the note vanished from both '
            'editions, it was lost');
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

  test('each edition writes the annotation marker in its own script', () {
    // 註 / 注 cannot go in the character list above, because 注 has a
    // perfectly good Traditional reading (注意) and appears 35 times in
    // the Traditional verse bodies. But as the marker that ends a
    // cross-reference — 「參可12.42註」, "see the note at Mark 12:42" —
    // the Traditional is 註 and the Simplified 注, and our two editions
    // are each internally consistent: 109/109 and 108/108.
    //
    // Pinned because the publisher's own tw-rev.json is NOT consistent.
    // It sets 啟示錄 20:4 as 「參啟1.2注」 with the Simplified character,
    // against 註 everywhere else in that same file. The printed
    // 《新約聖經 梁家鏗譯本（註釋本）》2025 第二版 prints 「參 1.2 註」,
    // so ours is the reading that matches the print and theirs is the
    // slip — do not "fix" ours towards their electronic edition.
    // Measured by tools/audit_biblexg_notes.py, which compares the text
    // of every note in both editions against the publisher's own files.
    final note = RegExp(r'<note:(.*?)>');
    String markers(String path, String wrong) => [
          for (final v in load(path))
            for (final m in note.allMatches(v['text'] as String))
              if (m.group(1)!.contains(wrong))
                '${v['book']} ${v['chapter']}:${v['verseLabel']} — ${m.group(1)}'
        ].join('\n');

    expect(markers('assets/biblexg-v2-tr.json', '注'), isEmpty,
        reason: 'a Simplified 注 has reached a Traditional note. The '
            'printed 註釋本 sets 註; check it at that verse before '
            'accepting the publisher electronic edition.');
    expect(markers('assets/biblexg-v2.json', '註'), isEmpty,
        reason: 'a Traditional 註 has reached a Simplified note');
  });

  test('以弗所書 3:15 keeps the printed edition\'s cross-reference', () {
    // The publisher's current tw-eph.json reads 「參4.6、16」; the printed
    // 2025 第二版 reads 「參 4.6，」, which is what we ship. So this is an
    // upstream revision that post-dates the printed volume, not a case
    // of our Traditional having been built from their Simplified — 3:16
    // right beside it ships their Traditional's 「參2.18註」 against
    // their Simplified's 注.
    //
    // Pinned so that a future re-import of the publisher's files adopts
    // the revision as a decision rather than silently. §四之二 of
    // docs/梁家鏗譯本-請教出版方.md is asking them about exactly this.
    final eph = load('assets/biblexg-v2-tr.json').firstWhere((v) =>
        v['book'] == '以弗所書' &&
        v['chapter'] == '3' &&
        v['verseLabel'] == '15');
    expect(eph['text'], contains('<note:參4.6，>'));
  });

  test('the Traditional still has the 馬可福音 6 that the hidden v2 lost',
      () {
    for (final path in ['assets/biblexg-v2-tr.json', 'assets/biblexg-v3-tr.json']) {
      final mark6 = {
        for (final v in load(path))
          if (v['book'] == '馬可福音' && v['chapter'] == '6')
            v['verse'] as String: v['text'] as String
      };
      expect(mark6['7'], endsWith('制服不潔的靈。'),
          reason: '$path — the hidden v2.json truncates 6:7 at 並授予他們權能');
      expect(mark6['8'], contains('只帶一根手杖'), reason: path);
      expect(mark6['11'], contains('把腳上的塵土跺落'), reason: path);
    }
  });

  test('the selectable v3 Simplified has restored 馬可福音 6:8-11', () {
    // commit `3cefcab7` restored 6:8-11 in biblexg-v3.json — the edition
    // a reader can actually select — while the hidden biblexg-v2.json
    // (bible_versions.dart:378-402) keeps the publisher's own gap
    // (pinned in expectedGaps above). Before this test, that restoration
    // had no guard at all: the test above only ever read the Traditional.
    final mark6 = {
      for (final v in load('assets/biblexg-v3.json'))
        if (v['book'] == '马可福音' && v['chapter'] == '6')
          v['verse'] as String: v['text'] as String
    };
    expect(mark6['7'], endsWith('制服不洁的灵。'));
    expect(mark6['8'], contains('只带一根手杖'));
    expect(mark6['9'], isNotNull);
    expect(mark6['10'], isNotNull);
    expect(mark6['11'], contains('把脚上的尘土跺落'));
  });
}
