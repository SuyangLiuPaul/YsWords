/// 2026-09-06 — email + password sign-in: the parts of
/// `CloudAuthService` that can be tested without a Firebase backend,
/// plus three source guards over the parts that cannot.
///
/// **What is genuinely exercised vs. what is only pinned** — the same
/// disclosure `sync_pull_direction_test.dart` makes, for the same
/// reason:
///
///   • [CloudAuthService.messageKeyForCode],
///     [CloudAuthService.isAccountCollision],
///     [CloudAuthService.shouldOfferPasswordReset] and
///     [CloudAuthService.normalizeEmail] are pure. Those cases are
///     real: they run the shipped functions.
///   • `ensureInitialized` is really invoked. It cannot reach Firebase
///     from a VM test, which is precisely the case worth proving — it
///     must COMPLETE and report false, not hang.
///   • The three source-structure cases at the bottom are guards over
///     properties nothing behavioural in this suite can see: that the
///     boot path was left alone, that every network call is bounded,
///     and that no logging statement in either file ever mentions a
///     password.
///
/// No real credential appears anywhere in this file. Every address is
/// `@example.invalid` (RFC 6761 reserves `.invalid`, so it can never
/// resolve) and every password is an obvious literal fake.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/services/cloud_auth_service.dart';

/// Strip `//` line comments and `///` doc comments so a source guard
/// cannot be satisfied — or defeated — by prose. Without this, the
/// long security comment at the top of `email_auth_sheet.dart` (which
/// contains the word "password" several times) would make the
/// no-logging guard either vacuous or permanently red depending on
/// which way it was written.
String _stripComments(String src) {
  return src
      .split('\n')
      .map((line) {
        final i = line.indexOf('//');
        if (i < 0) return line;
        // Not a comment if the `//` is inside a string literal — the
        // only such case in these two files is a `https://` URL.
        if (i > 0 && line[i - 1] == ':') return line;
        return line.substring(0, i);
      })
      .join('\n');
}

void main() {
  group('error codes map to a sentence key', () {
    // Every code the reader can actually provoke, and the brief's own
    // list: wrong password, unknown user, weak password, malformed
    // email, network failure, too many attempts.
    const cases = <String, String>{
      'wrong-password': 'authErrWrongPassword',
      'user-not-found': 'authErrUserNotFound',
      'weak-password': 'authErrWeakPassword',
      'invalid-email': 'authErrInvalidEmail',
      'network-request-failed': 'authErrNetwork',
      'too-many-requests': 'authErrTooManyRequests',
      'invalid-credential': 'authErrInvalidCredential',
      'invalid-login-credentials': 'authErrInvalidCredential',
      'email-already-in-use': 'authErrEmailInUse',
      'account-exists-with-different-credential': 'authErrEmailInUse',
      'user-disabled': 'authErrUserDisabled',
      'operation-not-allowed': 'authErrEmailNotEnabled',
    };

    cases.forEach((code, key) {
      test('$code -> $key', () {
        expect(CloudAuthService.messageKeyForCode(code), key);
      });
    });

    test('an unknown code falls back rather than leaking the code', () {
      expect(
        CloudAuthService.messageKeyForCode('some-code-firebase-added-later'),
        CloudAuthService.authErrorFallbackKey,
      );
      expect(
        CloudAuthService.messageKeyForCode(null),
        CloudAuthService.authErrorFallbackKey,
      );
    });

    test('the six codes the brief names all resolve DISTINCT sentences',
        () {
      // A mapping that collapsed everything onto one key would pass a
      // "returns a non-null key" test while telling every reader the
      // same thing. Six inputs, six different keys.
      final keys = <String>{
        CloudAuthService.messageKeyForCode('wrong-password'),
        CloudAuthService.messageKeyForCode('user-not-found'),
        CloudAuthService.messageKeyForCode('weak-password'),
        CloudAuthService.messageKeyForCode('invalid-email'),
        CloudAuthService.messageKeyForCode('network-request-failed'),
        CloudAuthService.messageKeyForCode('too-many-requests'),
      };
      expect(keys.length, 6);
      expect(keys, isNot(contains(CloudAuthService.authErrorFallbackKey)));
    });
  });

  group('the collision ruling', () {
    test('both collision codes are recognised', () {
      expect(CloudAuthService.isAccountCollision('email-already-in-use'),
          isTrue);
      expect(
        CloudAuthService
            .isAccountCollision('account-exists-with-different-credential'),
        isTrue,
      );
    });

    test('an unrelated code is not a collision', () {
      expect(CloudAuthService.isAccountCollision('weak-password'), isFalse);
      expect(CloudAuthService.isAccountCollision(null), isFalse);
    });

    test('the reset escape hatch is offered on every code that needs it',
        () {
      for (final code in const [
        'email-already-in-use',
        'account-exists-with-different-credential',
        // Enumeration protection collapses a Google-only account and a
        // plain typo into this one. It is the case the ruling calls
        // out explicitly: the offer must not be buried.
        'invalid-credential',
        'invalid-login-credentials',
        'wrong-password',
        'user-not-found',
      ]) {
        expect(CloudAuthService.shouldOfferPasswordReset(code), isTrue,
            reason: '$code must offer the reset');
      }
    });

    test('the reset is NOT offered where it would be noise', () {
      for (final code in const [
        'weak-password',
        'invalid-email',
        'network-request-failed',
        'too-many-requests',
        'user-disabled',
        'operation-not-allowed',
        null,
      ]) {
        expect(CloudAuthService.shouldOfferPasswordReset(code), isFalse,
            reason: '$code must not offer the reset');
      }
    });
  });

  group('email normalisation', () {
    test('surrounding whitespace is trimmed', () {
      expect(CloudAuthService.normalizeEmail('  reader@example.invalid  '),
          'reader@example.invalid');
    });

    test('case is preserved — this app does not invent a second rule', () {
      expect(CloudAuthService.normalizeEmail('Reader@Example.Invalid'),
          'Reader@Example.Invalid');
    });
  });

  group('ensureInitialized completes rather than hanging', () {
    test('reports false, and does not throw, when Firebase cannot start',
        () async {
      // There is no Firebase platform channel under `flutter test`, so
      // `_doInit` fails. That is the point: the reader-facing promise
      // is that a tap always resolves into a sentence. A method that
      // threw, or never completed, would produce the exact spinner the
      // brief calls worse than no button.
      final ok = await CloudAuthService.instance
          .ensureInitialized(timeout: const Duration(seconds: 5));
      expect(ok, isFalse);
      expect(CloudAuthService.instance.isConfigured, isFalse);
      // And it recorded WHY, so Settings' existing error surface stays
      // truthful instead of silently empty.
      expect(CloudAuthService.instance.initError, isNotNull);
    });

    test('concurrent callers share one in-flight init', () async {
      // Double-tapping the button must not start a second
      // Firebase.initializeApp.
      final a = CloudAuthService.instance
          .ensureInitialized(timeout: const Duration(seconds: 5));
      final b = CloudAuthService.instance
          .ensureInitialized(timeout: const Duration(seconds: 5));
      expect(identical(a, b), isTrue);
      await Future.wait([a, b]);
    });
  });

  group('source guards — properties nothing behavioural here can see', () {
    late String authSrc;
    late String sheetSrc;
    late String mainSrc;

    setUpAll(() {
      authSrc = File('lib/services/cloud_auth_service.dart').readAsStringSync();
      sheetSrc = File('lib/widgets/email_auth_sheet.dart').readAsStringSync();
      mainSrc = File('lib/main.dart').readAsStringSync();
      // Trap 39: assert the extraction is non-vacuous before asserting
      // anything about it.
      expect(authSrc.length, greaterThan(5000));
      expect(sheetSrc.length, greaterThan(3000));
      expect(mainSrc.length, greaterThan(5000));
    });

    test('no password ever reaches a logging call', () {
      // The rule: in real code (comments stripped), no print /
      // debugPrint statement may mention a password.
      for (final entry in {
        'cloud_auth_service.dart': authSrc,
        'email_auth_sheet.dart': sheetSrc,
      }.entries) {
        final code = _stripComments(entry.value);
        final calls = RegExp(r'\b(debugPrint|print)\s*\(')
            .allMatches(code)
            .map((m) {
          // Take the statement from the call to the next `);` — good
          // enough to catch an interpolated password, which is the
          // shape that would actually leak one.
          final end = code.indexOf(');', m.start);
          return code.substring(m.start, end < 0 ? code.length : end);
        });
        for (final call in calls) {
          expect(
            call.toLowerCase().contains('password'),
            isFalse,
            reason: '${entry.key}: a logging call mentions a password:\n'
                '$call',
          );
        }
      }
    });

    test('the password is never trimmed', () {
      // Trimming would silently change the credential and make an
      // account unopenable by the value that created it.
      final code = _stripComments(authSrc) + _stripComments(sheetSrc);
      expect(RegExp(r'password\s*\.\s*trim\s*\(').hasMatch(code), isFalse);
      expect(RegExp(r'_passwordCtl\.text\s*\.\s*trim').hasMatch(code),
          isFalse);
    });

    test('every email/password network call is bounded', () {
      final code = _stripComments(authSrc);
      // `_emailCall` runs the SDK call, `sendPasswordResetEmail` runs
      // the reset, `ensureInitialized` runs init. All three must carry
      // a `.timeout(`.
      for (final method in const [
        '_emailCall',
        'sendPasswordResetEmail',
        'ensureInitialized',
      ]) {
        final start = code.indexOf(RegExp('$method[<(]'));
        expect(start, greaterThan(0), reason: '$method not found');
        // Read a generous window forward; every one of these methods
        // is well under 80 lines.
        final window = code.substring(
            start, (start + 4000).clamp(0, code.length).toInt());
        expect(window.contains('.timeout('), isTrue,
            reason: '$method has an unbounded await');
      }
    });

    test('the boot path was left alone — no lazy init from main()', () {
      // The whole point of shipping this in the China build was that
      // it costs nothing at boot. `main.dart:538`'s `if (!kChinaMode)`
      // still guards Firebase, and nothing in main() calls the lazy
      // entry point.
      expect(mainSrc.contains('if (!kChinaMode) {'), isTrue,
          reason: 'the China boot skip was removed');
      // `WidgetsFlutterBinding.ensureInitialized()` is a different
      // method with the same name and is legitimately on line 102, so
      // the guard is: EVERY `ensureInitialized` in main.dart is that
      // one. Adding `CloudAuthService.instance.ensureInitialized()`
      // anywhere in the boot sequence turns this red.
      final hits = RegExp(r'[\w.]*ensureInitialized')
          .allMatches(mainSrc)
          .map((m) => m.group(0))
          .toSet();
      expect(hits, isNotEmpty, reason: 'extraction is vacuous');
      expect(hits, {'WidgetsFlutterBinding.ensureInitialized'},
          reason: 'lazy init leaked onto the boot path — the China '
              'build would pay Firebase latency at every launch again');
    });
  });
}
