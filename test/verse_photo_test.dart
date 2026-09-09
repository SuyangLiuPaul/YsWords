// The reader's own photograph as a verse-card background.
//
// Two failures matter here and neither is visible from the widget
// tree, which is why most of this file rasterises. The first is a card
// that shows the photograph on screen and exports without it — the
// `DecorationImage` resolves a frame or two after the style changes,
// and `RenderRepaintBoundary.toImage` captures the last frame that was
// PAINTED, so the picture can be on the reader's screen and absent
// from the file they just sent. The second is a card that exports the
// photograph at full strength and buries the verse in it.
//
// The fake below replaces `ImagePickerPlatform.instance`, so nothing
// in this file opens a camera roll or needs a plugin to answer. That
// is also why `image_picker_platform_interface` is a declared dev
// dependency rather than a transitive one.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/services/verse_card_service.dart';
import 'package:yswords/widgets/verse_card.dart';
import 'package:yswords/widgets/verse_card_sheet.dart';

const String _verse = 'Jesus wept.';

/// A one-colour PNG, encoded through the engine so it is a real file
/// and not a hand-rolled byte string the decoder might refuse.
///
/// Solid rather than patterned on purpose: every pixel of the card's
/// background then has the same known source colour, so "did the
/// photograph reach the export" can be asked of any pixel that is not
/// under type, and "how much was it veiled" is arithmetic rather than
/// a judgement about a thumbnail.
Future<Uint8List> _solidPhoto(WidgetTester tester, Color color) async {
  final bytes = await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 64, 64),
      Paint()..color = color,
    );
    final image = await recorder.endRecording().toImage(64, 64);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  return bytes!;
}

/// Pump a card and rasterise it the way the export does.
///
/// The photograph is precached first, exactly as `VerseCardSheet`
/// does before it switches style — see `_pickPhoto` there. Without
/// that step this helper would be testing whether an image happens to
/// decode inside one `pump`, which is the very race the production
/// code is written to avoid rather than something a test should rely
/// on.
Future<ui.Image> _exportCard(
  WidgetTester tester, {
  required VerseCardStyle style,
  ImageProvider? photo,
  Brightness brightness = Brightness.dark,
}) async {
  final key = GlobalKey();
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: RepaintBoundary(
            key: key,
            child: Builder(builder: (context) {
              return VerseCard(
                reference: 'John 11:35',
                body: _verse,
                versionLabel: 'KJV',
                appName: "Yahweh's Words",
                scheme: verseCardScheme(
                  seed: Colors.lightBlue,
                  brightness: brightness,
                ),
                style: style,
                photo: photo,
              );
            }),
          ),
        ),
      ),
    ),
  ));
  if (photo != null) {
    final context = key.currentContext!;
    await tester.runAsync(() => precacheImage(photo, context));
  }
  await tester.pump();
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await tester.runAsync(
    () => boundary.toImage(pixelRatio: kVerseCardPixelRatio),
  );
  return image!;
}

/// The colour of one pixel of a rasterised card, as `(r, g, b, a)`.
Future<List<int>> _pixel(WidgetTester tester, ui.Image image, int x, int y) async {
  final rgba = await tester.runAsync(() async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final bytes = Uint8List.view(data!.buffer);
    final i = (y * image.width + x) * 4;
    return <int>[bytes[i], bytes[i + 1], bytes[i + 2], bytes[i + 3]];
  });
  return rgba!;
}

/// A pixel inside the card that no type can reach: the right-hand
/// margin, level with the verse. The card's padding is 28 dp and the
/// reference and body both start at the left edge of the content box,
/// so this sits in background on every style.
Future<List<int>> _backgroundPixel(WidgetTester tester, ui.Image image) =>
    _pixel(tester, image, image.width - 14, (image.height * 0.45).round());

/// Stands in for the camera roll. [answer] is what the reader "picks":
/// bytes for a photograph, null for backing out.
class _FakePicker extends ImagePickerPlatform {
  final Uint8List? answer;
  int calls = 0;

  _FakePicker(this.answer);

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    calls++;
    if (answer == null) return null;
    return XFile.fromData(answer!, mimeType: 'image/png', name: 'photo.png');
  }
}

void main() {
  group('the photograph reaches the file', () {
    testWidgets(
        'a photo card exports the picture, not an empty veil — the failure '
        'that would look correct on screen and be missing from what was sent',
        (tester) async {
      final png = await _solidPhoto(tester, const Color(0xFFFF00FF));
      final image = await _exportCard(
        tester,
        style: VerseCardStyle.photo,
        photo: MemoryImage(png),
      );
      final px = await _backgroundPixel(tester, image);
      // Magenta survives the veil: red and blue still dominate green
      // by a wide margin. Asserting the exact post-scrim value would
      // pin the scrim's alpha, which is a design number and free to
      // change; asserting the HUE pins the thing that must not change,
      // which is that the reader's picture is in the file at all.
      expect(px[0], greaterThan(px[1] + 60), reason: 'red channel: $px');
      expect(px[2], greaterThan(px[1] + 60), reason: 'blue channel: $px');
      expect(px[3], 255, reason: 'the card must export opaque: $px');
      image.dispose();
    });

    testWidgets(
        'the veil is real — the picture arrives dimmed, neither at full '
        'strength nor replaced by the fallback fill', (tester) async {
      // Pure green, chosen so the assertion below cannot be satisfied
      // by anything except a veiled photograph: the card's own
      // photo-style fill is near-black (green channel 24) and the
      // unveiled picture is 255, so a band strictly between the two
      // fails if the picture is missing AND fails if the scrim is.
      // An earlier version of this test used magenta and asserted
      // "< 255", which the fallback fill also satisfies — it passed
      // with the photograph deleted, which is no test at all.
      final png = await _solidPhoto(tester, const Color(0xFF00FF00));
      final image = await _exportCard(
        tester,
        style: VerseCardStyle.photo,
        photo: MemoryImage(png),
        brightness: Brightness.dark,
      );
      final px = await _backgroundPixel(tester, image);
      expect(px[1], greaterThan(120),
          reason: 'the photograph is missing — this is the fill: $px');
      expect(px[1], lessThan(250),
          reason: 'the scrim is missing — this is raw green: $px');
      image.dispose();
    });

    testWidgets(
        'the light card veils the same photograph towards white and the dark '
        'card towards black, which is the whole of what the toggle does here',
        (tester) async {
      final png = await _solidPhoto(tester, const Color(0xFF808080));
      final lightImage = await _exportCard(
        tester,
        style: VerseCardStyle.photo,
        photo: MemoryImage(png),
        brightness: Brightness.light,
      );
      final light = await _backgroundPixel(tester, lightImage);
      lightImage.dispose();

      final darkImage = await _exportCard(
        tester,
        style: VerseCardStyle.photo,
        photo: MemoryImage(png),
        brightness: Brightness.dark,
      );
      final dark = await _backgroundPixel(tester, darkImage);
      darkImage.dispose();

      expect(light[0], greaterThan(dark[0]),
          reason: 'light $light should sit above dark $dark');
      // And both are still recognisably the mid-grey photograph
      // rather than the card's own white / near-black fill, which
      // would satisfy the comparison above on its own.
      expect(light[0], inInclusiveRange(140, 225), reason: 'light: $light');
      expect(dark[0], inInclusiveRange(55, 120), reason: 'dark: $dark');
    });

    testWidgets(
        'a photo card with no photograph still exports an opaque card rather '
        'than a transparent one, because a see-through PNG is only visible '
        'after it has been sent', (tester) async {
      final image = await _exportCard(
        tester,
        style: VerseCardStyle.photo,
        photo: null,
      );
      final px = await _backgroundPixel(tester, image);
      expect(px[3], 255, reason: 'alpha: $px');
      expect(image.width, (kVerseCardWidth * kVerseCardPixelRatio).round());
      image.dispose();
    });
  });

  group('what the photo palette imposes', () {
    test('only the photo style carries a scrim and a shadow, because only it '
        'paints type over something it did not choose', () {
      final scheme = verseCardScheme(
        seed: Colors.lightBlue,
        brightness: Brightness.dark,
      );
      for (final style in VerseCardStyle.values) {
        final palette = VerseCardPalette.of(style, scheme);
        final expected = style == VerseCardStyle.photo;
        expect(palette.scrim != null, expected, reason: '$style scrim');
        expect(palette.shadows != null, expected, reason: '$style shadows');
      }
    });

    test('the photo card ignores the reader’s seed colour — a plum accent '
        'over somebody’s photograph is a collision, not a theme', () {
      for (final seed in [Colors.purple, Colors.orange, Colors.teal]) {
        final palette = VerseCardPalette.of(
          VerseCardStyle.photo,
          verseCardScheme(seed: seed, brightness: Brightness.dark),
        );
        expect(palette.foreground, Colors.white, reason: '$seed');
        expect(palette.accent, Colors.white, reason: '$seed');
      }
    });

    test('light and dark photo cards write in opposite inks', () {
      Color inkFor(Brightness b) => VerseCardPalette.of(
            VerseCardStyle.photo,
            verseCardScheme(seed: Colors.lightBlue, brightness: b),
          ).foreground;
      final light = inkFor(Brightness.light);
      final dark = inkFor(Brightness.dark);
      expect(dark.computeLuminance(), greaterThan(0.9));
      expect(light.computeLuminance(), lessThan(0.1));
    });
  });

  group('the chip is the picker', () {
    late ImagePickerPlatform original;

    setUp(() => original = ImagePickerPlatform.instance);
    tearDown(() => ImagePickerPlatform.instance = original);

    /// Open the sheet on a translation that is allowed to become a
    /// picture, with [picker] standing in for the camera roll.
    Future<void> open(WidgetTester tester, _FakePicker picker) async {
      ImagePickerPlatform.instance = picker;
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await tester.pumpWidget(
        ChangeNotifierProvider<AppSettings>.value(
          value: AppSettings(),
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => Center(
                  child: ElevatedButton(
                    onPressed: () => VerseCardSheet.show(
                      ctx,
                      reference: 'John 11:35',
                      body: _verse,
                      version: 'kjv',
                      versionLabel: 'KJV',
                      shareText: 'John 11:35 — $_verse',
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

    String label(String key) => uiStrings[key]!['zh-Hans']!;

    /// Tap the photo chip and wait for the pick to land.
    ///
    /// `pumpAndSettle` alone cannot do this and the reason is worth
    /// stating, because the failure it produces is a bare "timed out"
    /// with nothing pointing at the cause. Two things are in the way.
    /// `precacheImage` decodes on the engine's own threads, which a
    /// `testWidgets` body's fake clock never advances to — so the
    /// pick's continuation never runs unless it is given real time
    /// through [WidgetTester.runAsync]. And while it is in flight the
    /// chip shows an indeterminate `CircularProgressIndicator`, which
    /// by definition never settles — so `pumpAndSettle` waits out its
    /// whole timeout on an animation that is doing exactly what it is
    /// supposed to. Real time first, then settle once the spinner is
    /// gone.
    Future<void> pickPhoto(WidgetTester tester) async {
      await tester.tap(find.text(label('verseCardStylePhoto')));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('the sheet offers the reader their own photo, which is the '
        'thing that was missing', (tester) async {
      await open(tester, _FakePicker(null));
      expect(find.text(label('verseCardStylePhoto')), findsOneWidget);
      // Nothing to remove until something has been picked.
      expect(find.text(label('verseCardPhotoRemove')), findsNothing);
    });

    testWidgets(
        'tapping the photo chip opens the camera roll rather than selecting '
        'an empty style — there is no state where the card says Photo and '
        'shows none', (tester) async {
      final picker = _FakePicker(null);
      await open(tester, picker);
      await pickPhoto(tester);

      expect(picker.calls, 1);
      // The reader backed out, so the card is exactly where it was.
      final card = tester.widget<VerseCard>(find.byType(VerseCard));
      expect(card.style, VerseCardStyle.plain);
      expect(card.photo, isNull);
      expect(find.text(label('verseCardPhotoRemove')), findsNothing);
    });

    testWidgets('a picked photograph selects the style and puts the picture '
        'on the card', (tester) async {
      final png = await _solidPhoto(tester, const Color(0xFF3366CC));
      final picker = _FakePicker(png);
      await open(tester, picker);
      await pickPhoto(tester);

      final card = tester.widget<VerseCard>(find.byType(VerseCard));
      expect(card.style, VerseCardStyle.photo);
      expect(card.photo, isNotNull);
      expect(find.text(label('verseCardPhotoRemove')), findsOneWidget);
    });

    testWidgets('removing the photograph takes the picture out of the app, '
        'not just off the card', (tester) async {
      final png = await _solidPhoto(tester, const Color(0xFF3366CC));
      await open(tester, _FakePicker(png));
      await pickPhoto(tester);

      await tester.tap(find.text(label('verseCardPhotoRemove')));
      await tester.pumpAndSettle();

      final card = tester.widget<VerseCard>(find.byType(VerseCard));
      expect(card.photo, isNull);
      expect(card.style, VerseCardStyle.plain);
      expect(find.text(label('verseCardPhotoRemove')), findsNothing);
    });

    testWidgets(
        'a file the picker accepts and the engine cannot decode leaves the '
        'card as it was and says so — it does not become a Photo card with '
        'nothing on it', (tester) async {
      // 2026-09-09 (review finding 1). `precacheImage` does not throw
      // on a bad file; it completes and reports through `onError`.
      // The sheet used to catch an exception that never came, so
      // these bytes flipped the style and painted a bare veil, and
      // the failure toast was unreachable. Any non-image bytes will
      // do; the engine refuses them at codec instantiation.
      final junk = Uint8List.fromList('not a png'.codeUnits);
      final picker = _FakePicker(junk);
      await open(tester, picker);
      await pickPhoto(tester);

      expect(picker.calls, 1);
      final card = tester.widget<VerseCard>(find.byType(VerseCard));
      expect(card.style, VerseCardStyle.plain,
          reason: 'an undecodable file must not select the photo style');
      expect(card.photo, isNull);
      expect(find.text(label('verseCardPhotoRemove')), findsNothing);
      expect(find.text(label('versePhotoFailed')), findsOneWidget,
          reason: 'the reader is told, rather than shown an empty card');
      // The chip is tappable again: a bad file is not a stuck picker.
      await tester.tap(find.text(label('verseCardStylePhoto')));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();
      expect(picker.calls, 2);
      // Let the toasts time out so the binding does not report their
      // timers as leaked.
      await tester.pump(const Duration(seconds: 3));
      expect(find.text(label('versePhotoFailed')), findsNothing);
    });
  });

  group('the macOS sandbox lets the picked file be read', () {
    // 2026-09-09 (review finding 2). image_picker on macOS goes through
    // file_selector_macos / NSOpenPanel, and a sandboxed app may only
    // read the file the user chose there if it carries
    // user-selected.read-only. Without it the panel returns a path
    // the app cannot open — the picker "works" and the card never gets
    // the picture. Both entitlement files are checked because the
    // debug build is what a developer would use to confirm the fix,
    // and a debug-only entitlement is how a release regresses quietly.
    const key = 'com.apple.security.files.user-selected.read-only';

    for (final file in const [
      'macos/Runner/Release.entitlements',
      'macos/Runner/DebugProfile.entitlements',
    ]) {
      test('$file grants $key', () {
        final plist = File(file).readAsStringSync();
        final granted = RegExp(
          '<key>${RegExp.escape(key)}</key>\\s*<true/>',
        ).hasMatch(plist);
        expect(granted, isTrue,
            reason: '$file must contain <key>$key</key> followed by <true/>');
      });
    }
  });
}
