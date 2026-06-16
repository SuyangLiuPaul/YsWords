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
#   3. Xiaomi Pad — on the same WiFi as Mac, wireless ADB enabled,
#      paired via `adb pair` (one-time, then mDNS auto-discovery
#      handles IP changes). MIUI's "Install via USB" + Pure Mode
#      tweaks already done in the setup phase.
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

# ─── ANDROID BUILD + INSTALLS ────────────────────────────────────
# 2026-05-24 (v1.3.38): the Android product flavors block in
# android/app/build.gradle.kts now requires `--flavor` on every
# build. `intl` is the default (international) flavor with the
# original com.example.yswords applicationId; the `cn` flavor is
# installed separately by tools/yswords-cn-install.sh.
echo ""
echo "→ flutter build apk --release --flavor intl ${DEFINES[*]}"
if "$FLUTTER" build apk --release --flavor intl "${DEFINES[@]}"; then
  # Warm up mDNS — the first poll after `adb start-server` can come
  # back empty even when broadcasts are live. A short settle lets
  # the cache populate. Total cost: 3s of one-time wait per run.
  adb mdns services >/dev/null 2>&1 || true
  sleep 3

  for entry in "${ANDROID_DEVICES[@]}"; do
    serial="${entry%%|*}"
    label="${entry##*|}"
    echo ""
    echo "→ resolving wireless ADB endpoint for $label (serial $serial)"

    # First preference: the v2 pair-token service. Match by SERIAL
    # PREFIX so we tolerate the random `-XXXXXX` pair suffix changing
    # on re-pair. `index($1, "adb-"s)==1` means "$1 starts with
    # adb-<serial>" — catches both `adb-SERIAL` (rare, never paired
    # for tls-connect) and `adb-SERIAL-SUFFIX` (the normal case).
    # Also require $3 to look like `IPv4:port` — sometimes the
    # mDNS announcement loses its host A-record and shows up as
    # `:44241` (just the port) when the device's IP rotated or
    # network blip during multicast advertisement. Without this
    # guard, `adb connect :44241` would target an empty hostname
    # and fail with a confusing error.
    addr="$(adb mdns services 2>/dev/null \
      | awk -v s="adb-$serial" \
            'index($1, s)==1 && $2 == "_adb-tls-connect._tcp" \
             && $3 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+$/ \
             {print $3; exit}')"

    # Fallback: classic `_adb._tcp` on port 5555. Only present after
    # `adb tcpip 5555` has been run on the device this boot — unlikely
    # to be there for HyperOS but cheap to check. Same host-validation
    # guard.
    if [ -z "$addr" ]; then
      addr="$(adb mdns services 2>/dev/null \
        | awk -v s="adb-$serial" \
              '$1 == s && $2 == "_adb._tcp" \
               && $3 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+:[0-9]+$/ \
               {print $3; exit}')"
    fi

    if [ -z "$addr" ]; then
      echo "✗ $label is not advertising wireless ADB on this network."
      echo "  → On the device: Settings → Developer options → Wireless"
      echo "    debugging → toggle ON and keep that screen visible."
      echo "    Then re-run this script. Or plug in USB and run"
      echo "    \`adb install -r $ANDROID_APK\` manually."
      failures=$((failures + 1))
      continue
    fi

    echo "→ found at $addr — connecting + installing"
    # `adb connect` is idempotent; safe to call even if the transport
    # is already attached from a previous run. Still — if a previous
    # `connect` left the transport in `offline` state (happens when
    # the device's wireless-debug pair-token has rolled but the
    # client thinks it's still good), a fresh `disconnect` clears it
    # before the new `connect` attempt.
    adb disconnect "$addr" >/dev/null 2>&1 || true
    adb connect "$addr" 2>&1 | tail -1 || true
    sleep 1
    device_id="$(adb devices | awk -v a="$addr" \
        '$2=="device" && $1 == a {print $1; exit}')"
    # If the transport is showing but as `offline`, give it one more
    # disconnect/connect cycle. 2026-05-27: yesterday's launchd run
    # found the device at mDNS-resolved :44241 but `adb devices`
    # came back without a `device` line — suggesting the transport
    # was in `offline` state. This retry catches that case.
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
      echo "  (pair token may have expired — re-pair via the Wireless"
      echo "  debugging → Pair device with pairing code screen)"
      failures=$((failures + 1))
      continue
    fi
    if adb -s "$device_id" install -r "$ANDROID_APK"; then
      echo "✓ installed to $label via $device_id"
      successes=$((successes + 1))
    else
      echo "✗ install to $label FAILED"
      failures=$((failures + 1))
    fi
  done
else
  echo "✗ flutter build apk FAILED — skipping Android installs"
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
