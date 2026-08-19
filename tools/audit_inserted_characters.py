#!/usr/bin/env python3
"""Find verses where OUR text carries characters that NEITHER witness has.

The mirror of `audit_dropped_characters.py`, and the direction nobody had ever
measured: that audit only reports where the witnesses read MORE than we do, so
until this file existed the app could add words to scripture and no check in
the repo would notice. Adding is the worse direction of the two — a reader who
sees a missing word may notice, but a reader who sees an extra one cannot.

Ours            assets/cuvs-yhwh.json          (Simplified, 雅伟 for YHWH)
Witness A       SeekSparks assets/cuvs-plus.json   (independent Simplified import)
Witness B       git blob 7a2dc43 = assets/cuv-tr.json (Traditional, dropped v1.4.5)

Witness B is folded to Simplified with opencc so all three sit in one script.
Only CJK ideographs are compared, so punctuation and spacing never register.
A hit is an insertion the two witnesses agree on, at the same place in our text.

**The 26 running-text hits have now been read against the printed 1919, and 20
of them are not insertions at all.** The print agrees with the two witnesses,
against us, at all but one — and that turns out to be the wrong question to
ask. Where our text reads longer, it supplies a Chinese word for a word that
is IN the Greek and that the print leaves implicit: 就開始控告 renders ἤρξατο
κατηγορεῖν where the print's 就告他說 drops ἤρξατο, and 等了多時，看見 renders
both προσδοκώντων and θεωρούντων where the print renders one. Our own tagged
corpus reads identically at all 20 and its Strong's numbers were checked
against assets/originals verse by verse. **Deleting any of them would remove a
word the Greek has.**

**Why the clustering in 使徒行傳 and 哥林多後書 is still not explained.** The
obvious story — one deliberate revision pass toward the original — was put to
an adversarial check and did not survive as a single cause: 創世記 48:17 is a
witness error, and two 民數記 hits are bare aspect particles rendering nothing.
An equally good rival is that this edition was keyed from a LATER CUV printing
rather than the 1919 sheets, which predicts the same scattered corrections and
the same clustering with no editorial intent at all. Nothing in reach
distinguishes them, so both are recorded and neither is asserted. Six are still
open — see PENDING.

Hits are split in two, because they are not the same kind of thing:

  APPARATUS  the extra characters lie wholly inside a <note:…> marker, a
             [雅伟]-style bracket gloss, or a （原文是…） parenthesis. This
             edition's own editorial apparatus, which the witnesses simply do
             not carry. 387 of the 419 hits, and none of them is a defect.
  RUNNING    the extra characters are in the verse itself. These are the ones
             that matter, and each has to be read individually.

**What this audit cannot see, and it is a large hole.** It only reports where
BOTH witnesses disagree with us, so any text we share with witness A is
invisible to it — and we share an ancestor with A. 歷代志上 15:3 read
「招聚以色列眾人眾人」 and this audit never flagged it, because A reads 眾人眾人
too. It was caught by a third witness that is internal to this repo and that
nothing here consults: `assets/tagged/cuvs-yhwh/`, whose runs concatenate back
to the verse and which held 以色列众人 once. That comparison now exists as
`audit_tagged_running_text.py`, and it found six more losses this hole hid —
two of which BOTH witnesses share.
"""
import json
import re
import subprocess
import sys
from difflib import SequenceMatcher
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
OURS = REPO / "assets/cuvs-yhwh.json"
WIT_A = Path("/Users/pliu0036/Documents/CodingProject/SeekSparks/assets/cuvs-plus.json")
WIT_B_BLOB = "7a2dc43"

CJK = re.compile(r"[一-鿿㐀-䶿]")

# Running-text hits that have been read individually and are NOT insertions.
# Anything outside this set is new drift and fails the run.
EXPLAINED = {
    # Verse-boundary placement: the trailing 說 of the previous verse opens
    # this one in this edition. Already carried by the deletion audit as the
    # other half of the same pair.
    "005005006": "說 opens 申命記 5:6 here; the witnesses leave it in 5:5",
    "005032020": "說 opens 申命記 32:20 here; the witnesses leave it in 32:19",
    # A transposition the printed 1919 settles in OUR favour — see the
    # deletion audit, which pins the mirror image of this hit.
    "024007014": "1919 reads 稱我為名下; the witnesses read 稱為我名下",
    # Verse 15 is merged into 14 in this edition, behind a <note: 15节> marker.
    # Whether it deserves its own number is a queued question for the user,
    # not a text defect: no character is invented, only un-numbered.
    "064001014": "約翰三書 1:15 is merged into 1:14 behind a 15节 note marker",
    # Filed separately in the queue as a substitution, not an insertion.
    "047013005": "ours 在你們裏面 where the print reads 在你們心裏",
    #
    # ---- THE 1919 PRINT HAS NOW BEEN READ FOR ALL OF THESE, 2026-08-19 ----
    #
    # It agrees with the two witnesses, i.e. AGAINST us, in every one below
    # except 創世記 48:17 — and they are still not insertions. Each of the
    # Greek ones supplies a Chinese word for a word that IS in the original
    # and that the print leaves implicit, our own tagged corpus reads
    # identically to the running text at all of them, and its Strong's number
    # sits on the very characters the witnesses lack. The numbers were checked
    # against assets/originals one by one: see each line.
    #
    # **Read the tag on the RUN, not on the character.** Runs are
    # multi-character and the tagging is alignment-derived, so an inserted
    # character can ride on a neighbour's number and prove nothing. That is
    # what disqualified 馬可福音 6:33, which is now in PENDING: its 城的 run
    # carries G3588, the article, while πόλεων is G4172 and G4172 appears in
    # no run of that verse at all. Off by one, not evidence.
    #
    # **What this does NOT establish is a single cause.** "One deliberate
    # revision pass toward the original" was the first explanation reached
    # for the 使徒行傳/哥林多後書 clustering and it does not cover the file:
    # 創世記 48:17 is a witness error, and the two 民數記 hits are bare aspect
    # particles rendering nothing. A rival that fits everything equally well
    # is that this edition was keyed from a LATER CUV printing rather than the
    # 1919 sheets — same scattered corrections, same clustering, no publisher
    # intent required, and nothing in reach distinguishes the two. Recorded
    # rather than settled. Either way the operational conclusion is the same
    # and it is the only one that matters here: DELETING any of these would
    # remove a word the Greek actually has.
    "001048017": "the PRINT AGREES WITH US — 以法蓮的頭上; the witnesses shortened",
    "004011030": "了 is an aspect particle rendering no word; not an accuracy "
                 "question either way, and the tagged corpus reads as we do",
    "004021020": "到了 is an aspect particle rendering no word; tagged corpus "
                 "reads as we do",
    "038008014": "我並不後悔: נִחָמְתִּי is 1cs, so the subject is in the Hebrew "
                 "verb. NOT a tag argument — the run 我並不 carries H3808 (לֹא) "
                 "and H5162 sits on 後悔",
    "044023035": "也 renders καὶ G2532",
    "044024002": "就開始控告 renders ἤρξατο κατηγορεῖν; the print's 就告他說 "
                 "drops ἤρξατο (G757/G2723)",
    "044024023": "要寬待 renders ἔχειν ἄνεσιν G2192",
    "044025022": "聽他 renders αὐτοῦ G846",
    "044028006": "等了多時，看見 renders BOTH προσδοκώντων and θεωρούντων; "
                 "the print's 看了多時、見 renders one (G2334)",
    "044028010": "所需用的東西 renders the substantivised τὰ G3588",
    "046015031": "我們主 renders τῷ Κυρίῳ ἡμῶν G2257/G1473",
    "047002013": "因為我沒有遇見 renders με G3165",
    "047006003": "在凡事 renders ἐν G1722",
    "047007014": "因我們對提多誇獎 renders ἡ καύχησις ἡμῶν G2257",
    "047008004": "這服事供給 renders τῆς διακονίας G1248",
    "047008006": "我們勸 renders ἡμᾶς G2248; 就 renders καὶ G2532",
    "047008015": "也沒有缺少 renders ἠλαττόνησεν G1641",
    "047008023": "我們那兩位兄弟 renders ἀδελφοὶ ἡμῶν G2257",
    "047009011": "在凡事富足 renders ἐν G1722",
    "047012020": "發見 renders εὑρίσκω G2147, twice, in both halves",
    # RESTORED text, not inserted text. Both witnesses are short here and the
    # printed 1919 is not — 「王所喜悅尊榮的人」, 「抹在你們的臉上」 — and our
    # own tagged corpus tags the restored word (H376 אִישׁ; H2219 抹在 with
    # H5921 עַל־פְּנֵיכֶם). Found by tools/audit_tagged_running_text.py and
    # applied by tools/repair_tagged_witness_losses.py. Do NOT "repair" them
    # back: both witnesses agreeing is not proof, which is the whole reason
    # this file keeps a PENDING list instead of a fix list.
    "017006007": "restored 人; the print reads 王所喜悅尊榮的人",
    "039002003": "restored 在; the print reads 抹在你們的臉上",
}

# What the printed 1919 did NOT settle. Five of the original 26; the other 21
# moved to EXPLAINED above once the print had been read against each of them.
#
# None of them may be "repaired" on the strength of the two witnesses alone.
# 創世記 39:22 and 41:30 are the standing warning — both witnesses read longer
# than us there and OURS was the correct 1919 reading.
#
# They are listed with the exact characters they add, so that this audit stays a
# working regression detector while they wait: a re-import that changes one of
# them, or adds a new one, still fails the run.
PENDING = {
    # 馬可福音 6:33. 「就從各城的步行」 is not good Chinese and the tag that
    # looked like evidence is an alignment off-by-one: the run 城的 carries
    # G3588 (the article) while πόλεων is G4172, which appears in NO run of
    # this verse. So nothing corroborates the 的 — but our tagged corpus does
    # read 城的 with us, so it is 2 of our files against the print and both
    # witnesses, which is not enough to delete a character unattended.
    "041006033": "马可福音 6:33  +的  (从各城的步行 / 从各城步行)"
                 "  ungrammatical, and the G3588 tag is an off-by-one",
    # Three in 尼希米記 1–3, and they are a different case from the 20. The
    # Hebrew HAS a word each could render — עַל twice (H5921), the second
    # אַתֶּם (H859), הֵמָּה (H1992) — so DELETING them would remove a word the
    # Hebrew has. But our own tagged corpus does not carry any of the three,
    # so they rest on our reading text's lineage alone: four lines of evidence
    # lack them, one has them. Not deletable, not corroborated.
    "016001002": "尼希米记 1:2  +关于 +关于  (我问他们关于那些… / 我问他们那些…)"
                 "  the Hebrew has עַל twice, but 关于 is a HAPAX — 1 verse in "
                 "31,102 — so contamination fits better than a revision",
    "016002019": "尼希米记 2:19  +你们  (你们要背叛王吗 / 要背叛王么)"
                 "  the Hebrew has a second אַתֶּם; our tagged corpus lacks it",
    "016003003": "尼希米记 3:3  +他们  (建立鱼门，他们架横梁 / 建立鱼门，架横梁)"
                 "  הֵמָּה is in the Hebrew, but our tagged corpus lists H1992 "
                 "among the UNTRANSLATED words — its own tagging says this "
                 "edition does not render it",
    # The one hit nothing supports. Ours reads 我是因雅偉神忿怒的杖; the print
    # and both witnesses read 耶和華 alone, our tagged corpus reads 雅偉 alone
    # and tags it H0 — supplied, no Strong's number — because the Hebrew
    # אֲנִי הַגֶּבֶר רָאָה עֳנִי בְּשֵׁבֶט עֶבְרָתוֹ has NO divine name at
    # all: "the rod of HIS wrath". So both readings are supplied, and the
    # extra 神 is supported by nothing. It is also a divine-name decision in
    # a divine-name edition, which is not an unattended call. Queued.
    "025003001": "耶利米哀歌 3:1  +神  (因雅伟神忿怒的杖 / 因耶和华忿怒的杖)"
                 "  the Hebrew has no divine name here at all",
    # 使徒行傳 26:16 was listed here and is GONE, repaired 2026-08-19 by
    # `tools/repair_transposed_characters.py`: 特意向你我顯現 → 我特意向你顯現.
    # It was a TRANSPOSITION rather than an insertion, and it reached this
    # audit because the comparison is POSITIONAL (SequenceMatcher), not a
    # multiset — a moved character reads as an insertion at the place it
    # arrived. That is worth knowing: this file catches reorderings the
    # multiset argument says it cannot. Removing the entry was checked
    # against the pre-repair data, where it comes back as NEW rather than
    # vanishing, so the guard is real.
}


def load(path):
    return {r["id"]: r for r in json.loads(Path(path).read_text(encoding="utf-8"))}


def load_blob(blob):
    raw = subprocess.run(
        ["git", "cat-file", "-p", blob], cwd=REPO, capture_output=True, check=True
    ).stdout.decode("utf-8")
    return {r["id"]: r for r in json.loads(raw)}


def to_simplified(texts):
    joined = "\n".join(t.replace("\n", " ") for t in texts)
    out = subprocess.run(
        ["opencc", "-c", "t2s"], input=joined.encode("utf-8"),
        capture_output=True, check=True,
    ).stdout.decode("utf-8")
    lines = out.split("\n")
    assert len(lines) == len(texts), (len(lines), len(texts))
    return lines


def han(text):
    return "".join(CJK.findall(text))


def apparatus_mask(text):
    """One flag per CJK character: is it inside editorial apparatus?

    Indexes line up with `han(text)`, so a hit's position can be tested
    directly. Brackets and parentheses nest independently of note markers
    because this edition uses 「（原文是…）」 inside notes and 「主[雅伟]」
    outside them.
    """
    flags = []
    note = brackets = parens = 0
    i = 0
    while i < len(text):
        if text.startswith("<note:", i):
            note += 1
            i += 6
            continue
        if note and text[i] == ">":
            note -= 1
            i += 1
            continue
        ch = text[i]
        if ch in "[［":
            brackets += 1
        elif ch in "]］":
            brackets = max(0, brackets - 1)
        elif ch in "（(":
            parens += 1
        elif ch in "）)":
            parens = max(0, parens - 1)
        elif CJK.match(ch):
            flags.append(bool(note or brackets or parens))
        i += 1
    return flags


def insertions(ours, theirs):
    """Substrings present in `ours` and absent from `theirs`, keyed by the
    position in `ours` where they were added."""
    out = []
    for tag, i1, i2, j1, j2 in SequenceMatcher(None, theirs, ours, autojunk=False).get_opcodes():
        if tag == "insert":
            out.append((j1, ours[j1:j2]))
    return out


def main():
    ours = load(OURS)
    a = load(WIT_A)
    b = load_blob(WIT_B_BLOB)

    ids = sorted(ours)
    b_ids = [i for i in ids if i in b]
    b_simp = dict(zip(b_ids, to_simplified([b[i]["text"] for i in b_ids])))

    apparatus, running = [], []
    for vid in ids:
        if vid not in a or vid not in b_simp:
            continue
        mine = han(ours[vid]["text"].replace("雅伟", "耶和华"))
        ta = han(a[vid]["text"])
        tb = han(b_simp[vid])
        if mine == ta and mine == tb:
            continue
        agreed = sorted(set(insertions(mine, ta)) & set(insertions(mine, tb)))
        if not agreed:
            continue
        mask = apparatus_mask(ours[vid]["text"].replace("雅伟", "耶和华"))
        if all(all(mask[p:p + len(s)] or [False]) for p, s in agreed):
            apparatus.append((vid, agreed))
        else:
            running.append((vid, agreed))

    known = EXPLAINED.keys() | PENDING.keys()
    fresh = [h for h in running if h[0] not in known]
    print(f"verses compared: {len(ids)}")
    print(f"we read more than both witnesses: {len(apparatus) + len(running)}")
    print(f"  editorial apparatus only: {len(apparatus)}")
    print(f"  in the running text: {len(running)}")
    print(f"    read and explained: {sum(1 for h in running if h[0] in EXPLAINED)} of {len(EXPLAINED)}")
    print(f"    awaiting the printed 1919: {sum(1 for h in running if h[0] in PENDING)} of {len(PENDING)}")
    print(f"    NEW, unexamined: {len(fresh)}")
    for vid, agreed in fresh:
        r = ours[vid]
        extra = " ".join(f"{s!r}@{pos}" for pos, s in agreed)
        print(f"\n{vid}  {r['book']} {r['chapter']}:{r['verse']}   extra {extra}")
        print(f"  ours : {r['text']}")
        print(f"  A    : {a[vid]['text']}")
        print(f"  B    : {b[vid]['text']}")

    # A known hit that stops appearing is drift too — the text moved under a
    # triage decision that was made by reading it.
    gone = sorted(known - {vid for vid, _ in running})
    for vid in gone:
        print(f"\n{vid} no longer reads long — update EXPLAINED/PENDING: "
              f"{EXPLAINED.get(vid) or PENDING[vid]}")
    return 1 if fresh or gone else 0


if __name__ == "__main__":
    sys.exit(main())
