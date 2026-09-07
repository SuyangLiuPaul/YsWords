import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:yswords/constants/bible_versions.dart' show bibleVersions;
import 'package:yswords/constants/section_title_map.dart'
    show sectionTitleSetByVersion;

/// Every English-language `BibleVersionInfo` must be wired into three
/// membership lists elsewhere in the codebase, or it silently degrades:
///
///   * `_englishVersionCodes` (`book_name_mapping.dart`) — omission makes
///     `toLocale`/`translateBookName` route the version through the
///     Chinese book-name table, which breaks any lookup keyed on the
///     translated name (e.g. jumping to a cross-reference or concordance
///     hit — `bible_reading_pane.dart`'s `_navigateToConcordanceRef` and
///     the Highlights-sheet `onNavigate`, both of which match
///     `v.book == translateBookName(...)`).
///   * `sectionTitleSetByVersion` (`section_title_map.dart`) — omission
///     means the reading pane shows no section headings for that version.
///   * `_bibleUrls` (`offline_pack_service.dart`) — omission means the
///     offline pack silently skips that version's asset.
///
/// Found 2026-09-07: CSB (added the same hour, `bible_versions.dart`)
/// was missing from all three. `_englishVersionCodes` and `_bibleUrls`
/// are private, so this test parses their literal source text the same
/// way `book_name_table_parity_test.dart` and
/// `offline_pack_counts_test.dart` already do for other private tables
/// in this codebase — there is no build-time way to reach a private
/// top-level `const` from another library.
Set<String> _englishVersionCodesFromSource() {
  final src =
      File('lib/constants/book_name_mapping.dart').readAsStringSync();
  final block = RegExp(r'const _englishVersionCodes = <String>\{(.*?)\n\};',
          dotAll: true)
      .firstMatch(src);
  if (block == null) {
    throw StateError('the _englishVersionCodes block moved or changed shape');
  }
  final body = block.group(1)!.replaceAll(RegExp(r'//[^\n]*'), '');
  return {for (final m in RegExp(r"'([^']+)'").allMatches(body)) m.group(1)!};
}

Set<String> _bibleUrlAssetsFromSource() {
  final src = File('lib/services/offline_pack_service.dart').readAsStringSync();
  final block = RegExp(r'_bibleUrls = \[(.*?)\n  \];', dotAll: true)
      .firstMatch(src);
  if (block == null) {
    throw StateError('the _bibleUrls block moved or changed shape');
  }
  final body = block.group(1)!.replaceAll(RegExp(r'//[^\n]*'), '');
  return {
    for (final m in RegExp(r"'assets/([^']+)\.json'").allMatches(body))
      m.group(1)!,
  };
}

void main() {
  final englishVersions = bibleVersions
      .where((v) => v.language == 'en')
      .map((v) => v.value)
      .toList();

  test('every English version is in _englishVersionCodes', () {
    final codes = _englishVersionCodesFromSource();
    for (final v in englishVersions) {
      expect(codes, contains(v),
          reason:
              '"$v" is language:"en" in bibleVersions but missing from '
              '_englishVersionCodes — its book names will render in '
              'Chinese and any lookup keyed on the translated name will '
              'never match');
    }
  });

  test('every English version is in sectionTitleSetByVersion', () {
    for (final v in englishVersions) {
      expect(sectionTitleSetByVersion, contains(v),
          reason:
              '"$v" is language:"en" in bibleVersions but missing from '
              'sectionTitleSetByVersion — its reading pane will show no '
              'section headings');
    }
  });

  test('every English version is in offline pack _bibleUrls', () {
    final assets = _bibleUrlAssetsFromSource();
    for (final v in englishVersions) {
      expect(assets, contains(v),
          reason:
              '"$v" is language:"en" in bibleVersions but '
              'assets/$v.json is missing from offline_pack_service.dart\'s '
              '_bibleUrls — the offline pack will silently skip it');
    }
  });
}
