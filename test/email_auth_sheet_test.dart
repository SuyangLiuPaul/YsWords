/// 2026-09-06 — behaviour of the email sign-in form.
///
/// These are REAL behavioural tests, not source guards. The sheet
/// takes its three network actions as injected callbacks precisely so
/// the failure branches — the ones that decide whether a reader sees a
/// sentence or an endless spinner — can be driven from a test. Every
/// case below pumps the shipped widget and asserts on what is actually
/// rendered.
///
/// SECURITY: no real credential appears here. Addresses use
/// `@example.invalid` (RFC 6761 reserves `.invalid`); passwords are
/// obvious fakes.
library;

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/services/cloud_auth_service.dart';
import 'package:yswords/widgets/email_auth_sheet.dart';

const _fakeEmail = 'reader@example.invalid';
const _fakePassword = 'not-a-real-password';

String _s(String key, String locale) => uiStrings[key]![locale]!;

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

Future<void> _fillForm(WidgetTester tester,
    {String email = _fakeEmail, String password = _fakePassword}) async {
  await tester.enterText(find.byKey(const Key('emailAuth.email')), email);
  await tester.enterText(
      find.byKey(const Key('emailAuth.password')), password);
  await tester.pump();
}

void main() {
  testWidgets(
      'a successful sign-in fires onSignedIn — this is where sync starts',
      (tester) async {
    var signedIn = 0;
    await tester.pumpWidget(_host(EmailAuthSheet(
      locale: 'en',
      onSignedIn: () => signedIn++,
      signIn: (e, p) async => CloudAuthResult.ok(_FakeUser()),
    )));
    await _fillForm(tester);
    await tester.tap(find.byKey(const Key('emailAuth.submit')));
    await tester.pumpAndSettle();
    // In production this callback is
    // `RealtimeDbSyncService.instance.init()` — started lazily, after a
    // real credential exists, never at boot. If it stopped firing, the
    // China build would sign readers in and never sync them.
    expect(signedIn, 1);
    expect(find.byKey(const Key('emailAuth.message')), findsNothing);
  });

  testWidgets('a null user is NOT treated as success', (tester) async {
    var signedIn = 0;
    await tester.pumpWidget(_host(EmailAuthSheet(
      locale: 'en',
      onSignedIn: () => signedIn++,
      signIn: (e, p) async => const CloudAuthResult.ok(null),
    )));
    await _fillForm(tester);
    await tester.tap(find.byKey(const Key('emailAuth.submit')));
    await tester.pumpAndSettle();
    expect(signedIn, 0);
  });

  testWidgets('the password reaches the auth call byte-for-byte',
      (tester) async {
    String? seenEmail;
    String? seenPassword;
    // A trailing space is a legitimate part of a password. Trimming it
    // would make the account unopenable by the value that created it.
    const spaced = '$_fakePassword ';
    await tester.pumpWidget(_host(EmailAuthSheet(
      locale: 'en',
      signIn: (e, p) async {
        seenEmail = e;
        seenPassword = p;
        return const CloudAuthResult.error('x', errorCode: 'wrong-password');
      },
    )));
    await _fillForm(tester, email: '  $_fakeEmail', password: spaced);
    await tester.tap(find.byKey(const Key('emailAuth.submit')));
    await tester.pumpAndSettle();
    expect(seenPassword, spaced);
    // The email is passed through untouched too — normalisation is the
    // service's job (`CloudAuthService.normalizeEmail`), in one place.
    expect(seenEmail, '  $_fakeEmail');
  });

  group('errors become sentences, in three locales', () {
    for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
      testWidgets('invalid-credential renders its sentence in $locale',
          (tester) async {
        await tester.pumpWidget(_host(EmailAuthSheet(
          locale: locale,
          signIn: (e, p) async => const CloudAuthResult.error(
            'ignored',
            errorCode: 'invalid-credential',
          ),
        )));
        await _fillForm(tester);
        await tester.tap(find.byKey(const Key('emailAuth.submit')));
        await tester.pumpAndSettle();

        final message = tester.widget<Text>(
          find.byKey(const Key('emailAuth.message')),
        );
        expect(message.data, _s('authErrInvalidCredential', locale));
        // Not the raw machine code, and not the fallback.
        expect(message.data, isNot(contains('invalid-credential')));
        expect(message.data, isNot(_s('authErrGeneric', locale)));
      });
    }

    testWidgets('too-many-requests and weak-password say DIFFERENT things',
        (tester) async {
      final seen = <String>[];
      for (final code in const ['too-many-requests', 'weak-password']) {
        await tester.pumpWidget(_host(EmailAuthSheet(
          key: ValueKey(code),
          locale: 'en',
          signIn: (e, p) async =>
              CloudAuthResult.error('ignored', errorCode: code),
        )));
        await _fillForm(tester);
        await tester.tap(find.byKey(const Key('emailAuth.submit')));
        await tester.pumpAndSettle();
        seen.add(tester
            .widget<Text>(find.byKey(const Key('emailAuth.message')))
            .data!);
      }
      expect(seen.length, 2);
      expect(seen[0], isNot(seen[1]),
          reason: 'both codes collapsed onto one sentence');
    });
  });

  group('the collision ruling, as the reader meets it', () {
    testWidgets(
        'email-already-in-use shows one sentence and one reset button, '
        'and names no provider', (tester) async {
      String? resetTo;
      await tester.pumpWidget(_host(EmailAuthSheet(
        locale: 'en',
        startInCreateMode: true,
        createAccount: (e, p) async => const CloudAuthResult.error(
          'ignored',
          errorCode: 'email-already-in-use',
        ),
        sendReset: (e) async {
          resetTo = e;
          return const CloudAuthActionResult.ok();
        },
      )));
      await _fillForm(tester);
      await tester.tap(find.byKey(const Key('emailAuth.submit')));
      await tester.pumpAndSettle();

      final message = tester
          .widget<Text>(find.byKey(const Key('emailAuth.message')))
          .data!;
      expect(message, _s('authErrEmailInUse', 'en'));
      // The ruling's load-bearing part: the copy must not name a
      // provider, because the app deliberately does not know which one
      // owns the address and does not need to.
      for (final banned in const ['Google', 'google', '谷歌', 'Gmail']) {
        expect(message.contains(banned), isFalse,
            reason: 'the collision copy names a provider: $banned');
      }
      // Exactly one reset affordance in create mode — the "Forgot
      // password?" link is a sign-in-mode thing, so there is no second
      // button competing with it.
      expect(find.byKey(const Key('emailAuth.sendReset')), findsOneWidget);
      expect(find.byKey(const Key('emailAuth.forgot')), findsNothing);

      await tester.tap(find.byKey(const Key('emailAuth.sendReset')));
      await tester.pumpAndSettle();
      // It went to the address just typed.
      expect(resetTo, _fakeEmail);
      // The confirmation replaces the offer rather than sitting beside
      // it, so the reader is not invited to send a second one.
      expect(
        tester.widget<Text>(find.byKey(const Key('emailAuth.message'))).data,
        _s('authResetSent', 'en'),
      );
      expect(find.byKey(const Key('emailAuth.sendReset')), findsNothing);
    });

    testWidgets('invalid-credential surfaces the same reset button',
        (tester) async {
      await tester.pumpWidget(_host(EmailAuthSheet(
        locale: 'en',
        signIn: (e, p) async => const CloudAuthResult.error(
          'ignored',
          errorCode: 'invalid-credential',
        ),
        sendReset: (e) async => const CloudAuthActionResult.ok(),
      )));
      await _fillForm(tester);
      await tester.tap(find.byKey(const Key('emailAuth.submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('emailAuth.sendReset')), findsOneWidget);
    });

    testWidgets('weak-password does NOT surface a reset button',
        (tester) async {
      await tester.pumpWidget(_host(EmailAuthSheet(
        locale: 'en',
        startInCreateMode: true,
        createAccount: (e, p) async => const CloudAuthResult.error(
          'ignored',
          errorCode: 'weak-password',
        ),
      )));
      await _fillForm(tester);
      await tester.tap(find.byKey(const Key('emailAuth.submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('emailAuth.message')), findsOneWidget);
      expect(find.byKey(const Key('emailAuth.sendReset')), findsNothing);
    });

    testWidgets('Forgot password? is visible before anything has failed',
        (tester) async {
      await tester.pumpWidget(_host(const EmailAuthSheet(locale: 'en')));
      expect(find.byKey(const Key('emailAuth.forgot')), findsOneWidget);
      expect(find.byKey(const Key('emailAuth.message')), findsNothing);
    });
  });

  group('no spinner that never resolves', () {
    testWidgets('a slow call shows a spinner, then a sentence, then re-arms',
        (tester) async {
      final gate = Completer<CloudAuthResult>();
      await tester.pumpWidget(_host(EmailAuthSheet(
        locale: 'en',
        signIn: (e, p) => gate.future,
      )));
      await _fillForm(tester);
      await tester.tap(find.byKey(const Key('emailAuth.submit')));
      await tester.pump();

      // In flight: a spinner, and the button refuses a second tap.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('emailAuth.submit')))
            .onPressed,
        isNull,
      );

      // The bound expires inside the service and comes back as a
      // timeout code. What matters here is what the reader then sees.
      gate.complete(const CloudAuthResult.error(
        'ignored',
        errorCode: CloudAuthService.codeTimeout,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        tester.widget<Text>(find.byKey(const Key('emailAuth.message'))).data,
        _s('authErrTimeout', 'en'),
      );
      // Re-armed, so "try again" is actually possible.
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('emailAuth.submit')))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('an unreachable sign-in server says so and sends nothing',
        (tester) async {
      await tester.pumpWidget(_host(EmailAuthSheet(
        locale: 'zh-Hans',
        signIn: (e, p) async => const CloudAuthResult.error(
          'ignored',
          errorCode: CloudAuthService.codeUnavailable,
        ),
      )));
      await _fillForm(tester);
      await tester.tap(find.byKey(const Key('emailAuth.submit')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const Key('emailAuth.message'))).data,
        _s('authErrInitUnavailable', 'zh-Hans'),
      );
    });
  });
}

/// A [User] that throws on every member access. Two jobs: it makes a
/// genuine success path testable without a Firebase backend, and it
/// asserts the sheet reads NOTHING off the user object — if it ever
/// starts to, this fake turns the success test red rather than letting
/// a field read slip in unnoticed.
class _FakeUser implements User {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
      'EmailAuthSheet must not read ${invocation.memberName} off the User');
}
