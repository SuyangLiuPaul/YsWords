#!/usr/bin/env python3
"""Render the traditional-conversion repair as a reviewable HTML page.

Reads the same RULES that fix_traditional_conversion.py applies, so the page
can never drift from what the script would actually write.
"""
from __future__ import annotations

import html
import importlib.util
import json
import re
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location(
    "fx", ROOT / "tools" / "fix_traditional_conversion.py")
fx = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fx)

WIN = 16          # context characters either side


def collect() -> tuple[list[dict], Counter, Counter]:
    rows, per_class, per_book = [], Counter(), Counter()
    for rel in fx.TARGETS:
        path = ROOT / rel
        if not path.exists():
            continue
        for v in json.loads(path.read_text(encoding="utf-8")):
            text = v["text"]
            cur = text
            # Re-apply rule by rule so each hit keeps its own position.
            for label, pat, rep in fx.RULES:
                while True:
                    m = pat.search(cur)
                    if not m:
                        break
                    i = m.start()
                    before = cur[max(0, i - WIN):i]
                    after = cur[m.end():m.end() + WIN]
                    rows.append({
                        "file": rel.split("/")[-1].replace("-tr.json", ""),
                        "ref": f"{v.get('book')} {v.get('chapter')}:{v.get('verse')}",
                        "cls": label,
                        "pre": before, "old": m.group(), "new": rep, "post": after,
                    })
                    per_class[label] += 1
                    per_book[v.get("book")] += 1
                    cur = cur[:i] + rep + cur[m.end():]
    return rows, per_class, per_book


def esc(s: str) -> str:
    return html.escape(s, quote=True)


def main() -> None:
    rows, per_class, per_book = collect()
    by_cls: dict[str, list[dict]] = defaultdict(list)
    for r in rows:
        by_cls[r["cls"]].append(r)

    # Why each rule is shaped the way it is — the reviewer's real question.
    NOTES = {
        "只 → 隻 (量詞)": "數詞之後的「只」是量詞。「只是／只要／不只」是副詞，不動。",
        "只 → 隻 (船隻/每隻)": "「船只」「每只要獻」都是量詞；此處不設「要」的例外，否則民 28:21 會漏改。",
        "只 → 隻 (那隻/這隻)": "「那只是…」「這只是…」是副詞，已排除。",
        "凈 → 淨": "全書 519 處逐一看過，全部是「潔淨」義，無competing用法。",
        "墻 → 牆": "234 處全部是城牆／牆垣。",
        "余 → 餘": "230 處全部是「其餘／餘剩／有餘」，無姓氏「余」、無第一人稱「余」。",
        "谷 → 穀": "只改穀物義（五穀、踹穀）。山谷、以拉谷、音谷等地名一律不動。",
        "幹 → 乾 (乾燥)": "乾地、乾渴、乾草、枯乾、擦乾、燒乾等。",
        "幹 → 干 (干犯/干預/干戈)": "干犯、干預、干戈、不干己、無干。",
        "松 → 鬆 (放鬆，非松樹)": "放鬆、鬆手、鬆開、輕鬆。松樹、松木、松香、杜松不動。",
        "發 → 髮 (頭髮)": "原檔案完全沒有「髮」字 — 轉換器從未產生過它。只改頭髮／白髮／毛髮／髮綹。",
        "采 → 採 (採集)": "採集義。",
        "腌 → 醃": "鹽醃。",
        "镕 → 鎔": "純簡體殘留，繁體無此字。",
        "鸮 → 鴞": "純簡體殘留。", "飖 → 颻": "純簡體殘留。",
        "珰 → 璫": "純簡體殘留。", "鹯 → 鸇": "純簡體殘留。",
    }

    KEPT = [
        ("亞幹・亞多尼幹・隱幹寧・斯利幹・約幹・雅幹・瑪拉幹・米母幹", "人名地名，一律不動"),
        ("座和幹（出 25:31）", "燈臺的立柱，本就是「幹」"),
        ("枝幹（結 19:11）", "樹的枝幹"),
        ("才幹（太 25:15）・若幹（可 12:41）", "本就是「幹」"),
        ("松樹・松木・松香・杜松", "松科植物，不是「鬆」"),
        ("山谷・以拉谷・音谷・鹽谷", "地形與地名，不是「穀」"),
        ("仆倒（74 處）", "仆倒本就作「仆」"),
        ("王后・太后（45 處）", "后妃之「后」，不是「後」"),
        ("占卜（26 處）・出征（5 處）", "本就作「占」「征」"),
        ("裏（4714 處）・「」（6528 處）・藉（199 處）", "和合本繁體的既有體例，opencc 會改壞，故保留"),
    ]

    def rows_html(items: list[dict]) -> str:
        out = []
        for r in items:
            out.append(
                f'<tr><td class="ref">{esc(r["ref"])}</td>'
                f'<td class="ctx">{esc(r["pre"])}<del>{esc(r["old"])}</del>{esc(r["post"])}</td>'
                f'<td class="ctx">{esc(r["pre"])}<ins>{esc(r["new"])}</ins>{esc(r["post"])}</td></tr>')
        return "".join(out)

    sections = []
    for label, items in sorted(by_cls.items(), key=lambda kv: -len(kv[1])):
        old, new = label.split(" → ")[0], label.split(" → ")[1].split(" ")[0]
        sections.append(f"""
    <section class="cls" data-cls="{esc(label)}">
      <header class="cls-head">
        <div class="glyphs"><span class="g-old">{esc(old)}</span><span class="arrow">→</span><span class="g-new">{esc(new)}</span></div>
        <div class="cls-meta">
          <h3>{esc(label)}</h3>
          <p>{esc(NOTES.get(label, ""))}</p>
        </div>
        <div class="count"><b>{len(items)}</b><span>處</span></div>
      </header>
      <div class="tablewrap">
        <table>
          <thead><tr><th>經文</th><th>現在</th><th>改為</th></tr></thead>
          <tbody>{rows_html(items)}</tbody>
        </table>
      </div>
    </section>""")

    kept_html = "".join(
        f'<li><b>{esc(a)}</b><span>{esc(b)}</span></li>' for a, b in KEPT)

    total = sum(per_class.values())
    verses = len({(r["ref"]) for r in rows})

    doc = f"""<title>朱批校訂表</title>
<style>
:root {{
  --paper:#f6f2e9; --paper-2:#efe9dc; --rule:#ddd3bf;
  --ink:#1b1714; --ink-2:#5c5348; --ink-3:#8a7f70;
  --zhu:#b3312a; --zhu-soft:#f0dedb; --jade:#41694f; --jade-soft:#e0e9e1;
  --shadow:0 1px 0 rgba(27,23,20,.05), 0 8px 28px -18px rgba(27,23,20,.5);
  --cjk:"Songti TC","Songti SC","STSong","SimSun",'Noto Serif CJK TC',serif;
  --ui:"PingFang TC","PingFang SC","Helvetica Neue",system-ui,sans-serif;
  --mono:"SF Mono",ui-monospace,Menlo,monospace;
}}
@media (prefers-color-scheme: dark) {{
  :root:not([data-theme="light"]) {{
    --paper:#15120f; --paper-2:#1d1916; --rule:#332c25;
    --ink:#ece4d6; --ink-2:#b3a794; --ink-3:#847968;
    --zhu:#e2695c; --zhu-soft:#3a201d; --jade:#7fb08d; --jade-soft:#1d2a21;
    --shadow:0 1px 0 rgba(0,0,0,.4), 0 10px 30px -20px #000;
  }}
}}
:root[data-theme="dark"] {{
  --paper:#15120f; --paper-2:#1d1916; --rule:#332c25;
  --ink:#ece4d6; --ink-2:#b3a794; --ink-3:#847968;
  --zhu:#e2695c; --zhu-soft:#3a201d; --jade:#7fb08d; --jade-soft:#1d2a21;
  --shadow:0 1px 0 rgba(0,0,0,.4), 0 10px 30px -20px #000;
}}
* {{ box-sizing:border-box; }}
body {{
  margin:0; background:var(--paper); color:var(--ink);
  font-family:var(--ui); line-height:1.6;
  -webkit-font-smoothing:antialiased;
}}
.wrap {{ max-width:1080px; margin:0 auto; padding:clamp(24px,5vw,64px) clamp(16px,4vw,32px) 96px; }}

/* ── masthead ─────────────────────────────────────────── */
.mast {{ border-bottom:2px solid var(--ink); padding-bottom:20px; margin-bottom:32px; }}
.eyebrow {{
  font-size:11px; letter-spacing:.22em; text-transform:uppercase;
  color:var(--ink-3); margin:0 0 10px;
}}
h1 {{ font-family:var(--cjk); font-size:clamp(30px,5.5vw,46px); margin:0; letter-spacing:.04em; font-weight:600; }}
.dek {{ color:var(--ink-2); margin:10px 0 0; max-width:60ch; }}

/* ── the origin verse ─────────────────────────────────── */
.origin {{
  margin:28px 0 36px; padding:22px 24px; background:var(--paper-2);
  border-left:3px solid var(--zhu); border-radius:2px; box-shadow:var(--shadow);
}}
.origin .label {{ font-size:11px; letter-spacing:.18em; text-transform:uppercase; color:var(--zhu); margin:0 0 12px; }}
.origin .v {{ font-family:var(--cjk); font-size:clamp(17px,2.4vw,21px); line-height:1.9; margin:4px 0; }}
.origin .v .ref {{ color:var(--ink-3); font-family:var(--ui); font-size:13px; margin-right:12px; letter-spacing:.04em; }}

/* ── stats ────────────────────────────────────────────── */
.stats {{ display:grid; grid-template-columns:repeat(auto-fit,minmax(150px,1fr)); gap:1px;
  background:var(--rule); border:1px solid var(--rule); border-radius:3px; overflow:hidden; margin-bottom:40px; }}
.stat {{ background:var(--paper); padding:18px 20px; }}
.stat b {{ display:block; font-size:30px; font-family:var(--mono); font-variant-numeric:tabular-nums; letter-spacing:-.02em; }}
.stat span {{ font-size:12px; color:var(--ink-3); letter-spacing:.06em; }}

/* ── filter ───────────────────────────────────────────── */
.tools {{ display:flex; gap:12px; align-items:center; margin-bottom:24px; flex-wrap:wrap; }}
#q {{
  flex:1; min-width:220px; padding:10px 14px; font:inherit; font-size:14px;
  background:var(--paper-2); color:var(--ink);
  border:1px solid var(--rule); border-radius:3px;
}}
#q:focus {{ outline:2px solid var(--zhu); outline-offset:1px; }}
.hint {{ font-size:12px; color:var(--ink-3); }}

/* ── class sections ───────────────────────────────────── */
.cls {{ margin-bottom:14px; border:1px solid var(--rule); border-radius:3px; background:var(--paper-2); overflow:hidden; }}
.cls-head {{ display:flex; gap:18px; align-items:center; padding:16px 20px; }}
.glyphs {{ display:flex; align-items:center; gap:8px; font-family:var(--cjk); flex:none; }}
.g-old {{ font-size:26px; color:var(--ink-3); text-decoration:line-through; text-decoration-color:var(--zhu); text-decoration-thickness:1.5px; }}
.arrow {{ color:var(--ink-3); font-size:13px; }}
.g-new {{ font-size:26px; color:var(--zhu); font-weight:600; }}
.cls-meta {{ flex:1; min-width:0; }}
.cls-meta h3 {{ margin:0; font-size:14px; font-weight:600; letter-spacing:.03em; }}
.cls-meta p {{ margin:4px 0 0; font-size:12.5px; color:var(--ink-2); line-height:1.55; }}
.count {{ flex:none; text-align:right; }}
.count b {{ font-family:var(--mono); font-size:20px; font-variant-numeric:tabular-nums; }}
.count span {{ font-size:11px; color:var(--ink-3); margin-left:3px; }}

.tablewrap {{ max-height:340px; overflow:auto; border-top:1px solid var(--rule); }}
table {{ width:100%; border-collapse:collapse; font-size:14px; }}
thead th {{
  position:sticky; top:0; background:var(--paper); z-index:1;
  text-align:left; font-size:10.5px; letter-spacing:.14em; text-transform:uppercase;
  color:var(--ink-3); font-weight:500; padding:8px 14px; border-bottom:1px solid var(--rule);
}}
tbody tr {{ border-bottom:1px solid var(--rule); }}
tbody tr:last-child {{ border-bottom:0; }}
td {{ padding:9px 14px; vertical-align:top; }}
td.ref {{ white-space:nowrap; color:var(--ink-3); font-size:12px; width:1%; padding-top:12px; }}
td.ctx {{ font-family:var(--cjk); line-height:1.75; }}
del {{ background:var(--zhu-soft); color:var(--zhu); text-decoration:line-through;
  text-decoration-thickness:1.5px; padding:1px 2px; border-radius:2px; }}
ins {{ background:var(--jade-soft); color:var(--jade); text-decoration:none;
  padding:1px 2px; border-radius:2px; font-weight:600; }}

/* ── kept ─────────────────────────────────────────────── */
.kept {{ margin-top:48px; padding-top:28px; border-top:2px solid var(--ink); }}
.kept h2 {{ font-family:var(--cjk); font-size:22px; margin:0 0 6px; font-weight:600; letter-spacing:.03em; }}
.kept > p {{ color:var(--ink-2); margin:0 0 20px; max-width:62ch; font-size:14px; }}
.kept ul {{ list-style:none; padding:0; margin:0; display:grid; gap:1px; background:var(--rule);
  border:1px solid var(--rule); border-radius:3px; overflow:hidden; }}
.kept li {{ background:var(--paper); padding:12px 18px; display:flex; gap:16px; flex-wrap:wrap; align-items:baseline; }}
.kept li b {{ font-family:var(--cjk); font-weight:500; font-size:15px; flex:1; min-width:220px; }}
.kept li span {{ font-size:12.5px; color:var(--ink-3); }}

footer {{ margin-top:48px; font-size:12px; color:var(--ink-3); line-height:1.8; }}
footer code {{ font-family:var(--mono); font-size:11.5px; background:var(--paper-2);
  padding:2px 6px; border-radius:2px; border:1px solid var(--rule); }}
.hidden {{ display:none !important; }}
@media (prefers-reduced-motion:reduce) {{ * {{ animation:none!important; transition:none!important; }} }}
</style>

<div class="wrap">
  <div class="mast">
    <p class="eyebrow">簡→繁 轉換校訂 · 待核准</p>
    <h1>朱批校訂表</h1>
    <p class="dek">讀者回報賽 2:16「船只」應作「船隻」。追查後發現不是單一錯字，而是當初簡轉繁時整批漏轉。以下是打算改的每一處，改之前請先過目。</p>
  </div>

  <div class="origin">
    <p class="label">回報的那一節</p>
    <p class="v"><span class="ref">現在</span>又臨到他施的<del>船只</del>並一切可愛的美物。</p>
    <p class="v"><span class="ref">改為</span>又臨到他施的<ins>船隻</ins>並一切可愛的美物。</p>
  </div>

  <div class="stats">
    <div class="stat"><b>{total}</b><span>處替換</span></div>
    <div class="stat"><b>{verses}</b><span>節經文</span></div>
    <div class="stat"><b>{len(by_cls)}</b><span>類</span></div>
    <div class="stat"><b>0</b><span>已寫入（試跑）</span></div>
  </div>

  <div class="tools">
    <input id="q" type="search" placeholder="搜尋經文出處或字詞，例如「以賽亞」「船」「乾」" aria-label="篩選" />
    <span class="hint" id="hint"></span>
  </div>

  {''.join(sections)}

  <div class="kept">
    <h2>刻意不動的部分</h2>
    <p>這些看起來像同一類，其實本來就是對的。逐字轉換最容易在這裡改壞，所以規則都寫了例外。</p>
    <ul>{kept_html}</ul>
  </div>

  <footer>
    規則與本表同源，皆讀自 <code>tools/fix_traditional_conversion.py</code>，不會各說各話。<br />
    試跑指令 <code>python3 tools/fix_traditional_conversion.py</code>；確認後加 <code>--apply</code> 才會寫檔。
  </footer>
</div>

<script>
const q = document.getElementById('q');
const hint = document.getElementById('hint');
const secs = [...document.querySelectorAll('.cls')];
const all = secs.map(s => [s, [...s.querySelectorAll('tbody tr')]]);
function run() {{
  const t = q.value.trim();
  let shown = 0;
  for (const [sec, trs] of all) {{
    let n = 0;
    for (const tr of trs) {{
      const hit = !t || tr.textContent.includes(t);
      tr.classList.toggle('hidden', !hit);
      if (hit) n++;
    }}
    sec.classList.toggle('hidden', n === 0);
    shown += n;
  }}
  hint.textContent = t ? shown + ' 處符合' : '';
}}
q.addEventListener('input', run);
</script>
"""
    out = ROOT / "tools" / "tr-fix-review.html"
    out.write_text(doc, encoding="utf-8")
    print(f"  {total} substitutions, {verses} verses, {len(by_cls)} classes")
    print(f"  → {out}  ({out.stat().st_size/1024:.0f} KB)")


if __name__ == "__main__":
    main()
