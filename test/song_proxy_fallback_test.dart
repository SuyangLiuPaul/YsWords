import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/services/song_player_service.dart';

/// 2026-08-23, "你看下为什么有些歌播放不了".
///
/// Measured before concluding: all 888 unique audio URLs in
/// assets/songs.json stream through the dev media proxy (206,
/// audio/mpeg — probed 2026-08-23), so no file is dead. The failures
/// are route failures: NATIVE streams directly from the church hosts,
/// and fydt.org + christiandiscipleschurch.org (one server) refuse
/// connections they classify as datacenter traffic — which includes
/// most VPN exits, and the report screenshots show a VPN in the
/// iPhone's status bar. cgdc songs kept playing; cdc/fydt songs sat at
/// 0:00 — "some songs won't play", pattern invisible from the phone.
///
/// The fix: on native, a failed or stalled track is retried ONCE
/// through the same-origin media proxy the web build already uses for
/// every stream. These tests pin the URL builder; the retry itself
/// lives in SongAudioHandler and is exercised on device.
void main() {
  group('nativeProxyFallbackUrl', () {
    // In a flutter test run kIsWeb is false, so the native branch is
    // the one under test.
    test('rewrites each church host through the qat proxy', () {
      expect(
        SongPlayerService.nativeProxyFallbackUrl(
            'https://www.christiandiscipleschurch.org/sites/default/files/music/mp3/D0180.mp3'),
        'https://yswords-qat.netlify.app/song-media/cdc/sites/default/files/music/mp3/D0180.mp3',
      );
      expect(
        SongPlayerService.nativeProxyFallbackUrl(
            'https://fydt.org/wp-content/uploads/2019/06/S03_006.mp3'),
        'https://yswords-qat.netlify.app/song-media/fydt/wp-content/uploads/2019/06/S03_006.mp3',
      );
      expect(
        SongPlayerService.nativeProxyFallbackUrl(
            'https://cgdc.hk/wp-content/uploads/2026/05/x.mp3'),
        'https://yswords-qat.netlify.app/song-media/cgdc/wp-content/uploads/2026/05/x.mp3',
      );
    });

    test('does not touch what no rule covers', () {
      // A local file path (downloaded song) or an unrelated host must
      // return null — "no second route", not a mangled URL.
      expect(
          SongPlayerService.nativeProxyFallbackUrl(
              '/var/mobile/Containers/song.mp3'),
          isNull);
      expect(
          SongPlayerService.nativeProxyFallbackUrl(
              'https://example.com/a.mp3'),
          isNull);
    });

    test('the fallback origin is not prod', () {
      // prod is pinned at v1.4.11, which predates the /song-media/*
      // rules — its proxy path serves index.html (text/html, verified
      // 2026-08-23). Falling back there would "succeed" with an HTML
      // document an audio element cannot play, which is harder to
      // diagnose than the original failure.
      final u = SongPlayerService.nativeProxyFallbackUrl(
          'https://fydt.org/x.mp3')!;
      expect(u, isNot(startsWith('https://yswords.netlify.app')));
      expect(u, isNot(startsWith('https://yswords-cn.netlify.app')));
    });
  });
}
