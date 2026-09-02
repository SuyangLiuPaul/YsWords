import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/models/video_series.dart';

/// The 在十字架下 references shipped in `assets/videos.json` on
/// 2026-09-02 and were invisible for a day, because `VideoEpisode`
/// simply did not parse the `refs` key — the asset grew a field and
/// nothing read it, which no existing test could notice.
///
/// `test/cross_series_refs_test.dart` checks the DATA (that every
/// reference resolves in our own Bible, including the 19:30 correction
/// to the source page's error). This one checks the MODEL, so the two
/// halves cannot drift apart again.
void main() {
  final doc = json.decode(File('assets/videos.json').readAsStringSync())
      as Map<String, dynamic>;
  final series = VideoSeries.listFromJson(doc);
  final cross = series.firstWhere((s) => s.id == 'cross');

  test('the model parses refs off the asset', () {
    final total =
        cross.episodes.fold<int>(0, (n, e) => n + e.refs.length);
    expect(total, 17,
        reason: 'the asset carries 17 references; the model must see '
            'all of them, not silently drop the key');
  });

  test('episode 1 parses as an empty list, not as missing', () {
    final ep1 = cross.episodes.firstWhere((e) => e.number == 1);
    expect(ep1.refs, isEmpty);
  });

  test('episode 9 carries John 19:28 and 19:30, in that order', () {
    // The source page repeats 19:28 for 「成了！」, which is 19:30.
    // If a re-import ever follows the page instead of our own text,
    // this fails here as well as in cross_series_refs_test.
    final ep9 = cross.episodes.firstWhere((e) => e.number == 9);
    expect(ep9.refs.map((r) => '${r.book} ${r.chapter}:${r.verse}'),
        ['John 19:28', 'John 19:30']);
  });

  test('every ref carries an English book name', () {
    // The chip localises at render time via localeAwareBookName, which
    // takes an ENGLISH book. A Chinese book name in the asset would
    // render as-is in English and fail to resolve on tap.
    final ascii = RegExp(r'^[A-Za-z0-9 ]+$');
    for (final e in cross.episodes) {
      for (final r in e.refs) {
        expect(ascii.hasMatch(r.book), isTrue,
            reason: 'episode ${e.number} has a non-English book '
                '"${r.book}" — the chip cannot resolve it');
      }
    }
  });

  test('an episode with no refs key at all still parses', () {
    // 獨一真神's episodes have never carried the key. Parsing must not
    // require it.
    final other = series.where((s) => s.id != 'cross');
    expect(other, isNotEmpty);
    for (final s in other) {
      for (final e in s.episodes) {
        expect(e.refs, isEmpty);
      }
    }
  });
}
