import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Shema series is the 29 links the church published — no more, no
/// fewer.
///
/// 2026-08-19. Bentley, via the user: "All 29 youtube links." That
/// number is the check: 25 numbered messages (#7–#31) plus the four
/// whole-part compilations. It is worth pinning because the count is
/// the only independent confirmation that the list is complete — the
/// church's own page refuses datacenter IPs, so nothing here could be
/// compared against it directly.
void main() {
  late List<Map<String, dynamic>> shema;

  setUpAll(() {
    final doc = jsonDecode(File('assets/videos.json').readAsStringSync())
        as Map<String, dynamic>;
    shema = [
      for (final s in (doc['series'] as List).cast<Map<String, dynamic>>())
        if ((s['id'] as String).startsWith('shema-')) s,
    ];
  });

  test('all 29 published videos are present, and only those', () {
    final eps = shema.expand((s) => s['episodes'] as List).toList();
    expect(eps.length, 29, reason: 'Bentley published 29 links');

    final numbered = eps.where((e) => (e['number'] as int) != 0).toList();
    final compilations = eps.length - numbered.length;
    expect(numbered.length, 25);
    expect(compilations, 4);
  });

  test('the numbered messages run #7 to #31 with no gaps', () {
    // A gap would mean a message was missed; a duplicate would mean one
    // was filed under two parts.
    final numbers = shema
        .expand((s) => s['episodes'] as List)
        .map((e) => e['number'] as int)
        .where((n) => n != 0)
        .toList()
      ..sort();
    expect(numbers, List<int>.generate(25, (i) => i + 7));
  });

  test('numbering starts at 7 on purpose', () {
    // #1–#6 exist on the same channel but belong to a different series,
    // and the user chose not to include them. If someone later "fixes"
    // the gap by renumbering from 1, this fails and says why.
    final first = shema
        .expand((s) => s['episodes'] as List)
        .map((e) => e['number'] as int)
        .where((n) => n != 0)
        .reduce((a, b) => a < b ? a : b);
    expect(first, 7,
        reason: '#1–#6 belong to another series on the same channel and '
            'were deliberately excluded — do not renumber to close the gap');
  });

  test('each compilation sits last within its own part', () {
    // The user's call: "在每个最后面吧". A compilation in the middle
    // would read as an episode.
    for (final s in shema) {
      final eps = (s['episodes'] as List).cast<Map<String, dynamic>>();
      final flags = eps.map((e) => e['isCompilation'] == true).toList();
      expect(flags.where((f) => f).length, 1,
          reason: '${s['id']} should have exactly one compilation');
      expect(flags.last, isTrue,
          reason: '${s['id']} must end with its compilation');
    }
  });

  test('every episode has exactly one English YouTube track', () {
    for (final s in shema) {
      for (final e in (s['episodes'] as List).cast<Map<String, dynamic>>()) {
        final tracks = (e['tracks'] as List).cast<Map<String, dynamic>>();
        expect(tracks.length, 1, reason: '${e['id']} in ${s['id']}');
        expect(tracks.single['lang'], 'en');
        final id = tracks.single['youtubeId'] as String;
        expect(RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id), isTrue,
            reason: '"$id" is not a YouTube id');
      }
    }
  });

  test('no video id appears twice anywhere in the file', () {
    final doc = jsonDecode(File('assets/videos.json').readAsStringSync())
        as Map<String, dynamic>;
    final ids = <String>[];
    for (final s in (doc['series'] as List).cast<Map<String, dynamic>>()) {
      for (final e in (s['episodes'] as List).cast<Map<String, dynamic>>()) {
        for (final t in (e['tracks'] as List).cast<Map<String, dynamic>>()) {
          ids.add(t['youtubeId'] as String);
        }
      }
    }
    expect(ids.length, ids.toSet().length,
        reason: 'a duplicated id means one recording is filed twice');
  });

  test('every episode carries a real title', () {
    for (final s in shema) {
      for (final e in (s['episodes'] as List).cast<Map<String, dynamic>>()) {
        final en = (e['titles'] as Map)['en'] as String;
        expect(en.trim(), isNotEmpty);
        expect(en, isNot(contains('FETCH_FAILED')));
      }
    }
  });
}
