import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/services/update_service.dart';

void main() {
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
