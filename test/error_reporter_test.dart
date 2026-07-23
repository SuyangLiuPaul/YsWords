/// 2026-05-24 (v1.3.23): regression tests for ErrorReporter's
library;
//
/// in-memory state. The reporter is mostly side-effects (HTTP POST,
/// global hooks) but the breadcrumb ring + route/locale tracking +
/// payload-cap helper are pure logic and worth locking in so a
/// future refactor can't silently break the visibility we just
/// shipped in v1.3.21.

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/services/error_reporter.dart';

void main() {
  setUp(() {
    ErrorReporter.resetForTest();
  });

  group('breadcrumb ring buffer', () {
    test('starts empty after reset', () {
      expect(ErrorReporter.breadcrumbsForTest, isEmpty);
    });

    test('breadcrumb() appends one entry', () {
      ErrorReporter.breadcrumb('nav:push', data: 'Dashboard');
      final crumbs = ErrorReporter.breadcrumbsForTest;
      expect(crumbs, hasLength(1));
      expect(crumbs.first.action, 'nav:push');
      expect(crumbs.first.data, 'Dashboard');
      expect(crumbs.first.timestamp, isA<DateTime>());
    });

    test('breadcrumb() preserves insertion order', () {
      ErrorReporter.breadcrumb('one');
      ErrorReporter.breadcrumb('two');
      ErrorReporter.breadcrumb('three');
      final actions =
          ErrorReporter.breadcrumbsForTest.map((b) => b.action).toList();
      expect(actions, ['one', 'two', 'three']);
    });

    test('breadcrumb() caps the ring at 10 entries (oldest evicted)', () {
      // Push 15 entries; expect only the last 10 to remain.
      for (var i = 0; i < 15; i++) {
        ErrorReporter.breadcrumb('action $i');
      }
      final crumbs = ErrorReporter.breadcrumbsForTest;
      expect(crumbs, hasLength(10));
      // The FIRST surviving entry should be the 6th push (index 5)
      // since 0..4 were evicted.
      expect(crumbs.first.action, 'action 5');
      expect(crumbs.last.action, 'action 14');
    });

    test('breadcrumb() accepts null data (and stores null, not "")', () {
      ErrorReporter.breadcrumb('memory:pressure');
      expect(ErrorReporter.breadcrumbsForTest.single.data, isNull);
    });

    test('breadcrumb timestamps are UTC + monotonically non-decreasing', () {
      ErrorReporter.breadcrumb('one');
      ErrorReporter.breadcrumb('two');
      final crumbs = ErrorReporter.breadcrumbsForTest;
      expect(crumbs[0].timestamp.isUtc, isTrue);
      expect(crumbs[1].timestamp.isUtc, isTrue);
      expect(
        crumbs[1].timestamp.isAtSameMomentAs(crumbs[0].timestamp) ||
            crumbs[1].timestamp.isAfter(crumbs[0].timestamp),
        isTrue,
      );
    });
  });

  group('route tracking', () {
    test('starts empty after reset', () {
      expect(ErrorReporter.currentRouteForTest, isEmpty);
    });

    test('setCurrentRoute() stores the value', () {
      ErrorReporter.setCurrentRoute('/HomePage');
      expect(ErrorReporter.currentRouteForTest, '/HomePage');
    });

    test('setCurrentRoute(null) clears to empty string', () {
      ErrorReporter.setCurrentRoute('/HomePage');
      ErrorReporter.setCurrentRoute(null);
      expect(ErrorReporter.currentRouteForTest, isEmpty);
    });

    test('setCurrentRoute() overwrites previous value', () {
      ErrorReporter.setCurrentRoute('/A');
      ErrorReporter.setCurrentRoute('/B');
      expect(ErrorReporter.currentRouteForTest, '/B');
    });
  });

  group('locale tracking', () {
    test('defaults to "en" after reset', () {
      expect(ErrorReporter.appLocaleForTest, 'en');
    });

    test('setLocale() stores the value', () {
      ErrorReporter.setLocale('zh-Hans');
      expect(ErrorReporter.appLocaleForTest, 'zh-Hans');
    });

    test('setLocale() round-trips both supported variants', () {
      ErrorReporter.setLocale('zh-Hant');
      expect(ErrorReporter.appLocaleForTest, 'zh-Hant');
      ErrorReporter.setLocale('en');
      expect(ErrorReporter.appLocaleForTest, 'en');
    });
  });

  group('payload-cap helper (_trim via trimForTest)', () {
    test('passes through strings shorter than the cap', () {
      expect(ErrorReporter.trimForTest('abc', 10), 'abc');
    });

    test('passes through strings exactly at the cap', () {
      expect(ErrorReporter.trimForTest('abcdefghij', 10), 'abcdefghij');
    });

    test('truncates strings longer than the cap', () {
      expect(
          ErrorReporter.trimForTest('abcdefghijklmno', 10), 'abcdefghij');
    });

    test('handles empty string', () {
      expect(ErrorReporter.trimForTest('', 10), '');
    });

    test('handles cap of 0', () {
      expect(ErrorReporter.trimForTest('abc', 0), '');
    });

    test('handles unicode (counts code units, matches Dart .length)', () {
      // Each CJK BMP character is 1 UTF-16 code unit in Dart, so
      // '你好世界'.length == 4. With cap=2 we expect the first two
      // characters '你好' (not '你' — see issue if we ever try to
      // store a 4-byte emoji that takes 2 code units; today the
      // reporter doesn't care).
      expect(ErrorReporter.trimForTest('你好世界', 2), '你好');
      // 4-byte emoji ("🎉" is U+1F389 = 2 code units). With cap=1
      // we'd cleave the surrogate pair — Dart strings tolerate
      // that but the resulting char is invalid. The reporter
      // doesn't try to be smart here; it documents the behavior.
      // We just check the length is correct.
      expect(ErrorReporter.trimForTest('🎉🎊', 2).length, 2);
    });
  });

  group('report() best-effort guarantee', () {
    test('does not throw when network is unavailable / no endpoint', () {
      // The reporter's contract: NEVER throw back into the caller.
      // With no init() / overrideEndpoint, the POST will time out
      // and the catch swallows it silently. We just verify no
      // exception escapes.
      expect(
        () => ErrorReporter.report(
          Exception('test'),
          StackTrace.current,
          source: 'test',
        ),
        returnsNormally,
      );
    });
  });

  group('benign-noise filter (v1.3.x)', () {
    test('drops CanvasKit getParameter WebGL failure on iOS Chrome', () {
      // Real reported shape (v1.3.49 web, CriOS): a TypeError thrown
      // from canvaskit.js MakeWebGLContext. App falls back to CPU
      // rendering — nothing to fix, so it must not be reported.
      const err = 'TypeError: getParameter is not a function';
      const stack = 'at WebGLRenderingContext.getParameter\n'
          'at canvaskit.js … MakeWebGLContext';
      expect(ErrorReporter.isIgnorableNoiseForTest(err, stack), isTrue);
    });

    test('drops match found only in the stack, not the message', () {
      expect(
        ErrorReporter.isIgnorableNoiseForTest(
            'Error', 'a.MakeWebGLContext (canvaskit.js:16)'),
        isTrue,
      );
    });

    test('drops google_fonts CDN-unreachable failures', () {
      // Real reported shape (v1.3.113, Android/Huawei ELS-AN00,
      // zh-Hans): the http GET inside google_fonts'
      // _httpFetchFontAndSaveToDevice throws when fonts.gstatic.com
      // is unreachable. font_catalog.dart's resolveFontFamily /
      // previewTextStyle already catch the synchronous call and fall
      // back to a system font, so the UI is fine — but the fetch
      // itself runs in an unawaited Future inside the package with
      // no .catchError, so it still reaches PlatformDispatcher.
      const err = 'Exception: Failed to load font with url '
          'https://fonts.gstatic.com/s/a/5ced104582: '
          'ClientException with SocketException';
      const stack = '#0 _httpFetchFontAndSaveToDevice '
          '(package:google_fonts/src/google_fonts_base.dart:268)\n'
          '#1 loadFontIfNecessary '
          '(package:google_fonts/src/google_fonts_base.dart:175)';
      expect(ErrorReporter.isIgnorableNoiseForTest(err, stack), isTrue);
    });

    test('keeps genuine app errors', () {
      expect(
        ErrorReporter.isIgnorableNoiseForTest(
            'RangeError: index out of range', '#0 List.[] dart:core'),
        isFalse,
      );
      expect(
        ErrorReporter.isIgnorableNoiseForTest(
            'set failed: value argument contains an invalid key', ''),
        isFalse,
      );
    });
  });
}
