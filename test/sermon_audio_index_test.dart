import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/services/sermon_audio_service.dart';

/// Sermon audio went from "written and dormant" to live on 2026-09-02:
/// the user pointed at the church's own public page
/// (「录音你可以直接用我们教会的」), which already serves all 589 MP3s with
/// range support and a one-year cache header. Nothing to host, no bill.
///
/// Two things this pins, and the second is the one that would hurt.
///
/// **The URL has to address a nested path.** The files sit in 20
/// category folders, so the old `baseUrl + filename` shape could never
/// resolve. And the filenames carry apostrophes, brackets and commas, so
/// the encoding has to be per-segment — `Uri.encodeComponent` over the
/// whole path escapes the slashes and yields one unrequestable segment.
///
/// **The index used to double-count.** It claimed 661 parts; the church
/// publishes 589, and the 72 extras were apostrophe variants of files
/// already in the list — byte-identical, same tape side. Unnoticed, a
/// two-part sermon would have played as four, playing the whole thing
/// twice. `tools/build_sermon_audio_index.py` drops them and refuses to
/// write if a part is neither published nor a duplicate of one that is.
void main() {
  final raw =
      File('assets/sermons/audio_index.json').readAsStringSync();
  final index = (json.decode(raw) as Map<String, dynamic>).map(
    (k, v) => MapEntry(
      k,
      (v as List)
          .map((e) => SermonAudioPart.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
  );

  test('all 289 sermons have audio, and none is empty', () {
    expect(index, hasLength(289));
    final empty = index.entries.where((e) => e.value.isEmpty).map((e) => e.key);
    expect(empty, isEmpty,
        reason: 'a sermon with an empty part list shows a play button that '
            'does nothing');
  });

  test('589 parts — the 72 duplicates stay dropped', () {
    final total = index.values.fold<int>(0, (n, p) => n + p.length);
    expect(total, 589,
        reason: 'was 661 before 2026-09-02; 72 were apostrophe-variant '
            'twins. A regression here plays sermons through twice.');
  });

  test('no sermon lists the same tape side twice', () {
    // The shape the duplicates took: two entries both marked part "a".
    final offenders = <String>[];
    index.forEach((sid, parts) {
      final sides = parts.map((p) => p.part).toList();
      if (sides.toSet().length != sides.length) offenders.add('$sid $sides');
    });
    expect(offenders, isEmpty);
  });

  test('every part carries a real nested path', () {
    for (final e in index.entries) {
      for (final p in e.value) {
        expect(p.path, startsWith('/sites/default/files/ehhc_mp3_sermons/'),
            reason: '${e.key} part ${p.part} has no path — urlFor would '
                'fall back to the flat shape and 404');
        expect(p.path, endsWith('.mp3'));
        expect(p.path.split('/').length, greaterThan(5),
            reason: 'the category folder is missing from ${p.path}');
      }
    }
  });

  test('parts are in tape order', () {
    for (final e in index.entries) {
      final sides = e.value.map((p) => p.part).toList();
      final sorted = [...sides]..sort();
      expect(sides, sorted,
          reason: '${e.key} would play side b before side a');
    }
  });

  group('urlFor', () {
    test('encodes each segment, not the whole path', () {
      const part = SermonAudioPart(
        part: 'a',
        file: "006a_The_Lord's_Concept.mp3",
        bytes: 1,
        path: "/sites/default/files/ehhc_mp3_sermons/09_Matthew_and_Luke/"
            "006a_The_Lord's_Concept.mp3",
      );
      final url = SermonAudioService.urlFor(part);
      expect(url, startsWith('https://'));
      expect(url, contains('/ehhc_mp3_sermons/09_Matthew_and_Luke/'),
          reason: 'the slashes were escaped — one unrequestable segment');
      expect(url, isNot(contains('%2F')));
      expect(url, endsWith('.mp3'));
    });

    test('the real index produces plausible URLs everywhere', () {
      for (final e in index.entries) {
        for (final p in e.value) {
          final url = SermonAudioService.urlFor(p);
          expect(url, isNot(contains('%2F')), reason: '${e.key} ${p.part}');
          expect(url, endsWith('.mp3'), reason: '${e.key} ${p.part}');
          expect(Uri.tryParse(url), isNotNull, reason: url);
        }
      }
    });

    test('falls back to the flat shape when path is absent', () {
      const legacy =
          SermonAudioPart(part: 'a', file: 'x.mp3', bytes: 1);
      expect(SermonAudioService.urlFor(legacy), endsWith('x.mp3'));
    });
  });

  test('the service is configured — no empty base', () {
    expect(SermonAudioService.isConfigured, isTrue,
        reason: 'baseUrl went back to empty, which silently hides every '
            'play button again');
    expect(SermonAudioService.baseUrl, isNot(endsWith('/')),
        reason: 'paths already begin with /, so a trailing slash here '
            'produces a double slash');
  });
}
