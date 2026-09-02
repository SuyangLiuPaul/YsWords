import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/constants/ui_strings.dart';

/// The LEB's licence does not merely ask to be credited — it prescribes
/// the exact sentence, and two phrases inside it that must be links.
///
/// Read from the LEB copyright statement 2026-09-02. Nobody in this
/// repository had read it before: every note treated LEB as
/// NASB-shaped, and the app shipped
/// `© Logos Bible Software · non-commercial study only` — which is
/// neither the required text nor a restriction the licence imposes in
/// those words. The licence in fact permits giving the whole text away
/// ("you can give away the Lexham English Bible, but you can't sell it
/// on its own"); what it does NOT permit is using it without this
/// attribution.
void main() {
  test('the attribution is the licence text, word for word', () {
    // Retyping this from the licence is the point. If it ever needs to
    // change, change it against the published statement, not against
    // what reads nicely.
    expect(
      kLebAttribution,
      'Scripture quotations marked (LEB) are from the Lexham English '
      'Bible. Copyright 2012 Logos Bible Software. Lexham is a registered '
      'trademark of Logos Bible Software.',
    );
  });

  test('it is not translated — a translation is a different string', () {
    for (final locale in ['en', 'zh-Hans', 'zh-Hant']) {
      expect(uiStrings['aboutLicenseLeb']?[locale], kLebAttribution,
          reason: locale);
    }
  });

  test('the old invented restriction is gone from the whole repo', () {
    // "non-commercial study only" was ours, not theirs.
    final ui = File('lib/constants/ui_strings.dart').readAsStringSync();
    final about = File('lib/pages/about_page.dart').readAsStringSync();
    for (final f in {'ui_strings': ui, 'about_page': about}.entries) {
      // Allowed in a comment explaining the history; not as a value.
      final asValue = RegExp(
          r"""['"]©\s*Logos Bible Software[^'"]*non-commercial""");
      expect(asValue.hasMatch(f.value), isFalse, reason: f.key);
    }
  });

  test('both phrases the licence names are linked', () {
    expect(kLebAttributionLinks.keys.toSet(),
        {'Lexham English Bible', 'Logos Bible Software'});
    // And each phrase must actually occur in the sentence, or the link
    // silently never renders.
    for (final phrase in kLebAttributionLinks.keys) {
      expect(kLebAttribution, contains(phrase), reason: phrase);
    }
  });

  test('the link targets are the hosts the licence names', () {
    // The licence prints http://www.lexhamenglishbible.com; that host
    // has no DNS record, so the bare domain is used. Both now redirect
    // to bakerbookhouse.com after Baker acquired the Lexham Press
    // imprint — that is the rights holder's redirect, not our choice,
    // and substituting a "better" destination would be us overriding
    // the address the licence names.
    expect(kLebAttributionLinks['Lexham English Bible'],
        'https://lexhamenglishbible.com');
    expect(kLebAttributionLinks['Logos Bible Software'],
        'https://www.logos.com');
    for (final u in kLebAttributionLinks.values) {
      expect(u, startsWith('https://'), reason: '$u should not be plain http');
    }
  });

  test('the About row uses the phrase links, not a row-level url', () {
    // A single row-level url cannot express two links inside one
    // sentence, and an InkWell over the row would swallow the taps.
    final about = File('lib/pages/about_page.dart').readAsStringSync();
    expect(about, contains('linkPhrases: kLebAttributionLinks'));
    expect(about, isNot(contains('lexhampress.com/product/9461')),
        reason: 'that product url now 301s to a bookshop search');
  });
}
