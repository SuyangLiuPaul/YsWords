import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/semantics.dart';
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
///
/// Ratchet pins for the chip-drift characterization test — see
/// `docs/autonomous-queue.md:15260`/`:13639` for what these numbers are
/// for. Re-derive, don't patch, if the packer or the corpus changes.
const _pinnedMaxOrdinaryChipDrift = 45.25;
const _pinnedOverBareLaneRadiusCount = 6;
const _pinnedMaxFoldChipDrift = 13.75;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ChronologyData data;
  late Map<String, dynamic> raw;
  late Map<String, Map<String, dynamic>> familyTree;
  late List kjv;

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
    kjv = json.decode(File('assets/kjv.json').readAsStringSync()) as List;
  });

  /// `book`/`chapter`/`verse` straight out of `assets/kjv.json` — the
  /// same asset the reader sees — so a future edit to that text (a
  /// correction, a versification fix) is what this test actually
  /// tracks, not a copy of the text frozen at write time.
  String kjvVerseText(String book, int chapter, int verse) {
    final row = kjv.cast<Map>().firstWhere(
          (r) =>
              r['book'] == book &&
              r['chapter'] == '$chapter' &&
              r['verse'] == '$verse',
          orElse: () =>
              throw StateError('$book $chapter:$verse missing from '
                  'assets/kjv.json'),
        );
    return row['text'] as String;
  }

  // ── fatherId — pure helpers, operating on whatever list of lifelines
  // they're handed. The tests below feed both the real loaded asset
  // (must be empty) and a deliberately broken in-memory copy (must not
  // be) — never the tracked JSON, which stays untouched.

  /// Everything wrong with the parent links in [lifelines]: an
  /// unresolvable `fatherId`, more or fewer than one root, a root that
  /// isn't `adam`, a birth outside the father's lifetime, a cycle, or —
  /// for a lifeline anchored on a CHILD's birth instead of a father's
  /// begetting age (`anchorChildId`; see CHILD_ANCHORED in
  /// tools/build_bible_chronology.py) — an unresolvable anchor or a
  /// birth ordering that puts the anchor person after, or dead before,
  /// the child they are supposedly the parent of.
  ///
  /// A lifeline with `anchorChildId` set is exempt from the "traces back
  /// to adam via fatherId" walk below: its provenance is by marriage or
  /// motherhood, not a begetting-age chain, and it is never itself a
  /// link anyone else's fatherId points through.
  List<String> fatherLinkDefects(List<Lifeline> lifelines) {
    final byId = {for (final l in lifelines) l.personId: l};
    final defects = <String>[];

    final roots = lifelines
        .where((l) => l.fatherId == null && l.anchorChildId == null)
        .toList();
    if (roots.length != 1) {
      defects.add('expected exactly one root, found ${roots.length}');
    } else if (roots.single.personId != 'adam') {
      defects.add('the one root is ${roots.single.personId}, not adam');
    }

    for (final l in lifelines) {
      if (l.fatherId == null) continue;
      final father = byId[l.fatherId];
      if (father == null) {
        defects.add(
            '${l.personId} fatherId ${l.fatherId} does not resolve');
        continue;
      }
      if (l.birthAm < father.birthAm) {
        defects.add('${l.personId} is born before ${father.personId} is');
      }
      if (father.deathAm != null && l.birthAm > father.deathAm!) {
        defects.add(
            '${father.personId} is dead when ${l.personId} is born');
      }
    }

    for (final l in lifelines) {
      if (l.anchorChildId == null) continue;
      final child = byId[l.anchorChildId];
      if (child == null) {
        defects.add(
            '${l.personId} anchorChildId ${l.anchorChildId} does not resolve');
        continue;
      }
      if (l.birthAm >= child.birthAm) {
        defects.add(
            '${l.personId} is born after their anchor child ${child.personId}');
      }
      if (l.deathAm != null && child.birthAm > l.deathAm!) {
        defects.add(
            '${l.personId} is dead when their anchor child ${child.personId} '
            'is born');
      }
    }

    for (final l in lifelines) {
      if (l.fatherId == null && l.anchorChildId != null) continue;
      final seen = <String>{};
      var cur = l;
      var broke = false;
      while (cur.fatherId != null) {
        if (!seen.add(cur.personId)) {
          defects.add('cycle in ancestry starting at ${l.personId}');
          broke = true;
          break;
        }
        final next = byId[cur.fatherId];
        if (next == null) {
          broke = true; // already reported above
          break;
        }
        cur = next;
      }
      if (!broke && cur.personId != 'adam') {
        defects.add(
            '${l.personId} traces back to ${cur.personId}, not adam');
      }
    }

    return defects;
  }

  /// Wherever the begetting age stated in the derivation prose (all
  /// three locales) disagrees with `birthAm - father.birthAm`.
  ///
  /// Two prose shapes are recognised: the ordinary "X was N when Y was
  /// born" for a directly-stated age, and a "... = N when ..." /
  /// "... = N，..." computed shape for a link like Joseph's, whose age
  /// is chained from several verses rather than stated by one (see
  /// DERIVED_PEOPLE in tools/build_bible_chronology.py). The computed
  /// shape is tried FIRST and, if present, wins — a derived sentence
  /// legitimately narrates other ages first (e.g. Joseph was 30 stood
  /// before Pharaoh) before arriving at the begetting age itself, and
  /// the plain "was N when" pattern would otherwise match one of those
  /// earlier numbers instead.
  List<String> derivationAgeDefects(List<Lifeline> lifelines) {
    final byId = {for (final l in lifelines) l.personId: l};
    final enPattern = RegExp(r'was (\d+) when');
    final hansPattern = RegExp(r'(\d+)\s*岁生');
    final hantPattern = RegExp(r'(\d+)\s*歲生');
    final computedEnPattern = RegExp(r'=\s*(\d+) when');
    final computedHansPattern = RegExp(r'=\s*(\d+)，');
    final computedHantPattern = RegExp(r'=\s*(\d+)，');
    final defects = <String>[];

    for (final l in lifelines) {
      if (l.fatherId == null) continue;
      final father = byId[l.fatherId];
      if (father == null) continue; // reported by fatherLinkDefects
      final expected = l.birthAm - father.birthAm;

      final en = computedEnPattern.firstMatch(l.derivationEn) ??
          enPattern.firstMatch(l.derivationEn);
      if (en == null || int.parse(en.group(1)!) != expected) {
        defects.add('${l.personId} derivationEn age '
            '${en == null ? 'missing' : en.group(1)} != $expected');
      }
      final hans = computedHansPattern.firstMatch(l.derivationZhHans) ??
          hansPattern.firstMatch(l.derivationZhHans);
      if (hans == null || int.parse(hans.group(1)!) != expected) {
        defects.add('${l.personId} derivationZhHans age '
            '${hans == null ? 'missing' : hans.group(1)} != $expected');
      }
      final hant = computedHantPattern.firstMatch(l.derivationZhHant) ??
          hantPattern.firstMatch(l.derivationZhHant);
      if (hant == null || int.parse(hant.group(1)!) != expected) {
        defects.add('${l.personId} derivationZhHant age '
            '${hant == null ? 'missing' : hant.group(1)} != $expected');
      }
    }

    return defects;
  }

  /// Everything wrong with the scheme carried on [lifelines] relative to
  /// [active], the scheme `data.activeScheme` resolves to and the one
  /// `chronology_chart.dart` actually draws on: a plotted lifeline whose
  /// `scheme` isn't [active], or an [active] that isn't itself
  /// [ChronologyScheme.supported]. `chronology_chart.dart` never filters
  /// `data.lifelines` by scheme — it trusts every lifeline it draws to
  /// already be on [active] — so this is the only place that claim is
  /// checked.
  List<String> schemeDefects(
    List<Lifeline> lifelines,
    ChronologyScheme active,
  ) {
    final defects = <String>[];
    if (!active.supported) {
      defects.add('active scheme ${active.id} is not marked supported');
    }
    for (final l in lifelines) {
      if (l.scheme != active.id) {
        defects.add('${l.personId} scheme ${l.scheme} != active ${active.id}');
      }
    }
    return defects;
  }

  /// Copy of [source] with one field replaced — the tracked asset is
  /// never mutated, only an in-memory `Lifeline`.
  Lifeline withBirthAm(Lifeline source, int birthAm) => Lifeline(
        personId: source.personId,
        lineId: source.lineId,
        scheme: source.scheme,
        nameEn: source.nameEn,
        nameZhHans: source.nameZhHans,
        nameZhHant: source.nameZhHant,
        fatherId: source.fatherId,
        anchorChildId: source.anchorChildId,
        birthAm: birthAm,
        deathAm: source.deathAm,
        lifespan: source.lifespan,
        refs: source.refs,
        derivationEn: source.derivationEn,
        derivationZhHans: source.derivationZhHans,
        derivationZhHant: source.derivationZhHant,
      );

  Lifeline withAnchorChildId(Lifeline source, String? anchorChildId) =>
      Lifeline(
        personId: source.personId,
        lineId: source.lineId,
        scheme: source.scheme,
        nameEn: source.nameEn,
        nameZhHans: source.nameZhHans,
        nameZhHant: source.nameZhHant,
        fatherId: source.fatherId,
        anchorChildId: anchorChildId,
        birthAm: source.birthAm,
        deathAm: source.deathAm,
        lifespan: source.lifespan,
        refs: source.refs,
        derivationEn: source.derivationEn,
        derivationZhHans: source.derivationZhHans,
        derivationZhHant: source.derivationZhHant,
      );

  Lifeline withDeathAm(Lifeline source, int? deathAm) => Lifeline(
        personId: source.personId,
        lineId: source.lineId,
        scheme: source.scheme,
        nameEn: source.nameEn,
        nameZhHans: source.nameZhHans,
        nameZhHant: source.nameZhHant,
        fatherId: source.fatherId,
        anchorChildId: source.anchorChildId,
        birthAm: source.birthAm,
        deathAm: deathAm,
        lifespan: source.lifespan,
        refs: source.refs,
        derivationEn: source.derivationEn,
        derivationZhHans: source.derivationZhHans,
        derivationZhHant: source.derivationZhHant,
      );

  Lifeline withFatherId(Lifeline source, String? fatherId) => Lifeline(
        personId: source.personId,
        lineId: source.lineId,
        scheme: source.scheme,
        nameEn: source.nameEn,
        nameZhHans: source.nameZhHans,
        nameZhHant: source.nameZhHant,
        fatherId: fatherId,
        anchorChildId: source.anchorChildId,
        birthAm: source.birthAm,
        deathAm: source.deathAm,
        lifespan: source.lifespan,
        refs: source.refs,
        derivationEn: source.derivationEn,
        derivationZhHans: source.derivationZhHans,
        derivationZhHant: source.derivationZhHant,
      );

  Lifeline withDerivationEn(Lifeline source, String derivationEn) =>
      Lifeline(
        personId: source.personId,
        lineId: source.lineId,
        scheme: source.scheme,
        nameEn: source.nameEn,
        nameZhHans: source.nameZhHans,
        nameZhHant: source.nameZhHant,
        fatherId: source.fatherId,
        anchorChildId: source.anchorChildId,
        birthAm: source.birthAm,
        deathAm: source.deathAm,
        lifespan: source.lifespan,
        refs: source.refs,
        derivationEn: derivationEn,
        derivationZhHans: source.derivationZhHans,
        derivationZhHant: source.derivationZhHant,
      );

  Lifeline withScheme(Lifeline source, String scheme) => Lifeline(
        personId: source.personId,
        lineId: source.lineId,
        scheme: scheme,
        nameEn: source.nameEn,
        nameZhHans: source.nameZhHans,
        nameZhHant: source.nameZhHant,
        fatherId: source.fatherId,
        anchorChildId: source.anchorChildId,
        birthAm: source.birthAm,
        deathAm: source.deathAm,
        lifespan: source.lifespan,
        refs: source.refs,
        derivationEn: source.derivationEn,
        derivationZhHans: source.derivationZhHans,
        derivationZhHant: source.derivationZhHant,
      );

  // ── formatChronologyYearRange ─────────────────────────────────
  //
  // Pure — no widget needed — and previously untested anywhere in the
  // file even though it has its own BC/AD-crossing branch and its own
  // zh branch, both unexercised by anything that only calls
  // [formatChronologyYear]. `masoretic-ussher`'s `creationBc` is 4004,
  // confirmed against `assets/bible_chronology.json` rather than
  // assumed, so `amToYear` below is worked out from that anchor.

  group('formatChronologyYearRange', () {
    late ChronologyScheme scheme;

    setUpAll(() {
      final raw = json.decode(
        File('assets/bible_chronology.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final data = ChronologyData.fromJson(raw);
      scheme = data.activeScheme;
      expect(scheme.creationBc, 4004,
          reason: 'the worked examples below are anchored to this value');
    });

    test('a same-AM span delegates to formatChronologyYear', () {
      expect(
        formatChronologyYearRange(4000, 4000, scheme, 'en'),
        formatChronologyYear(4000, scheme, 'en'),
      );
    });

    test('a same-era BC span reads as one BC range, not two BC years', () {
      // AM 4000 -> 4 BC, AM 4002 -> 2 BC.
      expect(formatChronologyYearRange(4000, 4002, scheme, 'en'), '4–2 BC');
      expect(
        formatChronologyYearRange(4000, 4002, scheme, 'zh-Hans'),
        '公元前4–2年',
      );
      expect(
        formatChronologyYearRange(4000, 4002, scheme, 'zh-Hant'),
        '公元前4–2年',
      );
    });

    test('a same-era AD span reads as one AD range', () {
      // AM 4010 -> AD 7, AM 4012 -> AD 9.
      expect(formatChronologyYearRange(4010, 4012, scheme, 'en'), 'AD 7–9');
      expect(
        formatChronologyYearRange(4010, 4012, scheme, 'zh-Hans'),
        '公元7–9年',
      );
    });

    test('a span crossing BC into AD names both eras, not one', () {
      // AM 4003 -> 1 BC, AM 4005 -> AD 2 — there is no year 0 in between,
      // so this pair is deliberately chosen to straddle the crossing.
      expect(
        formatChronologyYearRange(4003, 4005, scheme, 'en'),
        '1 BC – AD 2',
      );
      expect(
        formatChronologyYearRange(4003, 4005, scheme, 'zh-Hans'),
        '公元前1年 – 公元2年',
      );
    });
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

    // 2026-09-17: `_meta.description` hand-typed "98 events" while three
    // prior slices (fatherId, Isaac/Jacob, Joseph) moved DUPLICATES and
    // events.length to 93 underneath it, and nothing caught the drift —
    // grepping this file for "98" or "description" found zero hits. The
    // generator now interpolates `len(events)` instead of a literal, so
    // this only fires again if a future edit reintroduces a hardcoded
    // number in the "N events" phrasing.
    test("_meta.description's event count never disagrees with "
        'events.length', () {
      final description = (raw['_meta'] as Map)['description'] as String;
      final match = RegExp(r'(\d+) events').firstMatch(description);
      expect(match, isNotNull,
          reason: 'description no longer names an event count in the '
              '"N events" phrasing this test looks for — update the '
              'regex to match the new phrasing, not just delete this '
              'test');
      expect(int.parse(match!.group(1)!), data.events.length,
          reason: 'description names a stale event count; regenerate '
              'assets/bible_chronology.json with '
              'tools/build_bible_chronology.py rather than hand-editing '
              'either');
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
      // The placed-events layer — `bible_timeline.json`'s 93 events —
      // was untouched by this test until now. Its one legitimate
      // exemption is the five intertestamental events (400 Silent
      // Years, Alexander, the Septuagint, the Maccabees, Rome's
      // conquest of Judea): genuinely extra-biblical, not a gap. The
      // exemption is asserted as an iff on `era`, not an id allow-list,
      // so it cannot be widened later just by adding another unsourced
      // event and leaving its era off this line.
      const extraBiblicalEra = 'intertestamental';
      for (final e in data.events) {
        final isUnsourced = e.refs.isEmpty;
        final isExemptEra = e.era == extraBiblicalEra;
        expect(isUnsourced, isExemptEra,
            reason: isUnsourced
                ? 'event ${e.id} has no verse citation and is not '
                    'era $extraBiblicalEra — either cite it or decide '
                    'its era belongs in the exemption'
                : 'event ${e.id} is era $extraBiblicalEra but carries '
                    'a citation — the exemption should not include it');
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
      for (final e in data.events) {
        for (final r in e.refs) {
          if (firstResolvableReference(r) == null) {
            unresolvable.add('${e.id}: $r');
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

    // `fatherId` is parsed by `Lifeline.fromJson` but, until now, read
    // nowhere: no validation, no render. It is also the one field the
    // chart's whole "coloured by descent" premise rests on, so a wrong
    // or absent link would be dead data on the claim the picture makes.

    test('every fatherId resolves to a real lifeline, forming one '
        'acyclic tree rooted at adam, with no one born outside their '
        "father's lifetime", () {
      expect(fatherLinkDefects(data.lifelines), isEmpty);
    });

    test('the fatherId check has teeth', () {
      final byId = {for (final l in data.lifelines) l.personId: l};
      final shem = byId['shem']!;
      final noah = byId['noah']!;

      // Born before the father who is supposed to have begotten him.
      final bornTooEarly = [
        for (final l in data.lifelines)
          l.personId == 'shem' ? withBirthAm(shem, noah.birthAm - 1) : l,
      ];
      expect(
        fatherLinkDefects(bornTooEarly),
        contains('shem is born before noah is'),
      );

      // A fatherId that names nobody on the chart.
      final danglingFather = [
        for (final l in data.lifelines)
          l.personId == 'shem' ? withFatherId(shem, 'nobody') : l,
      ];
      expect(
        fatherLinkDefects(danglingFather),
        contains('shem fatherId nobody does not resolve'),
      );

      // A second root — adam already has none, so giving shem one too
      // means two lifelines with a null fatherId.
      final secondRoot = [
        for (final l in data.lifelines)
          l.personId == 'shem' ? withFatherId(shem, null) : l,
      ];
      expect(
        fatherLinkDefects(secondRoot),
        contains('expected exactly one root, found 2'),
      );

      // A two-node cycle: point noah at shem, on top of shem already
      // pointing at noah.
      final cycle = [
        for (final l in data.lifelines)
          l.personId == 'noah' ? withFatherId(noah, 'shem') : l,
      ];
      expect(
        fatherLinkDefects(cycle),
        anyElement(contains('cycle in ancestry')),
      );
    });

    // Sarah's `anchorChildId` (Isaac) takes the place a `fatherId` chain
    // would otherwise occupy — checked separately here so a broken
    // anchor, or a birth-order violation against the child, is caught
    // exactly as a broken fatherId link would be. Also confirms Sarah's
    // null fatherId does NOT make her a second root on the real asset —
    // 'the fatherId check has teeth' above already proves the OPPOSITE
    // case (giving Shem a null fatherId IS a defect), so this is the
    // half of the exemption that test cannot exercise.
    test('the anchorChildId check has teeth, and does not flag the real '
        'asset', () {
      expect(fatherLinkDefects(data.lifelines), isEmpty);

      final sarah = data.lifelines.firstWhere((l) => l.personId == 'sarah');
      final isaac = data.lifelines.firstWhere((l) => l.personId == 'isaac');

      // An anchorChildId that names nobody on the chart.
      final danglingAnchor = [
        for (final l in data.lifelines)
          l.personId == 'sarah' ? withAnchorChildId(sarah, 'nobody') : l,
      ];
      expect(
        fatherLinkDefects(danglingAnchor),
        contains('sarah anchorChildId nobody does not resolve'),
      );

      // Born after the child she is supposedly the mother of.
      final bornTooLate = [
        for (final l in data.lifelines)
          l.personId == 'sarah'
              ? withBirthAm(sarah, isaac.birthAm + 1)
              : l,
      ];
      expect(
        fatherLinkDefects(bornTooLate),
        contains('sarah is born after their anchor child isaac'),
      );

      // Dead before the child she is supposedly the mother of is born.
      final deadTooSoon = [
        for (final l in data.lifelines)
          l.personId == 'sarah'
              ? withDeathAm(sarah, isaac.birthAm - 1)
              : l,
      ];
      expect(
        fatherLinkDefects(deadTooSoon),
        contains('sarah is dead when their anchor child isaac is born'),
      );
    });

    test('the begetting age stated in the derivation prose matches '
        'birthAm arithmetic, in all three locales', () {
      expect(derivationAgeDefects(data.lifelines), isEmpty);
    });

    test('the derivation-arithmetic check has teeth', () {
      final shem = data.lifelines.firstWhere((l) => l.personId == 'shem');
      final wrongProse = [
        for (final l in data.lifelines)
          l.personId == 'shem'
              ? withDerivationEn(
                  shem,
                  shem.derivationEn.replaceFirst('= 502 when', '= 5 when'),
                )
              : l,
      ];
      expect(
        derivationAgeDefects(wrongProse),
        contains('shem derivationEn age 5 != 502'),
      );
    });

    test('every lifeline declares the chronology scheme its year is on',
        () {
      final ids = data.schemes.map((s) => s.id).toSet();
      for (final l in data.lifelines) {
        expect(ids, contains(l.scheme),
            reason: '${l.personId} cites unknown scheme ${l.scheme}');
      }
    });

    // The check above only confirms `l.scheme` names a *known* scheme —
    // a lifeline carrying a known but unsupported scheme (Septuagint or
    // Samaritan, both present in `data.schemes`) would still pass it,
    // and `_chart` in `chronology_chart.dart` plots `data.lifelines`
    // unfiltered, so it would be drawn on the Ussher axis under the
    // Masoretic banner. `schemeDefects` is the check that actually ties
    // a plotted lifeline to the scheme the chart renders on.

    test('every plotted lifeline is on the scheme the chart actually '
        'renders, data.activeScheme, and that scheme is supported', () {
      expect(schemeDefects(data.lifelines, data.activeScheme), isEmpty);
    });

    test('the scheme check has teeth', () {
      final shem = data.lifelines.firstWhere((l) => l.personId == 'shem');
      // A scheme id that is real (present in `data.schemes`, so the
      // weaker "known scheme" test above would pass it) but carried,
      // not supported — exactly the case the weaker test misses.
      final unsupported = data.schemes.firstWhere((s) => !s.supported).id;
      final wrongScheme = [
        for (final l in data.lifelines)
          l.personId == 'shem' ? withScheme(shem, unsupported) : l,
      ];
      expect(
        schemeDefects(wrongScheme, data.activeScheme),
        contains(
          'shem scheme $unsupported != active ${data.activeScheme.id}',
        ),
      );
    });

    test('_meta.defaultScheme resolves to a real, supported scheme — '
        "activeScheme's unsupported-fallback path is never taken today",
        () {
      expect(data.schemes.map((s) => s.id), contains(data.defaultScheme));
      expect(data.activeScheme.id, data.defaultScheme);
      expect(data.activeScheme.supported, isTrue);
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

    // Pins the Genesis 21:5 / 25:26 / 35:28 / 47:28 arithmetic (AM
    // 2108-2288 and 2168-2315) AND the cross-check the task that added
    // these two named: the isaac_born MARKER — computed independently,
    // from Abraham's birth year plus his stated age at Isaac's birth
    // — has to land on the same year as the isaac LIFELINE's birth, or
    // the two layers disagree about the same page.
    test("Isaac's and Jacob's years match Genesis and the isaac_born "
        'marker', () {
      final isaac = data.lifelines.firstWhere((l) => l.personId == 'isaac');
      final jacob = data.lifelines.firstWhere((l) => l.personId == 'jacob');
      final isaacBorn =
          data.markers.firstWhere((m) => m.id == 'isaac_born');

      expect(isaac.birthAm, 2108, reason: 'Genesis 21:5');
      expect(isaac.deathAm, 2288, reason: 'Genesis 35:28');
      expect(jacob.birthAm, 2168, reason: 'Genesis 25:26');
      expect(jacob.deathAm, 2315, reason: 'Genesis 47:28');
      expect(isaac.birthAm, isaacBorn.am,
          reason: 'the isaac lifeline and the isaac_born marker are '
              'computed independently and must agree');
      expect(jacob.fatherId, 'isaac');
      expect(isaac.fatherId, 'abraham');
    });

    // Pins the Genesis 16:16 / 25:17 arithmetic (AM 2094-2231) and the
    // family_tree.json 86/137 cross-check, and that Ishmael is filed as
    // a BRANCH off Abraham — not a further link toward Isaac — so his
    // years don't move the chain's computed end.
    test("Ishmael's years are the Genesis 16:16 / 25:17 ages Scripture "
        'states directly, and he is a branch off Abraham', () {
      final abraham =
          data.lifelines.firstWhere((l) => l.personId == 'abraham');
      final ishmael =
          data.lifelines.firstWhere((l) => l.personId == 'ishmael');

      expect(ishmael.fatherId, 'abraham');
      expect(ishmael.lineId, 'ishmaelite');
      expect(ishmael.birthAm, abraham.birthAm + 86, reason: 'Genesis 16:16');
      expect(ishmael.birthAm, 2094);
      expect(ishmael.lifespan, 137, reason: 'Genesis 25:17');
      expect(ishmael.deathAm, 2231);
      expect(ishmael.refs, containsAll(<String>[
        'Genesis 16:16', 'Genesis 25:17',
      ]));
      for (final text in [
        ishmael.derivationEn, ishmael.derivationZhHans,
        ishmael.derivationZhHant,
      ]) {
        expect(text, contains('16:16'));
        expect(text, contains('25:17'));
      }

      final famAbraham = familyTree['abraham']!;
      final famIshmael = familyTree['ishmael']!;
      expect(famIshmael['yearSystem'], 'bc');
      expect(
        (famIshmael['birthYear'] as int) - (famAbraham['birthYear'] as int),
        86,
        reason: 'family_tree.json encodes the same 86-year gap on its own '
            'late-date BC scale',
      );
      expect(
        (famIshmael['deathYear'] as int) - (famIshmael['birthYear'] as int),
        137,
        reason: 'family_tree.json also gives Ishmael a 137-year lifespan',
      );

      // Ishmael outlives Abraham (2231 > 2183) but not Isaac (2288) or
      // Joseph (2369) — the computed boundary does not move.
      expect(ishmael.deathAm, greaterThan(abraham.deathAm!));
      final joseph =
          data.lifelines.firstWhere((l) => l.personId == 'joseph');
      expect(ishmael.deathAm, lessThan(joseph.deathAm!));
      expect(data.computedEndAm, 2369);
      expect(data.spanEndAm, 4098);
    });

    // Pins Sarah's Genesis 17:17 / 23:1 arithmetic (AM 2018-2145) and the
    // family_tree.json 10/127-year cross-check on ITS OWN (BC) scale, and
    // that she is anchored on Isaac's birth rather than chained from a
    // father — Genesis 20:12 names Terah as her father but states no
    // begetting age for her, so there is nothing to chain her birth from
    // his the way every CHAIN row above does.
    test("Sarah's years are anchored on Isaac's birth (Genesis 17:17, "
        '21:5), not a father\'s begetting age, and Genesis 23:1 gives her '
        'lifespan directly', () {
      final isaac = data.lifelines.firstWhere((l) => l.personId == 'isaac');
      final sarah = data.lifelines.firstWhere((l) => l.personId == 'sarah');

      expect(sarah.fatherId, isNull,
          reason: 'Genesis 20:12 names Terah as her father but states no '
              'begetting age for her — nothing to chain her birth from');
      expect(sarah.anchorChildId, 'isaac');
      expect(sarah.lineId, 'matriarchs');
      expect(sarah.birthAm, isaac.birthAm - 90, reason: 'Genesis 17:17');
      expect(sarah.birthAm, 2018);
      expect(sarah.lifespan, 127, reason: 'Genesis 23:1');
      expect(sarah.deathAm, 2145);
      expect(sarah.refs, containsAll(<String>[
        'Genesis 17:17', 'Genesis 23:1',
      ]));
      for (final text in [
        sarah.derivationEn, sarah.derivationZhHans, sarah.derivationZhHant,
      ]) {
        expect(text, contains('17:17'));
        expect(text, contains('23:1'));
      }

      final famAbraham = familyTree['abraham']!;
      final famSarah = familyTree['sarah']!;
      expect(famSarah['yearSystem'], 'bc');
      expect(
        (famSarah['birthYear'] as int) - (famAbraham['birthYear'] as int),
        10,
        reason: 'family_tree.json has Sarah born 10 years after Abraham on '
            'its own late-date BC scale',
      );
      expect(
        (famSarah['deathYear'] as int) - (famSarah['birthYear'] as int),
        127,
        reason: 'family_tree.json also gives Sarah a 127-year lifespan '
            '(Genesis 23:1)',
      );

      // Sarah outlives Abraham's birth by a wide margin but dies well
      // before Joseph — the computed boundary does not move.
      final joseph =
          data.lifelines.firstWhere((l) => l.personId == 'joseph');
      expect(sarah.deathAm, lessThan(joseph.deathAm!));
      expect(data.computedEndAm, 2369);
      expect(data.spanEndAm, 4098);
    });

    // Pins Esau's Genesis 25:26 twin-birth arithmetic (AM 2168, the same
    // as Jacob's) and that he is the chart's first OPEN_ENDED row: no
    // verse anywhere states his death age, cross-checked against
    // family_tree.json's independently curated esau record, which has
    // no deathYear and no lifespan field either — the curated tree
    // reaches the same "birth known, death unknown" shape on its own.
    test("Esau shares Jacob's Genesis 25:26 birth year and is drawn "
        'open-ended, since Scripture never states his death age', () {
      final isaac = data.lifelines.firstWhere((l) => l.personId == 'isaac');
      final jacob = data.lifelines.firstWhere((l) => l.personId == 'jacob');
      final esau = data.lifelines.firstWhere((l) => l.personId == 'esau');

      expect(esau.fatherId, 'isaac');
      expect(esau.lineId, 'edomite');
      expect(esau.birthAm, isaac.birthAm + 60, reason: 'Genesis 25:26');
      expect(esau.birthAm, 2168);
      expect(esau.birthAm, jacob.birthAm,
          reason: 'Genesis 25:26 dates both twins in the one verse');
      expect(esau.deathAm, isNull,
          reason: "no verse anywhere states Esau's death age");
      expect(esau.refs, ['Genesis 25:26']);
      for (final text in [
        esau.derivationEn, esau.derivationZhHans, esau.derivationZhHant,
      ]) {
        expect(text, contains('25:26'));
      }
      expect(esau.derivationEn, isNot(contains('lived')),
          reason: 'the open-ended prose must not claim a lifespan');
      expect(esau.derivationZhHans, isNot(contains('活了')));
      expect(esau.derivationZhHant, isNot(contains('活了')));

      final famJacob = familyTree['jacob']!;
      final famEsau = familyTree['esau']!;
      expect(famEsau['yearSystem'], 'bc');
      expect(famEsau['birthYear'], famJacob['birthYear'],
          reason: 'family_tree.json independently gives Esau and Jacob '
              'the same birthYear on its own late-date BC scale');
      expect(famEsau.containsKey('deathYear'), isFalse,
          reason: 'family_tree.json also has no deathYear for Esau');
      expect(famEsau.containsKey('lifespan'), isFalse,
          reason: 'nor a lifespan field');

      // Esau's open-ended bar does not move the computed boundary: it
      // is excluded from computed_end's max() because deathAm is null.
      expect(data.computedEndAm, 2369);
      expect(data.spanEndAm, 4098);
    });

    // Pins the four-verse chain (Gen 41:46 + 41:53 + 45:6 + 47:9 = 91,
    // Jacob's age at Joseph's birth; Gen 50:22/50:26 = Joseph's 110-year
    // lifespan) AND cross-checks it against assets/family_tree.json,
    // which is on a different (BC, late-date) scale but still encodes
    // the same 91-year gap and 110-year lifespan independently.
    test("Joseph's years are the Gen 41/45/47/50 chain, not a stated "
        'age, and agree with family_tree.json', () {
      final jacob = data.lifelines.firstWhere((l) => l.personId == 'jacob');
      final joseph = data.lifelines.firstWhere((l) => l.personId == 'joseph');

      expect(joseph.fatherId, 'jacob');
      expect(joseph.birthAm, jacob.birthAm + 91,
          reason: '30 (Gen 41:46) + 7 (41:53) + 2 (45:6) = 39; '
              '130 (Gen 47:9) - 39 = 91');
      expect(joseph.birthAm, 2259);
      expect(joseph.lifespan, 110, reason: 'Genesis 50:22 / 50:26');
      expect(joseph.deathAm, 2369);
      expect(joseph.refs, containsAll(<String>[
        'Genesis 41:46', 'Genesis 41:53', 'Genesis 45:6', 'Genesis 47:9',
        'Genesis 50:22', 'Genesis 50:26',
      ]));
      // Joseph's derivation must say the figure is computed, never that
      // a verse states it directly — the standard "X was N when Y was
      // born" phrasing every other lifeline uses would misattribute a
      // number no single verse gives.
      for (final text in [
        joseph.derivationEn, joseph.derivationZhHans, joseph.derivationZhHant,
      ]) {
        expect(text, isNot(contains('when Joseph was born (Genesis 41:46')),
            reason: 'must not phrase 91 as a stated begetting age');
      }
      expect(joseph.derivationEn, contains('computed'));

      final famJoseph = familyTree['joseph']!;
      final famJacob = familyTree['jacob']!;
      expect(famJoseph['yearSystem'], 'bc',
          reason: 'a different scale from the AM lifelines — the point '
              'of the cross-check is that it agrees anyway');
      expect(
        (famJoseph['birthYear'] as int) - (famJacob['birthYear'] as int),
        91,
        reason: 'both are negative BC years (more negative = earlier); '
            'family_tree.json encodes the same 91-year gap on its own '
            'late-date BC scale',
      );
      expect(
        (famJoseph['deathYear'] as int) - (famJoseph['birthYear'] as int),
        110,
        reason: 'family_tree.json also gives Joseph a 110-year lifespan',
      );
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

    // A third class, distinct from the undrawn-lines note above: Levi,
    // Kohath, Amram, Moses, Aaron, Joshua and David all have a lifespan
    // Scripture states (David's by sum, not by a verse's own word), but
    // no verse gives their father's age at their birth, so there is no
    // year to anchor a bar on.
    test(
        'the unanchored-lifespans note is declared in all three locales',
        () {
      for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
        expect(data.localizedUnanchored(locale), isNotEmpty,
            reason: 'no $locale note about lifespans this chart cannot '
                'place');
      }
    });

    test(
        'every lifespan the unanchored-lifespans note cites matches '
        'assets/kjv.json, and every reference it names is quoted', () {
      const cites = [
        ('Exodus', 6, 16, 'thirty and seven years', 137, 'Exodus 6:16'),
        ('Exodus', 6, 18, 'thirty and three years', 133, 'Exodus 6:18'),
        ('Exodus', 6, 20, 'thirty and seven years', 137, 'Exodus 6:20'),
        ('Deuteronomy', 34, 7, 'hundred and twenty years old', 120,
            'Deuteronomy 34:7'),
        ('Numbers', 33, 39, 'hundred and twenty and three years old', 123,
            'Numbers 33:39'),
        ('Joshua', 24, 29, 'hundred and ten years old', 110, 'Joshua 24:29'),
        // David: 30 at accession and 40 on the throne (2 Sam 5:4), the
        // 40 itemised as 7½ + 33 (2 Sam 5:5) and repeated in 1 Kings
        // 2:11 — 70 is the note's own sum of 30 + 40, not a number any
        // of these verses states outright (checked separately below).
        ('2 Samuel', 5, 4, 'thirty years old', 30, '2 Samuel 5:4'),
        ('2 Samuel', 5, 4, 'reigned forty years', 40, '2 Samuel 5:4'),
        ('2 Samuel', 5, 5, 'thirty and three years', 33, '2 Samuel 5:5'),
        ('1 Kings', 2, 11, 'forty years', 40, '1 Kings 2:11'),
      ];
      final en = data.localizedUnanchored('en');
      for (final (book, chapter, verse, versePhrase, numeral, ref)
          in cites) {
        expect(kjvVerseText(book, chapter, verse), contains(versePhrase),
            reason: '$ref no longer says "$versePhrase" in '
                'assets/kjv.json — the note\'s figure needs re-deriving');
        expect(en, contains(ref),
            reason: 'the English note does not cite $ref');
        for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
          expect(data.localizedUnanchored(locale), contains('$numeral'),
              reason: 'the $locale note does not cite the age $numeral, '
                  'from $ref');
        }
      }
      // 70 is not itemised above because no verse states it outright —
      // it is 30 + 40 by the note's own arithmetic. Checked directly.
      for (final locale in const ['en', 'zh-Hans', 'zh-Hant']) {
        expect(data.localizedUnanchored(locale), contains('70'),
            reason: 'the $locale note does not give David\'s summed age '
                '70');
      }
    });

    test(
        'every family_tree.json person with a stated lifespan is either '
        'drawn as a lifeline or declared in unanchoredFamilyTreeIds', () {
      final withLifespan = familyTree.values
          .where((p) => p['lifespan'] != null)
          .map((p) => p['id'] as String)
          .toSet();
      final drawn = data.lifelines.map((l) => l.personId).toSet();
      final declaredUnanchored =
          ((raw['_meta'] as Map)['unanchoredFamilyTreeIds'] as List)
              .cast<String>()
              .toSet();
      expect(withLifespan.difference(drawn), declaredUnanchored,
          reason: 'a person with a stated lifespan is missing from the '
              'chart and not accounted for in _meta.unanchoredFamilyTreeIds '
              '— they would silently vanish from the chart');
      expect(declaredUnanchored.difference(withLifespan), isEmpty,
          reason: '_meta.unanchoredFamilyTreeIds names someone '
              'family_tree.json does not give a lifespan to');
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

  /// The on-glass tick-lane labels whose text is exactly [title] — the
  /// same "actually on screen, not just built into the off-screen part
  /// of the Stack" filter the stacked-label test below uses, but keyed
  /// by rendered text instead of "first on glass", so it can target one
  /// specific event rather than whichever tick happens to be nearest.
  /// [viewport] is the plot's own scroll box, not the device width: the
  /// label lane's Stack is laid out at full-timeline width regardless of
  /// scroll position, so a label's paint rect can sit well past the
  /// screen edge while still being (or not being) inside the part the
  /// reader can actually see and tap. Matched on the label's CENTRE
  /// falling inside the viewport, not full containment — the deepest
  /// zoom is a fixed 43-year window, and a long title near that
  /// window's edge legitimately overhangs it while still being the
  /// thing a tap on its visible portion would hit.
  List<Element> onGlassMatches(
    WidgetTester tester,
    String title,
    Rect viewport,
  ) =>
      find
          .byWidgetPredicate((w) =>
              w is Text &&
              w.data == title &&
              w.style?.fontSize != null &&
              (w.style!.fontSize! - 12).abs() < 0.01 &&
              w.maxLines == 1 &&
              w.softWrap == false)
          .evaluate()
          .where((e) {
            final r = tester.getRect(find.byWidget(e.widget));
            return viewport.contains(r.center);
          })
          .toList();

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

    testWidgets(
        "the sheet names a non-root person's father and his age at the "
        'birth, and omits the line entirely for adam', (tester) async {
      await pumpChart(tester);
      await tester.tap(find.text('Methuselah').first);
      await tester.pumpAndSettle();
      // methuselah.birthAm 687 - enoch.birthAm 622 == 65.
      expect(find.text('Son of Enoch (aged 65 at the birth)'),
          findsOneWidget);

      // A fresh pump replaces the whole tree, sheet included. Adam's
      // bar sits well before the default view's cursor (near the
      // Flood), so reach it the same way the reachability test above
      // does — zoom all the way out first.
      await pumpChart(tester);
      await wholeSpan(tester);
      await tester.tap(find.text('Adam').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Son of'), findsNothing,
          reason: 'adam is the root lifeline and has no father to name');
    });

    testWidgets(
        "tapping the father line replaces the sheet with the father's own",
        (tester) async {
      await pumpChart(tester);
      await tester.tap(find.text('Methuselah').first);
      await tester.pumpAndSettle();
      // methuselah.birthAm 687 - enoch.birthAm 622 == 65.
      final fatherLine = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Son of Enoch (aged 65 at the birth)'),
      );
      expect(fatherLine, findsOneWidget);

      await tester.tap(fatherLine);
      await tester.pumpAndSettle();

      // One sheet, not two: only one BottomSheet route is up, it no
      // longer names Methuselah, and it carries Enoch's own title and
      // his own father line.
      expect(find.byType(BottomSheet), findsOneWidget);
      final sheet = find.byType(BottomSheet);
      expect(find.descendant(of: sheet, matching: find.text('Methuselah')),
          findsNothing);
      expect(find.descendant(of: sheet, matching: find.text('Enoch')),
          findsOneWidget);
      // enoch.birthAm 622 - jared.birthAm 460 == 162.
      expect(
        find.descendant(
          of: sheet,
          matching: find.text('Son of Jared (aged 162 at the birth)'),
        ),
        findsOneWidget,
      );
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

    testWidgets(
        'an event with no verse citation says so in its detail sheet, '
        'not an empty citation row', (tester) async {
      final unsourced = data.events.where((e) => e.refs.isEmpty).toList();
      // Re-derived, not assumed: the sourcing test above pins this to
      // exactly the five intertestamental events, but this test only
      // needs "at least one" to have something to open.
      expect(unsourced, isNotEmpty,
          reason: 'nothing unsourced to test — has the exemption changed?');

      await pumpChart(tester, size: const Size(900, 1700));
      for (final e in unsourced) {
        final title = e.localizedTitle('en');
        await viewAt(tester, e.am, years: 8);
        final viewport = tester.getRect(find.byType(SingleChildScrollView).last);
        final matches = onGlassMatches(tester, title, viewport);
        expect(matches, hasLength(1),
            reason: '"$title" (${e.id}) is not uniquely on glass at '
                'AM ${e.am}');
        await tester.tap(find.byWidget(matches.single.widget));
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(BottomSheet),
            matching: find.text('Not recorded in Scripture'),
          ),
          findsOneWidget,
          reason: '${e.id} has no citation and must say so in its sheet',
        );
        Navigator.of(tester.element(find.byType(BottomSheet))).pop();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('a sourced event does not carry the no-citation line',
        (tester) async {
      // The intertestamental cluster's own neighbour: sourced, and far
      // enough from the rest of the monarchy-era events to be alone on
      // glass at this zoom.
      final sourced =
          data.events.firstWhere((e) => e.id == 'nehemiah_walls');
      expect(sourced.refs, isNotEmpty,
          reason: 're-check the fixture — this event should be sourced');
      final title = sourced.localizedTitle('en');

      await pumpChart(tester, size: const Size(900, 1700));
      await viewAt(tester, sourced.am, years: 8);
      final viewport = tester.getRect(find.byType(SingleChildScrollView).last);
      final matches = onGlassMatches(tester, title, viewport);
      expect(matches, hasLength(1),
          reason: '"$title" (${sourced.id}) is not uniquely on glass at '
              'AM ${sourced.am}');
      await tester.tap(find.byWidget(matches.single.widget));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Not recorded in Scripture'),
        ),
        findsNothing,
        reason: '${sourced.id} carries a citation and must not show the '
            'no-citation line',
      );
    });

    testWidgets('a same-year cluster the packer cannot fully seat draws a '
        '"+N" chip, and the chip opens a list naming more than one event',
        (tester) async {
      // AM 4036 — measured directly from assets/bible_chronology.json,
      // not assumed — carries six of the Gospel-era events at the exact
      // same year: Triumphal Entry, Last Supper, Crucifixion,
      // Resurrection, Ascension, Pentecost. They tie on x, so no row the
      // packer tries can ever seat more than one of the six, and at this
      // viewport the surrounding Gospel titles are dense enough that
      // none of the six get a label of their own at all — confirmed by
      // instrumenting `chronologyLabelPlan`'s own drop list before this
      // test was written, at this exact `viewAt` call, rather than
      // assumed from the layout.
      final handle = tester.ensureSemantics();
      await pumpChart(tester, size: const Size(402, 874));
      await viewAt(tester, 4036, years: 100);

      // Other, smaller ties sit within the same 100-year window (AM
      // 4000, 4029, 4038 each carry a pair) — `+6` picks out the one
      // this test is actually about, not just any chip.
      final chip = find.bySemanticsLabel(RegExp(r'^\+6$'));
      expect(chip, findsOneWidget,
          reason: 'no "+6" cluster chip drawn at the AM 4036 tie');

      await tester.tap(chip, warnIfMissed: false);
      await tester.pumpAndSettle();

      const cluster = {
        'Triumphal Entry',
        'Last Supper',
        'Crucifixion of Jesus',
        'Resurrection',
        'Ascension',
        'Pentecost: Holy Spirit Poured Out',
      };
      final namedInSheet = cluster.where((t) => find
          .descendant(of: find.byType(BottomSheet), matching: find.text(t))
          .evaluate()
          .isNotEmpty);
      expect(namedInSheet.length, greaterThan(1),
          reason: 'the cluster sheet should name more than one event — '
              'found: $namedInSheet');
      handle.dispose();
    });

    testWidgets('every one of the 14 events in the densest decade in the '
        'whole corpus (AM 4029–4038) is reachable, enumerated — not just '
        '"more than one" of them', (tester) async {
      // The test above only asserts `namedInSheet.length > 1` for the
      // AM 4036 six-way tie alone — it has never checked that all six are
      // named, and it has never looked at the other eight events sharing
      // this same crowded 100-year window. This test measures the whole
      // decade at once, the "Left open, deliberately" note's own next
      // step (docs/autonomous-queue.md:13323, repeated at 13504/13683/
      // 13974): "The NT's densest decade still cannot label every tick".
      //
      // Re-derived directly from assets/bible_chronology.json for this
      // slice (python3, `events` + `markers`, half-open window
      // `[a, a+10)`, scanning every possible start): AM 4029–4038 is the
      // single densest 10-year window in the whole corpus — 14 events,
      // no markers in it — AM 4029 x2, 4030, 4031, 4032, 4033, AM 4036
      // x6 (the Passion week + Pentecost), AM 4038 x2. That matches the
      // note's own "fourteen events in ten years, six on one year".
      final handle = tester.ensureSemantics();
      await pumpChart(tester, size: const Size(402, 874));
      await viewAt(tester, 4036, years: 100);

      const titles = [
        'Baptism of Jesus',
        'Wilderness Temptation',
        'Calling of the Twelve',
        'Sermon on the Mount',
        'Feeding the 5000',
        'Transfiguration',
        'Triumphal Entry',
        'Last Supper',
        'Crucifixion of Jesus',
        'Resurrection',
        'Ascension',
        'Pentecost: Holy Spirit Poured Out',
        "Paul's Conversion on Damascus Road",
        'Stephen Martyred',
      ];

      final laneBox = find.byKey(const ValueKey('chronoTickLaneBox'));
      final unreached = <String>[];

      for (final title in titles) {
        // Reachable as its own inline label — no tap needed.
        if (find
            .descendant(of: laneBox, matching: find.text(title))
            .evaluate()
            .isNotEmpty) {
          continue;
        }

        var found = false;
        // Keyed by the chip's own `ValueKey('chronoClusterChip_$am')`, not
        // by widget identity: popping a sheet rebuilds the lane, so a
        // `Widget` captured before the tap is a stale instance the tree
        // no longer contains by the time the next chip is tapped.
        final chipKeys = find
            .descendant(
              of: laneBox,
              matching: find.bySemanticsLabel(RegExp(r'^\+\d+$')),
            )
            .evaluate()
            .map((e) => e.findAncestorWidgetOfExactType<Positioned>()?.key)
            .whereType<Key>()
            .toList();
        for (final chipKey in chipKeys) {
          final chipFinder = find.byKey(chipKey);
          if (chipFinder.evaluate().isEmpty) continue;
          await tester.tap(chipFinder, warnIfMissed: false);
          await tester.pumpAndSettle();
          final sheet = find.byType(BottomSheet);
          if (sheet.evaluate().isNotEmpty) {
            // The sheet's list is `ListView(shrinkWrap: true)` — still
            // lazy despite `shrinkWrap`, so with a 14-item bucket a
            // title can be legitimately unbuilt (off-screen), not
            // unreachable. Scroll the sheet's own Scrollable before
            // concluding either way.
            try {
              await tester.scrollUntilVisible(
                find.descendant(of: sheet, matching: find.text(title)),
                60,
                scrollable:
                    find.descendant(of: sheet, matching: find.byType(Scrollable))
                        .first,
              );
              found = true;
            } catch (_) {
              found = find
                  .descendant(of: sheet, matching: find.text(title))
                  .evaluate()
                  .isNotEmpty;
            }
            Navigator.of(tester.element(sheet)).pop();
            await tester.pumpAndSettle();
          }
          if (found) break;
        }
        if (!found) unreached.add(title);
      }

      expect(unreached, isEmpty,
          reason: 'events with no inline label and not named in any '
              'on-screen chip\'s sheet: $unreached');
      handle.dispose();
    });

    testWidgets('tapping the AM 4038 "+2" chip opens its own sheet, not '
        "the AM 4036 tie's", (tester) async {
      // AM 4036 (a "+6" chip) and AM 4038 (a "+2" chip) are two years
      // apart, which is 8 pt of separation at this viewport's density —
      // narrower than either chip's own drawn width. Before the chips
      // were packed, both were drawn content-sized with no collision
      // check, and the AM 4036 chip's fixed 18 pt hit box (unrelated to
      // its actual drawn width) reached well into the AM 4038 chip's
      // visible pixels, so a tap that looked like it landed on "+2"
      // resolved to the AM 4036 tie instead.
      final handle = tester.ensureSemantics();
      await pumpChart(tester, size: const Size(402, 874));
      await viewAt(tester, 4036, years: 100);

      final sixChip = find.bySemanticsLabel(RegExp(r'^\+6$'));
      expect(sixChip, findsOneWidget);
      final sixX = tester.getCenter(sixChip).dx;

      // AM 4000, 4029 and 4038 each carry a pair — three "+2" chips in
      // this window. AM 4038 is the only one of the three AFTER AM 4036
      // (4000 and 4029 both precede it), so it is uniquely identifiable
      // as whichever "+2" chip sits closest to the right of "+6",
      // without relying on any particular packing implementation.
      final twoChips = find.bySemanticsLabel(RegExp(r'^\+2$'));
      expect(twoChips, findsNWidgets(3),
          reason: 'AM 4000, 4029 and 4038 each carry a pair');
      Finder? target;
      var bestDx = double.infinity;
      for (var i = 0; i < 3; i++) {
        final f = twoChips.at(i);
        final dx = tester.getCenter(f).dx - sixX;
        if (dx > 0 && dx < bestDx) {
          bestDx = dx;
          target = f;
        }
      }
      expect(target, isNotNull,
          reason: 'no "+2" chip sits to the right of the AM 4036 "+6" chip '
              '— AM 4038 should be there');

      await tester.tap(target!, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text("Paul's Conversion on Damascus Road"),
        ),
        findsOneWidget,
        reason: 'tapping the AM 4038 chip should open the AM 4038 sheet',
      );
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Triumphal Entry'),
        ),
        findsNothing,
        reason: 'the AM 4036 sheet must not open when the AM 4038 chip is '
            'tapped',
      );
      handle.dispose();
    });

    testWidgets('a row-exhaustion drop with nobody to tie with still gets '
        'a chip, never silence', (tester) async {
      // AM 4030–4033 — Calling of the Twelve, Sermon on the Mount,
      // Feeding the 5000, Transfiguration — one event each, so none of
      // them ties on x with anything the way the AM 4036 six-way tie
      // above does. They sit in the same crowded 100-year window as the
      // two chip tests above, between the AM 4029 pair and the AM 4036
      // tie, and used to be dropped by the label packer for want of a
      // free row and then discarded outright by the caller's old
      // `.where((g) => g.length > 1)` filter — a bucket of one from a
      // row-exhaustion drop looked exactly like a bucket of one from an
      // edge drop, and both were thrown away. The tick was still
      // painted, so the reader saw an unnamed mark with nothing to tap.
      final handle = tester.ensureSemantics();
      await pumpChart(tester, size: const Size(402, 874));
      await viewAt(tester, 4036, years: 100);

      const singles = [
        'Calling of the Twelve',
        'Sermon on the Mount',
        'Feeding the 5000',
        'Transfiguration',
      ];

      // First confirm this test is actually exercising the row-
      // exhaustion path and not a viewport where the packer had room
      // after all — a title drawn as its own label makes the rest of
      // this test vacuous.
      for (final title in singles) {
        expect(find.text(title), findsNothing,
            reason: '$title has its own label at this viewport — this '
                'test is not measuring the row-exhaustion path any more; '
                'the window or the fixture data has moved');
      }

      // Every one of the four must be reachable from some on-screen
      // chip — its own "+1", or merged into a neighbour's "+N" — by
      // opening whichever sheet that chip leads to (a single event's own
      // sheet, or a list sheet naming several).
      for (final title in singles) {
        var found = false;
        for (final chip
            in find.bySemanticsLabel(RegExp(r'^\+\d+$')).evaluate().toList()) {
          await tester.tap(find.byWidget(chip.widget), warnIfMissed: false);
          await tester.pumpAndSettle();
          if (find
              .descendant(
                  of: find.byType(BottomSheet), matching: find.text(title))
              .evaluate()
              .isNotEmpty) {
            found = true;
          }
          if (find.byType(BottomSheet).evaluate().isNotEmpty) {
            Navigator.of(tester.element(find.byType(BottomSheet))).pop();
            await tester.pumpAndSettle();
          }
          if (found) break;
        }
        expect(found, isTrue,
            reason: '$title is neither labeled nor reachable from any '
                'on-screen chip');
      }
      handle.dispose();
    });

    testWidgets(
        'the "+N" cluster chip\'s band is tall enough for its own glyph '
        'at large text scale', (tester) async {
      // The chip's box height was a flat 13, like every other lane
      // metric used to be before `_lineHeight` was threaded through
      // them — except this one was missed. Measured directly (not
      // derived from `8.5 * scale * 1.4`, per this file's own refuter
      // rule): at 100% text the "+6" chip's glyph needs 12 pt in its
      // 13 pt box (fits); at 130% it needs 16 pt in the same 13 pt box;
      // at 200% it needs 24 pt. Both of the larger cases used to
      // overflow the fixed band and paint into the label row below it.
      for (final scale in const [1.0, 1.3, 2.0]) {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(402, 874);
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
        await viewAt(tester, 4036, years: 100);

        final chipTextFinder = find.text('+6');
        expect(chipTextFinder, findsOneWidget,
            reason: 'no "+6" chip drawn at scale $scale');

        // The box the chip is actually laid out and hit-tested in — read
        // off the widget tree, not re-derived, so this fails on the
        // fixed-13 code exactly the way the reader would experience it.
        final positioned = tester.widget<Positioned>(
          find
              .ancestor(of: chipTextFinder, matching: find.byType(Positioned))
              .first,
        );
        final boxHeight = positioned.height!;

        // The glyph's actual drawn height, measured the same way the
        // chart itself measures widths (`_measure`): through the
        // ambient style and the reader's own text scaler.
        final textWidget = tester.widget<Text>(chipTextFinder);
        final ctx = tester.element(chipTextFinder);
        final tp = TextPainter(
          text: TextSpan(
            text: textWidget.data,
            style: DefaultTextStyle.of(ctx).style.merge(textWidget.style),
          ),
          maxLines: 1,
          textScaler: MediaQuery.textScalerOf(ctx),
          textDirection: TextDirection.ltr,
        )..layout();

        expect(boxHeight, greaterThanOrEqualTo(tp.height),
            reason: 'at text scale $scale the chip band is $boxHeight pt '
                'but its own glyph needs ${tp.height} pt — it will spill '
                'into the label row below');
      }
    });

    testWidgets('every drawn event label is its own accessibility node, '
        'not one merged utterance for the whole lane', (tester) async {
      // 2026-09-09, residual #2 of the "left open, deliberately" note on
      // `queue:12717`. The lane was one opaque GestureDetector wrapping
      // bare Text widgets — nothing gave any individual label its own
      // semantics boundary, so every title on screen merged upward into
      // that one ancestor node. A screen reader read all of them as a
      // single run-on utterance and could not target one event.
      //
      // Reproduced first: this pumps the same New Testament decade the
      // "tapping a stacked label" test above uses, where fourteen events
      // are visibly stacked, and measures the semantics tree that is
      // ACTUALLY there — not the "64" the queue note inherited from a
      // different capture.
      final handle = tester.ensureSemantics();
      await pumpChart(tester, size: const Size(900, 1700));
      for (var i = 0; i < 16; i++) {
        await tester.tap(find.byIcon(Icons.zoom_in_rounded));
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.tap(find.byKey(const ValueKey('chronoChip_john_patmos')));
      await tester.pumpAndSettle();

      // Same predicate the tap-routing test above uses to find labels
      // actually on glass at this viewport.
      final onGlass = find
          .byWidgetPredicate((w) =>
              w is Text &&
              w.style?.fontSize != null &&
              (w.style!.fontSize! - 12).abs() < 0.01 &&
              w.maxLines == 1 &&
              w.softWrap == false)
          .evaluate()
          .map((e) => (
                tester.getRect(find.byWidget(e.widget)),
                (e.widget as Text).data!,
              ))
          .where((r) => r.$1.left >= 0 && r.$1.right <= 900)
          .toList();
      expect(onGlass.length, greaterThan(1),
          reason: 'need more than one visible label for this test to mean '
              'anything at this viewport');
      final titles = onGlass.map((e) => e.$2).toSet();
      expect(titles.length, onGlass.length,
          reason: 'two labels on glass share a title — the per-title '
              'lookup below would be ambiguous; adjust the viewport');

      final owner = tester.semantics.find(find.byType(ChronologyChart)).owner!;
      List<SemanticsNode> flatten(SemanticsNode n) {
        final out = <SemanticsNode>[n];
        n.visitChildren((c) {
          out.addAll(flatten(c));
          return true;
        });
        return out;
      }

      final all = flatten(owner.rootSemanticsNode!);
      for (final title in titles) {
        final matches = all
            .where((n) => n.getSemanticsData().label == title)
            .toList();
        expect(matches.length, 1,
            reason: '"$title" should have exactly one semantics node');
        final node = matches.single;
        expect(node.isMergedIntoParent, isFalse,
            reason: '"$title" is merged into an ancestor — a screen reader '
                'cannot address it on its own');
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue,
            reason: '"$title" carries no tap action of its own');
      }

      // And the accessibility tap actually opens THAT event, exactly the
      // way `SemanticsOwner.performAction` drives it for a screen reader
      // or Flutter web's DOM overlay — not `tester.tap`, which hit-tests
      // the render tree and would pass even if every label above were
      // merged into one node.
      final deepest =
          (onGlass.toList()..sort((a, b) => b.$1.top.compareTo(a.$1.top)))
              .first;
      final target =
          all.firstWhere((n) => n.getSemanticsData().label == deepest.$2);
      owner.performAction(target.id, SemanticsAction.tap);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text(deepest.$2),
        ),
        findsOneWidget,
        reason: 'the accessibility tap must open the sheet for the label '
            'that was actually activated',
      );
      handle.dispose();
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
    test('lifelines are still bounded by a continuous chain of ages', () {
      // The span doubled; the BARS did not, past where Scripture stops
      // giving a continuous chain of ages — directly stated ages for
      // most, and Shem's, Abraham's and Joseph's each chained together
      // from multiple verses rather than a single one. That boundary moved twice
      // now — Isaac and Jacob's ages are stated as directly as Genesis
      // 11's, and Joseph's is the chain's first derived link — so this
      // pins the chain's actual end (Joseph), not a fixed "past
      // Abraham" or "past Jacob" claim. 26, not 23: Ishmael is a branch
      // off Abraham, not a further link, so he adds a lifeline without
      // moving the chain's end; Sarah is a further branch again, anchored
      // on Isaac's birth rather than a father's begetting age (see
      // CHILD_ANCHORED in tools/build_bible_chronology.py), so she too
      // adds a lifeline without moving it; Esau is a third branch, off
      // Isaac this time, open-ended because Scripture never gives his
      // death age (see OPEN_ENDED), and he does not move it either.
      expect(data.lifelines, hasLength(26));
      expect(data.lifelines.first.personId, 'adam');
      final byId = {for (final l in data.lifelines) l.personId};
      expect(byId, contains('abraham'));
      expect(byId, contains('isaac'));
      expect(byId, contains('jacob'));
      expect(byId, contains('joseph'));
      for (final l in data.lifelines) {
        for (final r in l.refs) {
          expect(
            r.startsWith('Genesis') || r.startsWith('Acts') ||
                r.startsWith('Hebrews'),
            isTrue,
            reason: '${l.personId} cites $r — not a book this chain '
                'draws from',
          );
        }
        // Esau is the one exception: his death age is never stated
        // (see OPEN_ENDED in tools/build_bible_chronology.py), and a
        // null deathAm does not move the computed boundary — it is
        // excluded from the max() below by construction (computed_end
        // in the generator).
        if (l.personId == 'esau') {
          expect(l.deathAm, isNull);
          continue;
        }
        expect(l.deathAm, isNotNull);
        expect(l.deathAm, lessThanOrEqualTo(data.computedEndAm));
      }
      expect(
        data.lifelines
            .map((l) => l.deathAm)
            .whereType<int>()
            .reduce((a, b) => a > b ? a : b),
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

  group('same-year events keep bible_timeline.json\'s narrative order', () {
    // allTicks used to tie-break same-AM events alphabetically by id,
    // which is meaningless — it put the Ascension before the
    // Crucifixion in the AM 4036 "+6" cluster. The tie-break is now the
    // event's own position in bible_timeline.json (carried as `seq`).
    test('AM 4036 — the Passion week — is not alphabetised', () {
      final ids = data.allTicks
          .where((t) => t.am == 4036)
          .map((t) => t.id)
          .toList();
      expect(ids, [
        'triumphal_entry',
        'last_supper',
        'crucifixion',
        'resurrection',
        'ascension',
        'pentecost',
      ]);
    });

    test('the other unambiguous same-year ties are in source order', () {
      expect(data.allTicks.where((t) => t.am == 2558).map((t) => t.id),
          ['burning_bush', 'plagues', 'exodus', 'red_sea', 'manna', 'sinai']);
      expect(data.allTicks.where((t) => t.am == 2598).map((t) => t.id),
          ['wilderness_40', 'moses_dies', 'jordan_crossed', 'jericho']);
      expect(data.allTicks.where((t) => t.am == 4000).map((t) => t.id),
          ['magi', 'flight_egypt']);
      expect(data.allTicks.where((t) => t.am == 4038).map((t) => t.id),
          ['stephen_martyred', 'paul_converted']);
    });

    test('every same-AM group of events matches its relative order in '
        'bible_timeline.json', () {
      final timeline = json.decode(
        File('assets/bible_timeline.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final sourceOrder = <String, int>{};
      for (final (i, e) in (timeline['events'] as List)
          .cast<Map<String, dynamic>>()
          .indexed) {
        sourceOrder[e['id'] as String] = i;
      }
      final byAm = <int, List<String>>{};
      for (final e in data.events) {
        byAm.putIfAbsent(e.am, () => []).add(e.id);
      }
      for (final entry in byAm.entries) {
        if (entry.value.length < 2) continue;
        final sourcePositions =
            entry.value.map((id) => sourceOrder[id]!).toList();
        expect(sourcePositions, [...sourcePositions]..sort(),
            reason: 'AM ${entry.key}: ${entry.value} is not in '
                'bible_timeline.json order');
      }
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

    test('every row-exhaustion AND edge drop ends up bucketed — '
        'chronologyLabelClusters no longer excludes a candidate close to '
        'the plot edge, because chronologyChipPlan already shrinks or '
        'folds a chip that has nowhere to go rather than dropping it',
        () {
      // Six candidates share one x — a six-event year no zoom can pull
      // apart, since every row starts fresh at each x and packing harder
      // only ever seats one more of the six.
      //
      // Two more sit near the plot's right edge, both too close for
      // their LABEL to ever have been drawn (`left + labelMinWidth(34) >
      // plotWidth`):
      //  - index 7 at `plotWidth - 5` has 5 pt of room, less than even a
      //    single-digit "+N" chip's own unshrunk width (measured ~21 pt
      //    at 100% text — see chronologyLabelClusters's doc). Until
      //    2026-09-15 this function excluded it outright; it no longer
      //    does, because [chronologyChipPlan] shrinks or folds a chip
      //    that has nowhere to go rather than dropping it — the bucket
      //    only has to get the candidate there, not size it.
      //  - index 8 at `plotWidth - 25` has 25 pt of room: still not
      //    enough for a label, but more than enough for an unshrunk
      //    chip — the band a 2026-09-14 fix already opened up.
      const plotWidth = 200.0;
      final lefts = [
        10.0, 10.0, 10.0, 10.0, 10.0, 10.0, // the six-way tie
        60.0, // an ordinary row-exhaustion drop, placed in the packer's
        // one free slot after the tie, so it should NOT be dropped
        plotWidth - 5, // index 7: 5 pt of room
        plotWidth - 25, // index 8: 25 pt of room
      ];
      final wants = [for (var i = 0; i < lefts.length; i++) 40.0];
      final plan = chronologyLabelPlan(
        lefts: lefts,
        wants: wants,
        rows: 1,
        plotWidth: plotWidth,
      );
      final buckets = chronologyLabelClusters(
        lefts: lefts,
        plan: plan,
      );

      final placed = {for (final s in plan) s.index};
      final bucketed = <int>{};
      for (final bucket in buckets) {
        for (final i in bucket) {
          expect(bucketed.add(i), isTrue,
              reason: 'candidate $i counted in more than one bucket');
        }
      }
      // Nobody is excluded any more: every unplaced candidate, edge or
      // not, is in exactly one bucket.
      for (var i = 0; i < lefts.length; i++) {
        expect(placed.contains(i) || bucketed.contains(i), isTrue,
            reason: 'candidate $i is in neither the plan nor a bucket — '
                'it vanished');
      }
      expect(placed.intersection(bucketed), isEmpty,
          reason: 'a candidate the packer placed was also bucketed');

      // The six-way tie comes back as ONE bucket, not six singletons —
      // that is the whole point: it is discoverable as a group.
      final tie = buckets.where((b) => lefts[b.first] == 10.0);
      expect(tie.length, 1);
      expect(tie.first, hasLength(5));
      // Indices 7 and 8 are 20 pt apart — exactly this call's default
      // mergeDistance — so they chain into ONE bucket, rather than
      // index 7 being excluded outright the way it used to be.
      final edgeBucket = buckets.where((b) => b.contains(7));
      expect(edgeBucket.length, 1);
      expect(edgeBucket.first, unorderedEquals([7, 8]));
      expect(buckets, hasLength(2));
    });

    test('a lone row-exhaustion drop with nobody within mergeDistance '
        'still comes back as its own bucket', () {
      // The AD 27–30 case from the queue: four single-event years, each
      // dropped for want of a free row, sitting between two real ties.
      // None of them shares an x with anything, but none of them may
      // vanish either — that was the bug. A drop far from every other
      // drop is the base case: it must still surface as a bucket of one,
      // even though nothing merges into it.
      const plotWidth = 1000.0;
      // Candidate 0 is wide enough to occupy the lane's one row all the
      // way past candidate 1's x, so candidate 1 is dropped for want of
      // a free row — row exhaustion, not the edge path (500 + 34 is
      // nowhere near plotWidth).
      final lefts = [0.0, 500.0];
      final wants = [600.0, 40.0];
      final plan = chronologyLabelPlan(
        lefts: lefts,
        wants: wants,
        rows: 1,
        plotWidth: plotWidth,
      );
      expect({for (final s in plan) s.index}, {0});
      final buckets = chronologyLabelClusters(
        lefts: lefts,
        plan: plan,
        mergeDistance: 20,
      );
      // Candidate 1, at x 500, is 500 pt from the only other candidate —
      // far outside mergeDistance — and there is nothing else dropped,
      // so it must still come back as a bucket of exactly itself.
      expect(buckets, hasLength(1));
      expect(buckets.single, [1]);
    });

    test('the chip packer never lets two "+N" chips overlap', () {
      // Measured off the real corpus, not synthesized: AM 4036 (a "+6"
      // chip) and AM 4038 (a "+2" chip) are two years apart, which is
      // 8 pt of anchor separation at this lane's default zoom — well
      // inside the width of either chip. Reproduced with the same
      // numbers the widget test below exercises live.
      const gap = 2.0;
      const lefts = [0.0, 8.0];
      const widths = [22.0, 16.0]; // "+6" then "+2", padded
      final plan = chronologyChipPlan(
        lefts: lefts,
        widths: widths,
        plotWidth: 400,
      );
      expect(plan, hasLength(2));
      expect(plan[0].left, lefts[0], reason: 'the leftmost chip never moves');
      expect(plan[1].left, greaterThanOrEqualTo(plan[0].left + plan[0].width),
          reason: 'the second chip must clear the first, not sit under it');
      expect(plan[1].left - lefts[1], greaterThanOrEqualTo(0),
          reason: 'a chip is only ever pushed right, never left of its own '
              'anchor');
      // And a comfortable gap survives the push, not just zero overlap.
      expect(plan[1].left, plan[0].left + plan[0].width + gap);
    });

    test('the chip packer never reorders ties, never overlaps two chips, '
        'and never pushes a chip left of its own anchor', () {
      final rnd = <double>[
        for (var i = 0; i < 40; i++) i * 11.0 + (i % 5) * 3,
      ];
      final widths = <double>[
        for (var i = 0; i < 40; i++) 14.0 + (i % 4) * 6,
      ];
      final plan = chronologyChipPlan(
        lefts: rnd,
        widths: widths,
        plotWidth: 900,
      );
      // Order along x is preserved: the plan comes back sorted by the
      // original anchor, and a later tie is never pushed ahead of an
      // earlier one.
      for (var i = 1; i < plan.length; i++) {
        expect(rnd[plan[i].cluster], greaterThanOrEqualTo(rnd[plan[i - 1].cluster]));
      }
      // No two placed chips overlap.
      for (var i = 1; i < plan.length; i++) {
        expect(plan[i].left, greaterThanOrEqualTo(plan[i - 1].left + plan[i - 1].width - 0.01));
      }
      // A chip is never pushed left of its own anchor.
      for (final s in plan) {
        expect(s.left, greaterThanOrEqualTo(rnd[s.cluster] - 0.01));
      }
      // No placed chip is drawn past the plot's right edge.
      for (final s in plan) {
        expect(s.left + s.width, lessThanOrEqualTo(900.0 + 0.01));
      }
    });

    test('the chip packer shrinks, but still places, a chip that runs off '
        'the plot rather than dropping it silently', () {
      final plan = chronologyChipPlan(
        lefts: const [390.0],
        widths: const [30.0],
        plotWidth: 400,
      );
      expect(plan, hasLength(1),
          reason: 'a same-year tie the reader cannot tap is worse than one '
              'drawn a little narrow — it must still be placed');
      expect(plan.first.width, lessThan(30.0));
      expect(plan.first.left + plan.first.width, lessThanOrEqualTo(400.0));
    });

    test('the chip packer never draws past plotWidth even when the room '
        'left is under 1pt', () {
      final plan = chronologyChipPlan(
        lefts: const [99.7],
        widths: const [5.0],
        plotWidth: 100.0,
      );
      expect(plan, hasLength(1));
      expect(plan.first.left + plan.first.width, lessThanOrEqualTo(100.0),
          reason: 'a floored-at-1.0 room used to let this chip draw at '
              'left=99.7 width=1.0, past the 100.0 axis');
    });

    test('a crowded row folds what will not fit into one terminal chip '
        'instead of dropping it — the clusters=43 placed=40 shape', () {
      // 43 anchors 3 pt apart, each wanting a 20 pt chip: every chip
      // after the first is pushed by its neighbour's width+gap (22 pt),
      // not by its own 3 pt of anchor spacing, so the row runs out of
      // plotWidth long before all 43 are seated at their own x — the
      // same cumulative-push shape that silently dropped 3 of 43 chips
      // before this fix (`clusters=43 placed=40`, measured off the real
      // corpus in `bible_chronology_test.dart` before this change).
      final lefts = [for (var i = 0; i < 43; i++) i * 3.0];
      final widths = List<double>.filled(43, 20.0);
      final plan = chronologyChipPlan(
        lefts: lefts,
        widths: widths,
        plotWidth: 300,
      );
      final reachable = plan.fold<int>(
          0, (sum, slot) => sum + 1 + slot.extraClusters.length);
      expect(reachable, 43,
          reason: 'every one of the 43 same-year ties must end up either '
              'with its own chip or inside the terminal chip\'s merged '
              'cluster list — none may simply vanish');
      // The clusters a terminal chip folded in must not also show up as
      // their own separate slot elsewhere in the plan.
      final seen = <int>{};
      for (final slot in plan) {
        seen.add(slot.cluster);
        seen.addAll(slot.extraClusters);
      }
      expect(seen, hasLength(43));
      // The plan still fits inside the plot the caller asked for.
      for (final slot in plan) {
        expect(slot.left + slot.width, lessThanOrEqualTo(300.0));
      }
    });

    test('a terminal-fold chip past the plot edge is seated at its '
        'measured merged width, not a 1pt sliver, when the previous chip '
        'left real room behind it', () {
      // The real corpus shape (`queue:13149`, 2026-09-15 follow-up): the
      // tick lane builds `lefts[i] = _x(t.am, plotWidth) + 3`, and for
      // the very last event `t.am == spanEndAm` so `_x` returns exactly
      // `plotWidth` — the last tick's own left is always `plotWidth + 3`,
      // by that formula, not by a one-off measurement. A candidate whose
      // `left` is already `>= plotWidth` hits the fold branch directly on
      // its very first iteration, before the ordinary shrink path (which
      // only ever sees `left < plotWidth`) gets a look at it.
      const plotWidth = 400.0;
      final plan = chronologyChipPlan(
        lefts: const [50.0, plotWidth + 3],
        widths: const [20.0, 20.0],
        plotWidth: plotWidth,
        measureMergedWidth: (_) => 26.0,
      );
      expect(plan, hasLength(2));
      final terminal = plan.last;
      expect(terminal.cluster, 1);
      // The previous chip is seated at 50 and ends at 70 (width clamped
      // to its own 20 pt ask, since 400 - 50 = 350 pt of room). The
      // terminal chip therefore has 400 - (70 + gap) = 328 pt behind it
      // — far more than its measured 26 pt — so it must be drawn at that
      // full measured width, not shrunk to a sliver.
      expect(terminal.width, 26.0,
          reason: 'the previous chip ends at 70 with plenty of room to '
              'plotWidth 400; the terminal chip must take its measured '
              'width, not a hardcoded 1.0 sliver');
      expect(terminal.left, plotWidth - 26.0,
          reason: 'pulled left off the plot edge by exactly its own '
              'width, not clamped to plotWidth - 1.0');
      expect(terminal.left + terminal.width, lessThanOrEqualTo(plotWidth));
      expect(terminal.left, greaterThanOrEqualTo(0.0));
    });

    test('the terminal fold absorbs a previous chip that left no real '
        'room, instead of overlapping it (queue:13986)', () {
      // Exact repro from the queue item: the first chip is seated at
      // [98.0, 100.0] — jammed against the plot edge with nothing behind
      // it — so the terminal fold's `room` used to floor at 1.0 and draw
      // at [99.0, 100.0], a 1pt overlap with the chip already there. The
      // fix folds that previous chip into the terminal one instead.
      final plan = chronologyChipPlan(
        lefts: const [98.0, 200.0],
        widths: const [50.0, 20.0],
        plotWidth: 100.0,
      );
      expect(plan, hasLength(1),
          reason: 'the previous chip had no real room of its own once the '
              'fold needed it, so it must be absorbed into one slot, not '
              'left standing to be overlapped');
      final covered = {plan.single.cluster, ...plan.single.extraClusters};
      expect(covered, {0, 1});
      expect(plan.single.left, greaterThanOrEqualTo(0.0));
      expect(plan.single.left + plan.single.width, lessThanOrEqualTo(100.0));
    });

    test('property: for a grid of lefts/widths/plotWidth, including '
        'edge-jammed and past-edge anchors, the chip packer never '
        'overlaps, never exceeds plotWidth, never reorders, and never '
        'drops a cluster index', () {
      const plotWidths = [40.0, 60.0, 100.0, 150.0, 300.0];
      const anchorSets = [
        [98.0, 200.0], // the queue's exact jammed-previous-chip repro
        [0.0, 40.0, 80.0, 120.0, 160.0],
        [95.0, 96.0, 97.0, 98.0, 99.0], // tightly packed near the edge
        [10.0, 500.0], // one placed comfortably, one far past the edge
        [-5.0, 30.0, 60.0, 90.0, 400.0], // a past-edge anchor too
      ];
      const widthSets = [
        [50.0, 20.0],
        [15.0, 15.0, 15.0, 15.0, 15.0],
        [30.0, 30.0, 30.0, 30.0, 30.0],
        [40.0, 40.0],
        [10.0, 20.0, 20.0, 20.0, 20.0],
      ];
      for (final plotWidth in plotWidths) {
        for (final lefts in anchorSets) {
          for (final widths in widthSets) {
            if (widths.length != lefts.length) continue;
            final plan = chronologyChipPlan(
              lefts: lefts,
              widths: widths,
              plotWidth: plotWidth,
            );
            final context = 'plotWidth=$plotWidth lefts=$lefts widths=$widths';
            // No two slots overlap.
            for (var i = 1; i < plan.length; i++) {
              expect(
                plan[i].left,
                greaterThanOrEqualTo(plan[i - 1].left + plan[i - 1].width - 1e-9),
                reason: 'overlap at slot $i — $context',
              );
            }
            // No slot's right edge exceeds plotWidth.
            for (final s in plan) {
              expect(s.left + s.width, lessThanOrEqualTo(plotWidth + 1e-9),
                  reason: 'past plotWidth — $context');
            }
            // Slots stay in x order (by original anchor).
            for (var i = 1; i < plan.length; i++) {
              expect(
                lefts[plan[i].cluster],
                greaterThanOrEqualTo(lefts[plan[i - 1].cluster]),
                reason: 'reordered — $context',
              );
            }
            // The union of cluster + extraClusters is exactly the input
            // index set — nothing dropped, nothing duplicated.
            final covered = <int>{};
            for (final s in plan) {
              covered.add(s.cluster);
              covered.addAll(s.extraClusters);
            }
            expect(covered, {for (var i = 0; i < lefts.length; i++) i},
                reason: 'index set mismatch — $context');
            expect(covered.length,
                plan.fold<int>(0, (n, s) => n + 1 + s.extraClusters.length),
                reason: 'a cluster index appears in more than one slot — '
                    '$context');
          }
        }
      }
    });

    test('composed labelPlan → labelClusters → chipPlan: every candidate '
        'ends up placed or chipped — nothing is silently lost across all '
        'three stages together, not even a candidate with 3 pt of room '
        'right at the plot edge', () {
      const plotWidth = 500.0;
      final lefts = <double>[
        20.0, 20.0, 20.0, // a three-way tie; the packer seats one
        100.0, // placed, ends the first row
        115.0, 130.0, // row-exhaustion singles, close enough to chain
        250.0, // placed in the row's remaining room
        plotWidth - 3, // 3 pt of room: less than an unshrunk chip needs,
        // but chronologyChipPlan shrinks a chip that has nowhere to go
        // rather than dropping it (fixed 2026-09-15 — this used to be
        // excluded by chronologyLabelClusters before it ever reached
        // that machinery)
        plotWidth - 25, // 25 pt: no label (needs 34), but an unshrunk
        // chip (needs ~21) fits — the band the 2026-09-14 fix opened up
      ];
      final wants = List<double>.filled(lefts.length, 40.0);
      final plan = chronologyLabelPlan(
        lefts: lefts,
        wants: wants,
        rows: 1,
        plotWidth: plotWidth,
      );
      final clusters = chronologyLabelClusters(
        lefts: lefts,
        plan: plan,
        mergeDistance: 20,
      );
      final chipLefts = [for (final c in clusters) lefts[c.first]];
      final chipWidths = List<double>.filled(clusters.length, 20.0);
      final chipPlan = chronologyChipPlan(
        lefts: chipLefts,
        widths: chipWidths,
        plotWidth: plotWidth,
      );

      final placed = {for (final s in plan) s.index};
      final chipCovered = <int>{};
      for (final slot in chipPlan) {
        for (final ci in [slot.cluster, ...slot.extraClusters]) {
          chipCovered.addAll(clusters[ci]);
        }
      }
      expect(placed.intersection(chipCovered), isEmpty,
          reason: 'a candidate the packer placed was also chipped');

      for (var i = 0; i < lefts.length; i++) {
        expect(placed.contains(i) || chipCovered.contains(i), isTrue,
            reason: 'candidate $i vanished across the composed '
                'labelPlan → labelClusters → chipPlan pipeline');
      }
      // And specifically: the two candidates too tight for a label are
      // the whole point of this change, so pin them by index, not just
      // by membership in the general sweep above.
      expect(placed.contains(8), isFalse);
      expect(chipCovered.contains(8), isTrue,
          reason: '25 pt of room is not enough for a 34 pt label but is '
              'enough for an unshrunk chip; it must not vanish');
      expect(placed.contains(7), isFalse);
      expect(chipCovered.contains(7), isTrue,
          reason: '3 pt of room used to make this candidate vanish '
              'outright — chronologyChipPlan now shrinks its chip to fit '
              'instead');
      // Pin the shrink itself, not just reachability: candidate 7's slot
      // must be narrower than the 20 pt it asked for, or this is really
      // testing the ordinary unshrunk-chip path by coincidence.
      final slot7 = chipPlan.firstWhere((s) =>
          [s.cluster, ...s.extraClusters].any((ci) => clusters[ci].contains(7)));
      expect(slot7.width, lessThan(20.0),
          reason: 'candidate 7 has only 3 pt of room; its chip must be '
              'shrunk, not drawn at the full requested width');
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

    test(
        'the right-hand end folds every row except Esau, whose open-ended '
        'bar is genuinely still there', () {
      // AM 2187 is 53% of the way along a 4,098-year axis, so the last
      // tenth of it — Rome, the Gospels, Patmos — contains no CLOSED bar
      // at all. Esau is the one exception, and correctly so: his death
      // age is never stated (see OPEN_ENDED in
      // tools/build_bible_chronology.py), so `endAm()` gives him
      // spanEndAm and his bar fades out across the whole rest of the
      // axis instead of stopping — see chronology_chart.dart's `_lane`.
      final p = plan(0.9, 1.0);
      expect(named(p), 'esau', reason: 'in view: ${named(p)}');
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
      final warm = plan(0.9, 1.0, previous: cold);
      // Esau is genuinely in view on both calls (see the test above) —
      // that is not a resurrection, he never left. Every other row must
      // still be folded.
      for (var i = 0; i < warm.length; i++) {
        if (data.lifelines[i].personId == 'esau') continue;
        expect(warm[i], isFalse,
            reason: 'hysteresis must not resurrect a folded row: '
                '${data.lifelines[i].personId}');
      }
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

      // Every row folds except Esau's: his bar has no stated death (see
      // OPEN_ENDED in tools/build_bible_chronology.py), so it is still
      // genuinely in view here — faded almost to nothing, but there.
      // The other 25 fold into consecutive bands above and below his
      // row, so this sums whatever band texts are on screen rather than
      // assuming there is exactly one.
      final foldTexts = find.textContaining(' not in view').evaluate();
      final folded = foldTexts.fold<int>(
          0, (a, e) => a + int.parse((e.widget as Text).data!.split(' ')[0]));
      expect(folded, data.lifelines.length - 1,
          reason: 'fold band texts: '
              '${foldTexts.map((e) => (e.widget as Text).data).toList()}');
      expect(find.text('Esau'), findsWidgets,
          reason: 'the one row that should stay unfolded');
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

    testWidgets('the tick lane also earns rows by DEMAND, not just by '
        'what the lifelines reclaim', (tester) async {
      // At the whole-span view nothing has folded — "nothing folds at
      // whole span" is the property the test above this one already
      // relies on — so the reclaim mechanism above has nothing to give
      // the lane: whatever height it shows here is on demand alone.
      //
      // There are 13 PINNED candidates at this density; the six earliest
      // (Creation, Enoch, the Flood, Abram's birth, his leaving Haran,
      // Isaac's birth) are spread across the whole span in TIME, but at
      // fit density the whole 4,000+ year axis is squeezed into a couple
      // hundred points, so in PIXEL space their fixed-width labels
      // collide anyway. Measured directly, not assumed: with just this
      // fix reverted in the working tree, only "Creation" and "Abram is
      // born" survive that collision at one row; the other four are
      // dropped rather than shown, silence the reclaim mechanism could
      // never fix because it had nothing to reclaim at this view.
      //
      // This is a partial fix, not a claim that every pinned event is
      // now reachable at fit view: the seven pins later than Abraham
      // (from "Abraham dies" through Revelation) still get no INLINE
      // label at fit view even with this fix — the row cap the packer
      // is built to respect is exhausted by the earlier six before it
      // reaches them. They surface as a "+N" chip instead (tap to reach
      // them, same as before this fix) — including the ones right at
      // the axis edge: chronologyLabelClusters used to exclude a
      // candidate too close to the plot's edge for an unshrunk chip, so
      // that band got neither a label nor a chip. Fixed 2026-09-15 —
      // chronologyChipPlan's existing shrink/terminal-fold now reaches
      // them too; see the chronologyLabelClusters/chronologyChipPlan
      // tests above and docs/autonomous-queue.md for the item this
      // closed.
      await pumpChart(tester, size: tall);
      await wholeSpan(tester);
      final laneBox = find.byKey(const ValueKey('chronoTickLaneBox'));
      const pins = [
        'Creation',
        'Enoch is taken',
        "The Flood (Noah's 600th year)",
        'Abram is born',
        'Abram leaves Haran, aged 75',
        'Isaac is born, Abraham aged 100',
      ];
      final inLane = pins.where((n) =>
          find.descendant(of: laneBox, matching: find.text(n)).evaluate().isNotEmpty);

      expect(inLane.length, greaterThan(2),
          reason: 'more than the two that fit on the reclaim-only floor '
              'should be in the lane once it can earn rows by demand — '
              'found only: $inLane');
      expect(tester.takeException(), isNull);
    });

    testWidgets('every one of the 13 pinned ticks is reachable at '
        'whole-span (fit) view, enumerated — not inferred from the '
        'edge-cutoff fix', (tester) async {
      // The test above this one measures 6 of the 13 pins reachable as
      // inline labels and *asserts in its own comment*, without ever
      // driving it through a widget tree, that the other 7 — Abraham's
      // death through Revelation — still reach the reader via a "+N"
      // chip once row exhaustion drops their label. That is exactly the
      // kind of claim this file exists to catch: "the fold reaches them
      // too" was inferred from the 2026-09-15 edge-cutoff deletion, not
      // observed. This test checks all 13 pinned ticks the same way the
      // densest-decade test above checks its 14 — by finding each one
      // either as its own inline label, or by tapping every on-screen
      // "+N" chip in turn and scrolling its sheet.
      //
      // Re-derived directly from assets/bible_chronology.json (7 markers
      // + 93 events; `pin` defaults to true when the key is absent, which
      // is why all 7 markers count): AM 0, 987, 1656, 2008, 2083, 2108,
      // 2183, 2558, 3038, 3418, 3999, 4036, 4098 — 13 total, matching the
      // "6 + 7" arithmetic the test above already states.
      //
      // `john_patmos` (AM 4098, the span's own end) is the one worth
      // naming going in: the tick lane computes `lefts[i] = _x(t.am,
      // plotWidth) + 3`, so at AM 4098 == `spanEndAm` that is `left ==
      // plotWidth + 3` — past the right edge before the packer even
      // runs — and its only route to the reader is
      // [chronologyChipPlan]'s shrink-then-terminal-fold, exercised here
      // in a real widget tree for the first time.
      final handle = tester.ensureSemantics();
      await pumpChart(tester, size: tall);
      await wholeSpan(tester);

      const titles = [
        'Creation',
        'Enoch is taken',
        "The Flood (Noah's 600th year)",
        'Abram is born',
        'Abram leaves Haran, aged 75',
        'Isaac is born, Abraham aged 100',
        'Abraham dies, aged 175',
        'The Exodus',
        "Solomon's Temple Built",
        'Judah Falls; Temple Destroyed',
        'Birth of Jesus Christ',
        'Crucifixion of Jesus',
        'John Exiled to Patmos; Revelation Written',
      ];

      final laneBox = find.byKey(const ValueKey('chronoTickLaneBox'));
      final unreached = <String>[];

      for (final title in titles) {
        // Reachable as its own inline label — no tap needed.
        if (find
            .descendant(of: laneBox, matching: find.text(title))
            .evaluate()
            .isNotEmpty) {
          continue;
        }

        // The lane's own painted rect, recomputed every title: popping a
        // sheet rebuilds the lane, and a geometry bug in the packer could
        // in principle shift it between iterations. `tester.tap()` taps
        // wherever a widget's LAYOUT says it is, even past the lane's own
        // clip — chronology_chart.dart's `_tickLane` Stack is built with
        // `clipBehavior: Clip.hardEdge`, so a chip placed outside this
        // rect is invisible and untappable for a real finger even though
        // `tester.tap()` would still "succeed" against it. Overlap with
        // `laneRect` is what tells the two cases apart; a bare tap does
        // not. (Found by deliberately shifting `chronologyChipPlan`'s
        // terminal-fold `tailLeft` 2000pt off-plot in the tree — the tap
        // still landed and the sheet still opened, with nothing here to
        // say the chip a user would see was nowhere near that tap.)
        final laneRect = tester.getRect(laneBox);

        var found = false;
        // Keyed by the chip's own `ValueKey('chronoClusterChip_$am')`, not
        // by widget identity: popping a sheet rebuilds the lane, so a
        // `Widget` captured before the tap is a stale instance the tree
        // no longer contains by the time the next chip is tapped.
        final chipKeys = find
            .descendant(
              of: laneBox,
              matching: find.bySemanticsLabel(RegExp(r'^\+\d+$')),
            )
            .evaluate()
            .map((e) => e.findAncestorWidgetOfExactType<Positioned>()?.key)
            .whereType<Key>()
            .toList();
        for (final chipKey in chipKeys) {
          final chipFinder = find.byKey(chipKey);
          if (chipFinder.evaluate().isEmpty) continue;
          if (!laneRect.overlaps(tester.getRect(chipFinder))) {
            // Painted outside the lane's own clip — not a real chip a
            // finger could reach, whatever `tester.tap()` would do to it.
            continue;
          }
          await tester.tap(chipFinder, warnIfMissed: false);
          await tester.pumpAndSettle();
          final sheet = find.byType(BottomSheet);
          if (sheet.evaluate().isNotEmpty) {
            // A bucket of one skips the cluster list and opens the same
            // detail sheet an inline label would — still a BottomSheet,
            // still worth scrolling before concluding either way, since
            // its own `ListView(shrinkWrap: true)` is lazy the same way
            // the cluster sheet's is.
            try {
              await tester.scrollUntilVisible(
                find.descendant(of: sheet, matching: find.text(title)),
                60,
                scrollable:
                    find.descendant(of: sheet, matching: find.byType(Scrollable))
                        .first,
              );
              found = true;
            } catch (_) {
              found = find
                  .descendant(of: sheet, matching: find.text(title))
                  .evaluate()
                  .isNotEmpty;
            }
            Navigator.of(tester.element(sheet)).pop();
            await tester.pumpAndSettle();
          }
          if (found) break;
        }
        if (!found) unreached.add(title);
      }

      expect(unreached, isEmpty,
          reason: 'pinned ticks with no inline label and not named in '
              'any on-screen chip\'s sheet: $unreached');
      expect(tester.takeException(), isNull);
      handle.dispose();
    });

    testWidgets('every tick in the whole corpus, not just the 13 pins, '
        'measured for whole-span reachability in one pass', (tester) async {
      // The test above only ever walked the 13 `pin: true` ticks. This
      // one widens that to all `data.allTicks` — 7 markers + 93 events,
      // re-derived at run time below rather than copied as a literal,
      // so a future `tools/build_bible_chronology.py` regeneration can't
      // silently stop being covered.
      //
      // It is a DIFFERENT shape of test than the one above it, not a
      // superset loop over the same titles: walking every on-screen
      // label and chip once, and recording everything each names, is
      // O(labels + chips) instead of O(titles x chips) — the loop above
      // taps every visible chip again for each of the 13 titles it is
      // still hunting for. That is fine at 13; it would not be at 100.
      //
      // `_tickCandidates()` in chronology_chart.dart states outright
      // that this is expected to come back short: "fit-to-width prints
      // only the pinned events, because at 0.06 pt per year the lane
      // has room for about four labels" — `_atFit: return t.pin;`. So
      // the assertion below is not `unreached.isEmpty`; it is that the
      // reached set is EXACTLY the pinned titles, and the unreached set
      // is EXACTLY the unpinned ones — an honest measurement of a
      // documented density cutoff, not a bug. A reader who wants the
      // other 87 has to zoom in at least one step first, which is a
      // product question for `queue:13341`, not a defect this test
      // should paper over by relaxing to `isEmpty` or dropping the
      // exactness.
      final handle = tester.ensureSemantics();
      await pumpChart(tester, size: tall);
      await wholeSpan(tester);

      final allTicks = data.allTicks;
      final allTitles = allTicks.map((t) => t.titleEn).toSet();
      expect(allTitles, hasLength(allTicks.length),
          reason: 'two ticks share a title — this test tells them apart '
              'by text, so a collision here would silently under-count');
      final pinnedTitles =
          allTicks.where((t) => t.pin).map((t) => t.titleEn).toSet();

      final laneBox = find.byKey(const ValueKey('chronoTickLaneBox'));
      final reached = <String>{};

      // One sweep: every Text anywhere in [scope] whose data names a
      // real tick counts as reached from there. Chip text reads "+N"
      // and sheet furniture (year, era, "N events...") reads as
      // something else, so neither can collide with a title in
      // `allTitles` (checked unique above) and false-positive `reached`.
      void harvest(Finder scope) {
        for (final e
            in find.descendant(of: scope, matching: find.byType(Text)).evaluate()) {
          final t = (e.widget as Text).data;
          if (t != null && allTitles.contains(t)) reached.add(t);
        }
      }

      harvest(laneBox);

      final chipKeys = find
          .descendant(
            of: laneBox,
            matching: find.bySemanticsLabel(RegExp(r'^\+\d+$')),
          )
          .evaluate()
          .map((e) => e.findAncestorWidgetOfExactType<Positioned>()?.key)
          .whereType<Key>()
          .toList();

      for (final chipKey in chipKeys) {
        final chipFinder = find.byKey(chipKey);
        if (chipFinder.evaluate().isEmpty) continue;
        // Recomputed per chip, not hoisted: popping the previous chip's
        // sheet rebuilds the lane (see the pinned test's own comment on
        // this), and this is the rect a tap on the NEXT chip is judged
        // against.
        final laneRect = tester.getRect(laneBox);
        if (!laneRect.overlaps(tester.getRect(chipFinder))) continue;
        await tester.tap(chipFinder, warnIfMissed: false);
        await tester.pumpAndSettle();
        final sheet = find.byType(BottomSheet);
        if (sheet.evaluate().isNotEmpty) {
          harvest(sheet);
          // A cluster sheet's `ListView(shrinkWrap: true, children: [...])`
          // still only builds what its Sliver has laid out — offscreen
          // members of a large bucket are not Elements yet at the top
          // scroll position. No bucket in this corpus is anywhere near
          // tall enough to need more than start/middle/end, but taking
          // all three is cheap insurance against the day one is.
          final scrollables = find
              .descendant(of: sheet, matching: find.byType(Scrollable))
              .evaluate()
              .toList();
          if (scrollables.isNotEmpty) {
            final state = tester
                .state<ScrollableState>(find.byWidget(scrollables.first.widget));
            final max = state.position.maxScrollExtent;
            if (max > 0) {
              for (final frac in [0.5, 1.0]) {
                state.position.jumpTo(max * frac);
                await tester.pumpAndSettle();
                harvest(sheet);
              }
            }
          }
          Navigator.of(tester.element(sheet)).pop();
          await tester.pumpAndSettle();
        }
      }

      final unreached = allTitles.difference(reached);

      expect(reached, unorderedEquals(pinnedTitles),
          reason: 'reached should be exactly the ${pinnedTitles.length} '
              'pinned titles, no more and no fewer — got $reached');
      expect(unreached, unorderedEquals(allTitles.difference(pinnedTitles)),
          reason: 'unreached should be exactly the '
              '${allTitles.length - pinnedTitles.length} unpinned titles — '
              'got $unreached');
      expect(tester.takeException(), isNull);
      handle.dispose();
    });

    testWidgets('the position-based route: a raw tap at each tick\'s own '
        'x, away from any label or chip, is measured for whether it '
        'reaches that tick\'s own sheet', (tester) async {
      // The test above measures the CONTENT-based route — an on-screen
      // label or chip, found by its text and tapped. This one measures
      // the other route `onTapDown` offers, named but left unmeasured by
      // this item's previous slice: a tap on bare lane, at a tick's own
      // x, that never lands inside any label's or chip's hit rect at
      // all. `onTapDown` falls back to `for (final t in ticks) { … if
      // (dx <= bestDx) best = t; }` over the WHOLE unfiltered
      // `data.allTicks`, nearest-in-x within 14 pt, with `<=` so the
      // LAST tick in list order wins any tie. That is a concrete way for
      // this to come back wrong: two ticks close enough in x — same AM,
      // or merely within 14 pt of each other at fit view's ~0.06 pt per
      // year here — and the earlier one's own mark can never open its
      // own sheet no matter how precisely a reader taps it.
      //
      // The tap's y is chosen fresh every iteration, never hoisted: the
      // pinned test above this one already warns that popping a sheet
      // rebuilds the lane, and rebuilding can change how many label rows
      // it reserves (a newly selected tick can belong to a fuller or
      // emptier row-packing than the last one), which moves the lane's
      // own top on screen and the boundary between its label rows and
      // its bare margin below them. A `laneRect` read once before the
      // loop went stale after exactly that — a reproducible run of this
      // test with a hoisted rect kept opening "Abram leaves Haran, aged
      // 75" for every tap after the lane shifted, because the stale y
      // had drifted from the reserved bottom margin into that tick's own
      // label row. `_chipBandHeight + labelRows * pitch` is what
      // `labelHits`/`chipHits` occupy (built in `_tickLane` above); the
      // lane's own height always reserves `+7` beyond that (see
      // `_tickLaneHeight` / `_tickLaneMaxHeight`), so `height - 2`,
      // read fresh each time, is always below both — checked below on
      // the live rect, not assumed.
      final handle = tester.ensureSemantics();
      await pumpChart(tester, size: tall);
      await wholeSpan(tester);

      final allTicks = data.allTicks;
      final span = (data.spanEndAm - data.spanStartAm).abs().toDouble();
      final plotWidth = plotWidthOf(tester);
      double xOf(int am) => (am - data.spanStartAm) / span * plotWidth;

      final laneBox = find.byKey(const ValueKey('chronoTickLaneBox'));

      final reached = <String>{};
      final unreached = <String>{};

      for (final t in allTicks) {
        final liveRect = tester.getRect(laneBox);
        final bareDy = liveRect.height - 2;

        // No drawn label may reach into the row this tap targets, at
        // the lane's CURRENT layout — checked fresh, since the layout
        // just shifted at least once in a real run (see above).
        for (final e in find
            .descendant(of: laneBox, matching: find.byType(Text))
            .evaluate()) {
          final r = tester.getRect(find.byWidget(e.widget));
          expect(r.top - liveRect.top, lessThan(bareDy),
              reason: 'a label reaches into the row this test relies on '
                  'being bare, for the tap aimed at "${t.titleEn}"');
        }

        final dx = xOf(t.am).clamp(0.0, plotWidth);
        await tester.tapAt(Offset(liveRect.left + dx, liveRect.top + bareDy));
        await tester.pumpAndSettle();

        var found = false;
        final sheet = find.byType(BottomSheet);
        if (sheet.evaluate().isNotEmpty) {
          final title = t.localizedTitle('en');
          try {
            await tester.scrollUntilVisible(
              find.descendant(of: sheet, matching: find.text(title)),
              60,
              scrollable: find
                  .descendant(of: sheet, matching: find.byType(Scrollable))
                  .first,
            );
            found = true;
          } catch (_) {
            found = find
                .descendant(of: sheet, matching: find.text(title))
                .evaluate()
                .isNotEmpty;
          }
          Navigator.of(tester.element(sheet)).pop();
          await tester.pumpAndSettle();
        }
        (found ? reached : unreached).add(t.titleEn);
      }

      // Independently re-derive the tie-break outcome the production
      // code computes, so the assertion below states WHY a title landed
      // where it did rather than pinning an opaque list. Same rule as
      // `onTapDown`: nearest in x within 14 pt, `<=` so the last tick in
      // `allTicks` order at a given x wins — but `best` no longer opens
      // only its own sheet. It now opens a cluster sheet naming every
      // tick within 0.5 pt of its own x (see `onTapDown`'s co-located
      // grouping), so a tap at `t`'s own x reaches `t` whenever `t` is
      // in THAT group, whether or not `t` itself won the tie.
      final expectedReached = <String>{};
      final expectedUnreached = <String>{};
      for (final t in allTicks) {
        final myX = xOf(t.am);
        ChronologyMarker? best;
        var bestDx = 14.0;
        for (final other in allTicks) {
          final dx = (xOf(other.am) - myX).abs();
          if (dx <= bestDx) {
            bestDx = dx;
            best = other;
          }
        }
        final coLocatesWithT =
            best != null && (myX - xOf(best.am)).abs() < 0.5;
        (coLocatesWithT ? expectedReached : expectedUnreached).add(t.titleEn);
      }

      // One measured exception to that pure math, checked here rather
      // than silently absorbed into a looser assertion: the corpus's own
      // last tick sits at `am == spanEndAm`, so its computed x is
      // exactly `plotWidth` — the lane's own right edge, where Flutter's
      // own right-exclusive `Rect`/`Size.contains` drops the tap before
      // `onTapDown` ever sees it, not a tie or an off-by-one in this
      // widget's `<=` or its co-located grouping. No real tap lands on
      // that exact sub-pixel float; the same tick already has a working
      // CONTENT-based route too (it is one of the pinned titles the test
      // above this one confirms reachable through
      // `chronologyChipPlan`'s terminal-fold). So: documented here, no
      // lib change, and moved from the pure-math prediction into
      // `expectedUnreached` rather than left to fail the assertion below.
      // With the co-located cluster-sheet fallback added by this slice,
      // that one right-edge tick is now the ONLY gap: measured at 99 of
      // 100 reached, up from 80 of 100 before this change.
      final lastTick =
          allTicks.firstWhere((t) => t.am == data.spanEndAm).titleEn;
      expect(expectedReached.remove(lastTick), isTrue,
          reason: 'the pure math should have predicted the corpus\'s own '
              'last tick reaches itself; if this fails the corpus shape '
              'changed and this exception needs re-deriving');
      expectedUnreached.add(lastTick);

      expect(reached, unorderedEquals(expectedReached),
          reason: 'measured reached set does not match the independently '
              're-derived nearest-in-x-within-14pt tie-break — got '
              '$reached, expected $expectedReached');
      expect(unreached, unorderedEquals(expectedUnreached),
          reason: 'measured unreached set does not match the '
              'independently re-derived tie-break — got $unreached, '
              'expected $expectedUnreached');
      expect(tester.takeException(), isNull);
      handle.dispose();
    });

    testWidgets('the bare-lane route and the chip route: does a tap under '
        'a chip reach the same events the chip itself names?', (tester) async {
      // `chronology_chart.dart:1979` groups the bare-lane fallback by
      // `< 0.5` of x — a sub-pixel epsilon that only ever catches an
      // EXACT same-x tie. `chronology_chart.dart:1727`'s chip route
      // groups by `_scaler.scale(20)` — two orders of magnitude wider,
      // and (per `chronologyLabelClusters`'s own doc at :3025-3033) it
      // also chains together nearby SINGLETON drops that share no year
      // at all. Nobody has checked whether a reader who misses the chip
      // itself and lands on the bare lane directly under it reaches the
      // same set the chip's own sheet would have named.
      //
      // AM 4029-4038 (the densest decade — re-derived below, not copied
      // from the note this file already quotes at the test above) has
      // both kinds of chip in view at this viewport: the AM 4036 "+6"
      // same-year tie, and merged runs of the four AM 4030-4033
      // row-exhaustion singles the test above this one exercises.
      final handle = tester.ensureSemantics();
      await pumpChart(tester, size: const Size(402, 874));
      await viewAt(tester, 4036, years: 100);

      // Re-derive the densest-decade fact fresh, per this item's own
      // "re-derive from the asset" instruction — the docstring above
      // only carries it forward as prose.
      final raw = jsonDecode(
        File('assets/bible_chronology.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final allAms = <int>[
        for (final e in raw['events'] as List) e['am'] as int,
        for (final m in raw['markers'] as List) m['am'] as int,
      ]..sort();
      var bestStart = allAms.first;
      var bestCount = 0;
      for (final start in allAms) {
        final count =
            allAms.where((a) => a >= start && a < start + 10).length;
        if (count > bestCount) {
          bestCount = count;
          bestStart = start;
        }
      }
      expect(bestStart, 4029,
          reason: 'the densest 10-year window has moved — this test\'s '
              'viewport and expectations need re-deriving, not patching');
      expect(bestCount, 14,
          reason: 'the densest decade\'s event count has moved — '
              're-derive rather than patch the number');

      final allTicks = data.allTicks;
      final allTitles = allTicks.map((t) => t.titleEn).toSet();
      expect(allTitles, hasLength(allTicks.length),
          reason: 'two ticks share a title — the harvest below tells '
              'them apart by text, so a collision would under-count');

      final laneBox = find.byKey(const ValueKey('chronoTickLaneBox'));

      Future<Set<String>> harvestSheet() async {
        final sheet = find.byType(BottomSheet);
        if (sheet.evaluate().isEmpty) return {};
        final found = <String>{};
        void sweep() {
          for (final e in find
              .descendant(of: sheet, matching: find.byType(Text))
              .evaluate()) {
            final t = (e.widget as Text).data;
            if (t != null && allTitles.contains(t)) found.add(t);
          }
        }

        sweep();
        final scrollables = find
            .descendant(of: sheet, matching: find.byType(Scrollable))
            .evaluate()
            .toList();
        if (scrollables.isNotEmpty) {
          final state = tester
              .state<ScrollableState>(find.byWidget(scrollables.first.widget));
          final max = state.position.maxScrollExtent;
          if (max > 0) {
            for (final frac in [0.5, 1.0]) {
              state.position.jumpTo(max * frac);
              await tester.pumpAndSettle();
              sweep();
            }
          }
        }
        return found;
      }

      // Keyed by the chip's own `ValueKey('chronoClusterChip_$am')` —
      // popping a sheet rebuilds the lane (see the pinned-reachability
      // test's own note on this), so a `Widget` captured up front would
      // be a stale instance by the second chip.
      // Paired in the same pass, not re-derived from the key afterwards:
      // `bySemanticsLabel` matches the `Semantics` element itself, so its
      // own `properties.label` is read right here rather than by walking
      // back up from the `Positioned` key, which is the chip's PARENT,
      // not its ancestor — `find.ancestor` from the key would search the
      // wrong direction entirely.
      // `Stack` builds every chip across the WHOLE corpus regardless of
      // horizontal scroll position — only paint is clipped — so without
      // an on-screen filter this finder also picks up chips from other
      // crowded decades that are not actually visible at this scroll
      // offset, and a tap "at their centre" lands off the real window
      // and hits nothing. The reachability test above this one hits the
      // same trap and filters the same way.
      final laneRect = tester.getRect(laneBox);
      final chipEntries = find
          .descendant(
            of: laneBox,
            matching: find.bySemanticsLabel(RegExp(r'^\+\d+$')),
          )
          .evaluate()
          .map((e) => (
                key: e.findAncestorWidgetOfExactType<Positioned>()?.key,
                label: (e.widget as Semantics).properties.label!,
              ))
          .where((r) =>
              r.key != null &&
              laneRect.overlaps(tester.getRect(find.byKey(r.key!))))
          .toList();
      expect(chipEntries, isNotEmpty,
          reason: 'this viewport should still be crowded enough to fold '
              'some ticks into a chip — if not, the viewport has drifted '
              'and this test is not exercising the chip route at all');

      // Per-chip: what its own sheet names, versus what a tap on bare
      // lane directly below its on-screen x reaches. Recorded per chip
      // (not pooled) so a disagreement names WHICH chip disagrees.
      final perChip = <String, ({Set<String> chip, Set<String> bare})>{};

      for (final entry in chipEntries) {
        final chipKey = entry.key!;
        final chipFinder = find.byKey(chipKey);
        if (chipFinder.evaluate().isEmpty) continue;
        // `chronoClusterChip_$am` names the FIRST candidate the bucket
        // was built from, which can repeat across chips that merged
        // ("+2" appears three times in this decade) — the semantics
        // label alone is not unique either, so key by both together.
        final id = '${(chipKey as ValueKey).value}_${entry.label}';

        final chipDx = tester.getCenter(chipFinder).dx;

        await tester.tap(chipFinder, warnIfMissed: false);
        await tester.pumpAndSettle();
        final chipTitles = await harvestSheet();
        var sheet = find.byType(BottomSheet);
        if (sheet.evaluate().isNotEmpty) {
          Navigator.of(tester.element(sheet)).pop();
          await tester.pumpAndSettle();
        }

        // Fresh rect: popping the sheet above can change how many label
        // rows the lane reserves (a newly `_selectedTickId` can shift
        // row-packing), which moves the boundary between the label rows
        // and the bare margin below them — the position-based-route
        // test above this one hit exactly this staleness.
        final liveLaneRect = tester.getRect(laneBox);
        final bareDy = liveLaneRect.height - 2;
        await tester.tapAt(Offset(chipDx, liveLaneRect.top + bareDy));
        await tester.pumpAndSettle();
        final bareTitles = await harvestSheet();
        sheet = find.byType(BottomSheet);
        if (sheet.evaluate().isNotEmpty) {
          Navigator.of(tester.element(sheet)).pop();
          await tester.pumpAndSettle();
        }

        perChip[id] = (chip: chipTitles, bare: bareTitles);
      }

      // The measured relationship is NOT the hypothesised proper subset
      // ("bare-lane reaches fewer of the SAME events"). Measured on the
      // four on-screen chips this decade actually produces:
      //
      //   chronoClusterChip_4029_+2: chip {Baptism of Jesus, Wilderness
      //     Temptation}, bare {Feeding the 5000}
      //   chronoClusterChip_4030_+4: chip {Calling of the Twelve, Sermon
      //     on the Mount, Feeding the 5000, Transfiguration}, bare
      //     {Stephen Martyred, Paul's Conversion on Damascus Road}
      //   chronoClusterChip_4036_+6: chip {6 Passion-week/Pentecost
      //     events}, bare {} (nothing within 14pt at that x)
      //   chronoClusterChip_4038_+2: chip {Stephen Martyred, Paul's
      //     Conversion on Damascus Road}, bare {Paul's First Missionary
      //     Journey}
      //
      // Every non-empty `bare` set names an event ABSENT from its own
      // chip's bucket — in the 4038 case, one from a wholly different
      // decade. `chronologyChipPlan` (the one-row packer chipLefts feed)
      // nudges each chip's drawn `left` right only far enough to clear
      // its own left neighbour, with no requirement that the result
      // stay near any of its bucket's own tick x's — so "the same x" a
      // reader sees the chip drawn at is frequently not within 0.5pt,
      // nor even within the bare fallback's 14pt search radius, of the
      // ticks the chip actually represents. The two routes are not one
      // strict and one loose version of the same grouping; they can
      // disagree about which DECADE they are even naming.
      //
      // So the assertion pinned here is the intersection, not a subset:
      // no chip in this decade's `bare` set shares even one title with
      // its own `chip` set.
      final overlapping = <String>[];
      for (final entry in perChip.entries) {
        final shared = entry.value.bare.intersection(entry.value.chip);
        if (shared.isNotEmpty) {
          overlapping.add('${entry.key}: bare and chip both name $shared');
        }
      }
      expect(overlapping, isEmpty,
          reason: 'a bare-lane tap under a chip named something the '
              'chip itself also names — the routes have converged for '
              'at least this chip, which is worth knowing since the '
              'four chips measured when this test was written shared '
              'nothing at all:\n${overlapping.join('\n')}');

      // Teeth for the claim above: at least one measured chip's bare
      // set is non-empty and therefore genuinely disjoint (not just
      // vacuously so, the way the AM 4036 tie's empty bare set is). If
      // this goes empty, the finding above has stopped reproducing and
      // this test should be re-derived, not weakened to keep passing.
      final nonEmptyDisjoint = perChip.entries
          .where((e) => e.value.bare.isNotEmpty)
          .map((e) => e.key)
          .toSet();
      expect(nonEmptyDisjoint, isNotEmpty,
          reason: 'expected at least one chip where the bare-lane tap '
              'lands on SOME real event (just not one of the chip\'s '
              'own) — if every bare set is empty the finding this test '
              'pins has changed shape and needs re-measuring');
      expect(tester.takeException(), isNull);
      handle.dispose();
    });

    testWidgets('characterizing chronologyChipPlan drift: how far a '
        'packed chip lands from its own bucket\'s true tick x, swept '
        'across the real corpus', (tester) async {
      // queue:15260 asks whether capping this drift is a cheap fix or a
      // chart-wide redesign, but the only evidence on file is the ONE
      // anecdote the test above this one measured, at ONE viewport
      // (AM 4029-4038). That is not enough to make the product call the
      // queue item itself says is not this loop's to make. This test
      // measures the distribution instead of guessing at a threshold —
      // no lib change, no fix, just the number the question needs.
      final handle = tester.ensureSemantics();
      await pumpChart(tester, size: const Size(402, 874));

      final allTicks = data.allTicks;
      final allTitles = allTicks.map((t) => t.titleEn).toSet();
      expect(allTitles, hasLength(allTicks.length),
          reason: 'two ticks share a title — the harvest below tells '
              'them apart by text, so a collision would under-count');
      final amByTitle = {for (final t in allTicks) t.titleEn: t.am};

      final laneBox = find.byKey(const ValueKey('chronoTickLaneBox'));

      Future<Set<String>> harvestSheet() async {
        final sheet = find.byType(BottomSheet);
        if (sheet.evaluate().isEmpty) return {};
        final found = <String>{};
        void sweep() {
          for (final e in find
              .descendant(of: sheet, matching: find.byType(Text))
              .evaluate()) {
            final t = (e.widget as Text).data;
            if (t != null && allTitles.contains(t)) found.add(t);
          }
        }

        sweep();
        final scrollables = find
            .descendant(of: sheet, matching: find.byType(Scrollable))
            .evaluate()
            .toList();
        if (scrollables.isNotEmpty) {
          final state = tester
              .state<ScrollableState>(find.byWidget(scrollables.first.widget));
          final max = state.position.maxScrollExtent;
          if (max > 0) {
            for (final frac in [0.5, 1.0]) {
              state.position.jumpTo(max * frac);
              await tester.pumpAndSettle();
              sweep();
            }
          }
        }
        return found;
      }

      // Four viewports, per this item's acceptance criteria: fit view,
      // the known-densest decade (re-derived, not copied, by the test
      // above this one), and two more spread across the span so the
      // measurement is not just that one decade's anecdote again.
      final viewports = <(String, Future<void> Function())>[
        ('fit', () => wholeSpan(tester)),
        ('AM4036/100y', () => viewAt(tester, 4036, years: 100)),
        ('AM2558/200y', () => viewAt(tester, 2558, years: 200)),
        ('AM2200/400y', () => viewAt(tester, 2200, years: 400)),
        ('AM4098/30y', () => viewAt(tester, 4098, years: 30)),
      ];

      // Recorded per chip, not pooled, so a re-derivation can see WHICH
      // viewport/chip produced the worst case, the same discipline the
      // test above this one used for its per-chip disagreement table.
      final ordinaryDrifts = <double>[];
      final foldDrifts = <double>[];
      final log = <String>[];

      for (final vp in viewports) {
        await vp.$2();
        final plotWidth = plotWidthOf(tester);
        final span = (data.spanEndAm - data.spanStartAm).abs().toDouble();
        double xOf(int am) => (am - data.spanStartAm) / span * plotWidth;

        final laneRect = tester.getRect(laneBox);
        // Same on-screen filter the 5b43d009 slice above uses: `Stack`
        // builds every chip across the whole corpus regardless of
        // scroll position, so without it this finder also picks up
        // chips from decades that are not actually on screen at this
        // viewport.
        final chipEntries = find
            .descendant(
              of: laneBox,
              matching: find.bySemanticsLabel(RegExp(r'^\+\d+$')),
            )
            .evaluate()
            .map((e) => (
                  key: e.findAncestorWidgetOfExactType<Positioned>()?.key,
                  label: (e.widget as Semantics).properties.label!,
                ))
            .where((r) =>
                r.key != null &&
                laneRect.overlaps(tester.getRect(find.byKey(r.key!))))
            .toList();

        for (final entry in chipEntries) {
          final chipKey = entry.key!;
          final chipFinder = find.byKey(chipKey);
          if (chipFinder.evaluate().isEmpty) continue;
          final chipRect = tester.getRect(chipFinder);
          final chipCentre = chipRect.center.dx;

          await tester.tap(chipFinder, warnIfMissed: false);
          await tester.pumpAndSettle();
          final titles = await harvestSheet();
          final sheet = find.byType(BottomSheet);
          if (sheet.evaluate().isNotEmpty) {
            Navigator.of(tester.element(sheet)).pop();
            await tester.pumpAndSettle();
          }
          if (titles.isEmpty) continue;

          // The chip's own bucket, established by the tap route — the
          // test above this one confirms the CHIP route (unlike the
          // bare-lane one) always reaches exactly the events its own
          // sheet names, so the harvested titles are the bucket, not an
          // approximation of it.
          var nearest = double.infinity;
          for (final title in titles) {
            final am = amByTitle[title];
            if (am == null) continue;
            // Same construction `_tickLane` uses for `chipLefts`:
            // `lefts[i] = _x(t.am, plotWidth) + 3`
            // (chronology_chart.dart:1695) — this is each member's own,
            // un-packed x, before `chronologyChipPlan` ever nudges it.
            final tickX = laneRect.left + xOf(am) + 3;
            final d = (chipCentre - tickX).abs();
            if (d < nearest) nearest = d;
          }
          if (!nearest.isFinite) continue;

          // A fold chip abandons its own x on purpose:
          // `chronologyChipPlan`'s terminal-fold branch seats it at
          // `tailLeft = plotWidth - tailWidth`
          // (chronology_chart.dart:3198), so its right edge sits at the
          // plot's own right edge — no ordinary packed chip's width
          // lands there except by coincidence. That is the discriminator
          // used here, not a re-derivation of the packer's internal
          // cluster/extraClusters split, which is private to the widget.
          final plotRightScreenX = laneRect.left + plotWidth;
          final isFold = (chipRect.right - plotRightScreenX).abs() < 1.0;

          (isFold ? foldDrifts : ordinaryDrifts).add(nearest);
          log.add('${vp.$1} ${(chipKey as ValueKey).value} '
              '${isFold ? "FOLD" : "ordinary"} '
              'drift=${nearest.toStringAsFixed(1)}pt');
        }
      }

      expect(ordinaryDrifts, isNotEmpty,
          reason: 'no ordinary packed chip was measured at any of the '
              'four viewports — the viewport list has drifted from what '
              'actually produces chips; re-derive rather than let this '
              'pass vacuously. Log so far:\n${log.join('\n')}');

      const bareLaneSearchRadius = 14.0;
      final overBareRadius =
          ordinaryDrifts.where((d) => d > bareLaneSearchRadius).length;

      final maxOrdinary = ordinaryDrifts.reduce((a, b) => a > b ? a : b);
      final maxFold =
          foldDrifts.isEmpty ? 0.0 : foldDrifts.reduce((a, b) => a > b ? a : b);

      // Measured at HEAD (`82245b2c` + this slice), 402x874, 4 viewports:
      // see the queue write-up this commit also makes for the full
      // per-chip log and the counts against the 14pt bare-lane radius.
      // Pinned in the ratchet style this repo already uses
      // (`audit_strongs_tagging.py`'s PINNED, `strongs_alignment_test
      // .dart`'s singleton-pair count) — a number that moves when
      // behaviour moves, not an invariant true by construction.
      expect(ordinaryDrifts.length, greaterThanOrEqualTo(4),
          reason: 'fewer on-screen ordinary chips than the four viewports '
              'used to produce — the measurement has gone thin. Log:\n'
              '${log.join('\n')}');
      expect(maxOrdinary, closeTo(_pinnedMaxOrdinaryChipDrift, 0.5),
          reason: 'the worst ordinary-chip drift measured across the '
              'four viewports moved from the pinned '
              '$_pinnedMaxOrdinaryChipDrift — re-derive the pin (this is '
              'a characterization, not an invariant), and update the '
              'queue write-up this test\'s commit made. Full log:\n'
              '${log.join('\n')}');
      expect(overBareRadius, _pinnedOverBareLaneRadiusCount,
          reason: 'the count of ordinary chips drifting past the '
              '14pt bare-lane search radius moved from the pinned '
              '$_pinnedOverBareLaneRadiusCount — re-derive, and update '
              'the queue write-up. Full log:\n${log.join('\n')}');
      if (foldDrifts.isNotEmpty) {
        expect(maxFold, closeTo(_pinnedMaxFoldChipDrift, 0.5),
            reason: 'the worst fold-chip drift moved from the pinned '
                '$_pinnedMaxFoldChipDrift — re-derive. Full log:\n'
                '${log.join('\n')}');
      }

      expect(tester.takeException(), isNull);
      handle.dispose();
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
      // Esau's open-ended bar (see OPEN_ENDED) is genuinely in view
      // here, splitting the other 25 rows' fold into bands above and
      // below his own unfolded row. Tap the LARGER one — that is the
      // one that actually holds Adam (adam..isaac, 22 rows), not
      // whichever band happens to be found first.
      final foldTexts = find
          .textContaining(' not in view')
          .evaluate()
          .map((e) => (e.widget as Text).data!)
          .toList();
      expect(foldTexts, isNotEmpty);
      final target = foldTexts.reduce((a, b) =>
          int.parse(a.split(' ')[0]) >= int.parse(b.split(' ')[0]) ? a : b);

      await tester.tap(find.text(target));
      await tester.pumpAndSettle();

      // The way back is the same mechanism a "Jump to" chip uses: it
      // scrolls the plot to where those bars are, and they unfold.
      expect(find.text(target), findsNothing);
      expect(find.text('Adam'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the narrow 402 pt phone survives the fold, at both ends',
        (tester) async {
      await pumpChart(tester, locale: 'zh-Hans', size: const Size(402, 900));
      await viewAt(tester, data.spanEndAm, years: 400);
      // Esau's open-ended bar (see OPEN_ENDED) is genuinely in view at
      // this end, splitting the rest of the fold into two bands — one
      // above his row, one below — rather than the single band there
      // used to be, so this only checks that folding happened at all.
      expect(find.textContaining('在视图外'), findsWidgets);
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
