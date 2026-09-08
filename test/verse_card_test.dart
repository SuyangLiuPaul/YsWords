// The verse-image card: what comes out of `toImage`, what happens to a
// selection that is too long or empty, and which translations are
// allowed to become a picture at all.
//
// Everything here goes through a real `RepaintBoundary` and a real PNG
// encode rather than asserting on the widget tree, because the two
// failures this feature actually has are both invisible from the tree:
// a card that lays out correctly and exports at 1× and looks soft on
// somebody else's phone, and a card that lays out correctly and
// exports Chinese as tofu.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/constants/bible_versions.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/services/verse_card_service.dart';
import 'package:yswords/widgets/verse_card.dart';
import 'package:yswords/widgets/verse_card_sheet.dart';

/// A short English verse — one line of body text, nothing to wrap.
const String _shortVerse = 'Jesus wept.';

/// Psalm 119-shaped: long enough to drive the type ladder to its floor
/// and then keep going.
final String _longVerse = List.filled(
  40,
  'Blessed are those whose way is blameless, who walk in the law of '
      'the LORD.',
).join(' ');

const String _cjkVerse = '神爱世人，甚至将他的独生子赐给他们';

/// Pump the card exactly the way `VerseCardSheet` does: inside a
/// `FittedBox`, which hands the boundary unbounded constraints so the
/// card lays out at its true 360 dp width whatever the screen is. A
/// plain `Center` would cap it at the 600 dp test surface and the
/// long-verse case would be testing Flutter's overflow behaviour
/// rather than the card's.
Future<GlobalKey> _pumpCard(
  WidgetTester tester, {
  required String body,
  String reference = 'John 11:35',
  String versionLabel = 'KJV',
  String? licence,
  VerseCardStyle style = VerseCardStyle.plain,
  Brightness brightness = Brightness.light,
}) async {
  final key = GlobalKey();
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: RepaintBoundary(
            key: key,
            child: VerseCard(
              reference: reference,
              body: body,
              versionLabel: versionLabel,
              licence: licence,
              appName: "Yahweh's Words",
              scheme: verseCardScheme(
                seed: Colors.lightBlue,
                brightness: brightness,
              ),
              style: style,
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.pump();
  return key;
}

/// Rasterise through the real service, off the fake clock.
///
/// `toByteData(format: png)` hands the encode to the engine's own
/// threads, and a `testWidgets` body runs under fake async that never
/// delivers their completion — awaiting it directly hangs the suite
/// with no error and no output. Every call into the capture path in
/// this file therefore goes through [WidgetTester.runAsync]. Production
/// needs nothing of the sort; this is a property of the test binding.
Future<Uint8List?> _capture(WidgetTester tester, GlobalKey key) =>
    tester.runAsync<Uint8List?>(() => captureVerseCardPng(key));

/// Decode the PNG the service produced, rather than trusting the
/// service's own arithmetic about how big it should have been. A codec
/// that refuses the bytes fails here, which is also the only check
/// that they really are a PNG.
///
/// Wrapped in [WidgetTester.runAsync] because `instantiateImageCodec`
/// completes off the engine's own threads, and a `testWidgets` body
/// runs under fake async that will never deliver that completion — the
/// await simply never returns and the suite hangs with no error.
Future<ui.Image> _decode(WidgetTester tester, Uint8List png) async {
  final image = await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(png);
    final frame = await codec.getNextFrame();
    return frame.image;
  });
  return image!;
}

/// Proportion of the raster that carries ink, by alpha. Used for the
/// tofu check; see the test that calls it for what the number means.
Future<double> _inkRatio(WidgetTester tester, ui.Image image) async {
  final inked = await tester.runAsync(() async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final bytes = Uint8List.view(data!.buffer);
    var count = 0;
    for (var i = 3; i < bytes.length; i += 4) {
      if (bytes[i] > 128) count++;
    }
    return count;
  });
  return inked! / (image.width * image.height);
}

Future<Uint8List> _rasterise(WidgetTester tester, Widget child) async {
  final key = GlobalKey();
  await tester.pumpWidget(MaterialApp(
    home: Center(child: RepaintBoundary(key: key, child: child)),
  ));
  await tester.pump();
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final png = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: kVerseCardPixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  return png!;
}

void main() {
  group('exporting the card', () {
    testWidgets(
        'a card exports a PNG three times its layout size, so a 360-point '
        'card lands on the 1080 pixels social platforms publish at',
        (tester) async {
      final key = await _pumpCard(tester, body: _shortVerse);
      final png = await _capture(tester, key);
      expect(png, isNotNull);
      expect(png!.isNotEmpty, isTrue);

      final image = await _decode(tester, png);
      final laidOut = tester.getSize(find.byType(VerseCard));
      expect(laidOut.width, kVerseCardWidth);
      expect(image.width, (kVerseCardWidth * kVerseCardPixelRatio).round());
      expect(image.height, (laidOut.height * kVerseCardPixelRatio).round());
      image.dispose();
    });

    testWidgets(
        'a 1x display still exports the full 1080-pixel file, because the '
        'ratio is fixed rather than taken from the device', (tester) async {
      // The regression this guards is silent by construction: a card
      // exported at the ambient ratio looks right to whoever made it,
      // on the screen they made it on, and is soft everywhere else. So
      // the view is pinned to the worst case — a 1x desktop browser,
      // where `devicePixelRatio` would have produced a 360 px image —
      // and the export has to come out the same size regardless.
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1.0;
      final key = await _pumpCard(tester, body: _shortVerse);
      final image = await _decode(tester, (await _capture(tester, key))!);
      expect(image.width, 1080);
      image.dispose();
    });
  });

  group('selections the card has to survive', () {
    testWidgets(
        'an empty verse still exports a square card at the minimum height '
        'instead of a letterbox strip', (tester) async {
      final key = await _pumpCard(tester, body: '');
      final image = await _decode(tester, (await _capture(tester, key))!);
      expect(tester.getSize(find.byType(VerseCard)).height,
          kVerseCardMinHeight);
      expect(image.width, 1080);
      expect(image.height, 1080);
      image.dispose();
    });

    testWidgets(
        'a Psalm 119-length selection makes the card taller and keeps every '
        'character, rather than clipping or scaling to nothing',
        (tester) async {
      await _pumpCard(tester, body: _shortVerse);
      final shortHeight = tester.getSize(find.byType(VerseCard)).height;

      final key = await _pumpCard(tester, body: _longVerse);
      final longHeight = tester.getSize(find.byType(VerseCard)).height;
      expect(longHeight, greaterThan(shortHeight));

      // Nothing clipped: the Text still holds the whole selection, and
      // it was given no maxLines to cut it with.
      final text = tester.widget<Text>(find.text(_longVerse));
      expect(text.data, _longVerse);
      expect(text.maxLines, isNull);
      expect(text.overflow, isNull);

      // And the type stepped down to the ladder's floor rather than
      // shrinking without limit — a 1080 px image of unreadable type
      // is a worse answer than a tall one.
      expect(text.style!.fontSize, verseCardBodyFontSize(_longVerse.length));
      expect(text.style!.fontSize, greaterThanOrEqualTo(11.5));

      final image = await _decode(tester, (await _capture(tester, key))!);
      expect(image.height, (longHeight * kVerseCardPixelRatio).round());
      image.dispose();
      expect(tester.takeException(), isNull);
    });

    testWidgets('every background treatment exports at the same size',
        (tester) async {
      // The picker must not change the geometry of the file, only its
      // colours — a reader who tries all three and picks the third
      // should not get a differently-shaped image.
      final sizes = <String>{};
      for (final style in VerseCardStyle.values) {
        for (final brightness in Brightness.values) {
          final key = await _pumpCard(
            tester,
            body: _shortVerse,
            style: style,
            brightness: brightness,
          );
          final png = await _capture(tester, key);
          final image = await _decode(tester, png!);
          sizes.add('${image.width}x${image.height}');
          image.dispose();
        }
      }
      expect(sizes, hasLength(1));
    });
  });

  group('Chinese renders as glyphs, not tofu', () {
    // WHAT THIS PROVES, AND WHAT IT DOES NOT.
    //
    // It proves three things about the VM/Skia path: the bundled
    // subset really is a declared asset and loads through rootBundle;
    // the card's own body style (the one carrying kCjkFontFallback)
    // lays CJK out on that font's full-width advances; and different
    // characters produce different rasters, which cannot happen if
    // they are all resolving to one .notdef box.
    //
    // It does NOT prove the glyphs are the RIGHT ones — only a golden
    // image would — and it does NOT exercise CanvasKit, which is a
    // different rasteriser and the one the pubspec's long note about
    // this font is actually about. The web path was checked by
    // compiling it (`flutter build web` succeeds), which is not the
    // same as rendering it.
    //
    // A control measurement was attempted and abandoned: rendering the
    // same string with an unregistered family and no fallback chain,
    // to see what tofu scores. It hangs flutter_tester indefinitely —
    // the font-fallback search never returns. Recorded so nobody
    // spends the ten minutes again.
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final loader = FontLoader('NotoSansSC-YsWords')
        ..addFont(rootBundle.load('assets/fonts/NotoSansSC-YsWords.otf'));
      await loader.load();
    });

    testWidgets('CJK advances one full-width em per character, and the ink '
        'is glyph-shaped rather than a filled box', (tester) async {
      final png = await _rasterise(
        tester,
        Text(
          _cjkVerse,
          style: verseCardBodyStyle(
            characters: _cjkVerse.length,
            color: const Color(0xFF000000),
          ),
        ),
      );
      final image = await _decode(tester, png);

      // 17 characters × 22 pt × 3 — the CJK metrics of the bundled
      // subset, not a proportional substitute squeezing them narrower.
      expect(
        image.width,
        (_cjkVerse.length * verseCardBodyFontSize(_cjkVerse.length) *
                kVerseCardPixelRatio)
            .round(),
      );

      // Measured 0.258 on this font. A .notdef box fills its em solid,
      // which against this line box (fontSize × the style's 1.62 line
      // height) would score above 0.6. The band is wide on purpose:
      // the assertion is "these are glyphs", not "these are these
      // glyphs", and it should not fail on a font revision.
      final ink = await _inkRatio(tester, image);
      expect(ink, greaterThan(0.05));
      expect(ink, lessThan(0.45));
      image.dispose();
    });

    testWidgets('two different Chinese characters rasterise differently, '
        'which one repeated fallback box could not', (tester) async {
      TextStyle style() => verseCardBodyStyle(
            characters: 4,
            color: const Color(0xFF000000),
          );
      final a = await _rasterise(tester, Text('神神神神', style: style()));
      final b = await _rasterise(tester, Text('神爱世人', style: style()));
      expect(a.length, greaterThan(0));
      expect(b, isNot(equals(a)));
    });
  });

  group('which translations may become a picture', () {
    test('the CSB is excluded, because nothing on file grants an image', () {
      // docs/permissions/ holds an ebook/app grant to a named person
      // for a named work in a named territory. It does not speak to
      // standalone PNGs that circulate with no app and no About page,
      // and this feature does not guess.
      expect(verseImageAllowed('csb'), isFalse);
      expect(verseCardLicence('csb', 'en'), isNull);
    });

    test('the NASB is excluded here as well as everywhere else', () {
      expect(kVerseImageRestrictedVersions, contains('nasb'));
      expect(verseImageAllowed('nasb'), isFalse);
    });

    test(
        'every translation the picker offers either prints its About-page '
        'credit on the card or is excluded from the feature outright', () {
      // The rule docs/permissions/README.md sets down is that anything
      // a reader is shown must match a document on file. A card is
      // something a reader is shown, so a new edition cannot be added
      // to the picker and silently ship a card with a blank footer.
      for (final version in availableVersions) {
        if (!verseImageAllowed(version.value)) continue;
        for (final locale in const ['zh-Hans', 'zh-Hant', 'en']) {
          final licence = verseCardLicence(version.value, locale);
          expect(
            licence,
            isNotNull,
            reason: '${version.value} has no card credit line for $locale',
          );
          expect(licence, isNotEmpty, reason: version.value);
        }
      }
    });

    test('the card quotes the About page rather than paraphrasing it', () {
      // A paraphrased licence is a wrong licence. These read the same
      // uiStrings keys the About page's table reads, so the two can
      // never drift apart.
      expect(verseCardLicence('leb', 'en'),
          uiStrings['aboutLicenseLeb']!['en']);
      expect(verseCardLicence('leb', 'en'), contains('Lexham English Bible'));
      expect(verseCardLicence('cuvs-yhwh', 'zh-Hans'),
          uiStrings['aboutLicenseCuvsYhwh']!['zh-Hans']);
      expect(verseCardLicence('biblexg-v2-tr', 'zh-Hant'),
          uiStrings['aboutLicenseLjk']!['zh-Hant']);
      expect(verseCardLicence('kjv', 'en'),
          uiStrings['aboutLicensePublicDomain']!['en']);
    });

    testWidgets('a credit line is never elided, however long it is',
        (tester) async {
      // The LEB's required statement is three sentences. It has to
      // survive onto the picture whole or the card is not carrying the
      // attribution at all — so the card grows for it, the same rule
      // the verse body follows.
      final licence = uiStrings['aboutLicenseLeb']!['en']!;
      await _pumpCard(tester, body: _shortVerse, versionLabel: 'LEB');
      final without = tester.getSize(find.byType(VerseCard)).height;

      await _pumpCard(
        tester,
        body: _shortVerse,
        versionLabel: 'LEB',
        licence: licence,
      );
      final text = tester.widget<Text>(find.text(licence));
      expect(text.maxLines, isNull);
      expect(text.overflow, isNull);
      expect(tester.getSize(find.byType(VerseCard)).height,
          greaterThanOrEqualTo(without));
      expect(tester.takeException(), isNull);
    });
  });

  group('the sheet the reader taps into', () {
    /// Put a button on screen that opens the sheet for [version], and
    /// press it. Returns after the sheet's entrance animation.
    Future<void> openFor(WidgetTester tester, String version) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final settings = AppSettings();
      await tester.pumpWidget(
        ChangeNotifierProvider<AppSettings>.value(
          value: settings,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => Center(
                  child: ElevatedButton(
                    onPressed: () => VerseCardSheet.show(
                      ctx,
                      reference: 'John 11:35',
                      body: _shortVerse,
                      version: version,
                      versionLabel: version.toUpperCase(),
                      shareText: 'John 11:35 — $_shortVerse',
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('an allowed translation gets a card with its credit line '
        'printed on it', (tester) async {
      await openFor(tester, 'kjv');
      expect(find.byType(VerseCard), findsOneWidget);
      expect(find.text(verseCardLicence('kjv', 'zh-Hans')!), findsOneWidget);
    });

    testWidgets('a restricted translation never reaches the card at all',
        (tester) async {
      await openFor(tester, 'csb');
      expect(find.byType(VerseCard), findsNothing);
      expect(
        find.text(uiStrings['verseCardVersionExcluded']!['zh-Hans']!),
        findsOneWidget,
      );
      // The toast removes itself on a plain timer, so pump past it or
      // the binding fails the test for a pending one.
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('file names', () {
    test('a Chinese reference keeps its characters and loses its colon', () {
      // Colons are illegal in a Windows path and are the separator in
      // every reference this app formats, so they are the one thing
      // that has to go. The book name does not — every platform this
      // ships to handles UTF-8 filenames, and 约翰福音-3-16.png is worth
      // more to the reader than a transliteration.
      expect(verseCardFileName('约翰福音 3:16'), '约翰福音-3-16.png');
      expect(verseCardFileName('John 11:35'), 'John-11-35.png');
      expect(verseCardFileName('Psalm 119:1–176'), 'Psalm-119-1–176.png');
    });

    test('a reference with nothing usable in it still names a file', () {
      expect(verseCardFileName('  '), 'verse.png');
      expect(verseCardFileName(''), 'verse.png');
    });
  });
}
