import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:yswords/utils/version_mapper.dart' show localizedReferenceLabel;

/// A displayed reference must cite what the source cites.
///
/// `localizedReferenceLabel` used to re-render the label from the parsed
/// `BibleReference`, and `parseReference` deliberately reduces a
/// reference to ONE navigable target: it stops at the first comma and
/// keeps only the opening chapter of a range. That is right for deciding
/// where to jump and wrong for deciding what to print — the Bible
/// Evidence card ended up quoting a narrower passage than the entry
/// gives.
///
/// Measured over the real asset before the fix: **20 of 225 entries**
/// were restated, including `2 Kings 19-20` → 「列王纪下 19」,
/// `Acts 27:27-28:1` → 「使徒行传 27:27」, `Daniel 2, 7, 8, 11` →
/// 「但以理书 2」 and `Jude 14-15` → 「犹大书 1:14」. The reference is the
/// one line on that card a reader copies out, so it is held to the
/// scripture-accuracy rule rather than treated as formatting.
void main() {
  /// The chapter/verse tail of a reference: the last run of digits and
  /// reference punctuation. Excludes CJK and Latin letters on purpose,
  /// so the same expectation holds in every locale — the book name is
  /// allowed to change, the citation is not.
  final tail = RegExp(r'[0-9][0-9:：.,\-–—\s]*$');
  String citedTail(String segment) {
    final m = tail.firstMatch(segment);
    return (m?.group(0) ?? '').replaceAll(RegExp(r'\s+'), '');
  }

  group('localizedReferenceLabel keeps the citation it was given', () {
    test('every Bible Evidence reference survives localization intact', () {
      final asset =
          jsonDecode(File('assets/bible_evidence.json').readAsStringSync());
      final entries =
          (asset['evidences'] as List).cast<Map<String, dynamic>>();
      expect(entries.length, greaterThan(200),
          reason: 'the asset should not have shrunk');

      final narrowed = <String>[];
      for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
        for (final entry in entries) {
          final raw = (entry['scriptureReference'] as String? ?? '').trim();
          if (raw.isEmpty) continue;
          final label = localizedReferenceLabel(raw, locale);
          final rawSegments = raw.split(';');
          final labelSegments = label.split(';');
          if (rawSegments.length != labelSegments.length) {
            narrowed.add('${entry['id']} [$locale] lost a segment: '
                '"$raw" -> "$label"');
            continue;
          }
          for (var i = 0; i < rawSegments.length; i++) {
            final want = citedTail(rawSegments[i].trim());
            final got = citedTail(labelSegments[i].trim());
            if (want != got) {
              narrowed.add('${entry['id']} [$locale] "$raw" -> "$label" '
                  '(cited "$want", printed "$got")');
            }
          }
        }
      }
      expect(narrowed, isEmpty,
          reason: 'these entries print a different passage from the one '
              'they cite:\n${narrowed.join('\n')}');
    });

    test('the citations that used to be narrowed now print in full', () {
      // One case per shape of loss, all taken from the real asset.
      expect(localizedReferenceLabel('2 Kings 19-20; Isaiah 37-39', 'zh-Hans'),
          '列王纪下 19-20; 以赛亚书 37-39'); // chapter range
      expect(localizedReferenceLabel('Acts 27:27-28:1', 'zh-Hans'),
          '使徒行传 27:27-28:1'); // cross-chapter verse range
      expect(localizedReferenceLabel('Daniel 2, 7, 8, 11', 'zh-Hans'),
          '但以理书 2, 7, 8, 11'); // comma-separated chapters
      expect(localizedReferenceLabel('John 18:31-33, 37-38', 'zh-Hans'),
          '约翰福音 18:31-33, 37-38'); // comma-separated verse spans
      expect(localizedReferenceLabel('2 Kings 9:2–10:36', 'zh-Hans'),
          '列王纪下 9:2–10:36'); // en dash, not a hyphen
      // Jude is a one-chapter book, so "14-15" is verses. Printing it as
      // 「犹大书 1:14」 both re-punctuated the citation and dropped v15.
      expect(localizedReferenceLabel('Jude 14-15', 'zh-Hans'), '犹大书 14-15');
    });

    test('a leading digit belongs to the book, not to the chapter', () {
      // The split point is found by scanning for a digit, so the numbered
      // books are the case that decides whether the scan is correct.
      expect(localizedReferenceLabel('1 Corinthians 13:4-7', 'zh-Hans'),
          '哥林多前书 13:4-7');
      expect(localizedReferenceLabel('1 Kings 5-7', 'zh-Hans'), '列王纪上 5-7');
      expect(localizedReferenceLabel('2 Samuel 5:9', 'en'), '2 Samuel 5:9');
    });

    test('the book name is still localized', () {
      // Guards against the trivial way of passing everything above:
      // returning the raw string untouched.
      expect(localizedReferenceLabel('Genesis 6-9', 'zh-Hans'), '创世纪 6-9');
      expect(localizedReferenceLabel('Genesis 6-9', 'zh-Hant'), '創世紀 6-9');
      expect(localizedReferenceLabel('Genesis 6-9', 'en'), 'Genesis 6-9');
    });
  });
}
