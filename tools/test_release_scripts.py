#!/usr/bin/env python3
"""Tests for the release scripts, run by test/release_scripts_test.dart.

Every script here is exercised FOR REAL, in a temp directory, with the
outside world replaced by stubs on PATH — a bare `origin` repository and
a fake `gh` for the tag script, fake `flutter` / `dart` / `netlify` /
`curl` binaries for the two web scripts, and an in-process fake network
for the python one.

The netlify stub is not a no-op: a "successful" deploy COPIES its --dir
into the directory the curl stub serves that host from. That is the only
way to write the failure these tests exist for — a deploy that exits 0
and does not land. It is not hypothetical. tools/release_web.sh records
it happening twice (v1.4.61 and v1.4.65, both yswords-qat), with
`netlify api listSiteDeploys` showing `state: error, "Deploy canceled"`
AFTER the CLI had exited 0.

What each class pins (2026-09-09 audit of the three scripts that
hard-code the netlify CLI path, plus the tag script):

  * ReleaseWeb — no fix; release_web.sh was already correct. These are
    characterisation tests, so the per-pid waits, the retry and the
    per-site re-fetch cannot be quietly undone. It was `&` + a bare
    `wait` once, which returns 0 whatever the jobs did.
  * ReleaseWebWasmDev — FIXED. It had no CLI guard (a missing binary
    surfaced only after a full wasm build, as bash's "No such file or
    directory") and no verification at all: it printed
    "✓ skwasm experiment deployed" on the CLI's exit code alone. Two of
    its fixtures are the ones that were missing when the verification was
    first written: a site UNREACHABLE rather than merely stale (which is
    what catches `set -e` eating the whole block on one failed curl), and
    a site whose version AND COEP header already match while the bundle
    is stale — the shape a second run of the experiment actually takes,
    since this script never bumps a version.
  * DeploySite — FIXED. Same missing verification, plus the CLI check
    ran per site AFTER staging a full copy of the build tree and named
    no recovery, and it ignored the $NETLIFY variable that both shell
    scripts (and their own recovery text) tell the operator to set.
  * ReleaseGithub — FIXED. `git tag -a` runs before `git push`, so a
    failed push stranded the local tag and the next run refused with
    "already exists. Bump the version first" — for a version that had
    never been released. The CI gate itself is sound and is pinned here.

A note on what "the wrong bundle" means here, because a fixture that
gets it wrong certifies nothing: the two FLAVOURS differ in main.dart.js,
NOT in flutter_bootstrap.js. See the flutter stub below.

Usage:
  python3 tools/test_release_scripts.py
"""

import contextlib
import hashlib
import importlib.util
import io
import os
import pathlib
import shutil
import stat
import subprocess
import sys
import tempfile
import textwrap
import unittest

TOOLS = pathlib.Path(__file__).resolve().parent

GIT_ENV = {
    'GIT_AUTHOR_NAME': 't', 'GIT_AUTHOR_EMAIL': 't@t',
    'GIT_COMMITTER_NAME': 't', 'GIT_COMMITTER_EMAIL': 't@t',
    'GIT_CONFIG_GLOBAL': os.devnull, 'GIT_CONFIG_SYSTEM': os.devnull,
}


def git(cwd, *args):
    return subprocess.run(
        ['git', *args], cwd=str(cwd), capture_output=True, text=True,
        check=True, env={**os.environ, **GIT_ENV},
    )


def executable(path, body):
    path.write_text(textwrap.dedent(body).lstrip(), encoding='utf-8')
    path.chmod(path.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
    return path


# ── tools/release_github.sh ──────────────────────────────────────────

class ReleaseGithub(unittest.TestCase):
    """A tag that never reached origin is not a release."""

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        root = pathlib.Path(self._tmp.name)

        self.origin = root / 'origin.git'
        subprocess.run(['git', 'init', '-q', '--bare', str(self.origin)],
                       check=True)

        self.work = root / 'work'
        (self.work / 'lib' / 'constants').mkdir(parents=True)
        (self.work / 'tools').mkdir()
        git(self.work.parent, 'init', '-q', '-b', 'main', str(self.work))
        (self.work / 'pubspec.yaml').write_text(
            'name: yswords\nversion: 1.0.0+1000000\n', encoding='utf-8')
        (self.work / 'lib' / 'constants' / 'app_version.dart').write_text(
            "const String _envAppVersion =\n"
            "    String.fromEnvironment('APP_VERSION', defaultValue: '');\n"
            "const String kAppVersion = "
            "_envAppVersion == '' ? '1.0.0' : _envAppVersion;\n",
            encoding='utf-8')
        shutil.copy(str(TOOLS / 'release_github.sh'),
                    str(self.work / 'tools'))
        git(self.work, 'add', '.')
        git(self.work, 'commit', '-q', '-m', 'release: v1.0.0')
        git(self.work, 'remote', 'add', 'origin', str(self.origin))
        git(self.work, 'push', '-q', '-u', 'origin', 'main')

        # `gh run list` — the CI gate. Records its argv so a test can
        # assert WHAT was asked, and answers with $GH_CONCLUSION.
        self.bin = root / 'bin'
        self.bin.mkdir()
        self.gh_log = root / 'gh.log'
        executable(self.bin / 'gh', f'''
            #!/usr/bin/env bash
            echo "$*" >> "{self.gh_log}"
            printf '%s\\n' "${{GH_CONCLUSION:-success}}"
        ''')

    def run_script(self, *args, **env):
        return subprocess.run(
            ['bash', 'tools/release_github.sh', *args], cwd=str(self.work),
            capture_output=True, text=True,
            env={**os.environ, **GIT_ENV,
                 'PATH': f'{self.bin}:{os.environ["PATH"]}', **env},
        )

    def reject_pushes(self):
        """origin reachable, but nothing may land on it."""
        executable(self.origin / 'hooks' / 'pre-receive',
                   '#!/usr/bin/env bash\necho "no" >&2\nexit 1\n')

    def remote_tags(self):
        return git(self.work, 'ls-remote', '--tags', 'origin').stdout

    def local_tags(self):
        return git(self.work, 'tag', '-l').stdout

    def test_a_local_tag_origin_lacks_is_pushed_not_called_released(self):
        # Exactly the state a failed push leaves behind.
        git(self.work, 'tag', '-a', 'v1.0.0', '-m', 'v1.0.0')
        self.assertNotIn('v1.0.0', self.remote_tags())

        r = self.run_script()

        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn('refs/tags/v1.0.0', self.remote_tags(),
                      'origin still has no tag, so no platform workflow ran '
                      'and no Release exists:\n' + r.stdout + r.stderr)
        self.assertNotIn('Bump the version first', r.stdout + r.stderr,
                         'bumping cannot push a tag that failed to push')

    def test_a_failed_push_does_not_strand_the_local_tag(self):
        self.reject_pushes()

        r = self.run_script()

        self.assertNotEqual(r.returncode, 0)
        self.assertNotIn('v1.0.0', self.local_tags(),
                         'the local tag survived a failed push; the next run '
                         'would refuse and demand a version bump')
        self.assertIn('do NOT bump', r.stderr)

    def test_a_tag_already_on_origin_is_refused(self):
        git(self.work, 'tag', '-a', 'v1.0.0', '-m', 'v1.0.0')
        git(self.work, 'push', '-q', 'origin', 'v1.0.0')

        r = self.run_script()

        self.assertNotEqual(r.returncode, 0)
        self.assertIn('already on origin', r.stderr)

    def test_a_stranded_tag_on_a_different_commit_is_refused(self):
        # Same version, another commit: pushing the tag we happen to have
        # would release a tree nobody asked for.
        stale = git(self.work, 'rev-parse', 'HEAD').stdout.strip()
        git(self.work, 'tag', '-a', 'v1.0.0', stale, '-m', 'v1.0.0')
        (self.work / 'README.md').write_text('later\n', encoding='utf-8')
        git(self.work, 'add', 'README.md')
        git(self.work, 'commit', '-q', '-m', 'more work')
        git(self.work, 'push', '-q', 'origin', 'main')

        r = self.run_script()

        self.assertNotEqual(r.returncode, 0)
        self.assertIn('exists locally', r.stderr)
        self.assertNotIn('refs/tags/v1.0.0', self.remote_tags())

    def test_the_happy_path_tags_and_pushes(self):
        r = self.run_script()
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn('refs/tags/v1.0.0', self.remote_tags())

    def test_dry_run_pushes_nothing_even_for_a_stranded_tag(self):
        git(self.work, 'tag', '-a', 'v1.0.0', '-m', 'v1.0.0')

        r = self.run_script('--dry-run')

        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertNotIn('refs/tags/v1.0.0', self.remote_tags())
        self.assertIn('v1.0.0', self.local_tags(),
                      'a dry run must not delete the tag it declined to push')
        # "no tag pushed" would be true and useless here: the operator is
        # looking at a stranded tag, and the question they came with is
        # whether THAT one moved. Say which tag stayed put.
        self.assertIn('stranded local v1.0.0 was NOT pushed', r.stdout)

    def test_ci_that_is_not_green_blocks_the_release(self):
        r = self.run_script(GH_CONCLUSION='failure')

        self.assertNotEqual(r.returncode, 0)
        self.assertIn('not success', r.stderr)
        self.assertNotIn('refs/tags/v1.0.0', self.remote_tags())
        self.assertNotIn('v1.0.0', self.local_tags(),
                         'a blocked release must not leave a tag to inherit')

    def test_the_ci_gate_asks_about_this_exact_commit(self):
        # The gate is only as good as its filter: a run picked without
        # --commit would be whatever ran last on any commit.
        head = git(self.work, 'rev-parse', 'HEAD').stdout.strip()

        r = self.run_script()

        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        asked = self.gh_log.read_text(encoding='utf-8')
        self.assertIn('run list', asked)
        self.assertIn(f'--commit {head}', asked)
        self.assertIn("--workflow Flutter CI", asked)

    def test_a_commit_whose_two_version_sources_disagree_is_refused(self):
        (self.work / 'pubspec.yaml').write_text(
            'name: yswords\nversion: 1.0.1+1000001\n', encoding='utf-8')
        git(self.work, 'add', 'pubspec.yaml')
        git(self.work, 'commit', '-q', '-m', 'half a bump')
        git(self.work, 'push', '-q', 'origin', 'main')

        r = self.run_script()

        self.assertNotEqual(r.returncode, 0)
        self.assertIn('disagrees with itself', r.stderr)


# ── the two web scripts share a stub kit ─────────────────────────────

class WebScriptCase(unittest.TestCase):
    """Temp project + stub flutter/dart/netlify/curl.

    `netlify deploy` copies --dir into sites/<host>, and curl reads from
    there. Set NETLIFY_LANDS=0 for the deploy that exits 0 and changes
    nothing — the recorded "Deploy canceled" shape.
    """

    def make_project(self, script):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.root = pathlib.Path(self._tmp.name)
        self.project = self.root / 'project'
        (self.project / 'tools').mkdir(parents=True)
        # No build-number suffix, like the real pubspec: both web
        # scripts take the whole field as APP_VERSION and compare it to
        # what version.json serves.
        (self.project / 'pubspec.yaml').write_text(
            'name: yswords\nversion: 1.0.0\n', encoding='utf-8')
        shutil.copy(str(TOOLS / script), str(self.project / 'tools'))

        self.sites = self.root / 'sites'
        self.sites.mkdir()
        self.hosts = self.root / 'hosts'     # "<site id> <host>" per line
        self.hosts.write_text('', encoding='utf-8')
        self.home = self.root / 'home'
        self.home.mkdir()
        self.log = self.root / 'calls.log'

        self.bin = self.root / 'bin'
        self.bin.mkdir()
        # `flutter build web` writes the files the scripts fetch back.
        #
        # WHICH argument reaches WHICH file is the whole point of this
        # stub, so it is modelled rather than approximated:
        #
        #   • main.dart.js  — where dart-defines land. CHINA_MODE is
        #     compiled in here, which is why it is the only file that can
        #     tell the intl bundle from the cn one.
        #   • flutter_bootstrap.js — web/flutter_bootstrap.js with its two
        #     tokens substituted. The build config carries the engine
        #     revision, the compile target and whether canvaskit is served
        #     locally; it does NOT carry dart-defines. So the two
        #     FLAVOURS' bootstraps come out byte-identical (measured, and
        #     recorded in release_web.sh's verify_site), while a
        #     canvaskit build and a --wasm build genuinely differ.
        #
        # A stub whose bootstrap varied with the dart-defines would let a
        # bootstrap-only check look like a flavour guard, which is the
        # false certification this suite exists to avoid.
        executable(self.bin / 'flutter', f'''
            #!/usr/bin/env bash
            echo "flutter $*" >> "{self.log}"
            flavour=intl; target=canvaskit; canvaskit=cdn
            for a in "$@"; do
              case "$a" in
                *CHINA_MODE=true) flavour=cn ;;
                --wasm) target=skwasm ;;
                --no-web-resources-cdn) canvaskit=local ;;
              esac
            done
            out="$PWD/build/web"
            mkdir -p "$out/assets/assets"
            printf 'bootstrap target=%s canvaskit=%s\\n' \\
              "$target" "$canvaskit" > "$out/flutter_bootstrap.js"
            printf 'main.dart.js flavour=%s\\n' "$flavour" > "$out/main.dart.js"
            printf '{{"app_name":"yswords","version":"1.0.0"}}' \\
              > "$out/version.json"
            printf 'not redistributable\\n' > "$out/assets/assets/nasb.json"
        ''')
        executable(self.bin / 'dart', f'''
            #!/usr/bin/env bash
            echo "dart $*" >> "{self.log}"
        ''')
        executable(self.bin / 'netlify', f'''
            #!/usr/bin/env bash
            echo "netlify $*" >> "{self.log}"
            dir=""; site=""; prev=""
            for a in "$@"; do
              case "$prev" in --dir) dir="$a" ;; --site) site="$a" ;; esac
              prev="$a"
            done
            if [ "${{NETLIFY_LANDS:-1}}" = "1" ]; then
              host="$(awk -v s="$site" '$1 == s {{print $2}}' "{self.hosts}")"
              [ -n "$host" ] || host="$site"
              rm -rf "{self.sites}/$host"
              mkdir -p "{self.sites}/$host"
              cp -R "$dir/." "{self.sites}/$host/"
              printf 'HTTP/2 200\\r\\ncontent-type: text/html\\r\\n' \\
                > "{self.sites}/$host.headers"
              if [ "${{NETLIFY_APPLIES_HEADERS:-1}}" = "1" ] \\
                 && grep -qi 'require-corp' "$dir/_headers" 2>/dev/null; then
                printf 'Cross-Origin-Embedder-Policy: require-corp\\r\\n' \\
                  >> "{self.sites}/$host.headers"
              fi
            fi
            exit "${{NETLIFY_EXIT:-0}}"
        ''')
        # Serves sites/<host>/. Honours -D (headers) and Range, because
        # release_web.sh's main.dart.js check uses both.
        executable(self.bin / 'curl', f'''
            #!/usr/bin/env bash
            echo "curl $*" >> "{self.log}"
            url=""; want_headers=0; range=""
            for a in "$@"; do
              case "$a" in
                -D) want_headers=1 ;;
                Range:*) range="${{a#Range: bytes=0-}}" ;;
                http*) url="$a" ;;
              esac
            done
            host="$(printf '%s' "$url" | sed -n 's#^https://\\([^./]*\\)\\..*#\\1#p')"
            path="$(printf '%s' "$url" | sed -n 's#^https://[^/]*/\\(.*\\)$#\\1#p')"
            if [ "$want_headers" = "1" ]; then
              [ -f "{self.sites}/$host.headers" ] || exit 22
              cat "{self.sites}/$host.headers"
              exit 0
            fi
            f="{self.sites}/$host/$path"
            [ -f "$f" ] || exit 22
            if [ -n "$range" ]; then head -c "$((range + 1))" "$f"; else cat "$f"; fi
        ''')

    def env(self, **extra):
        return {
            **os.environ,
            'PATH': f'{self.bin}:{os.environ["PATH"]}',
            'HOME': str(self.home),
            'FLUTTER': str(self.bin / 'flutter'),
            'DART': str(self.bin / 'dart'),
            'NETLIFY': str(self.bin / 'netlify'),
            'RELEASE_VERIFY_SLEEP': '0',
            **extra,
        }

    def calls(self):
        return self.log.read_text(encoding='utf-8') if self.log.exists() else ''


# ── tools/release_web.sh — characterisation, no fix ──────────────────

class ReleaseWeb(WebScriptCase):
    """Already correct. These keep it that way."""

    HOSTS = {
        'b745ae1f-0780-4fa3-8478-bdf2f2aaf59a': 'yswords-dev',
        '2bcb6644-2a3a-4050-b6dc-5b059bbe96d3': 'yswords-qat',
        '975d1a08-8203-4994-a7ef-ca60452e41bf': 'yswords',
        '50f1502c-299f-4ff8-a21b-28f53eaee1e1': 'yswords-cn-dev',
        '266f97ef-f28b-4313-b83b-653c098df640': 'yswords-cn-qat',
        '3094b5e5-bf62-48e4-9b3b-4ff8adc84f3c': 'yswords-cn',
    }

    def setUp(self):
        self.make_project('release_web.sh')
        self.hosts.write_text(
            ''.join(f'{i} {h}\n' for i, h in self.HOSTS.items()),
            encoding='utf-8')

    def run_script(self, *args, **extra):
        return subprocess.run(
            ['bash', 'tools/release_web.sh', '--no-bump', *args],
            cwd=str(self.project), capture_output=True, text=True,
            env=self.env(**extra),
        )

    def test_every_site_it_says_it_deployed_is_re_fetched(self):
        r = self.run_script('--include-prod')

        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        calls = self.calls()
        for host in self.HOSTS.values():
            self.assertIn(f'https://{host}.netlify.app/version.json', calls,
                          f'{host} was deployed to and never asked')
        self.assertIn('✓ v1.0.0 deployed', r.stdout)

    def test_a_deploy_that_exits_0_and_does_not_land_is_not_a_release(self):
        # The recorded v1.4.61 / v1.4.65 failure: "Deploy canceled" is a
        # state Netlify sets after the CLI has gone, so no exit code
        # carries it and only the site can answer.
        r = self.run_script(NETLIFY_LANDS='0')

        self.assertNotEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn('release ABORTED', r.stdout)
        self.assertNotIn('✓ v1.0.0 deployed', r.stdout)

    def test_a_nonzero_deploy_is_noticed_and_retried_not_waited_away(self):
        # `&` + a bare `wait` returns 0 whatever the jobs did. Both dev
        # and qat must be named, and each must be retried alone.
        r = self.run_script(NETLIFY_EXIT='1', NETLIFY_LANDS='0')

        self.assertNotEqual(r.returncode, 0)
        self.assertIn('WARN: netlify deploy of dev exited non-zero', r.stdout)
        self.assertIn('WARN: netlify deploy of qat exited non-zero', r.stdout)
        self.assertIn('retrying dev alone', r.stdout)

    def test_the_china_bundle_reaching_an_international_site_is_caught(self):
        # The recovery hazard the script names: once the second build
        # starts, build/web holds the CHINA bundle, so redeploying it to
        # an international site ships CHINA_MODE to readers who can reach
        # Google. Right version, right bootstrap, wrong main.dart.js.
        r = self.run_script()
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        for host in ('yswords-dev', 'yswords-qat'):
            (self.sites / host / 'main.dart.js').write_text(
                'main.dart.js flavour=cn\n', encoding='utf-8')

        # NETLIFY_LANDS=0 so the second run's upload leaves the sites in
        # the state above rather than repairing it.
        r = self.run_script(NETLIFY_LANDS='0')

        self.assertNotEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn('CHINA_MODE/intl mix-up', r.stdout)

    def test_a_missing_netlify_cli_stops_it_before_the_build(self):
        r = self.run_script(NETLIFY=str(self.bin / 'gone'))

        self.assertEqual(r.returncode, 1)
        self.assertIn('netlify CLI not found', r.stderr)
        self.assertIn('npm install netlify-cli', r.stderr)
        self.assertNotIn('flutter ', self.calls())


# ── tools/release_web_wasm_dev.sh — fixed ────────────────────────────

class ReleaseWebWasmDev(WebScriptCase):

    DEV = 'b745ae1f-0780-4fa3-8478-bdf2f2aaf59a'

    def setUp(self):
        self.make_project('release_web_wasm_dev.sh')
        self.hosts.write_text(f'{self.DEV} yswords-dev\n', encoding='utf-8')
        # The site starts on the CanvasKit build it is being moved off.
        self.seed_site(version='0.9.9')

    def seed_site(self, *, version, coep=False):
        stale = self.sites / 'yswords-dev'
        stale.mkdir(exist_ok=True)
        (stale / 'flutter_bootstrap.js').write_text(
            'bootstrap canvaskit\n', encoding='utf-8')
        (stale / 'version.json').write_text(
            '{"app_name":"yswords","version":"%s"}' % version,
            encoding='utf-8')
        headers = 'HTTP/2 200\r\ncontent-type: text/html\r\n'
        if coep:
            headers += 'Cross-Origin-Embedder-Policy: require-corp\r\n'
        (self.sites / 'yswords-dev.headers').write_text(
            headers, encoding='utf-8')

    def unreachable_site(self):
        """No files, no headers — every curl in the script exits 22."""
        shutil.rmtree(str(self.sites / 'yswords-dev'))
        (self.sites / 'yswords-dev.headers').unlink()

    def run_script(self, **extra):
        return subprocess.run(
            ['bash', 'tools/release_web_wasm_dev.sh'], cwd=str(self.project),
            capture_output=True, text=True, env=self.env(**extra),
        )

    def test_the_happy_path_says_what_it_confirmed(self):
        r = self.run_script()

        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn('✓ skwasm experiment deployed', r.stdout)
        self.assertIn('COEP require-corp', r.stdout)
        self.assertIn('--wasm', self.calls())

    def test_a_deploy_that_exits_0_and_does_not_land_is_not_success(self):
        r = self.run_script(NETLIFY_LANDS='0')

        self.assertNotEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertNotIn('✓ skwasm experiment deployed', r.stdout)
        self.assertIn('NOT confirmed', r.stderr)
        self.assertIn("version.json says '0.9.9'", r.stderr)
        self.assertIn('still on the CanvasKit bundle', r.stderr)

    def test_a_deploy_whose_coep_header_did_not_take_is_not_success(self):
        # The bundle lands, the per-deploy _headers does not. Nothing
        # about the upload looks wrong; the context is simply not
        # crossOriginIsolated and skwasm degrades to single-threaded —
        # the v1.3.132 bug the script's own header warns about.
        r = self.run_script(NETLIFY_APPLIES_HEADERS='0')

        self.assertNotEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertNotIn('✓ skwasm experiment deployed', r.stdout)
        self.assertIn('Cross-Origin-Embedder-Policy', r.stderr)
        self.assertIn('single-threaded', r.stderr)

    def test_a_stale_bundle_at_the_same_version_with_coep_set_is_not_success(
            self):
        # The primary real-world case, and the one the bootstrap hash
        # exists for. This script never bumps anything — APP_VERSION is
        # read straight out of pubspec.yaml — so a SECOND run of the
        # experiment finds version.json already matching and the COEP
        # header already present from the first wasm deploy. Version and
        # header therefore say nothing, and the bundle hash is the only
        # check left that can catch a "Deploy canceled" that never
        # landed.
        #
        # Getting this wrong is worse than a plain false ✓: the script's
        # ✓ hands the operator exactly one instruction — go read
        # window.crossOriginIsolated — and on a site still serving the
        # CanvasKit build that flag reads false, which looks precisely
        # like the v1.3.132 "skwasm silently went single-threaded" bug.
        # The experiment gets reverted over a failure that was in the
        # upload.
        self.seed_site(version='1.0.0', coep=True)

        r = self.run_script(NETLIFY_LANDS='0')

        self.assertNotEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertNotIn('✓ skwasm experiment deployed', r.stdout)
        self.assertNotIn('matching bundle', r.stdout)
        self.assertIn('still on the CanvasKit bundle', r.stderr)

    def test_a_site_that_answers_nothing_is_diagnosed_not_a_silent_exit(self):
        # An UNREACHABLE site, not a stale one — the case every other
        # fixture here misses, because they all leave sites/yswords-dev/
        # and its .headers in place and the curl stub therefore always
        # exits 0.
        #
        # Under `set -euo pipefail` a plain assignment from a command
        # substitution carries that pipeline's exit status. Run as
        # top-level code, the verification block died on its FIRST curl —
        # measured: exit 22, nothing on stderr, 1 of the 9 calls made, no
        # retry, and the whole diagnosis dead. That is not a theoretical
        # curl failure: a 5xx while the Netlify edge propagates, a DNS
        # blip, a reset or a --max-time timeout all reach it, and it
        # turns a recoverable deploy into a script that says nothing at
        # all.
        self.unreachable_site()

        r = self.run_script(NETLIFY_LANDS='0')

        self.assertNotEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn('NOT confirmed', r.stderr)
        self.assertIn("version.json says 'unreachable'", r.stderr)
        self.assertIn("Cross-Origin-Embedder-Policy is 'absent'", r.stderr)
        self.assertIn('still on the CanvasKit bundle', r.stderr)
        self.assertEqual(self.calls().count('curl '), 9,
                         'the 3-attempt retry never ran: one failing curl '
                         'took the whole script with it\n' + self.calls())

    def test_a_missing_netlify_cli_stops_it_before_the_wasm_build(self):
        r = self.run_script(NETLIFY=str(self.bin / 'gone'))

        self.assertEqual(r.returncode, 1)
        self.assertIn('netlify CLI not found', r.stderr)
        self.assertIn('npm install netlify-cli', r.stderr)
        self.assertNotIn('flutter ', self.calls(),
                         'the build ran before discovering it could not deploy')


# ── tools/deploy_site.py — fixed ─────────────────────────────────────

def load_deploy_site():
    spec = importlib.util.spec_from_file_location(
        'deploy_site_under_test', str(TOOLS / 'deploy_site.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


# The two flavours' main.dart.js, which is where CHINA_MODE actually
# lands — modelled the way tools/release_web.sh's suite already models
# it, and deliberately larger than deploy_site.MAIN_SLICE so the Range
# request is doing real work rather than fetching the whole file anyway.
MAIN_INTL = b'main.dart.js flavour=intl\n' + b'\x00' * 300_000
MAIN_CN = b'main.dart.js flavour=cn\n' + b'\x00' * 300_000

# The manifest the BASE build carries. tools/site-icons/<flavour>-<tier>/
# overlays its own on top; a deploy that ships this one is a deploy whose
# whole reason for existing did not happen.
BASE_MANIFEST = b'{"name":"YsWords","icons":[]}'


class DeploySite(unittest.TestCase):

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.root = pathlib.Path(self._tmp.name)

        self.mod = load_deploy_site()
        self.mod.REPO_ROOT = str(self.root)
        self.mod.VERIFY_SLEEP = 0

        build = self.root / 'build' / 'web' / 'icons'
        build.mkdir(parents=True)
        web = build.parent
        (web / 'flutter_bootstrap.js').write_text('bootstrap v1.0.0\n',
                                                  encoding='utf-8')
        (web / 'version.json').write_text(
            '{"app_name":"yswords","version":"1.0.0"}', encoding='utf-8')
        (web / 'main.dart.js').write_bytes(MAIN_INTL)
        (web / 'manifest.json').write_bytes(BASE_MANIFEST)
        icons = self.root / 'tools' / 'site-icons' / 'intl-dev' / 'icons'
        icons.mkdir(parents=True)
        (icons.parent / 'favicon.png').write_bytes(b'\x89PNG dev')
        (icons.parent / 'manifest.json').write_text('{"name":"dev"}',
                                                    encoding='utf-8')
        for name in ('Icon-192.png', 'Icon-512.png',
                     'Icon-maskable-192.png', 'Icon-maskable-512.png'):
            (icons / name).write_bytes(b'\x89PNG ' + name.encode())

        self.netlify_log = self.root / 'netlify.log'
        self.netlify = executable(self.root / 'netlify', f'''
            #!/usr/bin/env bash
            echo "$*" >> "{self.netlify_log}"
            echo "Website Draft URL: https://example.netlify.app"
            exit ${{NETLIFY_EXIT:-0}}
        ''')
        self.mod.NETLIFY_CLI = str(self.netlify)

        # What the site "serves". Default: the deploy landed, overlay and
        # all.
        self.served = {
            'version.json': b'{"app_name":"yswords","version":"1.0.0"}',
            'main.dart.js': MAIN_INTL,
            'manifest.json': b'{"name":"dev"}',
            'flutter_bootstrap.js': b'bootstrap v1.0.0\n',
        }
        self.asked = []          # (filename, headers) per fetch

        def fake_fetch(url, timeout=30, headers=None):
            self.assertTrue(url.startswith('https://yswords-dev.netlify.app/'),
                            f'asked the wrong host: {url}')
            name = url.rsplit('/', 1)[-1]
            headers = dict(headers or {})
            self.asked.append((name, headers))
            body = self.served.get(name)
            if body is None:
                raise OSError('404')
            # Netlify answers 206 to this; anything else would be sending
            # ~10 MB per site per attempt.
            match = headers.get('Range')
            if match:
                return body[:int(match.rsplit('-', 1)[-1]) + 1]
            return body

        self.mod._fetch = fake_fetch

    def headers_for(self, name):
        """The headers the LAST fetch of `name` was made with."""
        for asked, headers in reversed(self.asked):
            if asked == name:
                return headers
        self.fail(f'{name} was never fetched; asked for '
                  f'{[a for a, _ in self.asked]}')

    def deploy(self, site='yswords-dev', **kwargs):
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            rc = self.mod.deploy_one(site, **kwargs)
        return rc, out.getvalue(), err.getvalue()

    def main(self, *argv):
        out, err = io.StringIO(), io.StringIO()
        old = sys.argv
        sys.argv = ['deploy_site.py', *argv]
        try:
            with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
                rc = self.mod.main()
        finally:
            sys.argv = old
        return rc, out.getvalue(), err.getvalue()

    def test_a_site_serving_the_deploy_is_a_deploy(self):
        rc, out, err = self.deploy()

        self.assertEqual(rc, 0, out + err)
        self.assertIn('✓ deployed yswords-dev', out)
        self.assertIn('--site b745ae1f-0780-4fa3-8478-bdf2f2aaf59a',
                      self.netlify_log.read_text(encoding='utf-8'))

    def test_a_site_that_did_not_move_is_not(self):
        # netlify exits 0; the site still serves what it served before.
        self.served['version.json'] = \
            b'{"app_name":"yswords","version":"0.9.9"}'
        self.served['flutter_bootstrap.js'] = b'bootstrap v0.9.9\n'

        rc, out, err = self.deploy()

        self.assertNotEqual(rc, 0, out + err)
        self.assertNotIn('✓ deployed', out)
        self.assertIn('not serving this deploy', err)
        self.assertIn("expected '1.0.0'", err)

    def test_a_site_serving_the_other_flavours_bundle_is_not(self):
        # Right version, RIGHT bootstrap, wrong build — the mix-up that
        # puts CHINA_MODE in front of readers who can reach Google.
        #
        # The bootstrap is left matching on purpose, because that is what
        # the real builds produce. tools/build_web.py builds both
        # flavours with identical flags apart from
        # --dart-define=CHINA_MODE=true, dart-defines do not reach
        # flutter_bootstrap.js (web/flutter_bootstrap.js is a committed
        # two-token file), and release_web.sh retired the bootstrap as a
        # flavour check on 2026-08-30 for exactly this reason. A fixture
        # that made the two bootstraps differ would be certifying a check
        # against a world the builds do not produce.
        self.served['main.dart.js'] = MAIN_CN

        rc, out, err = self.deploy()

        self.assertNotEqual(rc, 0, out + err)
        self.assertNotIn('✓ deployed', out)
        self.assertIn('main.dart.js differs', err)
        self.assertIn('CHINA_MODE went to the wrong site', err)

    def test_the_flavour_check_reads_a_slice_not_the_whole_bundle(self):
        # main.dart.js is ~10 MB and this runs on six sites on every
        # retry. `Accept-Encoding: identity` is not decoration either:
        # without it the range applies to a compressed stream instead of
        # the bytes on disk, and the hashes could never match.
        rc, out, err = self.deploy()

        self.assertEqual(rc, 0, out + err)
        headers = self.headers_for('main.dart.js')
        self.assertEqual(headers.get('Range'),
                         f'bytes=0-{self.mod.MAIN_SLICE - 1}')
        self.assertEqual(headers.get('Accept-Encoding'), 'identity')

    def test_a_wasm_build_is_verified_by_the_bundle_it_actually_has(self):
        # `tools/build_web.py --wasm` prints deploy_site.py as its next
        # step, and a dart2wasm build's payload is main.dart.wasm. Making
        # main.dart.js the only acceptable evidence would refuse that
        # deploy at the verification step — AFTER it has uploaded — and
        # send the operator hunting for a file the build never emitted.
        web = self.root / 'build' / 'web'
        (web / 'main.dart.js').unlink()
        (web / 'main.dart.wasm').write_bytes(MAIN_INTL)
        del self.served['main.dart.js']
        self.served['main.dart.wasm'] = MAIN_INTL

        rc, out, err = self.deploy()
        self.assertEqual(rc, 0, out + err)
        self.assertEqual(self.headers_for('main.dart.wasm').get('Range'),
                         f'bytes=0-{self.mod.MAIN_SLICE - 1}')

        # And it is a real check on that file, not a shrug: the flavour
        # mix-up must still be caught through the wasm bundle.
        self.served['main.dart.wasm'] = MAIN_CN

        rc, out, err = self.deploy()
        self.assertNotEqual(rc, 0, out + err)
        self.assertIn('main.dart.wasm differs', err)
        self.assertIn('CHINA_MODE went to the wrong site', err)

    def test_a_site_serving_no_overlay_at_all_is_not_a_deploy(self):
        # Per-tier PWA icons + manifest are this script's whole reason to
        # exist (module docstring). A deploy that landed the base build
        # untouched used to print "✓ deployed" like any other, because
        # nothing verified the one thing this script adds.
        self.served['manifest.json'] = BASE_MANIFEST

        rc, out, err = self.deploy()

        self.assertNotEqual(rc, 0, out + err)
        self.assertNotIn('✓ deployed', out)
        self.assertIn('manifest.json differs', err)
        self.assertIn("another tier's PWA icons", err)

    def test_a_nonzero_cli_is_still_a_failure(self):
        os.environ['NETLIFY_EXIT'] = '1'
        self.addCleanup(os.environ.pop, 'NETLIFY_EXIT', None)

        rc, out, err = self.deploy()

        self.assertNotEqual(rc, 0)
        self.assertIn('deploy failed', err)

    def test_a_missing_cli_is_refused_before_anything_is_staged(self):
        self.mod.NETLIFY_CLI = str(self.root / 'gone')
        staged = []
        self.mod.deploy_one = lambda site, **kw: staged.append(site) or 0

        rc, out, err = self.main('--all')

        self.assertEqual(rc, 2, out + err)
        self.assertEqual(staged, [], 'it staged builds it could never deploy')
        self.assertIn('netlify CLI not found', err)
        self.assertIn('npm install netlify-cli', err)

    def test_a_cli_that_is_not_executable_is_a_message_not_a_traceback(self):
        os.chmod(str(self.netlify), 0o644)

        rc, out, err = self.main('yswords-dev')

        self.assertEqual(rc, 2, out + err)
        self.assertIn('not executable', err)

    def test_a_cli_that_stops_being_runnable_mid_run_does_not_abort_it(self):
        # The up-front guard in main() is checked ONCE, and --all then
        # stages and uploads six ~10 MB trees over several minutes. The
        # recorded hazard is a cleanup in ANOTHER project's node_modules
        # (2026-09-09), which does not wait for this script — so the CLI
        # can stop being runnable between that check and any of the
        # deploys, and this is the layer that has to survive it.
        #
        # Not the same failure as the up-front one: a missing file raises
        # FileNotFoundError, a file that is no longer executable raises
        # PermissionError. Catching only the first let the second escape
        # deploy_one as a traceback and take the rest of a --all run with
        # it, naming no way back.
        os.chmod(str(self.netlify), 0o644)

        rc, out, err = self.deploy()

        self.assertEqual(rc, 2, out + err)
        self.assertIn('could not run the netlify CLI', err)
        self.assertIn('npm install netlify-cli', err)

    def test_the_netlify_variable_the_recovery_text_names_is_honoured(self):
        os.environ['NETLIFY'] = '/somewhere/else/netlify'
        self.addCleanup(os.environ.pop, 'NETLIFY', None)

        self.assertEqual(load_deploy_site().NETLIFY_CLI,
                         '/somewhere/else/netlify')

    def test_one_failure_among_many_is_named_at_the_end(self):
        done = []

        def one_bad(site, dry_run=False):
            done.append(site)
            return 1 if site == 'yswords-cn-dev' else 0

        self.mod.deploy_one = one_bad

        rc, out, err = self.main('--tier', 'dev')

        self.assertEqual(rc, 1)
        self.assertEqual(sorted(done), ['yswords-cn-dev', 'yswords-dev'])
        self.assertIn('yswords-cn-dev', err)
        self.assertIn('did not deploy', err)

    def test_the_verifier_compares_against_what_was_actually_staged(self):
        # Not against a constant: the check must fail if the staged
        # bundle changes and the site does not.
        (self.root / 'build' / 'web' / 'flutter_bootstrap.js').write_text(
            'bootstrap v1.0.1\n', encoding='utf-8')

        rc, out, err = self.deploy()

        self.assertNotEqual(rc, 0, out + err)
        digest = hashlib.sha256(b'bootstrap v1.0.1\n').hexdigest()
        self.assertIn(digest[:12], err)


if __name__ == '__main__':
    unittest.main(verbosity=2)
