import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/bible_evidence.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/pages/evidence_detail_page.dart';
import 'package:yswords/pages/evidence_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/utils/reference_parser.dart';

/// A citation the app cannot open must not be dressed as a link.
///
/// Two of the 225 evidence entries cite something outside every version
/// we ship — `cairo_genizah` cites `Ecclesiasticus (Sirach) 39:1`, which
/// is deuterocanonical, and `strabo_geography` cites the prose
/// `Various NT references`. Both went down the single-reference path,
/// which wired `onTap` unconditionally, so the card and the detail page
/// each offered a 「→ 阅读经文」 that could only answer "Couldn't parse
/// reference".
///
/// Nothing is wrong with the data: those are honest citations of things
/// that are not in the app. It was the affordance that lied, and an
/// affordance that always fails teaches a reader that the app's
/// cross-links to scripture do not work — which then discourages them
/// from following the 223 that do.
BibleEvidence _evidence(String reference) => BibleEvidence(
      id: 'test-unresolvable',
      category: 'Manuscripts',
      bibleBooks: const [],
      timeline: const {'en': '1st century'},
      discoveryDate: const {'en': '1896'},
      location: const {'en': 'Cairo'},
      scriptureReference: reference,
      images: const [],
      academicSources: const [],
      confidenceLevel: 'high',
      icon: 'scroll',
      title: const {'en': 'Unresolvable citation'},
      summary: const {'en': 'Summary.'},
      description: const {'en': 'Description.'},
      scripturalCorrelation: const {'en': 'Correlation.'},
    );

Future<void> _pump(WidgetTester tester, String reference) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(402, 874);
  final mp = MainProvider();
  mp.setVersion('kjv');
  mp.setVerses([
    for (var v = 1; v <= 31; v++)
      Verse(book: 'Genesis', chapter: 1, verse: v, text: 'v$v'),
  ]);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: mp),
        ChangeNotifierProvider(create: (_) => AppSettings()),
      ],
      child: MaterialApp(
        home: EvidenceDetailPage(evidence: _evidence(reference)),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 400));
}

/// The chip's tap target: the only `InkWell` on the page whose corner
/// radius is the chip's 8.
Finder _chipTapTargets() => find.byWidgetPredicate((w) =>
    w is InkWell &&
    w.onTap != null &&
    w.borderRadius == BorderRadius.circular(8));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Get.testMode = true;
  });

  group('the asset', () {
    test('exactly two entries cite something the app cannot open', () {
      final raw = File('assets/bible_evidence.json').readAsStringSync();
      final entries =
          (jsonDecode(raw) as Map<String, dynamic>)['evidences'] as List;
      expect(entries.length, 225);

      // Measured over the whole corpus rather than spot-checked, so an
      // import that adds a third unresolvable citation moves this number
      // instead of quietly shipping another dead affordance.
      final unresolvable = <String>[];
      for (final e in entries.cast<Map<String, dynamic>>()) {
        final ref = e['scriptureReference'] as String? ?? '';
        expect(ref.trim(), isNotEmpty,
            reason: 'every entry cites something');
        final segments = splitCitation(ref);
        final navigable = segments.any((s) => s.target != null);
        if (!navigable) unresolvable.add('${e['id']}: $ref');
      }
      expect(unresolvable, [
        'cairo_genizah: Ecclesiasticus (Sirach) 39:1',
        'strabo_geography: Various NT references',
      ]);
    });

    test('the card row and the card tap read the same resolution', () {
      // The row's underline, arrow and ink response are drawn from
      // `cardJumpTarget`, and so is the jump, so the two cannot come
      // apart.
      expect(cardJumpTarget('Ecclesiasticus (Sirach) 39:1'), isNull);
      expect(cardJumpTarget('Various NT references'), isNull);
      expect(cardJumpTarget('Genesis 1:1')!.englishBook, 'Genesis');

      // A `;` citation whose FIRST part is unresolvable still opens at
      // the part that resolves — the row stays tappable there, which is
      // the behaviour this change must not narrow.
      expect(
        cardJumpTarget('Ecclesiasticus (Sirach) 44:1; Exodus 14:21-22')!
            .englishBook,
        'Exodus',
      );
    });
  });

  test('the timeline and the family tree cite nothing unresolvable', () {
    // Those two surfaces wire their reference chips the same
    // unconditional way the evidence chip did, and are only safe
    // because their data happens to resolve. Pinning that here means a
    // future import cannot quietly hand them the same dead affordance —
    // which is the cheaper guard than defending against data that does
    // not exist.
    for (final file in const {
      'assets/bible_timeline.json': 123,
      'assets/family_tree.json': 665,
    }.entries) {
      final refs = <String>[];
      void walk(dynamic node) {
        if (node is Map) {
          node.forEach((k, v) {
            if (k == 'refs' && v is List) refs.addAll(v.cast<String>());
            walk(v);
          });
        } else if (node is List) {
          node.forEach(walk);
        }
      }

      walk(jsonDecode(File(file.key).readAsStringSync()));
      expect(refs.length, file.value, reason: file.key);
      expect(refs.where((r) => parseReference(r) == null), isEmpty,
          reason: '${file.key} cites something the reader cannot open');
    }
  });

  testWidgets('an unresolvable citation is plain text, not a link',
      (tester) async {
    addTearDown(tester.view.reset);
    await _pump(tester, 'Ecclesiasticus (Sirach) 39:1');

    // The citation is still printed — the entry cites it and the card
    // goes on saying so.
    expect(
      find.byWidgetPredicate((w) =>
          w is RichText &&
          w.text.toPlainText().contains('Ecclesiasticus (Sirach) 39:1')),
      findsWidgets,
    );
    // Pre-fix this found one, and tapping it produced only a snackbar.
    expect(_chipTapTargets(), findsNothing);
    expect(find.byIcon(Icons.arrow_forward), findsNothing,
        reason: 'the arrow promises a destination there is none of');
  });

  testWidgets('prose in the reference field is plain text too',
      (tester) async {
    addTearDown(tester.view.reset);
    await _pump(tester, 'Various NT references');

    expect(_chipTapTargets(), findsNothing);
    expect(find.byIcon(Icons.arrow_forward), findsNothing);
  });

  testWidgets('a resolvable single citation keeps its chip and its jump',
      (tester) async {
    addTearDown(tester.view.reset);
    await _pump(tester, 'Genesis 1:1');

    expect(_chipTapTargets(), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
  });
}
