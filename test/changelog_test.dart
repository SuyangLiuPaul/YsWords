// The changelog the app ships: what the generator kept, how the page
// groups it, and whether the reader can reach it.
//
// The asset is generated from git by `tools/build_changelog.py`, so
// most of what could go wrong here is a filter that lets bookkeeping
// through — and bookkeeping is the majority of this repository's
// commits. A changelog whose top line is "release: v1.6.270 to dev +
// prod" is worse than none: it tells the reader we deploy a lot and
// nothing about what they got.
//
// 2026-09-09, after review, four more things that could go wrong and
// had:
//   * the asset stopped one version short of the build it ships inside
//     (finding 1) — the top entry is now checked against pubspec;
//   * eighteen bookkeeping lines were on the page (finding 2) — the
//     forms this repo actually writes now have a table;
//   * the day heading and the 「你的版本」 badge were plain Rows and
//     overflowed on a narrow phone at a large text scale (finding 3);
//   * nothing told a Chinese reader why the notes are English
//     (finding 4).
// And finding 5, which is why the other four could go stale again:
// tools/release_web.sh never ran the generator at all.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yswords/constants/app_version.dart';
import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/pages/changelog_page.dart';
import 'package:yswords/services/changelog_service.dart';

Map<String, dynamic> _asset() => jsonDecode(
      File('assets/changelog.json').readAsStringSync(),
    ) as Map<String, dynamic>;

List<Map<String, dynamic>> _entries() =>
    (_asset()['entries'] as List<dynamic>).cast<Map<String, dynamic>>();

/// `X.Y.Z` from pubspec.yaml, without any `+build` suffix — the same
/// read tools/release_web.sh does, so this test and that script agree
/// on what "the version being built" means.
String _pubspecVersion() {
  final m = RegExp(r'^version:\s*(\d+\.\d+\.\d+)', multiLine: true)
      .firstMatch(File('pubspec.yaml').readAsStringSync());
  expect(m, isNotNull, reason: 'pubspec.yaml has no version: line');
  return m!.group(1)!;
}

List<int> _parseVersion(String v) =>
    v.split('.').map(int.parse).toList(growable: false);

bool _descends(List<int> a, List<int> b) =>
    a[0] < b[0] ||
    (a[0] == b[0] && a[1] < b[1]) ||
    (a[0] == b[0] && a[1] == b[1] && a[2] < b[2]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

    // Review finding 2 (2026-09-09): the first filter covered the
    // conventional-commit list and almost none of the forms this
    // repository actually writes for its own record — `audit:`,
    // `tools:`, `state:`, `queue:`, `tests:` (the list had the singular
    // only), `nightly:`, `wip(nasb):`, `fix CI` and `fix(lint):`.
    // Eighteen such lines were on the shipped page, among them "tools:
    // pin web_verify_headless.mjs's Chrome locale, fix a real click
    // collision" and "state: all six sites and yahwehword.com are on
    // 1.5.12". Both are real work; neither is anything a reader of the
    // app can see.
    test('no bookkeeping form this repo uses reaches a reader', () {
      final bookkeeping = RegExp(
        r'^(?:'
        r'(?:release|docs?|chore|ci|tests?|build|style|refactor'
        r'|tools|state|queue|nightly|wip)(?:\+[a-z]+)*(?:\([^)]*\))?:'
        r'|audit(?:[_ -][^:]{0,40})?:'
        r'|release[-_][a-z0-9]+:'
        r'|fix\s*\(\s*(?:ci|lint|release)\s*\)\s*:'
        r'|fix\b[\s:]*CI\b'
        r'|PROJECT_STATE\b'
        r'|Merge (?:branch|pull request|remote-tracking branch|origin/)'
        r')',
        caseSensitive: false,
      );
      final offenders = <String>[
        for (final e in _entries())
          for (final note in (e['notes'] as List<dynamic>).cast<String>())
            if (bookkeeping.hasMatch(note)) '${e['version']}: $note',
      ];
      expect(offenders, isEmpty,
          reason: 'bookkeeping reached the changelog:\n'
              '${offenders.join('\n')}');
    });

    // Remediation of the 2026-09-09 review (finding 1): the regex above
    // is anchored at the START of the subject, and the three worst lines
    // on the shipped asset carried no bookkeeping token there. The
    // regenerated entry 0, note 0 — the most-read line on the page — was
    // literally "Stop the 50dcc102 apparatus-reformat noise from burying
    // real drift"; a raw commit SHA and internal jargon, in front of end
    // users. The other two were "fix: audit_p0.py's check() silently
    // missed explicit null Strong's codes" and a `fix:` naming a harness
    // plus a second SHA.
    //
    // Two marks that mean "this is talking to the repository, not to the
    // reader" no matter where in the line they fall. Mirrors
    // BOOKKEEPING_ANYWHERE in tools/build_changelog.py; the python suite
    // pins the same rule against a table of real subjects, and this one
    // pins the FILE, which is what actually ships.
    test('no commit SHA and no tools/ script name reaches a reader', () {
      // Both a digit AND an a-f letter, case-sensitively, so ordinary
      // words spelled out of hex letters ("defaced", "acceded") and
      // upper-case Strong's codes are not mistaken for SHAs.
      final sha = RegExp(r'\b(?=[0-9a-f]{7,40}\b)(?=[0-9a-f]*[0-9])'
          r'(?=[0-9a-f]*[a-f])[0-9a-f]{7,40}\b');
      // The app ships Dart and assets; a .py/.sh/.zsh/.mjs/.yml is this
      // repository's machinery. `.dart`, `.json` and `.md` are
      // deliberately absent — those name things a reader can see.
      final tooling = RegExp(r'\b[Tt]ools/|\b[\w.+-]+\.(?:py|sh|zsh|mjs|ya?ml)\b');
      final offenders = <String>[
        for (final e in _entries())
          for (final note in (e['notes'] as List<dynamic>).cast<String>())
            if (sha.hasMatch(note) || tooling.hasMatch(note))
              '${e['version']}: $note',
      ];
      expect(offenders, isEmpty,
          reason: 'repository bookkeeping reached the changelog:\n'
              '${offenders.join('\n')}');
    });

    // Remediation finding 2: the head/anchor fold inspected versions[0]
    // only, so an anchor naming the version being built that sat deeper
    // in the list survived and the page showed that version twice —
    // both rows wearing 「你的版本」, with a newer version between them.
    // "versions descend" above catches the ordering; this catches the
    // duplicate, which is the half a reader would actually notice.
    test('no version is listed twice — one row can wear 「你的版本」', () {
      final versions = _entries()
          .map((e) => e['version'] as String)
          .toList(growable: false);
      final seen = <String>{};
      final duplicates = <String>[
        for (final v in versions)
          if (!seen.add(v)) v,
      ];
      expect(duplicates, isEmpty,
          reason: 'these versions have more than one entry: $duplicates');
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

  // Review finding 1 (2026-09-09): the generator anchored every entry
  // on a `release: vX.Y.Z` commit, and that commit is written AFTER the
  // build for X.Y.Z has been deployed — so the asset inside the v1.5.21
  // build stopped at v1.5.20. Two things the reader lost: the
  // 「你的版本」 badge compares against the running version and so never
  // rendered at all, and the top of a page whose entire job is its top
  // entry was one release stale. The generator now synthesises the
  // entry for the version pubspec names. These assertions are the proof
  // and they are what keeps it fixed: run the generator before the
  // bump, or drop the flag from release_web.sh, and they fail.
  group('the running build is in the asset', () {
    test('the asset says which version it was built for, and it is the '
        'one in pubspec', () {
      final head = _asset()['head'] as Map<String, dynamic>?;
      expect(head, isNotNull,
          reason: 'no `head` — the generator was run without a head '
              'version, i.e. the pre-review generator');
      expect(head!['version'], _pubspecVersion());
    });

    test('the top entry IS the pubspec version — through the real parser, '
        'on the real asset, with no catch-all in the way', () {
      final entries = ChangelogService.parse(
        File('assets/changelog.json').readAsStringSync(),
      );
      expect(entries, isNotEmpty);
      // Newest first, or the page opens on the oldest day.
      for (var i = 1; i < entries.length; i++) {
        expect(
          _descends(_parseVersion(entries[i].version),
              _parseVersion(entries[i - 1].version)),
          isTrue,
          reason: '${entries[i].version} came after ${entries[i - 1].version}',
        );
      }
      final head = _asset()['head'] as Map<String, dynamic>;
      // A release with no reader-visible change (a data re-import, a
      // tooling fix) is recorded under `head` but not listed — an empty
      // row is a version number pretending to be news. Every other
      // release, which is nearly all of them, must be on top.
      if ((head['notes'] as int) > 0) {
        expect(entries.first.version, _pubspecVersion(),
            reason: 'the top entry is not the build being shipped — the '
                'badge cannot render and 「更新记录」 is one behind');
      } else {
        expect(entries.first.version, isNot(_pubspecVersion()));
      }
    });

    test('and kAppVersion matches it, which is what the badge compares', () {
      // The badge is `entry.version == kAppVersion`. pubspec and
      // kAppVersion drifting is app_version_fallback_test's subject;
      // this is the one line of it this page depends on.
      expect(kAppVersion, _pubspecVersion());
    });

    test('the same through rootBundle, the way the page loads it', () async {
      ChangelogService.resetForTest();
      addTearDown(ChangelogService.resetForTest);
      final days = await ChangelogService.load();
      expect(days, isNotEmpty,
          reason: 'load() returned the empty state for the real asset — '
              'either rootBundle cannot see it or parse() threw and the '
              'catch-all hid it; the test above says which');
      expect(days.first.versions.first.version, _pubspecVersion());
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

    test('parse() throws on a malformed asset instead of returning nothing '
        '— the catch-all belongs to load(), not to the parser', () {
      expect(() => ChangelogService.parse('{"entries": [{"version": 1}]}'),
          throwsA(isA<TypeError>()));
      expect(() => ChangelogService.parse('not json'),
          throwsA(isA<FormatException>()));
    });
  });

  group('the page', () {
    Future<AppSettings> pump(
      WidgetTester tester, {
      required String locale,
      required double width,
      required double textScale,
      required List<ChangelogDay> days,
    }) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(ChangelogService.resetForTest);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = Size(width, 1400);
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      ChangelogService.setForTest(days);
      final settings = AppSettings();
      await tester.pumpWidget(
        ChangeNotifierProvider<AppSettings>.value(
          value: settings,
          child: const MaterialApp(home: ChangelogPage()),
        ),
      );
      await tester.pump();
      await settings.setLocale(locale);
      // AppSettings debounces its persist by 600 ms; let it fire, or the
      // binding fails the test for a pending timer after the tree is
      // gone instead of for anything about the layout.
      await tester.pump(const Duration(milliseconds: 700));
      return settings;
    }

    // A day carrying the running version — so the badge row is on
    // screen too — with a two-digit change count. Fourteen changes in a
    // day is an ordinary number here; 2026-09-09 had more.
    final busyDay = ChangelogService.groupByDay([
      ChangelogEntry(
        version: kAppVersion,
        date: '2026-09-09',
        notes: List.generate(
          14,
          (i) => 'sermons: the 15 audio-only messages reach readers, and '
              'the corpus is 429 ($i)',
        ),
      ),
    ]);

    // Review finding 3 (2026-09-09): the day heading was a Row of two
    // texts, and the version line a Row of `v1.5.21` and the
    // 「你的版本」 badge — neither with a Flexible or a Wrap between
    // them. Both texts are sized from the reader's own font size AND
    // the OS text scale, so on a 360 dp phone at 200% the date alone is
    // wider than the content column and the count overflowed it. This
    // pumps that exact configuration; before the fix takeException()
    // returns the RenderFlex overflow.
    for (final locale in const ['zh-Hans', 'zh-Hant', 'en']) {
      testWidgets('$locale: a 360 dp phone at 200% text does not overflow '
          'the day heading or the badge', (tester) async {
        final settings = await pump(tester,
            locale: locale, width: 360, textScale: 2.0, days: busyDay);
        expect(settings.locale, locale, reason: 'the locale did not take');
        expect(tester.takeException(), isNull);
        // Everything the heading promises is still on screen — a Wrap
        // that dropped a child would pass "no overflow" and fail the
        // reader.
        expect(find.text('2026-09-09'), findsOneWidget);
        expect(
          find.text((uiStrings['changelogCount']![locale]!)
              .replaceAll('{n}', '14')),
          findsOneWidget,
        );
        expect(find.text('v$kAppVersion'), findsOneWidget);
        expect(find.text(uiStrings['changelogYours']![locale]!),
            findsOneWidget,
            reason: 'the badge for the running build is not on the page');
      });
    }

    // Review finding 4 (2026-09-09): under 「更新记录」 the notes are
    // English commit subjects with nothing saying why. One caption, in
    // the Chinese locales only.
    testWidgets('a Chinese reader is told the notes are in English',
        (tester) async {
      for (final locale in const ['zh-Hans', 'zh-Hant']) {
        final caption = uiStrings['changelogLanguageNote']![locale]!;
        expect(caption, isNotEmpty, reason: '$locale caption is empty');
        await pump(tester,
            locale: locale, width: 800, textScale: 1.0, days: busyDay);
        expect(find.text(caption), findsOneWidget,
            reason: 'no caption in $locale');
      }
    });

    // Remediation (2026-09-09). The guard here used to be
    //   expect(hans, isNot(hant), reason: 'Traditional is a script, not
    //       a character swap');
    // which passes for ANY character swap, including the one it was
    // written about: 「更新记录以英文记录。」 became 「更新記錄以英文記錄。」,
    // the same glyph for the noun and the verb, while this very file
    // writes the noun 紀錄 (readingStatsEmpty, readingStatsClear) per
    // Taiwan/HK usage. The reason string named a property the assertion
    // could not test. These two can.
    test('the Traditional caption is Traditional, and does not conflate '
        '紀錄 with 記錄', () {
      final hant = uiStrings['changelogLanguageNote']!['zh-Hant']!;
      // The named defect class this repo already tools for — Simplified
      // prose reaching a zh-Hant reader (tools/audit_untranslated_hant.py,
      // test/bible_evidence_untranslated_hant_test.dart). Every one of
      // these is Simplified-only with no Traditional use, and the first
      // five are exactly the characters this sentence turns on.
      for (final c in const [
        '记', '录', '内', '写', '这', '圣', '经', '说', '们',
      ]) {
        expect(hant.contains(c), isFalse,
            reason: 'Simplified 「$c」 in the zh-Hant caption: $hant');
      }
      // 記錄 is the verb; the record itself is 紀錄. The caption avoids
      // the noun altogether (撰寫), so 記錄 appearing here means the
      // Simplified string was swapped character-by-character again.
      expect(hant.contains('記錄'), isFalse,
          reason: 'the caption is back to the character-swapped wording: '
              '$hant');
    });

    testWidgets('and an English reader is not', (tester) async {
      expect(uiStrings['changelogLanguageNote']!['en'], isEmpty);
      await pump(tester,
          locale: 'en', width: 800, textScale: 1.0, days: busyDay);
      expect(find.text(uiStrings['changelogLanguageNote']!['zh-Hans']!),
          findsNothing);
      expect(find.text(uiStrings['changelogLanguageNote']!['zh-Hant']!),
          findsNothing);
      // And no blank first row where the caption would have been: the
      // first thing on the page is the first day.
      final firstText = tester
          .widgetList<Text>(find.descendant(
              of: find.byType(ListView), matching: find.byType(Text)))
          .first;
      expect(firstText.data, '2026-09-09');
    });
  });

  // The generator is python, so its tests are too; this is what puts
  // them inside `flutter test`, where they are actually run.
  group('the generator', () {
    test('tools/test_build_changelog.py passes', () async {
      final r = await Process.run(
        'python3',
        ['tools/test_build_changelog.py'],
        workingDirectory: Directory.current.path,
      );
      expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('the door', () {
    test('About opens the changelog, and NOT behind the update tile’s '
        'platform gate — the asset is bundled, so the web can read it too',
        () {
      final about = File('lib/pages/about_page.dart').readAsStringSync();
      // Comment lines are dropped first: a commented-out push would
      // satisfy a plain `contains` and the door would be painted shut.
      final live = about
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      final at = live.indexOf('ChangelogPage()');
      expect(at, greaterThanOrEqualTo(0),
          reason: 'a page nothing pushes is a page nobody sees');
      final before = live.substring((at - 400).clamp(0, at), at);
      expect(before.contains('AppUpdateInstaller.isSupported'), isFalse,
          reason: 'the changelog is not an installer feature');
      expect(RegExp(r'if \(!?kIsWeb').hasMatch(before), isFalse,
          reason: 'the web can read a bundled asset too');
    });

    test('the asset is declared in pubspec, or it is not in the build at all',
        () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final live = pubspec
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('#'))
          .join('\n');
      expect(live.contains('assets/changelog.json'), isTrue,
          reason: 'a commented-out asset line is no asset');
    });

    // Review finding 5 (2026-09-09): the generator shipped and NOTHING
    // ever ran it — not a script, not a workflow, not a hook — so the
    // bundled asset was frozen at whatever the one hand run left behind
    // and went staler at every release. Finding 1's other half lives
    // here too: a caller that runs the generator bare regenerates the
    // pre-review, one-version-behind asset.
    //
    // Remediation: the first wiring called it from tools/release_web.sh,
    // which is ONE of three doors onto a version bump — `BUMP_VERSION=1
    // tools/yswords-ios-reinstall.sh` and a bare `tools/bump_version.sh`
    // both moved pubspec.yaml without it, which is exactly the stale
    // asset this feature exists to stop AND turns the three assertions
    // above red. It now runs from bump_version.sh, the single writer of
    // the version, so every door gets it. tools/test_build_changelog.py
    // bumps a fixture repository for real and checks the asset that
    // comes out; this is the cheap structural half of the same claim.
    test('the version bump regenerates the changelog, and hands it the '
        'version it just wrote', () {
      final bump = File('tools/bump_version.sh').readAsStringSync();
      expect(bump.contains('build_changelog.py'), isTrue,
          reason: 'bump_version.sh never runs the changelog generator, so '
              'every door onto a release ships a stale asset');
      expect(
        RegExp(r'build_changelog\.py[^\n]*(?:\\\n[^\n]*)*'
                r'--head-version "\$NEW"')
            .hasMatch(bump),
        isTrue,
        reason: 'build_changelog.py is not passed --head-version "\$NEW"',
      );
      // After pubspec has actually moved, or the asset records the old
      // version and the assertions above fail just the same.
      expect(bump.indexOf('mv "\$TMP" "\$PUBSPEC"'),
          lessThan(bump.indexOf('build_changelog.py')));
    });

    test('and the web release reaches it before it builds the bundle', () {
      // An asset refreshed AFTER the bundle is written is not in the
      // bundle. It is now the BUMP that has to come first.
      final script = File('tools/release_web.sh').readAsStringSync();
      final bumped = script.indexOf('"\$PROJECT/tools/bump_version.sh"');
      final built = script.indexOf('"\$FLUTTER" build web');
      expect(bumped, greaterThan(-1));
      expect(built, greaterThan(-1));
      expect(bumped, lessThan(built),
          reason: 'the bump — and so the changelog — happens after the web '
              'bundle is built, so the build ships the old one');
    });

    test('and the native install door bumps through the same script', () {
      // `BUMP_VERSION=1 tools/yswords-ios-reinstall.sh` is the second
      // door onto a version change; it must delegate, not move pubspec
      // itself.
      final script =
          File('tools/yswords-ios-reinstall.sh').readAsStringSync();
      expect(
        RegExp(r'BUMP_VERSION[^\n]*\n\s*"\$PROJECT/tools/bump_version\.sh"')
            .hasMatch(script),
        isTrue,
        reason: 'the reinstall script no longer bumps via bump_version.sh, '
            'so it moves the version without regenerating the changelog',
      );
    });
  });
}
