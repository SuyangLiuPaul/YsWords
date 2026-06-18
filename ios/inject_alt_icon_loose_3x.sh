#!/bin/sh
# v1.3.90 — iOS alternate-app-icon @3x loose-file injection.
#
# WHY THIS EXISTS
# ---------------
# SpringBoard renders ALTERNATE app icons (the ones chosen via
# UIApplication.setAlternateIconName) from the loose PNG files in the app
# bundle that CFBundleAlternateIcons -> CFBundleIconFiles points at — NOT from
# Assets.car. (The PRIMARY icon is the opposite: it renders from Assets.car,
# which is why the primary looks fine at @3x even though it too only ships an
# @2x loose file.)
#
# actool only emits the alternate loose files at @2x
# (AppIcon-<Variant>60x60@2x.png = 120x120) and ~ipad @2x. It never emits the
# @3x loose file. On an @3x device (iPhone Pro / Pro Max) SpringBoard therefore
# has no image to draw for the alternate icon: setAlternateIconName SUCCEEDS
# (the name is valid, UIApplication.alternateIconName updates), an OS alert may
# even appear, but the home-screen icon silently stays on the primary. Confirmed
# on iPhone 16 Pro Max / iOS 26: setIcon -> true, currentIconName(after) ==
# AppIcon-Dark, yet the icon did not change. @2x devices (iPad) are unaffected
# because their @2x loose file exists.
#
# WHAT THIS DOES
# --------------
# For each themed variant, copy the 180x180 @3x PNG into the built bundle under
# the exact name actool's CFBundleIconFiles references:
# AppIcon-<Variant>60x60@3x.png.
#
# CRUCIAL: the source PNGs live in ios/alt_icons_3x/ and are PRE-FLATTENED to
# have NO alpha channel. iOS/SpringBoard silently REJECTS home-screen icons
# that carry an alpha channel — it records the alternate name (so
# setAlternateIconName returns success) but draws nothing, leaving the primary
# icon. The raw .appiconset @3x sources DO have an (all-opaque) alpha channel,
# so we must not copy them directly; actool flattens alpha for the @2x files it
# emits, which is why @2x devices (iPad) worked while the @3x iPhone did not.
# Regenerate ios/alt_icons_3x/ with tools/flatten_alt_icons_3x.py if the
# appiconset art changes.
#
# Runs as a build phase; re-seals the signature below so the injected files are
# covered regardless of phase order. Idempotent; safe to re-run.
set -u

APP="${BUILT_PRODUCTS_DIR}/${CONTENTS_FOLDER_PATH}"
SRC="${SRCROOT}/alt_icons_3x"

for V in Dark Green Orange Pink Purple Red; do
  src="${SRC}/AppIcon-${V}60x60@3x.png"
  dst="${APP}/AppIcon-${V}60x60@3x.png"
  if [ -f "${src}" ]; then
    cp -f "${src}" "${dst}"
    echo "inject_alt_icon_loose_3x: ${V} -> $(basename "${dst}")"
  else
    echo "inject_alt_icon_loose_3x: WARNING missing ${src}" >&2
  fi
done

# Re-seal the signature so the freshly-injected loose files are covered.
# Under Xcode's new build system an output-less Run Script phase is NOT
# ordered before the implicit CodeSign step — it usually runs AFTER it — so
# the files we just added would otherwise be unsigned ("file added" in
# `codesign --verify`) and the app would be rejected / crash on launch.
# This block is order-independent:
#   • if the bundle is ALREADY signed (this phase ran after CodeSign), we
#     re-sign it, preserving the entitlements/flags Xcode applied;
#   • if it is NOT yet signed (this phase ran before CodeSign), we leave it
#     and Xcode's upcoming CodeSign seals the injected files for us.
if [ "${CODE_SIGNING_REQUIRED:-YES}" != "NO" ] && \
   [ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]; then
  if codesign -d "${APP}" >/dev/null 2>&1; then
    codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY}" \
      --preserve-metadata=identifier,entitlements,flags "${APP}"
    echo "inject_alt_icon_loose_3x: re-sealed signature with injected files"
  else
    echo "inject_alt_icon_loose_3x: bundle not yet signed; CodeSign will seal"
  fi
fi
