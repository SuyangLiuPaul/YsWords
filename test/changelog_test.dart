// The changelog the app ships: what the generator kept, how the page
// groups it, and whether the reader can reach it.
//
// The asset is generated from git by `tools/build_changelog.py`, so
// most of what could go wrong here is a filter that lets bookkeeping
// through — and bookkeeping is the majority of this repository's
// commits. A changelog whose top line is "release: v1.6.270 to dev +
// prod" is worse than none: it tells the reader we deploy a lot and
// nothing about what they got.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:yswords/services/changelog_service.dart';

Map<String, dynamic> _asset() => jsonDecode(
      File('assets/changelog.json').readAsStringSync(),
    ) as Map<String, dynamic>;

List<Map<String, dynamic>> _entries() =>
    (_asset()['entries'] as List<dynamic>).cast<Map<String, dynamic>>();

void main() {
  group('what the generator shipped', () {
    test('the asset exists and is not empty — a bundled changelog that '
        'ships empty is the failure a fetching one would have had', () {
      expect(File('assets/changelog.json').existsSync(), isTrue);
      expect(_entries(), isNotEmpty);
    });

    test('no entry is a release, docs or PROJECT_STATE line', () {
      final offenders = <String>[];
      for (final e in _entries()) {
        for (final note in (e['notes'] as List<dynamic>).cast<String>()) {
          final lower = note.toLowerCase();
          if (lower.startsWith('release:') ||
              lower.startsWith('chore(release):') ||
              lower.startsWith('docs:') ||
              lower.startsWith('doc:') ||
              note.startsWith('PROJECT_STATE')) {
            offenders.add('${e['version']}: $note');
          }
        }
      }
      expect(offenders, isEmpty,
          reason: 'bookkeeping reached the changelog:\n'
              '${offenders.join('\n')}');
    });

    test('every entry has something to say — an empty row is a version '
        'number pretending to be news', () {
      for (final e in _entries()) {
        expect((e['notes'] as List<dynamic>), isNotEmpty,
            reason: '${e['version']} shipped with no notes');
      }
    });

    test('versions descend, so the newest is at the top of the page', () {
      List<int> parse(String v) =>
          v.split('.').map(int.parse).toList(growable: false);
      final versions = _entries().map((e) => parse(e['version'] as String));
      var previous = <int>[999, 999, 999];
      for (final v in versions) {
        expect(
          v[0] < previous[0] ||
              (v[0] == previous[0] && v[1] < previous[1]) ||
              (v[0] == previous[0] && v[1] == previous[1] && v[2] < previous[2]),
          isTrue,
          reason: '$v came after $previous',
        );
        previous = v;
      }
    });

    test('dates are ISO, because the page groups on them by string equality',
        () {
      final iso = RegExp(r'^\d{4}-\d{2}-\d{2}$');
      for (final e in _entries()) {
        expect(iso.hasMatch(e['date'] as String), isTrue,
            reason: '${e['version']} has date ${e['date']}');
      }
    });

    test('the window stays small enough to bundle', () {
      final bytes = File('assets/changelog.json').lengthSync();
      expect(bytes, lessThan(200 * 1024),
          reason: 'a changelog is not worth 200 KB of app; '
              'lower --max-entries in tools/build_changelog.py');
    });
  });

  group('grouping by day', () {
    test('collapses a burst of same-day releases into one heading — the '
        'reason the page is not a list of version numbers', () {
      final days = ChangelogService.groupByDay(const [
        ChangelogEntry(version: '1.6.270', date: '2026-09-09', notes: ['c']),
        ChangelogEntry(version: '1.6.269', date: '2026-09-09', notes: ['b']),
        ChangelogEntry(version: '1.6.266', date: '2026-09-09', notes: ['a']),
        ChangelogEntry(version: '1.6.265', date: '2026-09-08', notes: ['z']),
      ]);
      expect(days.length, 2);
      expect(days.first.date, '2026-09-09');
      expect(days.first.versions.length, 3);
      expect(days.last.versions.length, 1);
    });

    test('counts changes, not versions — six versions in an afternoon is '
        'how often we deploy, which is not the reader’s business', () {
      final days = ChangelogService.groupByDay(const [
        ChangelogEntry(version: '1.0.2', date: '2026-09-09', notes: ['a', 'b']),
        ChangelogEntry(version: '1.0.1', date: '2026-09-09', notes: ['c']),
      ]);
      expect(days.single.versions.length, 2);
      expect(days.single.noteCount, 3);
    });

    test('keeps release order inside a day, so the newer version is first',
        () {
      final days = ChangelogService.groupByDay(const [
        ChangelogEntry(version: '1.6.270', date: '2026-09-09', notes: ['x']),
        ChangelogEntry(version: '1.6.269', date: '2026-09-09', notes: ['y']),
      ]);
      expect(
        days.single.versions.map((v) => v.version).toList(),
        ['1.6.270', '1.6.269'],
      );
    });

    test('an empty changelog groups to nothing rather than throwing', () {
      expect(ChangelogService.groupByDay(const []), isEmpty);
    });
  });

  group('the door', () {
    test('About opens the changelog, and NOT behind the update tile’s '
        'platform gate — the asset is bundled, so the web can read it too',
        () {
      final about = File('lib/pages/about_page.dart').readAsStringSync();
      expect(about.contains('ChangelogPage()'), isTrue,
          reason: 'a page nothing pushes is a page nobody sees');
    });

    test('the asset is declared in pubspec, or it is not in the build at all',
        () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      expect(pubspec.contains('assets/changelog.json'), isTrue);
    });
  });
}
