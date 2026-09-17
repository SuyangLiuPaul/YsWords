import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/constants/app_version.dart';
import 'package:yswords/services/update_service.dart';

void main() {
  group('UpdateService.repo', () {
    // 2026-08-30: this string constant was 'SuyangLiuPaul/Yahweh\'s Words'
    // for months — the wrong slug 404s, checkForUpdate() swallows every
    // non-200 into a silent null, and the About tile reported "couldn't
    // check" for its entire life with no test ever failing.
    //
    // 2026-09-18: the repository was renamed to `Yahwehs-Words`, so the
    // literal this test pinned became the stale one — and a literal
    // against a literal could never have caught that. It asks the
    // CHECKOUT instead: whatever remote this working copy pushes to is
    // the repository whose releases the updater must read. GitHub
    // redirects an old name for a while, which is exactly what makes
    // this failure quiet enough to need a test.
    test('is the repository this checkout actually belongs to', () {
      final config = File('.git/config').readAsStringSync();
      final match = RegExp(r'github\.com[/:]([\w.-]+/[\w.-]+?)(?:\.git)?\s')
          .firstMatch(config);
      expect(match, isNotNull,
          reason: 'no github remote in .git/config, so this test cannot '
              'tell what the right answer is');
      expect(UpdateService.repo, match!.group(1),
          reason: 'the updater is asking GitHub about a different '
              'repository than the one this code is pushed to');
    });

    test('every repo slug under lib/ is one GitHub could resolve', () {
      // This used to look for the literal string "SuyangLiuPaul/Yahweh",
      // which was the broken slug — and on 2026-09-18 became the prefix
      // of the CORRECT one (`Yahwehs-Words`), so the guard would have
      // failed the rename it was meant to survive.
      //
      // What was actually wrong with the old value is that
      // `Yahweh's Words` is not a repository name: an apostrophe and a
      // space cannot appear in one. So that is what this asks.
      final bad = <String>[];
      final slug = RegExp('SuyangLiuPaul/([^\\s\'")]*)');
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        for (final m in slug.allMatches(entity.readAsStringSync())) {
          final name = m.group(1) ?? '';
          if (!RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(name)) {
            bad.add('${entity.path}: "$name"');
          }
        }
      }
      expect(bad, isEmpty,
          reason: 'a GitHub repository name is letters, digits, dot, dash '
              'and underscore — these are not names, so they 404 and the '
              'update check goes quiet: $bad');
    });
  });

  group('kAppVersion fallback', () {
    // The durable half of this fix: whatever bump_version.sh last wrote
    // into app_version.dart's two literals must equal pubspec.yaml's
    // version. This is what fails the moment the two drift again — the
    // exact failure mode that let the fallback sit at 1.3.113 for two
    // months while pubspec moved to 1.4.170.
    test('equals pubspec.yaml, so the update check never sees a phantom '
        'downgrade', () {
      // Mirrors bump_version.sh's own `awk '/^version:/'` extraction —
      // a single root-level `version:` line, build metadata (`+N`)
      // stripped, the same way the script strips it before bumping.
      final line = File('pubspec.yaml')
          .readAsLinesSync()
          .firstWhere((l) => l.startsWith('version:'));
      final pubspecVersion = line.split(':')[1].trim().split('+').first;
      expect(kAppVersion, pubspecVersion);
    });

    test('a real latest release is never "newer" than a correct fallback',
        () {
      // Measured 2026-08-30: GitHub's actual latest release tag is v1.4.6.
      // If the fallback drifts stale again, isNewer would go true and the
      // About tile would tell a reader on 1.4.170 to "update" to 1.4.6 —
      // the phantom-downgrade prompt this whole fix exists to prevent.
      expect(UpdateService.isNewer('1.4.6', kAppVersion), isFalse);
    });
  });

  group('UpdateService.stripV', () {
    test('strips a leading v', () {
      expect(UpdateService.stripV('v1.3.88'), '1.3.88');
    });
    test('leaves a bare version untouched', () {
      expect(UpdateService.stripV('1.3.88'), '1.3.88');
    });
  });

  group('UpdateService.isNewer', () {
    test('patch bump is newer', () {
      expect(UpdateService.isNewer('1.3.88', '1.3.87'), isTrue);
    });
    test('minor bump is newer', () {
      expect(UpdateService.isNewer('1.4.0', '1.3.99'), isTrue);
    });
    test('major bump is newer', () {
      expect(UpdateService.isNewer('2.0.0', '1.9.9'), isTrue);
    });
    test('same version is NOT newer', () {
      expect(UpdateService.isNewer('1.3.87', '1.3.87'), isFalse);
    });
    test('older latest is NOT newer (no accidental downgrade prompt)', () {
      expect(UpdateService.isNewer('1.3.86', '1.3.87'), isFalse);
    });
    test('numeric compare, not lexicographic (10 > 9)', () {
      expect(UpdateService.isNewer('1.3.10', '1.3.9'), isTrue);
    });
    test('tolerates a missing patch segment', () {
      expect(UpdateService.isNewer('1.4', '1.3.99'), isTrue);
      expect(UpdateService.isNewer('1.3', '1.3.0'), isFalse);
    });
  });
}
