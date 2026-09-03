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
      // Zoom in first: at 1x the whole span is on screen and there is
      // nothing to scroll, which is the point of 1x.
      await tester.tap(find.byIcon(Icons.zoom_in_rounded));
      await tester.pump(const Duration(milliseconds: 100));

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
        for (var z = 1; z < 8; z++) {
          await tester.tap(find.byIcon(Icons.zoom_in_rounded));
          await tester.pump(const Duration(milliseconds: 60));
          expect(tester.takeException(), isNull,
              reason: 'zoom ${z + 1} in $locale');
        }
        // And the ruler never prints two labels on top of each other:
        // the step ladder widens with the plot, so consecutive AM
        // labels stay at least a label-width apart.
        expect(find.byType(ChronologyChart), findsOneWidget);
      }
    });

    testWidgets('no two ruler labels overlap, at any zoom or width',
        (tester) async {
      // Overlapping year labels are the commonest way this chart type
      // fails, and this one did: at 402 pt with a 1,000-year step,
      // "AM 3000" sat under the pinned "AM 4098". The step ladder and
      // the right-edge reserve are both measured off the text engine
      // now, so this is the assertion that keeps them honest.
      for (final size in const [Size(320, 900), Size(402, 900),
        Size(900, 1200)]) {
        await pumpChart(tester, size: size);
        for (var z = 1; z <= 8; z++) {
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
                  reason: 'ruler labels collide at $size zoom $z: '
                      '${rects[i]} vs ${rects[j]}');
            }
          }
          if (z < 8) {
            await tester.tap(find.byIcon(Icons.zoom_in_rounded));
            await tester.pump(const Duration(milliseconds: 60));
          }
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
