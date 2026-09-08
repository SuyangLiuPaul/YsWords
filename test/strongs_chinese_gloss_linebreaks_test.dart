import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `glossZh` is the whole of CBOL's sense 1, not the first printed line
/// of it.
///
/// `tools/build_originals.py` took the gloss with one
/// `^\s*1\)\s*(.+?)\s*$` match, which stops at whatever newline CBOL
/// happened to wrap the sense on. CBOL wraps at its own column width
/// with a `\n   ` continuation, so 426 entries shipped a sentence cut in
/// half and 59 more ended on CBOL's trailing comma. `glossZh` is the
/// meaning printed by the originals sheet, the Strong's entry page,
/// search results and the distribution table, so every one of those was
/// on screen. `tools/repair_zh_gloss_linebreaks.py` rebuilt them.
///
/// The opposite error is the danger this file is mostly here to guard,
/// because CBOL writes a wrap and a deliberate break with the same
/// newline: joining across a real break invents a reading. Both halves
/// are pinned below.
void main() {
  late Map<String, dynamic> greek;
  late Map<String, dynamic> hebrew;

  setUpAll(() {
    greek = json.decode(File('assets/strongs/greek.json').readAsStringSync())
        as Map<String, dynamic>;
    hebrew = json.decode(File('assets/strongs/hebrew.json').readAsStringSync())
        as Map<String, dynamic>;
  });

  String gloss(Map<String, dynamic> lex, String id, [String key = 'glossZh']) =>
      (lex[id] as Map<String, dynamic>)[key] as String;

  Iterable<({String id, String key, String gloss, String body})>
      everyGloss() sync* {
    for (final lex in [greek, hebrew]) {
      for (final entry in lex.entries) {
        final e = entry.value as Map<String, dynamic>;
        for (final pair in const [
          ('glossZh', 'defZh'),
          ('glossZhTw', 'defZhTw'),
        ]) {
          final g = e[pair.$1];
          final b = e[pair.$2];
          if (g is String && g.isNotEmpty && b is String && b.isNotEmpty) {
            yield (id: entry.key, key: pair.$1, gloss: g, body: b);
          }
        }
      }
    }
  }

  group('a sense CBOL wrapped arrives whole', () {
    test('the four worked examples say what the definition says', () {
      // Each of these ended where the printed page broke, and the clause
      // that carried the actual meaning was on the line after.
      expect(gloss(hebrew, 'H86'), contains('"你们要下拜"或"俯首"的意思'));
      expect(gloss(greek, 'G3712'), contains('两手中指指尖距离所测得的长度'));
      expect(gloss(greek, 'G1179'), endsWith('南方是非拉铁非 (#太 4:25; 可 5:20,7:31|)'));
      expect(gloss(greek, 'G2815'), endsWith('他就是初世纪末的罗马主教革利免'));
    });

    test('a wrap inside a parenthesis is still a wrap', () {
      // H1374 closes a bracket mid-sentence — `(今 Anata 亚拿塔)` — so a
      // closing bracket alone must not read as the end of the sense.
      // Stopping there left the gloss saying the village is AT Anathoth
      // rather than between the ridges of Anathoth and Nob.
      expect(gloss(hebrew, 'H1374'), contains('和挪伯城所在的山脊之间'));
    });

    test('the Traditional column was rejoined out of its own body', () {
      // Not converted from the repaired Simplified gloss: the same join
      // run over `defZhTw`, which `scripts/build_strongs_traditional.py`
      // already produced character-for-character from `defZh`. Running
      // opencc again would have re-applied a conversion this repo keeps
      // a family of `repair_tr_*` scripts to undo.
      expect(gloss(hebrew, 'H204', 'glossZhTw'), endsWith('居住之地'));
      expect(gloss(greek, 'G4102', 'glossZhTw'), contains('信靠的觀念'));
    });

    test('a part-of-speech tag on the next line is not swallowed', () {
      // H2108 is why `介係詞` had to be listed beside `介系詞` in the
      // repair's vocabulary: this tree's s2t writes 系 as 係, so the
      // Traditional tag went unrecognised and the Traditional gloss ran
      // one line further than the Simplified one.
      expect(gloss(hebrew, 'H2108', 'glossZhTw'), endsWith('連接詞)'));
      expect(gloss(hebrew, 'H2108'), endsWith('连接词)'));
    });
  });

  group('a break CBOL meant is not joined across', () {
    test('a short sense in a wide entry stays short', () {
      // G749's sense 1 is 17 columns in an entry whose lines run to 90,
      // and the line after it opens a fresh article. Joining them gives
      // `大祭司在祭司中最大的一`, a reading found in no lexicon.
      expect(gloss(greek, 'G749'), '祭司长, 大祭司');
    });

    test('a heading on the next line ends the sense', () {
      // G5208's second line is the heading 经文以外的意思.
      expect(gloss(greek, 'G5208'), isNot(contains('经文以外')));
    });

    test('a gloss that ends on a colon is CBOL\'s own stub and stays one', () {
      // `StrongsEntry.localizedGloss` has a path for these; it must keep
      // firing, so the colon must survive the repair.
      expect(gloss(greek, 'G1537'), endsWith(':'));
    });

    test('an entry CBOL never numbered keeps an empty gloss', () {
      // H7665 prints its sense 1 as a bare line and numbers only the
      // stems below it, so the shipped body is the raw CBOL entry and
      // there is no `1)` to read. A fallback loose enough to accept
      // `1a)` would ship `(Qal)` as the word's meaning; the empty gloss
      // is correct, and the model reads the body at runtime instead.
      expect(gloss(hebrew, 'H7665'), '');
      expect((greek['G2304'] as Map<String, dynamic>)['glossZh'], '');
    });
  });

  group('across the whole lexicon', () {
    test('no gloss ends mid-clause', () {
      final dangling = [
        for (final g in everyGloss())
          if (RegExp(r'[,，、;；]\s*$').hasMatch(g.gloss)) '${g.id}/${g.key}',
      ];
      expect(dangling, isEmpty,
          reason: 'a gloss ending on a separator is a sentence cut short');
    });

    test('every gloss is text CBOL itself printed, only reflowed', () {
      // The join takes CBOL's own line breaks out; it must never put a
      // character in. So each gloss, whitespace ignored, has to still be
      // a contiguous run of the definition body beside it. This is what
      // separates reflowing from paraphrasing, and it is checked over
      // all 28,366 glosses rather than only the 485 that were rebuilt.
      final ws = RegExp(r'\s+');
      final invented = <String>[];
      var checked = 0;
      for (final g in everyGloss()) {
        checked++;
        if (!g.body.replaceAll(ws, '').contains(g.gloss.replaceAll(ws, ''))) {
          invented.add('${g.id}/${g.key}: ${g.gloss}');
        }
      }
      expect(invented, isEmpty, reason: invented.take(10).join('\n'));
      expect(checked, 28366);
    });

    test('the two orthographies were rejoined at the same line', () {
      // The columns are one body in two scripts, so a gloss present in
      // one and absent in the other means the join read them
      // differently — a bug in the line grammar, not a fact about the
      // entry. The 11 entries with no `glossZhTw` key at all predate
      // this repair: `scripts/build_strongs_traditional.py` skips an
      // entry whose Simplified gloss is empty, and 9 of the 11 still
      // have one. G2304 and H7665 are the other two, and they are empty
      // on both sides for the reason pinned above.
      final lopsided = <String>[];
      for (final lex in [greek, hebrew]) {
        for (final entry in lex.entries) {
          final e = entry.value as Map<String, dynamic>;
          final sc = e['glossZh'];
          final tw = e['glossZhTw'];
          if (tw == null) continue;
          if ((sc as String).isEmpty != (tw as String).isEmpty) {
            lopsided.add(entry.key);
          }
        }
      }
      expect(lopsided, isEmpty);
    });
  });
}
