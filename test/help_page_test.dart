/// The Help page, mounted — 2026-09-18.
///
/// `help_catalog_test.dart` pins the words and the search. This pins the
/// page: that it reaches the screen in Chinese (the default reader's
/// locale), that a search opens its answers rather than listing titles,
/// and that the gestures lead on a phone.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yahwehs_words/models/app_settings.dart';
import 'package:yahwehs_words/pages/help_page.dart';
import 'package:yahwehs_words/utils/help_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpHelp(WidgetTester t, {String? query}) async {
    t.view.physicalSize = const Size(900, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ChangeNotifierProvider(
      create: (_) => AppSettings(),
      child: MaterialApp(home: HelpPage(initialQuery: query)),
    ));
    await t.pumpAndSettle();
  }

  testWidgets('the first sections are on the page, and every chip',
      (t) async {
    await pumpHelp(t);
    for (final s in HelpSection.values) {
      // The chip row names every section; the list below is lazy, so
      // only the chips can be asserted for all of them.
      expect(find.text(kHelpSectionNames[s]!.hans), findsWidgets,
          reason: s.name);
    }
    expect(find.text('雅伟之言是什么'), findsOneWidget);
  });

  testWidgets('a search opens its answers rather than listing titles',
      (t) async {
    await pumpHelp(t, query: '分屏');
    expect(find.text('分屏阅读：两个译本并排'), findsOneWidget);
    // The body, not only the title.
    expect(find.textContaining('两个阅读栏完全独立'), findsOneWidget);
    expect(find.text('带我去'), findsNothing,
        reason: 'split view has no page of its own to open');
  });

  testWidgets('a topic with a door offers it', (t) async {
    await pumpHelp(t, query: '同步');
    expect(find.text('带我去'), findsWidgets);
  });

  testWidgets('a projection key is found by what it does', (t) async {
    await pumpHelp(t, query: '黑屏');
    expect(find.text('黑屏 / 恢复'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
  });
}
