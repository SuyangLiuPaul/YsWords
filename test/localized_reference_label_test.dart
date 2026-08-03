import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/utils/version_mapper.dart';

void main() {
  group('localizedReferenceLabel', () {
    test('single verse, English locale passes through unchanged', () {
      expect(localizedReferenceLabel('2 Samuel 5:9', 'en'), '2 Samuel 5:9');
    });

    test('single verse, Simplified Chinese locale translates the book', () {
      expect(localizedReferenceLabel('2 Samuel 5:9', 'zh-Hans'),
          '撒母耳记下 5:9');
    });

    test('single verse, Traditional Chinese locale translates the book', () {
      expect(localizedReferenceLabel('2 Samuel 5:9', 'zh-Hant'),
          '撒母耳記下 5:9');
    });

    test('verse range is preserved after localization', () {
      expect(localizedReferenceLabel('Genesis 1:1-3', 'zh-Hans'),
          '创世纪 1:1-3');
    });

    test('whole-chapter reference (no verse) is preserved', () {
      expect(localizedReferenceLabel('John 3', 'zh-Hans'), '约翰福音 3');
    });

    test('currentVersion overrides locale-driven book naming', () {
      // Traditional-script version name should win even under a
      // Simplified locale, matching localeAwareBookName's own
      // currentVersion precedence.
      expect(
          localizedReferenceLabel('Genesis 1:1', 'zh-Hans', 'cuvs-tr'),
          '創世紀 1:1');
    });

    test('multi-book reference localizes each segment', () {
      expect(
          localizedReferenceLabel(
              'Matthew 5:3-12; Luke 6:20-23', 'zh-Hans'),
          '马太福音 5:3-12; 路加福音 6:20-23');
    });

    test('unparseable segment falls back to the raw text unchanged', () {
      expect(localizedReferenceLabel('Multiple Books', 'zh-Hans'),
          'Multiple Books');
    });

    test('empty locale-independent default (no locale-specific mapping) keeps English', () {
      expect(localizedReferenceLabel('Genesis 1:1', 'fr'), 'Genesis 1:1');
    });
  });
}
