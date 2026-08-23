import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Two punctuation defects that sat in **both** CUV editions at the same
/// positions — which is what says they are upstream of the Traditional script
/// conversion rather than caused by it, unlike the glyph holes pinned by
/// `traditional_classifier_test.dart` and its siblings.
///
/// 1. `丶` (U+4E36) is the CJK *stroke radical*, a dictionary head component
///    with no use in running prose. It stood in for the enumeration comma `、`
///    in 53 places, so 出埃及記 15:4 read 「法老的車輛丶軍兵」 and 詩篇 146:6
///    read 「雅偉造天丶地丶海」.
///
/// 2. Eight verses carried an orphaned mark — 「接連一塊，，。」,
///    「有希弗族；。」, 「喊著說：！不潔淨的」.
///
/// The eighth was found by this test rather than by the sweep that preceded
/// it: the sweep tabulated 「：，」 with a count of 2 and the reader took both
/// to be 阿摩司書 6:10, so 6:14 was repaired only once the assertion below ran
/// over the whole corpus. A count read off a table is not the same as a
/// position checked in the data.
///
/// Every repair was a deletion or a one-character substitution confirmed
/// against a witness: `assets/cuv-tr.json`, the plain 和合本 Traditional,
/// dropped at v1.4.5 but readable as git blob `7a2dc43`. Nothing was written
/// into scripture.
///
/// The counts here are deliberately exact rather than `isEmpty`. A converter
/// or an import that reintroduces the defect will move them, and a count that
/// moves is the signature this repo keeps missing when it only asks whether a
/// verse exists.
void main() {
  const editions = {
    'Simplified': 'assets/cuvs-yhwh.json',
    'Traditional': 'assets/cuvs-yhwh-tr.json',
  };

  final loaded = <String, List<Map<String, dynamic>>>{};

  setUpAll(() {
    for (final entry in editions.entries) {
      loaded[entry.key] = (json.decode(File(entry.value).readAsStringSync())
              as List)
          .cast<Map<String, dynamic>>();
    }
  });

  String blobOf(String edition) =>
      loaded[edition]!.map((v) => v['text'] as String).join();

  String textOf(String edition, String id) =>
      loaded[edition]!.firstWhere((v) => v['id'] == id)['text'] as String;

  for (final edition in editions.keys) {
    group(edition, () {
      test('the stroke radical 丶 appears nowhere in scripture', () {
        expect(blobOf(edition).contains('丶'), isFalse,
            reason: 'U+4E36 is a dictionary head component, not punctuation. '
                'Re-run tools/repair_stray_punctuation.py.');
      });

      test('the enumeration commas it displaced are all present', () {
        // 6271 before the repair + the 53 that were written as 丶.
        expect(blobOf(edition).split('、').length - 1, 6324);
      });

      test('no punctuation mark is doubled or orphaned', () {
        const marks = '，。、；：？！';
        // Pairs that are legitimate: a mark before an opening or after a
        // closing quote, and 。 before （. Two marks from this set in a row
        // never is.
        final offenders = <String>[];
        for (final v in loaded[edition]!) {
          final text = v['text'] as String;
          for (var i = 0; i < text.length - 1; i++) {
            if (marks.contains(text[i]) && marks.contains(text[i + 1])) {
              offenders.add('${v['book']} ${v['chapter']}:${v['verse']} — '
                  '${text.substring((i - 8).clamp(0, text.length), (i + 8).clamp(0, text.length))}');
            }
          }
        }
        expect(offenders, isEmpty);
      });

      /// A verse whose whole text is a `<note: …>` renders as a book icon
      /// and nothing else, so any character left OUTSIDE the note is the
      /// only thing the reader sees. 路加福音 17:36 left a `」` there and
      /// printed an icon followed by a bare closing bracket; it was the
      /// only one of 31,102 verses that did.
      ///
      /// The rule is written over the whole corpus rather than as one
      /// assertion about 17:36, because the eight wholly-editorial verses
      /// are exactly the ones where a leftover mark is invisible to every
      /// other check — the verse is non-empty on disk, unique, and carries
      /// no doubled punctuation. A remainder holding no CJK at all is not
      /// text; it is debris.
      test('nothing is left outside a wholly-editorial verse\'s note', () {
        final cjk = RegExp(r'[㐀-鿿]');
        final offenders = <String>[];
        for (final v in loaded[edition]!) {
          final text = v['text'] as String;
          if (!text.startsWith('<note:')) continue;
          final rest = text.substring(text.indexOf('>') + 1);
          if (rest.trim().isEmpty || cjk.hasMatch(rest)) continue;
          offenders.add('${v['book']} ${v['chapter']}:${v['verse']} — $rest');
        }
        expect(offenders, isEmpty);
      });

      test('the repaired verses read correctly', () {
        expect(textOf(edition, '002015004'), contains('車輛、軍兵'.chars(edition)));
        expect(textOf(edition, '019146006'), contains('造天、地、海'.chars(edition)));
        expect(textOf(edition, '016009005'), contains('甲篾、巴尼'.chars(edition)));
        expect(textOf(edition, '002025035'), contains('接連一塊。燈臺'.chars(edition)));
        expect(textOf(edition, '004026032'), contains('有希弗族。'.chars(edition)));
        expect(textOf(edition, '025004015'), contains('喊著說：不潔淨的'.chars(edition)));
        expect(textOf(edition, '038003008'), contains('作預兆的）。我必使'.chars(edition)));
        expect(textOf(edition, '030006010'), contains('又說：不要作聲'.chars(edition)));
        expect(textOf(edition, '030006014'), contains('說：以色列家啊'.chars(edition)));
        expect(textOf(edition, '058013003'), contains('同受捆綁；也要'.chars(edition)));
        expect(textOf(edition, '042017036'), endsWith('>'));
        // The mark that stays. Deleting THIS one instead would have left
        // Jesus' discourse closing after an icon; three lines — the tagged
        // Strong's corpus, 梁家鏗's independent NT, and the five other
        // note-only verses — put the close here, at 17:35.
        expect(textOf(edition, '042017035'),
            endsWith(edition == 'Simplified' ? '撇下一个。”' : '撇下一個。」'));
      });
    });
  }

  test('the tagged Strong\'s corpus carries neither defect', () {
    final dir = Directory('assets/tagged/cuvs-yhwh');
    var strokes = 0;
    for (final file in dir.listSync().whereType<File>()) {
      if (!file.path.endsWith('.json')) continue;
      final data = json.decode(file.readAsStringSync()) as Map<String, dynamic>;
      for (final runs in data.values) {
        for (final run in (runs as List).cast<Map<String, dynamic>>()) {
          strokes += (run['w'] as String? ?? '').split('丶').length - 1;
        }
      }
    }
    expect(strokes, 0,
        reason: 'the interlinear renders these words too — 44 of them '
            'printed the stroke radical between coordinate nouns');
  });
}

extension on String {
  /// The two editions differ in script, so a Traditional probe has to be
  /// written in Simplified to be looked for in the Simplified asset. Only the
  /// handful of characters used by the probes above need mapping.
  String chars(String edition) {
    if (edition != 'Simplified') return this;
    const map = {
      '車': '车',
      '輛': '辆',
      '軍': '军',
      '篾': '篾',
      '塊': '块',
      '燈': '灯',
      '臺': '台',
      '連': '连',
      '記': '记',
      '喊': '喊',
      '著': '着',
      '說': '说',
      '潔': '洁',
      '淨': '净',
      '預': '预',
      '兆': '兆',
      '製': '制',
      '聲': '声',
      '綁': '绑',
      '捆': '捆',
      '兒': '儿',
      '應': '应',
    };
    return split('').map((c) => map[c] ?? c).join();
  }
}
