import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/constants/bible_versions.dart';
import 'package:yswords/services/daily_verse_fallback.dart';

/// 2026-06-11 audit: regression coverage for the d1eb87b daily-verse
/// fallback. LJK1/LJK2 (biblexg*) ship NT only; an OT daily verse on
/// those versions used to render an empty card. The fallback resolves
/// the verse from the same-language full-canon CUVS-YHWH bundle.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bibleVersionFullCanonFallback mapping', () {
    test('NT-only Simplified versions fall back to cuvs-yhwh', () {
      expect(bibleVersionFullCanonFallback('biblexg'), 'cuvs-yhwh');
      expect(bibleVersionFullCanonFallback('biblexg-v2'), 'cuvs-yhwh');
    });

    test('NT-only Traditional versions fall back to cuvs-yhwh-tr', () {
      expect(bibleVersionFullCanonFallback('biblexg-tr'), 'cuvs-yhwh-tr');
      expect(
          bibleVersionFullCanonFallback('biblexg-v2-tr'), 'cuvs-yhwh-tr');
    });

    test('full-canon versions have no fallback', () {
      expect(bibleVersionFullCanonFallback('nasb'), isNull);
      expect(bibleVersionFullCanonFallback('kjv'), isNull);
      expect(bibleVersionFullCanonFallback('cuvs-yhwh'), isNull);
      expect(bibleVersionFullCanonFallback('cuv'), isNull);
    });
  });

  group('fallbackVersionLabel', () {
    test('labels the fallback with its menu label', () {
      final expected = bibleVersions
          .firstWhere((v) => v.value == 'cuvs-yhwh')
          .menuLabel;
      expect(DailyVerseFallback.fallbackVersionLabel('biblexg'), expected);
    });

    test('null for versions without a fallback', () {
      expect(DailyVerseFallback.fallbackVersionLabel('nasb'), isNull);
    });
  });

  group('resolve (loads the real cuvs-yhwh asset)', () {
    test('full-canon current version → null without loading anything',
        () async {
      final r = await DailyVerseFallback.resolve(
        englishBook: 'Genesis',
        chapter: 1,
        verseNumber: 1,
        currentVersion: 'nasb',
      );
      expect(r, isNull);
    });

    test('OT verse on an NT-only version resolves via cuvs-yhwh',
        () async {
      final r = await DailyVerseFallback.resolve(
        englishBook: 'Genesis',
        chapter: 1,
        verseNumber: 1,
        currentVersion: 'biblexg',
      );
      expect(r, isNotNull,
          reason: 'Genesis 1:1 must resolve from the cuvs-yhwh bundle');
      expect(r!.fromVersion, 'cuvs-yhwh');
      expect(r.verse.chapter, 1);
      expect(r.verse.verse, 1);
      expect(r.verse.text, isNotEmpty);
    });

    test('nonexistent verse returns null instead of throwing', () async {
      final r = await DailyVerseFallback.resolve(
        englishBook: 'Genesis',
        chapter: 99,
        verseNumber: 99,
        currentVersion: 'biblexg',
      );
      expect(r, isNull);
    });
  });
}
