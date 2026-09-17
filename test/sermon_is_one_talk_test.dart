/// ONE TALK, ONE TIMELINE.
///
/// 2026-09-18 「Sword和Words有分几段的 可以帮我合并 并且上次听到哪里都记录
/// 下来吗」, with a screenshot of the player reading `0:00 / 0:00  第 2 段
/// / 共 3 段`.
///
/// The files are tape sides — part b opens mid-sentence where part a ran
/// out — and the player has always rolled from one into the next. What
/// had not been merged was the READING: the clock restarted at every
/// boundary, so a listener forty minutes into a talk saw four, and the
/// counter beside it described the app's file layout rather than their
/// place in the sermon.
///
/// The index carries bytes and no durations, so the combined length
/// starts as arithmetic on the corpus's fixed 32 kbps and is replaced,
/// part by part, with what the player measures.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:yswords/services/sermon_audio_service.dart';

import 'support/fake_song_playback_engine.dart';

void main() {
  SermonAudioPart part(String p, int bytes) =>
      SermonAudioPart(part: p, file: '$p.mp3', bytes: bytes);

  group('where a moment in the talk falls', () {
    // Three ten-minute parts.
    final lengths = [
      const Duration(minutes: 10),
      const Duration(minutes: 10),
      const Duration(minutes: 10),
    ];

    test('the start is the start of the first part', () {
      expect(SermonAudioService.locate(lengths, Duration.zero),
          (0, Duration.zero));
    });

    test('a moment inside a part keeps its offset', () {
      expect(SermonAudioService.locate(lengths, const Duration(minutes: 4)),
          (0, const Duration(minutes: 4)));
      expect(SermonAudioService.locate(lengths, const Duration(minutes: 14)),
          (1, const Duration(minutes: 4)));
      expect(SermonAudioService.locate(lengths, const Duration(minutes: 25)),
          (2, const Duration(minutes: 5)));
    });

    test('a boundary belongs to the part that is starting', () {
      // Ten minutes in is the first frame of part b, not the last of a.
      expect(SermonAudioService.locate(lengths, const Duration(minutes: 10)),
          (1, Duration.zero));
    });

    test('before the beginning is the beginning', () {
      expect(SermonAudioService.locate(lengths, const Duration(minutes: -5)),
          (0, Duration.zero));
    });

    test('past the end is the end of the last part, not an empty index', () {
      final (index, offset) =
          SermonAudioService.locate(lengths, const Duration(minutes: 99));
      expect(index, 2);
      expect(offset, const Duration(minutes: 10));
    });

    test('a single part is the whole talk', () {
      expect(
          SermonAudioService.locate(
              [const Duration(minutes: 10)], const Duration(minutes: 3)),
          (0, const Duration(minutes: 3)));
    });

    test('no parts answers rather than throwing', () {
      expect(SermonAudioService.locate(const [], const Duration(minutes: 3)),
          (0, Duration.zero));
    });
  });

  group('how long a part is before anyone has played it', () {
    final svc = SermonAudioService.withEngine(FakeSongPlaybackEngine());

    test('a size at the corpus bitrate is a duration', () {
      // 32 kbps mono is 4000 bytes a second; 2.4 MB is ten minutes.
      expect(svc.lengthOf(part('a', 2400000)), const Duration(minutes: 10));
    });

    test('a real file from the index lands in the right minutes', () {
      // 002a, the first sermon in `audio_index.json`: 6,587,009 bytes.
      final d = svc.lengthOf(part('a', 6587009));
      expect(d.inMinutes, inInclusiveRange(26, 28),
          reason: 'a 6.5 MB tape side at 32 kbps is about 27 minutes; if '
              'this is far out, the corpus is not the bitrate this '
              'estimate assumes');
    });

    test('a part with no size is not a negative length', () {
      expect(svc.lengthOf(part('a', 0)), Duration.zero);
    });
  });
  group('on the real corpus', () {
    // Read the index off disk rather than `svc.load()`: that goes
    // through `rootBundle`, which this codebase documents as unreliable
    // inside a plain test (see `seedForTest`'s doc comment and
    // `sermon_audio_index_test.dart`'s header) and which swallows a
    // missing-asset error rather than throwing it — the group would
    // fail confusingly at 'greaterThan(1)' instead of at the read.
    final raw = File('assets/sermons/audio_index.json').readAsStringSync();
    final index = (json.decode(raw) as Map<String, dynamic>).map(
      (k, v) => MapEntry(
        k,
        (v as List)
            .map((e) => SermonAudioPart.fromJson(e as Map<String, dynamic>))
            .toList(),
      ),
    );

    test('a multi-part sermon reads as one length, not the first file', () {
      final svc = SermonAudioService.withEngine(FakeSongPlaybackEngine());
      index.forEach(svc.seedForTest);
      // 002 is the first sermon in the index and has two tape sides.
      final parts = svc.partsOf('002');
      expect(parts.length, greaterThan(1),
          reason: 'this test needs a sermon that is actually split');
      final whole = parts.fold<Duration>(
          Duration.zero, (a, p) => a + svc.lengthOf(p));
      expect(whole, greaterThan(svc.lengthOf(parts.first)),
          reason: 'the whole talk must be longer than its first side');
      // Every sermon in the index: no part may be zero-length, or the
      // combined timeline has a gap the slider cannot express.
      var sermons = 0;
      for (final id in index.keys) {
        final ps = svc.partsOf(id);
        if (ps.isEmpty) continue;
        sermons++;
        for (final p in ps) {
          expect(svc.lengthOf(p), greaterThan(Duration.zero),
              reason: '$id part ${p.part} has no size, so the talk it '
                  'belongs to has a timeline with a hole in it');
        }
      }
      expect(sermons, 289, reason: 'the index did not load as expected');
    });
  });
}
