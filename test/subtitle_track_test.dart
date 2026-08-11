import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/models/subtitle_track.dart';

/// Guards the generated subtitle files and the parser that reads them.
///
/// These captions are the church's own words placed on a clock derived
/// from speech recognition, so the failure mode is not "no subtitles" —
/// it is a subtitle that is *slightly* wrong, attributing a sentence to
/// the wrong moment. Every property below is one that went wrong at
/// least once while building `scripts/align_subtitles.py`.
void main() {
  final files = Directory('assets/subtitles/01')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.vtt'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('the expected five tracks are shipped', () {
    final names = files.map((f) => f.uri.pathSegments.last).toSet();
    expect(
      names,
      {
        'cmn.zh-Hant.vtt',
        'cmn.zh-Hans.vtt',
        'yue.zh-Hant.vtt',
        'yue.zh-Hans.vtt',
        'en.en.vtt',
      },
      reason: 'each recording carries captions only in the language it '
          'is spoken in — the Chinese and English scripts do not '
          'correspond paragraph-for-paragraph',
    );
  });

  for (final f in files) {
    final name = f.uri.pathSegments.last;
    group(name, () {
      late SubtitleTrack track;
      setUpAll(() => track = SubtitleTrack.parse(f.readAsStringSync()));

      test('parses to a useful number of cues', () {
        expect(track.cues.length, greaterThan(100));
      });

      test('cues never overlap and never run backwards', () {
        for (var i = 0; i < track.cues.length; i++) {
          final c = track.cues[i];
          expect(c.end, greaterThan(c.start),
              reason: 'cue $i has no duration');
          if (i > 0) {
            expect(c.start, greaterThanOrEqualTo(track.cues[i - 1].end),
                reason: 'cue $i starts before cue ${i - 1} ends — a '
                    'player shows overlapping cues stacked or drops one');
          }
        }
      });

      test('every cue is on screen long enough to read', () {
        // 0.5s was the floor the aligner had to enforce: an early pass
        // emitted cues of 0.13s and 0.05s, present and gone unread.
        for (final c in track.cues) {
          expect(c.end - c.start,
              greaterThanOrEqualTo(const Duration(milliseconds: 500)),
              reason: 'cue "${c.text}" lasts ${c.end - c.start}');
        }
      });

      test('nothing outlives its recording', () {
        // The videos are 17:17 / 17:18 / 18:35. A first version pushed
        // overlapping cues forward and accumulated 2.5 minutes of drift,
        // ending at 21.1 minutes on an 18.6-minute video.
        expect(track.cues.last.end,
            lessThan(const Duration(minutes: 19)),
            reason: 'captions run past the end of the video');
      });

      test('no stage directions', () {
        // "(Back to the slide of the Greek the only true God)" is an
        // instruction to whoever cut the video. Shown as a caption it
        // claims the speaker said it.
        for (final c in track.cues) {
          expect(RegExp(r'^\s*[（(\[].*[）)\]]\s*$').hasMatch(c.text), isFalse,
              reason: 'stage direction shown as speech: "${c.text}"');
        }
      });

      test('lookup finds the cue covering a time', () {
        final c = track.cues[track.cues.length ~/ 2];
        final mid = c.start +
            Duration(microseconds: (c.end - c.start).inMicroseconds ~/ 2);
        expect(track.cueAt(mid)?.text, c.text);
      });
    });
  }

  test('Traditional and Simplified differ in text but not in timing', () {
    final hant = SubtitleTrack.parse(
        File('assets/subtitles/01/cmn.zh-Hant.vtt').readAsStringSync());
    final hans = SubtitleTrack.parse(
        File('assets/subtitles/01/cmn.zh-Hans.vtt').readAsStringSync());

    expect(hans.cues.length, hant.cues.length);
    for (var i = 0; i < hant.cues.length; i++) {
      expect(hans.cues[i].start, hant.cues[i].start,
          reason: 'the two are the same words — the clock must match');
    }
    // They are the same sentences in two scripts, so most lines differ
    // but a line of pure punctuation or digits legitimately will not.
    final differing = [
      for (var i = 0; i < hant.cues.length; i++)
        if (hant.cues[i].text != hans.cues[i].text) i
    ];
    expect(differing.length, greaterThan(hant.cues.length ~/ 2),
        reason: 'the Simplified file looks like a copy of the '
            'Traditional one — conversion did not run');
  });

  test('a malformed file yields no cues rather than throwing', () {
    // Captions are an accessory; a broken one must never be able to
    // take down the video it belongs to.
    expect(SubtitleTrack.parse('not a vtt at all').cues, isEmpty);
    expect(SubtitleTrack.parse('WEBVTT\n\n99:99 --> nonsense\nhi').cues,
        isEmpty);
  });
}
