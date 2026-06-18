#!/usr/bin/env python3
"""Regenerate ios/alt_icons_3x/ — alpha-flattened @3x alternate app icons.

WHY
---
iOS / SpringBoard silently rejects home-screen icons that carry an alpha
channel (it records the alternate-icon name so setAlternateIconName returns
success, but draws nothing — the icon never visibly changes). actool flattens
alpha for the @2x loose files it emits, but it never emits the @3x loose files
that @3x devices (iPhone Pro / Pro Max) need for ALTERNATE icons. The raw
.appiconset @3x sources DO have an (all-opaque) alpha channel, so they cannot
be used directly.

This script reads each variant's @3x source from the asset catalog, flattens
the alpha (lossless when the art is fully opaque, otherwise composited onto
white), and writes ios/alt_icons_3x/AppIcon-<Variant>60x60@3x.png — the exact
filename the build phase (ios/inject_alt_icon_loose_3x.sh) copies into the
bundle. Re-run this whenever the appiconset art changes.

Usage:  python3 tools/flatten_alt_icons_3x.py
"""
import os
from PIL import Image

VARIANTS = ["Dark", "Green", "Orange", "Pink", "Purple", "Red"]
SRC_BASE = "ios/Runner/Assets.xcassets"
OUT_BASE = "ios/alt_icons_3x"


def main() -> None:
    os.makedirs(OUT_BASE, exist_ok=True)
    for v in VARIANTS:
        src = f"{SRC_BASE}/AppIcon-{v}.appiconset/AppIcon-{v}@3x.png"
        im = Image.open(src)
        if im.mode in ("RGBA", "LA") or (im.mode == "P" and "transparency" in im.info):
            rgba = im.convert("RGBA")
            amin, _ = rgba.getchannel("A").getextrema()
            if amin == 255:
                flat = rgba.convert("RGB")  # fully opaque → lossless drop
            else:
                bg = Image.new("RGB", rgba.size, (255, 255, 255))
                bg.paste(rgba, mask=rgba.getchannel("A"))
                flat = bg
        else:
            flat = im.convert("RGB")
        out = f"{OUT_BASE}/AppIcon-{v}60x60@3x.png"
        flat.save(out, format="PNG")
        print(f"wrote {out} ({flat.size[0]}x{flat.size[1]}, no alpha)")


if __name__ == "__main__":
    main()
