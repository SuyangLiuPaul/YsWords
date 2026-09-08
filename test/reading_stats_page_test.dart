// What the reading-statistics page is allowed to say.
//
// Two claims on this page can be wrong in ways the reader cannot detect,
// so both are pinned here:
//
//  1. The period. A coverage percentage with no period attached reads as
//     a lifetime figure. A reader of two years' standing seeing "1% of
//     the canon" would be told something false about themselves by an
//     app that had only been counting since Tuesday.
//  2. The absence of a streak. 打卡 is excluded from this project, and a
//     "days in a row" number is the same mechanic whatever it is called,
//     so the guard is against the shape rather than against one word.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/pages/reading_stats_page.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/services/profile_service.dart';
import 'package:yswords/services/reading_history_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpWith(WidgetTester tester, Map<String, Object> seed) async {
    SharedPreferences.setMockInitialValues(seed);
    await ProfileService.instance.init();
    ReadingHistoryService.instance.resetForTest();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => MainProvider()),
          ChangeNotifierProvider(create: (_) => AppSettings()),
        ],
        child: const MaterialApp(home: ReadingStatsPage()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
  }

  /// A record of John 3 and John 4, begun on 1 September 2026.
  Map<String, Object> seededRecord() {
    final scoped = ProfileService.instance.scopedKey;
    final begun = DateTime(2026, 9, 1, 8, 0);
    return {
      scoped(ReadingHistoryService.coverageBaseKey): jsonEncode({
        'John': [3, 4]
      }),
      scoped(ReadingHistoryService.logBaseKey): jsonEncode([
        {
          'b': 'John',
          'c': 4,
          'v': 'kjv',
          't': begun.add(const Duration(minutes: 5)).millisecondsSinceEpoch
        },
        {
          'b': 'John',
          'c': 3,
          'v': 'kjv',
          't': begun.millisecondsSinceEpoch
        },
      ]),
      scoped(ReadingHistoryService.sinceBaseKey): begun.millisecondsSinceEpoch,
    };
  }

  testWidgets('the page names the date recording began, beside the figures',
      (tester) async {
    // ProfileService.scopedKey needs a booted profile before the seed map
    // can be keyed, so the first init happens against an empty store.
    SharedPreferences.setMockInitialValues({});
    await ProfileService.instance.init();
    await pumpWith(tester, seededRecord());

    expect(find.textContaining('2026-09-01'), findsOneWidget,
        reason: 'without the period line every percentage on the page reads '
            'as a lifetime figure');
  });

  testWidgets('coverage is shown as counts as well as a percentage',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await ProfileService.instance.init();
    await pumpWith(tester, seededRecord());

    // 2 of the canon's 1,189 chapters. The raw counts sit beside the
    // percentage because "0%" alone hides whether that is 2 chapters or
    // none at all.
    expect(find.textContaining('2 / 1189'), findsOneWidget);
    expect(find.textContaining('/ 66'), findsOneWidget);
  });

  testWidgets('an empty record explains itself instead of showing zeroes',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await ProfileService.instance.init();
    await pumpWith(tester, {});

    // A wall of 0% would read as an accusation. The first thing a reader
    // sees here is what is recorded and where it goes.
    expect(find.textContaining('0 / 1189'), findsNothing);
    expect(find.byType(ListView), findsNothing);
  });

  testWidgets('nothing on the page counts consecutive days', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await ProfileService.instance.init();
    await pumpWith(tester, seededRecord());

    final rendered = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => (t.data ?? '').toLowerCase())
        .join(' ');
    for (final banned in [
      'streak',
      'in a row',
      'consecutive',
      'days running',
      '连续',
      '連續',
      '打卡',
    ]) {
      expect(rendered.contains(banned), isFalse,
          reason: 'the owner excluded 打卡 from this project — "$banned" is '
              'that mechanic under another name');
    }
  });
}
