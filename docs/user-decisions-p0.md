# P0 — the decisions only you can make

Rewritten 2026-09-02. **Most of this page no longer exists**, and that is
the news.

> ## 🔒 和合本雅偉版 is frozen — user, 2026-09-02
>
> > cuvs yhwh这个不用管 因为出版方说这个不要
> > 删掉相关内容
>
> Sections A, C and item 8 of the previous version were all proposals to
> edit `assets/cuvs-yhwh.json` / `cuvs-yhwh-tr.json`. The publisher has
> declined, so they are not decisions any more — they are deleted.
>
> **25 open queue items went with them**, plus the whole 兇/凶 · 蹟/跡 ·
> 鍊/鏈 · 剋/克 glyph class, the one-to-many converter leftovers, the
> Revelation and speech-mark quotation classes, 創 45:10, 哀 3:1, 尼 1–3,
> 可 6:33, 摩 6:8, 鴻 3:4, 路 21:30, 番 1:1 and 約 9:9. The queue carries a
> FROZEN block at the top; `test/cuvs_yhwh_frozen_test.dart` pins both
> files by SHA-256 so an audit that rediscovers 0 蹟 / 103 跡 next month
> cannot quietly "fix" it.
>
> **What is NOT frozen**, so the ruling is not over-read: the word-tap
> corpus, the Strong's tagging, the lexicon, and every line of rendering
> code — including the `[雅偉]` brackets shipped in v1.4.192, which are a
> rendering decision about the publisher's own notation, not an edit to it.

---

## 1. NASB — the one thing that is still urgent

Measured against prod:

```
https://yahwehword.com/assets/assets/nasb.json  →  HTTP 200, 7,215,432 bytes
assets/nasb.json  →  31,090 verses
```

The Lockman Foundation's gratis-use policy caps quotation at **1,000
verses**, and separately forbids storing more than 1,000 in an electronic
retrieval system. A publicly fetchable 31,090-verse JSON is outside both.
README claims *"used under the publisher's free-quotation provisions"* —
that claim does not hold at this size.

**Decide:** obtain a written licence from Lockman, or drop `nasb.json` from
the public web build. I have not touched it — removing a translation is
your call. *(URL, byte count and verse count are mine. The Lockman clause
summary is Fable's; worth your own look before acting.)*

This also blocks the NASB divine-pronoun item at the bottom of the queue.

---

## 2. The Traditional-glyph ruling — its subject just disappeared

You ruled the same day:

> 关于繁体字 你可以参考和合本最新版本的繁体版看那边怎么写的然后用他们的

That was aimed at `cuvs-yhwh-tr`, which is now frozen. **Nothing to apply
it to there** — the file keeps 0 蹟 / 103 跡, 0 鍊 / 60 鏈, 48 兇 / 0 凶,
measured and accepted.

Where it still applies is `biblexg-v2-tr.json`, which is also **our own
conversion** rather than the publisher's Traditional. I measured it, and
it is in much better shape than the CUV conversion — the collapse pattern
is simply absent:

| pair | biblexg-v2-tr | reading |
|---|---|---|
| 蹟 / 跡 | 97 / 1 | correct — 神蹟 distinguished from 痕跡 |
| 幹 / 干 | 31 / 3 | **all 31 correct** — 幹活, 幹農活, 幹掉 |
| 癒 / 愈 | 22 / 3 | correct — 痊癒, 治癒 |
| 剋 / 克 | 1 / 19 | correct — 剋扣 |

Two real inconsistencies, both small:

* **8 stray 着 against 1058 著** — 穿着, 盯着, 站着, 拖着, 照着, 憑着,
  靠着, 得着. Modern Traditional prints 著 throughout; these 8 are
  leftovers.
* **兇 8 / 凶 8, splitting the same words** — 兇惡 once and 凶惡 twice,
  兇殺 beside 行凶.

**Neither is worth a sweep today**, because item "rebuild the Traditional
from the corrected Simplified" will regenerate this file once the publisher
answers. Your ruling is now recorded *in that item*, so the rebuild
produces modern Traditional conventions rather than needing a second pass.

---

## 3. 梁家鏗譯本 — waiting on the publisher, not on you

These are the only remaining scripture items, and your action on all four
is the same: finish the per-book review of §四之二 so the letter can go.

* The **427 Traditional wording differences** — clustered in 路加 (178)
  and 馬可 (89), reading as one consistent later revision.
* The **86 Simplified wording differences** — counted and settled, waiting
  only on their direction.
* **The two official editions disagree** — drafted, ships with the letter.
* **馬可福音 6:8-11 is missing from the publisher's own Simplified** —
  `cn-mk.json` has no 6:8-11 and truncates 6:7 mid-sentence.

One of theirs is a **visible bug**, not a policy question, and I would fix
it independently of the letter if you want it gone sooner:

* **路加福音 23:33 prints the literal characters `34a` inside the verse
  body**, in both editions:
  > 「…右手一個，左手一個。**34a**耶穌說：父親啊，赦免他們…」

  Repair is to render it as the doubtful-passage affix the repo already
  handles for 22:43, 22:44 and 23:17. **No sub-verse labels** — the app has
  no non-numeric verse label and the sort problem is real.

---

## 4. Not decisions after all

Kept here only so they are not re-raised as questions:

* **約翰三書 1:14/15** — the CUV genuinely has 14 verses (KJV
  versification), and `originals_versification.json` already maps
  `3_john 1:14 → [1:14, 1:15]`. The fix is in the cross-reference lookup.
  Code work.
* **17 wrong 幹 in `assets/sermons/zh-TW/`** — 幹枯 / 幹淨 / 幹擾. The
  sermon assets are the church's, not the publisher's, and these are our
  conversion errors. Work, not a ruling.
* **貴胄 / 貴冑** — answered. All 26 positions take 貴胄; 和合本 renders
  "helmet" as 盔/頭盔/盔甲/鎧甲, zero 甲冑 in 31,102 verses.

---

## Suggested order

1. **NASB** — live exposure, and it gates the divine-pronoun item too.
2. **Finish §四之二** so the 梁家鏗 letter leaves your desk.
3. Then 路加 23:34a and the 約翰三書 lookup — both are code, no ruling.

The census still runs, and still writes nothing — though its glyph section
now describes a frozen file:

```bash
python3 tools/audit_p0.py
```
