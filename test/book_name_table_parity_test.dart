import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/constants/book_names.dart' show bookNameToEnglish;

/// `bookNameToEnglish` (this package) and `_zhAliasToEn`
/// (`book_name_mapping.dart`) are two independently-maintained tables of
/// the same 135 Chinese book-name spellings. They drifted once already —
/// 约拿记/約拿記 and 哥罗西书/哥羅西書 were added to `_zhAliasToEn` by later
/// queue items and never mirrored here, and 啓示錄 was added to
/// `_zhAliasToEn` only — found 2026-09-01.
///
/// `_zhAliasToEn` is private AND cannot be derived from `bookNameToEnglish`
/// at build time: `test/sermon_ref_extraction_test.dart` and
/// `scripts/extract_sermon_refs.py` both parse its literal source text
/// with a regex (`const _zhAliasToEn = \{...\n\};`), so it must stay a
/// hand-written `const` map. This test is the drift detector instead: it
/// also reads the source text, and fails the moment the two CJK key sets
/// (or their values) disagree.
Map<String, String> _zhAliasToEnFromSource() {
  final src = File('lib/constants/book_name_mapping.dart').readAsStringSync();
  final block =
      RegExp(r'const _zhAliasToEn = \{(.*?)\n\};', dotAll: true).firstMatch(src);
  if (block == null) {
    throw StateError('the _zhAliasToEn block moved or changed shape');
  }
  return {
    for (final m
        in RegExp(r"'([^']+)'\s*:\s*'([^']+)'").allMatches(block.group(1)!))
      m.group(1)!: m.group(2)!,
  };
}

bool _isCjk(String s) => s.codeUnits.any((c) => c > 0x7f);

void main() {
  test('bookNameToEnglish and _zhAliasToEn cover the same CJK spellings', () {
    final bnCjk = <String, String>{
      for (final e in bookNameToEnglish.entries)
        if (_isCjk(e.key)) e.key: e.value,
    };
    final aliasCjk = _zhAliasToEnFromSource();

    final missingFromBookNames = aliasCjk.keys.toSet().difference(bnCjk.keys.toSet());
    final missingFromAlias = bnCjk.keys.toSet().difference(aliasCjk.keys.toSet());

    expect(
      missingFromBookNames,
      isEmpty,
      reason: 'spellings in _zhAliasToEn but missing from bookNameToEnglish',
    );
    expect(
      missingFromAlias,
      isEmpty,
      reason: 'spellings in bookNameToEnglish but missing from _zhAliasToEn',
    );

    for (final key in aliasCjk.keys) {
      if (!bnCjk.containsKey(key)) continue;
      expect(
        bnCjk[key],
        aliasCjk[key],
        reason: '"$key" maps to different English names in the two tables',
      );
    }
  });
}
