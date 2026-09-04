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
# The function is EXTRACTED from the script rather than copied, so this
# tests the shipped text and cannot drift away from it.
set -u

REPO="${0:A:h:h}"
SCRIPT="$REPO/tools/yswords-ios-reinstall.sh"
FN="$(mktemp)"
awk '/^clear_stuck_jnilib_merge\(\) \{/,/^\}/' "$SCRIPT" > "$FN"
if [ ! -s "$FN" ]; then
  echo "FAIL: could not extract clear_stuck_jnilib_merge from $SCRIPT"
  echo "      (was it renamed, or is it no longer at column 0?)"
  exit 1
fi
source "$FN"

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
rm -rf "$PROJECT" "$FN"
[ "$fail" -eq 0 ]
