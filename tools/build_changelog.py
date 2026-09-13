#!/usr/bin/env python3
"""Turn the git history into the changelog the app ships.

WHY THIS EXISTS. On 2026-09-09 the owner asked for release notes in
the app — 「也要有历史的release note但是不要全部的」. The finding was
that there were none to show: all 88 GitHub Releases carry the same
body, `Automated Linux x64 build. Download the tarball...`, written by
the Linux job of `release-linux.yml`. That is build instructions for
one platform, not a note, and it is identical on every release.

The notes were in the commit subjects the whole time. This app writes
them as sentences — "A retired edition is announced once, not on every
launch", "versions: plain BSB comes off the interface, and the English
default with it" — which is already a changelog, so nothing here
rewrites them. It selects.

WHAT IS DROPPED, and why each one is bookkeeping rather than a change
the reader can see:

  * `release: vX.Y.Z to dev + prod` — the mechanics of shipping. There
    is one per version, so leaving them in would make the changelog
    half release lines.
  * `PROJECT_STATE: …` and `docs: …` — this repository's own record.
    Real work, none of it visible in the app.
  * `chore:` / `ci:` / `test:` — the same, one level down.

WHY THE SPINE IS THE `release:` COMMITS AND NOT THE TAGS. Tags were
the obvious choice and are wrong here: `release_github.sh` only started
pushing them on 2026-09-08, so the repository holds **68** tags for
88 versions. Built on tags, the oldest entry swallowed the entire
history back to the initial commit — 719 notes in one row, 51 KB.
Every released version does have a `release: vX.Y.Z …` commit (older
ones read `chore(release): vX.Y.Z`), all the way back, so those are
the anchors.

WHY IT IS A BUNDLED ASSET rather than fetched. The GitHub bodies for
every EXISTING release are the boilerplate above, so an app that read
them would show an empty history until enough new releases accumulated
— the reader would ask for the changelog and be told there isn't one,
which is worse than not offering it. Generating from git gives a full
history on the first build, and gives it offline, which matters for a
Bible app used on a tablet with no SIM.

HOW MANY, and why the first two answers were both wrong. The owner's
constraint was 「不要全部的而是足够的不然太多」. The first guess was 20
versions; measured, this app ships **29 versions in three days**, so 20
is a day and a half and reads as a broken page. The second guess was 30
"because that is three to six weeks" — measured, it is three days.

The measurement that settled it: **120 versions is 115 entries, 250
notes, 25 KB, and one month** (2026-08-11 → 2026-09-09) spread over 17
days. Size was never the constraint — 25 KB is nothing to bundle. The
constraint is the reader's scroll, and the thing that makes a changelog
here unreadable is not the notes, it is **115 version numbers**. So the
notes are all kept and the page groups them BY DAY: seventeen headings
instead of a hundred and fifteen rows. Throwing away history would have
been solving the wrong half.

Versions whose every commit was filtered out are dropped rather than
shown empty. Everything older than the window stays on GitHub, which
the page links to.

THE BUILD'S OWN VERSION (2026-09-09 review, finding 1). Anchoring on
`release:` commits has a hole at the top, and it is at the top that
this page is read. The release commit for vX.Y.Z is written AFTER the
build for X.Y.Z has been deployed, so the asset baked into a build
could only ever reach the version before it — measured here, pubspec
said 1.5.21 while the shipped asset stopped at 1.5.20. Two consequences
for the reader: the 「你的版本」 badge on the page compares against the
running version and therefore never rendered at all, and "what's new"
was one release behind on a page whose entire job is its first entry.

So the top entry is now SYNTHESISED. `--head-version` (the version
being built; pubspec's when the flag is absent) names it, and its notes
are every commit after the newest `release:` anchor up to HEAD —
exactly the span the release commit will cover once it is written. Any
anchor at or above that version is FOLDED IN rather than listed
separately — its own (a `--no-bump` re-run, or a regenerate after the
release commit has been written), and any NEWER one that `git log --all`
can see on a branch this build does not contain. So the version appears
once, at the top, with every half of its span, and nothing above it. The
asset records the version it was generated for under `head`, which is
how test/changelog_test.dart can tell "generated after the bump" from
"generated before it" — the difference the reader sees.

WHO RUNS IT. `tools/bump_version.sh`, which is the one place the
version in pubspec.yaml moves — so every door onto a release
(release_web.sh, `BUMP_VERSION=1 yswords-ios-reinstall.sh`, a bare
bump) regenerates the asset, and `release_web.sh --no-bump` correctly
ships prod the same asset dev and qat verified.

Usage:
  tools/build_changelog.py            # write assets/changelog.json
  tools/build_changelog.py --check    # print, write nothing
  tools/build_changelog.py --head-version 1.5.21 --head-date 2026-09-09
"""

import argparse
import json
import pathlib
import re
import subprocess
import sys

PROJECT = pathlib.Path(__file__).resolve().parent.parent
OUT = PROJECT / 'assets' / 'changelog.json'

# How many versions-with-something-to-say to keep. Measured at this
# repo's rate: about one month, 250 notes, 25 KB. See "HOW MANY" above
# for the two smaller numbers that were tried and why they were wrong.
DEFAULT_MAX_ENTRIES = 120

# A released version, in either convention this repo has used.
ANCHOR = re.compile(
    r'^(?:release|chore\(release\)):\s*v?(\d+\.\d+\.\d+)\b',
    re.IGNORECASE,
)

# `type` or `type(scope)` — the scoped form is why `chore(release):`
# survived the first draft of this filter and put twelve release lines
# into the notes.
#
# 2026-09-09 (review finding 2): widened to the bookkeeping subjects
# THIS repository actually writes, which the conventional-commit list
# above never covered. Eighteen of them were on the shipped page:
# `audit:` and its three other spellings, `tools:`, `tools+docs:`,
# `state:`, `tests:` (the list had `test:` only, singular), `queue:`,
# `fix CI:` and `fix(lint):`. Each is real work and none of it is
# visible in the app — "tools: pin web_verify_headless.mjs's Chrome
# locale" was in front of readers. Added with them: `nightly:` (the
# unattended loop's own record) and `wip(nasb):` (the 40-commit
# chapter-by-chapter import of a translation — a pure asset
# regeneration, and the reader wants "the NASB is in" once, not forty
# times), plus `release_web:` / `release-macos:`, the release plumbing
# under a name the `release(scope):` branch cannot see.
#
# The line each of these is on: does the reader of the app see it? A
# free-form area label this repo also uses — `sermons:`, `versions:`,
# `videos:`, `originals:` — is the note's own first word and stays.
DROP = re.compile(
    r'^(?:'
    r'(?:release|docs?|chore|ci|tests?|build|style|refactor'
    r'|tools|state|queue|nightly|wip)'
    # `tools+docs:`, `docs+test:` — this repo joins two bookkeeping
    # types with a `+` when one commit did both. Bookkeeping plus
    # bookkeeping is still bookkeeping.
    r'(?:\+[a-z]+)*'
    r'(?:\([^)]*\))?:'
    # `audit:`, `audit_p0:`, `audit docstrings:`, `audit re-run:` — the
    # census is written four ways and all four are the repo's own record.
    r'|audit(?:[_ -][^:]{0,40})?:'
    # `release_web:`, `release-macos:` — a release script or workflow,
    # not a release.
    r'|release[-_][a-z0-9]+:'
    # CI and lint repairs wearing a `fix` token. A bare `fix:` stays —
    # nearly all of those are changes a reader can see; it is only when
    # CI is the FIRST thing the subject names that the commit is about
    # the build going red, which happens here in three spellings:
    # `fix CI: …`, `Fix CI red from …`, `fix: CI red on the …`.
    r'|fix\s*\(\s*(?:ci|lint|release)\s*\)\s*:'
    r'|fix\b[\s:]*CI\b'
    # `bump version to 1.4.174` — the version number IS the row it
    # would sit in. It surfaced only once the filter above freed a slot
    # under MAX_NOTES_PER_VERSION, which is worth saying: dropping
    # bookkeeping promotes whatever the cap was hiding, so the filter
    # has to be right about the tail too, not only the head.
    r'|bump\s+version\b'
    r'|PROJECT_STATE\b'
    # `git log --no-merges` already drops true merges; this catches a
    # squashed or fast-forwarded one, which arrives as an ordinary
    # commit whose subject is still the merge's.
    r'|Merge (?:branch|pull request|remote-tracking branch|origin/)'
    r')',
    re.IGNORECASE,
)

# 2026-09-09 (remediation, finding 1): DROP is anchored at the START of
# the subject, and the three worst lines on the shipped page had no type
# token at all — the filter never got to look at them. Entry 0, note 0,
# the most-read line on the page, was:
#
#   "Stop the 50dcc102 apparatus-reformat noise from burying real drift"
#
# and two more were "fix: audit_p0.py's check() silently missed explicit
# null Strong's codes" and "fix: harness state-oracle JSON-quoting bug;
# … run repro against dev with 0fa4effb live". A bare `fix:` is kept on
# purpose (nearly all of those ARE reader-visible), so widening DROP's
# prefix list could not reach them.
#
# Two marks say "repository bookkeeping" wherever in the subject they
# appear, and neither depends on the author having used a type token:
#
#   * A COMMIT SHA. A reader of the app cannot resolve a hex blob and
#     has nothing to do with it; a subject that needs one is talking to
#     the repository, not to them. Required to carry BOTH a digit and an
#     a-f letter so that ordinary English words made only of hex letters
#     — "defaced", "acceded", "effaced" — are not eaten, and matched
#     case-sensitively so that Strong's-style codes are out of scope.
#   * A FILE UNDER tools/. The app ships Dart and assets; a `.py`,
#     `.sh`, `.zsh`, `.mjs` or workflow `.yml` is this repository's own
#     machinery, and so is a literal `tools/` path. `.dart`, `.json` and
#     `.md` are deliberately NOT here: "Revert bundled songs.json to
#     pre-sync state" and "Update verse_widget.dart: top-align note
#     icon" are changes a reader sees.
#
# Measured over all 1700 subjects in this repository's history: six are
# newly dropped, all six bookkeeping, and nothing a reader can see is
# lost. The table in tools/test_build_changelog.py holds all six plus
# the near-misses.
# 2026-09-09, second pass. The four below survived the first version of
# this regex and reached the shipped asset, because each names its
# apparatus in the MIDDLE of an otherwise ordinary-looking sentence:
#
#   "fix: stop failing this repo's CI for an upstream song-catalogue
#    outage"                       — touched only PROJECT_STATE.md, docs,
#                                     a script and its test
#   "boot crash: extend the harness to prove the sweep's forced reload
#    fires"
#   "boot crash: pre-fix 1.4.178 bundle also runs clean under the
#    faithful plant, but a refuter found the harness can't test the real
#    variable"
#   "fix: harness planted undecodable raw strings, explaining the
#    bare-hash anomaly; also fix a process leak"
#
# `harness`, `refuter` and "this repo" are words that only ever appear
# when a subject is talking about the machinery rather than the app.
#
# Deliberately NOT `\bCI\b`: the first note above is already caught by
# "this repo", and a bare CI collides with the near-miss this table has
# pinned since the first pass — 'fix: CItation scope, not CI'. A filter
# that has to break an existing keeper to catch a case another pattern
# already catches is a filter that is too wide.
#
# The near-miss that must NOT be dropped, and is pinned as such in the
# test table: "deep links: snapshot the boot QUERY, the way the hash
# already is" — `snapshot` and `hash` are ordinary words about a feature
# a reader uses, so neither is in this pattern.
BOOKKEEPING_ANYWHERE = re.compile(
    r'\b(?=[0-9a-f]{7,40}\b)(?=[0-9a-f]*[0-9])(?=[0-9a-f]*[a-f])'
    r'[0-9a-f]{7,40}\b'
    r'|\b[Tt]ools/'
    r'|\b[\w.+-]+\.(?:py|sh|zsh|mjs|ya?ml)\b'
    r'|\b(?:harness|refuter)\b'
    r'|\bthis repo\b'
)


def is_bookkeeping(subject: str) -> bool:
    """The whole filter, in one place.

    Both halves matter and they fail differently: DROP reads the
    subject's opening token, BOOKKEEPING_ANYWHERE reads the rest of the
    line. Callers — including the head synthesis, which is where the
    SHA reached the top of the page — must go through this rather than
    through either regex, or they get half a filter.
    """
    return bool(DROP.match(subject) or BOOKKEEPING_ANYWHERE.search(subject))


def _version_key(v: str) -> tuple[int, ...]:
    """`1.5.9` sorts BELOW `1.5.21`, which a string compare gets wrong.

    Only ever called on strings ANCHOR or pubspec matched, both of which
    are `\\d+\\.\\d+\\.\\d+`.
    """
    return tuple(int(p) for p in v.split('.'))


def pubspec_version(repo: pathlib.Path | None = None) -> str:
    """The `version:` in pubspec.yaml without the `+build` suffix.

    That suffix is Android's versionCode and is never shown to anyone,
    so it must not reach the changelog either — `1.5.21+521` and
    `1.5.21` have to compare equal to the page's `kAppVersion`.
    """
    text = ((repo or PROJECT) / 'pubspec.yaml').read_text(encoding='utf-8')
    m = re.search(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)', text, re.MULTILINE)
    if not m:
        raise SystemExit('pubspec.yaml has no version: line')
    return m.group(1)

# No single version may fill the whole page. Nothing in this repo's
# history comes near it; it is here so that a first release, or a
# long-lived branch landing at once, degrades into "a lot happened"
# rather than into a wall.
MAX_NOTES_PER_VERSION = 12


# `repo` is a test seam and nothing more: tools/test_build_changelog.py
# builds throwaway git repositories of empty commits, because reading
# `git log` IS this file's job and a mocked log would only prove the
# mock.
def git(*args: str, repo: pathlib.Path = PROJECT) -> str:
    return subprocess.run(
        ['git', *args], cwd=repo, capture_output=True, text=True, check=True
    ).stdout.strip()


def released_versions(
    limit: int, repo: pathlib.Path = PROJECT,
) -> list[tuple[str, str, str]]:
    """`(version, sha, date)` for the newest [limit] release commits.

    Walked newest-first and stopped at [limit], so the initial commit
    is never reached and no entry can absorb the whole history — the
    exact failure the tag-based first draft had.
    """
    out = git(
        # HEAD, not --all: the build is cut from HEAD, and a `release:`
        # commit on an unmerged branch or a stray worktree is not this
        # build's history. With --all such an anchor became a shipped
        # row — reproduced by review with a throwaway branch.
        'log', '--format=%H\x1f%cs\x1f%s', '--no-merges', 'HEAD',
        repo=repo,
    ).splitlines()
    found: list[tuple[str, str, str]] = []
    seen: set[str] = set()
    for line in out:
        sha, date, subject = line.split('\x1f', 2)
        m = ANCHOR.match(subject)
        if not m:
            continue
        version = m.group(1)
        # A version re-cut (dev, then dev + prod) has two release
        # commits. The FIRST one seen walking backwards is the newest,
        # which is the one whose date the reader should be shown.
        if version in seen:
            continue
        seen.add(version)
        found.append((version, sha, date))
        if len(found) > limit:
            break
    return found


def notes_between(
    older_sha: str | None, newer_sha: str, repo: pathlib.Path = PROJECT,
) -> list[str]:
    span = f'{older_sha}..{newer_sha}' if older_sha else newer_sha
    subjects = git(
        'log', '--no-merges', '--format=%s', span, repo=repo,
    ).splitlines()
    kept: list[str] = []
    for s in subjects:
        s = s.strip()
        if not s or is_bookkeeping(s):
            continue
        if s not in kept:  # a cherry-pick should not read as two changes
            kept.append(s)
    return kept


def build(
    max_entries: int,
    head_version: str | None = None,
    head_date: str | None = None,
    repo: pathlib.Path = PROJECT,
) -> dict:
    # One extra, so the oldest kept entry still has a predecessor to
    # measure against rather than reaching back to the initial commit.
    versions = released_versions(max_entries, repo=repo)
    entries = []
    head: dict | None = None
    if head_version:
        # Finding 1: the version being built, whose own `release:`
        # anchor does not exist yet. Its span is everything after the
        # newest anchor — and if that anchor already NAMES this version
        # (a re-run after the release commit, or --no-bump), the anchor
        # is dropped from the list below and the span starts one
        # earlier, so the version is listed once with both halves
        # rather than twice with one each.
        #
        # 2026-09-09 (remediation, finding 2): this used to inspect
        # versions[0] ONLY — `if versions[0][0] == head_version:
        # versions = versions[1:]`. released_versions() walks
        # `git log --all`, so an anchor for the version being built can
        # sit DEEPER in the list whenever a newer `release:` commit
        # exists on any ref (a `--no-bump` build, a release cut on a
        # branch). With anchors 1.0.2 / 1.0.1 / 1.0.0 and head 1.0.1 the
        # generator emitted 1.0.1, then 1.0.2, then 1.0.1 again: two rows
        # for one version, BOTH wearing 「你的版本」 (the page's badge is
        # `entry.version == kAppVersion`), with a newer version wedged
        # between them.
        #
        # The rule is not "drop the duplicate" but "the asset ships
        # INSIDE the build for head_version". A version at or above the
        # one being built is either this build — synthesised at the top,
        # here — or a build this one does not contain, and listing it
        # would tell the reader about changes they do not have. So every
        # such anchor goes, and the head's span starts at the newest
        # anchor strictly below it.
        head_key = _version_key(head_version)
        versions = [v for v in versions if _version_key(v[0]) < head_key]
        base = versions[0][1] if versions else None
        notes = notes_between(base, 'HEAD', repo=repo)
        head = {
            'version': head_version,
            'date': head_date or git(
                'log', '-1', '--format=%cs', 'HEAD', repo=repo),
            # The TRUE count, before MAX_NOTES_PER_VERSION trims the
            # list: this is what lets a test tell "nothing to say" from
            # "capped", which the entry itself cannot say.
            'notes': len(notes),
        }
        if notes:
            entries.append({
                'version': head_version,
                'date': head['date'],
                'notes': notes[:MAX_NOTES_PER_VERSION],
                # What the cap dropped, so the page can SAY so instead of a
                # version quietly looking smaller than it was.
                'omitted': max(0, len(notes) - MAX_NOTES_PER_VERSION),
            })
        else:
            # A data-only or tooling-only release. Recorded under
            # `head` so the asset still says which build it was
            # generated for, but not listed — an empty row is a version
            # number pretending to be news, the same rule as below.
            print(f'note: v{head_version} has no reader-visible change '
                  'since the last release; not listed', file=sys.stderr)
    for i, (version, sha, date) in enumerate(versions):
        if len(entries) >= max_entries:
            break
        older = versions[i + 1][1] if i + 1 < len(versions) else None
        if older is None:
            # No predecessor in the window: rather than walk to the
            # beginning of the repository, stop. The page links to
            # GitHub for everything older, which is where it is.
            break
        notes = notes_between(older, sha, repo=repo)
        if not notes:
            # A version whose every commit was bookkeeping. Dropping it
            # rather than showing an empty row is the difference between
            # a changelog and a list of version numbers.
            continue
        entries.append({
            'version': version,
            'date': date,
            'notes': notes[:MAX_NOTES_PER_VERSION],
            # What the cap dropped, so the page can SAY so instead of a
            # version quietly looking smaller than it was.
            'omitted': max(0, len(notes) - MAX_NOTES_PER_VERSION),
        })
    data: dict = {'entries': entries}
    if head is not None:
        data['head'] = head
    return data


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument('--check', action='store_true')
    ap.add_argument('--max-entries', type=int, default=DEFAULT_MAX_ENTRIES)
    ap.add_argument(
        '--head-version', default=None,
        help='the version being built (default: pubspec.yaml). Its entry '
             'is synthesised from the commits after the last release: '
             'anchor, because its own anchor does not exist yet',
    )
    ap.add_argument(
        '--head-date', default=None,
        help='YYYY-MM-DD for the head entry (default: the HEAD commit date)',
    )
    args = ap.parse_args()

    data = build(
        args.max_entries,
        head_version=args.head_version or pubspec_version(),
        head_date=args.head_date,
    )
    if not data['entries']:
        print('refusing to write an empty changelog', file=sys.stderr)
        return 1

    text = json.dumps(data, ensure_ascii=False, separators=(',', ':'))
    if args.check:
        print(json.dumps(data, ensure_ascii=False, indent=2))
        print(
            f'\n{len(data["entries"])} versions, '
            f'{sum(len(e["notes"]) for e in data["entries"])} notes, '
            f'{len(text.encode())} bytes',
            file=sys.stderr,
        )
        return 0

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(text, encoding='utf-8')
    print(f'{OUT.relative_to(PROJECT)}: {len(data["entries"])} versions, '
          f'{len(text.encode())} bytes')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
