#!/usr/bin/env python3
"""
Verify every image URL in assets/bible_evidence.json actually loads.
For broken URLs, attempt to extract a stable file name and fall back
to https://commons.wikimedia.org/wiki/Special:FilePath/<name>?width=400
which is hash-stable and immune to thumb-cache invalidation.

If the FilePath rewrite also fails, clear `images: []` and let the UI
render the entry's emoji icon — no generic per-category placeholder.

Idempotent. Run after backfill_evidence_images.py.
"""

import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from typing import Optional

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JSON_PATH = os.path.join(REPO_ROOT, "assets", "bible_evidence.json")

UA = "yswords-image-verifier/1.0 (https://yswords.netlify.app)"

# No category fallbacks — entries with no working real image get
# `images: []` and the UI renders the emoji icon (see `_IconFallback`,
# `_IconHero`, `_ThumbIcon`). A generic Tel Megiddo photo under
# "Nuzi tablets" is more misleading than showing no photo at all.


def fetch_status(url: str, timeout: int = 8) -> int:
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status
    except urllib.error.HTTPError as e:
        return e.code
    except Exception:
        return 0


def extract_filename(thumb_url: str) -> Optional[str]:
    """
    Given a Wikimedia thumb URL like
      https://upload.wikimedia.org/wikipedia/commons/thumb/b/b3/Sphinx_Gate%2C_Hattusa.jpg/330px-Sphinx_Gate%2C_Hattusa.jpg
    extract the canonical file name 'Sphinx_Gate,_Hattusa.jpg'.

    Also handles non-thumb (direct) URLs:
      https://upload.wikimedia.org/wikipedia/commons/3/3d/Foo.jpg
    """
    if "upload.wikimedia.org" not in thumb_url:
        return None
    parts = thumb_url.split("/")
    # /thumb/X/YY/<filename>/<thumb-prefix>-<filename>
    # /commons/X/YY/<filename>
    if "thumb" in parts:
        try:
            i = parts.index("thumb")
            # filename is parts[i + 3]
            name = parts[i + 3]
        except (IndexError, ValueError):
            return None
    else:
        name = parts[-1]
    # URL-decode (%2C -> ,)
    return urllib.parse.unquote(name)


def special_filepath(name: str, width: int = 400) -> str:
    """Build a hash-stable FilePath URL. Spaces / commas are tolerated."""
    return (
        f"https://commons.wikimedia.org/wiki/Special:FilePath/"
        f"{urllib.parse.quote(name)}?width={width}"
    )


def main() -> int:
    with open(JSON_PATH, "r", encoding="utf-8") as f:
        data = json.load(f)

    evs = data["evidences"]
    total = len(evs)
    fixed_filepath = 0
    fixed_fallback = 0
    ok = 0

    print(f"Verifying {total} images")

    for idx, entry in enumerate(evs, 1):
        eid = entry.get("id", f"<idx {idx}>")
        cur = (entry.get("images") or [None])[0]
        if not cur:
            # Already empty — UI will render emoji icon. Skip.
            continue

        code = fetch_status(cur)
        if code == 200:
            ok += 1
            if idx % 25 == 0:
                print(f"[{idx:3d}/{total}] ok  {eid}")
            continue

        # Try Special:FilePath rewrite.
        fname = extract_filename(cur)
        new_url = None
        if fname:
            candidate = special_filepath(fname, 400)
            ccode = fetch_status(candidate)
            if ccode == 200:
                new_url = candidate

        if new_url:
            entry["images"] = [new_url] + (entry.get("images") or [])[1:]
            fixed_filepath += 1
            print(f"[{idx:3d}/{total}] {code} -> filepath  {eid}")
        else:
            # No working URL — clear so the UI renders the icon.
            entry["images"] = []
            fixed_fallback += 1
            print(f"[{idx:3d}/{total}] {code} -> icon  {eid}")

        time.sleep(0.1)

    data["_meta"]["generatedAt"] = datetime.now(timezone.utc).isoformat()

    with open(JSON_PATH, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    print()
    print(f"Done. ok={ok}  filepath_rewrite={fixed_filepath}  icon-only={fixed_fallback}  total={total}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
