import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
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

  /// 402 x 874 is the phone case the team measures typography at, and
  /// the default here. `size: _tall` is used where an assertion has to
  /// read the scrubber at the top AND press a chip at the bottom in one
  /// frame — scrolling between them would dispose the thing being
  /// asserted, which tests the ListView rather than the chart.
  const tall = Size(402, 1700);

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

  // ── The zoom model, as the tests below have to talk about it ──
  //
  // Zoom is a DENSITY — pixels per year — not a multiplier, so "zoom 5"
  // is no longer a thing a test can say. What a test can say, and what
  // the reader actually chooses, is how many years are on screen. These
  // helpers read that straight off the live scroll position, so nothing
  // below re-derives the layout or assumes a ladder.

  ScrollableState plotScroll(WidgetTester tester) => tester
      .stateList<ScrollableState>(find.byType(Scrollable))
      .firstWhere((s) => s.widget.axisDirection == AxisDirection.right);

  double plotWidthOf(WidgetTester tester) {
    final p = plotScroll(tester).position;
    return p.viewportDimension + p.maxScrollExtent;
  }

  double yearsInView(WidgetTester tester) {
    final p = plotScroll(tester).position;
    return (data.spanEndAm - data.spanStartAm) *
        p.viewportDimension /
        plotWidthOf(tester);
  }

  /// Zoom all the way out — the whole-span view, which is still the
  /// floor of the ladder even though it is no longer the default.
  Future<void> wholeSpan(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      if (plotScroll(tester).position.maxScrollExtent == 0) return;
      await tester.tap(find.byIcon(Icons.zoom_out_rounded));
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  /// Put [am] in the middle of the plot at the coarsest level holding no
  /// more than [years] years — the reader's own two controls, driven so
  /// the assertion is about a stated viewport rather than about where a
  /// chip happened to land.
  Future<void> viewAt(
    WidgetTester tester,
    int am, {
    required int years,
  }) async {
    await wholeSpan(tester);
    for (var i = 0; i < 12; i++) {
      if (yearsInView(tester) <= years) break;
      await tester.tap(find.byIcon(Icons.zoom_in_rounded));
      await tester.pump(const Duration(milliseconds: 60));
    }
    final pos = plotScroll(tester).position;
    final x = am / (data.spanEndAm - data.spanStartAm) * plotWidthOf(tester);
    pos.jumpTo((x - pos.viewportDimension / 2)
        .clamp(0.0, pos.maxScrollExtent));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
  }

  group('ChronologyChart', () {
    testWidgets('renders at 402 pt without overflowing', (tester) async {
      await pumpChart(tester);
      expect(find.byType(ChronologyChart), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('every person on the chart is reachable by name',
        (tester) async {
      // At the whole-span view, which the chart no longer OPENS on but
      // is always one Zoom out away. Everybody has a row there — that is
      // what "nothing folds at whole span" means, and it is the view
      // this assertion has always been about.
      await pumpChart(tester);
      await wholeSpan(tester);
      for (final l in data.lifelines) {
        expect(find.text(l.localizedName('en')), findsWidgets,
            reason: '${l.personId} is not visible on the chart');
      }
    });

    testWidgets('every person is reachable in Traditional Chinese too',
        (tester) async {
      await pumpChart(tester, locale: 'zh-Hant');
      await wholeSpan(tester);
      for (final l in data.lifelines) {
        expect(find.text(l.localizedName('zh-Hant')), findsWidgets,
            reason: '${l.personId} is not visible in zh-Hant');
      }
    });

    testWidgets('every dated marker is reachable as a chip', (tester) async {
      // The chips sit below a 20-row plot, so on a phone they are a
      // scroll away — reach them the way a reader would rather than by
      // widening the window until the assertion is free.
      await pumpChart(tester);
      for (final m in data.markers) {
        final chip = find.byKey(ValueKey('chronoChip_${m.id}'));
        await tester.scrollUntilVisible(
          chip,
          120,
          scrollable: find.byType(Scrollable).first,
        );
        expect(chip, findsOneWidget, reason: 'marker ${m.id} has no chip');
        expect(find.text(m.localizedTitle('en')), findsWidgets,
            reason: 'marker ${m.id} chip is unlabelled');
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

    testWidgets('the whole-span view fits the width, and only the plot '
        'scrolls sideways when zoomed', (tester) async {
      await pumpChart(tester);

      Iterable<ScrollableState> horizontals() => tester
          .stateList<ScrollableState>(find.byType(Scrollable))
          .where((s) => s.widget.axisDirection == AxisDirection.right ||
              s.widget.axisDirection == AxisDirection.left);

      expect(horizontals(), isNotEmpty,
          reason: 'the plot should live in its own horizontal scroll box');

      await wholeSpan(tester);
      for (final s in horizontals()) {
        expect(s.position.maxScrollExtent, 0,
            reason: 'at whole span nothing should scroll sideways');
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

    testWidgets('it opens on a level a reader can read, not on the whole '
        'span', (tester) async {
      // The reader's second complaint, as an assertion. Opening at
      // fit-to-width put 4,098 years in 250 pt; the default now holds
      // about half a millennium, and the plot opens centred on the
      // cursor rather than at year zero.
      await pumpChart(tester, size: tall);
      expect(yearsInView(tester), lessThan(900),
          reason: 'the default view is still the whole span');
      expect(yearsInView(tester), greaterThan(120),
          reason: 'the default should not open deep inside the axis');
      final flood = data.markers.firstWhere((m) => m.id == 'flood');
      final pos = plotScroll(tester).position;
      final x = flood.am /
          (data.spanEndAm - data.spanStartAm) *
          plotWidthOf(tester);
      expect(x, greaterThanOrEqualTo(pos.pixels - 1));
      expect(x, lessThanOrEqualTo(pos.pixels + pos.viewportDimension + 1),
          reason: 'the default view should contain the opening cursor');
    });

    testWidgets('a zoom level is a DENSITY — the same level is the same '
        'plot on every device', (tester) async {
      // The defect this pass fixes, stated as a test. "8×" meant eight
      // times the fitted width, so it delivered four times more pixels
      // per year on a desktop than on a phone and the same control gave
      // two different pictures. Pixels per year is the same everywhere;
      // a wider screen simply holds more years at once.
      final rungs = <double, List<double>>{};
      final windows = <double, double>{};
      for (final w in const [402.0, 834.0, 1280.0]) {
        await pumpChart(tester, size: Size(w, 1700));
        await wholeSpan(tester);
        final seen = <double>[];
        for (var i = 0; i < 12; i++) {
          await tester.tap(find.byIcon(Icons.zoom_in_rounded));
          await tester.pump(const Duration(milliseconds: 60));
          final p = plotWidthOf(tester);
          if (seen.isNotEmpty && (seen.last - p).abs() < 0.5) break;
          seen.add(p);
          if (p >= 8000) windows[w] ??= yearsInView(tester);
        }
        rungs[w] = seen;
      }
      final span = (data.spanEndAm - data.spanStartAm).toDouble();
      // Every level a device offers is a rung of ONE absolute ladder in
      // pixels per year, shared by all of them. A phone starts lower on
      // it — its fitted width is less dense — but it climbs the same
      // ladder and ends on the same rung.
      for (final e in rungs.entries) {
        for (final p in e.value) {
          final d = p / span;
          expect((d * 16).roundToDouble() / 16, closeTo(d, 0.001),
              reason: '${e.key} pt offers $d pt/yr, off the ladder: $rungs');
        }
        expect(e.value.last, closeTo(rungs[402]!.last, 0.5),
            reason: 'devices end on different rungs: $rungs');
      }
      // And at the SAME rung, the bigger screen holds more years — which
      // is what a bigger screen is for.
      expect(windows[1280]!, greaterThan(windows[402]! * 2),
          reason: 'years in view at 2 pt/yr: $windows');
    });

    testWidgets('the deepest level is the same density everywhere, and '
        'it is far past the old 8×', (tester) async {
      final seen = <double, double>{};
      for (final w in const [402.0, 900.0, 1280.0]) {
        await pumpChart(tester, size: Size(w, 1700));
        for (var i = 0; i < 16; i++) {
          await tester.tap(find.byIcon(Icons.zoom_in_rounded));
          await tester.pump(const Duration(milliseconds: 60));
        }
        seen[w] = plotWidthOf(tester);
      }
      final span = (data.spanEndAm - data.spanStartAm).toDouble();
      for (final e in seen.entries) {
        // 16 pt/yr. This asserted 4 until 2026-09-04, when a reader on a
        // tablet hit the ceiling with the New Testament still crammed
        // into the right-hand fifth of the plot. 4 was the knee of a
        // measurement of label COMPLETENESS, and completeness was
        // already satisfied there — what the cluster still needed was
        // separation. See `_maxDensity` for the full argument.
        expect(e.value / span, closeTo(16, 0.01),
            reason: 'max density at ${e.key} pt: $seen');
        // The old ceiling was 8 × the fitted width. On a phone the new
        // one is many times that; the whole point is that it no longer
        // depends on the width at all.
        expect(e.value, greaterThan(8 * e.key));
      }
    });

    testWidgets('tapping a stacked label opens THAT event, not the one '
        'nearest in x', (tester) async {
      // 2026-09-04. The lane's hit test matched on x alone, within
      // 14 pt, and ignored dy. Where labels stack — fourteen New
      // Testament events fall in ten years, five rows deep — several
      // ticks sit inside the same 14 pt, so tapping a label on a lower
      // row opened whichever tick was nearest horizontally: almost
      // always an earlier one, which is why the reader described it as
      // jumping backwards.
      //
      // The test picks the DEEPEST visible label, because a label on a
      // row below the first is by construction one that could not fit
      // beside its neighbours — exactly the case the old code got
      // wrong.
      await pumpChart(tester, size: const Size(900, 1700));
      for (var i = 0; i < 16; i++) {
        await tester.tap(find.byIcon(Icons.zoom_in_rounded));
        await tester.pump(const Duration(milliseconds: 60));
      }
      // Into the New Testament, where the crowding is.
      await tester.tap(find.byKey(const ValueKey('chronoChip_john_patmos')));
      await tester.pumpAndSettle();

      // The lane builds every label in the span, most of them scrolled
      // out of the plot's viewport — a tap on one of those lands
      // nowhere. Only the ones actually on glass are candidates.
      final onGlass = find
          .byWidgetPredicate((w) =>
              w is Text &&
              w.style?.fontSize != null &&
              (w.style!.fontSize! - 12).abs() < 0.01 &&
              // Size alone stopped identifying the lane once the labels
              // were raised to 12 — the page has other 12 pt text. The
              // lane's are the single-line, non-wrapping ones.
              w.maxLines == 1 &&
              w.softWrap == false)
          .evaluate()
          .map((e) => (tester.getRect(find.byWidget(e.widget)), e.widget as Text))
          .where((r) => r.$1.left >= 0 && r.$1.right <= 900)
          .toList()
        ..sort((a, b) => b.$1.top.compareTo(a.$1.top));
      expect(onGlass, isNotEmpty,
          reason: 'no event labels drawn at max zoom in the New Testament');

      final target = onGlass.first.$2;
      final title = target.data!;
      // Confirm it really is a stacked one: another label sits above it.
      expect(onGlass.first.$1.top, greaterThan(onGlass.last.$1.top),
          reason: 'every label landed on one row — nothing to test');

      await tester.tap(find.byWidget(target));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(title),
        ),
        findsOneWidget,
        reason: 'the sheet must name the label that was tapped',
      );
    });

    testWidgets('tapping the plot reads the year off it, and does not '
        'scroll the view away', (tester) async {
      // 2026-09-04, from a phone at ~19 years in view: "我滑动可以，但是
      // 我按的时候想看具体时间却不行". Scrolling worked; asking the chart
      // what year you were looking at did not.
      //
      // The cursor could only be moved by the slider or the overview
      // strip, and both map all 4,098 years onto the width of the
      // screen — about five years per pixel on a phone. So the reader
      // could scroll to AD 47 and the scrubber would still be reporting
      // 100 BC, with no way to bring it over short of dragging a slider
      // by single pixels.
      await pumpChart(tester, size: tall);
      for (var i = 0; i < 16; i++) {
        await tester.tap(find.byIcon(Icons.zoom_in_rounded));
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.pumpAndSettle();

      final scrolled = plotScroll(tester).position.pixels;
      final before = find
          .textContaining(RegExp(r'^AM \d+'))
          .evaluate()
          .map((e) => (e.widget as Text).data)
          .first;

      // Somewhere in the plot that is neither a bar nor a label: the
      // ruler strip at the very top of the scrolling area.
      final plotBox = tester.getRect(find.byType(SingleChildScrollView).last);
      await tester.tapAt(Offset(plotBox.left + plotBox.width * 0.75,
          plotBox.top + 8));
      await tester.pumpAndSettle();

      final after = find
          .textContaining(RegExp(r'^AM \d+'))
          .evaluate()
          .map((e) => (e.widget as Text).data)
          .first;
      expect(after, isNot(before),
          reason: 'the scrubber must report the year that was tapped');
      expect(plotScroll(tester).position.pixels, closeTo(scrolled, 0.5),
          reason: 'placing the cursor must not move the view — scrolling '
              'out from under the thing just pointed at is how a '
              'crosshair stops being usable');
    });

    testWidgets('EVERY horizontal band of the plot answers a press with '
        'the year under it', (tester) async {
      // 2026-09-04, second report: "我按一下还是不行，但是按住不动就在那个
      // 位置了". Two separate causes, and the band sweep below is what
      // found them — the first version of this feature was tested with
      // one tap at one height, which is exactly the row that worked.
      //
      //   * `_foldLane`, the hatched "{n} not in view" band, was an
      //     opaque detector over `_goTo`. It is one of the largest
      //     things on a phone screen at close zoom and reads as chart
      //     ground, so pressing it scrolled the chart somewhere else.
      //   * The cursor handler was a GestureDetector's `onTapDown`,
      //     which fires on winning the arena OR at 100 ms. Hold and it
      //     fires; tap and an inner recogniser can take the arena
      //     first. `tapAt` cannot reproduce that — both paths pass —
      //     so the sweep asserts the OUTCOME at every height instead.
      await pumpChart(tester, size: tall);
      for (var i = 0; i < 16; i++) {
        await tester.tap(find.byIcon(Icons.zoom_in_rounded));
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.pumpAndSettle();

      final plot = plotScroll(tester);
      final box = tester.getRect(find.byType(SingleChildScrollView).last);
      String cursorText() => tester
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data ?? '')
          .firstWhere((s) => s.startsWith('AM '));

      final span = (data.spanEndAm - data.spanStartAm).toDouble();
      for (var dy = 6.0; dy < box.height - 4; dy += 20) {
        final scrollBefore = plot.position.pixels;
        // The year that is genuinely under the press point, derived
        // from the live scroll offset rather than from a reset — some
        // bands legitimately open a sheet, and a reset tap would land
        // on that sheet's barrier instead of the chart.
        final px = scrollBefore + box.width * 0.7;
        final want = (data.spanStartAm + px / plotWidthOf(tester) * span)
            .round();

        await tester.tapAt(Offset(box.left + box.width * 0.7, box.top + dy));
        await tester.pumpAndSettle();

        expect(cursorText(), startsWith('AM $want '),
            reason: 'the band at dy=$dy did not report the year under the '
                'press — it either swallowed it or answered with the '
                'wrong year');
        expect(plot.position.pixels, closeTo(scrollBefore, 0.5),
            reason: 'the band at dy=$dy scrolled the chart instead of '
                'answering — that is the fold band bug');

        // A press may legitimately have opened an event or person
        // sheet; close it so the next press reaches the chart.
        if (find.byType(BottomSheet).evaluate().isNotEmpty) {
          Navigator.of(tester.element(find.byType(BottomSheet))).pop();
          await tester.pumpAndSettle();
        }
      }
    });

    testWidgets('the label whose sheet is open is highlighted, and the '
        'highlight dies with the sheet', (tester) async {
      // Asked for 2026-09-04: show which label the press landed on.
      // The highlight is a TINT, never a bold — weight on this lane
      // already means provenance (w800 computed / w500 placed), and
      // bolding a selected placed event would make it read as computed
      // for as long as its sheet was open. That is the one claim the
      // drawing must never make by accident.
      await pumpChart(tester, size: const Size(900, 1700));
      for (var i = 0; i < 16; i++) {
        await tester.tap(find.byIcon(Icons.zoom_in_rounded));
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.tap(find.byKey(const ValueKey('chronoChip_john_patmos')));
      await tester.pumpAndSettle();

      Text? laneLabel(String title) => tester
          .widgetList<Text>(find.byType(Text))
          .where((w) =>
              w.data == title &&
              (w.style?.fontSize ?? 0) == 12 &&
              w.maxLines == 1)
          .firstOrNull;

      final onGlass = find
          .byWidgetPredicate((w) =>
              w is Text && (w.style?.fontSize ?? 0) == 12 && w.maxLines == 1)
          .evaluate()
          .map((e) => (tester.getRect(find.byWidget(e.widget)), e.widget as Text))
          .where((r) => r.$1.left >= 0 && r.$1.right <= 900)
          .toList();
      expect(onGlass, isNotEmpty);

      final target = onGlass.first.$2;
      final title = target.data!;
      final plainWeight = target.style!.fontWeight;
      final plainColour = target.style!.color;

      await tester.tap(find.byWidget(target), warnIfMissed: false);
      await tester.pumpAndSettle();

      final open = laneLabel(title)!;
      expect(open.style!.color, isNot(plainColour),
          reason: 'the selected label must be tinted while its sheet is up');
      expect(open.style!.fontWeight, plainWeight,
          reason: 'weight is provenance — selection may not borrow it, or a '
              'placed event reads as computed while it is selected');

      // Close the sheet; the highlight must go with it.
      Navigator.of(tester.element(find.byType(BottomSheet))).pop();
      await tester.pumpAndSettle();
      expect(laneLabel(title)!.style!.color, plainColour,
          reason: 'a highlight that outlives its sheet is a stale selection');
    });

    testWidgets('the plot carries a visible horizontal scrollbar, on a '
        'mouse platform and before anyone has scrolled', (tester) async {
      // 2026-09-04: "对于在browser电脑使用的人来说，没有往左右scroll bar
      // 来说他们不知道怎么scroll".
      //
      // This is not a styling nicety, it is a missing affordance, and
      // the reason it was missing is a Flutter default that is easy to
      // assume away: MaterialScrollBehavior.buildScrollbar returns the
      // child UNTOUCHED for Axis.horizontal and only wraps vertical
      // scrollables. So a chart whose whole point is a plot far wider
      // than the screen shipped to desktop browsers with nothing saying
      // it could be scrolled sideways. On a phone a reader swipes and
      // finds out; with a mouse there is no equivalent guess.
      //
      // The assertion is on thumbVisibility rather than on pixels
      // because a fade-on-scroll thumb would pass a "does a Scrollbar
      // exist" test while still being invisible at the moment the
      // reader needs it — which is before their first scroll.
      // The bar is deliberately NOT conditioned on platform. Flutter's
      // own rule — desktop gets a bar, touch does not — is about a
      // scrollbar as feedback. As an affordance it is worth the 12 pt
      // everywhere, and on touch it doubles as a position readout on a
      // plot that is sixty screens wide at full zoom.
      await pumpChart(tester, size: const Size(1280, 1700));

      final onPlot = tester
          .widgetList<Scrollbar>(find.byType(Scrollbar))
          .where((b) => b.controller == plotScroll(tester).widget.controller);
      expect(onPlot, isNotEmpty,
          reason: 'no scrollbar on the plot — Flutter adds none of its own '
              'for a horizontal axis');
      expect(onPlot.first.thumbVisibility, isTrue,
          reason: 'the thumb must be up before the first scroll, or it is '
              'feedback rather than an affordance');
    });

    testWidgets('a MOUSE can drag the plot sideways, and dragging does not '
        'move the cursor', (tester) async {
      // "我以为鼠标在这里可以drag走的呢…鼠标变成手的姿势往左右拽不是吗".
      // Flutter's default ScrollBehavior.dragDevices omits
      // PointerDeviceKind.mouse, so with a mouse the only built-in way
      // to move a horizontal scroll view is shift-wheel. Nobody
      // guesses that, which is the same discoverability hole the
      // scrollbar was.
      //
      // The second half asserts that panning leaves the cursor alone.
      // Note what it does NOT show: local and global coordinates behave
      // the same here, because Flutter routes a pointer's later events
      // through the transform captured at down, so `localPosition`
      // travels with the finger too. Swapping them keeps this green.
      await pumpChart(tester, size: const Size(1280, 1700));
      for (var i = 0; i < 16; i++) {
        await tester.tap(find.byIcon(Icons.zoom_in_rounded));
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.tap(find.byKey(const ValueKey('chronoChip_flood')));
      await tester.pumpAndSettle();

      String cursorText() => tester
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data ?? '')
          .firstWhere((s) => s.startsWith('AM '));

      final before = cursorText();
      final scrollBefore = plotScroll(tester).position.pixels;
      final box = tester.getRect(find.byType(SingleChildScrollView).last);
      // NOT the centre. A "Jump to" chip centres the cursor, so a drag
      // starting at the middle begins on the cursor's own year and
      // could not tell a stray cursor placement from a no-op — the
      // first version of this test made exactly that mistake and passed
      // with the bug reinstated.
      final from =
          Offset(box.left + box.width * 0.25, box.top + box.height * 0.5);

      final mouse = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
      for (var i = 0; i < 10; i++) {
        await mouse.moveBy(const Offset(-30, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await mouse.up();
      await tester.pumpAndSettle();

      expect(plotScroll(tester).position.pixels,
          greaterThan(scrollBefore + 100),
          reason: 'a mouse drag must pan the plot — Flutter does not allow '
              'this by default');
      expect(cursorText(), before,
          reason: 'panning must not carry the cursor along — the press only '
              'commits when the pointer stayed within touch slop');
    });

    testWidgets('a scroll drag does not drag the cursor with it',
        (tester) async {
      // The reason the press commits on pointer UP within touch slop
      // rather than on pointer down: the plot is horizontally
      // scrollable, and a crosshair that moved every time you scrolled
      // would be worse than one that never moved.
      await pumpChart(tester, size: tall);
      for (var i = 0; i < 16; i++) {
        await tester.tap(find.byIcon(Icons.zoom_in_rounded));
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.tap(find.byKey(const ValueKey('chronoChip_flood')));
      await tester.pumpAndSettle();

      final before = tester
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data ?? '')
          .firstWhere((s) => s.startsWith('AM '));
      final box = tester.getRect(find.byType(SingleChildScrollView).last);
      await tester.dragFrom(
          Offset(box.left + box.width * 0.5, box.top + box.height * 0.5),
          const Offset(-120, 0));
      await tester.pumpAndSettle();

      expect(
          tester
              .widgetList<Text>(find.byType(Text))
              .map((w) => w.data ?? '')
              .firstWhere((s) => s.startsWith('AM ')),
          before,
          reason: 'scrolling must leave the cursor where it was');
    });

    testWidgets('the scrubber reports who was alive that year',
        (tester) async {
      await pumpChart(tester, size: tall);
      // The view opens on the Flood, where the Genesis 5 fathers are all
      // dead but Noah's household is not.
      final flood = data.markers.firstWhere((m) => m.id == 'flood');
      final aliveAtFlood = data.aliveAt(flood.am).length;
      expect(aliveAtFlood, greaterThan(0));
      expect(find.text('$aliveAtFlood alive'), findsOneWidget);

      // Creation: only Adam. By key, not by text — the event lane
      // prints some of the same titles as the chips.
      await tester.tap(find.byKey(const ValueKey('chronoChip_creation')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('${data.aliveAt(0).length} alive'), findsOneWidget);
    });
  });

  // ── The span, and the two layers on it ────────────────────────
  //
  // 2026-09-04. The chart stopped at Abraham while the event list on
  // the SAME page ran to Revelation, so scrolling right never arrived
  // anywhere: 「chronology chart为什么不能一直往右边一直到今天」, asked
  // three times, then 「直接做到跟event一致就行了」. What follows pins
  // the fix AND the thing the fix put at risk — that a reader can still
  // tell a year counted from stated ages from a year somebody placed.

  group('the span reaches Revelation', () {
    late Map<String, dynamic> timeline;

    setUpAll(() {
      timeline = json.decode(
        File('assets/bible_timeline.json').readAsStringSync(),
      ) as Map<String, dynamic>;
    });

    List<Map<String, dynamic>> timelineEvents() =>
        (timeline['events'] as List).cast<Map<String, dynamic>>();

    test('the axis ends where the event list ends — AD 95, Patmos', () {
      final events = timelineEvents();
      final lastYear =
          events.map((e) => (e['year'] as num).toInt()).reduce((a, b) => a > b ? a : b);
      expect(lastYear, 95);
      final ussher = data.activeScheme;
      expect(ussher.amToYear(data.spanEndAm), lastYear,
          reason: 'the chart must span as far as the event list does');
      expect(data.spanEndAm, 4098);
    });

    test('the axis starts no later than the earliest event', () {
      final events = timelineEvents();
      final firstYear = events
          .map((e) => (e['year'] as num).toInt())
          .reduce((a, b) => a < b ? a : b);
      final ussher = data.activeScheme;
      expect(ussher.amToYear(data.spanStartAm), lessThanOrEqualTo(firstYear));
    });

    test('AD conversion is right at both ends, and there is no year 0',
        () {
      final ussher = data.activeScheme;
      // Checked at the joint rather than trusted: BC and AD are off by
      // one from each other because there is no year zero.
      expect(ussher.amToYear(4003), -1);
      expect(ussher.amToYear(4004), 1);
      expect(ussher.amToYear(4098), 95); // Revelation
      // And nothing anywhere claims a year 0.
      expect(
        List.generate(4200, (am) => ussher.amToYear(am)).contains(0),
        isFalse,
      );
      for (final e in timelineEvents()) {
        expect(e['year'], isNot(0), reason: '${e['id']} is dated year 0');
      }
    });

    test('every event on the chart sits where its own year puts it', () {
      final ussher = data.activeScheme;
      for (final e in data.events) {
        expect(e.year, isNotNull, reason: '${e.id} has no stated year');
        expect(ussher.amToYear(e.am), e.year,
            reason: '${e.id} was moved on the way onto the AM axis');
      }
    });

    test('every event is inside the span', () {
      for (final e in data.events) {
        expect(e.am, greaterThanOrEqualTo(data.spanStartAm));
        expect(e.am, lessThanOrEqualTo(data.spanEndAm), reason: e.id);
      }
    });
  });

  group('the two layers stay distinguishable', () {
    test('lifelines are still bounded by Genesis 5 and 11', () {
      // The span doubled; the BARS did not. Nothing past Abraham has a
      // stated begetting age, so nothing past Abraham gets a lifeline.
      expect(data.lifelines, hasLength(20));
      expect(data.lifelines.first.personId, 'adam');
      final byId = {for (final l in data.lifelines) l.personId};
      expect(byId, contains('abraham'));
      for (final l in data.lifelines) {
        for (final r in l.refs) {
          expect(
            r.startsWith('Genesis') || r.startsWith('Acts') ||
                r.startsWith('Hebrews'),
            isTrue,
            reason: '${l.personId} cites $r — outside Genesis 5/11',
          );
        }
        expect(l.deathAm, isNotNull);
        expect(l.deathAm, lessThanOrEqualTo(data.computedEndAm));
      }
      expect(
        data.lifelines.map((l) => l.deathAm!).reduce((a, b) => a > b ? a : b),
        data.computedEndAm,
        reason: 'the computed boundary must be read off the bars',
      );
      // And the boundary is well inside the span — otherwise there is
      // no placed stretch to distinguish.
      expect(data.computedEndAm, lessThan(data.spanEndAm));
    });

    test('every tick declares which layer it is on', () {
      expect(data.markers, isNotEmpty);
      expect(data.events, isNotEmpty);
      for (final m in data.markers) {
        expect(m.isComputed, isTrue, reason: '${m.id} is not computed');
        expect(m.am, lessThanOrEqualTo(data.computedEndAm));
      }
      for (final e in data.events) {
        expect(e.isComputed, isFalse, reason: '${e.id} claims to be counted');
      }
    });

    test('the computed/placed distinction is explained in all three '
        'locales', () {
      for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
        expect(data.localizedComputedNote(locale), isNotEmpty, reason: locale);
        expect(data.contested!.localizedNote(locale), isNotEmpty,
            reason: locale);
      }
    });

    test('the contested band is the ordering clash, not a guess', () {
      final c = data.contested!;
      // Everything in it is a placed event drawn EARLIER than the first
      // computed event of its own era — Ishmael before Abram is born.
      expect(c.eventCount, greaterThan(0));
      expect(c.startAm, lessThan(c.endAm));
      expect(c.endAm, data.computedEndAm);
      final firstComputedInEra = <String, int>{};
      for (final m in data.markers) {
        final cur = firstComputedInEra[m.era];
        if (cur == null || m.am < cur) firstComputedInEra[m.era] = m.am;
      }
      final misordered = data.events
          .where((e) =>
              firstComputedInEra.containsKey(e.era) &&
              e.am < firstComputedInEra[e.era]!)
          .toList();
      expect(misordered, hasLength(c.eventCount));
      expect(misordered.map((e) => e.am).reduce((a, b) => a < b ? a : b),
          c.startAm);
      // The ~170 years family_tree.json and this count disagree by, not
      // quietly averaged away.
      final abramCall = data.markers.firstWhere((m) => m.id == 'abram_call');
      expect(abramCall.placedYear, -2091);
      expect(abramCall.placedDeltaYears, -170);
    });
  });

  group('events are deduped against the computed markers', () {
    test('nothing is on the chart twice', () {
      final ids = data.allTicks.map((t) => t.id).toList();
      expect(ids.toSet(), hasLength(ids.length), reason: 'duplicate tick id');
      // The five events both files carry are drawn once each, as the
      // computed marker, with the timeline's own figure attached.
      for (final pair in const [
        ['creation', 'creation', 4],
        ['enoch_taken', 'enoch_walks', 17],
        ['flood', 'flood', 0],
        ['abram_call', 'abram_called', -170],
        ['isaac_born', 'isaac_born', -170],
      ]) {
        final markerId = pair[0] as String;
        final eventId = pair[1] as String;
        final delta = pair[2] as int;
        final m = data.markers.firstWhere((x) => x.id == markerId);
        expect(m.placedDeltaYears, delta, reason: markerId);
        expect(data.events.any((e) => e.id == eventId), isFalse,
            reason: '$eventId is drawn twice');
      }
    });

    test('every other timeline event survived the projection', () {
      final timeline = json.decode(
        File('assets/bible_timeline.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final all = (timeline['events'] as List)
          .cast<Map<String, dynamic>>()
          .map((e) => e['id'] as String)
          .toSet();
      const deduped = {
        'creation', 'enoch_walks', 'flood', 'abram_called', 'isaac_born',
      };
      expect(data.events.map((e) => e.id).toSet(), all.difference(deduped));
      expect((timeline['_meta'] as Map)['count'], all.length,
          reason: '_meta.count must match what the file holds');
    });
  });

  group('era bands', () {
    test('tile the whole axis without gaps or overlaps', () {
      expect(data.eras, hasLength(8));
      expect(data.eras.first.startAm, data.spanStartAm);
      expect(data.eras.last.endAm, data.spanEndAm);
      for (var i = 1; i < data.eras.length; i++) {
        expect(data.eras[i].startAm, data.eras[i - 1].endAm,
            reason: 'gap or overlap before ${data.eras[i].id}');
      }
    });

    test('use the same palette as the Events list on the same page', () {
      // One page, one dataset family — the two views must not band the
      // same centuries different colours.
      final page =
          File('lib/pages/bible_timeline_page.dart').readAsStringSync();
      for (final e in data.eras) {
        expect(page, contains(e.colorHex.replaceFirst('#', '0xFF')),
            reason: '${e.id} colour is not the page era palette');
        for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
          expect(e.localizedName(locale), isNotEmpty, reason: '${e.id}/$locale');
        }
      }
    });

    test('every tick belongs to a declared era', () {
      for (final t in data.allTicks) {
        expect(data.eraById(t.era), isNotNull,
            reason: '${t.id} is in unknown era ${t.era}');
      }
    });
  });

  group('the generator is the only author of the asset', () {
    test('re-running it changes nothing', () async {
      final before = File('assets/bible_chronology.json').readAsStringSync();
      final r = await Process.run(
          'python3', ['tools/build_bible_chronology.py']);
      expect(r.exitCode, 0, reason: '${r.stderr}');
      final after = File('assets/bible_chronology.json').readAsStringSync();
      expect(after, before, reason: 'the generator is not idempotent');
    }, timeout: const Timeout(Duration(minutes: 1)));
  });

  group('the chart shows the reader it reaches Revelation', () {
    testWidgets('the right-hand end of the ruler prints AD 95',
        (tester) async {
      await pumpChart(tester);
      expect(find.text('AM 4098'), findsWidgets);
      expect(find.text('AD 95'), findsWidgets);
    });

    testWidgets('Revelation has a chip, and it scrolls the plot to it',
        (tester) async {
      await pumpChart(tester, size: tall);
      final chip = find.byKey(const ValueKey('chronoChip_john_patmos'));
      expect(chip, findsOneWidget);
      await tester.tap(chip);
      await tester.pumpAndSettle();

      final horizontal = tester
          .stateList<ScrollableState>(find.byType(Scrollable))
          .firstWhere(
              (s) => s.widget.axisDirection == AxisDirection.right);
      expect(horizontal.position.pixels,
          horizontal.position.maxScrollExtent,
          reason: 'jumping to Revelation should land at the right edge');
      expect(tester.takeException(), isNull);
    });

    testWidgets('the whole span is legible at every zoom level, in every '
        'locale', (tester) async {
      for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
        await pumpChart(tester, locale: locale);
        await wholeSpan(tester);
        for (var z = 0; z < 10; z++) {
          await tester.tap(find.byIcon(Icons.zoom_in_rounded));
          await tester.pump(const Duration(milliseconds: 60));
          expect(tester.takeException(), isNull,
              reason: 'level $z in $locale');
        }
        // And the ruler never prints two labels on top of each other:
        // the step ladder widens with the plot, so consecutive AM
        // labels stay at least a label-width apart.
        expect(find.byType(ChronologyChart), findsOneWidget);
      }
    });

    testWidgets('no two ruler labels overlap, at any level, width, or '
        'text scale', (tester) async {
      // Overlapping year labels are the commonest way this chart type
      // fails, and this one did: at 402 pt with a 1,000-year step,
      // "AM 3000" sat under the pinned "AM 4098". The step ladder and
      // the right-edge reserve are both measured off the text engine
      // now, so this is the assertion that keeps them honest.
      //
      // Widened this pass in both directions the reader asked about:
      // every device class from a 320 pt phone to a 1280 pt desktop, and
      // — new — a reader at 130% system text, whose labels are wider
      // than the ones in the screenshots and used to be measured as if
      // they were not.
      const sizes = [
        Size(320, 900), // small phone portrait
        Size(402, 900), // the typography reference width
        Size(844, 700), // phone landscape
        Size(834, 1194), // tablet portrait
        Size(1194, 834), // tablet landscape
        Size(1280, 900), // desktop
      ];
      for (final scale in const [1.0, 1.3]) {
        for (final size in sizes) {
          tester.view.devicePixelRatio = 1.0;
          tester.view.physicalSize = size;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            host(
              MediaQuery(
                data: MediaQueryData(
                    textScaler: TextScaler.linear(scale)),
                child: ChronologyChart(data: data, locale: 'en'),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 100));
          await wholeSpan(tester);
          for (var z = 0; z <= 8; z++) {
            final rects = <Rect>[];
            for (final e in find.byType(Text).evaluate()) {
              final t = e.widget as Text;
              if (!(t.data ?? '').startsWith('AM ')) continue;
              final ro = e.renderObject;
              if (ro is! RenderBox || !ro.attached) continue;
              final origin = ro.localToGlobal(Offset.zero);
              rects.add(origin & ro.size);
            }
            for (var i = 0; i < rects.length; i++) {
              for (var j = i + 1; j < rects.length; j++) {
                // Same row only: the ruler stacks AM over BC/AD, and the
                // scrubber's own readout is elsewhere on the page.
                if ((rects[i].top - rects[j].top).abs() > 2) continue;
                expect(rects[i].overlaps(rects[j].deflate(0.5)), isFalse,
                    reason: 'ruler labels collide at $size level $z '
                        'text scale $scale: ${rects[i]} vs ${rects[j]}');
              }
            }
            await tester.tap(find.byIcon(Icons.zoom_in_rounded));
            await tester.pump(const Duration(milliseconds: 60));
          }
        }
      }
    });

    test('the packer never lets a neighbour crowd a label', () {
      // The pure half of the truncation fix. Pass one used to reserve
      // `width.clamp(34, 190)`, so any title wider than 190 pt was
      // under-reserved and then trimmed by the label after it — a cap in
      // the packer wearing a collision's clothes. The invariant now: a
      // chosen label is complete unless the END OF THE AXIS cuts it.
      final rnd = <double>[
        for (var i = 0; i < 60; i++) i * 37.5 + (i % 7) * 9,
      ];
      final wants = <double>[
        for (var i = 0; i < 60; i++) 30 + (i % 11) * 22.0,
      ];
      for (final rows in const [1, 2, 5]) {
        for (final plotWidth in const [400.0, 1200.0, 4000.0]) {
          final plan = chronologyLabelPlan(
            lefts: rnd,
            wants: wants,
            rows: rows,
            plotWidth: plotWidth,
          );
          for (final s in plan) {
            expect(s.complete || rnd[s.index] + wants[s.index] > plotWidth,
                isTrue,
                reason: 'label ${s.index} was crowded, not clipped by the '
                    'axis (rows $rows, plot $plotWidth)');
            expect(s.row, lessThan(rows));
          }
          // And two labels in the same row never sit on top of each
          // other, which is the other half of the same promise.
          for (var i = 0; i < plan.length; i++) {
            for (var j = i + 1; j < plan.length; j++) {
              if (plan[i].row != plan[j].row) continue;
              final a = rnd[plan[i].index];
              final b = rnd[plan[j].index];
              expect((b - a).abs(), greaterThanOrEqualTo(plan[i].width - 0.5));
            }
          }
        }
      }
    });

    testWidgets('an event label on screen is not ellipsised — the '
        'measurement uses the font the chart actually draws',
        (tester) async {
      // The root cause of 「很多都是…」. A bare `TextStyle(fontSize: 8.5)`
      // in a TextPainter inherits neither the reader's chosen font
      // family nor their text scale, while the `Text` beside it inherits
      // both — so the packer sized every label against one font and the
      // engine drew a wider one, and the lane ellipsised labels it had
      // just decided would fit. Measured off the reader's own capture,
      // "Alexander the Great Conquers Persia" had 159 pt of room, was
      // measured at 142, and drew at about 155.
      for (final scale in const [1.0, 1.3]) {
        for (final size in const [Size(402, 1700), Size(1194, 1000)]) {
          tester.view.devicePixelRatio = 1.0;
          tester.view.physicalSize = size;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            host(
              MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: ChronologyChart(data: data, locale: 'en'),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 100));
          // Mid-axis, so the end of the plot — the one thing allowed to
          // cut a label — is nowhere near the window.
          await viewAt(tester, 2000, years: 400);

          final titles = {
            for (final t in data.allTicks) t.localizedTitle('en'),
          };
          var seen = 0;
          for (final e in find.byType(Text).evaluate()) {
            final t = e.widget as Text;
            if (!titles.contains(t.data)) continue;
            final ro = e.renderObject;
            if (ro is! RenderParagraph || !ro.attached) continue;
            final x = ro.localToGlobal(Offset.zero).dx;
            // On screen only: the lane lays out labels for the whole
            // 16,000 pt plot, most of it scrolled out of the window.
            if (x < 0 || x + ro.size.width > size.width) continue;
            seen++;
            expect(ro.didExceedMaxLines, isFalse,
                reason: '"${t.data}" is ellipsised at $size, text scale '
                    '$scale, with nothing beside it');
          }
          expect(seen, greaterThan(0),
              reason: 'no event labels on screen at $size — the assertion '
                  'proved nothing');
        }
      }
    });

    testWidgets('a name in the left column is never cut short',
        (tester) async {
      // 「Nahor (the el…」. The column was a flat 88 pt, which is short
      // of "Nahor (the elder)" in the app's own font and shorter still
      // of 拿鹤(亚伯拉罕祖父) — so the one person who needs a
      // disambiguating parenthetical was the one whose name was cut. It
      // is measured now, and wraps rather than ellipsising past the cap.
      for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
        for (final size in const [
          Size(402, 1700),
          Size(834, 1700),
          Size(1280, 1700),
        ]) {
          await pumpChart(tester, locale: locale, size: size);
          await wholeSpan(tester);
          final names = {
            for (final l in data.lifelines) l.localizedName(locale),
          };
          var checked = 0;
          for (final e in find.byType(Text).evaluate()) {
            final t = e.widget as Text;
            if (!names.contains(t.data)) continue;
            final ro = e.renderObject;
            if (ro is! RenderParagraph || !ro.attached) continue;
            checked++;
            expect(ro.didExceedMaxLines, isFalse,
                reason: '"${t.data}" is ellipsised at $size in $locale');
          }
          expect(checked, greaterThan(0));
        }
      }
    });

    testWidgets('renders on the dark theme without throwing',
        (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(402, 874);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => MainProvider()),
            ChangeNotifierProvider(create: (_) => AppSettings()),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: Scaffold(
              body: ChronologyChart(data: data, locale: 'zh-Hant'),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });

    testWidgets('survives a 320 pt window — the narrow case',
        (tester) async {
      await pumpChart(tester,
          locale: 'zh-Hans', size: const Size(320, 700));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byIcon(Icons.zoom_in_rounded));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a placed event opens a sheet that says it is placed',
        (tester) async {
      await pumpChart(tester, size: tall);
      final chip = find.byKey(const ValueKey('chronoChip_crucifixion'));
      await tester.tap(chip);
      await tester.pumpAndSettle();
      // The chip moves the cursor rather than opening the sheet, so
      // read the cursor instead: it is the placed year.
      final crucifixion =
          data.events.firstWhere((e) => e.id == 'crucifixion');
      expect(
        find.text(formatChronologyYear(
            crucifixion.am, data.activeScheme, 'en')),
        findsWidgets,
      );
      expect(find.textContaining('AD 33'), findsWidgets);
    });

    testWidgets('past the computed stretch the chart says it has no bars, '
        'rather than reporting nobody alive', (tester) async {
      await pumpChart(tester, size: tall);
      final chip = find.byKey(const ValueKey('chronoChip_john_patmos'));
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(find.text('no lifelines here'), findsOneWidget);
      expect(find.text('0 alive'), findsNothing);
    });

    testWidgets('the boundary and the legend both state the distinction',
        (tester) async {
      await pumpChart(tester, size: tall);
      // In the drawing (the rotated rule label is painted, so assert
      // the legend copy) AND in words.
      final key = find.text('Computed from ages Scripture states');
      expect(key, findsOneWidget);
      expect(find.text('Placed event — dated by scholarship, not counted'),
          findsOneWidget);
    });
  });

  // ── Lifeline rows earn their height ───────────────────────────
  //
  // 2026-09-04, the pass after the span reached Revelation. Scrolled to
  // the right-hand end, all twenty lifeline rows were still drawn — the
  // names in the left column, no bars, Adam through Abraham listed
  // against 700 BC — and they took well over half the chart's height.
  // On a phone that pushed everything worth seeing off the screen.
  //
  // What follows pins the fix at BOTH ends and, most importantly, ACROSS
  // the boundary: the fold is a function of the viewport, not a switch
  // at AM 2187, because a viewport straddling the boundary has real bars
  // in it and must show them.

  group('lifeline rows fold to the space they earn', () {
    // The pure half first. `chronologyRowsInView` is the whole decision,
    // and it is a function of the viewport and the previous plan only —
    // no widget, no scroll controller, no zoom.

    List<bool> plan(double a, double b, {List<bool>? previous}) =>
        chronologyRowsInView(
          lifelines: data.lifelines,
          spanStartAm: data.spanStartAm,
          spanEndAm: data.spanEndAm,
          viewStartFrac: a,
          viewEndFrac: b,
          previous: previous,
        );

    String named(List<bool> p) => [
          for (var i = 0; i < p.length; i++)
            if (p[i]) data.lifelines[i].personId,
        ].join(',');

    test('zoom 1 — the whole span in view — folds nothing', () {
      final p = plan(0, 1);
      expect(p.length, data.lifelines.length);
      expect(p.every((v) => v), isTrue,
          reason: 'the default view must be exactly what it was');
    });

    test('the right-hand end folds every row, because no bar is there',
        () {
      // AM 2187 is 53% of the way along a 4,098-year axis, so the last
      // tenth of it — Rome, the Gospels, Patmos — contains no bar at
      // all. That is the defect: twenty names and no bars.
      final p = plan(0.9, 1.0);
      expect(p.any((v) => v), isFalse, reason: 'in view: ${named(p)}');
    });

    test('the left-hand end keeps the rows that are actually there', () {
      final p = plan(0.0, 0.1);
      // 10% of 4,098 is AM 0-410 (plus the entry margin). Adam, Seth,
      // Enosh, Kenan and Mahalalel are born inside it; Abraham is not
      // born for another 1,600 years.
      final byId = {
        for (var i = 0; i < data.lifelines.length; i++)
          data.lifelines[i].personId: p[i],
      };
      expect(byId['adam'], isTrue);
      expect(byId['seth'], isTrue);
      expect(byId['mahalalel'], isTrue);
      expect(byId['abraham'], isFalse);
      expect(byId['terah'], isFalse);
    });

    test('a viewport straddling AM 2187 shows the bars that are in it',
        () {
      // THE case this must not get wrong. A binary "past the boundary"
      // test would fold every row here; overlap does not.
      const span = 4098;
      const half = 400 / span; // an 800-year window, ~zoom 5
      final c = data.computedEndAm / span;
      final p = plan(c - half, c + half);
      final byId = {
        for (var i = 0; i < data.lifelines.length; i++)
          data.lifelines[i].personId: p[i],
      };
      // Eber dies ON the boundary — AM 2187 is read off his bar — and
      // Abraham, Terah and Shem all run into the window.
      expect(byId['eber'], isTrue);
      expect(byId['abraham'], isTrue);
      expect(byId['terah'], isTrue);
      expect(byId['shem'], isTrue);
      // Adam has been dead 900 years by then. Nothing to draw.
      expect(byId['adam'], isFalse);
      expect(byId['enoch'], isFalse);
      // And it is a mixture, which is the point: neither all nor none.
      expect(p.where((v) => v).length,
          allOf(greaterThan(3), lessThan(data.lifelines.length)));
    });

    test('the fold is hysteretic, so a bar on the edge cannot flicker',
        () {
      // A row leaves at a wider margin than it enters at. Without that,
      // a bar resting on the viewport edge folds and unfolds with every
      // pixel of scroll, and each flip moves 26 pt of layout.
      final wide = plan(0.30, 0.55); // Abraham (2008-2183) is in view
      final abraham =
          data.lifelines.indexWhere((l) => l.personId == 'abraham');
      expect(wide[abraham], isTrue);

      // Nudge the window past him: AM 0-1721, which reaches AM 1824
      // with the enter margin (short of his birth at 2008) and AM 2151
      // with the wider exit margin (past it).
      const a = 0.0, b = 0.42;
      expect(plan(a, b)[abraham], isFalse,
          reason: 'the enter test alone should drop him here');
      // Warm — he was in view a moment ago — he is held.
      expect(plan(a, b, previous: wide)[abraham], isTrue,
          reason: 'hysteresis should hold a row that just left');
      // But held is not forever: scroll well away and he goes.
      expect(plan(0.0, 0.30, previous: wide)[abraham], isFalse);
    });

    test('a row that is out stays out until it really arrives', () {
      final cold = plan(0.9, 1.0);
      expect(plan(0.9, 1.0, previous: cold).any((v) => v), isFalse,
          reason: 'hysteresis must not resurrect a folded row');
    });
  });

  group('the folded rows say why, and take you back', () {
    double plotHeight(WidgetTester tester) =>
        (plotScroll(tester).context.findRenderObject()! as RenderBox)
            .size
            .height;

    testWidgets('at whole span nothing folds — that view is intact',
        (tester) async {
      await pumpChart(tester, size: tall);
      await wholeSpan(tester);
      expect(find.textContaining('not in view'), findsNothing);
      for (final l in data.lifelines) {
        expect(find.text(l.localizedName('en')), findsWidgets,
            reason: '${l.personId} vanished at whole span');
      }
    });

    testWidgets('at the right-hand end the rows fold, and say why',
        (tester) async {
      await pumpChart(tester, size: tall);
      await wholeSpan(tester);
      final tall1x = plotHeight(tester);

      await viewAt(tester, data.spanEndAm, years: 800);

      // The whole column folds into one band, labelled with the count
      // and the reason. Not blank, not gone: twenty rows, named.
      expect(find.text('${data.lifelines.length} not in view'),
          findsOneWidget);
      // And the chart is now a fraction of its height. This is the
      // defect: it used to be all 597 pt of it, most of it empty.
      expect(plotHeight(tester), lessThan(tall1x * 0.45),
          reason: 'folded: ${plotHeight(tester)} vs $tall1x at zoom 1');
      expect(tester.takeException(), isNull);
    });

    testWidgets('the reclaimed height goes to the event lane, which '
        'stacks its labels', (tester) async {
      await pumpChart(tester, size: tall);
      Set<double> labelRows() {
        final titles = {for (final t in data.allTicks) t.localizedTitle('en')};
        final tops = <double>{};
        for (final e in find.byType(Text).evaluate()) {
          final t = e.widget as Text;
          if (!titles.contains(t.data)) continue;
          final ro = e.renderObject;
          if (ro is! RenderBox || !ro.attached) continue;
          tops.add(ro.localToGlobal(Offset.zero).dy.roundToDouble());
        }
        return tops;
      }

      await viewAt(tester, data.spanEndAm, years: 800);
      // Past AM 2187 the event lane is the only layer with content in
      // it, so it is the layer the folded rows pay. One row of labels
      // became several, which names ticks that used to be anonymous.
      expect(labelRows().length, greaterThan(1),
          reason: 'the taller lane should stack labels, not pad itself');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a viewport straddling AM 2187 draws the bars that are '
        'in it and folds only the rest', (tester) async {
      await pumpChart(tester, size: tall);
      await viewAt(tester, data.computedEndAm, years: 800);

      // Both at once — which is what "not a hard on/off at AM 2187"
      // means in the drawing. One band or several: consecutive folded
      // rows fuse, and which runs are consecutive depends on where the
      // window falls, so the assertion is that SOME rows folded and the
      // ones whose bars are on screen did not.
      expect(find.textContaining('not in view'), findsWidgets);
      expect(find.text('Eber'), findsWidgets,
          reason: 'Eber dies ON the boundary; his bar is in this window');
      expect(find.text('Abraham'), findsWidgets);
      expect(find.text('Adam'), findsNothing,
          reason: 'Adam has been dead 1,250 years at this viewport');
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping a folded band takes the reader to those bars',
        (tester) async {
      await pumpChart(tester, size: tall);
      await viewAt(tester, data.spanEndAm, years: 800);
      final fold = find.text('${data.lifelines.length} not in view');
      expect(fold, findsOneWidget);

      await tester.tap(fold);
      await tester.pumpAndSettle();

      // The way back is the same mechanism a "Jump to" chip uses: it
      // scrolls the plot to where those bars are, and they unfold.
      expect(find.text('${data.lifelines.length} not in view'), findsNothing);
      expect(find.text('Adam'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the narrow 402 pt phone survives the fold, at both ends',
        (tester) async {
      await pumpChart(tester, locale: 'zh-Hans', size: const Size(402, 900));
      await viewAt(tester, data.spanEndAm, years: 400);
      expect(find.textContaining('在视图外'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await viewAt(tester, 0, years: 400);
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.takeException(), isNull);
    });

    testWidgets('folding does not disturb the ruler or the plot width',
        (tester) async {
      // The fold changes HEIGHT only. If it moved the axis, every year
      // on the chart would be wrong.
      await pumpChart(tester, size: tall);
      await viewAt(tester, data.spanEndAm, years: 1200);
      final pos = plotScroll(tester).position;
      final before = pos.maxScrollExtent;
      await tester.pump(const Duration(milliseconds: 200));
      expect(plotScroll(tester).position.maxScrollExtent, before);
      expect(find.text('AM 4098'), findsWidgets);
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
