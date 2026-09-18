import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:yahwehs_words/constants/bible_versions.dart'
    show availableVersions, bibleVersions, disabledVersions;
import 'package:yahwehs_words/services/offline_pack_service.dart';
import 'package:yahwehs_words/constants/section_title_map.dart'
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

  test('every OFFERED English version is in the offline pack', () async {
    // 2026-09-14. Two things changed here and they pull in opposite
    // directions, so both are spelled out.
    //
    // The source-text parse is gone: `_bibleUrls` is no longer a literal
    // to parse but a derivation over `availableVersions`, so this asks the
    // service what it would fetch. That is strictly better — the old
    // parse would have gone on passing if `_bibleUrls` had been correct in
    // source and wrong at runtime.
    //
    // And the subject narrowed from "every English version" to every
    // English version the picker OFFERS. `nasb` is language:"en" and in
    // `disabledVersions`, and it was the reason this test now reads this
    // way: the old assertion demanded the pack fetch it, the pack did,
    // and `tools/release_web.sh` deletes `assets/nasb.json` out of
    // `build/web` — so the test was enforcing a guaranteed 404 on every
    // reader who downloaded the Bibles pack. The other two lists below
    // still cover ALL English editions, hidden included, and correctly:
    // a hidden edition is still resolved by name, so its book names and
    // section titles must still work.
    final assets = {
      for (final url in await OfflinePackService.instance
          .debugUrlsFor(OfflinePackCategory.bibles))
        url.replaceFirst('assets/', '').replaceFirst('.json', ''),
    };
    for (final v in englishVersions.where(
        (v) => availableVersions.any((a) => a.value == v))) {
      expect(assets, contains(v),
          reason:
              '"$v" is an offered English edition but assets/$v.json is '
              'not in what the offline pack fetches — the pack will '
              'silently skip it');
    }
    for (final v in englishVersions.where(disabledVersions.contains)) {
      expect(assets, isNot(contains(v)),
          reason:
              '"$v" is hidden from the picker, so the pack must not '
              'download it — for `nasb` the fetch cannot even succeed, '
              'because release_web.sh strips the asset from prod');
    }
  });
}
