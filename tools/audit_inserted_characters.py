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
    #
    # ---- 98 apparatus-reformat hits from the 50dcc102 adoption, 2026-09-09 ----
    #
    # Mirrors the batch of the same name in audit_dropped_characters.py: a
    # `<note:…>` gloss's anchor moved relative to the word it annotates, or
    # its wording changed, or (042017036 alone) its delimiter changed from
    # `<note:…>` to `〔…〕` — the case that motivated teaching apparatus_mask
    # the second spelling, see that function's docstring. Checked against
    # `docs/autonomous-queue.md:2451`'s method: the text outside the note is
    # byte-identical between `50dcc102^` and HEAD. Listed by id, not by a
    # blanket "multiset unchanged" rule — see the dropped-audit comment for
    # why that rule would swallow six genuine word-order corruptions the
    # same pass found (009001007, 043012035, 043016004, 045012003,
    # 049004022, 066002016), none of which appear below.
    "004032038": "民数记 32:38  extra '西比玛'@16 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "007006026": "士师记 6:26  extra '上'@4 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "009006019": "撒母耳记上 6:19  extra '的他的原文是耶和华'@11 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "009025001": "撒母耳记上 25:1  extra '里'@28 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "010011011": "撒母耳记下 11:11  extra '的'@29 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "011002034": "列王纪上 2:34  extra '里坟墓里'@30 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "011003004": "列王纪上 3:4  extra '的'@18 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "013015013": "历代志上 15:13  extra '我们刑罚'@28 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "014030003": "历代志下 30:3  extra '间'@2 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "015001006": "以斯拉记 1:6  extra '帮助他们'@18 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "016003005": "尼希米记 3:5  extra '担'@19 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "019009014": "诗篇 9:14  extra '的'@17 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "019010010": "诗篇 10:10  extra '之下'@17 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "019022020": "诗篇 22:20  extra '脱离'@16 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "019051010": "诗篇 51:10  extra '的'@20 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "019088004": "诗篇 88:4  extra '的人'@13 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "019106028": "诗篇 106:28  extra '的'@16 '死'@19 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "019140009": "诗篇 140:9  extra '自己陷害'@21 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "023014032": "以赛亚书 14:32  extra '的'@7 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "023016001": "以赛亚书 16:1  extra '的山城'@24 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "023022004": "以赛亚书 22:4  extra '的众民'@21 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "023033004": "以赛亚书 33:4  extra '尽禾稼吃'@14 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "023038017": "以赛亚书 38:17  extra '灵魂'@18 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "023041009": "以赛亚书 41:9  extra '来的领'@8 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "023044014": "以赛亚书 44:14  extra '树柞树'@9 '作'@14 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "023048014": "以赛亚书 48:14  extra '内中他们'@10 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "023049012": "以赛亚书 49:12  extra '国秦'@21 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "023055011": "以赛亚书 55:11  extra '的事上'@32 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "024003003": "耶利米书 3:3  extra '雨'@7 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "024005006": "耶利米书 5:6  extra '的晚上'@14 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "024006002": "耶利米书 6:2  extra '女子'@8 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "024006026": "耶利米书 6:26  extra '民'@1 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "024009001": "耶利米书 9:1  extra '中百姓'@21 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "024030014": "耶利米书 30:14  extra '你'@13 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "024030017": "耶利米书 30:17  extra '的'@36 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "025003034": "耶利米哀歌 3:34  extra '在踹'@8 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "026001016": "以西结书 1:16  extra '颜色'@5 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "026014019": "以西结书 14:19  extra '灭命'@12 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "026023025": "以西结书 23:25  extra '的人遗留'@31 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "026026006": "以西结书 26:6  extra '居民'@6 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "026028010": "以西结书 28:10  extra '的人未受割礼'@14 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "026033022": "以西结书 33:22  extra '灵'@16 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "026040003": "以西结书 40:3  extra '如颜色'@12 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "026040044": "以西结书 40:44  extra '在南门旁'@22 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "026047010": "以西结书 47:10  extra '网之处晒网'@21 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "027001017": "但以理书 1:17  extra '上'@14 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "027003004": "但以理书 3:4  extra '的人'@16 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "027008002": "但以理书 8:2  extra '中'@18 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "027010013": "但以理书 10:13  extra '中的'@19 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "030008014": "阿摩司书 8:14  extra '牛犊'@7 '道'@46 '道'@51 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "033001013": "弥迦书 1:13  extra '的民'@15 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "033004008": "弥迦书 4:8  extra '城'@9 '民'@31 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "033004010": "弥迦书 4:10  extra '民'@3 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "033004013": "弥迦书 4:13  extra '民'@3 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "033005001": "弥迦书 5:1  extra '民'@3 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "036002014": "西番雅书 2:14  extra '的'@6 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "036003010": "西番雅书 3:10  extra '民'@11 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "038008023": "撒迦利亚书 8:23  extra '中'@24 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "040004005": "马太福音 4:5  extra '上'@15 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "040016025": "马太福音 16:25  extra '的'@9 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "040017027": "马太福音 17:27  extra '他们'@5 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "040021005": "马太福音 21:5  extra '居民'@5 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "040021009": "马太福音 21:9  extra '和散那'@10 '耶和华'@39 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "040024008": "马太福音 24:8  extra '的起头'@5 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "041009005": "马可福音 9:5  extra '拉比'@6 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "042004009": "路加福音 4:9  extra '上'@17 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "042009024": "路加福音 9:24  extra '的'@9 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "042009054": "路加福音 9:54  extra '耶稣'@14 '吗'@41 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "043008015": "约翰福音 8:15  extra '以外貌'@3 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "043019030": "约翰福音 19:30  extra '了尝了'@3 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "044002026": "使徒行传 2:26  extra '灵'@9 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "044013018": "使徒行传 13:18  extra '他们容忍'@6 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "044018024": "使徒行传 18:24  extra '的学问'@27 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "045007022": "罗马书 7:22  extra '意思'@8 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "046011024": "哥林多前书 11:24  extra '的舍'@17 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "046011030": "哥林多前书 11:30  extra '的'@18 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "047001020": "哥林多后书 1:20  extra '的'@26 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "048003013": "加拉太书 3:13  extra '了受'@7 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "048004006": "加拉太书 4:6  extra '的心你们'@18 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "048004017": "加拉太书 4:17  extra '离间你们'@15 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "049002021": "以弗所书 2:21  extra '各房'@0 '耶和华'@18 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "051001023": "歌罗西书 1:23  extra '被引动失去'@22 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "054003011": "提摩太前书 3:11  extra '女执事'@0 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "054006018": "提摩太前书 6:18  extra '人供给'@22 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "058004001": "希伯来书 4:1  extra '中间我们'@23 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "058007005": "希伯来书 7:5  extra '中身中'@40 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "058007010": "希伯来书 7:10  extra '中身'@25 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "058010038": "希伯来书 10:38  extra '义人'@2 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "059002007": "雅各书 2:7  extra '的尊名吗'@11 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "059004004": "雅各书 4:4  extra '淫乱的人'@4 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "060001012": "彼得前书 1:12  extra '的传讲'@13 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "062001004": "约翰一书 1:4  extra '的喜乐你们的'@13 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "063001008": "约翰二书 1:8  extra '所做的工你们'@11 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "066002023": "启示录 2:23  extra '党类'@7 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "066002027": "启示录 2:27  extra '他们'@7 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "066003002": "启示录 3:2  extra '的衰微'@13 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "066019015": "启示录 19:15  extra '他们'@22 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
    "066020008": "启示录 20:8  extra '的方'@9 — apparatus reformat (50dcc102 adoption, :2451), running text unchanged",
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
    # the four other PENDING ids (016001002, 016002019, 016003003, 025003001)
    # no longer read long at all — they surface as `gone` below, not here.
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

# What each EXPLAINED/PENDING id's `agreed` list (position, extra-substring
# pairs) reads as at the moment it was explained — generated from `compute()`
# at HEAD, not hand-typed. `changed_signatures()` re-derives the SAME id's
# CURRENT agreed list on every run and compares it against this: EXPLAINED/
# PENDING only ever suppressed a hit by its id, so a later defect at that
# same id (a genuinely new addition, unrelated to the reason it was
# explained) used to exit 0 silently. See docs/autonomous-queue.md:2512.
SIGNATURES = {
    "001048017": ((34, '的'),),
    "004011030": ((17, '了'),),
    "004021020": ((4, '了'),),
    "004032038": ((16, '西比玛'),),
    "005005006": ((0, '说'),),
    "005032020": ((0, '说'),),
    "007006026": ((4, '上'),),
    "009006019": ((11, '的他的原文是耶和华'),),
    "009025001": ((28, '里'),),
    "010011011": ((29, '的'),),
    "011002034": ((30, '里坟墓里'),),
    "011003004": ((18, '的'),),
    "013015013": ((28, '我们刑罚'),),
    "014030003": ((2, '间'),),
    "015001006": ((18, '帮助他们'),),
    "016003005": ((19, '担'),),
    "017006007": ((13, '人'),),
    "019009014": ((17, '的'),),
    "019010010": ((17, '之下'),),
    "019022020": ((16, '脱离'),),
    "019051010": ((20, '的'),),
    "019088004": ((13, '的人'),),
    "019106028": ((16, '的'), (19, '死')),
    "019140009": ((21, '自己陷害'),),
    "023014032": ((7, '的'),),
    "023016001": ((24, '的山城'),),
    "023022004": ((21, '的众民'),),
    "023033004": ((14, '尽禾稼吃'),),
    "023038017": ((18, '灵魂'),),
    "023041009": ((8, '来的领'),),
    "023044014": ((9, '树柞树'), (14, '作')),
    "023048014": ((10, '内中他们'),),
    "023049012": ((21, '国秦'),),
    "023055011": ((32, '的事上'),),
    "024003003": ((7, '雨'),),
    "024005006": ((14, '的晚上'),),
    "024006002": ((8, '女子'),),
    "024006026": ((1, '民'),),
    "024007014": ((7, '我'),),
    "024009001": ((21, '中百姓'),),
    "024030014": ((13, '你'),),
    "024030017": ((36, '的'),),
    "025003034": ((8, '在踹'),),
    "026001016": ((5, '颜色'),),
    "026014019": ((12, '灭命'),),
    "026023025": ((31, '的人遗留'),),
    "026026006": ((6, '居民'),),
    "026028010": ((14, '的人未受割礼'),),
    "026033022": ((16, '灵'),),
    "026040003": ((12, '如颜色'),),
    "026040044": ((22, '在南门旁'),),
    "026047010": ((21, '网之处晒网'),),
    "027001017": ((14, '上'),),
    "027003004": ((16, '的人'),),
    "027008002": ((18, '中'),),
    "027010013": ((19, '中的'),),
    "030008014": ((7, '牛犊'), (46, '道'), (51, '道')),
    "033001013": ((15, '的民'),),
    "033004008": ((9, '城'), (31, '民')),
    "033004010": ((3, '民'),),
    "033004013": ((3, '民'),),
    "033005001": ((3, '民'),),
    "036002014": ((6, '的'),),
    "036003010": ((11, '民'),),
    "038008014": ((27, '我'), (32, '原文有万军之耶和华说的')),
    "038008023": ((24, '中'),),
    "039002003": ((18, '在'),),
    "040004005": ((15, '上'),),
    "040016025": ((9, '的'),),
    "040017027": ((5, '他们'),),
    "040021005": ((5, '居民'),),
    "040021009": ((10, '和散那'), (39, '耶和华')),
    "040024008": ((5, '的起头'),),
    "041006033": ((19, '的'),),
    "041009005": ((6, '拉比'),),
    "042004009": ((17, '上'),),
    "042009024": ((9, '的'),),
    "042009054": ((14, '耶稣'), (41, '吗')),
    "043008015": ((3, '以外貌'),),
    "043019030": ((3, '了尝了'),),
    "044002026": ((9, '灵'),),
    "044013018": ((6, '他们容忍'),),
    "044018024": ((27, '的学问'),),
    "044023035": ((7, '也'),),
    "044024002": ((10, '开始控'),),
    "044024023": ((13, '要'),),
    "044025022": ((28, '他'),),
    "044028006": ((21, '看'),),
    "044028010": ((25, '东西'),),
    "045007022": ((8, '意思'),),
    "046011024": ((17, '的舍'),),
    "046011030": ((18, '的'),),
    "046015031": ((6, '们'),),
    "047001020": ((26, '的'),),
    "047002013": ((4, '我'),),
    "047006003": ((2, '在'),),
    "047007014": ((21, '们'),),
    "047008004": ((11, '服事'),),
    "047008006": ((3, '们'), (14, '就')),
    "047008015": ((19, '少'),),
    "047008023": ((20, '我们'),),
    "047009011": ((3, '在'),),
    "047012020": ((8, '发'), (21, '发')),
    "047013005": ((41, '面'),),
    "048003013": ((7, '了受'),),
    "048004006": ((18, '的心你们'),),
    "048004017": ((15, '离间你们'),),
    "049002021": ((0, '各房'), (18, '耶和华')),
    "051001023": ((22, '被引动失去'),),
    "054003011": ((0, '女执事'),),
    "054006018": ((22, '人供给'),),
    "058004001": ((23, '中间我们'),),
    "058007005": ((40, '中身中'),),
    "058007010": ((25, '中身'),),
    "058010038": ((2, '义人'),),
    "059002007": ((11, '的尊名吗'),),
    "059004004": ((4, '淫乱的人'),),
    "060001012": ((13, '的传讲'),),
    "062001004": ((13, '的喜乐你们的'),),
    "063001008": ((11, '所做的工你们'),),
    "066002023": ((7, '党类'),),
    "066002027": ((7, '他们'),),
    "066003002": ((13, '的衰微'),),
    "066019015": ((22, '他们'),),
    "066020008": ((9, '的方'),),
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

    `〔…〕` is the same apparatus, written as visible brackets instead of a
    `<note:…>` tag — this edition uses it for verse-merge markers
    (`〔见上节〕`) and manuscript-variant notes (`〔有古卷在此有36节…〕`), the
    same content `<note:…>` carries elsewhere. The 50dcc102 publisher-text
    adoption converted 72 of these from `<note:…>` to `〔…〕` without
    changing a single character inside; before this, a verse caught in that
    conversion read as a RUNNING hit (e.g. 042017036) purely because this
    function didn't know the second spelling, not because anything in the
    verse actually changed.
    """
    flags = []
    note = brackets = parens = lens = 0
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
        elif ch == "〔":
            lens += 1
        elif ch == "〕":
            lens = max(0, lens - 1)
        elif CJK.match(ch):
            flags.append(bool(note or brackets or parens or lens))
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


def compute():
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
    return ours, a, b, ids, apparatus, running


def signature(agreed):
    """Canonical, comparable form of a hit's `agreed` list — what an
    EXPLAINED/PENDING entry looked like at the moment it was explained, so a
    LATER run can tell a still-known id apart from one whose content quietly
    changed underneath the same id. Shared by both audits (imported into
    `audit_dropped_characters.py` alongside `apparatus_mask`) so the
    comparison is defined once, not forked."""
    return tuple(sorted(agreed))


def changed_signatures(known_ids, running, signatures):
    """Known ids whose CURRENT hit content no longer matches what was
    recorded when they were explained — a defect at an already-explained id,
    which `fresh` (keyed by id alone) cannot see.

    A known id with no recorded signature counts as changed too: EXPLAINED/
    PENDING entries added without a matching `SIGNATURES` entry would
    otherwise pass this check by omission, reopening the exact hole this
    function exists to close.
    """
    running_by_id = dict(running)
    changed = []
    for vid in sorted(known_ids):
        if vid not in running_by_id:
            continue
        current = signature(running_by_id[vid])
        if signatures.get(vid) != current:
            changed.append((vid, current))
    return changed


def main():
    ours, a, b, ids, apparatus, running = compute()

    known = EXPLAINED.keys() | PENDING.keys()
    fresh = [h for h in running if h[0] not in known]
    changed = changed_signatures(known, running, SIGNATURES)
    print(f"verses compared: {len(ids)}")
    print(f"we read more than both witnesses: {len(apparatus) + len(running)}")
    print(f"  editorial apparatus only: {len(apparatus)}")
    print(f"  in the running text: {len(running)}")
    print(f"    read and explained: {sum(1 for h in running if h[0] in EXPLAINED)} of {len(EXPLAINED)}")
    print(f"    awaiting the printed 1919: {sum(1 for h in running if h[0] in PENDING)} of {len(PENDING)}")
    print(f"    content changed at an explained/pending id: {len(changed)}")
    print(f"    NEW, unexamined: {len(fresh)}")
    for vid, agreed in fresh:
        r = ours[vid]
        extra = " ".join(f"{s!r}@{pos}" for pos, s in agreed)
        print(f"\n{vid}  {r['book']} {r['chapter']}:{r['verse']}   extra {extra}")
        print(f"  ours : {r['text']}")
        print(f"  A    : {a[vid]['text']}")
        print(f"  B    : {b[vid]['text']}")
    for vid, current in changed:
        r = ours[vid]
        extra = " ".join(f"{s!r}@{pos}" for pos, s in current)
        print(f"\nCHANGED {vid}  {r['book']} {r['chapter']}:{r['verse']}  now extra {extra}"
              f", not what was recorded: {EXPLAINED.get(vid) or PENDING[vid]}")

    # A known hit that stops appearing is drift too — the text moved under a
    # triage decision that was made by reading it.
    gone = sorted(known - {vid for vid, _ in running})
    for vid in gone:
        print(f"\n{vid} no longer reads long — update EXPLAINED/PENDING: "
              f"{EXPLAINED.get(vid) or PENDING[vid]}")
    return 1 if fresh or gone or changed else 0


if __name__ == "__main__":
    sys.exit(main())
