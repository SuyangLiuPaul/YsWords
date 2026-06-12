#!/usr/bin/env bash
# 2026-05-24 (v1.3.9): single-command web release.
# 2026-05-31 (v1.3.x): split into TWO builds — the Chinese sites must
#   ship with CHINA_MODE=true. Previously this built ONE international
#   bundle and deployed it to the cn-* sites too, so yswords-cn showed
#   the Google sign-in button + tried to init Firebase (both useless
#   behind the GFW). CHINA_MODE=true skips Firebase Auth/RTDB init and
#   hides the Google sign-in UI (see lib/constants/build_flags.dart).
#
# Auto-bumps version, then:
#   • builds the INTERNATIONAL bundle → yswords-dev + yswords-qat
#     (+ yswords prod with --include-prod)
#   • builds the CHINA bundle (CHINA_MODE=true) → yswords-cn-dev +
#     yswords-cn-qat (+ yswords-cn prod with --include-prod)
#
# Usage:
#   tools/release_web.sh                   # bump patch, build both, deploy 4 dev/qat sites
#   tools/release_web.sh --no-bump         # use current pubspec version
#   tools/release_web.sh --include-prod    # ALSO push to yswords + yswords-cn (REQUIRES user OK)
set -euo pipefail

PROJECT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER="${FLUTTER:-$HOME/flutter/bin/flutter}"
NETLIFY="${NETLIFY:-$HOME/Documents/CodingProject/SmartHome/node_modules/.bin/netlify}"

BUMP=1
INCLUDE_PROD=0
for arg in "$@"; do
  case "$arg" in
    --no-bump) BUMP=0 ;;
    --include-prod) INCLUDE_PROD=1 ;;
  esac
done

if [[ "$BUMP" = "1" ]]; then
  "$PROJECT/tools/bump_version.sh"
fi
APP_VERSION="$(awk '/^version:/ {print $2; exit}' "$PROJECT/pubspec.yaml")"
# 2026-06-09 (v1.3.59): release time is no longer injected per-build.
# bump_version.sh stamps it into lib/constants/app_version.dart
# (kAppReleaseTime) so EVERY platform reads one identical value, instead
# of each build's own wall clock (which made iOS/web/Android disagree and
# an unset shell var land empty → blank "last updated").
echo "==> APP_VERSION=$APP_VERSION (release time stamped in source)"

# 2026-05-27 (v1.3.47): refresh the version cache so the launchd-
# spawned yswords-ios-reinstall.sh has a known-good fallback even
# if its own awk gets blocked by macOS TCC at 04:00 (the cache
# lives at `~/.config/yswords/current-version`, outside the
# TCC-protected `~/Documents` tree).
VERSION_CACHE="$HOME/.config/yswords/current-version"
mkdir -p "$(dirname "$VERSION_CACHE")" 2>/dev/null
printf '%s\n' "$APP_VERSION" > "$VERSION_CACHE" 2>/dev/null || true

# 2026-06-12: keep the launchd 04:00 entry script in sync. It MUST be a
# full COPY outside ~/Documents: macOS TCC blocks the launchd-spawned
# bash from even OPENING a script inside ~/Documents ("Operation not
# permitted", exit 126) — the 2026-06-10 exec-shim experiment failed
# exactly that way on its first 04:00 run. Re-copying here (an
# interactive session, no TCC issue) on every release keeps the copy
# from drifting, which is what bit us when v1.3.59 removed the
# APP_RELEASE_TIME inject but the stale copy kept injecting it.
LAUNCHD_COPY="$HOME/.config/yswords/scripts/yswords-ios-reinstall.sh"
if [ -d "$(dirname "$LAUNCHD_COPY")" ]; then
  cp "$PROJECT/tools/yswords-ios-reinstall.sh" "$LAUNCHD_COPY" 2>/dev/null \
    && chmod +x "$LAUNCHD_COPY" 2>/dev/null \
    && echo "==> launchd reinstall copy synced" \
    || echo "WARN: could not sync launchd reinstall copy"
fi

cd "$PROJECT"

# Deploy build/web to each "id:name" entry (parallel, then wait).
deploy_sites() {
  for entry in "$@"; do
    id="${entry%:*}"
    name="${entry#*:}"
    echo "==> deploying $name ($id)"
    "$NETLIFY" deploy --prod --site "$id" --dir build/web \
      --message "v$APP_VERSION $name" &
  done
  wait
}

# ── International build → English sites (+ prod) ──────────────────
echo "==> building INTERNATIONAL bundle"
"$FLUTTER" build web --release \
  --dart-define="APP_VERSION=$APP_VERSION"
INTL_SITES=(
  "b745ae1f-0780-4fa3-8478-bdf2f2aaf59a:dev"
  "2bcb6644-2a3a-4050-b6dc-5b059bbe96d3:qat"
)
if [[ "$INCLUDE_PROD" = "1" ]]; then
  echo "==> --include-prod set; international build will also go to prod."
  INTL_SITES+=("975d1a08-8203-4994-a7ef-ca60452e41bf:prod")
fi
deploy_sites "${INTL_SITES[@]}"

# ── China build (CHINA_MODE=true) → Chinese sites (+ cn prod) ─────
# Rebuilds build/web in place; the international deploys above have
# already finished uploading (deploy_sites waits), so overwriting is
# safe.
echo "==> building CHINA bundle (CHINA_MODE=true)"
"$FLUTTER" build web --release \
  --dart-define="APP_VERSION=$APP_VERSION" \
  --dart-define="CHINA_MODE=true"
CN_SITES=(
  "50f1502c-299f-4ff8-a21b-28f53eaee1e1:cn-dev"
  "266f97ef-f28b-4313-b83b-653c098df640:cn-qat"
)
if [[ "$INCLUDE_PROD" = "1" ]]; then
  echo "==> --include-prod set; China build will also go to yswords-cn."
  CN_SITES+=("3094b5e5-bf62-48e4-9b3b-4ff8adc84f3c:cn")
fi
deploy_sites "${CN_SITES[@]}"

echo
echo "✓ v$APP_VERSION deployed (international → en sites, CHINA_MODE → cn sites)."
echo "  next: git commit + push, then tools/yswords-ios-reinstall.sh for native devices"
