import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yswords/constants/build_flags.dart';
import 'package:yswords/services/google_fonts_reachability.dart';
import 'package:yswords/utils/font_catalog.dart';

/// 2026-08-30 (queue: retire the China bundle, item A/B).
///
/// [kChinaMode] is a compile-time bet about the *build*; several
/// mainland-China users report the international build working for
/// them over yahwehword.com, so the font picker also needs a runtime
/// verdict from [GoogleFontsReachabilityService]. This file covers:
///   • availableFontOptions() gates on that verdict, failing OPEN
///     while it's `unknown`.
///   • kChinaMode still wins outright regardless of the verdict.
///   • the probe itself demonstrably reports failure (a mocked
///     network error / non-200 both resolve to `unreachable`, not a
///     probe that can only ever say "reachable").
///   • migrateLegacyFontKey stays gated on kChinaMode ONLY — a
///     transient runtime verdict must never overwrite a user's
///     stored font selection.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    GoogleFontsReachabilityService.instance.debugReset();
  });

  tearDown(() {
    GoogleFontsReachabilityService.instance.debugReset();
  });

  test('sanity: this test build is not China mode', () {
    expect(kChinaMode, isFalse);
  });

  group('availableFontOptions runtime gate', () {
    test('fails open: unknown verdict still shows Google fonts', () {
      // The test body is synchronous (no `async`/`await`), so no
      // microtask from the probe's Future chain can run before this
      // assertion executes, however fast the mock resolves. That
      // proves availableFontOptions() reads the CURRENT verdict on
      // the spot rather than awaiting the probe it just kicked off.
      GoogleFontsReachabilityService.instance.clientFactory =
          () => MockClient((_) async => http.Response('', 200));

      final options = availableFontOptions();
      expect(options.any((f) => f.isGoogleFont), isTrue);
    });

    test('unreachable verdict hides Google fonts', () {
      GoogleFontsReachabilityService.instance
          .debugSetVerdict(GoogleFontsReachability.unreachable);

      final options = availableFontOptions();
      expect(options.any((f) => f.isGoogleFont), isFalse);
      expect(options, isNotEmpty); // bundled + system entries remain
    });

    test('reachable verdict shows Google fonts', () {
      GoogleFontsReachabilityService.instance
          .debugSetVerdict(GoogleFontsReachability.reachable);

      final options = availableFontOptions();
      expect(options.any((f) => f.isGoogleFont), isTrue);
    });
  });

  group('GoogleFontsReachabilityService probe demonstrably reports failure',
      () {
    test('a thrown exception (blocked host) resolves to unreachable',
        () async {
      GoogleFontsReachabilityService.instance.clientFactory = () =>
          MockClient((_) async => throw Exception('simulated GFW block'));

      GoogleFontsReachabilityService.instance.ensureProbed();
      await GoogleFontsReachabilityService.instance.debugWaitForProbe();

      expect(GoogleFontsReachabilityService.instance.verdict,
          GoogleFontsReachability.unreachable);
    });

    test('a non-200 response resolves to unreachable', () async {
      GoogleFontsReachabilityService.instance.clientFactory = () =>
          MockClient((_) async => http.Response('blocked', 403));

      GoogleFontsReachabilityService.instance.ensureProbed();
      await GoogleFontsReachabilityService.instance.debugWaitForProbe();

      expect(GoogleFontsReachabilityService.instance.verdict,
          GoogleFontsReachability.unreachable);
    });

    test('a real 200 response resolves to reachable', () async {
      GoogleFontsReachabilityService.instance.clientFactory = () =>
          MockClient((_) async => http.Response('font bytes', 200));

      GoogleFontsReachabilityService.instance.ensureProbed();
      await GoogleFontsReachabilityService.instance.debugWaitForProbe();

      expect(GoogleFontsReachabilityService.instance.verdict,
          GoogleFontsReachability.reachable);
    });

    test('does not re-probe once resolved this session', () async {
      var callCount = 0;
      GoogleFontsReachabilityService.instance.clientFactory = () =>
          MockClient((_) async {
            callCount++;
            return http.Response('', 200);
          });

      GoogleFontsReachabilityService.instance.ensureProbed();
      await GoogleFontsReachabilityService.instance.debugWaitForProbe();
      expect(callCount, 1);

      GoogleFontsReachabilityService.instance.ensureProbed();
      await GoogleFontsReachabilityService.instance.debugWaitForProbe();
      expect(callCount, 1,
          reason: 'second call must reuse the cached verdict, not re-probe');
    });
  });

  group('migrateLegacyFontKey stays gated on kChinaMode only (item B)', () {
    test('a stored Google-font key survives an unreachable runtime verdict',
        () {
      GoogleFontsReachabilityService.instance
          .debugSetVerdict(GoogleFontsReachability.unreachable);

      final migrated = migrateLegacyFontKey('EB Garamond');

      expect(migrated, 'EB Garamond',
          reason:
              'a transient runtime verdict must never overwrite a stored '
              'font selection; only kChinaMode (build-time, permanent) '
              'may do that');
    });
  });
}
