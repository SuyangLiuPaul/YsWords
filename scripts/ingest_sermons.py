#!/usr/bin/env python3
"""
Ingest Pastor Eric's sermon corpus into Flutter assets.

Reads `~/Downloads/P.Eric Sermon/`:
  - SERMON_INDEX.md  → metadata (topic, id, date, parts, passage, title)
  - <topic>/<id>_*.formatted.txt        → English body (combined parts)
  - <topic>/<id>_*.zh-proofread.txt     → proofread Simplified Chinese
  - <topic>/<id>_*.zh-TW.txt            → Traditional Chinese
  (Falls back to .zh-CN.txt when .zh-proofread.txt is absent.)

Writes:
  assets/sermons/index.json             → array of metadata records
  assets/sermons/en/<id>.txt            → English body, lazy-loaded by app
  assets/sermons/zh-CN/<id>.txt         → Simplified body
  assets/sermons/zh-TW/<id>.txt         → Traditional body

Run from repo root:
    python3 scripts/ingest_sermons.py

Idempotent — re-run after corpus updates. Removes stale outputs.
"""
from __future__ import annotations

import json
import re
import shutil
import sys
from dataclasses import dataclass, asdict
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SOURCE = Path.home() / "Downloads" / "P.Eric Sermon"
OUT = REPO / "assets" / "sermons"
INDEX_MD = SOURCE / "SERMON_INDEX.md"

# Map slugified-on-disk topic folder names back to the canonical topic
# heading from SERMON_INDEX.md. The corpus author replaced apostrophes
# in folder names with underscores ("Pastor Eric_s Testimony"), so the
# folder→heading mapping isn't 1:1.
TOPIC_FOLDER_OVERRIDES = {
    "Pastor Eric's Testimony": "Pastor Eric_s Testimony",
    "Hasten the Lord's coming": "Hasten the Lord_s coming",
    "The Lord's Vision for the Church": "The Lord_s Vision for the Church",
    "Understanding the Truth of God's Word": "Understanding the Truth of God_s Word",
}


@dataclass
class SermonRecord:
    id: str            # canonical sermon id, e.g. "004", "EC010", "397-1"
    topic: str         # topic heading from index
    topicSlug: str     # disk folder name
    date: str          # "1979-04-08" or "yyyy-mmdd" when undated
    parts: str         # "A/B", "A/B/C", "" for single-part
    passage: str       # raw passage hint from index ("Luke 4:5-13"), may be ""
    title: str         # English title from the index (short)
    # Per-language localised titles, extracted from the first
    # markdown H1 line of each body file. The body H1 is the formal
    # sermon title written by the proofreader and is the single best
    # source of a localised title — way better than auto-translating
    # the short English index title. May differ stylistically from
    # `title`: H1 typically includes the part letter ("(Part A)"), a
    # subtitle after an em-dash, and a passage suffix in parens.
    titles: dict[str, str]
    hasEn: bool
    hasZhCn: bool
    hasZhTw: bool


def parse_index(md_path: Path) -> list[SermonRecord]:
    """Walk the markdown index extracting one record per sermon row."""
    text = md_path.read_text(encoding="utf-8")
    records: list[SermonRecord] = []
    current_topic: str | None = None
    for line in text.splitlines():
        if line.startswith("## "):
            current_topic = line[3:].strip()
            continue
        if not line.startswith("| ") or current_topic is None:
            continue
        # Header / divider rows: skip
        if line.startswith("| #") or line.startswith("|--"):
            continue
        cols = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cols) < 6:
            continue
        # Columns: # | ID | Date | Parts | Passage | Title
        _row, sid, date, parts, passage, title = cols[:6]
        if not sid or not sid[0].isdigit() and not sid[0].isalpha():
            continue
        topic_slug = TOPIC_FOLDER_OVERRIDES.get(current_topic, current_topic)
        records.append(SermonRecord(
            id=sid,
            topic=current_topic,
            topicSlug=topic_slug,
            date=date,
            parts=parts,
            passage=passage,
            title=title,
            titles={},
            hasEn=False, hasZhCn=False, hasZhTw=False,
        ))
    return records


def find_body(topic_dir: Path, sid: str, suffix: str) -> Path | None:
    """Find the *combined* (no part letter) body file for a sermon.

    File naming: `<id>_<date>_<passage_slug>_<title_slug>.<suffix>`.
    The combined files have the bare `<id>` (e.g. `004_…`); per-part
    files have a trailing letter (`004a_…`). We want the combined one.
    """
    # Strict: id followed by underscore, no letter.
    pattern = re.compile(rf"^{re.escape(sid)}_.*\.{re.escape(suffix)}$")
    candidates = [p for p in topic_dir.iterdir() if pattern.match(p.name)]
    if candidates:
        return sorted(candidates)[0]
    return None


def find_body_with_fallback(topic_dir: Path, sid: str) -> tuple[Path | None, Path | None, Path | None]:
    """Locate (en, zh-CN, zh-TW) bodies for one sermon.

    Pipeline reminder (from PIPELINE.md):
      Phase 3 produces .zh-CN.txt   (Simplified)
      Phase 4 produces .zh-TW.txt   (Traditional, opencc-converted)
      Phase 5 produces .zh-proofread.txt  (proofread Traditional)

    So .zh-proofread.txt is *Traditional* — using it for the
    Simplified bundle is wrong (and was the cause of the round-49
    bug where 简体 sermons rendered as 繁體). Correct mapping:

      zh-CN  → .zh-CN.txt     (the only Simplified file we have)
      zh-TW  → .zh-proofread.txt preferred, .zh-TW.txt fallback
              (proofread > opencc-auto)
    """
    en = find_body(topic_dir, sid, "formatted.txt")
    zh_cn = find_body(topic_dir, sid, "zh-CN.txt")
    zh_tw = (
        find_body(topic_dir, sid, "zh-proofread.txt")
        or find_body(topic_dir, sid, "zh-TW.txt")
    )
    return en, zh_cn, zh_tw


def normalize_body(text: str) -> str:
    """Trim trailing whitespace per line; collapse 3+ blank lines to 2."""
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = "\n".join(line.rstrip() for line in text.split("\n"))
    text = re.sub(r"\n{3,}", "\n\n", text).strip() + "\n"
    return text


def extract_h1_title(body: str) -> str:
    """Return the first markdown-H1 line ('# ...') stripped of the
    leading hashes, or empty string if no H1 in the first 5 lines."""
    for line in body.split("\n", 5)[:5]:
        line = line.strip()
        if line.startswith("# "):
            return line[2:].strip()
        if line.startswith("#\t"):
            return line[2:].strip()
    return ""


def main() -> int:
    if not INDEX_MD.exists():
        print(f"ERROR: {INDEX_MD} not found", file=sys.stderr)
        return 1

    records = parse_index(INDEX_MD)
    print(f"Index parsed: {len(records)} sermon rows")

    # Wipe output and rebuild from scratch — keeps it idempotent and
    # automatically removes sermons that were dropped from the index.
    if OUT.exists():
        shutil.rmtree(OUT)
    (OUT / "en").mkdir(parents=True)
    (OUT / "zh-CN").mkdir(parents=True)
    (OUT / "zh-TW").mkdir(parents=True)

    bytes_written = {"en": 0, "zh-CN": 0, "zh-TW": 0}
    skipped: list[str] = []

    for rec in records:
        topic_dir = SOURCE / rec.topicSlug
        if not topic_dir.is_dir():
            skipped.append(f"{rec.id}: topic folder missing ({rec.topicSlug})")
            continue
        en, zh_cn, zh_tw = find_body_with_fallback(topic_dir, rec.id)

        if en:
            body = normalize_body(en.read_text(encoding="utf-8"))
            (OUT / "en" / f"{rec.id}.txt").write_text(body, encoding="utf-8")
            bytes_written["en"] += len(body.encode("utf-8"))
            rec.hasEn = True
            t = extract_h1_title(body)
            if t:
                rec.titles["en"] = t
        if zh_cn:
            body = normalize_body(zh_cn.read_text(encoding="utf-8"))
            (OUT / "zh-CN" / f"{rec.id}.txt").write_text(body, encoding="utf-8")
            bytes_written["zh-CN"] += len(body.encode("utf-8"))
            rec.hasZhCn = True
            t = extract_h1_title(body)
            if t:
                rec.titles["zh-CN"] = t
        if zh_tw:
            body = normalize_body(zh_tw.read_text(encoding="utf-8"))
            (OUT / "zh-TW" / f"{rec.id}.txt").write_text(body, encoding="utf-8")
            bytes_written["zh-TW"] += len(body.encode("utf-8"))
            rec.hasZhTw = True
            t = extract_h1_title(body)
            if t:
                rec.titles["zh-TW"] = t
        if not (en or zh_cn or zh_tw):
            skipped.append(f"{rec.id}: no body files found in {rec.topicSlug}")

    # Drop sermons with no content at all from the index.
    kept = [r for r in records if r.hasEn or r.hasZhCn or r.hasZhTw]
    index_path = OUT / "index.json"
    index_path.write_text(
        json.dumps([asdict(r) for r in kept], ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    print(f"\nWrote {len(kept)} sermon records to {index_path.relative_to(REPO)}")
    print(f"  English bodies     : {sum(1 for r in kept if r.hasEn)} files, "
          f"{bytes_written['en'] / 1e6:.1f} MB")
    print(f"  Simplified bodies  : {sum(1 for r in kept if r.hasZhCn)} files, "
          f"{bytes_written['zh-CN'] / 1e6:.1f} MB")
    print(f"  Traditional bodies : {sum(1 for r in kept if r.hasZhTw)} files, "
          f"{bytes_written['zh-TW'] / 1e6:.1f} MB")

    if skipped:
        print(f"\nSkipped {len(skipped)} entries with no matching body files:")
        for s in skipped[:10]:
            print(f"  • {s}")
        if len(skipped) > 10:
            print(f"  • ... and {len(skipped) - 10} more")

    print("\nDone. Remember to add `assets/sermons/` to pubspec.yaml so "
          "the bodies ship with the app.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
