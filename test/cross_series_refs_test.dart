import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The 在十字架下 episodes now carry the scripture they are built on, so a
/// reader can open the passage instead of hearing it quoted and having
/// to go looking.
///
/// The queue's instruction was to verify every reference against our own
/// text before shipping, because "a citation that opens the wrong
/// passage is P0, and this is the exact shape of that defect". That was
/// not a formality: **the source page carries one.**
/// `yahwehdehua.net/assets/page/easter/` cites 约 19:28 twice in the
/// Chinese block of episode 9 — once for 「我渴了」, correctly, and once
/// for 「成了！」, which is 19:30. The English block of the same episode
/// has it right. Transcribed faithfully, tapping 「成了！」 would have
/// opened "I thirst".
///
/// So this file checks the data against the Bible asset rather than
/// against the page it came from.
void main() {
  final doc = json.decode(File('assets/videos.json').readAsStringSync())
      as Map<String, dynamic>;
  final cross = (doc['series'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((s) => s['id'] == 'cross');
  final episodes = (cross['episodes'] as List).cast<Map<String, dynamic>>();

  const enToZh = {
    'Matthew': '马太福音',
    'Mark': '马可福音',
    'Luke': '路加福音',
    'John': '约翰福音',
    'Psalms': '诗篇',
  };

  test('all ten episodes carry a refs list', () {
    expect(episodes, hasLength(10));
    for (final e in episodes) {
      expect(e['refs'], isA<List>(),
          reason: 'episode ${e['number']} has no refs key at all — the '
              'absence of a reference has to be an empty list, not a '
              'missing field, or the UI cannot tell them apart');
    }
  });

  test('every reference resolves in our own Bible', () {
    final verses =
        json.decode(File('assets/cuvs-yhwh.json').readAsStringSync()) as List;
    final present = <String>{
      for (final v in verses)
        '${(v as Map)['book']}|${v['chapter']}|${v['verse']}'
    };
    var checked = 0;
    for (final e in episodes) {
      for (final r in (e['refs'] as List).cast<Map<String, dynamic>>()) {
        final zh = enToZh[r['book']];
        expect(zh, isNotNull,
            reason: 'unmapped book ${r['book']} in episode ${e['number']}');
        expect(present, contains('$zh|${r['chapter']}|${r['verse']}'),
            reason: 'episode ${e['number']} cites ${r['book']} '
                '${r['chapter']}:${r['verse']}, which is not a verse');
        checked++;
      }
    }
    expect(checked, 17);
  });

  test('episode 9 cites John 19:30 for "It is finished", not 19:28', () {
    // The specific error on the source page. If someone re-transcribes
    // from it, this is what catches them.
    final ep9 = episodes.firstWhere((e) => e['number'] == 9);
    final refs = (ep9['refs'] as List).cast<Map<String, dynamic>>();
    expect(refs, hasLength(2));
    expect(refs[0], {'book': 'John', 'chapter': 19, 'verse': 28});
    expect(refs[1], {'book': 'John', 'chapter': 19, 'verse': 30},
        reason: 'the page repeats 19:28 here; 19:30 is 「成了！」');
  });

  test('episode 1 has none, and that is the page, not a gap', () {
    final ep1 = episodes.firstWhere((e) => e['number'] == 1);
    expect(ep1['refs'], isEmpty);
  });

  test('episode 10 cites Luke 23:46 alone', () {
    // A first extraction ran past the block boundary into the song
    // lyrics and picked up Lk 9:22-23 and Acts 5:30-31. It does not
    // cite those.
    final ep10 = episodes.firstWhere((e) => e['number'] == 10);
    expect(ep10['refs'], [
      {'book': 'Luke', 'chapter': 23, 'verse': 46}
    ]);
  });
}
