import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `assets/bible_evidence.json` used to print SIMPLIFIED prose to Traditional
/// readers. **Fixed 2026-09-03** by `tools/repair_untranslated_hant.py`; this
/// file was the measurement that scoped it and is now the guard that it does
/// not come back.
///
/// What it measured, and the numbers are kept because the next re-import has
/// to be judged against them: the audit's test reported **951 of 1,575
/// `zh-Hant` fields (60.4%) across 223 of the 225 entries**, of which 942 were
/// their `zh-Hans` twin character-for-character. **830 of the 951 actually
/// carried Simplified text** — 32,638 Simplified character occurrences over
/// 785 distinct code points. The other 121 are script-neutral strings
/// ("1946–1956", 死海古卷, 但以理石碑) that are correctly identical to their
/// twin, which is a false positive of the audit's `==` clause and not a
/// defect.
///
/// **This was NOT the converter-hole defect** and was deliberately not swept
/// with the tools that fix that one. Every `tools/repair_tr_*.py` is a
/// single-character substitution justified by a witness edition; there is no
/// witness for apologetics copy, and changing 恒→恆 inside a paragraph that is
/// Simplified from end to end would have "fixed" one character and made the
/// real defect harder to see.
///
/// The conversion itself is pinned by `test/bible_evidence_traditional_test.dart`
/// — that file holds the repaired readings and the keep side. This one holds
/// the two facts that made the defect possible in the first place.
void main() {
  late List<Map<String, dynamic>> evidences;

  setUpAll(() {
    final doc = json.decode(File('assets/bible_evidence.json').readAsStringSync())
        as Map<String, dynamic>;
    evidences = (doc['evidences'] as List).cast<Map<String, dynamic>>();
  });

  /// Every `zh-Hant` string in the document, paired with its `zh-Hans` twin.
  List<List<String?>> hantFields() {
    final out = <List<String?>>[];
    void walk(Object? node) {
      if (node is List) {
        for (final v in node) {
          walk(v);
        }
      } else if (node is Map) {
        final m = node.cast<String, dynamic>();
        final hant = m['zh-Hant'];
        if (hant is String && hant.isNotEmpty) {
          out.add([hant, m['zh-Hans'] as String?]);
        }
        for (final v in m.values) {
          walk(v);
        }
      }
    }

    walk(evidences);
    return out;
  }

  test('no zh-Hant field is its zh-Hans twin unless it is script-neutral', () {
    final fields = hantFields();
    expect(fields, hasLength(1575));
    final identical =
        fields.where((f) => f[1] != null && f[1] == f[0]).toList();
    // Down from 942. The 122 that remain are strings whose every character is
    // the same in both scripts, so being identical is correct — dates, and
    // titles like 死海古卷 / 但以理石碑 / 希西家水道. Any string here that
    // contains a Simplified-only character means a field regressed, and the
    // companion test catches that directly.
    expect(identical, hasLength(122),
        reason: 'a zh-Hant field is its Simplified twin again — re-run '
            'tools/repair_untranslated_hant.py');
  });

  test('no entry has an untranslated field left', () {
    // Was 222 of 225 by this test's own hand-picked character subset.
    var touched = 0;
    for (final entry in evidences) {
      var bad = false;
      void walk(Object? node) {
        if (node is List) {
          for (final v in node) {
            walk(v);
          }
        } else if (node is Map) {
          final m = node.cast<String, dynamic>();
          final hant = m['zh-Hant'];
          if (hant is String && hant.isNotEmpty) {
            // 这 / 圣 / 经 / 说 — Simplified-only, no Traditional use, and
            // none of them is a member of the one-to-many class that the
            // glyph audit owns.
            for (final c in const ['这', '圣', '经', '说', '书', '发现', '们']) {
              if (hant.contains(c)) bad = true;
            }
          }
          for (final v in m.values) {
            walk(v);
          }
        }
      }

      walk(entry);
      if (bad) touched++;
    }
    expect(evidences, hasLength(225));
    expect(touched, 0);
  });

  test('the reading that made this visible is converted, and its twin is not',
      () {
    // Evidence 24 in the item's own words: 「古代伯利恒泥印」 and 「这枚直径约
    // 1.5厘米的小型黏土泥印…」 under zh-Hant — 这 / 圣经 / 约旦 and all.
    final entry = evidences.firstWhere((e) => e['id'] == 'bethlehem_bulla');
    final title = entry['title'] as Map<String, dynamic>;
    expect(title['zh-Hant'], '古代伯利恆泥印');
    // The Simplified side is untouched — this was a conversion, not an edit.
    expect(title['zh-Hans'], '古代伯利恒泥印');
    final summary = entry['summary'] as Map<String, dynamic>;
    expect((summary['zh-Hant'] as String).contains('聖經'), isTrue);
    expect((summary['zh-Hant'] as String).contains('圣经'), isFalse);
    expect((summary['zh-Hans'] as String).contains('圣经'), isTrue);
  });

  test('nothing renders these to Traditional at run time', () {
    // Checked in the code rather than assumed, because "it is probably
    // converted on the way out" is the reason this sat unmeasured. There is
    // no s2t anywhere in lib/ — the only mention is a docstring in
    // lib/models/strongs.dart describing how the LEXICON asset was built.
    // So a Traditional reader is shown these strings exactly as stored, which
    // is why the fix had to be made in the asset.
    final hits = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final s = f.readAsStringSync();
      if (s.contains('s2t') || s.contains('OpenCC') || s.contains('opencc')) {
        hits.add(f.path);
      }
    }
    expect(hits, ['lib/models/strongs.dart'],
        reason: 'if a render-time converter is ever added, this item changes '
            'shape entirely — re-read it before acting');
  });
}
