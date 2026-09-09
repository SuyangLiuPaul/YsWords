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
DEV_URL="https://yswords-dev.netlify.app"

# 2026-09-09: same guard tools/release_web.sh grew, for the same reason
# and checked at the same point — BEFORE the build. The netlify CLI lives
# in another project's node_modules, so a cleanup over there silently
# disarms releases here (it did, 2026-09-09). Without this the missing
# binary is only discovered after a full `flutter build web --wasm`, and
# announces itself as bash's "No such file or directory", which names no
# way back.
if [ ! -x "$NETLIFY" ]; then
  echo "netlify CLI not found or not executable at:" >&2
  echo "  $NETLIFY" >&2
  echo "Restore it with:" >&2
  echo "  (cd ~/Documents/CodingProject/SmartHome && npm install netlify-cli --no-save --legacy-peer-deps)" >&2
  echo "or point NETLIFY= at another copy." >&2
  exit 1
fi

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

# 2026-09-09: the CLI exiting 0 is not the deploy landing, and this
# script used to print its ✓ on nothing else.
#
# tools/release_web.sh carries the recorded evidence: v1.4.61 and v1.4.65
# both printed "✓ deployed" while the site still served the previous
# bundle, and `netlify api listSiteDeploys` had the deploy in
# `state: error, "Deploy canceled"` — a state Netlify can set AFTER the
# CLI has already exited 0, which no exit code can carry. `set -e`
# handles the deploy that fails loudly; it cannot handle this one.
#
# The cost of not checking is worse here than on a normal release. This
# script's ✓ hands the operator one instruction: go look at
# window.crossOriginIsolated. If the deploy never landed, the site is
# still the CanvasKit build, that flag is false, and the honest reading
# of the printed advice is "skwasm went single-threaded" — the v1.3.132
# bug — so the experiment gets reverted over a failure that was in the
# upload. Ask the SITE instead, and check the three things that make
# this deploy the thing it claims to be:
#
#   • version.json    — the site moved at all
#   • bootstrap hash  — the WASM bundle landed, not a stale CanvasKit one
#                       (Netlify serves this byte-identical to disk; see
#                       release_web.sh's verify_site for the measurement).
#                       A dart2wasm build changes the build config —
#                       compile target and renderer — so unlike the
#                       intl/cn split, this file DOES tell the two apart.
#                       It is also the only check with anything to say on
#                       a SECOND run: nothing here bumps a version, so
#                       version.json already matches and the COEP header
#                       is already set from the first wasm deploy.
#   • COEP header     — the per-deploy build/web/_headers actually took
#                       effect. Without it the context is not
#                       crossOriginIsolated and skwasm silently degrades,
#                       which is the whole hazard this script documents.
#
# This body MUST live in a function, and the call below MUST stay in the
# condition of an `if` — see the call site. Everything here is written to
# survive a site that answers nothing at all, which is precisely when the
# operator most needs to be told something.
verify_dev_site() {
  local want_boot served got_boot coep attempt
  want_boot="$(shasum -a 256 "$PROJECT/build/web/flutter_bootstrap.js" | cut -d' ' -f1)"
  served=""; got_boot=""; coep=""
  for attempt in 1 2 3; do
    served="$(curl -fsS --max-time 30 "$DEV_URL/version.json" 2>/dev/null \
      | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
    got_boot="$(curl -fsS --max-time 30 "$DEV_URL/flutter_bootstrap.js" 2>/dev/null \
      | shasum -a 256 | cut -d' ' -f1)"
    # -D - keeps the headers; the body goes nowhere. Lower-cased because
    # HTTP header names are case-insensitive and nothing promises which
    # casing an edge returns.
    coep="$(curl -fsS --max-time 30 -o /dev/null -D - "$DEV_URL/" 2>/dev/null \
      | tr 'A-Z' 'a-z' | tr -d '\r' \
      | sed -n 's/^cross-origin-embedder-policy:[[:space:]]*//p' | head -1)"
    if [[ "$served" = "$APP_VERSION" && "$got_boot" = "$want_boot" \
          && "$coep" = "require-corp" ]]; then
      return 0
    fi
    # The backoff is a knob only so tools/test_release_scripts.py can run
    # the failure path without waiting on it.
    if [[ "$attempt" != "3" ]]; then sleep "${RELEASE_VERIFY_SLEEP:-5}"; fi
  done

  echo >&2
  echo "✗ skwasm deploy NOT confirmed on $DEV_URL — do NOT read anything" >&2
  echo "  into window.crossOriginIsolated until this is resolved:" >&2
  if [[ "$served" != "$APP_VERSION" ]]; then
    echo "    version.json says '${served:-unreachable}', expected $APP_VERSION" >&2
  fi
  if [[ "$got_boot" != "$want_boot" ]]; then
    echo "    flutter_bootstrap.js differs from build/web — the site is" >&2
    echo "    probably still on the CanvasKit bundle" >&2
  fi
  if [[ "$coep" != "require-corp" ]]; then
    echo "    Cross-Origin-Embedder-Policy is '${coep:-absent}', not" >&2
    echo "    require-corp — skwasm would run single-threaded (v1.3.132)" >&2
  fi
  echo "  build/web still holds the wasm bundle, so re-running just the" >&2
  echo "  netlify deploy above is safe right now." >&2
  return 1
}

# `if ! verify_dev_site` is load-bearing, not style. Under `set -euo
# pipefail` (line 51) a plain assignment from a command substitution
# carries that pipeline's status, so ONE failing curl — a 5xx while the
# Netlify edge propagates, a DNS blip, a reset, a --max-time timeout —
# aborts the whole script on the spot. Run as top-level code this block
# did exactly that: measured, the script died at `served=…` with exit 22,
# printed NOTHING after "==> verifying", made 1 of its 9 curl calls, and
# never reached the retry or the diagnosis below — the `${served:-
# unreachable}` and `${coep:-absent}` fallbacks above were written for a
# case the code could not survive long enough to report.
#
# The shell suspends errexit for everything executed while a command's
# status is being TESTED, and that suspension follows the call into the
# function body. tools/release_web.sh has always called its own
# verify_site() this way. Moving this call out of the `if` re-arms the
# bug silently; tools/test_release_scripts.py's unreachable-site test is
# what catches that.
echo "==> verifying $DEV_URL is serving this deploy"
if ! verify_dev_site; then
  exit 1
fi

echo
echo "✓ skwasm experiment deployed to $DEV_URL"
echo "  — re-fetched: v$APP_VERSION, matching bundle, COEP require-corp."
echo "  VERIFY FIRST: window.crossOriginIsolated must be true."
echo "  Revert with: tools/release_web.sh"
