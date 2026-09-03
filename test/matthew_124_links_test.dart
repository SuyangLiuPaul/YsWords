import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yswords/services/sermon_service.dart';

/// Pastor Eric's Matthew series exists twice: as our 289 transcribed
/// cassette recordings, and as the church's *124 Messages*, a
/// nine-volume written edition that came back online on 2026-09-02
/// after being unreachable for seventeen straight attempts.
///
/// **36 recordings are provably the same sermon as one of the 124.
/// Nothing else is linked.** The other 88 messages and 253 sermons show
/// no link at all, on purpose: the written edition is re-titled and cut
/// finer than the recordings, so most pairings are guesses, and a link
/// that opens a message about a different talk is the same class of
/// error as a citation that opens the wrong verse.
///
/// This file exists because the mapping is derived by scraping a site
/// we do not control, and a re-scrape must not be able to change it
/// quietly. `tools/reconcile_matthew_124.py --emit` rebuilds the asset;
/// if the church renumbers, retitles, fixes a typo or reorders the
/// listing, the count or one of the pinned pairs moves and this fails.
///
/// **Why 36 and not 61.** The tool's four-tier survey reports 61
/// "exact" and that number is in the queue doc, but it is not a
/// shippable set: its key is `(book, chapter, FIRST verse)`, so
/// `Matthew 3:13-17` and `Matthew 3:13 - 4:17` are the same passage to
/// it, and messages 006, 007 and 008 all land on our single recording
/// 002. Eight of our sermons were claimed by two or three messages
/// each. See the tool's docstring for the five rules that cut it to 36.
void main() {
  final raw = File('assets/sermons/matthew_124.json').readAsStringSync();
  final doc = json.decode(raw) as Map<String, dynamic>;
  final links = (doc['links'] as Map<String, dynamic>).map(
    (k, v) => MapEntry(
      k,
      MatthewMessage.fromJson(v as Map<String, dynamic>),
    ),
  );
  final index = (json.decode(
    File('assets/sermons/index.json').readAsStringSync(),
  ) as List)
      .cast<Map<String, dynamic>>();

  test('36 links, out of the church\'s 124 and our 289', () {
    expect(doc['messageCount'], 124,
        reason: 'the tool refuses to emit unless the listing still has '
            'exactly 124 messages');
    expect(links, hasLength(36),
        reason: 'A CHANGE HERE IS NOT A ROUTINE UPDATE. 36 is what '
            'survived: identical passage range, no partial-verse '
            'suffix, no rival on either side at the same '
            'book+chapter+first verse, and the preaching date on their '
            'page equal to ours. If a re-scrape moves this number, read '
            'the diff before accepting it — a link on the wrong sermon '
            'is worse than a missing one.');
  });

  test('every link points at a sermon that exists', () {
    final ids = {for (final s in index) s['id'] as String};
    final orphans = links.keys.where((k) => !ids.contains(k)).toList();
    expect(orphans, isEmpty,
        reason: 'a link keyed to a sermon id we no longer ship renders '
            'nowhere and hides a re-ingestion that changed our ids');
  });

  test('no message is used twice', () {
    // The failure the whole rule is built to prevent, in its most
    // visible form: two of our recordings both pointing at message 007
    // means at least one of them is wrong.
    final used = links.values.map((m) => m.message).toList();
    expect(used.toSet(), hasLength(used.length),
        reason: 'one written message cannot be two different recordings');
  });

  test('every link carries a real message page and PDF', () {
    links.forEach((sid, m) {
      // /content/matthew-NNN, not /matthew-NNN. The listing's hrefs are
      // relative to /content/ and the absolute form 404s — the tool
      // used to build the broken one.
      expect(m.url, 'https://www.christiandiscipleschurch.org/content/'
          'matthew-${m.message}',
          reason: '$sid: message page URL');
      expect(m.pdf, endsWith('/matthew_sermon_${m.message}.pdf'),
          reason: '$sid: PDF and page must be the same message');
      expect(m.title, isNotEmpty, reason: '$sid: their title');
      expect(m.ref, isNotEmpty, reason: '$sid: their reference');
    });
  });

  test('the preaching dates still agree — this is the independent check',
      () {
    // Rule 5, re-asserted against our own index. Nothing about a date
    // derives from a passage, so this is the one piece of evidence that
    // does not restate the rule that made the pair. 36 of the 37 pairs
    // that survived the passage rules agreed to the day.
    final byId = {for (final s in index) s['id'] as String: s};
    links.forEach((sid, m) {
      expect(m.date, byId[sid]!['date'],
          reason: '$sid vs their message ${m.message}: the pair was '
              'admitted BECAUSE these agreed');
    });
  });

  test('the pairs that were rejected stay rejected', () {
    // Each of these was a plausible link and each is wrong or
    // unprovable. They are named individually so that a re-scrape
    // cannot quietly re-admit one.
    //
    // 002  messages 006, 007 and 008 all expound from Matthew 3:13;
    //      one recording cannot be three messages.
    // 059  message 026 is Matthew 11:12 and 027 is 11:12b. The
    //      passage rule picks 026 — but our 059 is titled "Take up
    //      your cross", which is 027's title, not 026's.
    // 106  message 046 is "The Syrophoenician Woman's Faith", which is
    //      our 106's title, but its reference reads "Matthew 15:21-18"
    //      — a typo the tool refuses to repair. That left 047 looking
    //      unique, and 047 is a different message.
    // 139  message 090 matches on passage but says it was preached on
    //      3 May 1981 where our index says 1981-05-13.
    // 155  messages 107 and 108 are both Matthew 24:34.
    // 162  messages 119 and 120 are both Luke 22:31-34.
    // 169  messages 081 and 082 are both John 2:17 + Matthew 21:12-13,
    //      with the same title.
    for (final sid in ['002', '059', '106', '139', '155', '162', '169']) {
      expect(links.containsKey(sid), isFalse,
          reason: '$sid was rejected deliberately — see the comment '
              'above and the tool docstring before linking it');
    }
  });

  test('a sample of specific pairs', () {
    // Spread across the nine volumes and across all four gospels our
    // Matthew series draws on, so a wholesale reordering of the church
    // listing cannot slip through by luck.
    const expected = {
      '004': '010', // Luke 4:5-13   Temptation after Baptism #2
      '005': '011', // Matthew 3:15, 4:17
      '053': '020', // Matthew 10:26-33  ours "Fear not"
      '071': '039', // Matthew 12:46-50  The Will of God
      '117': '066', // Matthew 18:21-35  ours "Forgiving others"
      '129': '079', // Mark 10:46-52
      '144': '095', // Matthew 23:33     ours "Hell"
      '153': '106', // Mark 13:33-37
      '164': '121', // Matthew 26:41     Crucify the Flesh
      '329': '097', // John 15
    };
    expected.forEach((sid, message) {
      expect(links[sid]?.message, message,
          reason: 'our sermon $sid is the church\'s message $message');
    });
  });

  group('the page shows nothing when there is no confirmed match', () {
    // `_WrittenEditionCard` is private to its page, and the page needs
    // the sermon service, the settings provider and a loaded body
    // before it paints — so these read the source, the same way
    // test/sermon_body_typography_test.dart does. What is at risk is
    // not the layout, it is someone making the card render a fallback.
    final src = File('lib/pages/sermon_detail_page.dart').readAsStringSync();

    test('the card is gated on a non-null lookup', () {
      expect(src, contains('if (_written != null) ...['),
          reason: '253 of the 289 sermons must render no link at all');
    });

    test('a null lookup is not turned into a placeholder', () {
      // The failure mode to guard: "no confirmed match" becoming a
      // link to the 124 listing, or to a chapter-tier guess. Either
      // one puts the reader in front of a different sermon.
      expect(src.contains('124-messages'), isFalse,
          reason: 'linking the listing itself is the browsable-series '
              'option the user declined on 2026-09-03');
    });

    test('the lookup cannot fail the sermon body', () {
      // The written edition loads on its own, so a slow or missing
      // asset delays nothing and cannot surface as "this sermon failed
      // to load".
      expect(src, contains('_loadWrittenEdition()'));
      expect(src, contains('if (!mounted || w == null) return;'));
    });
  });

  test('the asset is declared in pubspec', () {
    // Same trap as assets/sermons/audio_index.json, which was missing
    // from pubspec and whose absence was silent: the service catches
    // the load failure and falls back to an empty map, so every sermon
    // simply shows no link — indistinguishable from "we confirmed
    // nothing".
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('assets/sermons/matthew_124.json'));
  });
}
