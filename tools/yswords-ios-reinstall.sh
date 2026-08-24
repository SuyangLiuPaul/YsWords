#!/bin/zsh
# 2026-05-21 (v1.2.68): scheduled YsWords multi-device reinstall.
#
# Each scheduled fire (daily @ 04:00 via launchd) does:
#   1. git pull origin main — pick up the latest committed code
#   2. flutter build ios --release  → iPhone + iPad install via
#      xcrun devicectl (free Apple ID cert expires every 7 days)
#   3. flutter build apk --release  → Xiaomi Pad install via
#      adb install -r (Android certs are permanent but we still
#      refresh on the same cadence so new commits ship without
#      manual intervention)
#   4. flutter build macos --release → /Applications/yswords.app
#      replaced on this Mac. Self-only target.
#
# Per-device failures are isolated — one device offline / bricked
# doesn't block the others. Exit 0 iff at least one device got the
# build; exit 1 only when ALL failed.
#
# Triggered by: ~/Library/LaunchAgents/com.yswords.ios-reinstall.plist
# Output logs: /tmp/yswords-ios-reinstall.log (rotates on each run)
#
# Prerequisites the schedule depends on:
#   1. Mac is awake at the fire time (user keeps Mac always-on, no
#      pmset wake needed)
#   2. iPhone + iPad — on the same WiFi as Mac, paired via "Connect
#      via network" in Xcode Devices and Simulators. Locked is fine,
#      deep sleep / airplane mode is not.
#   3. Xiaomi Pad — EITHER plugged in via USB (most reliable; wired ADB
#      never drops) OR on the same WiFi with wireless ADB enabled, paired
#      via `adb pair` once. Discovery self-heals: it checks the USB
#      transport first, then polls mDNS for ~18s (HyperOS keeps turning
#      Wireless debugging back off, so a single scan often misses it).
#      MIUI's "Install via USB" + Pure Mode tweaks done in setup.
#
# Manual re-run if a scheduled fire misses (e.g. WiFi was down):
#   ~/Documents/yswords/tools/yswords-ios-reinstall.sh

# NOTE: NO `set -e` here — we want install failures on one device
# to not abort the others.

LOG="/tmp/yswords-ios-reinstall.log"
FLUTTER="/Users/pliu0036/flutter/bin/flutter"
PROJECT="/Users/pliu0036/Documents/yswords"
IOS_APP="$PROJECT/build/ios/iphoneos/Runner.app"
ANDROID_APK="$PROJECT/build/app/outputs/flutter-apk/app-intl-release.apk"

# Android toolchain env — same paths as the interactive shell uses.
export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools
export JAVA_HOME=/opt/homebrew/opt/openjdk@17
export PATH="$ANDROID_HOME/platform-tools:/opt/homebrew/opt/openjdk@17/bin:$PATH"

# iOS device roster — paired iPhone + iPad. Add more here when new
# iOS devices get paired (USB-pair once, enable wireless in Xcode →
# Devices and Simulators → Connect via network).
IOS_DEVICES=(
  "9FA8108D-E7E4-58F5-8326-3BD835C3A5E7|iPhone 16 Pro Max (Paul)"
  "D5B9E2F7-F74E-5F8A-8A08-83008BDBD13C|iPad Pro 11-inch (Paul Liu's iPad)"
)

# Android device roster — STABLE device serials only. Previously
# this list pinned the mDNS pair-suffix (`adb-<serial>-XXXXXX._adb-
# tls-connect._tcp`) AND a hard-coded ip:port, both of which drift:
#
#   • HyperOS 3 (Android 16, V816) assigns a NEW random TCP port
#     every time the Wireless-debugging toggle is enabled — the old
#     `192.168.4.19:38027` was already a stale `:44241` the next day.
#   • The mDNS pair-suffix `-K09tQP` rotates if the device re-pairs.
#   • HyperOS 3 also auto-DISABLES wireless debugging when the user
#     leaves the Wireless-debugging settings screen or the device
#     sleeps — so the broadcast is intermittent by design.
#
# 2026-05-26 (v1.3.45 follow-up): script now resolves the device's
# current ip:port at runtime via `adb mdns services`, matching on
# the stable serial prefix only. Falls back to the classic
# `_adb._tcp` port-5555 service (present after `adb tcpip 5555`).
# If neither broadcast is visible, the device is asleep / off-Wi-Fi
# / wireless-debug toggle is off — print actionable instructions
# rather than burning time on stale endpoints.
ANDROID_DEVICES=(
  "0907E41001A00540|Xiaomi Pad 7 Ultra (jinghu)"
)

exec >"$LOG" 2>&1
echo "==== $(date '+%Y-%m-%d %H:%M:%S %Z') ===="

cd "$PROJECT"

# Pull any newer commits from main so the reinstall ships the latest
# code, not the last build. Safe — main is the deploy branch.
git fetch origin main --quiet || true
git pull --ff-only origin main --quiet || echo "git pull skipped (working tree dirty or no fast-forward)"

successes=0
failures=0

# Pull APP_VERSION + APP_RELEASE_TIME from pubspec so the native builds
# carry the same dart-define values that tools/build_web.py injects for
# web. Without this, native binaries fall back to app_version.dart's
# hard-coded default and the About page drifts behind pubspec on every
# release. 2026-05-22 (v1.2.76): user spotted the iOS About page stuck
# on v1.2.67 — this paragraph fixes the drift permanently.
# 2026-05-24 (v1.3.9): pick up whatever version pubspec.yaml currently
# holds — DON'T auto-bump here. The bump lives in `tools/release_web.sh`
# (the canonical "start a new release cycle" entrypoint) so a typical
# release flow goes:
#   1. tools/release_web.sh        ← bumps + builds + deploys 4 web sites
#   2. tools/yswords-ios-reinstall.sh ← picks up the same pubspec version
#      that release_web.sh just bumped to, builds native + installs.
# Both ship the SAME X.Y.Z. If install ran its own bump, web would be
# at 1.3.9 and native at 1.3.10 — drift. Bump opt-in via:
#   BUMP_VERSION=1 tools/yswords-ios-reinstall.sh
if [[ "${BUMP_VERSION:-0}" = "1" && -x "$PROJECT/tools/bump_version.sh" ]]; then
  "$PROJECT/tools/bump_version.sh"
fi
# 2026-05-27 (v1.3.47): robust APP_VERSION resolution. At 04:00 the
# launchd-spawned awk somehow can't open the absolute pubspec.yaml
# path under ~/Documents (likely macOS TCC on background daemons —
# repros every overnight fire, never repros interactively). Until
# that's understood, cascade through multiple read strategies plus
# a `~/.config/yswords/current-version` cache that the interactive
# release_web.sh + this script BOTH refresh whenever they succeed —
# so the next launchd fire has a known-good fallback even if its
# own awk hits TCC again.
VERSION_CACHE="$HOME/.config/yswords/current-version"

APP_VERSION=""
# (1) Direct awk on absolute path — the original method. Works
#     interactively from Terminal; fails for launchd-spawned awk.
APP_VERSION="$(awk '/^version:/ {print $2; exit}' "$PROJECT/pubspec.yaml" 2>/dev/null || true)"

# (2) CD-into-PROJECT + relative-path awk. Different syscall path
#     than the absolute open; may dodge whatever TCC binding the
#     absolute path tripped over.
if [ -z "$APP_VERSION" ]; then
  APP_VERSION="$(cd "$PROJECT" 2>/dev/null && awk '/^version:/ {print $2; exit}' pubspec.yaml 2>/dev/null || true)"
fi

# (3) grep + shell parameter expansion. Different binary, different
#     open path. If awk is the one being blocked, grep may sail
#     through.
if [ -z "$APP_VERSION" ]; then
  vline="$(grep -m1 '^version:' "$PROJECT/pubspec.yaml" 2>/dev/null || true)"
  APP_VERSION="${vline#version: }"
fi

# (4) Cache file fallback (refreshed below whenever any of 1-3
#     succeeded on a previous run, including interactive ones).
if [ -z "$APP_VERSION" ] && [ -r "$VERSION_CACHE" ]; then
  APP_VERSION="$(tr -d '[:space:]' < "$VERSION_CACHE" 2>/dev/null || true)"
  echo "WARN: pubspec.yaml unreadable at this run; using cached APP_VERSION=$APP_VERSION from $VERSION_CACHE"
fi

# (5) Last-ditch sentinel so we NEVER ship `--dart-define=APP_VERSION=`
#     again. About page falls back to lib/services/app_version.dart's
#     hard-coded constant, but at least the dart-define isn't an
#     empty-string black hole.
if [ -z "$APP_VERSION" ]; then
  APP_VERSION="unknown"
  echo "ERROR: could not determine APP_VERSION via any method (pubspec read failed + no cache)."
  echo "       Shipping APP_VERSION=unknown so the build doesn't blow up."
fi

# Refresh the cache whenever we got a real version — gives the next
# launchd fire a safety net. Idempotent + cheap.
if [ "$APP_VERSION" != "unknown" ]; then
  mkdir -p "$(dirname "$VERSION_CACHE")" 2>/dev/null
  printf '%s\n' "$APP_VERSION" > "$VERSION_CACHE" 2>/dev/null || true
fi

# 2026-06-09 (v1.3.59): release time is NOT injected here anymore.
# bump_version.sh stamps it into the kAppReleaseTime source constant, so
# every platform reads one identical value. Injecting `date` per-build
# made iOS/web/Android disagree, and a launchd run where the shell var
# came back empty shipped `--dart-define=APP_RELEASE_TIME=` → blank
# "last updated" on the device (seen on the Mi Pad).
DEFINES=(
  --dart-define="APP_VERSION=$APP_VERSION"
)
echo "==> APP_VERSION=$APP_VERSION (release time stamped in source)"

# ─── iOS BUILD + INSTALLS ────────────────────────────────────────
echo ""
echo "→ flutter build ios --release ${DEFINES[*]}"
if "$FLUTTER" build ios --release "${DEFINES[@]}"; then
  # Multi-pass install: at 04:03 ALL iOS devices are deep-asleep with
  # their WiFi radios in low-power maintenance mode. A single attempt
  # times out with CoreDeviceError 4000 ("tunnel interrupted") before
  # the radio wakes. Live-tested: a manual retry ~2min later always
  # works. So we do passes — try each device once, then circle back
  # to any failures after a 45s warmup window. Devices waking for one
  # install also tend to wake nearby devices via shared mDNS activity.
  remaining=("${IOS_DEVICES[@]}")
  # NOTE: no `declare -A` here. macOS ships bash 3.2 (the launchd run and
  # any `bash tools/...` invocation use it), and bash 3.2 has no
  # associative arrays — `declare -A` errors out, and a plain indexed
  # `succeeded[$uuid]=1` then makes bash arithmetic-evaluate the UUID
  # ("value too great for base"), which aborts BOTH install loops right
  # after the first device → the iPad was silently dropped every run.
  # Per-device success/failure is already tracked via the `remaining` /
  # `next_remaining` lists + the `successes`/`failures` counters, so no
  # extra set is needed. Keep this loop free of bash-4-only syntax so it
  # runs identically under bash 3.2, bash 4+, and zsh.
  for pass in 1 2 3; do
    [ ${#remaining[@]} -eq 0 ] && break
    echo ""
    echo "── iOS install pass $pass — ${#remaining[@]} device(s) to install ──"
    next_remaining=()
    for entry in "${remaining[@]}"; do
      uuid="${entry%%|*}"
      label="${entry##*|}"
      echo ""
      echo "→ pass $pass: installing to $label ($uuid)"
      if xcrun devicectl device install app --device "$uuid" "$IOS_APP"; then
        echo "✓ installed to $label"
        successes=$((successes + 1))
      else
        echo "✗ pass $pass: $label not ready, will retry"
        next_remaining+=("$entry")
      fi
    done
    remaining=("${next_remaining[@]}")
    if [ ${#remaining[@]} -gt 0 ] && [ $pass -lt 3 ]; then
      echo ""
      echo "  ${#remaining[@]} device(s) still pending — sleeping 45s for WiFi radios to wake…"
      sleep 45
    fi
  done
  # Any still-failing devices are now permanently failed for this run
  for entry in "${remaining[@]}"; do
    label="${entry##*|}"
    echo "✗ install to $label FAILED (3 passes)"
    failures=$((failures + 1))
  done
else
  echo "✗ flutter build ios FAILED — skipping iOS installs"
  failures=$((failures + ${#IOS_DEVICES[@]}))
fi

# ─── YAHWEH'S SWORDS (SeekSparks) iOS BUILD + INSTALLS ───────────
# 2026-08-24: the sister app rides the same nightly so its free-cert
# 7-day expiry is handled the same way. Its checkout doubles as the
# SeekSparks unattended loop's working tree, so two guards:
#   1. skip when the loop's hidden .lock is held — building a tree the
#      loop is mid-edit in ships a torn binary;
#   2. pull --ff-only only when the tree is clean, same tolerance as
#      the yswords pull above.
# Failures here are isolated like every other device: they never block
# the yswords installs that already happened above.
SWORDS_PROJECT="/Users/pliu0036/Documents/CodingProject/SeekSparks"
SWORDS_APP="$SWORDS_PROJECT/build/ios/iphoneos/Runner.app"
SWORDS_LOCK="$HOME/Library/Application Support/seeksparks-loop/.lock"

echo ""
# With the loop's off-peak gate removed (2026-08-24) it runs around the
# clock, so 04:00 lands on a held .lock more often than not. The
# nightly has nowhere else to be: wait for the iteration to finish —
# median 42 min, MAX_RUN kills at 90 — and only skip if 50 minutes of
# patience wasn't enough. First rehearsal skipped for exactly this
# reason; a skip a night is no way to hold a 7-day certificate.
waited=0
while [ -d "$SWORDS_LOCK" ] && [ "$waited" -lt 3000 ]; do
  [ "$waited" -eq 0 ] && echo "→ Yahweh's Swords: loop mid-iteration — waiting for .lock (up to 50 min)"
  sleep 60
  waited=$((waited + 60))
done
if [ -d "$SWORDS_LOCK" ]; then
  echo "→ Yahweh's Swords: SKIPPED — .lock still held after ${waited}s."
  echo "  The next nightly (or the next manual run) will catch it up."
else
  [ "$waited" -gt 0 ] && echo "  lock freed after ${waited}s — proceeding"
  cd "$SWORDS_PROJECT"
  git fetch origin main --quiet || true
  git pull --ff-only origin main --quiet || echo "swords git pull skipped (working tree dirty or no fast-forward)"
  echo "→ flutter build ios --release (Yahweh's Swords)"
  if "$FLUTTER" build ios --release; then
    remaining=("${IOS_DEVICES[@]}")
    for pass in 1 2 3; do
      [ ${#remaining[@]} -eq 0 ] && break
      echo ""
      echo "── Swords iOS install pass $pass — ${#remaining[@]} device(s) ──"
      next_remaining=()
      for entry in "${remaining[@]}"; do
        uuid="${entry%%|*}"
        label="${entry##*|}"
        echo "→ pass $pass: installing Swords to $label ($uuid)"
        if xcrun devicectl device install app --device "$uuid" "$SWORDS_APP"; then
          echo "✓ Swords installed to $label"
          successes=$((successes + 1))
        else
          echo "✗ pass $pass: $label not ready, will retry"
          next_remaining+=("$entry")
        fi
      done
      remaining=("${next_remaining[@]}")
      if [ ${#remaining[@]} -gt 0 ] && [ $pass -lt 3 ]; then
        echo "  sleeping 45s for WiFi radios to wake…"
        sleep 45
      fi
    done
    for entry in "${remaining[@]}"; do
      label="${entry##*|}"
      echo "✗ Swords install to $label FAILED (3 passes)"
      failures=$((failures + 1))
    done
  else
    echo "✗ flutter build ios (Swords) FAILED — skipping its installs"
    failures=$((failures + ${#IOS_DEVICES[@]}))
  fi
  cd "$PROJECT"
fi

# ─── ANDROID BUILD + INSTALLS ────────────────────────────────────
# 2026-05-24 (v1.3.38): the Android product flavors block in
# android/app/build.gradle.kts now requires `--flavor` on every
# build. `intl` is the default (international) flavor with the
# original com.example.yswords applicationId; the `cn` flavor is
# installed separately by tools/yswords-cn-install.sh.
echo ""
# 2026-08-24: drop the generated plugin registrant before a release
# build. `flutter pub get` regenerates it listing EVERY plugin, dev
# dependencies included — and integration_test's Android artifact is
# only on the debug classpath, so the release compile dies with
# "package dev.flutter.plugins.integration_test does not exist".
# A release build does NOT regenerate an existing registrant, so the
# breakage persists until something clears it. The file is generated
# and untracked; deleting it costs nothing and the build writes a
# correct, release-appropriate one. (Found the hard way: the nightly
# only worked because this file happened to be stale from before
# integration_test was added.)
rm -f "$PROJECT/android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java"

# 2026-08-24: CONTENT assertion on the APK before it is installed.
#
# `assembleIntlRelease` can "succeed" in 5 seconds by reusing stale
# Gradle artifacts — the Dart AOT task reports up-to-date and libapp.so
# is never recompiled. Every downstream signal then lies: `adb install
# -r` says Success, and the `pm list packages` check below passes
# because it only asks whether the package is PRESENT, not whether it is
# current. That shipped three phantom bug reports off the Mi Pad on
# 2026-08-24 (YouTube window, SoundCloud, drag) which were all one stale
# APK.
#
# The assertion reads the compiled code rather than the manifest's
# versionName on purpose: versionName is written by a different Gradle
# task from the Dart AOT compile, so agreeing with pubspec says nothing
# about which Dart went in. (In the one sample on disk here they did
# agree, at 1.4.147 — that is not evidence they cannot diverge.)
#
# The marker is `kAppReleaseTime`'s defaultValue in
# lib/constants/app_version.dart — a UTC instant to the second, stamped
# by tools/bump_version.sh on every release. It is a plain const string
# reached from the About page, so dart2native folds it into the AOT
# string pool: the APK built at v1.4.147 carries `2026-08-24T02:16:51Z`
# in all three of its libapp.so slices and nothing else matching that
# shape, and `4ac245c` ("Record the v1.4.147 bump") is the commit that
# wrote that stamp into the source. Read through the same two anchors
# bump_version.sh writes, so reader and writer move together;
# test/apk_freshness_guard_test.dart fails if that shape drifts.
#
# SCOPE — and it is narrower than it looks. This proves the APK was
# compiled from the source as of the LAST BUMP, not from HEAD. The
# stamp only moves when bump_version.sh runs, and this script does not
# bump unless BUMP_VERSION=1, which the 04:00 launchd plist does not
# set. So a Dart commit that lands between two releases is invisible to
# the marker — and the nightly is exactly the path the three phantom
# Mi Pad reports came out of. The drift count printed below turns that
# blind spot into a stated one instead of a silent "✓ verified".
#
# Zip entry timestamps cannot be used instead: every one of this APK's
# 1699 entries reads 1981-01-01 01:01 (AGP's fixed constant). And the
# APK's own file mtime proves nothing either — Gradle re-zips on every
# run whether or not the AOT task was skipped.
expected_release_stamp="$(awk '
  /const String kAppReleaseTime = String\.fromEnvironment\(/ { in_block = 1 }
  in_block && /defaultValue:/ {
    if (match($0, /'\''[^'\'']*'\''/)) print substr($0, RSTART + 1, RLENGTH - 2)
    exit
  }
' "$PROJECT/lib/constants/app_version.dart" 2>/dev/null)"

# Returns 0 iff every lib/*/libapp.so inside $1 carries the stamp $2.
apk_carries_release_stamp() {
  local apk_path want_stamp slice_list stale_slices slice found
  apk_path="$1"
  want_stamp="$2"
  stale_slices=0

  if [ -z "$want_stamp" ]; then
    echo "✗ APK content check: could not read kAppReleaseTime out of"
    echo "  lib/constants/app_version.dart — the constant's shape changed."
    return 1
  fi

  slice_list="$(mktemp)" || {
    echo "✗ APK content check: mktemp failed, cannot list the APK's slices"
    return 1
  }

  unzip -Z1 "$apk_path" 'lib/*/libapp.so' >"$slice_list" 2>/dev/null
  if [ ! -s "$slice_list" ]; then
    echo "✗ APK content check: no lib/*/libapp.so inside $apk_path"
    rm -f "$slice_list"
    return 1
  fi

  while IFS= read -r slice; do
    [ -n "$slice" ] || continue
    if unzip -p "$apk_path" "$slice" 2>/dev/null \
         | LC_ALL=C grep -aq -- "$want_stamp"; then
      continue
    fi
    stale_slices=$((stale_slices + 1))
    # Report the stamp the slice DOES carry, so the log names the build
    # that was reused. Matched as a substring, not a whole `strings`
    # line — in the 32-bit slice the stamp sits inside a longer printable
    # run, so an anchored match finds nothing. Exactly one ISO instant
    # occurs per slice.
    found="$(unzip -p "$apk_path" "$slice" 2>/dev/null \
      | LC_ALL=C grep -aoE '2[0-9]{3}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z' \
      | sort -u | head -1)"
    echo "✗ $slice was built at '${found:-unknown}', not '$want_stamp'"
  done <"$slice_list"

  rm -f "$slice_list"
  [ "$stale_slices" -eq 0 ]
}

# 2026-08-25: the SECOND freshness check, and it is the one that covers
# the nightly.
#
# apk_carries_release_stamp above can only see across a bump_version.sh
# run, because the stamp only moves when that script runs and the 04:00
# launchd job does not bump. Dart landing BETWEEN two releases is
# invisible to it — and the nightly is the path the three phantom Mi Pad
# reports came out of. This check carries no commit or version in it at
# all: it asks whether the AOT snapshot this build produced post-dates
# every Dart source file that went into it.
#
# WHICH FILE IS MEASURED, and why it is not the obvious one.
# `<abi>/app.so` and `jniLibs/<abi>/libapp.so` are both COPIES — the
# first draft of this check exonerated app.so on the false ground that
# it was flutter assemble's direct output. It is not: AndroidAot writes
# into `.dart_tool/flutter_build/<hash>/<abi>/app.so` and AndroidAotBundle
# `copySync`s it here (flutter_tools/…/build_system/targets/android.dart).
# What separates them is the SKIP RULE of the thing doing the copying:
#
#   * jniLibs/ is filled by Gradle's `copyJniLibs<Variant>`, a `Sync`
#     task (flutter_tools/gradle/…/FlutterPlugin.kt). Gradle is
#     up-to-date per TASK, so one changed input re-copies the whole set
#     with fresh mtimes. Measured here 2026-08-25: after one build,
#     jniLibs/arm64-v8a/libpdfium.so carried mtime 01:00:18 over content
#     byte-identical (sha256 ef8c440d…) to its source, last written
#     2026-08-24T07:26:50 — a fresh mtime over 17-hour-old bytes. A
#     stale libapp.so swept along by that same Sync would read as fresh,
#     which is worse than no check at all.
#   * flutter's own build_system skips per TARGET on the input's md5
#     (file_store.dart), and AndroidAotBundle's only input is the AOT
#     app.so (targets/android.dart). So an unchanged AOT leaves this
#     copy alone: measured, a second identical build 78s after the first
#     returned in 1m18s with all three app.so mtimes AND sha256s
#     unchanged.
#
# What this does NOT prove, because a draft of this comment claimed it
# and it is false: the copy does not re-run *only* when the AOT bytes
# change. `computeChanges` also invalidates on outputMissing /
# outputChanged / buildKeyChanged, so wiping build/ while
# .dart_tool/flutter_build/ survives re-copies with a fresh mtime. That
# is still not a false all-clear — AndroidAot is a dependency of that
# copy, so the graph is evaluated against the current kernel either way
# — but the honest claim is narrower than "iff". A fresh mtime here
# means flutter ran the AOT chain to completion during THIS build. It
# is not, and cannot be, proof that the bytes encode the current source;
# no mtime can be.
#
# Measuring `.dart_tool/flutter_build/<hash>/<abi>/app.so` instead — the
# AOT's direct output — was considered and rejected. It is one step
# FURTHER from the APK: if flutter recompiled but Gradle never copied
# the result, .dart_tool would read fresh while the installed APK was
# stale, which is the failure this whole guard exists for. It also needs
# the right <hash> picked out of the several snapshot directories on
# disk. Measure as close to the artifact as the skip rules allow.
#
# WHICH SOURCES ARE COMPARED. `flutter_build.d`, the depfile the build
# just wrote, not a `find` over lib/. A `find` was the first draft and it
# was wrong twice over: `lib/.DS_Store` exists and Finder rewrites it at
# any moment, and 22 of this repo's 234 lib/*.dart files are not inputs
# to an Android build at all — 17 are `*_web.dart` conditional-import
# stubs. A web-only commit would therefore have made this refuse a
# perfectly correct Android build, every night, until something
# unrelated forced a recompile.
#
# KNOWN HOLES, stated so the ✓ is not read wider than it is:
#   * a lib/ edit landing DURING the ~4-minute build is older than the
#     app.so written at the end of it, and absent from the snapshot. A
#     second session shares this checkout, so this is reachable.
#   * a dep whose mtime moved but whose content did not (an edit and a
#     revert) refuses a build that is legitimately not rebuilt. `git
#     pull --ff-only` cannot cause it; an interactive session can.
#   * assets, pubspec.yaml, dart-defines and android/ Kotlin are outside
#     this check entirely.
aot_postdates_dart_source() {
  local intermediates depfile dep_list aot newest newest_epoch newest_path
  local slices stale
  intermediates="$PROJECT/build/app/intermediates/flutter/intlRelease"
  depfile="$intermediates/flutter_build.d"
  slices=0
  stale=0

  # Every branch that cannot measure DISCLOSES and returns 0. A guard
  # whose failure mode is refusing everything is worse than the
  # staleness it catches, so a moved layout or a missing depfile must
  # not block the nightly — but it must never be silent either, or the
  # ✓ printed after this reads as an all-clear it did not earn.
  if [ ! -f "$depfile" ]; then
    echo "  NOTE: no flutter_build.d under build/app/intermediates/"
    echo "  flutter/intlRelease — the AOT freshness check did not run."
    return 0
  fi

  dep_list="$(mktemp)" || {
    echo "  NOTE: mktemp failed — the AOT freshness check did not run."
    return 0
  }

  # A depfile is `<outputs...>: <inputs...>`, one long space-separated
  # line with no trailing newline. The separator is the LAST output
  # token with `:` glued to it, so take everything after the first token
  # ending in `:` and keep the inputs under lib/.
  tr ' ' '\n' <"$depfile" \
    | awk -v pfx="$PROJECT/lib/" \
        '/:$/ { seen = 1; next } seen && index($0, pfx) == 1' \
    >"$dep_list"

  if [ ! -s "$dep_list" ]; then
    echo "  NOTE: flutter_build.d lists no lib/ inputs — the AOT"
    echo "  freshness check did not run."
    rm -f "$dep_list"
    return 0
  fi

  newest="$(tr '\n' '\0' <"$dep_list" \
    | xargs -0 stat -f '%m %N' 2>/dev/null | sort -rn | head -1)"
  rm -f "$dep_list"
  newest_epoch="${newest%% *}"
  newest_path="${newest#* }"
  case "$newest_epoch" in
    ''|*[!0-9]*)
      echo "  NOTE: could not read mtimes for the depfile's lib/ inputs —"
      echo "  the AOT freshness check did not run."
      return 0
      ;;
  esac

  for aot in "$intermediates"/*/app.so; do
    [ -f "$aot" ] || continue
    slices=$((slices + 1))
    [ "$(stat -f '%m' "$aot" 2>/dev/null || echo 0)" -lt "$newest_epoch" ] \
      || continue
    stale=$((stale + 1))
    echo "✗ ${aot#"$PROJECT/"} predates ${newest_path#"$PROJECT/"}"
  done

  if [ "$slices" -eq 0 ]; then
    echo "  NOTE: no <abi>/app.so under build/app/intermediates/flutter/"
    echo "  intlRelease — the AOT freshness check did not run."
    return 0
  fi

  if [ "$stale" -gt 0 ]; then
    echo "✗ $stale of $slices AOT slice(s) predate Dart that this build"
    echo "  was supposed to compile — a stale snapshot was reused."
    echo "  Refusing to install. Re-run; if it repeats, flutter clean."
    return 1
  fi

  echo "✓ AOT freshness verified — all $slices app.so slices post-date"
  echo "  every lib/ input flutter_build.d lists for this build"
  return 0
}

echo "→ flutter build apk --release --flavor intl ${DEFINES[*]}"
if "$FLUTTER" build apk --release --flavor intl "${DEFINES[@]}" \
   && apk_carries_release_stamp "$ANDROID_APK" "$expected_release_stamp" \
   && aot_postdates_dart_source; then
  echo "✓ APK content verified — libapp.so carries $expected_release_stamp"

  # How much Dart landed AFTER the stamp the check just matched. Those
  # commits are outside what the marker can see, so name them rather
  # than letting the ✓ above read as an all-clear.
  # `-S` matches a commit that changed the occurrence COUNT in either
  # direction, so for an older stamp it would find the commit that
  # REMOVED it. Safe here only because the stamp we look up is by
  # definition the one HEAD's source still holds — nothing has removed
  # it yet, so the newest such commit is the one that wrote it.
  stamp_commit="$(git log -1 --format=%H -S"$expected_release_stamp" \
    -- lib/constants/app_version.dart 2>/dev/null)"
  # Uncommitted lib/ work is in the build but in no commit, so rev-list
  # cannot see it. This script tolerates a dirty tree by design (the
  # `git pull` above is allowed to skip), and a second session shares
  # this checkout.
  dirty_lib="$(git status --porcelain -- lib 2>/dev/null | wc -l | tr -d ' ')"
  if [ -z "$stamp_commit" ]; then
    # BUMP_VERSION=1 produces exactly this: bump_version.sh edits the
    # working tree and does NOT commit, so the stamp is in no commit
    # yet. Staying silent here would let the ✓ above stand unqualified
    # in the very case the advice below creates.
    echo "  NOTE: $expected_release_stamp is not in any commit yet (an"
    echo "  uncommitted bump), so how much Dart post-dates it is unknown."
  else
    # --full-history: without it, path-based history simplification drops
    # merge parents and undercounts. Measured on this repo's merges: 1
    # simplified against 2 full, and 101 against 102.
    lib_drift="$(git rev-list --count --full-history "$stamp_commit..HEAD" \
      -- lib 2>/dev/null)"
    if [ -n "$lib_drift" ] && [ "$lib_drift" -gt 0 ]; then
      echo "  NOTE: $lib_drift commit(s) have touched lib/ since that stamp"
      echo "  was written, and the marker cannot see whether they made it in."
      echo "  The AOT freshness check above covers them by mtime instead."
    fi
  fi
  if [ -n "$dirty_lib" ] && [ "$dirty_lib" -gt 0 ]; then
    echo "  NOTE: $dirty_lib uncommitted change(s) under lib/ went into this"
    echo "  build and are outside what the marker can attest to."
    echo "  The AOT freshness check above covers them by mtime instead."
  fi

  # Warm up mDNS — the first poll after `adb start-server` can come
  # back empty even when broadcasts are live. A short settle lets
  # the cache populate. Total cost: 3s of one-time wait per run.
  adb mdns services >/dev/null 2>&1 || true
  sleep 3

  for entry in "${ANDROID_DEVICES[@]}"; do
    serial="${entry%%|*}"
    label="${entry##*|}"
    echo ""
    echo "→ locating $label (serial $serial) — USB first, then wireless"

    # 2026-06-29: self-healing discovery. HyperOS silently turns OFF
    # Wireless debugging (screen-lock / idle / Wi-Fi reconnect), so a
    # single mDNS scan often misses the device and the run reports a
    # spurious "not advertising" failure even though the device is fine.
    # Two fixes:
    #   (a) USB FAST PATH — `adb devices` lists the BARE serial for a
    #       cabled device. Wired ADB never drops, so a plugged-in Mi Pad
    #       is the most reliable path; check it first and every round.
    #   (b) RETRY WINDOW — poll up to 6 rounds (~18s), re-warming mDNS
    #       between tries, so a device that's slow to advertise (or one
    #       whose Wireless debugging the user just toggled on) still gets
    #       caught instead of failing instantly.
    device_id=""
    addr=""
    for attempt in 1 2 3 4 5 6; do
      # (a) USB / any already-attached transport carrying the bare serial.
      device_id="$(adb devices | awk -v s="$serial" \
          '$1==s && $2=="device" {print $1; exit}')"
      if [ -n "$device_id" ]; then
        echo "→ found $label on USB ($serial)"
        break
      fi

      # (b) Wireless: resolve current ip:port via mDNS. v2 pair-token
      # service first (match by serial PREFIX to tolerate the random
      # `-XXXXXX` pair suffix), then legacy `_adb._tcp`:5555. Require $3
      # to look like IPv4:port so a host-less `:44241` announcement
      # (IP rotated / multicast blip) doesn't become `adb connect :port`.
      addr="$(adb mdns services 2>/dev/null \
        | awk -v s="adb-$serial" \
              'index($1, s)==1 && $2 == "_adb-tls-connect._tcp" \
               && $3 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+$/ {print $3; exit}')"
      if [ -z "$addr" ]; then
        addr="$(adb mdns services 2>/dev/null \
          | awk -v s="adb-$serial" \
                '$1 == s && $2 == "_adb._tcp" \
                 && $3 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+$/ {print $3; exit}')"
      fi
      [ -n "$addr" ] && break

      if [ "$attempt" -lt 6 ]; then
        echo "  …not visible yet (round $attempt/6) — re-scanning in 3s"
        adb mdns services >/dev/null 2>&1 || true
        sleep 3
      fi
    done

    if [ -z "$device_id" ] && [ -z "$addr" ]; then
      echo "✗ $label is not reachable (no USB cable, and not advertising"
      echo "  wireless ADB after ~18s of scanning)."
      echo "  → Easiest permanent fix: plug $label in with a USB cable and"
      echo "    re-run — wired ADB never drops."
      echo "  → Or on the device: Settings → Developer options → Wireless"
      echo "    debugging → toggle ON, keep that screen visible, re-run."
      failures=$((failures + 1))
      continue
    fi

    # Wireless path only (no USB transport yet): connect to the resolved
    # endpoint. Idempotent; a stale `offline` transport is cleared by a
    # disconnect first, then re-connected (pair-token roll recovery).
    if [ -z "$device_id" ]; then
      echo "→ found at $addr — connecting"
      adb disconnect "$addr" >/dev/null 2>&1 || true
      adb connect "$addr" 2>&1 | tail -1 || true
      sleep 1
      device_id="$(adb devices | awk -v a="$addr" \
          '$2=="device" && $1 == a {print $1; exit}')"
      # Transport present but `offline` → one more disconnect/connect cycle.
      if [ -z "$device_id" ]; then
        offline_state="$(adb devices | awk -v a="$addr" '$1 == a {print $2; exit}')"
        if [ -n "$offline_state" ] && [ "$offline_state" != "device" ]; then
          echo "  transport showed $offline_state — retrying disconnect+connect"
          adb disconnect "$addr" >/dev/null 2>&1 || true
          sleep 2
          adb connect "$addr" 2>&1 | tail -1 || true
          sleep 1
          device_id="$(adb devices | awk -v a="$addr" \
              '$2=="device" && $1 == a {print $1; exit}')"
        fi
      fi
      if [ -z "$device_id" ]; then
        echo "✗ adb connect to $addr did not yield a 'device' transport"
        echo "  (pair token may have expired — re-pair via Wireless"
        echo "  debugging → Pair device with pairing code, or use USB)"
        failures=$((failures + 1))
        continue
      fi
    fi
    # 2026-08-24: verify the package is actually THERE afterwards.
    # `adb install` has been seen to report success while the package
    # never landed — HyperOS's "Install via USB" toggle, which it turns
    # itself back off, refuses the install at the system level. The
    # 2026-08-24 04:00 run logged "✓ installed to Xiaomi Pad" for a
    # package that was not on the device. A summary that counts a
    # phantom install as a success is worse than one that fails loudly.
    # 2026-08-24: the match must be EXACT. `pm list packages` prints one
    # `package:<id>` per line, and the `cn` flavor's applicationIdSuffix
    # (android/app/build.gradle.kts:75) makes it `com.example.yswords.cn`
    # — which a substring grep for `com.example.yswords` also matches. A
    # device with only the China build installed would therefore have
    # reported the intl install "verified present".
    if adb -s "$device_id" install -r "$ANDROID_APK" && \
       adb -s "$device_id" shell pm list packages 2>/dev/null \
         | tr -d '\r' | grep -qx "package:com.example.yswords"; then
      echo "✓ installed to $label via $device_id (package verified present)"
      successes=$((successes + 1))
    else
      echo "✗ install to $label FAILED (adb error, or the package is absent afterwards —"
      echo "   check Settings → Developer options → Install via USB on the device)"
      failures=$((failures + 1))
    fi
  done
else
  echo "✗ flutter build apk FAILED, or the APK it produced does not carry"
  echo "  the current code — skipping Android installs. If the content check"
  echo "  is the one that fired, the Dart AOT task was wrongly up-to-date:"
  echo "  clear it with \`$FLUTTER clean\` (or delete"
  echo "  build/app/intermediates/flutter) and re-run."
  failures=$((failures + ${#ANDROID_DEVICES[@]}))
fi

# ─── macOS BUILD + INSTALL (this Mac) ────────────────────────────
# Build the native macOS desktop app and replace /Applications/yswords.app.
# Killing any running instance first since cp -R can't overwrite a busy
# bundle. Single-device target (this Mac), no roster — if the script is
# ever run on a different Mac it'll just install there instead.
echo ""
# 2026-06-12 (v1.3.62): macOS via `flutter build macos --config-only`
# (refreshes Generated.xcconfig: version from pubspec + the dart-defines)
# THEN raw `xcodebuild -allowProvisioningUpdates`. Plain
# `flutter build macos` does NOT pass -allowProvisioningUpdates to its
# inner xcodebuild, so the free-Apple-ID 7-day provisioning profile
# can't be auto-renewed and the build fails with "No profiles for
# com.example.yswords". The two-step keeps the bundle version in sync
# AND renews the profile from CLI (requires an Apple ID signed into
# Xcode → Settings → Accounts; done 2026-06-11).
echo "→ flutter build macos --config-only ${DEFINES[*]}"
MACOS_APP_BUILT="$PROJECT/build/macos/Build/Products/Release/yswords.app"
MACOS_APP_INSTALLED="/Applications/yswords.app"
if "$FLUTTER" build macos --config-only --release "${DEFINES[@]}" \
    && xcodebuild -workspace "$PROJECT/macos/Runner.xcworkspace" \
        -scheme Runner -configuration Release \
        -derivedDataPath "$PROJECT/build/macos" \
        -allowProvisioningUpdates build; then
  echo ""
  echo "→ installing to /Applications (this Mac)"
  # If yswords is currently running, replacing the bundle while open
  # corrupts the install. Kill first; the user will see the window close
  # at 04:00 but the schedule fires when the Mac is idle anyway.
  pkill -f "/Applications/yswords.app/Contents/MacOS/yswords" 2>/dev/null || true
  sleep 1
  rm -rf "$MACOS_APP_INSTALLED"
  if cp -R "$MACOS_APP_BUILT" "$MACOS_APP_INSTALLED"; then
    echo "✓ installed to /Applications/yswords.app (this Mac)"
    successes=$((successes + 1))
  else
    echo "✗ install to /Applications/yswords.app FAILED"
    failures=$((failures + 1))
  fi
else
  echo "✗ flutter build macos FAILED — skipping macOS install"
  failures=$((failures + 1))
fi

echo ""
echo "==== summary: $successes ok, $failures failed ===="
echo "==== done $(date '+%H:%M:%S') ===="

# Exit 0 if at least one device got the build; 1 only if all failed.
if [ "$successes" -gt 0 ]; then
  exit 0
else
  exit 1
fi
