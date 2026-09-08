import 'package:flutter/foundation.dart'
    show FlutterMemoryAllocations, ObjectCreated, ObjectDisposed, ObjectEvent;
import 'package:flutter/gestures.dart' show TapGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yswords/services/chinese_lexicon_service.dart';
import 'package:yswords/utils/cbol_references.dart';
import 'package:yswords/widgets/cbol_reference_text.dart';
import 'package:yswords/widgets/chinese_lexicon_block.dart';

/// The one surface that renders a CBOL citation as a target rather than
/// as text.
///
/// `StrongsEntry` flattens its own fields before any widget sees them,
/// because the six places it is printed have room for one line. The
/// BDB/Thayer article is the surface that holds the raw asset and has
/// the space, so it is the one that gets links.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
        MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
      );

  /// Every span the widget put on screen, flattened.
  List<InlineSpan> spansOf(WidgetTester tester) {
    final spans = <InlineSpan>[];
    for (final t in tester.widgetList<RichText>(find.byType(RichText))) {
      t.text.visitChildren((s) {
        spans.add(s);
        return true;
      });
    }
    return spans;
  }

  group('a citation on screen is a target', () {
    testWidgets('the delimiters are gone and the reference is still there',
        (tester) async {
      await pump(
        tester,
        const CbolReferenceText(
          source: '2) 在亚设的大衮庙 (#书19:27)',
          style: TextStyle(fontSize: 14),
        ),
      );
      final printed =
          spansOf(tester).map((s) => s.toPlainText()).join();
      expect(printed, contains('书19:27'));
      expect(printed, isNot(contains('#')));
      expect(printed, isNot(contains('|')));
    });

    testWidgets('only the citation carries the recogniser, not the prose',
        (tester) async {
      await pump(
        tester,
        const CbolReferenceText(
          source: '结束, 完成 (#路 14:19-30|)',
          style: TextStyle(fontSize: 14),
        ),
      );
      final tappable = spansOf(tester)
          .whereType<TextSpan>()
          .where((s) => s.recognizer != null)
          .toList();
      expect(tappable, hasLength(1));
      expect(tappable.single.text, '路 14:19-30');
      expect(tappable.single.recognizer, isA<TapGestureRecognizer>());
      // A link the reader cannot see as one is not a link.
      expect(tappable.single.style!.decoration, TextDecoration.underline);
    });

    testWidgets('a reference the parser refuses is text, not a wrong link',
        (tester) async {
      await pump(
        tester,
        const CbolReferenceText(
          // `代` is either book of Chronicles; guessing would put the
          // reader in a book the lexicon did not name.
          source: '9) 暗利的父亲或先祖 (#代 27:18|)',
          style: TextStyle(fontSize: 14),
        ),
      );
      expect(
          spansOf(tester)
              .whereType<TextSpan>()
              .where((s) => s.recognizer != null),
          isEmpty);
      expect(spansOf(tester).map((s) => s.toPlainText()).join(),
          contains('#代 27:18'));
    });

    testWidgets('every recogniser it builds is disposed, on a rebuild as '
        'well as on the way out', (tester) async {
      // This widget sits inside the originals sheet, which rebuilds on
      // every scroll frame, and it builds one recogniser per citation.
      // Releasing them only in `dispose` would leak three a frame here,
      // so `build` releases the previous set first — and that is what
      // this counts, through the framework's own allocation events
      // rather than through the widget's private list.
      var created = 0;
      var disposed = 0;
      void listen(ObjectEvent event) {
        if (event is! ObjectCreated && event is! ObjectDisposed) return;
        final object = event is ObjectCreated
            ? event.object
            : (event as ObjectDisposed).object;
        if (object is! TapGestureRecognizer) return;
        if (event is ObjectCreated) {
          created++;
        } else {
          disposed++;
        }
      }

      FlutterMemoryAllocations.instance.addListener(listen);
      addTearDown(
          () => FlutterMemoryAllocations.instance.removeListener(listen));

      final style = ValueNotifier<double>(14);
      addTearDown(style.dispose);
      await pump(
        tester,
        ValueListenableBuilder<double>(
          valueListenable: style,
          builder: (context, size, child) => CbolReferenceText(
            source: '(#徒 25:15; 帖后 1:9; 犹7)',
            style: TextStyle(fontSize: size),
          ),
        ),
      );
      expect(
          spansOf(tester)
              .whereType<TextSpan>()
              .where((s) => s.recognizer != null),
          hasLength(3),
          reason: 'three citations, three targets');
      expect(created, 3);
      expect(disposed, 0);

      for (var i = 0; i < 4; i++) {
        style.value = 14 + i + 1;
        await tester.pump();
      }
      expect(created, 15, reason: 'a fresh set per build');
      expect(disposed, 12, reason: 'every set but the live one');

      await pump(tester, const SizedBox.shrink());
      expect(disposed, created);
    });
  });

  group('the BDB/Thayer article', () {
    const article = ChineseLexEntry(
      number: 'H1324',
      lemma: 'בת',
      translit: 'bath',
      etymology: '源自 H1327; 阴性名词',
      senses: ['1) 罢特, 测量液体的单位 (#王上 7:26|)', '2) 一种量器 (#结 45:14|)'],
    );

    testWidgets('prints its senses with the citations live and the '
        'delimiters gone', (tester) async {
      await pump(tester,
          const ChineseLexiconBlock(entry: article, locale: 'zh-Hans'));
      final printed = spansOf(tester).map((s) => s.toPlainText()).join();
      expect(printed, contains('王上 7:26'));
      expect(printed, contains('结 45:14'));
      expect(printed, isNot(contains('#')));
      expect(printed, isNot(contains('|')));

      final tappable = spansOf(tester)
          .whereType<TextSpan>()
          .where((s) => s.recognizer != null)
          .map((s) => s.text)
          .toList();
      expect(tappable, ['王上 7:26', '结 45:14']);
    });
  });

  group('the parser is what the widget renders', () {
    test('a span is built for every reference run and nothing else', () {
      const source = '1) 犹大境内地方 #代上 2:51 |';
      final runs = parseCbolRuns(source);
      final spans = buildCbolSpans(
        source: source,
        baseStyle: const TextStyle(),
        refColor: const Color(0xFF000000),
      );
      expect(spans, hasLength(runs.length));
      expect(spans.map((s) => s.toPlainText()).join(),
          runs.map((r) => r.text).join());
    });

    test('read-only rendering builds no recogniser to leak', () {
      final spans = buildCbolSpans(
        source: '结束, 完成 (#路 14:19-30|)',
        baseStyle: const TextStyle(),
        refColor: const Color(0xFF000000),
      );
      expect(
          spans.whereType<TextSpan>().where((s) => s.recognizer != null),
          isEmpty);
    });
  });
}
