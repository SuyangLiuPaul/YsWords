#!/usr/bin/env bash
# 2026-09-01: cut a GitHub Release, so the in-app update check has
# something to point at again.
#
#   tools/release_github.sh                 # tag origin/main at its own version
#   tools/release_github.sh --commit <sha>  # tag a specific commit
#   tools/release_github.sh --dry-run       # run every check, push nothing
#
# ── Why this exists ───────────────────────────────────────────────────
# Native builds (Android / Windows / macOS / Linux / iOS) are published
# as GitHub Release assets — there is no app store in the loop. Pushing
# a `v*` tag is the whole trigger: .github/workflows/release-*.yml each
# fire on `push: tags: ['v*']`, build their platform, and attach the
# asset to that tag's Release, creating it if absent.
#
# Nothing about that was ever broken. Releases stopped on 2026-08-04 at
# v1.4.6 simply because nobody pushed a tag again, and by 2026-09-01 the
# web sites were on 1.4.190 — 184 versions and 500 commits later. Anyone
# running the v1.4.6 APK was never told, because `UpdateService` reports
# an update only when the latest TAG is newer than their running
# `kAppVersion`, and 1.4.6 is not newer than 1.4.6.
#
# ── NOT once per web deploy ───────────────────────────────────────────
# `release_web.sh` runs many times a day; this must not. A tag starts
# FIVE platform builds and the Android asset alone is ~160 MB, so
# tagging every web version would mean hundreds of releases a month and
# nothing a user could meaningfully read. Native releases are cut
# deliberately, when there is something worth installing.
#
# ── The failure this guards ───────────────────────────────────────────
# Tagging a commit whose version is not the tag. `UpdateService`
# compares the tag against the `kAppVersion` COMPILED INTO the build, so
# if they disagree the app tells its users forever about an update they
# already have — a notification that can never be satisfied by
# installing anything. Both files are checked at the tagged commit, not
# in the working tree, because the working tree is usually ahead.
set -euo pipefail

PROJECT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT"

COMMIT=""
DRY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --commit) COMMIT="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

git fetch --quiet origin
if [[ -z "$COMMIT" ]]; then
  COMMIT="$(git rev-parse origin/main)"
fi
COMMIT="$(git rev-parse "$COMMIT")"
SHORT="$(git rev-parse --short "$COMMIT")"

# The commit must be on origin/main. A tag on a local-only commit
# creates a Release whose source archive GitHub cannot serve.
if ! git merge-base --is-ancestor "$COMMIT" origin/main; then
  echo "FATAL: $SHORT is not on origin/main — push it first." >&2
  exit 1
fi

# Read BOTH version sources out of the tagged commit itself.
PUBSPEC_V="$(git show "$COMMIT:pubspec.yaml" | awk '/^version:/ {print $2; exit}')"
PUBSPEC_V="${PUBSPEC_V%%+*}"
DART_V="$(git show "$COMMIT:lib/constants/app_version.dart" \
  | sed -n "s/^const String kAppVersion = .*'\([0-9][0-9.]*\)'.*/\1/p" | head -1)"

if [[ -z "$PUBSPEC_V" || -z "$DART_V" ]]; then
  echo "FATAL: could not read the version out of $SHORT" >&2
  echo "  pubspec.yaml -> '${PUBSPEC_V:-}'" >&2
  echo "  app_version.dart -> '${DART_V:-}'" >&2
  exit 1
fi
if [[ "$PUBSPEC_V" != "$DART_V" ]]; then
  echo "FATAL: $SHORT disagrees with itself about its version." >&2
  echo "  pubspec.yaml      $PUBSPEC_V" >&2
  echo "  app_version.dart  $DART_V   <- this is what ships in the build" >&2
  echo "  UpdateService compares the tag to app_version.dart, so a tag" >&2
  echo "  built from pubspec would advertise an update nobody can install." >&2
  exit 1
fi
VERSION="$DART_V"
TAG="v$VERSION"

# 2026-09-09: a LOCAL tag and a tag ON ORIGIN used to be the same
# condition here, and they are not the same fact.
#
# `git tag -a` below runs before `git push`. A push that fails — no
# network, a rejected credential, a hook — leaves the annotated tag
# sitting in the local repository while origin has nothing: no platform
# workflow fired, no Release exists, nothing was released. The next run
# then found that local tag and said "already exists. Bump the version
# first" — advice that cannot fix anything. Bumping does not push the
# release that failed; it moves the release to a version whose tag would
# strand exactly the same way, and it tells the operator to change the
# BUILD in order to repair a NETWORK failure. Meanwhile the app's
# UpdateService keeps reading the last Release it can see, so the
# stranded version reaches nobody and no message says so.
#
# Only a tag on origin means released. A local-only tag is the wreckage
# of a failed push, so this run finishes that push instead of refusing.
TAG_LOCAL=0
if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  TAG_LOCAL=1
fi
if git ls-remote --exit-code --tags origin "refs/tags/$TAG" >/dev/null 2>&1; then
  echo "FATAL: $TAG is already on origin. Bump the version first." >&2
  exit 1
fi
if [[ "$TAG_LOCAL" = "1" ]]; then
  TAGGED="$(git rev-parse "refs/tags/$TAG^{commit}")"
  if [[ "$TAGGED" != "$COMMIT" ]]; then
    echo "FATAL: $TAG exists locally at $(git rev-parse --short "$TAGGED")," >&2
    echo "  but this run is for $SHORT, and origin has neither. Decide which" >&2
    echo "  commit carries $VERSION, delete the other tag (git tag -d $TAG)," >&2
    echo "  and re-run — pushing this one would release the wrong tree." >&2
    exit 1
  fi
  echo "==> $TAG exists locally, origin does not have it: a previous push"
  echo "    failed. This run pushes THAT tag rather than minting a new one."
fi

# CI must be green ON THIS COMMIT. The release workflows do not run the
# test suite — they only build — so a tag is the last point where a
# broken commit can still be stopped before it becomes a download.
CI="$(gh run list --commit "$COMMIT" --workflow 'Flutter CI' \
      --limit 1 --json conclusion --jq '.[0].conclusion // "none"')"
if [[ "$CI" != "success" ]]; then
  echo "FATAL: Flutter CI on $SHORT is '$CI', not success." >&2
  echo "  The release workflows only BUILD; nothing downstream runs the" >&2
  echo "  tests, so this is the last gate before users can download it." >&2
  exit 1
fi

PREV="$(git tag --sort=-v:refname | head -1)"
echo "==> $TAG at $SHORT"
echo "    version   $VERSION (pubspec and app_version.dart agree)"
echo "    CI        $CI"
echo "    previous  ${PREV:-none}"
if [[ -n "$PREV" ]]; then
  echo "    spans     $(git rev-list --count "$PREV..$COMMIT") commits since $PREV"
fi
echo "    triggers  release-{android,ios,linux,macos,windows}.yml"

if [[ "$DRY" = "1" ]]; then
  echo
  if [[ "$TAG_LOCAL" = "1" ]]; then
    echo "DRY RUN — the stranded local $TAG was NOT pushed."
  else
    echo "DRY RUN — no tag pushed."
  fi
  exit 0
fi

if [[ "$TAG_LOCAL" = "1" ]]; then
  echo "==> pushing the existing $TAG"
else
  git tag -a "$TAG" "$COMMIT" -m "$TAG"
fi
# The local tag must not outlive a failed push: that is the state that
# made the NEXT run refuse with "already exists" and send the operator to
# bump a version that was never released. Deleting it costs nothing — the
# tag is reconstructible from $COMMIT — and leaves the next run a clean
# slate that can simply be re-run.
if ! git push origin "$TAG"; then
  git tag -d "$TAG" >/dev/null
  echo "!!! push of $TAG failed. The local tag was deleted, so re-running" >&2
  echo "!!! this script once the push works cuts the release as intended;" >&2
  echo "!!! do NOT bump the version — $VERSION has not been released." >&2
  exit 1
fi
echo
echo "Pushed $TAG. Waiting for the five platform release workflows..."

# 2026-09-15: v1.6.8 shipped with four assets, not five — macOS failed
# 11 minutes after the tag went public (a new plugin's platform minimum,
# see PROJECT_STATE.md trap 70), and nothing here noticed. The script
# used to stop at the push and print a `gh run list` suggestion to a
# human. That is not a report, it is a hope: the tag is the only trigger
# these five workflows have, a red one can only be fixed by a NEW tag,
# and until now the sole way to learn about it was someone looking.
#
# Bounded, not indefinite: today's own runs give the real shape — macOS
# failed at +11 min, iOS was still building at +10 min — so the cap has
# to clear a normal build, not a canary. Both knobs are overridable so
# the test harness in tools/test_release_scripts.py never sleeps for
# real.
RELEASE_WORKFLOWS=(
  "Release Android"
  "Release iOS (unsigned)"
  "Release Linux"
  "Release macOS"
  "Release Windows"
)
N=${#RELEASE_WORKFLOWS[@]}
RESULT_STATUS=()
RESULT_CONCL=()
i=0
while [ "$i" -lt "$N" ]; do
  RESULT_STATUS[$i]=""
  RESULT_CONCL[$i]=""
  i=$((i + 1))
done

POLL_INTERVAL="${RELEASE_GITHUB_POLL_INTERVAL:-30}"
POLL_CAP="${RELEASE_GITHUB_POLL_CAP:-1800}"
START=$SECONDS
while :; do
  ALL_DONE=1
  i=0
  while [ "$i" -lt "$N" ]; do
    if [ "${RESULT_STATUS[$i]}" != "completed" ]; then
      wf="${RELEASE_WORKFLOWS[$i]}"
      READ_OUT="$(gh run list --commit "$COMMIT" --workflow "$wf" \
        --event push --limit 1 --json status,conclusion \
        --jq '(.[0].status // "not_started") + " " + (.[0].conclusion // "none")')"
      read -r RSTATUS RCONCL <<<"$READ_OUT"
      RESULT_STATUS[$i]="$RSTATUS"
      RESULT_CONCL[$i]="$RCONCL"
      [ "$RSTATUS" = "completed" ] || ALL_DONE=0
    fi
    i=$((i + 1))
  done
  [ "$ALL_DONE" = "1" ] && break
  [ "$((SECONDS - START))" -ge "$POLL_CAP" ] && break
  sleep "$POLL_INTERVAL"
done

echo
echo "Release workflow results for $TAG:"
FAILED=0
PENDING=0
i=0
while [ "$i" -lt "$N" ]; do
  wf="${RELEASE_WORKFLOWS[$i]}"
  st="${RESULT_STATUS[$i]}"
  cn="${RESULT_CONCL[$i]}"
  if [ "$st" != "completed" ]; then
    echo "  ?? $wf — still $st after ${POLL_CAP}s. Not green, not known red"
    echo "     either — check yourself: gh run list --commit $COMMIT --workflow '$wf'"
    PENDING=$((PENDING + 1))
  elif [ "$cn" = "success" ]; then
    echo "  ok $wf"
  else
    echo "  !! $wf — $cn"
    FAILED=$((FAILED + 1))
  fi
  i=$((i + 1))
done

if [ "$FAILED" -gt 0 ] || [ "$PENDING" -gt 0 ]; then
  echo
  echo "!!! $TAG is ALREADY PUBLIC. Do not delete it, do not re-point it," >&2
  echo "!!! do not re-run a release workflow expecting it to fix this tag —" >&2
  echo "!!! a re-run checks out the same tree and fails the same way. This" >&2
  echo "!!! is a BUILD report, not a tagging failure: the Release exists" >&2
  echo "!!! with fewer than five platform assets. Investigate the run(s)" >&2
  echo "!!! above (or wait longer for a pending one), then fix forward with" >&2
  echo "!!! a new tag — see PROJECT_STATE.md trap 70 for how v1.6.8 did." >&2
  exit 1
fi

echo
echo "All five platform builds for $TAG succeeded."
