import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'package:yswords/services/verse_photo_picker.dart';

/// 2026-09-13: image_picker honours maxWidth/maxHeight on the phones and
/// the web and silently ignores them on macOS, Windows and Linux, so the
/// 1920-edge downscale the memory budget depends on did not happen
/// there. The engine does it now; these pin that it does, that a small
/// image is left alone, and that an undecodable one is passed through
/// for the caller's own decode to reject.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Uint8List> png(int w, int h) async {
    final rec = ui.PictureRecorder();
    ui.Canvas(rec).drawRect(
        ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        ui.Paint()..color = const ui.Color(0xFF3366CC));
    final img = await rec.endRecording().toImage(w, h);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    return data!.buffer.asUint8List();
  }

  Future<(int, int)> size(Uint8List bytes) async {
    final c = await ui.instantiateImageCodec(bytes);
    final f = await c.getNextFrame();
    final s = (f.image.width, f.image.height);
    f.image.dispose();
    c.dispose();
    return s;
  }

  test('a wide photograph comes back at the ceiling, aspect kept', () async {
    final out = await downscaleVersePhoto(await png(2560, 640));
    expect(await size(out), (1920, 480));
  });

  test('a tall one too', () async {
    final out = await downscaleVersePhoto(await png(600, 2400));
    expect(await size(out), (480, 1920));
  });

  test('one already inside the ceiling is returned as-is', () async {
    final src = await png(1200, 800);
    final out = await downscaleVersePhoto(src);
    expect(identical(out, src), isTrue,
        reason: 'no re-encode, no quality loss, no work');
  });

  group('luminance, for the scrim', () {
    Future<Uint8List> flat(ui.Color c) async {
      final rec = ui.PictureRecorder();
      ui.Canvas(rec).drawRect(
          const ui.Rect.fromLTWH(0, 0, 64, 64), ui.Paint()..color = c);
      final img = await rec.endRecording().toImage(64, 64);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      img.dispose();
      return data!.buffer.asUint8List();
    }

    test('white is 1, black is 0, mid-grey is in between', () async {
      expect(await versePhotoLuminance(await flat(const ui.Color(0xFFFFFFFF))),
          closeTo(1.0, 0.02));
      expect(await versePhotoLuminance(await flat(const ui.Color(0xFF000000))),
          closeTo(0.0, 0.02));
      final grey =
          await versePhotoLuminance(await flat(const ui.Color(0xFF808080)));
      expect(grey, inInclusiveRange(0.18, 0.26),
          reason: 'sRGB mid-grey is ~0.216 in linear light');
    });

    test('undecodable bytes give null, not a throw', () async {
      expect(await versePhotoLuminance(Uint8List.fromList([9, 9, 9])), isNull);
    });
  });

  test('bytes that are not an image pass through untouched', () async {
    final junk = Uint8List.fromList([1, 2, 3, 4]);
    expect(identical(await downscaleVersePhoto(junk), junk), isTrue,
        reason: 'the caller\'s decode is what says a file is unusable');
  });
}
