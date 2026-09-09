#!/usr/bin/env bash
# 2026-05-24 (v1.3.9): auto-bump APP_VERSION patch + write it to BOTH
# pubspec.yaml and lib/constants/app_version.dart in lock-step.
#
# User asked: "version numbers why not update automatically with time
# local time". The release TIME was already auto-stamped at build
# time (yswords-ios-reinstall.sh sets APP_RELEASE_TIME from
# `date -u`). The VERSION NUMBER was manually edited in two files
# every commit, easy to forget, easy to drift between pubspec.yaml
# and the Dart default.
#
# Strategy: monotonic patch bump per call. Major.Minor stays
# manually-bumped (intentional — those mark architectural eras
# like the v1.2 → v1.3 PageView refactor). Patch is auto.
#
# 2026-09-06 — THE LADDER, from the owner. The mechanism above already
# allowed a minor bump; what was missing was the criterion, so in
# practice every release since v1.3.9 has moved only the patch digit
# regardless of what shipped. That is the thing to stop.
#
#   1.x.0   A WHOLE CAPABILITY becomes genuinely usable.
#           Not "code for it landed" — a reader can now do something
#           they could not do before. Shipping the sermon library, or
#           making videos streamable, or making a corpus searchable.
#           Use `--set`; the automatic path never produces this.
#
#   1.x.y   A fix or a repair ON an existing capability. Defect work,
#           corpus corrections, guard hardening. This is the default
#           and what a bare call gives you.
#
#   2.0.0   A BREAK THAT COULD NOT BE MIGRATED. Deliberately hard to
#           reach — the owner's rule (2026-09-06) is that the LAST digit
#           climbing is fine and the FIRST one should not move easily.
#
#           So a break is not automatically a major. Renaming a saved
#           preference key is NOT one: read the old key, write the new,
#           and the reader never knows — this app has done exactly that
#           before. Changing a route a prerendered sitemap points at is
#           not one either: keep the old path answering.
#
#           A major is what is left when migration is genuinely
#           impossible and an installed copy would lose the reader's
#           highlights, notes or progress. If you can write the
#           migration, write it and ship a minor.
#
# Deciding is a judgement, and the honest test is the reader's side of
# it: if you cannot name a thing a reader can now DO, it is not a minor.
# Bundling one capability with twenty fixes is still a minor — the
# capability is what the number is announcing. And twenty fixes with no
# new capability is a patch, however many there are; a big last digit is
# not a problem to be solved by moving a bigger one.
#
# Usage:
#   tools/bump_version.sh           # bump patch by 1 (1.3.8 → 1.3.9)
#   tools/bump_version.sh --print   # just print current version
#   tools/bump_version.sh --set 1.3.10  # set explicit version
#
# Called automatically by tools/yswords-ios-reinstall.sh before
# every multi-platform build. Web build wrapper does the same.
set -euo pipefail

PROJECT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PUBSPEC="$PROJECT/pubspec.yaml"
APP_VERSION_DART="$PROJECT/lib/constants/app_version.dart"

current_version() {
  awk '/^version:/ {print $2; exit}' "$PUBSPEC"
}

case "${1:-}" in
  --print)
    current_version
    exit 0
    ;;
  --set)
    if [[ -z "${2:-}" ]]; then
      echo "bump_version.sh: --set requires a version argument" >&2
      exit 2
    fi
    NEW="$2"
    ;;
  *)
    CUR="$(current_version)"
    # Parse semver MAJOR.MINOR.PATCH. Extra build metadata
    # (e.g. "+timestamp") gets stripped — the auto-stamp lives in
    # APP_RELEASE_TIME, not in the version string itself.
    IFS='.' read -r MA MI PA <<<"$CUR"
    PA="${PA%%+*}" # strip any +build metadata
    NEW="$MA.$MI.$((PA + 1))"
    ;;
esac

echo "==> bumping version: $(current_version) → $NEW"

# Update pubspec.yaml — single `version: X.Y.Z` line at root.
# sed -i variants differ between BSD (macOS default) and GNU; use
# a temp file for portability.
TMP="$(mktemp)"
awk -v new="$NEW" '
  BEGIN { done = 0 }
  /^version:/ && !done { print "version: " new; done = 1; next }
  { print }
' "$PUBSPEC" >"$TMP"
mv "$TMP" "$PUBSPEC"

# Update lib/constants/app_version.dart — the `defaultValue: '...'`
# inside _envAppVersion's String.fromEnvironment call, AND the ternary
# fallback literal on kAppVersion's own line (`_envAppVersion == '' ?
# '...' : _envAppVersion`). Both must move together or the two-literal
# guard from 3c22efa (2026-06-29, the empty-dart-define blank-version
# fix) drifts apart — see test/update_service_test.dart.
#
# 2026-08-30: this anchor used to say `kAppVersion = String.fromEnvironment(`,
# which 3c22efa renamed away when it split the constant in two. The awk
# matched nothing from that commit onward — every bump since silently left
# the fallback frozen at 1.3.113 while still printing a success message.
TMP="$(mktemp)"
awk -v new="$NEW" '
  /const String _envAppVersion = String\.fromEnvironment\(/ { in_block = 1 }
  in_block && /defaultValue:/ {
    sub(/defaultValue: '\''[^'\'']*'\''/, "defaultValue: '\''" new "'\''")
    in_block = 0
  }
  /const String kAppVersion = _envAppVersion ==/ {
    sub(/'\''[^'\'']*'\'' : _envAppVersion/, "'\''" new "'\'' : _envAppVersion")
  }
  { print }
' "$APP_VERSION_DART" >"$TMP"
mv "$TMP" "$APP_VERSION_DART"

# 2026-06-09 (v1.3.59): ALSO stamp kAppReleaseTime's defaultValue with
# the current UTC ISO-8601 moment. Previously this relied ENTIRELY on
# each build injecting --dart-define=APP_RELEASE_TIME, which proved
# unreliable: a gradle no-op or an empty/missing inject left the About
# footer's "last updated" BLANK (Mi Pad) or showing different values
# across iOS/web/Android. Stamping the constant makes it a single
# source of truth baked into the source for EVERY platform —
# formatReleaseTimeLocal() converts the ISO UTC to the viewer's local
# timezone. Builds no longer need to pass APP_RELEASE_TIME at all.
RELEASE_TIME="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
TMP="$(mktemp)"
awk -v rt="$RELEASE_TIME" '
  /const String kAppReleaseTime = String\.fromEnvironment\(/ { in_block = 1 }
  in_block && /defaultValue:/ {
    sub(/defaultValue: '\''[^'\'']*'\''/, "defaultValue: '\''" rt "'\''")
    in_block = 0
  }
  { print }
' "$APP_VERSION_DART" >"$TMP"
mv "$TMP" "$APP_VERSION_DART"

echo "✓ pubspec.yaml + app_version.dart now at $NEW (release time: $RELEASE_TIME)"

# 2026-09-09: regenerate the bundled changelog, HERE, because this is
# the one place the version moves.
#
# assets/changelog.json's top entry IS the version being built — its
# own `release:` commit is not written until after the deploy, so the
# generator has to be TOLD which version that is (see the "THE BUILD'S
# OWN VERSION" section of tools/build_changelog.py). The asset records
# it under `head`, and test/changelog_test.dart pins that to
# pubspec.yaml. So a bump that does not regenerate ships a stale
# changelog — 「你的版本」 has no row to render on and the top of the
# page is one release behind — and turns the suite red on the way.
#
# The first wiring put this call in tools/release_web.sh and left two
# other doors open: `BUMP_VERSION=1 tools/yswords-ios-reinstall.sh`
# (that script's own bump hook) and a bare `tools/bump_version.sh`.
# Both moved pubspec without touching the asset. Repeating the call at
# each door would mean the next door added is wrong again, so it lives
# at the single place every door already goes through: whoever moves
# the version regenerates the changelog. That also fixes the other
# half — `release_web.sh --no-bump` no longer rebuilds the asset from a
# HEAD that has moved, so prod ships the changelog dev and qat verified.
#
# Deliberately NOT tolerant of failure: `set -e` stops here with
# pubspec already at $NEW, which is the true state and says exactly
# what to fix. A swallowed error would put the stale asset back.
if [ -f "$PROJECT/tools/build_changelog.py" ]; then
  python3 "$PROJECT/tools/build_changelog.py" \
    --head-version "$NEW" --head-date "$(date +%Y-%m-%d)"
fi
