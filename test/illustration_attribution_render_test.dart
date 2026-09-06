import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/bible_map.dart';
import 'package:yswords/pages/about_page.dart';
import 'package:yswords/services/map_service.dart';

/// Does the About page actually DISCHARGE the licence, or merely
/// mention it?
///
/// `e2fe38c1` put a verified `rights` block on the 40 Sweet Publishing
/// / Jim Padgett illustrations in `assets/maps_index.json` and rendered
/// none of it: About showed one sentence — "Public domain / Creative
/// Commons archives." — for all 1192. Data alone discharges nothing;
/// the obligation is a rendering obligation.
///
/// What CC BY-SA 3.0 asks for, read off the deed on 2026-09-06 rather
/// than remembered (https://creativecommons.org/licenses/by-sa/3.0/):
/// "give appropriate credit, provide a link to the license, and
/// indicate if changes were made", where appropriate credit is "the
/// name of the creator and attribution parties, a copyright notice, a
/// license notice, a disclaimer notice, and a link to the material",
/// and where — the deed says this explicitly of pre-4.0 licences —
/// "CC licenses prior to Version 4.0 also require you to provide the
/// title of the material if supplied".
///
/// So five things must reach the screen: TITLE, AUTHOR, SOURCE,
/// LICENCE-WITH-LINK, and a statement about MODIFICATION. Every one of
/// them is asserted below, in all three locales, for every rights
/// grouping the asset actually contains — never for a hardcoded
/// "Sweet Publishing", which is the failure mode this file exists to
/// catch.
///
/// Its companion is `illustration_attribution_new_grouping_test.dart`,
/// which swaps the asset bundle for an index carrying a copyleft
/// grouping that appears nowhere in this repo and requires the page to
/// credit it. A page that prints "Sweet Publishing" from a constant
/// passes everything in THIS file and fails that one. It lives in its
/// own file because `MapService` memoises the load in a static that
/// `clearCache()` does not reset, so the swap only takes in a process
/// that has not read the real index yet.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const locales = <String>['en', 'zh-Hans', 'zh-Hant'];

  late List<BibleMap> onDisk;

  setUpAll(() {
    // Read the same file the app bundles. Nothing about the licence is
    // retyped in this test: every expected string is pulled from the
    // asset, so the test cannot drift from the verified record and
    // cannot be satisfied by a constant it defines itself.
    final raw = File('assets/maps_index.json').readAsStringSync();
    onDisk = (json.decode(raw) as List)
        .map((e) => BibleMap.fromJson(e as Map<String, dynamic>))
        .toList();
  });

  /// Distinct attribution obligations in [maps], in index order.
  List<List<MapRights>> groupsOf(List<BibleMap> maps) {
    final order = <String>[];
    final byKey = <String, List<MapRights>>{};
    for (final m in maps) {
      final r = m.rights;
      if (r == null || !r.attributionRequired) continue;
      final k = r.attributionKey;
      if (!byKey.containsKey(k)) order.add(k);
      (byKey[k] ??= <MapRights>[]).add(r);
    }
    return [for (final k in order) byKey[k]!];
  }

  Future<void> pumpAbout(WidgetTester tester, String locale) async {
    SharedPreferences.setMockInitialValues({'locale': locale});
    // Tall enough that the whole page is laid out — a ListView only
    // builds what fits, and an attribution scrolled out of existence
    // would look identical to one that renders.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1000, 9000);
    addTearDown(tester.view.reset);
    // flutter_test draws every glyph as a square of the font size, so
    // the English section headers overflow the 520 px settings column
    // that real fonts fit comfortably — an artifact of the test font,
    // not of this page (`_SectionTitle`, untouched here, has done it
    // since before this work; the zh locales fit because their headers
    // are shorter). Shrink the scaler so a font artifact does not
    // masquerade as an attribution failure. Real overflow coverage
    // lives in `responsive_overflow_smoke_test.dart`.
    tester.platformDispatcher.textScaleFactorTestValue = 0.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.runAsync(MapService.loadMaps);
    // AppSettings does not read prefs in its constructor, so the locale
    // has to be set explicitly — otherwise every locale in this loop
    // would silently render the zh-Hans default and three passing tests
    // would be one test run three times.
    final settings = AppSettings();
    if (settings.locale != locale) {
      await tester.runAsync(() => settings.setLocale(locale));
    }
    expect(settings.locale, locale);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppSettings>.value(
        value: settings,
        child: const MaterialApp(home: AboutPage()),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
    // The list of works is behind an expander; open it.
    final works = find.byKey(const ValueKey('mapRightsWorks'));
    if (works.evaluate().isNotEmpty) {
      await tester.tap(works);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
    }
  }

  /// Every string the page actually rendered, plain-text.
  List<String> renderedText(WidgetTester tester) {
    final out = <String>[];
    for (final t in tester.widgetList<Text>(find.byType(Text))) {
      final data = t.data;
      if (data != null) {
        out.add(data);
      } else {
        final span = t.textSpan;
        if (span != null) out.add(span.toPlainText());
      }
    }
    return out;
  }

  bool showsSomewhere(List<String> page, String needle) =>
      page.any((s) => s.contains(needle));

  group('the CC BY-SA 3.0 attribution reaches the screen', () {
    for (final locale in locales) {
      testWidgets('title, author, source, licence+link and modification '
          '— $locale', (tester) async {
        final groups = groupsOf(onDisk);
        expect(groups, isNotEmpty,
            reason: 'no entry in assets/maps_index.json requires '
                'attribution any more. If a licensed illustration was '
                'removed, say so deliberately; if the rights block was '
                'dropped, that is the bug this file exists to catch.');

        await pumpAbout(tester, locale);
        final page = renderedText(tester);

        for (final works in groups) {
          final r = works.first;

          // AUTHOR + the attribution party the licensor names.
          expect(showsSomewhere(page, r.author), isTrue,
              reason: 'the artist (${r.author}) is not on the page');
          expect(showsSomewhere(page, r.holder), isTrue,
              reason: 'the rights holder (${r.holder}) is not on the page');

          // The holder's own credit sentence, verbatim — it carries the
          // copyright notice ("Copyright 1984"), so paraphrasing it
          // drops a required element.
          expect(showsSomewhere(page, r.credit), isTrue,
              reason: 'the credit line is not rendered verbatim');

          // LICENCE notice: short name, the deed's own title, and the
          // deed URL as readable text.
          expect(showsSomewhere(page, r.license), isTrue,
              reason: '${r.license} is not named on the page');
          expect(showsSomewhere(page, r.licenseFullName), isTrue,
              reason: '${r.licenseFullName} is not named on the page');
          expect(showsSomewhere(page, r.licenseUrl), isTrue,
              reason: 'the licence deed URL is not readable on the page');

          // ...and a LINK to it, not just the text of one.
          final rowKey = ValueKey('mapRightsCredit:${r.licenseUrl}');
          expect(find.byKey(rowKey), findsOneWidget,
              reason: 'no credit row is bound to ${r.licenseUrl}');
          final tap = tester.widget<InkWell>(find
              .descendant(of: find.byKey(rowKey), matching: find.byType(InkWell))
              .first);
          expect(tap.onTap, isNotNull,
              reason: 'the credit row shows the licence URL but cannot '
                  'be tapped to open it');

          // MODIFICATION, in the reader's own language.
          final modification = r.localizedModification(locale);
          expect(modification, isNotEmpty,
              reason: 'no $locale modification statement in the asset');
          expect(showsSomewhere(page, modification), isTrue,
              reason: 'CC BY-SA 3.0 requires indicating whether changes '
                  'were made; the $locale statement is not rendered');

          // The provenance of the licence claim itself.
          expect(showsSomewhere(page, r.verified), isTrue,
              reason: 'the verification note is not rendered');

          // TITLE of each work, and a link to each SOURCE.
          for (final w in works) {
            expect(showsSomewhere(page, w.title), isTrue,
                reason: 'the title "${w.title}" is not listed; CC licences '
                    'before 4.0 require the title of the work');
            final workKey = ValueKey('mapRightsWork:${w.sourceUrl}');
            expect(find.byKey(workKey), findsOneWidget,
                reason: 'nothing links to ${w.sourceUrl}');
            final open = tester.widget<InkWell>(find.byKey(workKey));
            expect(open.onTap, isNotNull,
                reason: 'the source row for "${w.title}" is not tappable');
          }
        }
      });
    }

    testWidgets('the page speaks for the licensed works only — the rest '
        'are counted, not claimed', (tester) async {
      final licensed = onDisk.where((m) => m.rights != null).length;
      final unasserted = onDisk.length - licensed;
      expect(licensed, greaterThan(0));
      expect(unasserted, greaterThan(0));

      await pumpAbout(tester, 'en');
      final page = renderedText(tester);

      // Exactly one linked source row per licensed work — not one per
      // illustration in the index. If this ever equals onDisk.length,
      // the page has started asserting something about entries whose
      // file pages were never checked.
      final workRows = find.byWidgetPredicate((w) =>
          w.key is ValueKey<String> &&
          (w.key as ValueKey<String>).value.startsWith('mapRightsWork:'));
      expect(workRows, findsNWidgets(licensed));

      // The count of unchecked entries is stated, and stated as a
      // non-claim.
      expect(showsSomewhere(page, '$unasserted'), isTrue,
          reason: 'the page does not say how many illustrations carry no '
              'licence record');
      expect(
        page.any((s) =>
            s.contains('$unasserted') && s.contains('no licence claim')),
        isTrue,
        reason: 'the unchecked majority must be described as unchecked, '
            'not as public domain',
      );

      // The sentence that was the non-compliance, in all three locales.
      for (final blanket in const [
        'Public domain / Creative Commons archives.',
        '来源于公有领域 / Creative Commons 资源库。',
        '來源於公有領域 / Creative Commons 資源庫。',
      ]) {
        expect(showsSomewhere(page, blanket), isFalse,
            reason: 'the blanket claim "$blanket" was false for the '
                'licensed illustrations and must not return');
      }
    });
  });


  // ── Is the committed modification statement still true? ────────────
  //
  // The asset says "Redistributed unmodified; thumbnails are cropped
  // and scaled for display only." That was true on 2026-09-06: the
  // bytes served are SHA-1 identical to the Commons originals (all 40
  // checked), the full-screen viewer draws BoxFit.contain at full size,
  // and only the 220 px strip and the 88x88 list thumb use BoxFit.cover
  // with a cacheWidth. It stops being true the moment someone recolours,
  // rotates, or composites into the image — so pin the widget that all
  // three call sites go through.
  group('the app still only crops and scales', () {
    final imageWidget =
        File('lib/widgets/illustration_image.dart').readAsStringSync();

    test('IllustrationImage applies no colour, blend or transform', () {
      for (final api in const [
        'colorBlendMode',
        'ColorFiltered',
        'ColorFilter',
        'ImageFilter',
        'Transform',
        'RotatedBox',
        'Opacity',
        'BackdropFilter',
        'CustomPaint',
      ]) {
        expect(imageWidget.contains(api), isFalse,
            reason: 'IllustrationImage now uses $api. If the app really '
                'does alter these images, `modification` in '
                'assets/maps_index.json ("Redistributed unmodified; '
                'thumbnails are cropped and scaled for display only.") '
                'is no longer true and must be rewritten before this '
                'test is relaxed.');
      }
    });

    test('every illustration render site goes through IllustrationImage',
        () {
      final callers = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.endsWith('illustration_image.dart')) continue;
        if (entity.readAsStringSync().contains('IllustrationImage(')) {
          callers.add(entity.path.replaceAll('\\', '/'));
        }
      }
      callers.sort();
      expect(
        callers,
        const [
          'lib/pages/map_viewer_page.dart',
          'lib/widgets/bible_reading_pane.dart',
        ],
        reason: 'a new place draws these illustrations. Check what it '
            'does to them before trusting the "unmodified" statement '
            'the About page now prints.',
      );
    });
  });
}
