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


def _logo_blue(img: Image.Image) -> tuple[int, int, int]:
    """Return the Bible-cover blue from the source icon.

    Samples a pixel on the front cover, below the white cross, where
    the blue is solid and unbroken. Falls back to a hardcoded
    canonical value if the sample lands on a white edge — e.g. a
    page-cut highlight, the cross itself, or the dove's foot — so
    the marker colour is deterministic across asset edits."""
    w, h = img.size
    sample = img.getpixel((int(w * 0.40), int(h * 0.72)))
    # Sanity: a too-bright sample means we hit white (page edge or
    # cross). Fall back to the Bible-cover blue from the v1 source
    # at assets/app_icon.png.
    if sample[0] + sample[1] + sample[2] > 600:
        return (66, 113, 168)
    return sample


def add_cn_badge(img: Image.Image) -> Image.Image:
    """Stamp a small "CN" watermark in the bottom-right area of the
    icon — in the empty background space below the dove and next to
    the Bible's right edge.

    Position history:
    - v1.2.3: red rounded-rectangle 中 badge top-right (loud, "weird")
    - v1.2.4: subtle 中 watermark top-right (better but still
      visually competing with the dove which lives in that corner)
    - v1.2.5: subtle 中 watermark bottom-right corner (clears the
      dove but hugs the rounded edge of the launcher icon mask)
    - v1.2.6 first cut: "CN" letters at darkened-bg colour, nudged
      inward (clearer than 中 at favicon size, less crowded)
    - v1.2.6 final: same position bumped up another ~6%, colour
      switched from a darkened-bg watermark to the **same blue as
      the Bible cover** — ties the marker visually into the icon's
      foreground palette so it reads as part of the design instead
      of a bolt-on tag.

    The Bible stays blue on every tier variant (only the background
    re-tints to green / amber), so a single colour-sample of the
    cover gives a marker that looks correct on prod / dev / qat
    without per-variant tuning."""
    w, _ = img.size
    img = img.copy()
    draw = ImageDraw.Draw(img)
    marker_color = _logo_blue(img)
    char_px = int(w * 0.12)
    font = _load_cjk_font(char_px)
    bbox = draw.textbbox((0, 0), "CN", font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    # 19% bottom inset (v1.2.5 was 13%) lifts the marker out of the
    # bottom edge zone into the clear background strip immediately
    # below the dove; 11% right inset stays the same so the marker
    # remains right-anchored.
    inset_right = int(w * 0.11)
    inset_bottom = int(w * 0.19)
    tx = w - inset_right - tw - bbox[0]
    ty = w - inset_bottom - th - bbox[1]
    draw.text((tx, ty), "CN", fill=marker_color, font=font)
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
