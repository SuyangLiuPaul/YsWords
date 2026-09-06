#!/bin/zsh
# Tests `clear_stuck_jnilib_merge` in tools/yswords-ios-reinstall.sh.
#
#   zsh tools/test_reinstall_recovery.zsh
#
# WHY THIS FILE EXISTS. That function runs `rm -rf`, unattended, at
# 04:00, on a path built from $PROJECT. Everything else in the reinstall
# script only reads, builds, or installs; this is the one thing that
# destroys. It deserves a test that does not require a broken Gradle
# cache to run.
#
# It is also the part I could NOT verify end to end. The failure it
# recovers from — Gradle's mergeJniLibFolders stuck up-to-date — could
# not be reproduced on demand: restoring the stale output directories is
# not enough, because Gradle tracks task state in its own database and
# noticed the outputs had changed underneath it, so it re-ran the merge
# and the recovery path never fired. So the recovery was proven here, on
# fixtures, rather than against the real fault.
#
# 2026-09-06: the deletion MOVED out of yswords-ios-reinstall.sh into
# tools/clear_stuck_jnilib_merge.sh, so every APK-producing path could
# share one copy. This test used to `awk` the function out of the
# reinstall script and `source` it; it now EXECUTES the real script, as
# every caller does. That is strictly better evidence — the extraction
# could only ever prove the text parsed, and it silently tested nothing
# if the function moved.
#
# $FLUTTER is pinned to the 3.44.2 the build paths use, NOT the PATH
# default (3.47.2 on this machine). The script correctly refuses to
# delete anything under >= 3.47.1, so leaving it unset would make every
# assertion below pass for the wrong reason.
set -u

REPO="${0:A:h:h}"
SCRIPT="$REPO/tools/clear_stuck_jnilib_merge.sh"
if [ ! -x "$SCRIPT" ]; then
  echo "FAIL: $SCRIPT is missing or not executable"
  exit 1
fi
export FLUTTER="${FLUTTER:-$HOME/flutter/bin/flutter}"

# Same contract the reinstall script's wrapper asks for: exit 0 iff
# something was cleared.
clear_stuck_jnilib_merge() { "$SCRIPT" --require-cleared "$PROJECT"; }

PROJECT="$(mktemp -d)"
pass=0
fail=0

chk() {
  if [ "$1" = "$2" ]; then
    echo "  ok: $3"
    pass=$((pass + 1))
  else
    echo "  FAIL: $3 (got '$1', want '$2')"
    fail=$((fail + 1))
  fi
}

mk() { mkdir -p "$PROJECT/build/app/intermediates/$1/$2"; }

echo "1. returns non-zero when there is nothing to clear"
# The caller uses this to skip a second full build when the stuck merge
# was not the problem — a wrong answer here costs ~90s every night.
clear_stuck_jnilib_merge >/dev/null
chk "$?" "1" "no directories present"

echo "2. clears all three known intermediates"
for d in merged_jni_libs merged_native_libs stripped_native_libs; do
  mk "$d" "intlRelease/deep/nest"
  echo stale > "$PROJECT/build/app/intermediates/$d/intlRelease/deep/nest/libapp.so"
done
out="$(clear_stuck_jnilib_merge)"
chk "$?" "0" "returns 0 when it cleared something"
chk "$(print -r -- "$out" | grep -c cleared)" "3" "reported three"
gone=1
for d in merged_jni_libs merged_native_libs stripped_native_libs; do
  [ -d "$PROJECT/build/app/intermediates/$d/intlRelease" ] && gone=0
done
chk "$gone" "1" "the trees are gone, nested contents included"

echo "3. matches *Release only, across flavors"
mk merged_jni_libs cnRelease
mk merged_jni_libs intlDebug
mk merged_jni_libs intlRelease
out="$(clear_stuck_jnilib_merge)"
chk "$?" "0" "returns 0"
# cnRelease goes too. That is deliberate rather than incidental: the
# China flavor is built by the same Gradle tasks and can stick the same
# way. The script only builds intl, so the cost is one rebuild the next
# time someone builds cn by hand.
chk "$(print -r -- "$out" | grep -c cleared)" "2" "intlRelease and cnRelease"
chk "$([ -d "$PROJECT/build/app/intermediates/merged_jni_libs/intlDebug" ] && echo yes)" \
  "yes" "intlDebug is not *Release and survives"

echo "4. touches nothing outside the intermediates tree"
mkdir -p "$PROJECT/build/app/outputs/Release" "$PROJECT/lib"
echo keep > "$PROJECT/lib/main.dart"
clear_stuck_jnilib_merge >/dev/null
chk "$([ -f "$PROJECT/lib/main.dart" ] && echo yes)" "yes" "lib/ untouched"
chk "$([ -d "$PROJECT/build/app/outputs/Release" ] && echo yes)" "yes" \
  "a same-named dir elsewhere under build/ untouched"

echo ""
echo "passed=$pass failed=$fail"
rm -rf "$PROJECT"
[ "$fail" -eq 0 ]
