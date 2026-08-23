#!/usr/bin/env python3
"""Move nine quotation marks that put one speaker's words inside another's.

馬太福音 15:34 read 耶穌說：「你們有多少餅？他們說：有七個，還有幾條小魚。」
— the disciples' answer sat inside Jesus's quotation, so the app attributed
their words to him. 約翰福音 2:7 read 耶穌對用人說：「把缸倒滿了水。他們就倒滿
了，直到缸口。」 — that is the narrator, inside Jesus's quotation.
哥林多前書 15:45 ran the scripture citation on past its end, so the app had
經上記著說 introduce a clause that is Paul's own.

**Only quotation marks move.** No Chinese character is added, deleted or
reordered in any of the nine, in any of the three files. Run
`tools/audit_speaker_attribution.py` for the detector and the triage.

Idempotent: a verse already in the repaired form is skipped, and any verse
that matches neither form aborts the whole run rather than being guessed at.
"""
import json
import os
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# (anchor_before, anchor_after) pairs, per verse, in Traditional and
# Simplified. `close` inserts the closing mark; `open` inserts the opening
# mark; `drop` deletes a now-redundant trailing mark.
#
# id: (traditional edits, simplified edits)
# each edit is (old, new) applied to the whole verse text, exactly once.
EDITS = {
    # 創世紀 30:6 — 因此給他起名叫但 is the narrator. The same passage sets the
    # identical naming formula OUTSIDE the quotation TEN times and inside it
    # only here: eight after the closing mark (29:33, 29:35, 30:8, 30:11,
    # 30:13, 30:18, 30:20, 30:24) and two before the opening one (29:32,
    # 29:34). The eight join with 。」於是/因此 and this one with 」，因此 —
    # a different join, but the one the witness 7a2dc43 uses here.
    '001030006': (
        [('賜我一個兒子，因此', '賜我一個兒子」，因此'), ('的意思>。」', '的意思>。')],
        [('赐我一个儿子，因此', '赐我一个儿子”，因此'), ('的意思>。”', '的意思>。')],
    ),
    # 馬太福音 15:34
    '040015034': (
        [('多少餅？他們說：', '多少餅？」他們說：「')],
        [('多少饼？他们说：', '多少饼？”他们说：“')],
    ),
    # 馬太福音 17:26 — the quotation does not close until 17:27, which is why
    # a balanced-span check never saw it.
    '040017026': (
        [('是向外人。耶穌說：', '是向外人。」耶穌說：「')],
        [('是向外人。耶稣说：', '是向外人。”耶稣说：“')],
    ),
    # 馬可福音 6:37
    '041006037': (
        [('他們吃吧。門徒說：', '他們吃吧。」門徒說：「')],
        [('他们吃吧。门徒说：', '他们吃吧。”门徒说：“')],
    ),
    # 約翰福音 2:7 — 他們就倒滿了 is narration; Jesus cannot be its speaker.
    '043002007': (
        [('倒滿了水。他們就', '倒滿了水。」他們就'), ('直到缸口。」', '直到缸口。')],
        [('倒满了水。他们就', '倒满了水。”他们就'), ('直到缸口。”', '直到缸口。')],
    ),
    # 約翰福音 2:8
    '043002008': (
        [('管筵席的。他們就', '管筵席的。」他們就'), ('送了去。」', '送了去。')],
        [('管筵席的。他们就', '管筵席的。”他们就'), ('送了去。”', '送了去。')],
    ),
    # 約翰福音 13:29 — 叫他拿什麼賙濟窮人 is third person, so it is the
    # narrator's alternative explanation, not Jesus addressing Judas.
    '043013029': (
        [('應用的東西，或是', '應用的東西」，或是'), ('賙濟窮人。」', '賙濟窮人。')],
        [('应用的东西，或是', '应用的东西”，或是'), ('赒济穷人。”', '赒济穷人。')],
    ),
    # 約翰福音 13:36
    '043013036': (
        [('那裏去？耶穌回答說：', '那裏去？」耶穌回答說：「')],
        [('那里去？耶稣回答说：', '那里去？”耶稣回答说：“')],
    ),
    # 哥林多前書 15:45 — the citation is Genesis 2:7 and ends at 活人;
    # 末後的亞當 is Paul. Leaving it inside made 經上記著說 introduce a
    # sentence that is not in the Old Testament at all.
    '046015045': (
        [('的活人；末後', '的活人」；末後'), ('叫人活的靈。」', '叫人活的靈。')],
        [('的活人；末后', '的活人”；末后'), ('叫人活的灵。”', '叫人活的灵。')],
    ),
}

# Tagged word-tap corpus (Simplified only): (book file, "c:v", [(old, new)])
TAGGED = [
    ('genesis', '30:6', [('一个儿子，', '一个儿子”，'),
                         ('〔就是"伸冤"的意思〕。”', '〔就是"伸冤"的意思〕。')]),
    ('matthew', '15:34', [('饼？', '饼？”'), ('说：有七个，', '说：“有七个，')]),
    ('matthew', '17:26', [('外人。', '外人。”'), ('说：', '说：“')]),
    ('mark', '6:37', [('吃吧。', '吃吧。”'), ('说：', '说：“')]),
    ('john', '2:7', [('水。', '水。”'), ('缸口。”', '缸口。')]),
    ('john', '2:8', [('管筵席的。', '管筵席的。”'), ('送了去。”', '送了去。')]),
    ('john', '13:29', [('的东西，或', '的东西”，或'), ('穷人。”', '穷人。')]),
    ('john', '13:36', [('去？', '去？”'), ('说：我所去', '说：“我所去')]),
    ('1_corinthians', '15:45', [('人；', '人”；'), ('的灵。”', '的灵。')]),
]


def apply_text(text, edits, ref):
    """Apply every edit exactly once. Returns (new_text, changed)."""
    done = 0
    for old, new in edits:
        if text.count(new) == 1 and text.count(old) == 0:
            continue                       # already repaired
        if text.count(old) != 1:
            raise SystemExit(
                f'{ref}: anchor {old!r} occurs {text.count(old)} times, '
                f'expected 1 — refusing to guess. Text: {text}')
        text = text.replace(old, new)
        done += 1
    return text, done > 0


def repair_edition(path, which):
    full = os.path.join(REPO, path)
    data = json.load(open(full))
    n = 0
    for v in data:
        if v['id'] not in EDITS:
            continue
        edits = EDITS[v['id']][which]
        v['text'], changed = apply_text(v['text'], edits, f'{path} {v["id"]}')
        n += bool(changed)
    with open(full, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write('\n')
    return n


def repair_tagged():
    n = 0
    for book, ref, edits in TAGGED:
        path = os.path.join(REPO, 'assets/tagged/cuvs-yhwh', f'{book}.json')
        data = json.load(open(path))
        runs = data[ref]
        joined = ''.join(r['w'] for r in runs)
        for old, new in edits:
            if joined.count(new) == 1 and joined.count(old) == 0:
                continue
            hits = [i for i, r in enumerate(runs) if r['w'] == old]
            if len(hits) != 1:
                raise SystemExit(
                    f'{book} {ref}: run {old!r} matches {len(hits)} runs, '
                    f'expected 1 — refusing to guess.')
            runs[hits[0]]['w'] = new
            n += 1
        with open(path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, separators=(',', ':'))
    return n


def main():
    a = repair_edition('assets/cuvs-yhwh-tr.json', 0)
    b = repair_edition('assets/cuvs-yhwh.json', 1)
    c = repair_tagged()
    print(f'Traditional: {a} verses, Simplified: {b} verses, '
          f'tagged runs changed: {c}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
