import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:yswords/services/song_file_saver.dart';

/// 2026-09-13: 「可以iPhone Android win mac都可以下载吗」. Saving a song
/// as a FILE the reader can find was never built on any platform. The
/// per-platform halves need a device; these pin the parts that do not.
void main() {
  group('file names', () {
    test('a Chinese title passes through; path breakers do not', () {
      expect(safeFileName('乘风破浪', extension: 'mp3'), '乘风破浪.mp3');
      expect(safeFileName('Sail / 乘风破浪: "破浪"?', extension: 'mp3'),
          'Sail 乘风破浪 破浪.mp3');
    });

    test('an empty or absurd title still names a file', () {
      expect(safeFileName('   ', extension: 'pdf'), 'song.pdf');
      expect(safeFileName('x' * 200, extension: 'mp3').length,
          lessThanOrEqualTo(84));
    });
  });

  test('the VM takes the io half, which is supported', () {
    expect(SongFileSaver.isSupported, isTrue);
  });

  group('the platforms have their doors', () {
    test('iOS exposes Documents to the Files app', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(plist.contains('UIFileSharingEnabled'), isTrue);
      expect(plist.contains('LSSupportsOpeningDocumentsInPlace'), isTrue,
          reason: 'a saved file that cannot be reached is not saved');
    });

    test('Android has the Downloads channel', () {
      final kt = File(
              'android/app/src/main/kotlin/com/example/yswords/MainActivity.kt')
          .readAsStringSync();
      expect(kt.contains('"yswords/downloads"'), isTrue);
      expect(kt.contains('MediaStore.Downloads.EXTERNAL_CONTENT_URI'), isTrue,
          reason: 'the public Downloads folder, not an app-private one');
      final dart = File('lib/services/song_file_saver_io.dart').readAsStringSync();
      expect(dart.contains("MethodChannel('yswords/downloads')"), isTrue,
          reason: 'both ends name the same channel');
    });
  });
}
