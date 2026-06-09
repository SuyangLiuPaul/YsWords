#!/bin/zsh
# 2026-05-24 (v1.3.38): China-mode YsWords multi-device install.
#
# Coexists with the regular international install. Uses:
#   • Android: --flavor cn (defined in android/app/build.gradle.kts)
#     → applicationId = com.example.yswords.cn
#     → home-screen label = "YsWords CN"
#   • iOS:     patches ios/Runner.xcodeproj/project.pbxproj +
#     ios/Runner/Info.plist before build, reverts after.
#     → CFBundleIdentifier = com.example.yswords.cn
#     → CFBundleDisplayName = "YsWords CN"
#
# Both paths set `--dart-define=CHINA_MODE=true` so the runtime
# behaviour (skip Firebase init, hide Google-Fonts options, show
# "中国版" badge in About) gates correctly.
#
# Usage:
#   tools/yswords-cn-install.sh
#
# Restores ios/* files on exit even if the build or install fails.

LOG="/tmp/yswords-cn-install.log"
FLUTTER="/Users/pliu0036/flutter/bin/flutter"
PROJECT="/Users/pliu0036/Documents/yswords"
IOS_APP_CN="$PROJECT/build/ios/iphoneos/Runner.app"
ANDROID_APK_CN="$PROJECT/build/app/outputs/flutter-apk/app-cn-release.apk"

export ANDROID_HOME=/opt/homebrew/share/android-commandlinetools
export JAVA_HOME=/opt/homebrew/opt/openjdk@17
export PATH="$ANDROID_HOME/platform-tools:/opt/homebrew/opt/openjdk@17/bin:$PATH"

# iOS device roster — same as the international install script.
IOS_DEVICES=(
  "00008140-000C5D6910E3C01C|iPhone 16 Pro Max (Paul)"
  "00008103-000A24441131001E|iPad Pro 11-inch (Paul Liu's iPad)"
)

# Android device roster — same Mi Pad as the international script.
ANDROID_DEVICES=(
  "adb-0907E41001A00540-K09tQP._adb-tls-connect._tcp|192.168.4.19:38027|Xiaomi Pad 7 Ultra (jinghu)"
)

exec > "$LOG" 2>&1
echo "==== yswords-cn-install $(date +%H:%M:%S) ===="

cd "$PROJECT" || exit 1

# Pull latest committed code so the CN build matches what's on
# origin/main — symmetric with the international install script.
echo "→ git pull origin main"
git -c core.hooksPath=/dev/null pull origin main || true

APP_VERSION="$(awk '/^version:/ {print $2; exit}' pubspec.yaml)"
# v1.3.59: release time stamped into kAppReleaseTime by bump_version.sh,
# not injected here (keeps it identical across platforms + never empty).
DEFINES=(
  --dart-define=APP_VERSION="$APP_VERSION"
  --dart-define=CHINA_MODE=true
)
echo "APP_VERSION=$APP_VERSION  CHINA_MODE=true (release time stamped in source)"

OK_COUNT=0
FAIL_COUNT=0

# ─── iOS BUILD + INSTALLS (with bundle-ID patching) ──────────────
# Save originals.
PBX="$PROJECT/ios/Runner.xcodeproj/project.pbxproj"
INFO_PLIST="$PROJECT/ios/Runner/Info.plist"
PBX_BACKUP="$(mktemp)"
INFO_BACKUP="$(mktemp)"
cp "$PBX" "$PBX_BACKUP"
cp "$INFO_PLIST" "$INFO_BACKUP"
# Always revert on exit (success or failure).
trap 'cp "$PBX_BACKUP" "$PBX"; cp "$INFO_BACKUP" "$INFO_PLIST"; rm -f "$PBX_BACKUP" "$INFO_BACKUP"' EXIT

echo ""
echo "→ patching iOS Runner bundle ID + display name"
# Patch Runner target's PRODUCT_BUNDLE_IDENTIFIER (3 occurrences:
# Debug, Profile, Release). The RunnerTests target uses
# `com.example.yswords.RunnerTests` so its lines won't match the
# trailing `yswords;` and stay untouched.
sed -i '' 's|PRODUCT_BUNDLE_IDENTIFIER = com\.example\.yswords;|PRODUCT_BUNDLE_IDENTIFIER = com.example.yswords.cn;|g' "$PBX"
# Patch CFBundleDisplayName so the home-screen label differs from
# the international install. The plist value sits two lines after
# the key in Apple's plist format.
sed -i '' 's|<key>CFBundleDisplayName</key>\n.*<string>.*</string>|<key>CFBundleDisplayName</key>\n\t<string>YsWords CN</string>|' "$INFO_PLIST"
# sed -i '' on macOS doesn't reliably handle \n across two lines; do
# it the safe way via plutil.
plutil -replace CFBundleDisplayName -string "YsWords CN" "$INFO_PLIST"

echo "→ flutter build ios --release ${DEFINES[*]}"
if "$FLUTTER" build ios --release "${DEFINES[@]}"; then
  for entry in "${IOS_DEVICES[@]}"; do
    udid="${entry%%|*}"
    label="${entry##*|}"
    echo ""
    echo "→ installing to $label ($udid)"
    if xcrun devicectl device install app --device "$udid" "$IOS_APP_CN" 2>&1 | tail -5; then
      echo "✓ installed to $label"
      ((OK_COUNT+=1))
    else
      echo "✗ install to $label failed"
      ((FAIL_COUNT+=1))
    fi
  done
else
  echo "✗ flutter build ios FAILED — skipping iOS installs"
  ((FAIL_COUNT+=2))
fi

# Restore iOS files NOW so the rest of the build runs against the
# international config (trap will be a no-op if files match).
cp "$PBX_BACKUP" "$PBX"
cp "$INFO_BACKUP" "$INFO_PLIST"

# ─── ANDROID BUILD + INSTALLS ────────────────────────────────────
echo ""
echo "→ flutter build apk --release --flavor cn ${DEFINES[*]}"
if "$FLUTTER" build apk --release --flavor cn "${DEFINES[@]}"; then
  for entry in "${ANDROID_DEVICES[@]}"; do
    mdns="${entry%%|*}"
    rest="${entry#*|}"
    ipport="${rest%%|*}"
    label="${rest##*|}"
    echo ""
    echo "→ installing to $label"
    adb connect "$mdns" 2>&1 | tail -1 || true
    adb connect "$ipport" 2>&1 | tail -1 || true
    device_id="$(adb devices | awk '$2=="device" && ($1 ~ /'"$mdns"'/ || $1 ~ /'"$ipport"'/) {print $1; exit}')"
    if [ -z "$device_id" ]; then
      # Last-ditch: any USB-connected device.
      device_id="$(adb devices | awk '$2=="device" && $1 !~ /(adb-|:)/ {print $1; exit}')"
    fi
    if [ -z "$device_id" ]; then
      echo "✗ Could not establish ADB to $label (neither mDNS nor IP nor USB)"
      ((FAIL_COUNT+=1))
      continue
    fi
    if adb -s "$device_id" install -r "$ANDROID_APK_CN"; then
      echo "✓ installed to $label"
      ((OK_COUNT+=1))
    else
      echo "✗ install to $label failed"
      ((FAIL_COUNT+=1))
    fi
  done
else
  echo "✗ flutter build apk FAILED — skipping Android install"
  ((FAIL_COUNT+=1))
fi

echo ""
echo "==== summary: $OK_COUNT ok, $FAIL_COUNT failed ===="
echo "==== done $(date +%H:%M:%S) ===="

# Exit 0 iff at least one device got the build; exit 1 only when ALL failed.
[ "$OK_COUNT" -gt 0 ] && exit 0 || exit 1
