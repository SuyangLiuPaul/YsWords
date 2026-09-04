// 2026-09-04: the NASB is hidden from the picker on every platform.
//
// Two days earlier `kWebRestrictedVersions` hid it on web only, "pending
// the publisher's answer", on the reasoning that bundling inside a native
// app is a materially weaker act than serving a downloadable file. The
// owner decided not to wait: it is now offered nowhere.
//
// Hiding an edition is never one line, and the 2026-09-02 web strip is
// the proof — hiding it from the picker shipped a boot crash on every
// English-locale web client, because two code paths set the version
// WITHOUT going through the picker (a fresh `locale == 'en'` install, and
// a returning reader's stored preference). This file pins the whole
// chain, not just the flag.
import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/constants/bible_versions.dart';

void main() {
  test('the NASB is not offered in any language list', () {
    expect(disabledVersions, contains('nasb'));
    expect(availableVersions.map((v) => v.value), isNot(contains('nasb')));
    expect(versionsForLanguage('en').map((v) => v.value),
        isNot(contains('nasb')));
  });

  test('hidden, NOT removed — the entry and its asset both stay', () {
    // The catalogue keeps the entry so an old shared link or a stored
    // preference naming `nasb` still resolves to something describable
    // rather than falling off the end of the world. Deleting the entry
    // and the asset is the NIV treatment; it is a separate decision and
    // it is the owner's to make.
    expect(bibleVersions.map((v) => v.value), contains('nasb'));
    expect(bibleVersionLanguage('nasb'), 'en');
  });

  test('a stored or defaulted nasb lands on the KJV, not on nothing', () {
    // English falls back inside its own family, and the KJV is public
    // domain — it can never itself become restricted. This is the guard
    // whose absence crashed v1.4.193/194 on boot.
    expect(resolvableVersion('nasb'), 'kjv');
    // And the same through the explicit-list door the web build needs.
    expect(resolvableVersionFrom('nasb', availableVersions), 'kjv');
  });

  test('English is still a language the picker offers', () {
    // Hiding the wrong edition could empty a whole language out of the
    // selector. English must survive on KJV + LEB.
    expect(bibleLanguageOrder, contains('en'));
    expect(versionsForLanguage('en').map((v) => v.value),
        containsAll(<String>['kjv', 'leb']));
  });

  test('the LEB is deliberately still offered on native', () {
    // Pinned so this is a decision and not a drift: the same 2026-09-02
    // note names the LEB in the same licensing position as the NASB, and
    // it stays web-restricted. The owner asked for the NASB only, so the
    // LEB is still here — if that changes, this expectation is the line
    // that should be edited on purpose.
    expect(kWebRestrictedVersions, containsAll(<String>['nasb', 'leb']));
    expect(availableVersions.map((v) => v.value), contains('leb'));
  });
}
