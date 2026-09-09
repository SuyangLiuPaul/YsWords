// Press share, choose link or image. Each tile runs exactly its own
// callback, after the sheet has closed; dismissing runs neither.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/widgets/share_chooser_sheet.dart';

void main() {
  Future<void> open(WidgetTester tester, {String locale = 'zh-Hans'}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => showShareChooser(
              ctx,
              locale: locale,
              menuScale: 1,
              onLink: () {},
              onImage: () {},
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('offers exactly a link tile and an image tile, in Chinese',
      (tester) async {
    await open(tester);
    expect(find.text('分享链接'), findsOneWidget);
    expect(find.text('分享图片'), findsOneWidget);
    expect(find.byIcon(Icons.link_rounded), findsOneWidget);
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    // The link tile says it COPIES — that is the surprise it defuses.
    expect(find.textContaining('复制'), findsOneWidget);
  });

  testWidgets('the link tile runs onLink only, and closes the sheet',
      (tester) async {
    var link = 0, image = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => showShareChooser(ctx,
                locale: 'en', menuScale: 1,
                onLink: () => link++, onImage: () => image++),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share link'));
    await tester.pumpAndSettle();
    expect((link, image), (1, 0));
    expect(find.text('Share link'), findsNothing, reason: 'sheet closed');
  });

  testWidgets('the image tile runs onImage only', (tester) async {
    var link = 0, image = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => showShareChooser(ctx,
                locale: 'en', menuScale: 1,
                onLink: () => link++, onImage: () => image++),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share image'));
    await tester.pumpAndSettle();
    expect((link, image), (0, 1));
  });

  testWidgets('dismissing the sheet runs neither', (tester) async {
    var link = 0, image = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => showShareChooser(ctx,
                locale: 'en', menuScale: 1,
                onLink: () => link++, onImage: () => image++),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // Tap the scrim, above the sheet.
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect((link, image), (0, 0));
  });

  test('the selection bar share button opens the chooser with both paths',
      () {
    final src = File('lib/widgets/bible_reading_pane.dart').readAsStringSync();
    final bar = src.substring(src.indexOf('class _SelectionActionBar'));
    final ourBar = bar.substring(0, bar.indexOf('\nclass '));
    final i = ourBar.indexOf('final shareBtn = IconButton(');
    expect(i, greaterThan(0));
    final btn = ourBar.substring(i, i + 500);
    expect(btn, contains('showShareChooser('));
    expect(btn, contains('onLink: onShare'));
    expect(btn, contains('onImage: onImage'));
  });
}
