#!/usr/bin/env bash
# 2026-05-24 (v1.3.31): generate the bundled Noto Sans CJK SC subset
# at assets/fonts/NotoSansSC-YsWords.otf.
#
# WHY: Flutter web's CanvasKit renderer can only fall back to fonts
# that are registered in its Skia font registry. CSS font names like
# `PingFang SC` or `Microsoft YaHei` are invisible to CanvasKit, so
# without a bundled CJK font, rare characters (`赒` U+8D52 in Acts
# 10:2 CUVS-YHWH, `䍁` U+4341, the Ext-B char `𨱔` U+28C54, etc.)
# render as "X" tofu glyphs. This script subsets the official Noto
# Sans CJK SC Regular (SIL OFL, freely redistributable) down to JUST
# the characters that appear anywhere in the app — Bible text, UI
# strings, lexicons, sermons — and bundles the result.
#
# Resulting subset is ~1.88 MB OTF (down from 16 MB full font),
# bundled via `fonts:` in pubspec.yaml with family name
# `NotoSansSC-YsWords`, and registered as the FIRST entry in
# `kCjkFontFallback` (lib/utils/font_catalog.dart).
#
# When to re-run:
#   * After adding a Bible version with new CJK characters
#   * After expanding section_titles / book_introductions / sermons
#   * After UI text adds new CJK glyphs
#   * After updating to a new Noto Sans CJK SC release
#
# Requirements:
#   pip install fonttools brotli zopfli  # or: brew install fonttools
#
# Usage:
#   tools/build_cjk_font_subset.sh

set -euo pipefail

PROJECT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap "rm -rf $WORK" EXIT

NOTO_URL='https://github.com/notofonts/noto-cjk/raw/main/Sans/OTF/SimplifiedChinese/NotoSansCJKsc-Regular.otf'

cd "$WORK"

echo "==> 1/4 Extracting charset from app data"
python3 << 'PY' > charset.txt
import os, glob, sys
chars = set()
roots = [
  '/Users/pliu0036/Documents/yswords/assets',
  '/Users/pliu0036/Documents/yswords/lib',
]
for root in roots:
  for ext in ('json', 'dart', 'txt', 'md'):
    for f in glob.glob(f'{root}/**/*.{ext}', recursive=True):
      try:
        with open(f, encoding='utf-8') as fh:
          chars.update(fh.read())
      except Exception: pass
keep = set()
keep.update(chr(i) for i in range(0x20, 0x7F))
keep.update(chr(i) for i in range(0xA0, 0x100))
keep.update(chr(i) for i in range(0x2000, 0x206F))
keep.update(chr(i) for i in range(0x3000, 0x303F))
keep.update(chr(i) for i in range(0xFF00, 0xFFF0))
keep.update(c for c in chars
            if 0x3400 <= ord(c) <= 0x9FFF
            or 0x20000 <= ord(c) <= 0x2FA1F)
print(f'  unique chars: {len(chars):,}', file=sys.stderr)
print(f'  subset chars: {len(keep):,}', file=sys.stderr)
print('\n'.join(sorted(keep)), end='')
PY

echo "==> 2/4 Downloading Noto Sans CJK SC source"
curl -sL -o noto.otf "$NOTO_URL"
size=$(stat -f%z noto.otf 2>/dev/null || stat -c%s noto.otf)
echo "  $((size/1024/1024)) MB source font"

echo "==> 3/4 Running pyftsubset"
pyftsubset noto.otf \
  --text-file=charset.txt \
  --output-file=NotoSansSC-YsWords.otf \
  --no-hinting \
  --no-recommended-glyphs \
  --layout-features='*'
subsize=$(stat -f%z NotoSansSC-YsWords.otf 2>/dev/null || stat -c%s NotoSansSC-YsWords.otf)
echo "  subset: $((subsize/1024)) KB"

echo "==> 4/4 Installing into assets/fonts/"
mkdir -p "$PROJECT/assets/fonts"
cp NotoSansSC-YsWords.otf "$PROJECT/assets/fonts/NotoSansSC-YsWords.otf"
ls -la "$PROJECT/assets/fonts/NotoSansSC-YsWords.otf"

echo
echo "✓ Done. Re-run flutter build to bundle the new subset."
