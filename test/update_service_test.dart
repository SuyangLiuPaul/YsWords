import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/constants/app_version.dart';
import 'package:yswords/services/update_service.dart';

void main() {
  group('UpdateService.repo', () {
    // 2026-08-30: this string constant was 'SuyangLiuPaul/Yahweh\'s Words'
    // for months — the real GitHub repo is 'SuyangLiuPaul/YsWords'. The
    // wrong slug 404s, checkForUpdate() swallows every non-200 into a
    // silent null, and the About tile has reported "couldn't check" for
    // its entire life with no test ever failing. Pin the exact string so
    // a future rename (of the app's DISPLAY name, which legitimately is
    // "Yahweh's Words") can't leak back into this constant.
    test('is the real GitHub repo slug, not the app display name', () {
      expect(UpdateService.repo, 'SuyangLiuPaul/YsWords');
    });

    test('no source file under lib/ still carries the old slug', () {
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final content = entity.readAsStringSync();
        if (content.contains("SuyangLiuPaul/Yahweh") ||
            content.contains('SuyangLiuPaul%2FYahweh')) {
          offenders.add(entity.path);
        }
      }
      expect(offenders, isEmpty,
          reason: 'these files still reference the 404ing repo slug: '
              '$offenders');
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
