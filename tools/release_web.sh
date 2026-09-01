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

# How much of main.dart.js verify_site() fingerprints. 256 KB out of
# ~10 MB: measured 2026-08-30, the intl and cn bundles already differ
# inside the first slice this size, and it keeps the check cheap enough
# to run on every site on every retry.
MAIN_SLICE=262144

# Prove one site is serving what was just built.
#
# Netlify answers a request for a missing file with 200 + index.html, so
# an exit status settles nothing here — both checks read the body.
verify_site() {
  local label="$1" host="$2"
  local url="https://$host.netlify.app"
  local served attempt

  # WHICH bundle landed matters as much as which version. Netlify serves
  # these files byte-identical to the copies on disk — measured across
  # all four sites, 2026-08-17 — so comparing hashes settles it without
  # depending on anything inside them. This is the check that catches the
  # recorded recovery hazard: once the second build starts, build/web
  # holds the CHINA bundle, so redeploying it to an international site
  # ships CHINA_MODE to readers who can reach Google.
  #
  # 2026-08-30: it now hashes main.dart.js as well, and that is the part
  # doing the work. The old version hashed flutter_bootstrap.js ALONE,
  # and its own comment named the blind spot that would kill it:
  #
  #   > the two bootstraps differ ONLY because --no-web-resources-cdn is
  #   > passed to the China build alone (dart-defines do not reach this
  #   > file). Pass that flag to both builds, or neither, and this check
  #   > keeps passing while no longer being able to tell the bundles
  #   > apart.
  #
  # That flag now goes to both builds (see the international build
  # below), so the bootstraps ARE byte-identical and that sentence has
  # come true. main.dart.js is where CHINA_MODE actually lands, and the
  # two differ there: measured on the dev sites at the same v1.4.169,
  # 10,418,966 B (intl) vs 10,285,102 B (cn), with distinct hashes
  # inside the first 256 KB.
  #
  # A 256 KB Range slice rather than the whole 10 MB file: enough to
  # tell the bundles apart, cheap enough to run on every site on every
  # attempt. Netlify answered 206 to this on both dev sites, and
  # `Accept-Encoding: identity` is required — without it the range would
  # apply to a gzip stream and not to the bytes on disk.
  #
  # The bootstrap hash is kept because it costs 11 KB and still catches
  # engine-revision and build-config drift; it just can no longer be the
  # thing that distinguishes intl from cn.
  local want_boot want_main got_boot got_main
  want_boot="$(shasum -a 256 "$PROJECT/build/web/flutter_bootstrap.js" | cut -d' ' -f1)"
  want_main="$(head -c "$MAIN_SLICE" "$PROJECT/build/web/main.dart.js" | shasum -a 256 | cut -d' ' -f1)"

  # Retried together, because an abort costs a rebuild and a single
  # dropped connection must not be able to cause one. Freshness comes
  # from Netlify invalidating the edge on deploy, NOT from a cache-buster
  # — measured 2026-08-17, a random query string returns the same edge
  # object with the same `age`, so the query is part of nothing.
  for attempt in 1 2 3; do
    served="$(curl -fsS --max-time 30 "$url/version.json" 2>/dev/null \
      | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')"
    got_boot="$(curl -fsS --max-time 30 "$url/flutter_bootstrap.js" 2>/dev/null \
      | shasum -a 256 | cut -d' ' -f1)"
    got_main="$(curl -fsS --max-time 60 \
      -H "Range: bytes=0-$((MAIN_SLICE - 1))" -H 'Accept-Encoding: identity' \
      "$url/main.dart.js" 2>/dev/null | shasum -a 256 | cut -d' ' -f1)"
    if [[ "$served" = "$APP_VERSION" && "$got_boot" = "$want_boot" \
          && "$got_main" = "$want_main" ]]; then
      echo "  ✓ $label — v$APP_VERSION, bundle matches build/web"
      return 0
    fi
    if [[ "$attempt" != "3" ]]; then sleep 5; fi
  done

  # Say WHICH check failed. "a different bundle" was ambiguous once there
  # was more than one way to be different, and the main.dart.js case is
  # the one that means CHINA_MODE went to the wrong site — worth naming
  # rather than leaving the operator to guess.
  if [[ "$served" != "$APP_VERSION" ]]; then
    echo "  ✗ $label serves version '${served:-none}', expected $APP_VERSION"
  elif [[ "$got_main" != "$want_main" ]]; then
    echo "  ✗ $label serves v$APP_VERSION but a different main.dart.js than"
    echo "    build/web — this is the CHINA_MODE/intl mix-up. Rebuild the"
    echo "    bundle this site should have and redeploy it."
  else
    echo "  ✗ $label serves v$APP_VERSION but a different flutter_bootstrap.js"
    echo "    than build/web"
  fi
  return 1
}

# Deploy build/web to each "id:label:host" entry (parallel), then verify
# every one of them.
#
# 2026-08-17: this used to run each deploy with `&` and then a bare
# `wait`, which returns 0 whatever the jobs did — verified on this
# machine's bash 3.2 — so `set -e` could never fire. Twice, v1.4.61 and
# v1.4.65 and both yswords-qat, the script printed "✓ deployed" while the
# site still served the previous version; the second time
# `netlify api listSiteDeploys` had recorded `state: error, "Deploy
# canceled"`.
#
# Waiting per PID is therefore NOT on its own enough, and the fix does
# not rest on it: "Deploy canceled" is a state Netlify can set after the
# upload finishes and the CLI has already exited 0, and no exit code
# would carry that. So exit codes only drive the retry — whether the
# release succeeded is decided by re-fetching from the SITE.
deploy_sites() {
  local entry id label host i
  local pids=() entries=() failed=()

  if [[ ! -f "$PROJECT/build/web/main.dart.js" ]]; then
    echo "✗ build/web/main.dart.js is missing — refusing to deploy a shell"
    exit 1
  fi

  for entry in "$@"; do
    IFS=':' read -r id label host <<<"$entry"
    echo "==> deploying $label ($id)"
    "$NETLIFY" deploy --prod --site "$id" --dir build/web \
      --message "v$APP_VERSION $label" &
    pids+=("$!")
    entries+=("$entry")
  done

  for i in "${!pids[@]}"; do
    if ! wait "${pids[$i]}"; then
      IFS=':' read -r id label host <<<"${entries[$i]}"
      echo "WARN: netlify deploy of $label exited non-zero"
      failed+=("${entries[$i]}")
    fi
  done

  # Retry a failed site once, on its own. Both recorded failures were a
  # canceled deploy inside a parallel fan-out, and stopping here would
  # leave the sites on two different versions — the state this change
  # exists to prevent. The retry's own exit code is not trusted either;
  # verification below decides.
  for entry in ${failed[@]+"${failed[@]}"}; do
    IFS=':' read -r id label host <<<"$entry"
    echo "==> retrying $label alone"
    "$NETLIFY" deploy --prod --site "$id" --dir build/web \
      --message "v$APP_VERSION $label (retry)" || true
  done

  failed=()
  echo "==> verifying"
  for entry in "$@"; do
    IFS=':' read -r id label host <<<"$entry"
    if ! verify_site "$label" "$host"; then
      failed+=("$entry")
    fi
  done

  if [[ ${#failed[@]} -gt 0 ]]; then
    echo
    echo "✗ release ABORTED — these sites are not serving v$APP_VERSION:"
    for entry in "${failed[@]}"; do
      IFS=':' read -r id label host <<<"$entry"
      echo "    $label  https://$host.netlify.app  ($id)"
    done
    echo "  build/web still holds the bundle for THIS group, so re-running"
    echo "  the same netlify deploy is safe right now. After a later build"
    echo "  overwrites build/web it is not — rebuild that bundle first."
    exit 1
  fi
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

# 2026-08-31: the crawlable Bible under /read/.
#
# The app paints scripture into a CanvasKit <canvas> and addresses
# chapters with hash routes, so yahwehword.com is ONE indexable URL with
# no text a crawler can read. tools/prerender_bible.dart emits ~4,300
# JavaScript-free pages carrying the real verse text, plus one sitemap
# per edition — and `web/sitemap.xml` is a committed sitemap INDEX that
# NAMES those five children. If this step is ever removed, that index
# keeps shipping and every child it points at 404s.
#
# The sermons under /sermons/ are the same story and the same fix, with
# one difference worth stating: they are the half that is actually
# unique. Scripture text is the most duplicated content on the web, but
# these 289 transcripts are not published anywhere else in this form.
# `web/sitemap.xml` names those three children too.
#
# Run per build, not once: `flutter build web` runs twice below
# (international, then CHINA_MODE) and each rewrites build/web in place.
# Cheap enough that per-build is the safe default — ~7 s for all five
# editions and all three sermon languages.
# test/prerender_bible_test.dart and test/prerender_sermons_test.dart
# each assert there is at least one prerender call per
# `flutter build web` in this file.
# 2026-09-02: strip the translations we may not redistribute as files.
#
# `flutter build web` writes EVERY asset declared in pubspec.yaml into
# build/web/assets/assets/, so the whole translation is one GET away.
# Measured on prod before this existed:
#
#   /assets/assets/nasb.json  200  7,215,432   (Lockman)
#   /assets/assets/leb.json   200  8,812,100   (Logos/Faithlife)
#   /assets/assets/kjv.json   200  7,604,330   (public domain — stays)
#
# Both are licensed for quotation, not for redistribution of the complete
# text. The 2026-08-31 prerender exclusion was built for exactly this
# concern and does NOT cover it: it keeps them out of the /read/ pages and
# never touched the asset bundle, which is where the files actually are.
#
# Native builds still bundle them — this is a web-only hold pending the
# publishers' answer, not the NIV treatment (entry and asset both deleted,
# 2026-05). `kWebRestrictedVersions` in lib/constants/bible_versions.dart
# is the other half: it hides the editions from the picker on web so the
# app never asks for a file that is not there. Keep the two lists equal —
# test/web_restricted_versions_test.dart fails if they drift, or if this
# step disappears from this script.
#
# Runs per build, like prerender(), because each `flutter build web`
# rewrites build/web in place and puts the files back.
WEB_RESTRICTED_ASSETS=(nasb leb)
strip_restricted_assets() {
  echo "==> stripping unlicensed translations from build/web"
  for v in "${WEB_RESTRICTED_ASSETS[@]}"; do
    f="$PROJECT/build/web/assets/assets/$v.json"
    if [[ -f "$f" ]]; then
      echo "    removed assets/$v.json ($(wc -c <"$f" | tr -d ' ') bytes)"
      rm -f "$f"
    fi
    # Belt and braces: refuse to deploy if it is somehow still there.
    if [[ -f "$f" ]]; then
      echo "✗ could not remove $f — refusing to deploy" >&2
      exit 1
    fi
  done
  # AssetManifest.bin still NAMES them. That is deliberate and harmless:
  # it is a binary manifest, rewriting it here would be fragile, and no
  # code path asks for these two on web now that the picker hides them.
  # If something ever does, it gets a 404 through rootBundle, which
  # daily_verse_fallback._loadBundle already treats as an empty result.
}

prerender() {
  echo "==> prerendering the crawlable Bible into build/web/read/"
  "${DART:-$HOME/flutter/bin/dart}" run "$PROJECT/tools/prerender_bible.dart" \
    --out "$PROJECT/build/web" --assets "$PROJECT/assets"
  echo "==> prerendering the crawlable sermons into build/web/sermons/"
  "${DART:-$HOME/flutter/bin/dart}" run "$PROJECT/tools/prerender_sermons.dart" \
    --out "$PROJECT/build/web" --assets "$PROJECT/assets"
}

# ── International build → English sites (+ prod) ──────────────────
echo "==> building INTERNATIONAL bundle"
# 2026-08-30: --no-web-resources-cdn is now passed to BOTH builds.
#
# It used to be China-only, deliberately: by default Flutter web pulls
# the ~7 MB CanvasKit wasm from `https://www.gstatic.com/flutter-canvaskit`,
# and for readers who can reach it that is a better-peered CDN, often
# already warm from another Flutter app. The local copy is emitted into
# build/web/canvaskit/ on every build regardless; the flag only decides
# whether the bootstrap USES it.
#
# What changed is the blast radius, not the reachability. The user
# reports several people in mainland China running the INTERNATIONAL
# build over yahwehword.com and finding it stable, so gstatic is
# evidently reachable for them today — the earlier assumption that it is
# uniformly blocked was too strong, and the China bundle is on its way
# out because of it. But once the cn sites are retired the intl bundle
# is the ONLY bundle, so gstatic stops being a preference with a
# fallback and becomes a single point of failure nobody here controls.
#
# Cost of the flag: one cold load per browser pulls canvaskit from
# Netlify instead of gstatic, then caches it. Benefit: the app depends
# on exactly one host being reachable — the one already serving it.
# That trade is worth a slower first paint.
#
# NOTE: this makes the two builds' flutter_bootstrap.js byte-identical.
# See verify_site() — the bundle check had to move to main.dart.js,
# which is the file dart-defines actually reach.
"$FLUTTER" build web --release \
  --no-web-resources-cdn \
  --dart-define="APP_VERSION=$APP_VERSION"
strip_restricted_assets
prerender
INTL_SITES=(
  "b745ae1f-0780-4fa3-8478-bdf2f2aaf59a:dev:yswords-dev"
  "2bcb6644-2a3a-4050-b6dc-5b059bbe96d3:qat:yswords-qat"
)
if [[ "$INCLUDE_PROD" = "1" ]]; then
  echo "==> --include-prod set; international build will also go to prod."
  INTL_SITES+=("975d1a08-8203-4994-a7ef-ca60452e41bf:prod:yswords")
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
strip_restricted_assets
prerender
CN_SITES=(
  "50f1502c-299f-4ff8-a21b-28f53eaee1e1:cn-dev:yswords-cn-dev"
  "266f97ef-f28b-4313-b83b-653c098df640:cn-qat:yswords-cn-qat"
)
if [[ "$INCLUDE_PROD" = "1" ]]; then
  echo "==> --include-prod set; China build will also go to yswords-cn."
  CN_SITES+=("3094b5e5-bf62-48e4-9b3b-4ff8adc84f3c:cn:yswords-cn")
fi
deploy_sites "${CN_SITES[@]}"

echo
echo "✓ v$APP_VERSION deployed (international → en sites, CHINA_MODE → cn sites)"
echo "  — every site was re-fetched and confirmed serving it."
echo "  next: git commit + push, then tools/yswords-ios-reinstall.sh for native devices"
