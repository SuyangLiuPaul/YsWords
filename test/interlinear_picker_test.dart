import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:yswords/constants/bible_versions.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/services/tagged_text_service.dart';
import 'package:yswords/utils/interlinear_editions.dart';

/// The Exegesis sheet's interlinear picker: which rows it may show, and
/// which row it opens on.
///
/// 「words要看选择可以看到的有数字的和翻译可以选版本的」 (owner,
/// 2026-09-08) — the reader should see the numbered line, and the
/// translation should let them pick a version.
///
/// The rule the tests below exist for is that the offer is an
/// INTERSECTION of "has a tagged layer" and "this app will show this
/// edition at all", computed rather than written down. A hand-written
/// list is how a withdrawn edition silently comes back, and this repo
/// has a live example sitting one file away: `nasb` is in
/// `disabledVersions` at the owner's instruction, its asset still ships
/// inside the native binary, and the only thing keeping it out of every
/// list in the app is that every list is computed.
void main() {
  test('the picker offers exactly the tagged editions the app will show, '
      'in catalogue order', () {
    expect(interlinearEditions,
        ['bsb-yhwh', 'asv-yhwh', 'cuvs-yhwh', 'cuvs-yhwh-tr']);
  });

  test('every offered code is in BOTH halves of the intersection', () {
    // The property, not the list — this is what stays true when a fifth
    // edition is tagged.
    for (final code in interlinearEditions) {
      expect(TaggedTextService.supports(code), isTrue,
          reason: '$code is offered and has no tagged layer');
      expect(availableVersions.map((v) => v.value), contains(code),
          reason: '$code is offered and the app does not show it anywhere');
    }
  });

  test('a hidden edition cannot be offered, however it came to be hidden',
      () {
    for (final hidden in disabledVersions) {
      expect(interlinearEditions, isNot(contains(hidden)));
    }
  });

  test('every tagged edition is declared in pubspec.yaml', () {
    // The failure this catches is a row in the picker that opens an
    // asset the shipped app does not contain — the reader taps a
    // translation by name and gets a blank line.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final code in TaggedTextService.taggedVersions) {
      expect(pubspec, contains('assets/tagged/$code/'),
          reason: '$code is in TaggedTextService.taggedVersions and is not '
              'declared in pubspec.yaml');
      expect(Directory('assets/tagged/$code').existsSync(), isTrue,
          reason: 'assets/tagged/$code does not exist on disk');
    }
    // And the other direction: a directory in the bundle that nothing
    // can reach is 13 MB of dead weight in every install.
    final onDisk = Directory('assets/tagged')
        .listSync()
        .whereType<Directory>()
        .map((d) => d.path.split('/').last)
        .toSet();
    expect(onDisk, TaggedTextService.taggedVersions);
  });

  group('resolveInterlinearEdition', () {
    test('the reader\'s own standing pick wins', () {
      final choice = resolveInterlinearEdition(
          chosen: 'asv-yhwh', currentVersion: 'cuvs-yhwh');
      expect(choice.version, 'asv-yhwh');
      expect(choice.source, InterlinearSource.chosen);
    });

    test('a stored pick that is no longer offered is ignored, not honoured',
        () {
      // An edition can leave `availableVersions` between one launch and
      // the next; a stored code is not a promise that it still exists.
      final choice = resolveInterlinearEdition(
          chosen: 'nasb', currentVersion: 'cuvs-yhwh');
      expect(choice.version, 'cuvs-yhwh');
      expect(choice.source, InterlinearSource.current);
    });

    test('with no pick, the sheet opens on the edition being read', () {
      for (final code in interlinearEditions) {
        final choice = resolveInterlinearEdition(currentVersion: code);
        expect(choice.version, code);
        expect(choice.source, InterlinearSource.current);
      }
    });

    test('an untagged edition falls back inside its OWN script', () {
      // The whole point of deriving `cuvs-yhwh-tr` was that a 繁體
      // reader should not be handed the Simplified edition. SeekSparks
      // folds zh-Hans and zh-Hant together because it has no Traditional
      // tagged set; this app has one, so it must not.
      final trad = resolveInterlinearEdition(currentVersion: 'biblexg-v2-tr');
      expect(trad.version, 'cuvs-yhwh-tr');
      expect(trad.source, InterlinearSource.substituted);

      final simp = resolveInterlinearEdition(currentVersion: 'biblexg-v2');
      expect(simp.version, 'cuvs-yhwh');
      expect(simp.source, InterlinearSource.substituted);

      final en = resolveInterlinearEdition(currentVersion: 'kjv');
      expect(en.version, 'bsb-yhwh');
      expect(en.source, InterlinearSource.substituted);
    });

    test('the Greek NT falls back to the neighbour the CATALOGUE already '
        'names for it', () {
      // `wh` is the one edition whose language family has no tagged
      // member. `bibleVersionFullCanonFallback('wh')` answers "which
      // English to show beside a Greek text" — the BSB, a modern
      // translation of the same critical text — and asking it again
      // here means the Exegesis sheet and the daily-verse card agree.
      expect(bibleVersionFullCanonFallback('wh'), 'bsb-yhwh');
      final choice = resolveInterlinearEdition(currentVersion: 'wh');
      expect(choice.version, 'bsb-yhwh');
      expect(choice.source, InterlinearSource.substituted);
    });

    test('an unknown code is not guessed at as Chinese', () {
      // `bibleVersionLanguage` returns zh-Hans for a code it does not
      // know. Steering a fallback off that guess would hand an imported
      // English edition the Chinese interlinear.
      final choice = resolveInterlinearEdition(currentVersion: 'imported-x');
      expect(choice.version, interlinearEditions.first);
      expect(choice.source, InterlinearSource.substituted);
    });

    test('no current version at all still lands somewhere', () {
      final choice = resolveInterlinearEdition();
      expect(choice.version, interlinearEditions.first);
      expect(choice.source, InterlinearSource.substituted);
    });
  });

  test('every string the picker prints exists in all three locales', () {
    const keys = [
      'interlinearVersion',
      'interlinearSubstituted',
      'interlinearVerseMissing',
      'interlinearNone',
    ];
    for (final k in keys) {
      final row = uiStrings[k];
      expect(row, isNotNull, reason: '$k is missing from ui_strings.dart');
      for (final locale in ['zh-Hans', 'zh-Hant', 'en']) {
        expect(row![locale], isNotNull,
            reason: '$k has no $locale translation');
        expect((row[locale] as String).trim(), isNotEmpty);
      }
    }
    // The two that interpolate must keep their placeholders in every
    // locale, or a reader is told "carries no alignment, so the line
    // below is ." with the edition name missing.
    for (final locale in ['zh-Hans', 'zh-Hant', 'en']) {
      expect(uiStrings['interlinearSubstituted']![locale]!,
          allOf(contains('{reading}'), contains('{shown}')));
      expect(uiStrings['interlinearVerseMissing']![locale]!,
          contains('{shown}'));
    }
  });

  test('every offered edition has a full label that is not just its code',
      () {
    for (final code in interlinearEditions) {
      expect(fullBibleVersionLabel(code), isNot(code),
          reason: 'the picker would show a reader the bare code $code — '
              'which is the complaint the full label exists to answer');
    }
  });
}
