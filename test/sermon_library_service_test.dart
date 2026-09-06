import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:yswords/models/library_sermon.dart';
import 'package:yswords/services/sermon_library_service.dart';

/// `SermonLibraryService` — the one door into the 940-record 福音电台
/// library.
///
/// Every test here runs through the service's own loader seam, which
/// is also the point: the asset directory is gitignored and not
/// declared in `pubspec.yaml`, so `rootBundle` cannot reach it, and a
/// test that installs a `dart:io` loader is simultaneously the proof
/// that the "bundle it or fetch it" decision really is one line.
///
/// The traps these are aimed at, in order of how much they would cost:
///
///   1. **the year 214.** One record's upstream date reads
///      `0214-07-02T11:19:11`. Parsed naively it sorts fifteen
///      centuries before the corpus and pins itself to one end of
///      every date-ordered list. Two independent locks refuse it, and
///      each is broken separately below — a test that only exercised
///      the real record would pass with either lock removed.
///   2. **rows that open onto nothing.** Three records have neither a
///      usable body nor audio. A header that counts them promises the
///      reader rows they cannot act on.
///   3. **the body text.** Returned byte-for-byte. These are
///      transcripts of preaching and nothing in this app gets to
///      re-punctuate them.
Map<String, dynamic> _record({
  required int id,
  String title = 'T',
  String date = '2020-06-01T00:15:00',
  bool dateSuspect = false,
  String? author = '甲',
  String? authorKind = kAuthorKindPerson,
  bool hasBody = true,
  int bodyChars = 5000,
  String bodyFile = 'bodies/x.txt',
  List<String> audioUrls = const [],
}) =>
    {
      'id': id,
      'refcode': 'R$id',
      'title': title,
      'slug': 's',
      'url': 'https://fuyindiantai.org/sermon/$id/',
      'language': 'zh',
      'date': date,
      'modified': date,
      'author': author,
      'authorSource': author == null ? 'none' : 'taxonomy',
      'authorKind': authorKind,
      'series': null,
      'book': null,
      'programmes': <String>[],
      'audioUrls': audioUrls,
      'transcriptDocUrls': <String>[],
      'mobileTranscriptUrls': <String>[],
      'videoUrls': <String>[],
      'hasBody': hasBody,
      'bodyChars': bodyChars,
      'bodyFile': hasBody ? bodyFile : '',
      'dateSuspect': dateSuspect,
    };

String _index(List<Map<String, dynamic>> records) => json.encode({
      '_meta': {
        'rights': '© 福音电台 及各讲员 · 经授权使用',
        'rightsEn': '© FYDT and the individual speakers · used with permission',
      },
      'sermons': records,
    });

void main() {
  final svc = SermonLibraryService.instance;
  final hasCorpus =
      File('${SermonLibraryService.libraryRoot}/index.json').existsSync();
  const corpusSkipReason =
      'assets/sermon_library/ is deliberately untracked (see .gitignore) — '
      'run scripts/sync_sermon_library.py to regenerate it locally. On a '
      'fresh clone this test SKIPS, mirroring test_sermon_library.py\'s '
      'TestSnapshot.';

  tearDown(() {
    // Back to `rootBundle`, caches dropped — otherwise one test's
    // fixture is served to the next one's `load()`.
    svc.useLoader((p) => noLoaderInstalled(p));
    svc.resetForTest();
  });

  // ── 1. The year 214, and both locks on it ──────────────────────

  group('a corrupt date is undated, not ancient', () {
    test('the suspect FLAG alone is enough, on an otherwise fine date', () {
      // The date here parses and is well inside the plausible range,
      // so the year guard cannot be what refuses it. Only the flag
      // can. Break `if (dateSuspect) return null` and this fails.
      final s = LibrarySermon.fromJson(_record(
          id: 1, date: '2020-06-01T00:15:00', dateSuspect: true));
      expect(s.publishedAt, isNull);
      expect(s.displayDate, '—');
    });

    test('the VALUE alone is enough, with no flag set', () {
      // The real record carries both. This one carries only the bad
      // value, so it isolates the second lock: break
      // `if (parsed.year < 1980) return null` and this fails while
      // the test above still passes.
      final s = LibrarySermon.fromJson(_record(
          id: 2, date: '0214-07-02T11:19:11', dateSuspect: false));
      expect(s.publishedAt, isNull,
          reason: 'a re-ingest could ship the corrupt value without the '
              'flag; the year guard is the second lock');
    });

    test('a good date is still a date', () {
      final s = LibrarySermon.fromJson(_record(id: 3, date: '2020-06-01T00:15:00'));
      expect(s.publishedAt?.year, 2020);
      expect(s.displayDate, '2020-06-01');
    });

    test('undated sorts LAST, not first, and the rest run newest-first', () {
      final sorted = SermonLibraryService.sortNewestFirst([
        LibrarySermon.fromJson(_record(id: 1, date: '2015-01-01T00:00:00')),
        LibrarySermon.fromJson(
            _record(id: 2, date: '0214-07-02T11:19:11', dateSuspect: true)),
        LibrarySermon.fromJson(_record(id: 3, date: '2022-01-01T00:00:00')),
        LibrarySermon.fromJson(_record(id: 4, date: '2019-01-01T00:00:00')),
      ]);
      expect([for (final s in sorted) s.id], [3, 4, 1, 2],
          reason: 'newest first; the undated record goes to the end. '
              'Sorting it to an epoch default would only move it to the '
              'other end of the same list.');
    });

    test('the real corpus has exactly one such record and it sorts last',
        skip: hasCorpus ? null : corpusSkipReason, () async {
      svc.useLoader(_diskLoader);
      final lib = await svc.load();
      final suspect = [
        for (final s in lib.sermons)
          if (s.dateSuspect) s,
      ];
      expect(suspect, hasLength(1));
      expect(suspect.single.id, 2967);
      expect(suspect.single.publishedAt, isNull);
      final all = SermonLibraryService.sortNewestFirst(lib.sermons);
      expect(all.last.id, 2967,
          reason: 'the one undated record is the last row of a '
              'date-ordered whole-corpus list, never the first');
    });
  });

  // ── 2. Rows a reader can actually open ─────────────────────────

  group('records with nothing behind them are dropped', () {
    test('no body worth opening and no audio → not in the library', () async {
      svc.useLoader((_) async => _index([
            _record(id: 1), // body
            _record(id: 2, hasBody: false, bodyChars: 0), // nothing
            _record(id: 3, hasBody: false, audioUrls: const ['a.mp3']), // audio
            _record(id: 4, bodyChars: 60), // stub body, below the floor
          ]));
      final lib = await svc.load();
      expect([for (final s in lib.sermons) s.id], [1, 3]);
      expect(lib.fetchedCount, 4,
          reason: 'what was dropped is still countable, not vanished');
    });

    test('the real corpus loses exactly three of its 940',
        skip: hasCorpus ? null : corpusSkipReason, () async {
      svc.useLoader(_diskLoader);
      final lib = await svc.load();
      expect(lib.fetchedCount, 940);
      expect(lib.sermons, hasLength(937));
      for (final s in lib.sermons) {
        expect(s.isOpenable, isTrue);
      }
    });
  });

  // ── 3. Who a sermon is credited to ─────────────────────────────

  group('speakers', () {
    test('a record with no author is credited to the station, not to null',
        () async {
      svc.useLoader((_) async => _index([
            _record(id: 1, author: null, authorKind: null),
            _record(id: 2, author: kLibraryFallbackCredit, authorKind: null),
          ]));
      final lib = await svc.load();
      expect(lib.speakers, hasLength(1),
          reason: 'the asset\'s own rightsNote says an unattributed record '
              'is credited to 福音电台, so it joins that row rather than '
              'sitting in a nameless one beside it');
      expect(lib.speakers.single.name, kLibraryFallbackCredit);
      expect(lib.speakers.single.count, 2);
      expect(lib.speakers.single.unattributedCount, 1,
          reason: 'and the page can still say how many got there that way');
    });

    test('ordered by count descending, ties broken by name', () async {
      svc.useLoader((_) async => _index([
            _record(id: 1, author: '乙'),
            _record(id: 2, author: '丙'),
            _record(id: 3, author: '丙'),
            _record(id: 4, author: '甲'),
          ]));
      final lib = await svc.load();
      expect([for (final s in lib.speakers) '${s.name}:${s.count}'],
          ['丙:2', '乙:1', '甲:1']);
    });

    test('小珊姊妹 and 小珊 stay two rows',
        skip: hasCorpus ? null : corpusSkipReason, () async {
      // Very probably one person. Merging them would be this app
      // deciding who somebody is from a substring — a larger claim
      // than the counterpart link `MatthewMessage` already refuses to
      // make on a near-match. If the church confirms it, the fetcher
      // is where the fix belongs.
      svc.useLoader(_diskLoader);
      final lib = await svc.load();
      final names = {for (final s in lib.speakers) s.name};
      expect(names, containsAll(<String>['小珊姊妹', '小珊']));
    });

    test('the programme is marked as one and the people are not',
        skip: hasCorpus ? null : corpusSkipReason, () async {
      svc.useLoader(_diskLoader);
      final lib = await svc.load();
      final programmes = [
        for (final s in lib.speakers)
          if (s.isProgramme) s.name,
      ];
      expect(programmes, ['奇妙恩典'],
          reason: 'a list headed "speakers" that silently included a radio '
              'programme would be a small lie');
    });

    test('every sermon reaches exactly one speaker, and none is lost',
        skip: hasCorpus ? null : corpusSkipReason, () async {
      svc.useLoader(_diskLoader);
      final lib = await svc.load();
      final bucketed =
          lib.speakers.fold<int>(0, (a, s) => a + s.sermons.length);
      expect(bucketed, lib.sermons.length);
      expect(lib.speakers.first.count, greaterThan(lib.speakers.last.count));
    });
  });

  // ── 4. The body, verbatim ──────────────────────────────────────

  group('bodies are returned untouched', () {
    const raw = '第一段。\n第二段，有空白  在里面。\n\n第四段。\n';

    test('byte for byte, including the whitespace', () async {
      svc.useLoader((p) async {
        if (p == 'index.json') return _index([_record(id: 1)]);
        if (p == 'refs.json') return '{}';
        return raw;
      });
      final lib = await svc.load();
      final body = await svc.loadBody(lib.sermons.single);
      expect(body, raw,
          reason: 'nothing in this app re-punctuates or re-wraps a '
              'preacher; the renderer decides layout, the service '
              'decides nothing');
    });

    test('a record with no usable body is never asked for one', () async {
      var reads = 0;
      svc.useLoader((p) async {
        if (p == 'index.json') {
          return _index([_record(id: 1, hasBody: false, audioUrls: const ['a'])]);
        }
        if (p == 'refs.json') return '{}';
        reads += 1;
        return raw;
      });
      final lib = await svc.load();
      expect(await svc.loadBody(lib.sermons.single), isNull);
      expect(reads, 0);
    });

    test('a missing file degrades to null and is not re-fetched', () async {
      var attempts = 0;
      svc.useLoader((p) async {
        if (p == 'index.json') return _index([_record(id: 1)]);
        if (p == 'refs.json') return '{}';
        attempts += 1;
        throw Exception('gone');
      });
      final lib = await svc.load();
      expect(await svc.loadBody(lib.sermons.single), isNull);
      expect(await svc.loadBody(lib.sermons.single), isNull);
      expect(attempts, 1, reason: 'a miss caches as a miss');
    });
  });

  // ── 5. The seam and the cache ──────────────────────────────────

  group('the loader is the only door', () {
    test('one parse serves every caller, even in the same frame', () async {
      var reads = 0;
      svc.useLoader((p) async {
        if (p != 'index.json') return '{}';
        reads += 1;
        return _index([_record(id: 1)]);
      });
      final a = svc.load();
      final b = svc.load();
      expect(identical(await a, await b), isTrue);
      await svc.load();
      expect(reads, 1,
          reason: 'the FUTURE is memoised, not just its value, so two '
              'widgets building in one frame share one parse — the '
              'difference between a page that renders and a page that '
              'sits on a spinner');
    });

    test('installing a loader drops what the previous one produced',
        () async {
      svc.useLoader((_) async => _index([_record(id: 1, author: '甲')]));
      expect((await svc.load()).sermons.single.id, 1);
      svc.useLoader((_) async => _index([_record(id: 99, author: '乙')]));
      expect((await svc.load()).sermons.single.id, 99,
          reason: 'a stale cache across a transport switch is how a test '
              'passes against a payload it never installed');
    });

    test('every path the service reads is relative to the library root',
        () async {
      final asked = <String>[];
      svc.useLoader((p) async {
        asked.add(p);
        if (p == 'index.json') return _index([_record(id: 1)]);
        if (p == 'refs.json') return '{}';
        return 'body';
      });
      final lib = await svc.load();
      await svc.loadBody(lib.sermons.single);
      expect(asked, ['index.json', 'refs.json', 'bodies/x.txt']);
      expect(SermonLibraryService.libraryRoot, 'assets/sermon_library');
    });
  });

  // ── 6. The rights line comes from the corpus ───────────────────

  test('the rights line is read, never composed',
      skip: hasCorpus ? null : corpusSkipReason, () async {
    svc.useLoader(_diskLoader);
    final lib = await svc.load();
    expect(lib.rightsFor('zh-Hans'), contains('福音电台'));
    expect(lib.rightsFor('zh-Hant'), lib.rightsFor('zh-Hans'),
        reason: 'the corpus ships one Chinese rights string and there is '
            'no Traditional edition of it to prefer');
    expect(lib.rightsFor('en'), isNot(lib.rightsFor('zh-Hans')));
    expect(lib.rightsFor('en'), contains('permission'));
  });
}

/// Reads the library off disk instead of out of the asset bundle.
///
/// `assets/sermon_library/` is gitignored and is NOT declared in
/// `pubspec.yaml`, so `rootBundle` genuinely cannot see it. Installing
/// this is therefore not a convenience — it is the same substitution
/// the app would make to fetch the corpus over HTTP, exercised.
Future<String> _diskLoader(String path) =>
    File('${SermonLibraryService.libraryRoot}/$path').readAsString();

/// The default loader, restored in `tearDown`. Named rather than
/// inlined so the restore reads as a restore.
Future<String> noLoaderInstalled(String path) =>
    throw StateError('test forgot to install a loader for $path');
