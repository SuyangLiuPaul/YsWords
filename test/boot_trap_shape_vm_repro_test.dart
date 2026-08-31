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

/// 2026-08-31 / 2026-09-01: VM-side repro attempts for the mailed-in boot
/// crash — `Invalid argument: 0`, web release only (queue:
/// `docs/autonomous-queue.md`, "a boot crash the app cannot recover from
/// on its own"). Dart's `.clamp(lower, upper)` throws `ArgumentError`
/// (unminified: "Invalid argument(s): 0"; dart2js: "Invalid argument: 0"
/// — same defect, two spellings) when `upper < lower`, which is exactly
/// what an empty result (a `length - 1` on nothing) produces feeding a
/// `.clamp(0, ...)` call.
///
/// The mitigation shipped 2026-08-31 (`legacy_reading_position_quarantine
/// .dart`) works around the SHAPE without explaining the throw, and it
/// only runs from the splash's 45s auto-recovery path — NOT from a plain
/// cold boot — so it does not interfere with reproducing the original
/// trap here. These tests skip straight past it and drive
/// `runBootstrapProper` below, which mirrors `lib/main.dart`'s
/// `_bootstrap()` try/catch EXACTLY (`lib/main.dart:353`-`404`):
/// `ProfileService.init()` → `AppSettings.loadSettings()` →
/// `MainProvider.restoreState()` → `FetchVerses.execute()` →
/// `FetchBooks.execute()` → the post-load "validate restored state or
/// fallback" block, and nothing past that.
///
/// `UrlSyncService.init` and `jump_to_reference.resolveAndPrepareJump`
/// are checked SEPARATELY, in `runPostBootstrapExtras`, and are
/// deliberately NOT folded into the claim "this covers `_bootstrap()`":
/// an adversarial review of an earlier draft of this file found that
/// (a) `UrlSyncService.init` in production runs at `lib/main.dart:481`,
/// AFTER `_bootstrap()`'s try/catch closes at `:404` — fire-and-forget
/// with its own `.catchError` (`:484`-`:486`), not inside the same
/// guard the earlier draft implied, and (b) `resolveAndPrepareJump` is
/// never called from `_bootstrap()` at all — it is only reachable from
/// a user tapping a cross-link, and was included here only as "the
/// closest VM-reachable proxy for a deep-link jump" (`UrlSyncService`'s
/// real hash-parsing implementation is web-only,
/// `dart:js_interop`-gated, and this VM harness dispatches to its
/// no-op native stub instead — see the note below on what that leaves
/// untested).
///
/// The first test below is the ORIGINAL single-case repro: the exact
/// three-key trap shape from the mailed-in report, but with values that
/// are all individually VALID (`book: 'John', chapter: 3, version:
/// 'kjv'` all resolve to real data) — which is why it passing proves
/// nothing about the throw site, only that the trap's absence-of-
/// profile-keys shape is not itself sufficient to crash.
///
/// The remaining tests are the follow-up this leaves open: turn "all
/// three keys valid" into a matrix over VALUES that are individually
/// stale/wrong in each of the ways `MainProvider.restoreState()`
/// (`lib/providers/main_provider.dart:1479`) does not validate before
/// assigning them — `currentVersion = v` at `:1581`, `currentBook =
/// savedBook` / `currentChapter = savedChapter` at `:1610`-`:1611`, with
/// no check that any of the three still resolves to real data. Only two
/// version ids are migrated (`niv → kjv`, and the locale-conditional
/// `cuvs-yhwh → nasb`); everything else — a retired/never-shipped
/// version id, a book name in the wrong version's language, an outright
/// unknown book string, a chapter past the book's length, chapter 0 —
/// passes through unchanged.
///
/// If a case throws, the failure output IS an unminified stack trace
/// naming the throw site — read it, don't guess from it.
///
/// If the whole matrix comes up clean (as it did when first written),
/// that is itself a real result: it narrows the mystery throw away from
/// `restoreState`/`FetchVerses`/`FetchBooks`/the validate-fallback
/// block — the ACTUAL `_bootstrap()` code path — for these seven stale-
/// value shapes specifically. It does NOT narrow past that: this
/// harness still cannot exercise dart2js codegen,
/// `shared_preferences_web`'s localStorage decoding, WIDGET
/// BUILD/layout (this file never pumps a widget tree), or — the gap an
/// adversarial review of an earlier draft caught — the real WEB-ONLY
/// URL→state path, `url_sync_service_web.dart`'s `_applyHashToState`,
/// which does its own independent book/chapter/version resolution from
/// `window.location.hash` on every web cold boot and is `dart:js_interop`
/// -gated, so it cannot run on the VM at all. Given the crash is
/// web-release-only, that file is a real remaining candidate this
/// harness cannot rule out, not a closed one. See
/// `docs/autonomous-queue.md:110` for what to try next, and don't
/// escalate to a browser hunt from here — that trap has already cost
/// three iterations.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Mirrors `lib/main.dart`'s `_bootstrap()` try/catch EXACTLY — same
  /// steps, same scope (`lib/main.dart:353`-`404`). Nothing past what
  /// `_bootstrap()` itself awaits inside that try block belongs in
  /// here; see `runPostBootstrapExtras` for the two calls that come
  /// after it in production.
  ///
  /// Returns the exception the try/catch caught, or null if the whole
  /// sequence completed cleanly.
  Future<Object?> runBootstrapProper(MainProvider mp, AppSettings appSettings) async {
    try {
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
      return null;
    } catch (e) {
      return e;
    }
  }

  /// The two calls production makes AFTER `_bootstrap()`'s own
  /// try/catch closes — checked separately, each under its own guard
  /// mirroring how production isolates them, NOT folded into "the boot
  /// sequence" (see the file doc comment for why that distinction
  /// matters). Returns the first exception either one raised, or null.
  Future<Object?> runPostBootstrapExtras(MainProvider mp, AppSettings appSettings) async {
    try {
      // Real boot order: URL sync (no-op stub on the VM) runs after
      // restoreState + the fetches, same as _bootstrap() — but, unlike
      // everything in runBootstrapProper, OUTSIDE _bootstrap()'s
      // try/catch in production (lib/main.dart:481, guarded by its own
      // .catchError at :484-486, not the :404 catch).
      await UrlSyncService.init(mainProvider: mp, appSettings: appSettings);
    } catch (e) {
      return e;
    }
    try {
      // NOT part of _bootstrap() in production at all — only reachable
      // from a user tapping a cross-link. Exercised here only as the
      // closest VM-reachable proxy for "deep-link jump", since
      // UrlSyncService's real hash-parsing implementation is web-only
      // (dart:js_interop-gated) and unreachable from this harness.
      await jumper.resolveAndPrepareJump(
        reference: const BibleReference(
          englishBook: 'John',
          chapter: 3,
          verseStart: 16,
          verseEnd: 16,
        ),
        mp: mp,
      );
      return null;
    } catch (e) {
      return e;
    }
  }

  test(
    'trap shape (book/chapter/version only, no profile.* keys) '
    'survives the full boot sequence on the VM without throwing — '
    'ALL THREE VALUES VALID, proves nothing about the throw site',
    () async {
      SharedPreferences.setMockInitialValues({
        'book': 'John',
        'chapter': 3,
        'version': 'kjv',
      });

      final appSettings = AppSettings();
      final mp = MainProvider();
      final caught = await runBootstrapProper(mp, appSettings);

      expect(caught, isNull,
          reason: 'the baseline valid-triple case must not throw at all — '
              'if this one throws, the boot sequence itself is broken, '
              'unrelated to stale-state handling');
      expect(mp.currentBook, isNotNull,
          reason: 'a completed boot must land on some book, trap or not');

      final extrasCaught = await runPostBootstrapExtras(mp, appSettings);
      expect(extrasCaught, isNull,
          reason: 'the post-bootstrap extras (URL sync + a deep-link-'
              'shaped jump) must not throw for the baseline valid case '
              'either');
    },
  );

  /// One matrix case: plant [prefsValues] as the ONLY stored state
  /// (same shape as the mailed-in trap — no profile.* keys at all),
  /// run `_bootstrap()` proper, and report what happened rather than
  /// asserting a single fixed outcome — different stale-value classes
  /// have different CORRECT outcomes (a missing asset should raise a
  /// caught, non-ArgumentError load failure; a bad chapter should fall
  /// back silently to the first verse). What every case shares is: no
  /// ArgumentError may escape, caught or not — that specific shape is
  /// the "Invalid argument: 0" bug this item is hunting.
  void staleCase(
    String description,
    Map<String, Object> prefsValues,
  ) {
    test(description, () async {
      SharedPreferences.setMockInitialValues(prefsValues);

      final appSettings = AppSettings();
      final mp = MainProvider();
      final caught = await runBootstrapProper(mp, appSettings);

      if (caught is ArgumentError) {
        fail('$description threw ArgumentError in _bootstrap() proper — '
            'this IS the "Invalid argument: 0" shape this item has been '
            'hunting: $caught');
      }
      // Any other caught exception (e.g. FlutterError: asset not found,
      // for a version id that was never shipped) is a KNOWN, already-
      // handled failure mode — main.dart's own try/catch turns it into
      // an error scaffold, not a crash. Print it for visibility only.
      if (caught != null) {
        // ignore: avoid_print
        print('$description: _bootstrap() caught (non-ArgumentError, '
            'expected-shape) $caught');
      }

      final extrasCaught = await runPostBootstrapExtras(mp, appSettings);
      if (extrasCaught is ArgumentError) {
        fail('$description threw ArgumentError in the post-bootstrap '
            'extras (URL sync / deep-link jump) — this IS the "Invalid '
            'argument: 0" shape: $extrasCaught');
      }
      if (extrasCaught != null) {
        // ignore: avoid_print
        print('$description: post-bootstrap extras caught '
            '(non-ArgumentError) $extrasCaught');
      }
    });
  }

  staleCase(
    'stale version id never shipped as an asset (rsv) does not throw '
    'ArgumentError — only a caught, known load failure is acceptable',
    {'book': 'John', 'chapter': 3, 'version': 'rsv'},
  );

  staleCase(
    'book name in the WRONG version\'s language (Chinese key, English '
    'version) does not throw ArgumentError — falls back to first verse',
    {'book': '约翰福音', 'chapter': 3, 'version': 'kjv'},
  );

  staleCase(
    'outright unknown book string does not throw ArgumentError — '
    'falls back to first verse',
    {'book': 'Frobnicate', 'chapter': 1, 'version': 'kjv'},
  );

  staleCase(
    'chapter past the book\'s length (John has 21) does not throw '
    'ArgumentError — falls back to first verse',
    {'book': 'John', 'chapter': 999, 'version': 'kjv'},
  );

  staleCase(
    'chapter 0 (verses are 1-indexed) does not throw ArgumentError — '
    'falls back to first verse',
    {'book': 'John', 'chapter': 0, 'version': 'kjv'},
  );

  staleCase(
    'the mirror-image book-language mismatch: English book key saved '
    'against a Chinese version whose OWN book keys are Chinese, does '
    'not throw ArgumentError — falls back to first verse',
    {'book': 'John', 'chapter': 3, 'version': 'cuvs-yhwh'},
  );
}
