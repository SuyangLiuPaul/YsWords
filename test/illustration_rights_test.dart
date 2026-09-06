import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/bible_map.dart';
import 'package:yswords/pages/about_page.dart';
import 'package:yswords/services/map_service.dart';

/// Regression tests for the Sweet Publishing / Jim Padgett attribution.
///
/// `e2fe38c1` (2026-09-06) added a `rights` block to 40 of the 1192
/// entries in `assets/maps_index.json` — the only 40 in the index that
/// carry a live CC BY-SA 3.0 obligation with a named artist — but left
/// the About page rendering one blanket "public domain / CC" sentence
/// for the whole set. `lib/models/bible_map.dart`'s doc comment cited
/// this file by name before it existed; this is that file.
///
/// Two things are pinned:
///   1. A FROZEN allowlist of the 40 ids that carry a `rights` block, so
///      a future import cannot silently join the no-rights-block
///      majority (which would drop a real obligation) or silently
///      shrink the credited set (which would over-claim once more).
///   2. That every distinct rights grouping actually present in the
///      asset is rendered on the About page — not merely that SOME
///      maps-related text renders, which the pre-fix blanket sentence
///      would already have satisfied.
void main() {
  late List<Map<String, dynamic>> rawEntries;

  setUpAll(() {
    final raw = File('assets/maps_index.json').readAsStringSync();
    rawEntries = (json.decode(raw) as List).cast<Map<String, dynamic>>();
  });

  // Frozen 2026-09-06 off e2fe38c1. If this fails because the set grew,
  // a new illustration gained a rights block — extend the list AND the
  // About page's rendering deliberately, don't just widen this set to
  // make the test pass. If it shrank, find out why before updating it.
  const frozenSweetIds = <String>{
    'illus_sweet_1_chronicles_10_1',
    'illus_sweet_1_chronicles_11_1',
    'illus_sweet_1_chronicles_13_1',
    'illus_sweet_1_chronicles_15_1',
    'illus_sweet_1_chronicles_17_1',
    'illus_sweet_1_chronicles_19_1',
    'illus_sweet_1_chronicles_22_1',
    'illus_sweet_1_chronicles_24_1',
    'illus_sweet_1_john_2_1',
    'illus_sweet_1_john_3_1',
    'illus_sweet_1_john_4_1',
    'illus_sweet_1_timothy_1_1',
    'illus_sweet_2_chronicles_10_1',
    'illus_sweet_2_chronicles_1_1',
    'illus_sweet_2_chronicles_24_1',
    'illus_sweet_2_chronicles_2_1',
    'illus_sweet_2_chronicles_34_1',
    'illus_sweet_2_chronicles_35_1',
    'illus_sweet_2_chronicles_3_1',
    'illus_sweet_2_chronicles_6_1',
    'illus_sweet_2_timothy_1_1',
    'illus_sweet_2_timothy_2_1',
    'illus_sweet_2_timothy_4_1',
    'illus_sweet_ezra_10_1',
    'illus_sweet_ezra_1_1',
    'illus_sweet_ezra_9_1',
    'illus_sweet_james_1_1',
    'illus_sweet_james_2_1',
    'illus_sweet_nehemiah_1_1',
    'illus_sweet_nehemiah_2_1',
    'illus_sweet_nehemiah_3_1',
    'illus_sweet_nehemiah_4_1',
    'illus_sweet_nehemiah_6_1',
    'illus_sweet_psalms_119_1',
    'illus_sweet_psalms_23_1',
    'illus_sweet_psalms_25_1',
    'illus_sweet_psalms_31_1',
    'illus_sweet_psalms_51_1',
    'illus_sweet_psalms_52_1',
    'illus_sweet_titus_1_1',
  };

  test('exactly the frozen 40 ids carry a rights block — no silent drift',
      () {
    final withRights = rawEntries
        .where((e) => e['rights'] != null)
        .map((e) => e['id'] as String)
        .toSet();
    expect(withRights, frozenSweetIds,
        reason: 'the set of illustrations carrying a `rights` block '
            'changed. If an import added one, extend the About page '
            'row (and this allowlist) deliberately; if one vanished, '
            'find out why before updating this test.');
    expect(withRights.length, 40);
  });

  test('all 40 collapse to exactly one attribution grouping', () {
    final maps = rawEntries
        .where((e) => frozenSweetIds.contains(e['id']))
        .map(BibleMap.fromJson)
        .toList();
    expect(maps.length, 40);
    final keys = maps.map((m) => m.rights!.attributionKey).toSet();
    expect(keys.length, 1,
        reason: 'if this ever fails, the About page must render one row '
            'per grouping, not assume the historic single Sweet '
            'Publishing grouping still covers everything');
    for (final m in maps) {
      expect(m.requiresAttribution, isTrue, reason: m.id);
    }
  });

  test('no entry outside the frozen 40 carries a rights block '
      '(the other 1152 stay unasserted, not flipped to a PD claim)', () {
    final withRights =
        rawEntries.where((e) => e['rights'] != null).length;
    expect(withRights, 40);
    expect(rawEntries.length, greaterThan(1000));
  });

  group('the About page renders the verified credit', () {
    Widget wrap() => ChangeNotifierProvider<AppSettings>(
          create: (_) => AppSettings(),
          child: const MaterialApp(home: AboutPage()),
        );

    // The maps row sits well below the fold on a default test surface,
    // and AboutPage's body is a plain (non-builder) ListView, whose
    // sliver machinery only builds children near the viewport — so a
    // normal-sized surface would never build the row at all and every
    // `find` below would report "0 widgets" regardless of whether the
    // credit rendered. A tall surface makes the whole page fit without
    // scrolling.
    void useTallSurface(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 8000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    testWidgets('names the holder, the artist, the licence and carries '
        'the modification notice', (tester) async {
      await tester.runAsync(MapService.loadMaps);
      useTallSurface(tester);
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      // The rights holder's own credit sentence, verbatim — read off
      // the asset, not retyped here, so this test cannot itself drift
      // from what e2fe38c1 recorded.
      final sweet = rawEntries.firstWhere(
          (e) => e['id'] == 'illus_sweet_ezra_1_1')['rights']
          as Map<String, dynamic>;
      final credit = sweet['credit'] as String;
      // AppSettings() defaults to 'zh-Hans' synchronously (its async
      // persisted-locale / system-detection load hasn't run yet at
      // this point), and that is the locale the page actually renders
      // with here — the modification notice IS localised, unlike the
      // credit sentence, so it must be read in the same locale.
      final modification =
          (sweet['modification'] as Map<String, dynamic>)['zh-Hans']
              as String;

      expect(credit, contains('Jim Padgett'));
      expect(credit, contains('Sweet Publishing'));
      expect(credit, contains('CC-BY-SA 3.0'));

      expect(
        find.textContaining(credit, findRichText: true),
        findsOneWidget,
        reason: 'the rights holder\'s own credit sentence must appear '
            'verbatim somewhere on the About page',
      );
      expect(
        find.textContaining(modification, findRichText: true),
        findsOneWidget,
        reason: 'the modification notice (CC BY-SA 3.0 requires stating '
            'whether the work was changed) must render',
      );
    });

    test('the blanket line no longer claims PD/CC for everything, in any '
        'of the three locales, and does not flip to claiming PD for the '
        'other 1152 either', () {
      const oldBlanket = <String, String>{
        'en': 'Public domain / Creative Commons archives.',
        'zh-Hans': '来源于公有领域 / Creative Commons 资源库。',
        'zh-Hant': '來源於公有領域 / Creative Commons 資源庫。',
      };
      for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
        final current = uiStrings['aboutLicenseMaps']?[locale];
        expect(current, isNotNull, reason: 'aboutLicenseMaps/$locale missing');
        expect(current, isNot(oldBlanket[locale]),
            reason: 'the false blanket PD/CC claim is still the maps '
                'row\'s licence text in $locale');
        // Must not assert the Sweet Publishing licence for the WHOLE
        // set — that would be the same error pointing the other way.
        expect(current!.toLowerCase(), isNot(contains('cc by-sa')));
      }
    });
  });
}
