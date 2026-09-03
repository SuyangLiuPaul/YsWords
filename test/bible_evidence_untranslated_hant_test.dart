import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `assets/bible_evidence.json` prints SIMPLIFIED prose to Traditional readers.
///
/// The queue item asked for one thing before anything was touched — "count how
/// many of the entries have `zh-Hant == zh-Hans` (or are Simplified by
/// character inventory) before deciding — it may be a handful of entries or
/// most of the file." It is most of the file, and this test pins that so the
/// number cannot drift while the question waits for the user.
///
/// **This is NOT the converter-hole defect** and must not be swept with the
/// tools that fix that one. Every `tools/repair_tr_*.py` is a single-character
/// substitution justified by a witness edition. There is no witness for
/// apologetics copy, and changing 恒→恆 inside a paragraph that is Simplified
/// from end to end "fixes" one character and makes the real defect harder to
/// see. Measured by `tools/audit_untranslated_hant.py`.
///
/// The decision this is waiting on: convert 951 paragraph-sized fields with
/// `opencc`, or leave the entries as they are. That is a content decision
/// about reader-facing copy, not a glyph repair, so it is the user's.
void main() {
  late List<Map<String, dynamic>> evidences;

  setUpAll(() {
    final doc = json.decode(File('assets/bible_evidence.json').readAsStringSync())
        as Map<String, dynamic>;
    evidences =
        (doc['evidences'] as List).cast<Map<String, dynamic>>();
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

  test('942 of 1,575 zh-Hant fields are their zh-Hans twin verbatim', () {
    // Character-for-character identity is decisive on its own and needs no
    // oracle: no conversion ran on these at all.
    final fields = hantFields();
    expect(fields, hasLength(1575));
    final identical =
        fields.where((f) => f[1] != null && f[1] == f[0]).length;
    expect(identical, 942,
        reason: 'measured 2026-09-03 by tools/audit_untranslated_hant.py');
  });

  test('222 of the 225 entries have at least one untranslated field', () {
    // The item asked whether this is "a handful of entries or most of the
    // file". It is 99% of the entries, which is what makes it a content
    // decision rather than a repair.
    //
    // 222 here against 223 from tools/audit_untranslated_hant.py, and the
    // gap is deliberate rather than a disagreement: the tool derives its
    // Simplified-only set from opencc at run time, which a Dart test cannot
    // do, so the seven characters below are a hand-picked subset that catches
    // one entry fewer. Pinning the smaller number keeps this test honest
    // about what it actually measures.
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
            if (m['zh-Hans'] == hant) bad = true;
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
    expect(touched, 222);
  });

  test('the reading that made this visible is still there', () {
    // Evidence 24 in the item's own words: 「古代伯利恒泥印」 and 「这枚直径约
    // 1.5厘米的小型黏土泥印…」 under zh-Hant — 这 / 圣经 / 约旦 and all.
    final blob = json.encode(evidences);
    expect(blob, contains('古代伯利恒泥印'));
    expect(blob.contains('这枚直径'), isTrue);
  });

  test('nothing renders these to Traditional at run time', () {
    // Checked in the code rather than assumed, because "it is probably
    // converted on the way out" is the reason this sat unmeasured. There is
    // no s2t anywhere in lib/ — the only mention is a docstring in
    // lib/models/strongs.dart describing how the LEXICON asset was built.
    // So a Traditional reader is shown these strings exactly as stored.
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
