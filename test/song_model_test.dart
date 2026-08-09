import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/models/song.dart';
import 'package:yswords/services/song_player_service.dart';

/// 2026-08-09 (Songs v2). The previous Songs feature was deleted
/// because its catalogue rotted without anything catching it, so these
/// tests assert against the REAL `assets/songs.json` rather than a
/// fixture — a sync that produces a malformed or media-less catalogue
/// should fail CI here.
void main() {
  late Map<String, dynamic> doc;
  late List<Song> songs;

  setUpAll(() {
    final raw = File('assets/songs.json').readAsStringSync();
    doc = json.decode(raw) as Map<String, dynamic>;
    songs = (doc['songs'] as List)
        .map((e) => Song.fromJson(e as Map<String, dynamic>))
        .toList();
  });

  group('catalogue shape', () {
    test('every row decodes and carries the required fields', () {
      expect(songs, isNotEmpty);
      for (final s in songs) {
        expect(s.id, isNotEmpty, reason: 'id missing');
        expect(s.title, isNotEmpty, reason: '${s.id} has no title');
        expect(s.url, startsWith('http'), reason: '${s.id} has a bad url');
        expect(s.source, isNotEmpty, reason: '${s.id} has no source');
        expect(s.id, startsWith('${s.source}:'),
            reason: '${s.id} is not namespaced by its source');
      }
    });

    test('ids are unique', () {
      final ids = songs.map((s) => s.id).toSet();
      expect(ids.length, songs.length, reason: 'duplicate song ids');
    });

    test('all three catalogues are present', () {
      final sources = songs.map((s) => s.source).toSet();
      expect(sources, containsAll(<String>['fydt', 'cahaya', 'cdc']));
    });

    test('every language and source has a display label', () {
      for (final s in songs) {
        expect(songLanguageLabels, contains(s.language),
            reason: '${s.id}: language "${s.language}" has no label');
        expect(songSourceLabels, contains(s.source),
            reason: '${s.id}: source "${s.source}" has no label');
      }
    });

    test('every theme key has a localised label', () {
      for (final s in songs) {
        for (final t in s.themes) {
          expect(songThemeLabels, contains(t),
              reason: '${s.id}: theme "$t" has no label — '
                  'add it to songThemeLabels');
        }
      }
    });

    test('media URLs are absolute https', () {
      for (final s in songs) {
        for (final url in [
          s.audioUrl,
          s.instrumentalUrl,
          s.accompanimentUrl,
          s.videoUrl,
          s.scoreUrl,
          s.artworkUrl,
        ]) {
          if (url == null) continue;
          expect(url, startsWith('https://'),
              reason: '${s.id} has a non-https media URL: $url');
        }
      }
    });

    test('the catalogue actually carries media', () {
      // Guards against a sync that "succeeds" but strips every link —
      // exactly the state the feature was deleted in.
      final withAudio = songs.where((s) => s.hasAudio).length;
      final withVideo = songs.where((s) => s.hasVideo).length;
      final withScore = songs.where((s) => s.scoreUrl != null).length;
      expect(withAudio, greaterThan(songs.length ~/ 2),
          reason: 'fewer than half the catalogue has audio');
      expect(withVideo, greaterThan(50));
      expect(withScore, greaterThan(songs.length ~/ 2));
    });

    test('_meta reports counts that match the rows', () {
      final meta = doc['_meta'] as Map<String, dynamic>;
      expect(meta['count'], songs.length);
      final bySource = (meta['bySource'] as Map).cast<String, dynamic>();
      for (final entry in bySource.entries) {
        final actual = songs.where((s) => s.source == entry.key).length;
        expect(actual, entry.value,
            reason: '_meta.bySource[${entry.key}] disagrees with the rows');
      }
    });
  });

  group('Song.fromJson', () {
    test('reads the full fydt media set', () {
      final s = Song.fromJson(const {
        'id': 'fydt:122368',
        'title': '神的爱',
        'language': 'zh',
        'source': 'fydt',
        'sourceLabel': '福音电台 FYDT',
        'code': 'S04_021',
        'url': 'https://fydt.org/song/x/',
        'artist': '张梁美琳 / 张梁美琳',
        'composer': '张梁美琳',
        'durationSec': 227,
        'audioUrl': 'https://fydt.org/a.mp3',
        'instrumentalUrl': 'https://fydt.org/b.mp3',
        'videoUrl': 'https://fydt.org/c.mp4',
        'scoreUrl': 'https://fydt.org/d.pdf',
        'lyrics': 'line one\nline two',
        'themes': ['爱', '敬拜'],
        'verse': 'Colossians 1:9-11',
      });
      expect(s.hasPlayableAudio, isTrue);
      expect(s.hasAudio, isTrue);
      expect(s.hasVideo, isTrue);
      expect(s.hasAlternateMixes, isTrue);
      expect(s.durationLabel, '3:47');
      expect(s.verseBook, 'Colossians');
      expect(s.themes, ['爱', '敬拜']);
    });

    test('collapses fydt\'s duplicated "X / X" credit', () {
      final s = Song.fromJson(const {
        'id': 'fydt:1',
        'title': 't',
        'source': 'fydt',
        'url': 'https://x/',
        'artist': '张梁美琳 / 张梁美琳',
        'themes': <String>[],
      });
      expect(s.creditLine, '张梁美琳');
    });

    test('keeps genuinely different performer and writer', () {
      final s = Song.fromJson(const {
        'id': 'fydt:2',
        'title': 't',
        'source': 'fydt',
        'url': 'https://x/',
        'artist': '刘天惠 / 刘天惠, 郑倩敏',
        'themes': <String>[],
      });
      expect(s.creditLine, '刘天惠 · 刘天惠, 郑倩敏');
    });

    test('a SoundCloud row has audio but nothing streamable', () {
      final s = Song.fromJson(const {
        'id': 'cahaya:allah-kehidupanku',
        'title': 'Allah Kehidupanku',
        'language': 'id',
        'source': 'cahaya',
        'url': 'https://cahayapengharapan.org/pujian/',
        'soundcloudTrackId': '1018288369',
        'youtubeId': 'OzGNED4vl70',
        'themes': <String>[],
      });
      expect(s.hasAudio, isTrue);
      expect(s.hasPlayableAudio, isFalse,
          reason: 'SoundCloud exposes no stream URL — must not offer '
              'an inline play button');
      expect(s.hasVideo, isTrue);
      expect(s.soundcloudUrl,
          'https://api.soundcloud.com/tracks/1018288369');
      expect(s.youtubeUrl,
          'https://www.youtube.com/watch?v=OzGNED4vl70');
    });

    test('empty strings decode as null, not as present-but-blank', () {
      final s = Song.fromJson(const {
        'id': 'cdc:d0180',
        'title': 'A Consecrated Soul',
        'source': 'cdc',
        'url': 'https://x/',
        'audioUrl': '',
        'code': '   ',
        'lyrics': '',
        'themes': <String>[],
      });
      expect(s.audioUrl, isNull);
      expect(s.code, isNull);
      expect(s.lyrics, isNull);
      expect(s.hasAudio, isFalse);
    });

    test('durationLabel pads seconds and drops absent values', () {
      Song withDuration(int? d) => Song.fromJson({
            'id': 'x:1',
            'title': 't',
            'source': 'cdc',
            'url': 'https://x/',
            'durationSec': d,
            'themes': const <String>[],
          });
      expect(withDuration(227).durationLabel, '3:47');
      expect(withDuration(60).durationLabel, '1:00');
      expect(withDuration(5).durationLabel, '0:05');
      expect(withDuration(null).durationLabel, isNull);
      expect(withDuration(0).durationLabel, isNull);
    });
  });

  group('web playback proxy', () {
    // audioplayers_web forces crossOrigin='anonymous', and none of the
    // three church servers send Access-Control-Allow-Origin, so web
    // playback only works when the URL is rewritten to our own origin
    // (the /song-media/* rules in netlify.toml). If these mappings and
    // those rules ever drift apart, every play button on the web build
    // breaks — so pin them.
    test('every media host in the catalogue has a proxy mapping', () {
      final hosts = <String>{};
      for (final s in songs) {
        for (final url in [
          s.audioUrl,
          s.instrumentalUrl,
          s.accompanimentUrl,
        ]) {
          if (url != null) hosts.add(Uri.parse(url).host);
        }
      }
      const proxied = {
        'fydt.org',
        'www.christiandiscipleschurch.org',
        'cahayapengharapan.org',
      };
      expect(hosts.difference(proxied), isEmpty,
          reason: 'a playable host has no /song-media/* rule in '
              'netlify.toml — web playback would break for it');
    });

    test('rewrites to the same-origin path on web, passes through '
        'everywhere else', () {
      const url = 'https://fydt.org/wp-content/uploads/a.mp3';
      final resolved = SongPlayerService.resolvePlaybackUrl(url);
      if (kIsWeb) {
        expect(resolved, '/song-media/fydt/wp-content/uploads/a.mp3');
      } else {
        expect(resolved, url,
            reason: 'native has no CORS — must stream direct so the '
                'media never touches our bandwidth');
      }
    });

    test('an unknown host is passed through unchanged', () {
      const url = 'https://example.org/x.mp3';
      expect(SongPlayerService.resolvePlaybackUrl(url), url);
    });
  });

  group('localisation helpers', () {
    test('source and language labels resolve per locale', () {
      expect(localizedSongSource('fydt', 'en'), 'FYDT Gospel Radio');
      expect(localizedSongSource('fydt', 'zh-Hant'), '福音電台');
      expect(localizedSongLanguage('id', 'en'), 'Indonesian');
      expect(localizedSongLanguage('id', 'zh-Hans'), '印尼文');
    });

    test('unknown keys fall back to the key itself', () {
      expect(localizedSongSource('nope', 'en'), 'nope');
      expect(localizedSongTheme('未知', 'en'), '未知');
    });
  });
}
