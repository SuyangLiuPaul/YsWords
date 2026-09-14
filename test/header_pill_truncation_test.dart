import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/constants/bible_versions.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/models/book.dart';
import 'package:yswords/models/chapter.dart';
import 'package:yswords/models/verse.dart';
import 'package:yswords/pages/home_page.dart';
import 'package:yswords/providers/main_provider.dart';

/// The book and version pills in the reading-pane header, measured on
/// the real screen, at every width the app is meant to run on.
///
/// This is the fourth round on one defect, and the first one written
/// before a reader found it.
///   • v1.3.160 gave the Chinese editions a `narrowLabel`, because
///     「和合本雅伟版」 was drawn as 「和合本雅…」.
///   • v1.3.161 stopped gating that on screen width: the pill shares its
///     row with the book title and the trailing icon cluster, so no
///     screen-width threshold is ever wide enough.
///   • 2026-09-08 took the flex share off the book chip, because flex
///     divides by RATIO rather than by need — 「書 22」 was handed three
///     fifths of the row while the version chip was capped at two fifths
///     and ellipsised to 「雅…」. Reported from an iPhone 12 and an older
///     Huawei P.
///
/// Nothing in the suite could have caught any of the three, because an
/// ellipsis is not an overflow. `responsive_overflow_smoke_test.dart`
/// lays this same page out at 320 and 390 and passes: `TextOverflow
/// .ellipsis` IS the layout succeeding — quietly, by deleting words. So
/// this file measures, and it measures the three things that actually
/// decide whether the pills fit:
///
///   1. **Screen width**, down to 320x480 — the iPhone 4 viewport, which
///      no report has ever come from and which the owner named as the
///      worst case worth surviving.
///   2. **Menu scale**, not reader font size. The header caps the
///      reader's size at 19 (`settings.fontSize.clamp(12, 19)`), so the
///      font slider barely moves these pills; `menuScale` multiplies
///      both the type AND the trailing icons, squeezing from both sides.
///      An earlier draft of this file varied font size 12/20/40, and its
///      own vacuity guard is what revealed that all three measured the
///      same pixels.
///   3. **Book-name length.** 帖撒罗尼迦后书 is the longest name in the
///      catalogue and, at 390px and up, the width where the header stops
///      folding to the short form — which is why an iPhone 12 was the
///      device the last report came from and a 320px phone was not.
///
/// The measurement is the whole pill pair's render subtree rather than a
/// string lookup: every `RenderParagraph` under the centered pair, laid
/// -out width against the width its own text wants on one line. Short by
/// a pixel is an ellipsis on someone's phone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // `-apple-system` is the default reader font and resolves, under the
    // test binding, to a font giving every glyph the same advance —
    // which turns a width measurement into a character count and lets
    // 「和合本雅伟版」 pass by pretending six Han characters are as narrow
    // as six Latin ones. The bundled Noto is loaded under that family
    // name so the Han metrics are real; PingFang, which `-apple-system`
    // resolves to on the reported iPhone, sets Han at the same 1em.
    await (FontLoader('-apple-system')
          ..addFont(rootBundle.load('assets/fonts/NotoSansSC-YsWords.otf')))
        .load();
  });

  const devices = <String, Size>{
    'iPhone 4 320x480': Size(320, 480),
    'iPhone SE 320x568': Size(320, 568),
    'Android 360x640': Size(360, 640),
    'iPhone 8 375x667': Size(375, 667),
    'iPhone 12 390x844': Size(390, 844),
    'iPhone 14 Pro Max 430x932': Size(430, 932),
  };

  // 1.5 is the top of the Menu Size slider (`setMenuScale` clamps to
  // 0.7–1.5). A reader who needs bigger type is the reader most likely
  // to be reading on a small phone, so the two worst cases coincide.
  const menuScales = <double>[1.0, 1.5];

  /// 帖撒罗尼迦后书 is the longest book name the catalogue holds, and the
  /// one that pushed the version pill off the row. 约翰福音 is an ordinary
  /// one, kept so a fix that only works for long names still fails here.
  const books = <String>['约翰福音', '帖撒罗尼迦后书'];

  Verse verse(String book, int n) =>
      Verse(book: book, chapter: 3, verse: n, text: '这是第$n节');

  Future<void> pumpHome(
    WidgetTester tester,
    Size size,
    double menuScale,
    String version,
    String book,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    final seed = [verse(book, 1), verse(book, 2)];
    // Set on the instance rather than seeded into prefs:
    // `AppSettings.loadSettings()` is called by `main.dart` and never by
    // the constructor, so a seeded pref reaches nothing here.
    final settings = AppSettings();
    await settings.setMenuScale(menuScale);
    // The top of the reader's own slider too, so the header runs at its
    // 19px cap and the two scales are the only variable left.
    await settings.setFontSize(40);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => MainProvider()
              ..currentVersion = version
              ..currentBook = book
              ..currentChapter = 3
              ..setBooks([
                Book(title: book, chapters: [Chapter(title: 3, verses: seed)]),
              ])
              ..setVerses(seed)),
        ChangeNotifierProvider<AppSettings>.value(value: settings),
      ],
      child: const MaterialApp(home: HomePage()),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Drains `AppSettings`' notify debounce before the tree goes, or the
  /// binding's pending-timer guard fails every test here for a reason
  /// that has nothing to do with the header.
  Future<void> dispose(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 700));
  }

  /// The centered book+version pair, found through the version pill's
  /// own tooltip and then up to the `Expanded` that holds the pair.
  ///
  /// Walked on the render tree instead of matched by string, so the
  /// measurement covers whatever the pills draw — including a label a
  /// later edition adds — and cannot accidentally measure the same words
  /// somewhere else on the page (the resume card carries them too).
  List<RenderBox> pairs(WidgetTester tester, String locale) {
    final tip = uiStrings['changeVersion']?[locale] ?? 'Change Version';
    final out = <RenderBox>[];
    for (final element in find.byTooltip(tip).evaluate()) {
      RenderBox? pair;
      element.visitAncestorElements((ancestor) {
        if (ancestor.widget is Expanded) {
          pair = ancestor.findRenderObject() as RenderBox?;
          return false;
        }
        return true;
      });
      if (pair != null) out.add(pair!);
    }
    return out;
  }

  /// Every label in [root] that was drawn narrower than it needs, as
  /// "text short by Npx".
  List<String> clipped(RenderBox root) {
    final out = <String>[];
    void visit(RenderObject o) {
      if (o is RenderParagraph) {
        final needed = o.getMaxIntrinsicWidth(double.infinity);
        final short = needed - o.size.width;
        if (short > 0.5) {
          out.add('"${o.text.toPlainText()}" short by '
              '${short.toStringAsFixed(1)}px');
        }
      }
      o.visitChildren(visit);
    }
    visit(root);
    return out;
  }

  for (final device in devices.entries) {
    for (final menuScale in menuScales) {
      for (final book in books) {
        testWidgets(
            'both header pills read in full — ${device.key}, menu '
            '${menuScale}x, $book', (tester) async {
          addTearDown(tester.view.reset);
          // 和合本雅伟版 is the cold-install default and carries the widest
          // narrow label the pill holds, which is why all three reports
          // were filed against it.
          await pumpHome(
              tester, device.value, menuScale, 'cuvs-yhwh', book);

          final found = pairs(tester, 'zh-Hans');
          expect(found, isNotEmpty,
              reason: 'the header pills are not on screen on '
                  '${device.key} — this test would pass by measuring '
                  'nothing');

          final bad = found.expand(clipped).toList();
          expect(bad, isEmpty,
              reason: 'ellipsised in the header on ${device.key} at menu '
                  'scale ${menuScale}x reading $book: ${bad.join(", ")}. '
                  '「雅…」 and 「书卷不见了」 are the two reports this header '
                  'has already been fixed for.');

          await dispose(tester);
        });
      }
    }
  }

  testWidgets('every edition the picker offers fits beside the longest '
      'book name, on the smallest screen, at the largest menu size',
      (tester) async {
    // The loop above pins one edition across the grid; this pins all
    // nine at the single worst corner of it, so an edition added later
    // cannot ship a label that only fits on the phone its author held.
    addTearDown(tester.view.reset);
    final bad = <String>[];
    for (final version in availableVersions) {
      await pumpHome(
          tester, const Size(320, 480), 1.5, version.value, '帖撒罗尼迦后书');
      final found = pairs(tester, 'zh-Hans');
      if (found.isEmpty) {
        bad.add('${version.value}: no header on screen');
      } else {
        bad.addAll(found.expand(clipped).map((c) => '${version.value}: $c'));
      }
      await dispose(tester);
    }
    expect(bad, isEmpty,
        reason: 'these editions ellipsise in the header at 320px: '
            '${bad.join("; ")}');
  });

  testWidgets('the menu scale actually reaches the header', (tester) async {
    // Every case above varies one number. An earlier draft varied the
    // reader font size, which the header caps at 19 — so all of it
    // measured identical pixels and passed. This is what says the axis
    // is real: the same pill, drawn wider at 1.5x than at 1.0x.
    addTearDown(tester.view.reset);
    double widthAt(WidgetTester t) {
      final root = pairs(t, 'zh-Hans').first;
      var widest = 0.0;
      void visit(RenderObject o) {
        if (o is RenderParagraph) {
          widest = o.getMaxIntrinsicWidth(double.infinity) > widest
              ? o.getMaxIntrinsicWidth(double.infinity)
              : widest;
        }
        o.visitChildren(visit);
      }
      visit(root);
      return widest;
    }

    // Measured at 1000px, where `chromeScaleFor` caps nothing and the
    // book name does not fold at either scale — the two runs then differ
    // by the scale alone, which is the thing being checked.
    await pumpHome(tester, const Size(1000, 900), 1.0, 'cuvs-yhwh', '约翰福音');
    final small = widthAt(tester);
    await dispose(tester);

    await pumpHome(tester, const Size(1000, 900), 1.5, 'cuvs-yhwh', '约翰福音');
    final large = widthAt(tester);
    await dispose(tester);

    expect(large, greaterThan(small * 1.2),
        reason: 'menuScale 1.5x drew the header labels ${large
            .toStringAsFixed(1)}px wide against ${small.toStringAsFixed(1)} '
            'at 1.0x — the scale is not reaching the pills, so the grid '
            'above is measuring one configuration three times');
  });
}
