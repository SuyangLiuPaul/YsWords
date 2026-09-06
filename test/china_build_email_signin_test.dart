/// 2026-09-06 — the China build ships email sign-in, and only the
/// Google button keeps its compile-time gate.
///
/// These are SOURCE-STRUCTURE assertions, and the disclosure matters:
/// a widget test cannot reach them. `kChinaMode` is a
/// `bool.fromEnvironment` const, so a test binary compiled without
/// `--dart-define=CHINA_MODE=true` renders the international branch
/// and can never see what the China branch does. The China bundle is a
/// separate compilation; the only thing available at test time is the
/// source it is compiled from.
///
/// What each case is really protecting:
///   • the email control is not inside any `kChinaMode` conditional —
///     the whole point of the change;
///   • the Google control still IS, because that flow needs
///     `accounts.google.com` and the un-proxyable account chooser;
///   • sync is started from the sign-in success callback, not at boot;
///   • the two strings that became lies are no longer read.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/constants/build_flags.dart';

/// Strip `//` and `///` comments. Both retired keys and the word
/// `kChinaMode` still appear all over this repo's PROSE — the
/// changelog in `app_version.dart`, the note that says WHY a branch
/// was removed — and a guard that could not tell code from commentary
/// would either be permanently red or, worse, would push a future
/// iteration into deleting the explanation to make a test pass.
String _code(String src) => src
    .split('\n')
    .map((line) {
      final i = line.indexOf('//');
      if (i < 0) return line;
      if (i > 0 && line[i - 1] == ':') return line; // https://
      return line.substring(0, i);
    })
    .join('\n');

/// Every file under `lib/` whose real code reads `uiStrings[<key>]`.
/// `ui_strings.dart` itself is excluded: it DEFINES the key, and the
/// key stays in that append-only table so any external translation
/// file still referencing it keeps resolving.
List<String> _renderersOf(String key) {
  final out = <String>[];
  for (final f in Directory('lib').listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    if (f.path.endsWith('constants/ui_strings.dart')) continue;
    final code = _code(f.readAsStringSync());
    if (code.contains("uiStrings['$key']") ||
        code.contains('uiStrings["$key"]')) {
      out.add(f.path);
    }
  }
  return out;
}

void main() {
  late String settingsSrc;
  late String onboardingSrc;

  setUpAll(() {
    settingsSrc = File('lib/pages/settings_page.dart').readAsStringSync();
    onboardingSrc =
        File('lib/widgets/onboarding_dialog.dart').readAsStringSync();
    // Trap 39: prove the extraction is non-vacuous before asserting on
    // it. A file read that silently returned '' would make every
    // "does not contain" case below pass for the wrong reason.
    expect(settingsSrc.length, greaterThan(50000));
    expect(onboardingSrc.length, greaterThan(2000));
    expect(settingsSrc.contains('kChinaMode'), isTrue,
        reason: 'settings_page must still use kChinaMode somewhere — '
            'if it does not, the Google-gate case below is vacuous');
  });

  test('sanity: the renderer scan can actually find a renderer', () {
    // Without this the two "no longer read" cases could pass because
    // the scan is broken rather than because the call sites are gone.
    // `cloudPrivacyNotice` is read by settings_page.dart's own notice,
    // right where `chinaCloudUnavailable` used to be read.
    expect(_renderersOf('cloudPrivacyNotice'), isNotEmpty);
  });

  test('sanity: this test build is not China mode', () {
    // Stated so the reasoning above is checkable rather than asserted.
    expect(kChinaMode, isFalse);
  });

  test('the email sign-in button is NOT gated on kChinaMode', () {
    final googleAt = settingsSrc.indexOf('_googleSignInButton(context');
    final emailAt = settingsSrc.indexOf("Key('settings.emailSignIn')");
    expect(googleAt, greaterThan(0), reason: 'Google button not found');
    expect(emailAt, greaterThan(googleAt),
        reason: 'email button not found after the Google button');

    // Everything between the Google button and the email button. The
    // Google gate opens BEFORE this span and closes inside it, so the
    // span is where a new `kChinaMode` wrapper around the email button
    // would have to appear.
    final between = settingsSrc.substring(googleAt, emailAt);
    expect(between.contains('],'), isTrue,
        reason: "the Google gate's block does not close before the "
            'email button — the email button may be inside it');
    expect(between.contains('kChinaMode'), isFalse,
        reason: 'the email sign-in button was put back behind a '
            'kChinaMode gate; a China-build reader loses their only '
            'route to an account');
  });

  test('the Google sign-in button IS still gated on kChinaMode', () {
    // This gate is correct and must not be removed as collateral:
    // Google sign-in needs `accounts.google.com` plus the
    // `/__/auth/*` handler netlify.toml proxies, and the account
    // chooser cannot be proxied.
    final gate = settingsSrc.indexOf('if (!kChinaMode && auth.isConfigured)');
    expect(gate, greaterThan(0),
        reason: 'the Google sign-in China gate is gone');
    final window = settingsSrc.substring(
        gate, (gate + 300).clamp(0, settingsSrc.length));
    expect(window.contains('_googleSignInButton'), isTrue,
        reason: 'the !kChinaMode gate no longer guards the Google '
            'button — it is guarding something else');
  });

  test('sync is started from the sign-in callback, not from boot', () {
    expect(
      settingsSrc.contains('RealtimeDbSyncService.instance.init()'),
      isTrue,
    );
    final onSignedInAt = settingsSrc.indexOf('onSignedIn: () =>');
    expect(onSignedInAt, greaterThan(0),
        reason: 'the email sheet no longer starts sync on success');
    final window = settingsSrc.substring(
        onSignedInAt, (onSignedInAt + 200).clamp(0, settingsSrc.length));
    expect(window.contains('RealtimeDbSyncService.instance.init()'), isTrue,
        reason: 'onSignedIn no longer starts RealtimeDbSyncService');
  });

  test('chinaCloudUnavailable is no longer read anywhere in lib/', () {
    // The string said flatly that cloud sync is unavailable in the
    // China build. It stays in ui_strings (an append-only table an
    // external translation file may reference) but nothing may render
    // it, because it is false for exactly the readers who get email
    // sign-in working.
    expect(_renderersOf('chinaCloudUnavailable'), isEmpty,
        reason: 'a file still renders the retired claim');
  });

  test('onboardCustomizeBodyChina is no longer read anywhere in lib/', () {
    expect(_renderersOf('onboardCustomizeBodyChina'), isEmpty,
        reason: 'a file still renders the retired claim');
  });

  test('the onboarding tour no longer branches on kChinaMode at all', () {
    expect(_code(onboardingSrc).contains('kChinaMode'), isFalse,
        reason: 'the Customize slide is back on a compile-time branch');
    expect(onboardingSrc.contains('onboardCustomizeBodyEmail'), isTrue,
        reason: 'the replacement copy is not being used');
  });

  test('build_flags.dart records WHY, at the point of use', () {
    final flags = File('lib/constants/build_flags.dart').readAsStringSync();
    expect(flags.length, greaterThan(1500),
        reason: 'extraction vacuous');
    // The reasoning a future reader needs in order not to re-gate the
    // control: which host each method talks to, and that boot is
    // deliberately untouched.
    for (final needle in const [
      'identitytoolkit.googleapis.com',
      '/__/auth/*',
      'accounts.google.com',
      'ensureInitialized',
      'main.dart:538',
    ]) {
      expect(flags.contains(needle), isTrue,
          reason: 'build_flags.dart no longer explains "$needle"');
    }
  });
}
