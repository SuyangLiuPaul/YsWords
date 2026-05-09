#!/usr/bin/env python3
"""Generate per-site PWA icons + manifest for the 6 YsWords Netlify
deployments so the user can tell each install / browser tab apart at
a glance.

Variants:
    intl-prod  → original icon (no change)
    cn-prod    → original + red 中 badge top-right
    intl-dev   → leaf-green background tint
    cn-dev     → leaf-green + 中 badge
    intl-qat   → warm amber background tint
    cn-qat     → warm amber + 中 badge

Each variant directory contains:
    favicon.png
    icons/Icon-192.png
    icons/Icon-512.png
    icons/Icon-maskable-192.png
    icons/Icon-maskable-512.png
    manifest.json   (with tier-aware `name` / `short_name`)

Run from repo root: `python3 tools/generate_site_icons.py`

The deploy helper (`tools/deploy_site.py`) overlays the variant
directory on top of the base build (`build/web` or `build-cn`)
before pushing to Netlify, so the same Flutter build can be reused
across all three tiers.
"""
from __future__ import annotations

import json
import os
import sys
from PIL import Image, ImageDraw, ImageFont

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(REPO_ROOT, "assets", "app_icon.png")  # 1024×1024 master
OUT_BASE = os.path.join(REPO_ROOT, "tools", "site-icons")

SIZES = [
    ("favicon.png", 192),
    ("icons/Icon-192.png", 192),
    ("icons/Icon-512.png", 512),
    ("icons/Icon-maskable-192.png", 192),
    ("icons/Icon-maskable-512.png", 512),
]

# (flavour, tier, tier_bg_color_or_None, include_cn_badge)
# tier_bg_color_or_None is the new background color for the icon.
# `None` means leave the source icon's background untouched.
VARIANTS = [
    ("intl", "prod", None,                False),
    ("cn",   "prod", None,                True),
    ("intl", "dev",  (175, 220, 165),     False),  # leaf green
    ("cn",   "dev",  (175, 220, 165),     True),
    ("intl", "qat",  (250, 210, 130),     False),  # warm amber
    ("cn",   "qat",  (250, 210, 130),     True),
]

# Maps (flavour, tier) → (manifest.name, manifest.short_name).
# `name` shows on the install splash, `short_name` shows under the
# saved icon on the home screen / in the launcher.
NAMES = {
    ("intl", "prod"): ("YsWords",          "YsWords"),
    ("cn",   "prod"): ("YsWords (中国版)", "YsW·中"),
    ("intl", "dev"):  ("YsWords (DEV)",    "YsW·DEV"),
    ("cn",   "dev"):  ("YsWords 中国版 DEV", "YsW·中·DEV"),
    ("intl", "qat"):  ("YsWords (QAT)",    "YsW·QAT"),
    ("cn",   "qat"):  ("YsWords 中国版 QAT", "YsW·中·QAT"),
}


def detect_bg_color(img: Image.Image) -> tuple[int, int, int]:
    """Sample 4 corner pixels and average them — gives the icon
    background colour without hardcoding a specific shade."""
    w, h = img.size
    corners = [
        img.getpixel((5, 5)),
        img.getpixel((w - 5, 5)),
        img.getpixel((5, h - 5)),
        img.getpixel((w - 5, h - 5)),
    ]
    r = sum(c[0] for c in corners) // 4
    g = sum(c[1] for c in corners) // 4
    b = sum(c[2] for c in corners) // 4
    return (r, g, b)


def replace_background(img: Image.Image, target_color: tuple[int, int, int],
                       tolerance: int = 35) -> Image.Image:
    """Replace pixels close to the auto-detected background colour
    with `target_color`. Foreground (Bible spine, dove, cross) is
    untouched because it uses very different RGB values."""
    bg = detect_bg_color(img)
    img = img.convert("RGB").copy()
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            p = px[x, y]
            if (abs(p[0] - bg[0]) <= tolerance
                    and abs(p[1] - bg[1]) <= tolerance
                    and abs(p[2] - bg[2]) <= tolerance):
                px[x, y] = target_color
    return img


def _load_cjk_font(size: int) -> ImageFont.ImageFont:
    """Find a system-installed CJK font on macOS so the 中 character
    actually renders. Falls back to PIL's default bitmap font if no
    CJK font is available (the badge will still render, just with a
    less elegant shape)."""
    candidates = [
        "/System/Library/Fonts/PingFang.ttc",
        "/System/Library/Fonts/STHeiti Medium.ttc",
        "/System/Library/Fonts/Hiragino Sans GB.ttc",
        "/Library/Fonts/Arial Unicode.ttf",
        "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
    ]
    for path in candidates:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                continue
    return ImageFont.load_default()


def add_cn_badge(img: Image.Image) -> Image.Image:
    """Stamp a small subtle 中 watermark in the top-right corner.

    2026-05-09 (v1.2.4): user said the previous red rounded-rectangle
    badge was "weird" — it dominated the composition and clashed with
    the rest of the icon's blue/green/amber palette. Replaced with a
    much smaller character (~14% of icon width vs 28%) drawn in the
    *same colour family as the background* — specifically the bg
    detected from the four corners darkened 28% so it reads as a
    quiet shadow / watermark rather than an alert badge. No box, no
    outline, no contrasting fill. You have to look for it, but it's
    there for the moments when you need to tell intl from cn."""
    w, _ = img.size
    img = img.copy()
    draw = ImageDraw.Draw(img)
    bg = detect_bg_color(img)
    # Same colour family as the bg, just darker — keeps the marker
    # tonally consistent with whatever tier-tint the rest of the icon
    # is using (light blue prod, leaf green dev, warm amber qat).
    marker_color = (
        max(0, int(bg[0] * 0.72)),
        max(0, int(bg[1] * 0.72)),
        max(0, int(bg[2] * 0.72)),
    )
    char_px = int(w * 0.14)
    font = _load_cjk_font(char_px)
    bbox = draw.textbbox((0, 0), "中", font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    inset = int(w * 0.04)
    tx = w - inset - tw - bbox[0]
    ty = inset - bbox[1]
    draw.text((tx, ty), "中", fill=marker_color, font=font)
    return img


def build_manifest(name: str, short_name: str) -> dict:
    """Mirror the shape of `web/manifest.json` and only swap the
    name / short_name fields. Keeps theme_color, icon list, and
    everything else identical so the deploy diff is minimal."""
    return {
        "name": name,
        "short_name": short_name,
        "start_url": "/",
        "display": "standalone",
        "background_color": "#ffffff",
        "theme_color": "#2196F3",
        "description": (
            "YsWords means Yahweh's words. A bilingual Bible app to help "
            "you listen to His voice and abide in Him daily."
        ),
        "orientation": "portrait-primary",
        "prefer_related_applications": False,
        "icons": [
            {"src": "icons/Icon-192.png", "sizes": "192x192", "type": "image/png"},
            {"src": "icons/Icon-512.png", "sizes": "512x512", "type": "image/png"},
            {"src": "icons/Icon-maskable-192.png", "sizes": "192x192",
             "type": "image/png", "purpose": "maskable"},
            {"src": "icons/Icon-maskable-512.png", "sizes": "512x512",
             "type": "image/png", "purpose": "maskable"},
        ],
    }


def main() -> int:
    if not os.path.exists(SRC):
        print(f"ERROR: source icon not found: {SRC}", file=sys.stderr)
        return 1
    src = Image.open(SRC).convert("RGB")
    print(f"Source: {SRC} ({src.size[0]}×{src.size[1]})")

    for flavour, tier, bg_color, cn in VARIANTS:
        variant = f"{flavour}-{tier}"
        out_dir = os.path.join(OUT_BASE, variant)
        os.makedirs(os.path.join(out_dir, "icons"), exist_ok=True)

        img = src
        if bg_color is not None:
            img = replace_background(src, bg_color)
        if cn:
            img = add_cn_badge(img)

        for filename, size in SIZES:
            resized = img.resize((size, size), Image.LANCZOS)
            resized.save(os.path.join(out_dir, filename), optimize=True)

        full_name, short_name = NAMES[(flavour, tier)]
        with open(os.path.join(out_dir, "manifest.json"), "w",
                  encoding="utf-8") as f:
            json.dump(build_manifest(full_name, short_name),
                      f, indent=4, ensure_ascii=False)
            f.write("\n")

        print(f"  generated {variant}/  ({full_name})")

    print()
    print(f"All variants written under {OUT_BASE}")
    print("Next: tools/deploy_site.py <site-name>")
    return 0


if __name__ == "__main__":
    sys.exit(main())
