import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/bible_evidence.dart';
import 'package:yswords/pages/evidence_detail_page.dart';
import 'package:yswords/providers/main_provider.dart';

/// An evidence card citing more than one passage must not run off the
/// screen.
///
/// 2026-08-11, from the phone: the Megiddo card cites 列王纪上 9:15 and
/// 列王纪上 10:26, and the reference row — icon, both references, an
/// arrow and 「阅读经文」 — was a `Row(mainAxisSize: min)` with no
/// Flexible anywhere in it. It laid out at its full intrinsic width and
/// the card simply cut it off at the right edge, so the "Read" affordance
/// was invisible and the second reference was half gone.
///
/// A single short reference is the common case and was fine, which is
/// why this survived: the defect only appears when the data has two.
BibleEvidence _evidence(String reference) => BibleEvidence(
      id: 'test-megiddo',
      category: 'Archaeology',
      bibleBooks: const ['1 Kings'],
      timeline: const {'en': '10th century BCE'},
      discoveryDate: const {'en': '1903'},
      location: const {'en': 'Tel Megiddo'},
      scriptureReference: reference,
      images: const [],
      academicSources: const ['Yadin, Y. Hazor. Random House, 1975.'],
      confidenceLevel: 'high',
      icon: 'temple',
      title: const {'en': 'Megiddo pillared buildings', 'zh-Hans': '米吉多柱厅建筑'},
      summary: const {'en': 'Two large complexes.', 'zh-Hans': '两组大型建筑群。'},
      description: const {'en': 'A longer description.', 'zh-Hans': '较长的说明。'},
      scripturalCorrelation: const {
        'en': 'The correlation text.',
        'zh-Hans': '经文对应的说明。',
      },
    );

Future<void> _pump(WidgetTester tester, String reference, Size size) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MainProvider()),
        ChangeNotifierProvider(create: (_) => AppSettings()),
      ],
      child: MaterialApp(home: EvidenceDetailPage(evidence: _evidence(reference))),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  // 375 is the narrowest phone the app supports; the report came from a
  // 402pt iPhone, so a fix that only worked at 402 would be no fix.
  const sizes = {
    '375x812': Size(375, 812),
    '402x874': Size(402, 874),
  };

  for (final entry in sizes.entries) {
    testWidgets('two references do not overflow at ${entry.key}',
        (tester) async {
      addTearDown(tester.view.reset);
      await _pump(tester, '1 Kings 9:15; 1 Kings 10:26', entry.value);

      expect(tester.takeException(), isNull);
    });

    testWidgets('a long single reference does not overflow at ${entry.key}',
        (tester) async {
      addTearDown(tester.view.reset);
      // The longest book name in the corpus, to catch the case where
      // one reference alone is wider than the card.
      await _pump(tester, '2 Thessalonians 2:13-17', entry.value);

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the reference and the Read affordance flow as one block',
      (tester) async {
    // The property that fixes the second report. A Row placed its
    // trailing children beside the whole text BLOCK, so a reference
    // long enough to wrap left 「→ 阅读经文」 at the end of line one
    // while the rest continued underneath it — nothing clipped, and
    // unreadable. They must live in a single RichText so they wrap
    // together and the affordance always follows the reference.
    //
    // 2026-08-17: this used to be asserted on a TWO-reference citation.
    // Multi-reference citations now render one chip per passage — each
    // with its own tap target and its own arrow — so the single flowing
    // paragraph is the one-reference layout, which is 204 of the 225
    // entries. See evidence_multi_reference_tap_test.dart for the other
    // 21. The sample moved again the same day: `Acts 19:11-20, 23-41`
    // was standing in for a long SINGLE citation, and the comma half of
    // that fix now splits it into two chips. `1 Corinthians 15:36-38` is
    // the longest citation in the corpus that really is one passage and
    // resolves, so it is the one that wraps down this path.
    addTearDown(tester.view.reset);
    await _pump(tester, '1 Corinthians 15:36-38', const Size(375, 812));

    final rich = find.byWidgetPredicate((w) {
      if (w is! RichText) return false;
      final plain = w.text.toPlainText();
      // Whichever locale AppSettings defaults to — the point is that
      // the label and the reference share one paragraph.
      const readLabels = ['Read', '阅读经文', '閱讀經文'];
      return plain.contains('15:36-38') && readLabels.any(plain.contains);
    });
    expect(rich, findsOneWidget,
        reason: 'the reference and the Read label must be in the '
            'same paragraph, not in sibling widgets');
  });

  testWidgets('two references give two tap targets, and neither clips',
      (tester) async {
    // The v1.4.79 report: 「那个经文其实是两个，但是按了好像只能去一个」.
    addTearDown(tester.view.reset);
    await _pump(tester, '1 Kings 9:15; 1 Kings 10:26', const Size(375, 812));

    expect(tester.takeException(), isNull);
    final chips = find.byWidgetPredicate((w) =>
        w is InkWell &&
        w.onTap != null &&
        w.borderRadius == BorderRadius.circular(8));
    expect(chips, findsNWidgets(2));
  });
}
