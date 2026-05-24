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
ANDROID_APK="$PROJECT/build/app/outputs/flutter-apk/app-release.apk"

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

# Android device roster — uses the mDNS `adb-<serial>._adb-tls-connect._tcp`
# format so DHCP IP changes don't break the schedule. Fallback to
# the current IP:port for the case mDNS doesn't resolve (some
# WiFi networks block .local mDNS).
ANDROID_DEVICES=(
  "adb-0907E41001A00540-K09tQP._adb-tls-connect._tcp|192.168.4.19:38027|Xiaomi Pad 7 Ultra (jinghu)"
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
APP_VERSION="$(awk '/^version:/ {print $2; exit}' "$PROJECT/pubspec.yaml")"
APP_RELEASE_TIME="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
DEFINES=(
  --dart-define="APP_VERSION=$APP_VERSION"
  --dart-define="APP_RELEASE_TIME=$APP_RELEASE_TIME"
)
echo "==> APP_VERSION=$APP_VERSION APP_RELEASE_TIME=$APP_RELEASE_TIME"

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
  declare -A succeeded
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
        succeeded[$uuid]=1
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
echo ""
echo "→ flutter build apk --release ${DEFINES[*]}"
if "$FLUTTER" build apk --release "${DEFINES[@]}"; then
  for entry in "${ANDROID_DEVICES[@]}"; do
    mdns="${entry%%|*}"
    rest="${entry#*|}"
    ipport="${rest%%|*}"
    label="${rest##*|}"
    echo ""
    echo "→ installing to $label"
    # Try mDNS first (survives IP changes); fall back to last-known
    # IP:port. ADB's `connect` is idempotent — safe to call even if
    # already connected.
    adb connect "$mdns" 2>&1 | tail -1 || true
    adb connect "$ipport" 2>&1 | tail -1 || true
    # Pick whichever transport is `device` (not offline)
    device_id="$(adb devices | awk '$2=="device" && ($1 ~ /'"$mdns"'/ || $1 ~ /'"$ipport"'/) {print $1; exit}')"
    if [ -z "$device_id" ]; then
      echo "✗ Could not establish wireless ADB to $label (neither mDNS nor IP)"
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
echo "→ flutter build macos --release ${DEFINES[*]}"
MACOS_APP_BUILT="$PROJECT/build/macos/Build/Products/Release/yswords.app"
MACOS_APP_INSTALLED="/Applications/yswords.app"
if "$FLUTTER" build macos --release "${DEFINES[@]}"; then
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
