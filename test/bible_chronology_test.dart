import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/chronology.dart';
import 'package:yswords/pages/bible_timeline_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/chronology_service.dart';
import 'package:yswords/utils/reference_parser.dart';
import 'package:yswords/utils/route_paths.dart';
import 'package:yswords/widgets/chronology_chart.dart';

/// The interactive chronology chart, asked for 2026-08-12 with a
/// reference sheet and the note that it is low priority and will take
/// several passes.
///
/// The thing this file is really guarding is not the drawing. It is the
/// claim the drawing makes. A chronology chart is exactly the artefact
/// that "reads plausibly, is wrong, and gets quoted": nothing on screen
/// distinguishes a year Genesis states from a year somebody assumed. So
/// the assertions below are mostly about provenance —
///
///   * every year on the chart is computed from stated ages, and the
///     arithmetic that produced it is carried next to it, in all three
///     locales;
///   * every citation actually opens in the reader;
///   * the numbers agree with `assets/family_tree.json`, which was
///     curated separately;
///   * the scheme in use is named ON the chart, and the schemes that
///     disagree with it are named too.
///
/// Plus the ordinary UI guarantees: it renders, every person is
/// reachable, it fits a 402 pt phone, and the horizontal scrolling stays
/// inside its own box.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ChronologyData data;
  late Map<String, dynamic> raw;
  late Map<String, Map<String, dynamic>> familyTree;

  setUpAll(() {
    raw = json.decode(
      File('assets/bible_chronology.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    data = ChronologyData.fromJson(raw);
    final fam = json.decode(
      File('assets/family_tree.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    familyTree = {
      for (final p in (fam['people'] as List).cast<Map<String, dynamic>>())
        p['id'] as String: p,
    };
  });

  // ── The data asset ────────────────────────────────────────────

  group('assets/bible_chronology.json', () {
    test('parses, and is not empty', () {
      expect(data.lifelines, isNotEmpty);
      expect(data.markers, isNotEmpty);
      expect(data.lines, isNotEmpty);
      expect(data.schemes, isNotEmpty);
      expect(data.spanEndAm, greaterThan(data.spanStartAm));
    });

    test('every year is sourced — citations and arithmetic, per locale',
        () {
      for (final l in data.lifelines) {
        expect(l.refs, isNotEmpty,
            reason: '${l.personId} has no verse citation');
        for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
          expect(l.localizedDerivation(locale), isNotEmpty,
              reason: '${l.personId} has no $locale derivation');
        }
        // The derivation has to actually show its working, not just
        // restate the year.
        expect(l.localizedDerivation('en'), contains('Genesis'),
            reason: '${l.personId} derivation cites nothing');
      }
      for (final m in data.markers) {
        expect(m.refs, isNotEmpty,
            reason: 'marker ${m.id} has no verse citation');
      }
    });

    test('every citation resolves to a passage the reader can open', () {
      final unresolvable = <String>[];
      for (final l in data.lifelines) {
        for (final r in l.refs) {
          if (firstResolvableReference(r) == null) {
            unresolvable.add('${l.personId}: $r');
          }
        }
      }
      for (final m in data.markers) {
        for (final r in m.refs) {
          if (firstResolvableReference(r) == null) {
            unresolvable.add('${m.id}: $r');
          }
        }
      }
      expect(unresolvable, isEmpty);
    });

    test('every lifeline names a person the family tree also knows', () {
      for (final l in data.lifelines) {
        expect(familyTree.containsKey(l.personId), isTrue,
            reason: '${l.personId} is not in assets/family_tree.json');
      }
    });

    test('years agree with the independently curated family tree', () {
      for (final l in data.lifelines) {
        final p = familyTree[l.personId]!;
        if (p['yearSystem'] != 'am') continue;
        expect(p['birthYear'], l.birthAm,
            reason: '${l.personId} birth disagrees with family_tree.json');
        if (l.deathAm != null) {
          expect(p['deathYear'], l.deathAm,
              reason: '${l.personId} death disagrees with family_tree.json');
        }
      }
    });

    test('lifespan is death minus birth, and bars run forwards', () {
      for (final l in data.lifelines) {
        expect(l.birthAm, greaterThanOrEqualTo(data.spanStartAm));
        if (l.deathAm == null) continue;
        expect(l.deathAm, greaterThan(l.birthAm),
            reason: '${l.personId} dies before he is born');
        expect(l.deathAm! - l.birthAm, l.lifespan,
            reason: '${l.personId} lifespan does not match the bar');
        expect(l.deathAm, lessThanOrEqualTo(data.spanEndAm));
      }
    });

    test('every lifeline belongs to a declared line of descent', () {
      for (final l in data.lifelines) {
        expect(data.lineById(l.lineId), isNotNull,
            reason: '${l.personId} is in unknown line ${l.lineId}');
      }
    });

    test('every lifeline declares the chronology scheme its year is on',
        () {
      final ids = data.schemes.map((s) => s.id).toSet();
      for (final l in data.lifelines) {
        expect(ids, contains(l.scheme),
            reason: '${l.personId} cites unknown scheme ${l.scheme}');
      }
    });

    // The load-bearing consistency check on the whole Genesis 5 + 11
    // arithmetic: Methuselah dies in the Flood year. If a future edit
    // to a begetting age or a lifespan drifts, this is where it shows.
    test('Methuselah dies in the year of the Flood', () {
      final meth =
          data.lifelines.firstWhere((l) => l.personId == 'methuselah');
      final flood = data.markers.firstWhere((m) => m.id == 'flood');
      expect(meth.deathAm, flood.am);
    });

    test('the contested schemes are carried, not just the chosen one', () {
      final supported = data.schemes.where((s) => s.supported).toList();
      final alternatives = data.schemes.where((s) => !s.supported).toList();
      expect(supported, hasLength(1),
          reason: 'exactly one scheme should be plotted');
      expect(alternatives, isNotEmpty,
          reason: 'the reader must be able to see that the dates are '
              'contested — that is the whole point of the banner');
      for (final s in data.schemes) {
        for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
          expect(s.localizedName(locale), isNotEmpty,
              reason: '${s.id} has no $locale name');
          expect(s.localizedNote(locale), isNotEmpty,
              reason: '${s.id} has no $locale note');
        }
      }
    });

    test('the undrawn lines of descent are declared in all three locales',
        () {
      for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
        expect(data.localizedUndrawn(locale), isNotEmpty,
            reason: 'no $locale note about the lines that are NOT drawn');
      }
    });

    test('AM converts to BC on the anchor, skipping the year zero', () {
      final ussher = data.activeScheme;
      expect(ussher.creationBc, 4004);
      expect(ussher.amToYear(0), -4004);
      expect(ussher.amToYear(1656), -2348); // the Flood, on this anchor
      expect(ussher.amToYear(4003), -1);
      expect(ussher.amToYear(4004), 1); // no year 0
    });
  });

  // ── Localisation ──────────────────────────────────────────────

  group('chronology ui strings', () {
    test('every chronology* key exists in all three locales', () {
      final keys =
          uiStrings.keys.where((k) => k.startsWith('chronology')).toList();
      expect(keys, isNotEmpty, reason: 'no chronology strings found');
      final missing = <String>[];
      for (final k in keys) {
        for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
          final v = uiStrings[k]?[locale];
          if (v == null || v.isEmpty) missing.add('$k/$locale');
        }
      }
      expect(missing, isEmpty);
    });

    test('the tab labels the two views are switched by are localised', () {
      for (final k in const [
        'chronologyChart',
        'chronologyTabEvents',
        'chronologyTabChart',
        'chronologyFeaturedSubtitle',
        'chronologySchemeBanner',
      ]) {
        for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
          expect(uiStrings[k]?[locale], isNotNull, reason: '$k/$locale');
        }
      }
    });

    test('the banner template keeps both placeholders in every locale',
        () {
      for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
        final t = uiStrings['chronologySchemeBanner']![locale]!;
        expect(t, contains('{scheme}'), reason: locale);
        expect(t, contains('{creation}'), reason: locale);
      }
    });
  });

  // ── The view ──────────────────────────────────────────────────

  Widget host(Widget child) => MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MainProvider()),
          ChangeNotifierProvider(create: (_) => AppSettings()),
        ],
        child: MaterialApp(home: Scaffold(body: child)),
      );

  Future<void> pumpChart(
    WidgetTester tester, {
    String locale = 'en',
    Size size = const Size(402, 874),
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      host(ChronologyChart(data: data, locale: locale)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('ChronologyChart', () {
    testWidgets('renders at 402 pt without overflowing', (tester) async {
      await pumpChart(tester);
      expect(find.byType(ChronologyChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('every person on the chart is reachable by name',
        (tester) async {
      await pumpChart(tester);
      for (final l in data.lifelines) {
        expect(find.text(l.localizedName('en')), findsWidgets,
            reason: '${l.personId} is not visible on the chart');
      }
    });

    testWidgets('every person is reachable in Traditional Chinese too',
        (tester) async {
      await pumpChart(tester, locale: 'zh-Hant');
      for (final l in data.lifelines) {
        expect(find.text(l.localizedName('zh-Hant')), findsWidgets,
            reason: '${l.personId} is not visible in zh-Hant');
      }
    });

    testWidgets('every dated marker is reachable as a chip', (tester) async {
      await pumpChart(tester);
      for (final m in data.markers) {
        expect(find.text(m.localizedTitle('en')), findsWidgets,
            reason: 'marker ${m.id} has no chip');
      }
    });

    testWidgets('the chronology scheme is stated on the chart itself',
        (tester) async {
      await pumpChart(tester);
      // Not in a tooltip, not in a footnote — on screen, unprompted.
      expect(find.textContaining('4004 BC'), findsWidgets);
      expect(find.textContaining('Ussher'), findsWidgets);
    });

    testWidgets('the banner opens the sheet naming the rival schemes',
        (tester) async {
      await pumpChart(tester);
      await tester.tap(find.textContaining('4004 BC').first);
      await tester.pumpAndSettle();
      expect(find.text('Whose chronology is this?'), findsOneWidget);
      // The sheet is taller than a phone, so the rival schemes below the
      // fold are reached by scrolling — which is the point of asserting
      // them individually rather than trusting the first screenful.
      final sheet = find.byType(ListView).last;
      for (final s in data.schemes) {
        await tester.dragUntilVisible(
          find.text(s.localizedName('en')),
          sheet,
          const Offset(0, -60),
        );
        expect(find.text(s.localizedName('en')), findsWidgets,
            reason: '${s.id} is not named in the sheet');
      }
      expect(find.textContaining('Septuagint'), findsWidgets);
    });

    testWidgets('tapping a person opens the sheet with its derivation',
        (tester) async {
      await pumpChart(tester);
      await tester.tap(find.text('Methuselah').first);
      await tester.pumpAndSettle();
      expect(find.text('How this year is derived'), findsOneWidget);
      expect(find.textContaining('969'), findsWidgets);
    });

    testWidgets('the plot fits the width at zoom 1 and only the plot '
        'scrolls sideways when zoomed', (tester) async {
      await pumpChart(tester);

      Iterable<ScrollableState> horizontals() => tester
          .stateList<ScrollableState>(find.byType(Scrollable))
          .where((s) => s.widget.axisDirection == AxisDirection.right ||
              s.widget.axisDirection == AxisDirection.left);

      expect(horizontals(), isNotEmpty,
          reason: 'the plot should live in its own horizontal scroll box');
      for (final s in horizontals()) {
        expect(s.position.maxScrollExtent, 0,
            reason: 'at zoom 1 nothing should scroll sideways');
      }

      await tester.tap(find.byIcon(Icons.zoom_in_rounded));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        horizontals().any((s) => s.position.maxScrollExtent > 0),
        isTrue,
        reason: 'zooming should widen the plot, not the page',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the scrubber reports who was alive that year',
        (tester) async {
      await pumpChart(tester);
      // The view opens on the Flood, where the Genesis 5 fathers are all
      // dead but Noah's household is not.
      final flood = data.markers.firstWhere((m) => m.id == 'flood');
      final aliveAtFlood = data.aliveAt(flood.am).length;
      expect(aliveAtFlood, greaterThan(0));
      expect(find.text('$aliveAtFlood alive'), findsOneWidget);

      // Creation: only Adam.
      await tester.tap(find.text('Creation'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('${data.aliveAt(0).length} alive'), findsOneWidget);
    });
  });

  // ── Registration ──────────────────────────────────────────────

  group('the section is actually reachable in the app', () {
    testWidgets('the timeline page opens on the chart view when asked',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      ChronologyService.instance.primeForTest(data);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(402, 874);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => MainProvider()),
            ChangeNotifierProvider(create: (_) => AppSettings()),
          ],
          child: const MaterialApp(
            home: BibleTimelinePage(initialView: TimelineView.chart),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ChronologyChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('both views are switchable from the one page',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      ChronologyService.instance.primeForTest(data);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(402, 874);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => MainProvider()),
            ChangeNotifierProvider(create: (_) => AppSettings()),
          ],
          child: const MaterialApp(home: BibleTimelinePage()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(ChronologyChart), findsNothing);
      // By icon, not by label: the app's default locale is zh-Hans, so
      // the segment reads 生平对照 on a fresh install.
      await tester.tap(find.byIcon(Icons.stacked_bar_chart_rounded));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ChronologyChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('/chronology is a registered route in both places', () {
      expect(kRegisteredRoutePaths, contains('/chronology'));
      final main = File('lib/main.dart').readAsStringSync();
      expect(main, contains("name: '/chronology'"));
      expect(main, contains('ChronologyChartPage()'));
    });

    test('the chart has a Featured card on the dashboard', () {
      final src = File('lib/pages/dashboard_page.dart').readAsStringSync();
      // The user asked for it to be featured, not merely reachable:
      // 2026-08-12, 「而且是featured」.
      final featured = src.substring(
        src.indexOf('case DashboardSection.featured:'),
        src.indexOf('case DashboardSection.todayEvidence:'),
      );
      expect(featured, contains("uiStrings['chronologyChart']"));
      expect(featured, contains("routeName: '/chronology'"));
    });
  });
}
