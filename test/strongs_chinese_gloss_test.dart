import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/models/strongs.dart';

/// The Chinese lexicon card printed English for 11 words — including
/// three of the commonest in the Bible.
///
/// Found while auditing whether each Chinese gloss belongs to the number
/// it is filed under (`tools/audit_strongs_gloss_refs.py`). The merge
/// itself is sound: 12,994 of the 14,203 verse citations CBOL embeds in
/// its own definitions find that very number in `assets/originals/`, an
/// independently sourced dataset the glosses were never derived from,
/// and the residue is Textus-Receptus-vs-critical-text variants and
/// lemmatisation convention, not misfiling.
///
/// What the audit did turn up is a gap on our side. 14 entries carry no
/// `glossZh` at all, and for 11 of them the Chinese IS in our asset —
/// in `defZh`. `localizedGloss` fell straight through to the English
/// gloss, so a Chinese reader tapping G2596 κατά (473 occurrences in
/// `assets/originals/`), G302 ἄν (166) or H7665 שָׁבַר (148) was answered
/// in English; G2243 Ἡλίας was answered `Helias (i`, the English gloss
/// itself truncated by the importer at the first full stop, while our
/// own asset held 以利亚 = "我的神是雅伟".
///
/// Nothing untrue was on screen, which is why no accuracy audit caught
/// it — the app was simply not showing the Chinese it had.
///
/// Writing the invariant as a test found a second class of the same
/// defect that reading the data had not: 8 entries whose Chinese gloss
/// is the Hebrew stem and nothing else — H874 בָּאַר glossed `(Piel)`,
/// H952 בּוּר glossed `(Qal)` — where the sense is the next line down
/// (`1a) 使之明显, 清楚`). The stem is kept, because in exegesis the
/// binyan is information; it just stops being the whole answer.
///
/// The blast radius was measured rather than argued: every one of the
/// 14,197 entries was rendered in `zh-Hans`, `zh-Hant` and `en` before
/// and after, and **exactly 18 changed, in Chinese only** — the 11
/// English fall-throughs and the 8 stem-only glosses, less H2536, whose
/// CBOL definition is itself English so there is nothing to show.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final entries = <String, StrongsEntry>{};
  setUpAll(() {
    for (final corpus in const ['hebrew', 'greek']) {
      final raw = json.decode(
        File('assets/strongs/$corpus.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      raw.forEach((key, value) {
        entries[key] = StrongsEntry.fromJson(key, value as Map<String, dynamic>);
      });
    }
  });

  bool hasChinese(String s) => RegExp(r'[㐀-鿿]').hasMatch(s);

  test('a Chinese definition always yields a Chinese gloss', () {
    final english = <String>[];
    for (final entry in entries.entries) {
      final e = entry.value;
      final hasChineseBody = hasChinese(e.definitionZh ?? '') ||
          hasChinese(e.definitionZhTw ?? '');
      if (!hasChineseBody) continue;
      for (final locale in const ['zh-Hans', 'zh-Hant']) {
        if (!hasChinese(e.localizedGloss(locale))) {
          english.add('${entry.key} $locale → ${e.localizedGloss(locale)}');
        }
      }
    }
    expect(english, isEmpty,
        reason: 'the Chinese lexicon card fell back to English where our '
            'own asset holds the Chinese:\n${english.join('\n')}');
  });

  test('the words the fix was found on read in Chinese', () {
    expect(entries['G2243']!.localizedGloss('zh-Hans'), '以利亚 = "我的神是雅伟"');
    expect(entries['G2243']!.localizedGloss('zh-Hant'), '以利亞 = "我的神是雅偉"');
    expect(entries['G2596']!.localizedGloss('zh-Hans'), contains('根据'));
    expect(entries['H7665']!.localizedGloss('zh-Hans'), '折断, 打碎');
    expect(entries['G717']!.localizedGloss('zh-Hant'), contains('米吉多'));
    // The stem stays, the meaning arrives.
    expect(entries['H874']!.localizedGloss('zh-Hans'), '(Piel); 使之明显, 清楚; 解释');
    expect(entries['H952']!.localizedGloss('zh-Hans'), startsWith('(Qal); '));
  });

  test('the source\'s sub-sense numbering is not printed as the word', () {
    final marker = RegExp(r'\b\d[a-z]\d*\)');
    final leaked = <String>[];
    for (final e in entries.values) {
      for (final locale in const ['zh-Hans', 'zh-Hant']) {
        if (marker.hasMatch(e.localizedGloss(locale))) {
          leaked.add('${e.number} $locale → ${e.localizedGloss(locale)}');
        }
      }
    }
    expect(leaked, isEmpty, reason: leaked.join('\n'));
  });

  test('etymology is never printed as a meaning', () {
    // H4092's definition opens `04084 的变异型; 形容词` — a fact about the
    // dictionary, where the reader is promised the sense of the word.
    final gloss = entries['H4092']!.localizedGloss('zh-Hans');
    expect(gloss, isNot(contains('变异型')));
    expect(gloss, contains('米甸人'));
    for (final e in entries.values) {
      expect(RegExp(r'^\s*\d{3,}\s').hasMatch(e.localizedGloss('zh-Hans')),
          isFalse,
          reason: '${e.number} glosses itself with a Strong\'s number');
    }
  });

  test('the English gloss is untouched', () {
    expect(entries['G2596']!.localizedGloss('en'), startsWith('(prepositionally) down'));
    expect(entries['H7665']!.localizedGloss('en'), 'to burst (literally or figuratively)');
    // …and a word that always had a Chinese gloss still uses it.
    expect(entries['H1']!.localizedGloss('zh-Hans'), '个人的父亲');
    expect(entries['H1']!.localizedGloss('en'), startsWith('father'));
  });
}
