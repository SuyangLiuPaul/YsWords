import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:yswords/services/sermon_library_service.dart';

/// The sermons this app holds twice, and what it does about them.
///
/// **Nothing is hidden, at any tier.** Which of the two texts is the
/// better one has been ruled both ways in one day — first the app's
/// copy, then the library's, on the evidence that the app's Chinese
/// bodies are machine translations of a Whisper transcript while the
/// library's are human work. Both rulings are about which text to
/// KEEP, and neither is a reason for this surface to delete a record:
/// a record wrongly shown is a duplicate a reader can see and
/// complain about, while a record wrongly hidden is a sermon that
/// ceases to exist on every screen with nobody to notice. That
/// asymmetry survived the inversion, and it is what these tests pin.
///
/// **What `confirmed` buys is a link.** `refs.json` grades 105
/// candidate pairs `confirmed` 22, `probable` 36, `possible` 4, `weak`
/// 43; only the first tier is established, and a separate pass is
/// adjudicating the rest in the same file. So the link is read from
/// the data at load time and appears or vanishes as that pass lands,
/// with no code change and no id written down anywhere.
///
/// Nothing here re-derives the grading. Title matching finds 10 of
/// these pairs; scripture-fingerprint matching finds 105, 97 of them
/// invisible to a title comparison. Detection belongs upstream, with
/// its evidence; this file's job is that the app reads it correctly.
Map<String, dynamic> _record(int id, {String author = '张熙和牧师'}) => {
      'id': id,
      'refcode': 'R$id',
      'title': 'T$id',
      'slug': 's',
      'url': 'u',
      'language': 'zh',
      'date': '2020-01-01T00:00:00',
      'modified': '2020-01-01T00:00:00',
      'author': author,
      'authorSource': 'taxonomy',
      'authorKind': 'person',
      'series': null,
      'book': null,
      'programmes': <String>[],
      'audioUrls': <String>[],
      'transcriptDocUrls': <String>[],
      'mobileTranscriptUrls': <String>[],
      'videoUrls': <String>[],
      'hasBody': true,
      'bodyChars': 5000,
      'bodyFile': 'bodies/$id.txt',
      'dateSuspect': false,
    };

String _index(List<int> ids) => json.encode({
      '_meta': {'rights': 'r', 'rightsEn': 'r'},
      'sermons': [for (final id in ids) _record(id)],
    });

String _refs(List<Map<String, dynamic>> pairs) => json.encode({
      'duplicates': {'crossCorpus': pairs},
    });

void main() {
  final svc = SermonLibraryService.instance;

  tearDown(() {
    svc.resetForTest();
  });

  /// Serve a hand-built index and refs pair.
  void serve(String index, String? refs) {
    svc.useLoader((p) async {
      if (p == 'index.json') return index;
      if (p == 'refs.json') {
        if (refs == null) throw Exception('no refs.json');
        return refs;
      }
      return 'body';
    });
  }

  // ── 1. No tier removes a record ────────────────────────────────

  group('the grading never deletes a sermon', () {
    test('every tier, including confirmed, stays in the list', () async {
      serve(
        _index([1, 2, 3, 4]),
        _refs([
          {'libId': '1', 'appId': '016', 'tier': 'confirmed'},
          {'libId': '2', 'appId': '018', 'tier': 'probable'},
          {'libId': '3', 'appId': '023', 'tier': 'possible'},
          {'libId': '4', 'appId': '027', 'tier': 'weak'},
        ]),
      );
      final lib = await svc.load();
      expect([for (final s in lib.sermons) s.id], [1, 2, 3, 4]);
    });

    test('an unreadable refs.json costs the links, never a record',
        () async {
      serve(_index([1, 2, 3]), null);
      final lib = await svc.load();
      expect(lib.sermons, hasLength(3));
      expect(lib.refs.isEmpty, isTrue);
      expect(lib.refs.confirmedPairFor(1), isNull);
    });

    test('a malformed refs.json is the same', () async {
      serve(_index([1, 2]), '{not json');
      expect((await svc.load()).sermons, hasLength(2));
    });
  });

  // ── 2. The link reaches exactly the confirmed tier ─────────────

  group('only `confirmed` earns a link', () {
    test('confirmed links; probable, possible and weak do not', () async {
      serve(
        _index([1, 2, 3, 4]),
        _refs([
          {'libId': '1', 'appId': '016', 'tier': 'confirmed'},
          {'libId': '2', 'appId': '018', 'tier': 'probable'},
          {'libId': '3', 'appId': '023', 'tier': 'possible'},
          {'libId': '4', 'appId': '027', 'tier': 'weak'},
        ]),
      );
      final refs = (await svc.load()).refs;
      expect(refs.confirmedPairFor(1)?.appId, '016');
      for (final id in const [2, 3, 4]) {
        expect(refs.confirmedPairFor(id), isNull,
            reason: 'a pair nobody has adjudicated is not a counterpart, '
                'and offering it would be the plausible link '
                'MatthewMessage exists to refuse');
      }
    });

    test('promoting a tier changes the link with no code change',
        () async {
      // The same record, the same id, one word different in the data.
      // This is the whole reason the tier is read at load time and no
      // id is written down in the app.
      serve(_index([2]),
          _refs([{'libId': '2', 'appId': '018', 'tier': 'probable'}]));
      expect((await svc.load()).refs.confirmedPairFor(2), isNull);
      serve(_index([2]),
          _refs([{'libId': '2', 'appId': '018', 'tier': 'confirmed'}]));
      expect((await svc.load()).refs.confirmedPairFor(2)?.appId, '018');
    });

    test('a tier this app has never heard of earns no link', () async {
      serve(_index([2]),
          _refs([{'libId': '2', 'appId': '018', 'tier': 'almost-certainly'}]));
      final lib = await svc.load();
      expect(lib.sermons, hasLength(1));
      expect(lib.refs.confirmedPairFor(2), isNull);
    });

    test('a row with NO tier field earns no link and keeps its record',
        () async {
      serve(_index([1]), _refs([{'libId': '1', 'appId': '016'}]));
      final lib = await svc.load();
      expect(lib.sermons, hasLength(1));
      expect(lib.refs.confirmedPairFor(1), isNull);
    });

    test('completeness round-trips when the data carries it', () async {
      // Two texts can be the same sermon and still be a bad swap. The
      // adjudicating pass records that here; this app carries the
      // value and renders nothing from it, because guessing the
      // vocabulary before it exists would be inventing the judgement
      // it is supposed to be reading.
      serve(
        _index([1, 2]),
        _refs([
          {
            'libId': '1',
            'appId': '016',
            'tier': 'confirmed',
            'completeness': 'partA-only',
          },
          {'libId': '2', 'appId': '018', 'tier': 'confirmed'},
        ]),
      );
      final refs = (await svc.load()).refs;
      expect(refs.confirmedPairFor(1)?.completeness, 'partA-only');
      expect(refs.confirmedPairFor(2)?.completeness, isNull,
          reason: 'absent must stay absent, not become a default');
    });

    test('the tiers survive the parse — they are not collapsed to a bool',
        () async {
      serve(
        _index([1, 2]),
        _refs([
          {'libId': '1', 'appId': '016', 'tier': 'confirmed'},
          {'libId': '2', 'appId': '018', 'tier': 'probable'},
        ]),
      );
      final lib = await svc.load();
      expect([for (final d in lib.refs.crossCorpus) d.tier],
          ['confirmed', 'probable'],
          reason: 'the pass promoting probable pairs needs the word, not a '
              'boolean somebody threw the word away to make');
    });
  });

  // ── 3. Against the real graded data ────────────────────────────

  group('the real corpus', () {
    setUp(() {
      svc.useLoader((p) async =>
          File('${SermonLibraryService.libraryRoot}/$p').readAsStringSync());
    });

    Map<String, dynamic> rawRefs() =>
        json.decode(File('${SermonLibraryService.libraryRoot}/refs.json')
            .readAsStringSync()) as Map<String, dynamic>;

    test('every graded record, every tier, is still in the library',
        () async {
      final rows = ((rawRefs()['duplicates']
          as Map<String, dynamic>)['crossCorpus'] as List)
          .cast<Map<String, dynamic>>();
      final confirmed = {
        for (final r in rows)
          if (r['tier'] == 'confirmed') int.parse('${r['libId']}'),
      };
      final other = {
        for (final r in rows)
          if (r['tier'] != 'confirmed') int.parse('${r['libId']}'),
      }..removeAll(confirmed);
      expect(confirmed, isNotEmpty);
      expect(other, isNotEmpty);

      final lib = await svc.load();
      for (final id in {...confirmed, ...other}) {
        // A record can still be absent for the unrelated reason that
        // it has nothing to open; what must never happen is its being
        // absent BECAUSE it was graded.
        final row = lib.byId[id];
        expect(row, isNotNull, reason: '$id was graded, not deleted');
      }
      // The corpus loses exactly the three empty records and nothing
      // else — so the grading, whatever it says, removed none.
      expect(lib.fetchedCount - lib.sermons.length, 3);
    });

    test('every confirmed record carries a link, and no other does',
        () async {
      final rows = ((rawRefs()['duplicates']
          as Map<String, dynamic>)['crossCorpus'] as List)
          .cast<Map<String, dynamic>>();
      final confirmed = {
        for (final r in rows)
          if (r['tier'] == 'confirmed') int.parse('${r['libId']}'),
      };
      final lib = await svc.load();
      final linked = {
        for (final s in lib.sermons)
          if (lib.refs.confirmedPairFor(s.id) != null) s.id,
      };
      expect(linked, confirmed,
          reason: 'the set of links is the confirmed tier, derived — no '
              'id and no count is written down in the app');
      expect(confirmed.length, greaterThan(0));
    });

    test('every confirmed link points at a sermon that exists', () async {
      // The card offers to open the other text. A pair naming an app
      // id that is not in the app corpus would render a button that
      // lands on "sermon not found" — the dead control this codebase
      // already learned about from the native link stub.
      final appIds = {
        for (final s in (json.decode(
                File('assets/sermons/index.json').readAsStringSync()) as List)
            .cast<Map<String, dynamic>>())
          s['id'] as String,
      };
      final lib = await svc.load();
      final confirmed = [
        for (final d in lib.refs.crossCorpus)
          if (d.isConfirmed) d,
      ];
      expect(confirmed, isNotEmpty);
      for (final d in confirmed) {
        expect(appIds, contains(d.appId),
            reason: 'library ${d.libId} links to ${d.appId}, which is not '
                'in the app corpus');
      }
    });
  });

  // ── 3. The scripture index the refs file also carries ──────────

  group('per-chapter lookup', () {
    setUp(() {
      svc.useLoader((p) async =>
          File('${SermonLibraryService.libraryRoot}/$p').readAsStringSync());
    });

    test('a chapter resolves to records, verse keys included', () async {
      final lib = await svc.load();
      final hits = lib.sermonsForChapter('Matthew', 5);
      expect(hits, isNotEmpty);
      for (final s in hits) {
        final keys = lib.refs.bySermon[s.id] ?? const <String>[];
        expect(
          keys.any((k) => k == 'Matthew 5' || k.startsWith('Matthew 5:')),
          isTrue,
        );
      }
      // Verse-level keys must be reached, not just the bare chapter —
      // most of the index is verse keys, and an exact-match lookup
      // would find almost nothing.
      final verseOnly = [
        for (final s in hits)
          if (!(lib.refs.bySermon[s.id] ?? const <String>[])
              .contains('Matthew 5'))
            s,
      ];
      expect(verseOnly, isNotEmpty,
          reason: 'these are reachable only through the "Matthew 5:" prefix');
    });

    test('a chapter nobody preached resolves to nothing', () async {
      final lib = await svc.load();
      expect(lib.sermonsForChapter('Matthew', 999), isEmpty);
    });

    test('the chapter index only yields records the library shows',
        () async {
      // The refs file indexes all 940, including the three with
      // nothing behind them. A lookup must not hand back a row that
      // opens onto an empty page.
      final lib = await svc.load();
      final hits = lib.sermonsForChapter('Matthew', 5);
      expect(hits, isNotEmpty);
      for (final s in hits) {
        expect(lib.byId.containsKey(s.id), isTrue);
        expect(s.isOpenable, isTrue);
      }
    });

    test('focus is levelled and parsed', () async {
      final lib = await svc.load();
      expect(lib.refs.focus, isNotEmpty);
      expect(lib.refs.byBook['Matthew'], isNotEmpty);
    });
  });
}
