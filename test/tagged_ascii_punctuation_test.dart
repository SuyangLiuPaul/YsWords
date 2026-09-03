import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The word-tap corpus printed half-width punctuation and import spacing.
///
/// `assets/tagged/cuvs-yhwh/` is rendered VERBATIM in place of the reader's
/// verse by `originals_sheet.dart`, and `TaggedTextService.coversVerse`
/// compares ideographs — so neither a `,` nor a space is visible to any guard
/// this repo has. Both printed as scripture: 馬可福音 1:5 read
/// 「耶路撒冷的人,都出去到约翰那里,」 and 使徒行傳 9:5 read 「主 说：」.
///
/// Measured 2026-09-03 over 31,102 verses / 367,574 runs:
///
///     ,  27 in 21 verses     .  16 in 13 verses
///     !  11 in 11 verses     ;   4 in  4 verses
///     :  56 in 53 verses     ␣ 621 in 361 verses
///
/// **Two of those populations were not all defect, and the tools say which
/// is which rather than applying a rule.**
///
/// `.` — 羅馬書 8:34 stores `〔"有基督...."：或作…〕`, and BOTH frozen reading
/// assets store the identical `<note: 有基督....或作…>`. Three transcription
/// lines agreeing makes that ellipsis the edition's own apparatus, so it is
/// kept and the real `.` population is 12, not 16.
///
/// `:` — 52 of the 56 live inside the edition's cross-reference notes
/// (`〔創10:3作"利法"〕`) and are legitimate, as the queue said. **Four do
/// not**: 使徒行傳 1:24, 路加福音 18:37 and 羅馬書 4:18 set a speech colon
/// half-width where the reading asset sets `：` in the same slot, and 約伯記
/// 11:6 reads 「所以当知道: 神追讨你」. Those four are widened.
///
/// `␣` — 429 are the `主 [雅伟] 誇口` gloss spacing that
/// `TaggedTextService._tightenGloss` owns and must keep seeing. Of the
/// remaining 192, **64 stand where the reading text of the same verse also
/// spaces** — 撒迦利亞書 1:6 「他已照樣行了。’ ”」 — and two independent
/// transcriptions of one edition agreeing is this repo's strongest witness,
/// so those stay too. 128 are the import's alone and are gone.
///
/// `tools/repair_tagged_ascii_punctuation.py` then
/// `tools/repair_tagged_stray_spaces.py` apply this, in that order. Both are
/// idempotent and both refuse a position they have no decision or no witness
/// for.
void main() {
  final files = Directory('assets/tagged/cuvs-yhwh')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  Map<String, String> corpus() {
    final out = <String, String>{};
    for (final file in files) {
      final slug = file.uri.pathSegments.last.replaceAll('.json', '');
      final decoded =
          json.decode(file.readAsStringSync()) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        out['$slug ${entry.key}'] =
            (entry.value as List).map((r) => (r as Map)['w'] as String).join();
      }
    }
    return out;
  }

  test('no half-width comma, bang or semicolon survives in the corpus', () {
    expect(files, hasLength(66));
    final offenders = <String>[];
    corpus().forEach((ref, text) {
      if (text.contains(RegExp(r'[,!;]'))) offenders.add(ref);
    });
    expect(offenders, isEmpty,
        reason: 'the corpus is set full-width 100,000 times over, so a '
            'half-width mark here prints as scripture: '
            '${offenders.join(', ')}');
  });

  test('the only ASCII periods left are the edition\'s own ellipsis', () {
    final holders = <String, int>{};
    corpus().forEach((ref, text) {
      final n = '.'.allMatches(text).length;
      if (n > 0) holders[ref] = n;
    });
    expect(holders, {'romans 8:34': 4});

    // And the frozen reading assets carry it too — which is the whole
    // reason it stays. If this ever fails, the corpus and the edition have
    // stopped agreeing and the ellipsis needs reading again, not deleting.
    for (final asset in ['assets/cuvs-yhwh.json', 'assets/cuvs-yhwh-tr.json']) {
      final rows = (json.decode(File(asset).readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();
      final dotted = rows.where((r) => (r['text'] as String).contains('.'));
      expect(dotted, hasLength(1), reason: asset);
      expect('${dotted.single['chapter']}:${dotted.single['verse']}', '8:34');
      expect(dotted.single['text'], contains('有基督....'));
    }
  });

  test('every ASCII colon left is inside a cross-reference note', () {
    final note = RegExp(r'〔[^〕]*〕');
    var inside = 0;
    final outside = <String>[];
    corpus().forEach((ref, text) {
      if (!text.contains(':')) return;
      final spans = note.allMatches(text).toList();
      for (var i = 0; i < text.length; i++) {
        if (text[i] != ':') continue;
        if (spans.any((m) => m.start <= i && i < m.end)) {
          inside++;
        } else {
          outside.add('$ref @$i');
        }
      }
    });
    expect(outside, isEmpty,
        reason: 'a speech colon set half-width prints as scripture: '
            '${outside.join(', ')}');
    // 52 measured 2026-09-03. Pinned low side only: the edition may set more
    // cross-references, but none of them may leave a 〔…〕.
    expect(inside, 52);
  });

  test('the spaces left are the gloss spacing and the witnessed ones', () {
    var gloss = 0;
    var other = 0;
    final byRef = <String, int>{};
    corpus().forEach((ref, text) {
      for (var i = 0; i < text.length; i++) {
        if (text[i] != ' ') continue;
        final glossy = (i + 1 < text.length && text[i + 1] == '[') ||
            (i > 0 && text[i - 1] == ']');
        if (glossy) {
          gloss++;
        } else {
          other++;
          byRef[ref] = (byRef[ref] ?? 0) + 1;
        }
      }
    });
    // 429 before the repair and 429 after: `_tightenGloss` reads these at
    // load time and a repair pass must not take its input away.
    expect(gloss, 429);
    // 192 before, 128 of them deleted as the import's own.
    expect(other, 64);
    expect(byRef.length, 57);
    // The class that stayed: a space the frozen reading asset also sets.
    expect(byRef.keys, contains('zechariah 1:6'));
    expect(byRef.keys, isNot(contains('acts 9:5')));
  });

  test('the verses the repair rewrote read the way the edition sets them', () {
    final text = corpus();
    // width, confirmed by the reading verse holding the full-width mark
    expect(text['mark 1:5'], startsWith('犹太全地和耶路撒冷的人，都出去到约翰那里，'));
    expect(text['genesis 44:17'], contains('我断不能这样行！在谁的手中'));
    expect(text['1_thessalonians 2:13'], contains('就领受了；不以为是人的道'));
    expect(text['luke 18:37'], '他们告诉他：“是拿撒勒人耶稣经过。”');
    // width only, where the two transcriptions choose different marks —
    // 約伯記 11:12 reads ； in the reading asset and ， here, and which mark
    // this line uses is not a punctuation repair's business.
    expect(text['job 11:12'], '空虚的人却毫无知识，人生在世好像野驴的驹子。');
    // doubled: the ASCII mark stood in front of the full-width one
    expect(text['genesis 6:11'], '世界在神面前败坏，地上满了强暴。');
    expect(text['proverbs 31:11'], '她丈夫心里倚靠她，必不缺少利益；');
    // stray: no witness marks the position and no Chinese mark can sit there
    expect(text['matthew 12:28'], '我若靠着神的灵赶鬼，这就是神的国临到你们了。');
    expect(text['psalms 69:25'], '愿他们的住处变为荒场；愿他们的帐棚无人居住。');
    expect(text['zechariah 3:9'], contains('万军之雅伟说：我要亲自雕刻'));
    // space: the import's own, and the gloss spacing beside it untouched
    expect(text['acts 9:5'], contains('主说：'));
    expect(text['1_chronicles 1:22'], contains('以巴录、亚比玛利、示巴、'));
    expect(text['acts 5:12'], contains('主 [雅伟] 借使徒的手'));
  });
}
