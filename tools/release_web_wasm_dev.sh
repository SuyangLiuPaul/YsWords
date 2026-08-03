#!/usr/bin/env bash
# 2026-08-02: DEV-ONLY skwasm experiment. Deliberately separate from
# tools/release_web.sh so the normal 6-site release path is untouched
# and this stays trivially revertible (delete this file).
#
# WHY: user reports reading-pane scroll isn't "silky" the way a native
# DOM site (BBC) is. Root cause is structural, not tunable: CanvasKit
# paints every frame through WebGL on the MAIN thread, while a DOM page
# is scrolled by the browser's native off-main-thread compositor. Scroll
# physics is already correct (the pane inherits iOS bouncing physics on
# macOS/iOS via MaterialScrollBehavior), so there is nothing left to
# tune at the Flutter layer. Flutter's answer is skwasm: Skia compiled
# to multithreaded WebAssembly, which moves rasterisation off the main
# thread.
#
# WHY THIS IS DEV-ONLY, AND WHY IT FAILED BEFORE: skwasm needs a
# `crossOriginIsolated` context (SharedArrayBuffer). Without it, Flutter
# SILENTLY falls back to single-threaded skwasm — which is WORSE than
# CanvasKit on cold boot. That is exactly what happened in v1.3.132:
# Skia init and the 6-8 MB Bible-JSON decode competed for one thread and
# intermittently blew the FetchVerses 20 s timeout ("fails to load,
# works on retry"). See netlify.toml's COOP comment for the full story.
#
# Isolation needs BOTH headers:
#   • Cross-Origin-Opener-Policy: same-origin  — already shipped
#     repo-wide in netlify.toml, unblocked by moving Google Sign-In off
#     signInWithPopup to redirect + the /__/auth/* proxy (v1.3.174-178).
#   • Cross-Origin-Embedder-Policy: require-corp — added HERE, via a
#     per-deploy build/web/_headers file rather than netlify.toml,
#     because netlify.toml is shared by all 6 sites and COEP has a real
#     blast radius: it blocks every cross-origin subresource that
#     doesn't opt in with CORP/CORS. Scoping it to this one deploy keeps
#     qat and both prod sites completely unaffected.
#
# `--no-web-resources-cdn` is REQUIRED here, not optional: by default the
# renderer's wasm is fetched from gstatic.com, which serves no CORP
# header and would therefore be blocked outright by require-corp —
# the app would fail to render at all. Serving it same-origin sidesteps
# that entirely.
#
# VERIFY AFTER RUNNING (in the browser console on yswords-dev):
#   window.crossOriginIsolated   → MUST be true. If false, skwasm has
#                                  silently gone single-threaded and you
#                                  are reproducing the v1.3.132 bug —
#                                  revert rather than "see how it goes".
# Then check Bible Evidence images + daily-verse art still load; those
# are the most likely COEP casualties.
#
# TO REVERT: run tools/release_web.sh (rebuilds CanvasKit and redeploys
# dev without the _headers file).
set -euo pipefail

PROJECT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER="${FLUTTER:-$HOME/flutter/bin/flutter}"
NETLIFY="${NETLIFY:-$HOME/Documents/CodingProject/SmartHome/node_modules/.bin/netlify}"
DEV_SITE="b745ae1f-0780-4fa3-8478-bdf2f2aaf59a"

APP_VERSION="$(awk '/^version:/ {print $2; exit}' "$PROJECT/pubspec.yaml")"
echo "==> skwasm DEV experiment, APP_VERSION=$APP_VERSION"

cd "$PROJECT"

echo "==> building WASM (skwasm) bundle"
"$FLUTTER" build web --release \
  --wasm \
  --no-web-resources-cdn \
  --dart-define="APP_VERSION=$APP_VERSION"

# Netlify honours a `_headers` file in the publish directory per-deploy,
# layered on top of netlify.toml. This is the ONLY place COEP is set.
cat > build/web/_headers <<'EOF'
# Dev-only skwasm experiment — see tools/release_web_wasm_dev.sh.
# COOP already comes from netlify.toml (same-origin); COEP is added here
# so it ships with THIS deploy only. Together they make the context
# crossOriginIsolated, which is what lets skwasm run multithreaded
# instead of silently degrading to its slower single-threaded build.
/*
  Cross-Origin-Embedder-Policy: require-corp
EOF
echo "==> wrote build/web/_headers (COEP require-corp)"

echo "==> deploying to yswords-dev ONLY ($DEV_SITE)"
"$NETLIFY" deploy --prod --site "$DEV_SITE" --dir build/web \
  --message "v$APP_VERSION skwasm dev experiment"

echo
echo "✓ skwasm experiment deployed to https://yswords-dev.netlify.app"
echo "  VERIFY FIRST: window.crossOriginIsolated must be true."
echo "  Revert with: tools/release_web.sh"
