import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The catalogue said for a month that CDC publishes no cover art. It
/// does — a per-song 600×300 photograph with the song's title set over
/// it, at `/sites/default/files/music/jpg/<CODE>.jpg`, linked from an
/// `<img>` on every song page.
///
/// The claim was never checked. It was made on 2026-08-11, while
/// `christiandiscipleschurch.org` was refusing every connection from
/// the machine doing the investigating, and the queue said so at the
/// time — "Re-check CDC when the host is reachable... 'CDC has no
/// images' is unverified rather than established." Re-checked
/// 2026-09-03: 191 of the 298 CDC songs have a cover that resolves.
/// That is the largest single artwork gap in the catalogue, and it was
/// closed by reading the pages, not by adding a feature.
///
/// `tools/add_cdc_artwork.py` wrote them and refuses to write a
/// partial survey. `scripts/sync_songs.py` now reads and verifies the
/// same field so the published catalogue keeps it — but that copy is
/// the reference implementation, and the run that publishes lives in
/// yswords-data. Until that side ships the change, a snapshot pull
/// would silently blank all 191. This test is what makes that loud.
void main() {
  final doc = json.decode(File('assets/songs.json').readAsStringSync())
      as Map<String, dynamic>;
  final songs = (doc['songs'] as List).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> cdc() =>
      songs.where((s) => s['source'] == 'cdc').toList();

  test('CDC songs carry the cover art the church publishes', () {
    final withArt =
        cdc().where((s) => s['artworkUrl'] != null).toList();
    // 191 at the time of writing. Asserted as a floor, not an equality:
    // the church uploading the 92 missing English covers should not
    // break the build, and losing them should.
    expect(withArt.length, greaterThanOrEqualTo(191),
        reason: 'CDC artwork went missing from the snapshot — most likely '
            'a pull from yswords-data before that repo carried the '
            'sync change. Re-run tools/add_cdc_artwork.py.');
  });

  test('every CDC cover points at the church music/jpg directory', () {
    for (final s in cdc()) {
      final url = s['artworkUrl'] as String?;
      if (url == null) continue;
      expect(url, startsWith('https://www.christiandiscipleschurch.org/'),
          reason: '${s['id']} artwork is not on the church host');
      expect(url, contains('/sites/default/files/music/jpg/'),
          reason: '${s['id']} artwork is not from the covers directory — a '
              'sheet-music PNG or a theme image would render as a cover');
      expect(url.toLowerCase(), endsWith('.jpg'));
    }
  });

  test('the cover filename matches the song it is on', () {
    // The one way a page-scrape can go wrong quietly: picking up the
    // <img> from a related-songs block and pairing D0180's cover with
    // D0182. The church names the file for the code, so this is
    // checkable without another fetch.
    final mismatched = <String>[];
    for (final s in cdc()) {
      final url = s['artworkUrl'] as String?;
      final code = s['code'] as String?;
      if (url == null || code == null) continue;
      final file = url.split('/').last.split('.').first;
      if (file.toUpperCase() != code.toUpperCase()) {
        mismatched.add('${s['id']} code=$code file=$file');
      }
    }
    expect(mismatched, isEmpty);
  });

  test('the 15 hymns are the ones without covers, and keep their scores', () {
    // h01–h15 live in `hymns/`, not `music/`, and have no cover there.
    // They are the reason "every CDC song has artwork" is not the
    // assertion — and the reason to check their scores survived, since
    // this ran over the same file tools/add_cdc_hymn_scores.py wrote.
    final hymns = cdc()
        .where((s) => RegExp(r'^cdc:h\d+$').hasMatch(s['id'] as String))
        .toList();
    expect(hymns, hasLength(15));
    for (final s in hymns) {
      expect(s['artworkUrl'], isNull,
          reason: '${s['id']} got a cover from somewhere unexpected');
      expect(s['scoreUrl'], isNotNull,
          reason: '${s['id']} lost the score add_cdc_hymn_scores.py set');
    }
  });

  test('no CDC song gained or lost anything else', () {
    // The patcher edits one field on 191 of 621 entries in an 800 KB
    // file. Cheap structural check that it did not reshape the rest.
    expect(songs, hasLength(621));
    expect(cdc(), hasLength(298));
    for (final s in cdc()) {
      expect(s['url'], isNotNull);
      expect(s['sourceLabel'], isNotNull);
    }
  });
}
