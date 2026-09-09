#!/usr/bin/env python3
"""Tests for build_changelog.py, run by test/changelog_test.dart.

The generator had no test at all, which is why both of the 2026-09-09
review findings could sit in the shipped asset unnoticed:

  * finding 1 — the build's own version was never in the asset, because
    its `release:` anchor is only written after the build is deployed.
    Measured on this repo: pubspec said 1.5.21 and the asset stopped at
    1.5.20, so the 「你的版本」 badge had no row to render on and the top
    of the page was one release stale. `build()` did not even take a
    head version; every test here passes one.
  * finding 2 — `audit:`, `tools:`, `state:`, `tests:`, `queue:`,
    `nightly:`, `wip(nasb):`, `fix CI` and `fix(lint):` were not in
    DROP, and eighteen such lines were in front of readers. The table
    below is real subjects out of `git log`, not invented ones.

And two more from the review of that fix (2026-09-09, remediation):

  * a raw commit SHA became the TOP line on the page — "Stop the
    50dcc102 apparatus-reformat noise from burying real drift" — with
    two more mid-subject leaks behind it. DROP is anchored at the start
    of the subject and could not reach any of them; see
    MID_SUBJECT_BOOKKEEPING below and BOOKKEEPING_ANYWHERE in the
    generator.
  * the head/anchor fold looked at versions[0] only, so an anchor for
    the version being built that sat DEEPER in the list was emitted a
    second time — two rows for one version, both wearing 「你的版本」.
  * the generator was wired into tools/release_web.sh, which is one of
    three doors onto a version bump. It now runs from
    tools/bump_version.sh, which is all three. See BumpWiring.

Fixtures are real git repositories in a temp dir, because reading
`git log` IS this file's job and a mocked log would only prove the mock.

Usage:
  python3 tools/test_build_changelog.py
"""

import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import unittest

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import build_changelog as bc  # noqa: E402


class Repo:
    """A throwaway git repository of empty commits, one per subject."""

    def __init__(self, path: pathlib.Path):
        self.path = path
        self.git('init', '-q', '-b', 'main')

    def git(self, *args: str, env: dict | None = None) -> str:
        full = dict(os.environ)
        full.update({
            'GIT_AUTHOR_NAME': 't', 'GIT_AUTHOR_EMAIL': 't@t',
            'GIT_COMMITTER_NAME': 't', 'GIT_COMMITTER_EMAIL': 't@t',
        })
        if env:
            full.update(env)
        return subprocess.run(
            ['git', *args], cwd=self.path, capture_output=True, text=True,
            check=True, env=full,
        ).stdout.strip()

    def commit(self, subject: str, date: str = '2026-09-01') -> str:
        stamp = f'{date}T12:00:00'
        self.git(
            'commit', '-q', '--allow-empty', '-m', subject,
            env={'GIT_AUTHOR_DATE': stamp, 'GIT_COMMITTER_DATE': stamp},
        )
        return self.git('rev-parse', 'HEAD')


class WithRepo(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.repo = Repo(pathlib.Path(self._tmp.name))
        self.addCleanup(self._tmp.cleanup)


class HeadVersionSynthesis(WithRepo):
    """Finding 1."""

    def seed(self):
        self.repo.commit('release: v0.9.0', '2026-09-01')
        self.repo.commit('sermons: the first one', '2026-09-02')
        self.repo.commit('release: v1.0.0 to dev + qat', '2026-09-02')
        self.repo.commit('picker: the link opens', '2026-09-03')
        self.repo.commit('docs: notes', '2026-09-03')
        self.repo.commit('tests: more', '2026-09-03')

    def test_top_entry_is_the_version_being_built(self):
        self.seed()
        data = bc.build(10, head_version='1.0.1', head_date='2026-09-09',
                        repo=self.repo.path)
        top = data['entries'][0]
        self.assertEqual(top['version'], '1.0.1')
        self.assertEqual(top['date'], '2026-09-09')
        # Only the commits AFTER the last anchor, bookkeeping dropped.
        self.assertEqual(top['notes'], ['picker: the link opens'])
        # The anchored history is untouched beneath it.
        self.assertEqual(data['entries'][1]['version'], '1.0.0')
        self.assertEqual(data['entries'][1]['notes'],
                         ['sermons: the first one'])
        self.assertEqual(data['head'],
                         {'version': '1.0.1', 'date': '2026-09-09',
                          'notes': 1})

    def test_an_anchor_deeper_than_index_0_is_folded_too(self):
        # 2026-09-09 remediation, finding 2. The fold used to inspect
        # versions[0] only, and released_versions() walks
        # `git log --all` — so a `release:` commit for a NEWER version on
        # any ref pushed this build's own anchor down the list and out of
        # the fold's sight. The generator then emitted the head version
        # TWICE, both rows wearing 「你的版本」, with the newer version
        # wedged between them.
        self.repo.commit('release: v1.0.0', '2026-09-01')
        self.repo.commit('picker: what 1.0.1 shipped', '2026-09-02')
        self.repo.commit('release: v1.0.1', '2026-09-02')
        self.repo.commit('reader: what 1.0.2 shipped', '2026-09-03')
        self.repo.commit('release: v1.0.2', '2026-09-03')
        # One commit past the newest anchor, or the head span is empty
        # and the duplicate does not get prepended — this is the shape
        # the reviewer reproduced.
        self.repo.commit('lexicon: after the newest anchor', '2026-09-04')
        data = bc.build(10, head_version='1.0.1', head_date='2026-09-09',
                        repo=self.repo.path)
        versions = [e['version'] for e in data['entries']]
        # Before the fix: ['1.0.1', '1.0.2', '1.0.1'] — two rows for the
        # running version, both wearing 「你的版本」.
        self.assertEqual(versions.count('1.0.1'), 1, versions)
        self.assertEqual(versions[0], '1.0.1', versions)
        # And nothing ABOVE the version being built: the asset ships
        # INSIDE that build, so a 1.0.2 row would be a heading over
        # changes the reader's copy is claimed not to have.
        self.assertNotIn('1.0.2', versions)
        # Still descending, which is what the page's day grouping and
        # the badge both assume.
        keys = [bc._version_key(v) for v in versions]
        self.assertEqual(keys, sorted(keys, reverse=True), versions)
        # Nothing is lost on the way: the notes those two anchors held
        # are all in the one surviving row, newest first. Folding must
        # not become dropping.
        self.assertEqual(data['entries'][0]['notes'], [
            'lexicon: after the newest anchor',
            'reader: what 1.0.2 shipped',
            'picker: what 1.0.1 shipped',
        ])

    def test_an_existing_anchor_for_the_head_version_is_folded_not_doubled(
            self):
        # A --no-bump re-run, or a regenerate after the release commit
        # has been written — which is the state THIS repository was in
        # when the fix was made. The version must appear once, spanning
        # both what its anchor spans and what landed after it.
        self.seed()
        data = bc.build(10, head_version='1.0.0', head_date='2026-09-09',
                        repo=self.repo.path)
        versions = [e['version'] for e in data['entries']]
        self.assertEqual(versions.count('1.0.0'), 1)
        self.assertEqual(data['entries'][0]['version'], '1.0.0')
        self.assertEqual(data['entries'][0]['notes'],
                         ['picker: the link opens', 'sermons: the first one'])

    def test_a_head_with_nothing_visible_is_recorded_but_not_listed(self):
        self.repo.commit('release: v0.9.0', '2026-09-01')
        self.repo.commit('sermons: the first one', '2026-09-02')
        self.repo.commit('release: v1.0.0', '2026-09-02')
        self.repo.commit('docs: only', '2026-09-03')
        data = bc.build(10, head_version='1.0.1', repo=self.repo.path)
        self.assertEqual(data['entries'][0]['version'], '1.0.0')
        self.assertEqual(data['head']['version'], '1.0.1')
        self.assertEqual(data['head']['notes'], 0)

    def test_head_date_defaults_to_the_head_commit_date(self):
        self.repo.commit('release: v0.9.0', '2026-09-01')
        self.repo.commit('sermons: the first one', '2026-09-02')
        self.repo.commit('release: v1.0.0', '2026-09-02')
        self.repo.commit('videos: the second', '2026-09-07')
        data = bc.build(10, head_version='1.0.1', repo=self.repo.path)
        self.assertEqual(data['entries'][0]['date'], '2026-09-07')

    def test_no_head_version_means_no_head_key(self):
        # The pre-review shape. Kept callable so that a bare build()
        # still works, and asserted so that `head` can never appear
        # without having been asked for.
        self.seed()
        data = bc.build(10, repo=self.repo.path)
        self.assertNotIn('head', data)
        self.assertEqual(data['entries'][0]['version'], '1.0.0')

    def test_the_cli_defaults_to_the_pubspec_version(self):
        # Against the real repository: without --head-version the
        # generator must read pubspec.yaml, or a hand run would ship an
        # asset one version behind again.
        out = subprocess.run(
            [sys.executable, str(HERE / 'build_changelog.py'), '--check'],
            capture_output=True, text=True, check=True,
        ).stdout
        data = json.loads(out)
        self.assertEqual(data['head']['version'], bc.pubspec_version())


class DropCoverage(unittest.TestCase):
    """Finding 2. Every subject below is a real one from `git log`."""

    BOOKKEEPING = [
        'release: v1.5.21 to dev + qat + prod',
        'chore(release): v1.4.12',
        'chore: bump the loop cadence',
        'chore(songs): re-pin the bundled directory',
        'docs: the 27-page walk, and what it found',
        'docs(queue): file the 4th recurrence',
        'docs(HANDOFF): the state of the letter',
        'Docs: the licence table',
        'PROJECT_STATE: the 1.5.12 row',
        'state: all six sites and yahwehword.com are on 1.5.12',
        'state: the tier table said 1.5.4/1.4.214; the sites serve 1.5.11',
        'queue: the boot-trap mitigation is on prod now, not dev/qat only',
        'Queue: the tagged-corpus audit is done',
        'audit: confirm post-adoption drift in cuvs-yhwh (97+120 new hits)',
        'audit_p0: stop hand-typing a corpus count that drifts',
        'audit docstrings: three headline numbers were wrong, not just stale',
        'audit re-run: three docstring headline numbers had gone stale',
        'tools: pin web_verify_headless.mjs’s Chrome locale',
        'tools+docs: land the orphaned census correction',
        'docs+test: settle the biblexg-v2/-tr stray-ASCII pin',
        'tests: the tracked decision now has to reach the file the merge reads',
        'test: two more that passed while what they tested was broken',
        'test(bible_evidence): the 830 untranslated fields',
        'nightly: no phantom successes, no stale plugin registrant',
        'wip(nasb): complete the Gospel of Mark (all 16 chapters)',
        'ci: cache the pub dir',
        'ci(macos): the 60-minute limit',
        'build: gradle 8',
        'style: trailing commas',
        'refactor(stats): split the painter',
        'release_web: pass --no-web-resources-cdn to the international build',
        'release-macos: 60-minute limit, because 30 was a coin flip',
        'fix CI: re-express the Android install gate against its new shape',
        'Fix CI red from the 8-verse repair: 7 downstream census counts moved',
        'fix: CI red on the v1.4.191 release — app_version.dart wasn’t bumped',
        'fix(lint): drop needless string interpolation in verse_picker_grid_test',
        'fix(ci): the analyzer floor',
        'fix(release): strip the +build suffix',
        "Merge branch 'd/chrono4': zoom becomes a density",
        "Merge remote-tracking branch 'origin/main'",
        'Merge origin/main (bundled songs refresh) into the licence work',
        'Merge pull request #12 from x/y',
        'bump version to 1.4.174',
    ]

    # 2026-09-09 remediation, finding 1. Every one of these is a real
    # subject out of `git log`, every one was ON the shipped page, and
    # not one of them can be reached by DROP: DROP is anchored at the
    # start of the subject and these carry no bookkeeping token there.
    # The first was entry 0, note 0 — the single most-read line on the
    # page — and it is a raw commit SHA.
    MID_SUBJECT_BOOKKEEPING = [
        'Stop the 50dcc102 apparatus-reformat noise from burying real drift',
        'fix: harness state-oracle JSON-quoting bug; report the last silent '
        'UrlSyncService.init catch; run repro against dev with 0fa4effb live',
        "fix: audit_p0.py's check() silently missed explicit null Strong's "
        'codes',
        'fix: repair import_csb.py’s dead credential reader, pin CSB bracket '
        'balance',
        'Add a pull-time regression guard to pull_songs_snapshot.py',
        'tools/release_web.sh: build CHINA_MODE bundle for the cn-* sites',
        # 2026-09-09, second pass. All four of these SHIPPED to readers
        # in the asset the first pass regenerated: each names its
        # apparatus mid-sentence, where neither DROP (which reads the
        # opening token) nor the SHA/path patterns could see it. The
        # first one touched only PROJECT_STATE.md, docs/, a script and
        # that script's test — nothing in lib/ or assets/ at all.
        "fix: stop failing this repo's CI for an upstream song-catalogue "
        'outage',
        "boot crash: extend the harness to prove the sweep's forced reload "
        'fires',
        'boot crash: pre-fix 1.4.178 bundle also runs clean under the '
        "faithful plant, but a refuter found the harness can't test the "
        'real variable',
        'fix: harness planted undecodable raw strings, explaining the '
        'bare-hash anomaly; also fix a process leak',
    ]

    # The other half of the same filter, and the half that is easy to
    # break: this repo labels REAL changes with free-form area words
    # that look like conventional-commit types from a distance.
    CHANGES = [
        # 2026-09-09: the near-miss that pins the second pass. `snapshot`
        # and `hash` are ordinary words about a feature a reader uses, so
        # widening the filter for `harness`/`refuter`/`this repo`/`CI`
        # must not reach them.
        'deep links: snapshot the boot QUERY, the way the hash already is',
        'sermons: the 15 audio-only messages reach readers — the corpus is 429',
        'versions: the Septuagint, shipped with no licence asserted',
        'videos: 在十字架下 04 now has its 普通话 recording',
        '投影: give the projection a door',
        'chart: give each chronology event label its own semantics node',
        'exegesis: the numbers are in the line, and the line has a picker',
        'lexicon: the orthography question, answered',
        'originals: choose which translation the interlinear runs against',
        'reader: one Back unwinds one page',
        'picker: one chip per verse number — 路加 23 showed "34" twice',
        'seo: the crawlable Bible under /read/',
        'news: the detail page keeps its scroll',
        'maps: the offline pack stops fetching 1137 dead tiles',
        'data(contexts): the 830 fields are real Traditional now',
        'copy: onboarding said 289 sermons; the corpus is 429',
        'feat(chronology): span Creation → Revelation',
        'fix(sermons): 127 wrong glyphs in the Traditional transcripts',
        'perf(reader): the index is built once',
        'revert(picker): put it back',
        'Adopt the publisher’s current text, then repair it against 和合本',
        'Verse cards can use the reader’s own photo',
        # Near-misses for each token added in this review. Each of these
        # would be a real change and each starts with the letters of a
        # dropped word.
        'testimony: a word the reader can look up',
        'toolsmith: not `tools:` either',
        'statement: not `state:` either',
        'stats: not `state:` either',
        'queueing: not `queue:` either',
        'wipe: not `wip:` either',
        'release notes are in the app now',  # no colon: not an anchor
        'fix: CItation scope, not CI',
        'Merged the two panes into one',
        'bump the reading font one step, and remember it',  # not a version
        # Near-misses for the mid-subject rules added in the remediation.
        # The first four are real subjects; a filter that took them would
        # be taking changes the reader can see.
        "boot crash: decode main.dart.js:59285:36 — it's dart2js's num.clamp",
        'Revert bundled songs.json to pre-sync state: CI red from a '
        'regressed upstream snapshot',
        'Seven unreachable sermon references repaired — and why refs.json '
        'must not be regenerated',
        'Update verse_widget.dart: top-align note icon, remove 主* and make '
        'icon bigger',
        # English words spelled entirely out of hex letters. Seven or
        # more characters each, so a length-only SHA rule eats them; the
        # rule requires a DIGIT as well, and these have none.
        'reader: the defaced glyphs in the Traditional transcripts',
        'the council acceded to the shorter reading',
        # A digit run with no a-f letter is a number, not a SHA.
        'maps: the offline pack stops fetching 11370000 dead tiles',
        # Strong's codes are upper-case; the SHA rule is not.
        "fix(strongs): H1245 no longer resolves to nothing",
    ]

    def test_every_bookkeeping_form_is_dropped(self):
        for s in self.BOOKKEEPING:
            self.assertTrue(bc.is_bookkeeping(s), f'not dropped: {s!r}')

    def test_mid_subject_bookkeeping_is_dropped(self):
        for s in self.MID_SUBJECT_BOOKKEEPING:
            self.assertTrue(bc.is_bookkeeping(s), f'not dropped: {s!r}')

    def test_mid_subject_bookkeeping_is_out_of_reach_of_the_prefix_regex(self):
        # Says WHY the second rule exists rather than a longer DROP: no
        # amount of widening the prefix list reaches these, because the
        # bookkeeping is not at the front of the sentence. Two of them
        # open with a bare `fix:`, which is kept on purpose.
        for s in self.MID_SUBJECT_BOOKKEEPING:
            self.assertFalse(bc.DROP.match(s),
                             f'DROP already covers this one: {s!r}')

    def test_no_change_is_dropped(self):
        for s in self.CHANGES:
            self.assertFalse(bc.is_bookkeeping(s), f'wrongly dropped: {s!r}')

    def test_the_shipped_asset_carries_none_of_them(self):
        # The regex passing on a table is not the same claim as the
        # FILE being clean; this is the one the reader cares about.
        data = json.loads(
            (bc.PROJECT / 'assets' / 'changelog.json').read_text('utf-8'))
        offenders = [
            f'{e["version"]}: {n}'
            for e in data['entries'] for n in e['notes']
            if bc.is_bookkeeping(n)
        ]
        self.assertEqual(offenders, [], '\n'.join(offenders))

    def test_the_head_synthesis_is_filtered_like_every_other_entry(self):
        # The regression this pins: the SHA reached the page through the
        # SYNTHESISED top entry, which is the one span not anchored by a
        # `release:` commit. Building the head over a bookkeeping-only
        # tail must leave nothing to list.
        with tempfile.TemporaryDirectory() as tmp:
            repo = Repo(pathlib.Path(tmp))
            repo.commit('release: v0.9.0', '2026-09-01')
            repo.commit('sermons: the first one', '2026-09-02')
            repo.commit('release: v1.0.0', '2026-09-02')
            for s in self.MID_SUBJECT_BOOKKEEPING:
                repo.commit(s, '2026-09-03')
            data = bc.build(10, head_version='1.0.1', repo=repo.path)
            self.assertEqual(data['head']['notes'], 0)
            self.assertEqual([e['version'] for e in data['entries']],
                             ['1.0.0'])


class NotesBetween(WithRepo):
    def test_bookkeeping_is_filtered_and_cherry_picks_deduplicated(self):
        base = self.repo.commit('release: v1.0.0')
        self.repo.commit('picker: the same change')
        self.repo.commit('picker: the same change')  # a cherry-pick
        self.repo.commit('sermons: faster')
        head = self.repo.commit('tests: not a change')
        self.assertEqual(
            bc.notes_between(base, head, repo=self.repo.path),
            ['sermons: faster', 'picker: the same change'],
        )

    def test_the_subjects_reach_the_reader_unrewritten(self):
        # This generator SELECTS; it does not edit. The owner's rule
        # about transcribed words is the same rule one level up: a
        # commit subject is somebody's sentence.
        base = self.repo.commit('release: v1.0.0')
        subject = 'cuvs-yhwh-tr: 白髮 was 白發, and Joseph stored 谷 rather than 穀'
        head = self.repo.commit(subject)
        self.assertEqual(
            bc.notes_between(base, head, repo=self.repo.path), [subject])


class Bound(WithRepo):
    def test_no_version_lists_more_than_the_cap(self):
        self.repo.commit('release: v0.9.0')
        self.repo.commit('sermons: seed')
        self.repo.commit('release: v1.0.0')
        n = bc.MAX_NOTES_PER_VERSION + 5
        for i in range(n):
            self.repo.commit(f'picker: change {i}')
        data = bc.build(10, head_version='1.0.1', repo=self.repo.path)
        top = data['entries'][0]
        self.assertEqual(len(top['notes']), bc.MAX_NOTES_PER_VERSION)
        # The NEWEST ones survive the cut, not the oldest.
        self.assertEqual(top['notes'][0], f'picker: change {n - 1}')
        # The count under `head` is the true number, before the cap:
        # that is what says "a lot happened", which the cap hides.
        self.assertEqual(data['head']['notes'], n)

    def test_the_anchored_path_is_capped_too(self):
        self.repo.commit('release: v0.9.0')
        for i in range(bc.MAX_NOTES_PER_VERSION + 3):
            self.repo.commit(f'picker: change {i}')
        self.repo.commit('release: v1.0.0')
        data = bc.build(10, repo=self.repo.path)
        self.assertEqual(data['entries'][0]['version'], '1.0.0')
        self.assertEqual(len(data['entries'][0]['notes']),
                         bc.MAX_NOTES_PER_VERSION)


class PubspecVersion(unittest.TestCase):
    def test_reads_x_y_z_without_the_build_suffix(self):
        v = bc.pubspec_version()
        self.assertRegex(v, r'^\d+\.\d+\.\d+$')
        text = (bc.PROJECT / 'pubspec.yaml').read_text(encoding='utf-8')
        self.assertIsNotNone(
            re.search(rf'^version:\s*{re.escape(v)}(?:\+|\s*$)', text,
                      re.MULTILINE))


class BumpWiring(unittest.TestCase):
    """Finding 5, and its remediation: ONE place is responsible.

    The first wiring called the generator from tools/release_web.sh.
    That covered the web door and left two others — `BUMP_VERSION=1
    tools/yswords-ios-reinstall.sh` and a bare `tools/bump_version.sh` —
    moving pubspec.yaml without the asset, which ships the stale
    changelog the whole feature exists to fix and turns
    test/changelog_test.dart red on that path. It now runs from
    bump_version.sh, the single writer of the version.
    """

    def script(self, name: str) -> str:
        return (bc.PROJECT / 'tools' / name).read_text('utf-8')

    def test_bump_version_runs_the_generator_with_the_version_it_wrote(self):
        s = self.script('bump_version.sh')
        self.assertIn('build_changelog.py', s,
                      'bump_version.sh does not regenerate the changelog, so '
                      'every door onto a release ships a stale asset')
        self.assertRegex(
            s,
            r'build_changelog\.py[^\n]*(?:\\\n[^\n]*)*--head-version "\$NEW"',
            'the generator is run without --head-version "$NEW", which '
            'regenerates the one-version-behind asset',
        )

    def test_it_runs_after_pubspec_has_actually_moved(self):
        # The asset pins itself to pubspec.yaml. Regenerating BEFORE the
        # new version is written would record the old one and fail
        # test/changelog_test.dart just the same.
        s = self.script('bump_version.sh')
        self.assertLess(s.index('mv "$TMP" "$PUBSPEC"'),
                        s.index('build_changelog.py'))

    def test_a_real_bump_leaves_the_asset_naming_the_new_version(self):
        """The one that survives a comment being right and the code wrong.

        A fixture repository with this repo's two scripts in it, bumped
        for real: 1.0.0 -> 1.0.1, and the asset on disk afterwards has
        to say 1.0.1. Delete the call from bump_version.sh and this
        fails; the text assertions above can be satisfied by a comment.
        """
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            repo = Repo(root)
            (root / 'tools').mkdir()
            for name in ('build_changelog.py', 'bump_version.sh'):
                shutil.copy2(bc.PROJECT / 'tools' / name, root / 'tools' / name)
            (root / 'assets').mkdir()
            (root / 'lib' / 'constants').mkdir(parents=True)
            (root / 'pubspec.yaml').write_text(
                'name: yswords\nversion: 1.0.0\n', encoding='utf-8')
            # The two literals bump_version.sh's awk moves. Shape copied
            # from the real lib/constants/app_version.dart.
            (root / 'lib' / 'constants' / 'app_version.dart').write_text(
                "const String _envAppVersion = String.fromEnvironment(\n"
                "  'APP_VERSION',\n"
                "  defaultValue: '1.0.0',\n"
                ");\n"
                "const String kAppVersion = _envAppVersion == ''"
                " ? '1.0.0' : _envAppVersion;\n"
                "const String kAppReleaseTime = String.fromEnvironment(\n"
                "  'APP_RELEASE_TIME',\n"
                "  defaultValue: '2026-01-01T00:00:00Z',\n"
                ");\n",
                encoding='utf-8')
            repo.commit('release: v0.9.0', '2026-09-01')
            repo.commit('sermons: the first one', '2026-09-02')
            repo.commit('release: v1.0.0', '2026-09-02')
            repo.commit('picker: the link opens', '2026-09-03')

            subprocess.run(
                ['bash', str(root / 'tools' / 'bump_version.sh')],
                cwd=root, capture_output=True, text=True, check=True,
            )

            self.assertIn(
                'version: 1.0.1',
                (root / 'pubspec.yaml').read_text(encoding='utf-8'))
            asset = root / 'assets' / 'changelog.json'
            self.assertTrue(
                asset.exists(),
                'bump_version.sh moved pubspec.yaml and wrote no changelog')
            data = json.loads(asset.read_text(encoding='utf-8'))
            self.assertEqual(data['head']['version'], '1.0.1')
            self.assertEqual(data['entries'][0]['version'], '1.0.1')
            self.assertEqual(data['entries'][0]['notes'],
                             ['picker: the link opens'])

    def test_release_web_reaches_the_generator_before_it_builds(self):
        # An asset refreshed AFTER the bundle is written is not in the
        # bundle, so order is still the point — it is just the BUMP that
        # has to come first now.
        s = self.script('release_web.sh')
        bump = s.index('"$PROJECT/tools/bump_version.sh"')
        build = re.search(r'^"\$FLUTTER" build web', s, re.MULTILINE)
        self.assertIsNotNone(build)
        self.assertLess(bump, build.start(),
                        'the version bump — and so the changelog — happens '
                        'after the web bundle is built')

    def test_release_web_does_not_regenerate_behind_no_bump(self):
        # docs/release-policy.md step 4: `--no-bump` exists so prod gets
        # the SAME build dev and qat verified. A regenerate outside the
        # bump block would rebuild the asset from a HEAD that has moved
        # (at minimum by the dev/qat release commit) and re-date it if
        # prod goes out the next day, so prod would ship a changelog
        # nobody verified.
        s = self.script('release_web.sh')
        for line in s.splitlines():
            stripped = line.strip()
            if stripped.startswith('#'):
                continue
            self.assertNotIn(
                'build_changelog.py', stripped,
                'release_web.sh runs the generator itself again; it is '
                'bump_version.sh\'s job, which --no-bump correctly skips')

    def test_the_native_bump_door_goes_through_bump_version_too(self):
        # `BUMP_VERSION=1 tools/yswords-ios-reinstall.sh` is the second
        # door onto a version change. It must delegate rather than move
        # pubspec itself, or it is back to shipping a stale asset.
        s = self.script('yswords-ios-reinstall.sh')
        self.assertRegex(
            s,
            r'BUMP_VERSION[^\n]*\n\s*"\$PROJECT/tools/bump_version\.sh"',
            'the reinstall script no longer bumps via bump_version.sh, so '
            'it moves the version without regenerating the changelog',
        )


if __name__ == '__main__':
    unittest.main()
