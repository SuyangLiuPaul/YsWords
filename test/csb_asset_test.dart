import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:yswords/constants/bible_versions.dart';
import 'package:yswords/constants/ui_strings.dart';

/// `assets/csb.json` — the CSB 2017, imported 2026-09-07.
///
/// Licence and the decisions behind it: `docs/permissions/`. The 2017
/// Holman grant, Pastor Raymond's extension of it (he is the named
/// licensee), and the owner's decision on worldwide distribution.
///
/// **This text is not the module as received**, and that is the reason
/// this file exists. `tools/import_csb.py` restores the divine name in
/// 962 verses where the source had lost CSB's own small-caps LORD and
/// left a bare "Lord" behind — Deuteronomy 6:4, the Shema, among them.
/// Loading it untouched would have put a Bible that spells the divine
/// name two ways into an app named for that name.
///
/// Every assertion below is one that failed at some point while the
/// importer was being written. In order: markup left in the text, the
/// Shema reading "The Yahweh our God", Adonai in Psalms 44/62/116 being
/// renamed, and the article surviving in front of the name.
void main() {
  late List<Map<String, dynamic>> csb;
  late List<Map<String, dynamic>> kjv;

  setUpAll(() {
    List<Map<String, dynamic>> load(String p) =>
        (json.decode(File(p).readAsStringSync()) as List)
            .cast<Map<String, dynamic>>();
    csb = load('assets/csb.json');
    kjv = load('assets/kjv.json');
  });

  String verse(String id) =>
      csb.firstWhere((r) => r['id'] == id)['text'] as String;

  test('it is a whole Bible, versified like the one already shipping', () {
    // Against KJV rather than a typed-in number: the importer maps book
    // names by canonical POSITION, so if the two ever disagreed about
    // versification every verse after the disagreement would be filed
    // under the wrong reference while the count still looked right.
    expect(csb, hasLength(31102));
    expect(csb.map((r) => r['book']).toSet(), hasLength(66));
    expect(csb.map((r) => r['id']).toList(), kjv.map((r) => r['id']).toList());
    expect(csb.map((r) => r['book']).toList(),
        kjv.map((r) => r['book']).toList());
  });

  test('no markup survived the import', () {
    // The module carries five kinds — Strong's numbers, <CL>, <CM>,
    // <TS…>/<Ts> section headings and <redletter> — plus two malformed
    // Strong's tags (WH5766x, WH853x) that a `<W[HG]\d+>` pattern misses.
    final withTags = csb.where((r) => (r['text'] as String).contains('<'));
    expect(withTags, isEmpty,
        reason: withTags.isEmpty ? '' : 'e.g. ${withTags.first}');
    for (final r in csb) {
      final t = r['text'] as String;
      expect(t.contains('  '), isFalse, reason: '${r['id']}: double space');
      expect(RegExp(r'\s[,.;:!?]').hasMatch(t), isFalse,
          reason: '${r['id']}: space before punctuation — the residue the '
              'lost small-caps run left behind');
      expect(t, t.trim());
    }
  });

  group('the divine name', () {
    test('the Shema reads as a name, not as a title', () {
      // "The LORD our God, the LORD is one" in print. The module had
      // lost the small caps and read "The Lord  our God"; the first
      // version of the importer replaced only the word and produced
      // "The Yahweh our God, the Yahweh is one", which is why the
      // article is part of the rule and why this assertion is exact.
      expect(verse('005006004'),
          contains('Yahweh our God, Yahweh is one'));
    });

    test('the article never survives in front of it', () {
      // Across the 5,041 verses the module had already restored, "The
      // Yahweh" appears zero times. This holds the imported ones to the
      // same convention.
      for (final r in csb) {
        final t = r['text'] as String;
        expect(t.contains('the Yahweh'), isFalse, reason: '${r['id']}: $t');
        expect(t.contains('The Yahweh'), isFalse, reason: '${r['id']}: $t');
      }
    });

    test('Adonai is left alone — Psalm 110:1 carries both', () {
      // The one verse that proves the rule discriminates rather than
      // sweeps: YHWH and Adonai in the same sentence.
      final ps110 = verse('019110001');
      expect(ps110, contains('declaration of Yahweh'));
      expect(ps110, contains('to my Lord'));
    });

    test('the three vocative Psalms keep their Lord', () {
      // These carry the same typographic residue as a lost LORD, so the
      // residue alone would have renamed them. The Chinese 雅伟版 reads
      // 主啊 at all three — Adonai — and that is what decides a bare
      // vocative. Had this not been checked, three Psalms would address
      // Adonai by the personal name.
      for (final id in const ['019044023', '019062012', '019116008']) {
        expect(verse(id), contains('Lord'), reason: id);
        expect(verse(id), isNot(contains('Yahweh')), reason: id);
      }
    });

    test('and the three that are the name, keep it', () {
      // Same shape, opposite answer — KJV prints all-caps LORD at each.
      // Without these the test above could be satisfied by a rule that
      // simply never touches a bare vocative.
      //
      // 1Kgs 8:26 is deliberately NOT here. It looks like the same case
      // — "Now Lord God of Israel" — and was going to be restored by
      // hand until KJV was consulted: "And now, O God of Israel", no
      // LORD, no name in the Hebrew. It keeps its Lord.
      for (final id in const ['009014041', '013017016', '029002017']) {
        expect(verse(id), contains('Yahweh'), reason: id);
      }
      expect(verse('011008026'), contains('Lord'));
      expect(verse('011008026'), isNot(contains('Yahweh')));
    });

    test('the module\'s own stray articles were repaired too', () {
      // The 5,041 verses that arrived already restored included ten that
      // kept the article: "This is the Yahweh's gate", "the house of the
      // Yahweh God", "Holy to the Yahweh". The blanket assertion above
      // covers them, and these name the two that read worst so a future
      // reader knows they were a real defect and not a rule misfiring.
      expect(verse('019118020'), contains("This is Yahweh’s gate"));
      expect(verse('002028036'), contains('Holy to Yahweh'));
    });

    test('the population is pinned', () {
      // 5,041 already in the module + the restorations. A re-import that
      // silently lost the divine-name pass would sit at 5,041 and every
      // spot check above except the Shema would still pass.
      final withName = csb.where((r) => (r['text'] as String)
          .contains('Yahweh'));
      expect(withName, hasLength(5801));
    });
  });

  test('the text is CSB 2017, not HCSB', () {
    // The source table is named `bsapp_bible_hcsbs`. It is a legacy key;
    // these are the readings that tell the two editions apart, and they
    // are also what the credit line below is required to be right about.
    expect(verse('019023001'), contains('I have what I need'));
    expect(verse('045001001'), contains('servant'));
    expect(verse('043003016'), contains('his one and only Son'));
  });

  test('the version is registered and offered', () {
    final csbInfo =
        bibleVersions.where((v) => v.value == 'csb').toList();
    expect(csbInfo, hasLength(1));
    expect(csbInfo.single.language, 'en');
    expect(kWebRestrictedVersions.contains('csb'), isFalse,
        reason: 'the owner decided worldwide distribution is fine — see '
            'docs/permissions/. NASB is the restricted one, not this.');
    expect(File('pubspec.yaml').readAsStringSync(),
        contains('assets/csb.json'),
        reason: 'an unlisted asset is a version that 404s at runtime');
  });

  test('the credit line Holman requires is present, word for word', () {
    // The grant names this sentence and says it must appear on the
    // copyright or title page. The About page is that page. Quoted here
    // in full deliberately: a paraphrase of it is a breach of the grant,
    // and a test that checked only a fragment would not notice one.
    const required =
        'Scripture quotations marked CSB®, are taken from the Christian '
        'Standard Bible®, Copyright © 2017 by Holman Bible Publishers. '
        'Used by permission. Christian Standard Bible®, and CSB® are '
        'federally registered trademarks of Holman Bible Publishers.';
    for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
      expect(uiStrings['aboutLicenseCsb']?[locale], required,
          reason: '$locale: the grant does not allow this to be '
              'translated or trimmed');
    }
    expect(File('lib/pages/about_page.dart').readAsStringSync(),
        contains("uiStrings['aboutLicenseCsb']"),
        reason: 'the string existing is not the same as the page drawing it');
  });
}
