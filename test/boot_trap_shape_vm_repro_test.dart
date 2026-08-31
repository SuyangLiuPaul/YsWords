import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/fetch_books.dart';
import 'package:yswords/services/fetch_verses.dart';
import 'package:yswords/services/profile_service.dart';
import 'package:yswords/services/url_sync_service.dart';
import 'package:yswords/utils/jump_to_reference.dart' as jumper;
import 'package:yswords/utils/reference_parser.dart';

/// 2026-08-31: VM-side repro attempt for the mailed-in boot crash —
/// `Invalid argument: 0`, web release only, on an origin whose only
/// stored state is the unscoped `book` / `chapter` / `version` legacy
/// keys with no `profile.*` keys at all (queue: `docs/autonomous-queue.md`,
/// "a boot crash the app cannot recover from on its own").
///
/// The mitigation shipped 2026-08-31 (`legacy_reading_position_quarantine
/// .dart`) works around the SHAPE without explaining the throw, and it
/// only runs from the splash's 45s auto-recovery path — NOT from a plain
/// cold boot — so it does not interfere with reproducing the original
/// trap here. This test skips straight past it and drives the same
/// sequence `lib/main.dart`'s `_bootstrap()` awaits, end to end, on the
/// Dart VM: `ProfileService.init()` → `AppSettings.loadSettings()` →
/// `MainProvider.restoreState()` → `FetchVerses.execute()` →
/// `FetchBooks.execute()` → the post-load "validate restored state or
/// fallback" block → a deep-link-shaped jump via
/// `jump_to_reference.resolveAndPrepareJump` (the function
/// `UrlSyncService`'s web-only hash handler ultimately feeds into; the
/// VM build of `UrlSyncService` itself is the no-op stub, so it is
/// called here too for completeness but cannot exercise real hash
/// parsing).
///
/// If none of this throws, that is itself a result, not a null test:
/// it narrows the defect to something reachable only through dart2js
/// codegen or `shared_preferences_web`'s localStorage decoding, neither
/// of which the VM build exercises. See the queue entry for what to try
/// next in that case.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'trap shape (book/chapter/version only, no profile.* keys) '
    'survives the full boot sequence on the VM without throwing',
    () async {
      SharedPreferences.setMockInitialValues({
        'book': 'John',
        'chapter': 3,
        'version': 'kjv',
      });

      final appSettings = AppSettings();
      final mp = MainProvider();

      await ProfileService.instance.init();
      await appSettings.loadSettings();
      await mp.restoreState();

      if (mp.verses.isEmpty) {
        await FetchVerses.execute(mainProvider: mp);
      }
      await FetchBooks.execute(mainProvider: mp);

      // Mirrors lib/main.dart's post-load "validate restored state or
      // fallback" block verbatim (not extracted into a shared helper
      // there, so duplicated here rather than reached through).
      if (mp.currentBook != null &&
          mp.currentChapter != null &&
          mp.verses.any((v) =>
              v.book == mp.currentBook && v.chapter == mp.currentChapter)) {
        final match = mp.verses.firstWhere(
          (v) => v.book == mp.currentBook && v.chapter == mp.currentChapter,
          orElse: () => mp.verses.first,
        );
        mp.updateCurrentVerse(verse: match);
      } else if (mp.verses.isNotEmpty) {
        final firstVerse = mp.verses.first;
        mp.setCurrentChapter(book: firstVerse.book, chapter: firstVerse.chapter);
        mp.updateCurrentVerse(verse: firstVerse);
      }

      // Real boot order: URL sync (no-op stub on the VM) runs after
      // restoreState + the fetches, same as _bootstrap().
      await UrlSyncService.init(mainProvider: mp, appSettings: appSettings);

      // Exercise the function the web hash handler ultimately calls,
      // with a reference shaped like a real shared link into the
      // restored chapter — the closest VM-reachable proxy for "deep-
      // link jump" since UrlSyncService's real implementation is
      // web-only (dart:js_interop-gated).
      final result = await jumper.resolveAndPrepareJump(
        reference: const BibleReference(
          englishBook: 'John',
          chapter: 3,
          verseStart: 16,
          verseEnd: 16,
        ),
        mp: mp,
      );

      expect(mp.currentBook, isNotNull,
          reason: 'a completed boot must land on some book, trap or not');
      expect(result.ready, isTrue,
          reason: 'John 3:16 exists in every bundled English version — '
              'a resolution failure here would itself be a finding');
    },
  );
}
