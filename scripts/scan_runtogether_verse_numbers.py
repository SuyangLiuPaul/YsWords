#!/usr/bin/env python3
"""Count Chinese numeral runs before 節/节 that `cn_number()` cannot
parse — the "run-together verse pair" shape (e.g. 十六十七 = 16 then 17
with no separator). Read-only: reports, never edits `refs.json`.

Used to measure `docs/autonomous-queue.md`'s "「第十六十七节」" item —
see that entry for the corpus-wide result and why no splitter shipped.
"""

import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from extract_sermon_refs import cn_number, _CN_NUM_RE  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent / "assets" / "sermons"
RUN_RE = re.compile(rf"({_CN_NUM_RE})[節节]")


def scan():
    hits = []
    for lang in ("en", "zh-CN", "zh-TW"):
        for f in sorted((ROOT / lang).glob("*.txt")):
            text = f.read_text(encoding="utf-8")
            for m in RUN_RE.finditer(text):
                run = m.group(1)
                if cn_number(run) is None:
                    start, end = max(0, m.start() - 20), min(len(text), m.end() + 10)
                    ctx = text[start:end].replace("\n", " ")
                    hits.append((str(f.relative_to(ROOT.parent.parent)), run, ctx))
    return hits


if __name__ == "__main__":
    hits = scan()
    print(f"total hits (cn_number rejects): {len(hits)}")
    print(f"distinct runs: {sorted(set(h[1] for h in hits))}")
    for h in hits:
        print(h)
