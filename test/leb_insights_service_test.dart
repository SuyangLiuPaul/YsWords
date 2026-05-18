// Tests for v1.2.53's cross-version translator-insights overlay.
//
// Covers:
//   • Service starts un-ready and becomes ready after `init()`.
//   • Lookups return expected notes for known LEB-annotated verses.
//   • Lookups translate localised book names via `bookNameToEnglish`
//     so reading the same verse on CUVS-YHWH (创世记) or CUV-TR
//     (創世記) returns the same notes as reading Genesis.
//   • LEB-asset truncated names (`Mic` / `Nah`) are aliased to
//     canonical English (`Micah` / `Nahum`) on load so a reader
//     on Micah / Nahum hits the right entry.
//   • Lookups for Judges + Obadiah return empty (those two books
//     are missing from the bundled LEB asset; the service must
//     fail gracefully).
//   • Verses with no LEB note return an empty list.
//   • init() is idempotent — calling it twice doesn't double-load.

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/services/leb_insights_service.dart';

void main() {
  // Required so rootBundle.loadString hits the test asset bundle.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LebInsightsService', () {
    setUpAll(() async {
      // Single shared instance — each group runs sequentially in a
      // single isolate. init() is idempotent so repeated calls
      // from earlier test groups (if any) are safe.
      await LebInsightsService.instance.init();
    });

    test('is ready after init()', () {
      expect(LebInsightsService.instance.isReady, isTrue);
    });

    test('reports a non-trivial number of annotated verses', () {
      // The bundled LEB asset annotates ~14.4 k of its ~30.5 k
      // verses (some verses carry multiple notes; the total note
      // count is ~23 k). Pin to a generous lower bound so an
      // unintended asset shrink is caught; 10 k gives ~4 k
      // headroom.
      expect(LebInsightsService.instance.annotatedVerseCount,
          greaterThan(10000));
    });

    test('Genesis 1:2 has the expected "Or \\"And\\"" note', () {
      final notes =
          LebInsightsService.instance.notesFor('Genesis', 1, 2);
      expect(notes, isNotEmpty);
      // The LEB asset shows the note as `Or "And"` — the leading
      // article variant on the conjunction.
      expect(notes.first.contains('Or'), isTrue);
    });

    test('Genesis 1:1 returns no notes (no annotation in LEB)', () {
      final notes =
          LebInsightsService.instance.notesFor('Genesis', 1, 1);
      expect(notes, isEmpty);
    });

    test('Simplified Chinese book name resolves via bookNameToEnglish',
        () {
      final notesEn =
          LebInsightsService.instance.notesFor('Genesis', 1, 2);
      final notesCn =
          LebInsightsService.instance.notesFor('创世记', 1, 2);
      expect(notesCn, notesEn);
    });

    test(
        'Traditional Chinese book name resolves via bookNameToEnglish',
        () {
      final notesEn =
          LebInsightsService.instance.notesFor('Genesis', 1, 2);
      final notesTr =
          LebInsightsService.instance.notesFor('創世記', 1, 2);
      expect(notesTr, notesEn);
    });

    test('Micah lookup hits the aliased "Mic" entries', () {
      // LEB ships with the truncated `Mic` book name. The service
      // aliases it to canonical Micah on load so callers looking
      // up by "Micah" still find the notes. Mic 1:1 has no note;
      // Mic 1:2 does (`Literally "the temple of his holiness"`)
      // so we check that one.
      final byCanonical =
          LebInsightsService.instance.notesFor('Micah', 1, 2);
      expect(byCanonical, isNotEmpty,
          reason: 'Micah 1:2 should have at least one LEB note via '
              'the Mic→Micah alias.');
    });

    test('Nahum lookup hits the aliased "Nah" entries', () {
      // Same alias pattern: Nah 1:1 has no note; Nah 1:2 does
      // (`Literally "a lord of wrath"`).
      final byCanonical =
          LebInsightsService.instance.notesFor('Nahum', 1, 2);
      expect(byCanonical, isNotEmpty,
          reason: 'Nahum 1:2 should have at least one LEB note via '
              'the Nah→Nahum alias.');
    });

    test('Judges 1:1 returns empty (book absent from LEB asset)', () {
      // Verified during the v1.2.53 audit — LEB asset has no
      // Judges entries at all. Service must return an empty list
      // (not throw, not log a 404).
      final notes =
          LebInsightsService.instance.notesFor('Judges', 1, 1);
      expect(notes, isEmpty);
    });

    test('Obadiah 1:1 returns empty (book absent from LEB asset)',
        () {
      final notes =
          LebInsightsService.instance.notesFor('Obadiah', 1, 1);
      expect(notes, isEmpty);
    });

    test('init() is idempotent — second call is a no-op', () async {
      final before = LebInsightsService.instance.annotatedVerseCount;
      await LebInsightsService.instance.init();
      final after = LebInsightsService.instance.annotatedVerseCount;
      expect(after, before);
    });

    test('lookup with non-existent book returns empty without error',
        () {
      final notes =
          LebInsightsService.instance.notesFor('Nonexistent', 1, 1);
      expect(notes, isEmpty);
    });

    test('lookup with out-of-range chapter:verse returns empty', () {
      final notes =
          LebInsightsService.instance.notesFor('Genesis', 999, 999);
      expect(notes, isEmpty);
    });
  });
}
