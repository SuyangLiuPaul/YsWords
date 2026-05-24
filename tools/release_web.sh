#!/usr/bin/env bash
# 2026-05-24 (v1.3.9): single-command web release.
#
# Auto-bumps version, builds web with the new APP_VERSION +
# APP_RELEASE_TIME injected as --dart-defines, then deploys to
# yswords-dev + yswords-qat + yswords-cn-dev + yswords-cn-qat
# (the four "free to push" sites — prod requires explicit user
# instruction per the release policy).
#
# Usage:
#   tools/release_web.sh                   # bump patch, build, deploy 4 sites
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
APP_RELEASE_TIME="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
echo "==> APP_VERSION=$APP_VERSION APP_RELEASE_TIME=$APP_RELEASE_TIME"

cd "$PROJECT"
"$FLUTTER" build web --release \
  --dart-define="APP_VERSION=$APP_VERSION" \
  --dart-define="APP_RELEASE_TIME=$APP_RELEASE_TIME"

# Free-to-push sites (dev + qat both English + Chinese variants).
SITES=(
  "b745ae1f-0780-4fa3-8478-bdf2f2aaf59a:dev"
  "50f1502c-299f-4ff8-a21b-28f53eaee1e1:cn-dev"
  "2bcb6644-2a3a-4050-b6dc-5b059bbe96d3:qat"
  "266f97ef-f28b-4313-b83b-653c098df640:cn-qat"
)
# Prod sites (require explicit user OK).
PROD_SITES=(
  "975d1a08-8203-4994-a7ef-ca60452e41bf:prod"
  "3094b5e5-bf62-48e4-9b3b-4ff8adc84f3c:cn"
)
if [[ "$INCLUDE_PROD" = "1" ]]; then
  echo "==> --include-prod set; will deploy to prod + cn after dev/qat."
  SITES+=("${PROD_SITES[@]}")
fi

for entry in "${SITES[@]}"; do
  id="${entry%:*}"
  name="${entry#*:}"
  echo "==> deploying $name ($id)"
  "$NETLIFY" deploy --prod --site "$id" --dir build/web \
    --message "v$APP_VERSION $name" &
done
wait

echo
echo "✓ v$APP_VERSION deployed."
echo "  next: git commit + push, then tools/yswords-ios-reinstall.sh for native devices"
