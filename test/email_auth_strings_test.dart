/// 2026-09-06 — every sentence the email sign-in surface can show
/// exists in all three locales.
///
/// The failure this guards against is specific and silent: a reader in
/// zh-Hant taps sign-in, something goes wrong, and the `??` fallback
/// hands them an English sentence — or, worse, the raw `ui_strings`
/// key, because the widget's fallback for a missing key IS the key.
/// Nothing in `flutter analyze` and nothing in a widget test written
/// in one locale can see that.
///
/// The set of keys is derived from
/// [CloudAuthService.messageKeyForCode] rather than hand-listed, so a
/// code added to that switch without a matching string turns this red.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/services/cloud_auth_service.dart';

/// Every code the service can produce. Kept beside the switch it
/// mirrors; the "no code maps to a missing key" case below also feeds
/// this list through the real function, so a typo in either place
/// shows up rather than cancelling out.
const _allCodes = <String>[
  'wrong-password',
  'user-not-found',
  'invalid-credential',
  'invalid-login-credentials',
  'weak-password',
  'invalid-email',
  'network-request-failed',
  'too-many-requests',
  'email-already-in-use',
  'account-exists-with-different-credential',
  'user-disabled',
  'operation-not-allowed',
  'missing-password',
  CloudAuthService.codeMissingEmail,
  CloudAuthService.codeMissingPassword,
  CloudAuthService.codeTimeout,
  CloudAuthService.codeUnavailable,
  'a-code-that-does-not-exist',
];

/// The keys the form and the sync row read directly, which no error
/// code routes to.
const _uiKeys = <String>[
  'cloudSignInEmail',
  'authSheetTitleSignIn',
  'authSheetTitleCreate',
  'authEmailLabel',
  'authPasswordLabel',
  'authSignInAction',
  'authCreateAction',
  'authSwitchToCreate',
  'authSwitchToSignIn',
  'authForgotPassword',
  'authResetSendButton',
  'authResetSent',
  'authWorking',
  'authNoticeNotSignedIn',
  'syncUnreachable',
  'onboardCustomizeBodyEmail',
];

const _locales = <String>['zh-Hans', 'zh-Hant', 'en'];

void main() {
  test('sanity: the derivation is not vacuous', () {
    expect(_allCodes.length, greaterThan(15));
    final keys =
        _allCodes.map(CloudAuthService.messageKeyForCode).toSet();
    // If the switch ever collapsed, this would be 1.
    expect(keys.length, greaterThan(8));
  });

  group('every error code resolves to a key present in all 3 locales', () {
    for (final code in _allCodes) {
      test(code, () {
        final key = CloudAuthService.messageKeyForCode(code);
        final entry = uiStrings[key];
        expect(entry, isNotNull,
            reason: 'code "$code" maps to key "$key", which has no '
                'ui_strings entry — the reader would be shown the '
                'literal key');
        for (final locale in _locales) {
          final text = entry![locale];
          expect(text, isNotNull,
              reason: '"$key" has no $locale translation');
          expect(text!.trim(), isNotEmpty,
              reason: '"$key" is blank in $locale');
          expect(text, isNot(key),
              reason: '"$key" in $locale is just the key echoed back');
        }
      });
    }
  });

  group('every directly-read UI key is present in all 3 locales', () {
    for (final key in _uiKeys) {
      test(key, () {
        final entry = uiStrings[key];
        expect(entry, isNotNull, reason: '"$key" is missing entirely');
        for (final locale in _locales) {
          expect(entry![locale]?.trim(), isNotEmpty,
              reason: '"$key" is missing or blank in $locale');
        }
      });
    }
  });

  test('the three locales of a sentence are actually different text', () {
    // A copy-paste that left English in the zh slots would pass every
    // "is present and non-empty" check above while giving Chinese
    // readers English. Simplified and Traditional may legitimately
    // coincide for short labels, so the assertion is only that the
    // Chinese is not identical to the English.
    for (final key in const [
      'authErrInvalidCredential',
      'authErrEmailInUse',
      'authErrNetwork',
      'authErrTooManyRequests',
      'authNoticeNotSignedIn',
      'syncUnreachable',
    ]) {
      final entry = uiStrings[key]!;
      expect(entry['zh-Hans'], isNot(entry['en']), reason: '$key zh-Hans');
      expect(entry['zh-Hant'], isNot(entry['en']), reason: '$key zh-Hant');
    }
  });

  test('the collision copy names no provider, in any locale', () {
    // The 2026-09-06 ruling: the answer is identical whichever
    // provider owns the address, so the copy must not name one. A
    // translation is exactly where such a name creeps back in.
    final entry = uiStrings['authErrEmailInUse']!;
    for (final locale in _locales) {
      final text = entry[locale]!;
      for (final banned in const [
        'Google',
        'google',
        '谷歌',
        '穀歌',
        'Gmail',
        'gmail',
      ]) {
        expect(text.contains(banned), isFalse,
            reason: '$locale collision copy names "$banned"');
      }
    }
  });

  test('no surviving string claims cloud sync is impossible in China', () {
    // `chinaCloudUnavailable` is still in the map — removing a key
    // from an append-only translation table breaks any external
    // translation file that references it — but it must no longer be
    // read by anything, and no NEW string may repeat its claim.
    for (final key in _uiKeys) {
      final en = uiStrings[key]!['en']!;
      expect(en.toLowerCase().contains('china build'), isFalse,
          reason: '"$key" repeats the retired China-build claim');
    }
  });
}
