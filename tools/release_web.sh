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

# 2026-08-03: `flutter build web` does NOT clean stray files it
# doesn't own out of build/web/ — it only writes/overwrites its own
# known outputs. tools/release_web_wasm_dev.sh (the dev-only skwasm
# experiment) writes build/web/_headers to add
# `Cross-Origin-Embedder-Policy: require-corp` for THAT ONE deploy —
# but because nothing here ever removed it, it silently rode along
# into every subsequent normal deploy from this script (v1.3.180,
# v1.3.181), shipping COEP to ALL FOUR dev/qat sites, not just the
# intended skwasm target. Concrete damage: it broke Google Sign-In
# dev-wide — signInWithRedirect's auth iframe (proxied from
# ysword.firebaseapp.com, no CORP header) got silently blocked by our
# own page's COEP, hanging Firebase.initializeApp() forever with no
# error, no timeout, and no way for the user to tell it apart from a
# real problem on their end. Also re-broke Bible Evidence images
# (yswords-data.netlify.app lacked a CORP header at the time) the
# same way. Neither this script nor the wasm one owns cleanup of the
# OTHER's leftover files, so remove it defensively here, every run —
# the wasm script re-adds it fresh on its own next run if wanted.
rm -f "$PROJECT/build/web/_headers"

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
# 2026-08-02: --no-web-resources-cdn is REQUIRED for the China build.
# By default Flutter web fetches the ~7 MB CanvasKit wasm from
# `https://www.gstatic.com/flutter-canvaskit/<rev>/chromium/canvaskit.wasm`
# — and gstatic.com is blocked in mainland China, which is precisely
# the audience this bundle exists for. The local copy is already
# emitted into build/web/canvaskit/ on every build; this flag makes
# the bootstrap actually USE it (same-origin, served by Netlify)
# instead of the unreachable CDN.
# Deliberately NOT applied to the international build above: for
# users who can reach it, gstatic is a better-peered CDN and is
# often already warm in the browser cache from other Flutter apps.
"$FLUTTER" build web --release \
  --no-web-resources-cdn \
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
