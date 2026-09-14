// 2026-09-14 (UI/UX audit): what tapping a verse NUMBER does.
//
// The number is the smallest thing in the reading pane — `fontSize *
// 0.65`, about 11 px at the default — and it sat on top of a fallback
// that no caller reached: when `onTextTap` was null,
// `buildVerseContentSpans` copied the verse to the clipboard and raised
// a snackbar. Both widgets that show a number pass the callback, and the
// third caller suppresses the number, so the branch was dead. It was
// still worth deleting rather than leaving: a caller that forgot the
// callback would have shipped a number that silently overwrites the
// reader's clipboard while looking exactly like the text around it.
//
// So the invariant these tests hold is not a size. It is that the number
// is not a separate control at all — it does what the verse does, with
// the same feedback, in both reading modes. That is also the reason the
// 11 px target is not worth padding to 24: WCAG 2.5.8's inline exception
// covers a target sized by the line height of the text it sits in, and a
// miss here lands on the several lines of verse that carry the same
// action.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/widgets/paragraph_group_widget.dart';
import 'package:yswords/widgets/verse_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Verse v(int n) => Verse.fromJson({
        'book': '约翰福音',
        'chapter': 3,
        'verse': n,
        'text': 'verse $n text',
      });

  /// Records every platform call the tap makes, so a haptic and a
  /// clipboard write are both observable — and distinguishable.
  late List<MethodCall> platformCalls;

  setUp(() {
    platformCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      platformCalls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<MainProvider> pump(WidgetTester tester,
      {required bool paragraphMode}) async {
    final mp = MainProvider(storagePrefix: 'test');
    final verses = [v(1), v(2)];
    mp.setVerses(verses);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<MainProvider>.value(value: mp),
        ChangeNotifierProvider(create: (_) => AppSettings()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: paragraphMode
                ? ParagraphGroupWidget(group: verses, startVerseIndex: 0)
                : Column(
                    children: [
                      for (var i = 0; i < verses.length; i++)
                        VerseWidget(verse: verses[i], index: i),
                    ],
                  ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return mp;
  }

  for (final mode in [true, false]) {
    final name = mode ? 'paragraph mode' : 'verse-per-line mode';

    testWidgets('$name: tapping the number selects the verse, same as its text',
        (tester) async {
      final mp = await pump(tester, paragraphMode: mode);
      expect(mp.isSelected(v(2)), isFalse);

      // find.text('2') is the verse-number Text itself — the 11 px
      // target, not the verse body.
      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();
      expect(mp.isSelected(v(2)), isTrue,
          reason: 'tapping the verse number must do what tapping the '
              'verse does');
      expect(mp.isSelected(v(1)), isFalse,
          reason: 'and it must select THAT verse, not its neighbour');
    });

    testWidgets('$name: the number never writes to the clipboard',
        (tester) async {
      await pump(tester, paragraphMode: mode);
      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();
      expect(
        platformCalls.map((c) => c.method),
        isNot(contains('Clipboard.setData')),
        reason: 'the removed fallback copied the verse on tap. A number '
            'that looks like text must not overwrite what the reader has '
            'on their clipboard',
      );
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('$name: the tap is confirmed by a haptic', (tester) async {
      await pump(tester, paragraphMode: mode);
      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();
      // Only `verse_widget.dart` buzzed until 2026-09-14; paragraph mode
      // is the default reading mode and had none. Both go through
      // `hapticSelect()`, which lands here as HapticFeedback.vibrate.
      expect(platformCalls.map((c) => c.method), contains('HapticFeedback.vibrate'),
          reason: 'in prose there is no row to see highlight — the tap '
              'needs the tactile confirmation more here, not less');
    });
  }
}
