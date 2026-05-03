#!/usr/bin/env python3
"""
Generate Traditional-Chinese variants of every Strong's entry's
glossZh and defZh fields, in-place in the lexicon JSONs.

Pipeline:
  assets/strongs/{greek,hebrew}.json
    glossZh / defZh   (Simplified, from CBOL)
        │
        │ opencc -c s2t.json  (line-by-line, preserves all formatting,
        │                      Bible-reference markers like "#约 13:1"
        │                      and Strong's numbers, etc.)
        ▼
    glossZhTw / defZhTw  (Traditional)
        │
        ▼  re-serialised JSON, written back to the same file

Run from repo root:
    python3 scripts/build_strongs_traditional.py

Idempotent — re-running rebuilds glossZhTw/defZhTw from the latest
glossZh/defZh, overwriting any prior conversion. Skips entries that
have no Simplified data (about a dozen out of 14000+).
"""
from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
TARGETS = [
    REPO / "assets" / "strongs" / "greek.json",
    REPO / "assets" / "strongs" / "hebrew.json",
]


def have_opencc() -> bool:
    return shutil.which("opencc") is not None


def s2t_batch(strings: list[str]) -> list[str]:
    """Run all strings through `opencc -c s2t.json` in a single
    subprocess. We feed them separated by an unlikely 4-byte sentinel
    so we can split the result back out without invoking opencc once
    per string (which would be ~14000 process spawns).
    """
    # Plain ASCII sentinel — null bytes get stripped by opencc, and
    # we want a string that opencc won't transform (no Han chars).
    sentinel = "\n@@@YSWORDS_S2T_RECORD_BREAK@@@\n"
    payload = sentinel.join(strings)
    result = subprocess.run(
        ["opencc", "-c", "s2t.json"],
        input=payload,
        capture_output=True,
        text=True,
        check=True,
    )
    out = result.stdout.split(sentinel)
    if len(out) != len(strings):
        raise RuntimeError(
            f"opencc batch length mismatch: in={len(strings)} out={len(out)}")
    return out


def process(path: Path) -> tuple[int, int]:
    """Returns (entries_with_glossZhTw, entries_with_defZhTw)."""
    data = json.loads(path.read_text(encoding="utf-8"))
    keys = list(data.keys())

    # Collect all strings in two parallel arrays so we make exactly
    # two opencc calls — one for glosses, one for definitions.
    gloss_inputs: list[str] = []
    gloss_keys: list[str] = []
    def_inputs: list[str] = []
    def_keys: list[str] = []
    for k in keys:
        v = data[k]
        gz = v.get("glossZh")
        if isinstance(gz, str) and gz.strip():
            gloss_inputs.append(gz)
            gloss_keys.append(k)
        dz = v.get("defZh")
        if isinstance(dz, str) and dz.strip():
            def_inputs.append(dz)
            def_keys.append(k)

    print(f"  {path.name}: {len(keys)} entries — converting "
          f"{len(gloss_inputs)} glosses + {len(def_inputs)} defs")

    gloss_outputs = s2t_batch(gloss_inputs) if gloss_inputs else []
    def_outputs = s2t_batch(def_inputs) if def_inputs else []

    for k, tw in zip(gloss_keys, gloss_outputs):
        data[k]["glossZhTw"] = tw
    for k, tw in zip(def_keys, def_outputs):
        data[k]["defZhTw"] = tw

    # Pretty-print so diffs stay reviewable; UTF-8 raw so Chinese
    # chars don't get \u-escaped.
    path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return len(gloss_outputs), len(def_outputs)


def main() -> int:
    if not have_opencc():
        print("ERROR: `opencc` CLI not found. Install with:", file=sys.stderr)
        print("  brew install opencc", file=sys.stderr)
        return 1
    total_g = 0
    total_d = 0
    for path in TARGETS:
        if not path.exists():
            print(f"WARN: missing {path}, skipping")
            continue
        g, d = process(path)
        total_g += g
        total_d += d
    print(f"\nDone. Wrote glossZhTw to {total_g} entries, "
          f"defZhTw to {total_d} entries.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
