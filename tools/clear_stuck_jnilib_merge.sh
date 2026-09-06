#!/bin/sh
# Clear the OUTPUTS of Gradle's jniLib merge before an Android build.
#
# WHY THIS EXISTS — flutter/flutter#191801.
#
# On Flutter 3.44.x, in a build WITH PRODUCT FLAVORS, Gradle's jniLib
# merge goes stale. Measured, in one build, two adjacent `--info` lines:
#
#   Task ':app:copyJniLibsflutterBuildIntlRelease' is not up-to-date …
#   Skipping task ':app:mergeIntlReleaseJniLibFolders' as it is up-to-date.
#
# The upstream task rewrites the jniLibs directory and the merge task,
# in the same build, still believes it has nothing to do:
#
#   intermediates/flutter/<flavor>Release/jniLibs/*/libapp.so   FRESH
#   intermediates/merged_jni_libs/.../out/*/libapp.so           STALE
#   intermediates/merged_native_libs/.../out/lib/*.so           STALE
#   intermediates/stripped_native_libs/.../out/lib/*.so         STALE
#
# and stripped_native_libs is byte-identical to the APK's shipped
# libapp.so. So the APK carries a NEW version string and OLD Dart code.
#
# Ordering is not the problem — the Flutter plugin's `dependsOn` is
# present and Gradle schedules copyJniLibs first. What fails is INPUT
# TRACKING: `FlutterPlugin.kt` used
# `sourceSet.jniLibs.srcDir(jniLibsDir.get().asFile)`, handing AGP a
# plain directory rather than a registered task output, so the merge
# task had nothing telling it to re-run.
#
# THE FLAVOR IS A NECESSARY CONDITION. The upstream maintainer verified
# that removing the product flavor makes the merge come out fresh.
#
# It does not heal on its own: a second build takes 5s, reports
# everything up-to-date, and leaves the same stale .so in place. And it
# is not intermittent — it is EVERY incremental build. Deleting
# intermediates/flutter does nothing, because that is the merge task's
# INPUT and it is already fresh. Only removing the merge task's OUTPUTS
# breaks the wedge. (`flutter clean` also works and is the blunt,
# several-minutes-slower version.)
#
# So: clear BEFORE the build rather than after it fails. With no
# previous output the merge task cannot be up-to-date, and the run costs
# one Android build instead of two.
#
# ─── WHEN TO DELETE THIS FILE ────────────────────────────────────────
#
# Fixed upstream in Flutter 3.47.1, via `addGeneratedSourceDirectory`.
# From 3.47.1 onward this script is UNNECESSARY.
#
# Two things enforce that so it cannot rot in place unnoticed:
#
#   1. This script, at runtime, detects a Flutter >= 3.47.1 and refuses
#      to delete anything, printing an OBSOLETE banner. It still exits 0
#      so it cannot break a build that no longer needs it.
#   2. `test/jnilib_workaround_guard_test.dart` FAILS when the Flutter
#      version pinned in .github/workflows/ reaches 3.47.1 — so the same
#      pull request that lifts the pin lands red until the workaround is
#      removed. That is the guard that actually gets read; a runtime
#      warning at 04:00 has nobody in front of it.
#
# To retire: delete this file, delete every call site the guard test
# enumerates, and delete the guard test.
#
# ─── CONTRACT ────────────────────────────────────────────────────────
#
#   clear_stuck_jnilib_merge.sh [--require-cleared] [PROJECT_ROOT]
#
#   PROJECT_ROOT  defaults to this script's own repository root. PASS IT
#                 EXPLICITLY from any caller that builds a DIFFERENT
#                 checkout than the one it lives in — SeekSparks/tools/
#                 holds two fork-leftover scripts that build ../yswords,
#                 and clearing the wrong tree would leave the real one
#                 stale while reporting success.
#
#   $FLUTTER      the Flutter binary the CALLER is about to build with,
#                 used for the >= 3.47.1 obsolescence check. Defaults to
#                 `flutter` on PATH. This matters here: the PATH default
#                 on this machine is 3.47.2 while every build path pins
#                 ~/flutter/bin/flutter at 3.44.2, so a caller that does
#                 not export FLUTTER would get the wrong answer.
#
#   exit 0        ran successfully (whether or not anything was cleared)
#   exit 1        --require-cleared was given and nothing was there
#   exit 2        refused — PROJECT_ROOT missing or not a directory
#
# Exit 0 on "nothing to clear" is deliberate: `release_native.sh` runs
# under `set -euo pipefail`, and a bare non-zero here would abort the
# release instead of building. Callers that genuinely need the boolean —
# "was a stuck merge the thing that was wrong?" — ask for it with
# --require-cleared.
#
# SAFETY. This is an `rm -rf` that runs unattended at 04:00. It is
# deliberately narrow: only `*Release` directories DIRECTLY inside the
# three known intermediate folders, each re-checked to be under
# <project>/build/app/intermediates before it is touched. Nothing is
# derived from user input, and the containment check is there so a
# future edit to PROJECT_ROOT cannot turn this into an rm at the wrong
# root. Tested by `tools/test_reinstall_recovery.zsh`.

set -u

require_cleared=0
project=""

while [ $# -gt 0 ]; do
  case "$1" in
    --require-cleared) require_cleared=1; shift ;;
    -h|--help)
      echo "usage: clear_stuck_jnilib_merge.sh [--require-cleared] [PROJECT_ROOT]"
      echo "  Works around flutter/flutter#191801 (stale jniLib merge with"
      echo "  product flavors). Obsolete from Flutter 3.47.1 — see the header."
      exit 0 ;;
    --) shift; break ;;
    -*) echo "clear_stuck_jnilib_merge: unknown option '$1'" >&2; exit 2 ;;
    *) project="$1"; shift ;;
  esac
done

# Default to this script's own repo root: <repo>/tools/<this file>.
if [ -z "$project" ]; then
  script_dir="$(cd "$(dirname "$0")" && pwd)" || exit 2
  project="$(cd "$script_dir/.." && pwd)" || exit 2
fi

if [ ! -d "$project" ]; then
  echo "clear_stuck_jnilib_merge: '$project' is not a directory" >&2
  exit 2
fi
# Normalise, so the containment check below compares resolved paths.
project="$(cd "$project" && pwd)" || exit 2

# ─── Obsolescence check: is the toolchain past the fix? ──────────────
#
# Compares the Flutter the CALLER will build with against 3.47.1. Parses
# "Flutter 3.44.2 • channel stable • …" — the first whitespace-separated
# field after the word Flutter, with any -pre/+hotfix suffix dropped.
flutter_bin="${FLUTTER:-flutter}"
fver=""
if command -v "$flutter_bin" >/dev/null 2>&1; then
  fver="$("$flutter_bin" --version 2>/dev/null \
    | awk '/^Flutter /{print $2; exit}' \
    | sed 's/[-+].*$//')"
fi

if [ -n "$fver" ]; then
  # Zero-padded numeric compare, so 3.5.0 does not sort above 3.47.1.
  fnum="$(echo "$fver" | awk -F. '{printf "%d%03d%03d", $1, $2, $3}')"
  if [ -n "$fnum" ] && [ "$fnum" -ge 3047001 ] 2>/dev/null; then
    echo "clear_stuck_jnilib_merge: OBSOLETE — Flutter $fver is >= 3.47.1,"
    echo "  which carries the upstream fix for flutter/flutter#191801."
    echo "  Nothing was cleared. DELETE this script, its call sites, and"
    echo "  test/jnilib_workaround_guard_test.dart."
    exit 0
  fi
fi

# ─── The deletion ────────────────────────────────────────────────────
cleared=0
for d in merged_jni_libs merged_native_libs stripped_native_libs; do
  for out in "$project/build/app/intermediates/$d"/*Release; do
    # An unmatched glob comes back literal in POSIX sh; -d rejects it.
    [ -d "$out" ] || continue
    case "$out" in
      "$project/build/app/intermediates/"*) ;;
      *)
        echo "  refusing to clear '$out' — outside the project build dir"
        continue
        ;;
    esac
    if rm -rf "$out"; then
      echo "  cleared $out"
      cleared=$((cleared + 1))
    else
      echo "  could not clear $out"
    fi
  done
done

if [ "$cleared" -eq 0 ]; then
  echo "  nothing to clear — no previous merge output in this tree"
  [ "$require_cleared" -eq 1 ] && exit 1
fi

exit 0
