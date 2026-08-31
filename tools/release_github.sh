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

if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null \
   || git ls-remote --exit-code --tags origin "$TAG" >/dev/null 2>&1; then
  echo "FATAL: $TAG already exists. Bump the version first." >&2
  exit 1
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
  echo "DRY RUN — no tag pushed."
  exit 0
fi

git tag -a "$TAG" "$COMMIT" -m "$TAG"
git push origin "$TAG"
echo
echo "Pushed $TAG. The five platform workflows are building now; each"
echo "attaches its asset to the Release when it finishes. Watch with:"
echo "  gh run list --limit 6"
