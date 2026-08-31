#!/usr/bin/env python3
"""Render `web/og-card.png`, the 1200x630 image every share of the site
shows — WeChat, WhatsApp, Facebook, Twitter/X, iMessage, Slack.

    python3 tools/make_og_card.py

Why a script and not a one-off export: the card carries the app name,
the tagline and the domain, and all three have already changed once (the
printed name pair was dropped on 2026-08-30; the site moved to
yahwehword.com). Regenerating has to be a one-liner, or the card
silently goes stale and every share advertises the old name.

Composition notes, so a later edit does not undo them by accident:
  * The logo is COMPOSITED, not redrawn. It already carries the rounded
    light-blue plate; redrawing it in code would fork the brand.
  * Text sits in the right two-thirds. Several platforms crop a 1.91:1
    card toward the centre on small previews, so nothing load-bearing
    goes within 40 px of an edge.
  * The font is Hiragino Sans GB (falling back to STHeiti): one family
    that covers Latin AND both Chinese scripts, so the Latin and the
    Chinese lines share a weight instead of visibly disagreeing the way
    Helvetica-plus-a-CJK-fallback does.
  * ONE name, not the pair. The user's rule (2026-08-30, restated
    2026-08-31): English is "Yahweh's Words", Chinese is 雅伟之言, and
    the two are never printed side by side. In the app that is easy —
    it reads the reader's own language. A share card cannot: WeChat,
    WhatsApp and every other unfurler read the raw HTML WITHOUT running
    JavaScript, so there is exactly one card for every reader and it has
    to pick. It picks English, matching the domain and the static
    <title> that link previews already fall back to. The Chinese carries
    the DESCRIPTION lines instead, so the card is still bilingual
    without ever stacking the two names.
    To flip the card to Chinese: swap `name` to 雅伟之言 below and swap
    og:title / og:image:alt in web/index.html to match. Change both or
    the picture and the text disagree.
"""

import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOGO = os.path.join(ROOT, 'web', 'logo', 'logo-512.png')
OUT = os.path.join(ROOT, 'web', 'og-card.png')

W, H = 1200, 630

# Sampled from web/logo/logo-512.png so the card cannot drift from the
# icon: the plate blue, the book blue, and a near-white for the surface.
BG_TOP = (250, 253, 255)
BG_BOTTOM = (226, 240, 250)
INK = (30, 66, 100)
INK_SOFT = (74, 116, 154)
RULE = (168, 205, 231)

# One family for Latin + Simplified + Traditional. Ordered by
# preference; the first that exists wins.
FONT_CANDIDATES = [
    '/System/Library/Fonts/Hiragino Sans GB.ttc',
    '/System/Library/Fonts/STHeiti Medium.ttc',
    '/System/Library/Fonts/Supplemental/Songti.ttc',
]


def _font_path():
    for p in FONT_CANDIDATES:
        if os.path.exists(p):
            return p
    return None


def _font(path, size, index=0):
    if path is None:
        return ImageFont.load_default()
    try:
        return ImageFont.truetype(path, size, index=index)
    except OSError:
        return ImageFont.truetype(path, size)


def main():
    if not os.path.exists(LOGO):
        sys.exit('FATAL: %s is missing — the card is built from the real '
                 'logo, not a redraw.' % LOGO)

    path = _font_path()
    if path is None:
        print('WARNING: no CJK font found; the Chinese lines will render '
              'as boxes. Install one or run this on macOS.', file=sys.stderr)

    card = Image.new('RGB', (W, H), BG_TOP)
    draw = ImageDraw.Draw(card)

    # Vertical wash, top-light. Flat colour looked like a placeholder at
    # thumbnail size; a wash reads as deliberate.
    for y in range(H):
        t = y / (H - 1)
        draw.line(
            [(0, y), (W, y)],
            fill=tuple(
                int(BG_TOP[i] + (BG_BOTTOM[i] - BG_TOP[i]) * t)
                for i in range(3)
            ),
        )

    # ── logo, left third ────────────────────────────────────────────
    logo = Image.open(LOGO).convert('RGBA')
    side = 300
    logo = logo.resize((side, side), Image.LANCZOS)
    lx, ly = 96, (H - side) // 2
    card.paste(logo, (lx, ly), logo)

    # ── text, right two-thirds ──────────────────────────────────────
    x = lx + side + 72
    # Nothing load-bearing within 48 px of the right edge.
    avail = W - x - 48

    # Measured, not guessed: the two name lines have different heights in
    # every family, so stacking by a constant leaves a visible gap on one
    # of them.
    def height(text, font):
        box = draw.textbbox((0, 0), text, font=font)
        return box[3] - box[1]

    def width(text, font):
        box = draw.textbbox((0, 0), text, font=font)
        return box[2] - box[0]

    def fitted(text, start, floor=18):
        """Largest size at or below `start` that keeps `text` inside the
        safe area. The first version of this card shipped a hardcoded
        size and the English tagline ran off the right edge — every
        share showed "…Greek & Hebre". Measuring removes the whole
        class of mistake, including for a future longer tagline."""
        size = start
        while size > floor:
            f = _font(path, size)
            if width(text, f) <= avail:
                return f
            size -= 1
        f = _font(path, floor)
        if width(text, f) > avail:
            print('WARNING: %r does not fit even at %dpx — shorten it.'
                  % (text, floor), file=sys.stderr)
        return f

    name = "Yahweh's Words"
    # "7 versions", NOT "7 translations" — the user's call, 2026-08-31:
    # 「不然以为7个语言」. Both numbers are defensible and they mean
    # different things, so the word has to be the careful one:
    #   * 7 是版本条目数 — what the version picker actually offers.
    #   * 5 是不同译本数 — 和合本雅伟版 and 梁家铿译本 are each shipped
    #     in 简体 and 繁體, the same translation converted script-wise
    #     (scripts/fix_traditional_conversion.py and the
    #     repair_tr_*_glyph.py family), not two separate works.
    # "translations" reads as "seven LANGUAGES", which would be a real
    # overclaim; "versions" is both true and the standard word in Bible
    # software (the V in KJV; 中文界面叫版本).
    # test/seo_meta_test.dart derives the 7 from
    # lib/constants/bible_versions.dart and fails if this line drifts.
    tag_en = 'Bilingual Bible · 7 versions · original languages'
    tag_zh = '双语圣经 · 和合本雅伟版 · 原文对照与释经注'
    domain = 'yahwehword.com'

    f_name = fitted(name, 82)
    f_tag = fitted(tag_en, 32)
    f_tag_zh = fitted(tag_zh, 32)
    f_domain = fitted(domain, 27)

    block = (height(name, f_name) + 44
             + height(tag_en, f_tag) + 16 + height(tag_zh, f_tag_zh)
             + 36 + height(domain, f_domain))
    y = (H - block) // 2

    draw.text((x, y), name, font=f_name, fill=INK)
    y += height(name, f_name) + 44

    draw.line([(x, y - 22), (x + 96, y - 22)], fill=RULE, width=3)

    draw.text((x, y), tag_en, font=f_tag, fill=INK_SOFT)
    y += height(tag_en, f_tag) + 16
    draw.text((x, y), tag_zh, font=f_tag_zh, fill=INK_SOFT)
    y += height(tag_zh, f_tag_zh) + 36

    draw.text((x, y), domain, font=f_domain, fill=RULE)

    card.save(OUT, 'PNG', optimize=True)
    kb = os.path.getsize(OUT) / 1024
    print('wrote %s (%dx%d, %.0f KB)' % (OUT, W, H, kb))
    if kb > 300:
        print('NOTE: over 300 KB. WeChat and some link unfurlers skip '
              'large images — consider re-encoding.', file=sys.stderr)


if __name__ == '__main__':
    main()
