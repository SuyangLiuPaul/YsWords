#!/usr/bin/env python3
"""
Backfill real Wikipedia thumbnail URLs into assets/bible_evidence.json.

The original React project (now sunset) generated plausible-looking but
INVALID Wikimedia URLs — they all 400. This script replaces them with
real thumbnails fetched from the Wikipedia REST API.

Strategy per entry:
  1. Try the English title verbatim against /page/summary/<title>.
  2. If 404 / no thumbnail, try a few transformed candidates (the id, or
     a stripped title without parentheticals).
  3. If still nothing, leave `images: []` and let the UI render the
     entry's emoji icon — better than a generic per-category photo that
     would mislead users into thinking the entry has a specific image.

Run with:
    cd <repo root>
    python3 scripts/backfill_evidence_images.py

Idempotent: re-running won't overwrite a URL that already returns 2xx.
"""

import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request
from typing import Optional, List

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
JSON_PATH = os.path.join(REPO_ROOT, "assets", "bible_evidence.json")

UA = "yswords-image-backfill/1.0 (https://yswords.netlify.app)"
SUMMARY_API = "https://en.wikipedia.org/api/rest_v1/page/summary/{}"
SEARCH_API = (
    "https://en.wikipedia.org/w/api.php?"
    "action=query&list=search&format=json&srlimit=3&srsearch={}"
)

# No category fallbacks — entries that we can't find a real image for
# render their emoji icon (handled in the Flutter widgets:
# _IconFallback / _IconHero / _ThumbIcon). A generic Tel Megiddo photo
# under "Nuzi tablets" is more misleading than showing no photo.


def http_get(url: str, timeout: int = 8) -> Optional[bytes]:
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            if r.status == 200:
                return r.read()
    except Exception:
        return None
    return None


def head_ok(url: str, timeout: int = 6) -> bool:
    """Return True iff GET (cheaper than HEAD on Wikimedia) yields 2xx."""
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return 200 <= r.status < 300
    except Exception:
        return False


def fetch_summary_thumb(title: str) -> Optional[str]:
    """Hit /page/summary/<title>. Return thumbnail.source if present."""
    if not title:
        return None
    url = SUMMARY_API.format(urllib.parse.quote(title.replace(" ", "_")))
    body = http_get(url)
    if not body:
        return None
    try:
        data = json.loads(body)
    except Exception:
        return None
    thumb = data.get("thumbnail") or {}
    src = thumb.get("source")
    # We prefer originalimage when the thumb is suspiciously tiny.
    if src and "width" in thumb and thumb["width"] < 200:
        orig = (data.get("originalimage") or {}).get("source")
        if orig:
            return orig
    return src


def search_titles(query: str) -> List[str]:
    """Use Wikipedia search to get candidate titles."""
    url = SEARCH_API.format(urllib.parse.quote(query))
    body = http_get(url)
    if not body:
        return []
    try:
        data = json.loads(body)
    except Exception:
        return []
    return [
        hit.get("title", "")
        for hit in (data.get("query", {}).get("search") or [])
        if hit.get("title")
    ]


def candidate_titles(entry: dict) -> List[str]:
    """Generate ordered candidate Wikipedia titles for an entry."""
    en_title = (entry.get("title") or {}).get("en") or ""
    cands: List[str] = []

    if en_title:
        cands.append(en_title)
        # Strip trailing parentheticals: "Tel Dan Stele (Aramaic)" -> "Tel Dan Stele".
        stripped = re.sub(r"\s*\([^)]*\)\s*$", "", en_title).strip()
        if stripped and stripped != en_title:
            cands.append(stripped)

    # Try id with underscores -> spaces, title-cased.
    eid = entry.get("id") or ""
    if eid:
        from_id = eid.replace("_", " ").replace("-", " ").strip().title()
        if from_id and from_id not in cands:
            cands.append(from_id)

    return cands


def find_real_image(entry: dict) -> Optional[str]:
    """Try direct title, then search-then-summary, then None."""
    for cand in candidate_titles(entry):
        thumb = fetch_summary_thumb(cand)
        if thumb:
            return thumb

    # Fallback: search and try the first 3 hits.
    en_title = (entry.get("title") or {}).get("en") or entry.get("id") or ""
    if en_title:
        for hit_title in search_titles(en_title):
            thumb = fetch_summary_thumb(hit_title)
            if thumb:
                return thumb

    return None


def main() -> int:
    with open(JSON_PATH, "r", encoding="utf-8") as f:
        data = json.load(f)

    evs = data["evidences"]
    total = len(evs)
    updated = 0
    fallback = 0
    kept = 0

    print(f"Auditing {total} entries from {JSON_PATH}")

    for idx, entry in enumerate(evs, 1):
        eid = entry.get("id", f"<idx {idx}>")
        existing = entry.get("images") or []

        # If the existing first URL still resolves, keep it (idempotent).
        if existing and head_ok(existing[0]):
            kept += 1
            print(f"[{idx:3d}/{total}] keep    {eid}")
            time.sleep(0.05)
            continue

        new_url = find_real_image(entry)
        if new_url:
            entry["images"] = [new_url] + existing[1:]
            updated += 1
            print(f"[{idx:3d}/{total}] update  {eid} -> {new_url[:90]}")
        else:
            # No real image found — clear so the UI renders the icon.
            entry["images"] = []
            fallback += 1
            print(f"[{idx:3d}/{total}] icon    {eid} (no real match — will render emoji)")

        # Be polite to Wikipedia API.
        time.sleep(0.25)

    # Refresh meta.
    from datetime import datetime, timezone
    data["_meta"]["generatedAt"] = datetime.now(timezone.utc).isoformat()

    with open(JSON_PATH, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    print()
    print(f"Done. updated={updated}  icon-only={fallback}  kept={kept}  total={total}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
