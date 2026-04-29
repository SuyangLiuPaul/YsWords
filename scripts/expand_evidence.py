#!/usr/bin/env python3
"""
Expand the bible_evidence dataset:
  1) Patch images on the 17 entries that ship with images: [].
  2) Append a curated set of NEW entries — every one with a Wikimedia
     Commons image URL and trilingual EN / 简 / 繁 copy.
  3) Re-stamp `_meta.count` and `_meta.generatedAt`.

Output: rewrites assets/bible_evidence.json in place. Run from repo root.

Image sourcing rule: every URL must be a stable upload.wikimedia.org
thumbnail under a Wikimedia Commons file page so the image is
public-domain / CC-BY-SA. No hot-linking arbitrary blogs.
"""
from __future__ import annotations

import datetime as _dt
import json
import os
import sys
from typing import Iterable

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DATA_PATH = os.path.join(ROOT, "assets", "bible_evidence.json")


# -----------------------------------------------------------------
# Image patches for entries that have empty images: []
# -----------------------------------------------------------------
PATCHES: dict[str, list[str]] = {
    "balaam_inscription": [
        "https://upload.wikimedia.org/wikipedia/commons/thumb/4/4c/Tell_Deir_Alla.jpg/640px-Tell_Deir_Alla.jpg",
    ],
    "nazareth_inscription": [
        "https://upload.wikimedia.org/wikipedia/commons/thumb/b/be/Nazareth_Inscription.jpg/512px-Nazareth_Inscription.jpg",
    ],
    "codex_sinaiticus": [
        "https://upload.wikimedia.org/wikipedia/commons/thumb/9/95/Codex_Sinaiticus%2C_Esther_2%2C13-3%2C2.jpg/640px-Codex_Sinaiticus%2C_Esther_2%2C13-3%2C2.jpg",
    ],
    "nash_papyrus": [
        "https://upload.wikimedia.org/wikipedia/commons/thumb/d/d6/Nash_Papyrus.jpg/640px-Nash_Papyrus.jpg",
    ],
    "murabba_at_scrolls": [
        "https://upload.wikimedia.org/wikipedia/commons/thumb/4/4f/Wadi_Murabbaat_caves.jpg/640px-Wadi_Murabbaat_caves.jpg",
    ],
    "nuzi_tablets": [
        "https://upload.wikimedia.org/wikipedia/commons/thumb/f/f2/Nuzi_tablet_dispute_over_inheritance.jpg/512px-Nuzi_tablet_dispute_over_inheritance.jpg",
    ],
    "nebo_sarsekim_tablet": [
        "https://upload.wikimedia.org/wikipedia/commons/thumb/a/a3/Nebo-Sarsekim_Tablet_BM_114789.jpg/512px-Nebo-Sarsekim_Tablet_BM_114789.jpg",
    ],
    "lmlk_seals": [
        "https://upload.wikimedia.org/wikipedia/commons/thumb/3/3a/LMLK_seal_drawing.png/512px-LMLK_seal_drawing.png",
    ],
    "tell_al_rimah_stele": [
        "https://upload.wikimedia.org/wikipedia/commons/thumb/5/55/Tell_al-Rimah_Stele_of_Adad-Nirari_III.jpg/420px-Tell_al-Rimah_Stele_of_Adad-Nirari_III.jpg",
    ],
    "nimrud_tablet_k3751": [
        "https://upload.wikimedia.org/wikipedia/commons/thumb/9/93/Tiglath-pileser_III_stele.jpg/420px-Tiglath-pileser_III_stele.jpg",
    ],
    "feeding_five_thousand_site": [
        "https://upload.wikimedia.org/wikipedia/commons/thumb/4/49/Bethsaida_excavation_site.jpg/640px-Bethsaida_excavation_site.jpg",
    ],
    "jacobs_well": [
        "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c6/Jacobs_Well_Bir_Yakub_Nablus.jpg/512px-Jacobs_Well_Bir_Yakub_Nablus.jpg",
    ],
    "ephesus_theater_artemis": [
        "https://upload.wikimedia.org/wikipedia/commons/thumb/2/29/Ephesus_Theatre_Selcuk_Izmir_Turkey.jpg/640px-Ephesus_Theatre_Selcuk_Izmir_Turkey.jpg",
    ],
    "prayer_of_nabonidus": [
        "https://upload.wikimedia.org/wikipedia/commons/thumb/6/61/4Q242_Prayer_of_Nabonidus.jpg/420px-4Q242_Prayer_of_Nabonidus.jpg",
    ],
    "solomon_six_chamber_gates": [
        "https://upload.wikimedia.org/wikipedia/commons/thumb/5/5a/Tel_Megiddo_six-chambered_gate.jpg/640px-Tel_Megiddo_six-chambered_gate.jpg",
    ],
    "triumphal_entry_jerusalem": [
        "https://upload.wikimedia.org/wikipedia/commons/thumb/0/06/Mount_of_Olives_with_view_of_Jerusalem.jpg/640px-Mount_of_Olives_with_view_of_Jerusalem.jpg",
    ],
    "paul_philippi_earthquake": [
        "https://upload.wikimedia.org/wikipedia/commons/thumb/e/e2/Philippi_BW_2017-10-05_12-51-23.jpg/640px-Philippi_BW_2017-10-05_12-51-23.jpg",
    ],
}


def _make(
    *,
    id: str,
    category: str,
    bible_books: list[str],
    timeline: str,
    discovery_date: str,
    location: str,
    scripture_reference: str,
    images: list[str],
    academic_sources: list[str],
    confidence_level: str,
    icon: str,
    title_en: str,
    title_zh_hans: str,
    title_zh_hant: str,
    summary_en: str,
    summary_zh_hans: str,
    summary_zh_hant: str,
    description_en: str,
    description_zh_hans: str,
    description_zh_hant: str,
    correlation_en: str,
    correlation_zh_hans: str,
    correlation_zh_hant: str,
) -> dict:
    """Build one evidence record in the canonical schema."""
    return {
        "id": id,
        "category": category,
        "bibleBooks": bible_books,
        "timeline": timeline,
        "discoveryDate": discovery_date,
        "location": location,
        "scriptureReference": scripture_reference,
        "images": images,
        "academicSources": academic_sources,
        "confidenceLevel": confidence_level,
        "icon": icon,
        "title": {"en": title_en, "zh-Hans": title_zh_hans, "zh-Hant": title_zh_hant},
        "summary": {
            "en": summary_en,
            "zh-Hans": summary_zh_hans,
            "zh-Hant": summary_zh_hant,
        },
        "description": {
            "en": description_en,
            "zh-Hans": description_zh_hans,
            "zh-Hant": description_zh_hant,
        },
        "scripturalCorrelation": {
            "en": correlation_en,
            "zh-Hans": correlation_zh_hans,
            "zh-Hant": correlation_zh_hant,
        },
    }


# -----------------------------------------------------------------
# New entries — each has at least one Wikimedia Commons image.
# -----------------------------------------------------------------
NEW_ENTRIES: list[dict] = [
    _make(
        id="taylor_prism",
        category="Archaeology",
        bible_books=["2 Kings", "Isaiah"],
        timeline="691 BCE",
        discovery_date="1830",
        location="British Museum, London",
        scripture_reference="2 Kings 18:13-16",
        images=[
            "https://upload.wikimedia.org/wikipedia/commons/thumb/8/86/Taylor_Prism-1.jpg/420px-Taylor_Prism-1.jpg",
        ],
        academic_sources=[
            "Luckenbill, D. D. The Annals of Sennacherib. University of Chicago Press, 1924.",
            "Grayson, A. K., and J. Novotny. The Royal Inscriptions of Sennacherib, King of Assyria. Eisenbrauns, 2012.",
        ],
        confidence_level="Definitive",
        icon="📜",
        title_en="Taylor Prism — Sennacherib's Annals of Hezekiah's Siege",
        title_zh_hans="泰勒棱柱——西拿基立围攻希西家年代记",
        title_zh_hant="泰勒稜柱——西拿基立圍攻希西家年代記",
        summary_en="Six-sided clay prism inscribed with King Sennacherib's own account of his 701 BCE campaign against Judah, naming Hezekiah of Jerusalem and tallying tribute paid — independently confirming 2 Kings 18:13-16.",
        summary_zh_hans="六面陶土棱柱，刻有亚述王西拿基立亲述公元前701年讨伐犹大的战役，明确提到耶路撒冷的希西家及所交贡赋，独立印证列王纪下18:13-16。",
        summary_zh_hant="六面陶土稜柱，刻有亞述王西拿基立親述公元前701年討伐猶大的戰役，明確提到耶路撒冷的希西家及所交貢賦，獨立印證列王紀下18:13-16。",
        description_en="The Taylor Prism, a hexagonal baked-clay cylinder roughly 38 cm tall, contains the most complete copy of Sennacherib's royal annals. It was found at Nineveh and acquired by Colonel Taylor in 1830, who sold it to the British Museum. Two near-identical copies exist (the Oriental Institute Prism in Chicago, and the Jerusalem Prism in the Israel Museum), giving scholars three independent witnesses to the same text.\n\nThe inscription describes the Assyrian conquest of forty-six fortified Judean cities and the tribute Hezekiah paid to escape destruction. Sennacherib boasts of shutting Hezekiah up 'like a caged bird' in Jerusalem — but pointedly never claims to have taken the city. The biblical narrative, written from Judah's side, attributes Jerusalem's deliverance to divine intervention (2 Kings 19:35-36).",
        description_zh_hans="泰勒棱柱是一件六面烘陶圆柱，高约38厘米，载有西拿基立王室年代记最完整的副本。它在尼尼微出土，1830年由泰勒上校购得，后转售大英博物馆。另有两件近似副本（芝加哥东方研究所的奥尔棱柱与以色列博物馆的耶路撒冷棱柱），构成对同一文本的三重独立见证。\n\n铭文记载亚述大军攻占犹大四十六座设防城邑，以及希西家为免毁灭所交的贡赋。西拿基立自夸将希西家「关在耶路撒冷如笼中之鸟」，却刻意未声称攻陷该城。圣经记载从犹大的视角解释了原因：耶路撒冷的得救乃出于神迹（列王纪下19:35-36）。",
        description_zh_hant="泰勒稜柱是一件六面烘陶圓柱，高約38厘米，載有西拿基立王室年代記最完整的副本。它在尼尼微出土，1830年由泰勒上校購得，後轉售大英博物館。另有兩件近似副本（芝加哥東方研究所的奧爾稜柱與以色列博物館的耶路撒冷稜柱），構成對同一文本的三重獨立見證。\n\n銘文記載亞述大軍攻佔猶大四十六座設防城邑，以及希西家為免毀滅所交的貢賦。西拿基立自誇將希西家「關在耶路撒冷如籠中之鳥」，卻刻意未聲稱攻陷該城。聖經記載從猶大的視角解釋了原因：耶路撒冷的得救乃出於神蹟（列王紀下19:35-36）。",
        correlation_en="The prism's tribute list — '30 talents of gold, 800 talents of silver' plus precious goods — closely matches 2 Kings 18:14, which records Hezekiah paying 30 talents of gold and 300 talents of silver. The tenfold discrepancy in silver may reflect Assyrian inflation of the figure or different valuation conventions; either way, the agreement on category and order of magnitude is striking. More telling is what Sennacherib does NOT claim: there is no Assyrian boast of conquering Jerusalem itself, perfectly aligned with the biblical account that the city was unexpectedly spared.",
        correlation_zh_hans="棱柱所列贡赋「金子三十他连得，银子八百他连得」并各种珍宝，与列王纪下18:14所载希西家所付「金子三十他连得，银子三百他连得」高度吻合。银量十倍之差可能源自亚述方面的夸大或计量惯例差异；但在贡品种类与数量级上的一致仍极为显著。更具意义的是西拿基立没有宣称攻下耶路撒冷——这与圣经记载该城蒙不期之拯救完全吻合。",
        correlation_zh_hant="稜柱所列貢賦「金子三十他連得，銀子八百他連得」並各種珍寶，與列王紀下18:14所載希西家所付「金子三十他連得，銀子三百他連得」高度吻合。銀量十倍之差可能源自亞述方面的誇大或計量慣例差異；但在貢品種類與數量級上的一致仍極為顯著。更具意義的是西拿基立沒有宣稱攻下耶路撒冷——這與聖經記載該城蒙不期之拯救完全吻合。",
    ),
    _make(
        id="behistun_inscription",
        category="History",
        bible_books=["Daniel", "Ezra", "Nehemiah", "Esther"],
        timeline="520-486 BCE",
        discovery_date="1835 (deciphered)",
        location="Mount Behistun, Kermanshah Province, Iran",
        scripture_reference="Ezra 6:1-12",
        images=[
            "https://upload.wikimedia.org/wikipedia/commons/thumb/3/35/Bisotun_Iran_Relief_Achamenid_Period.JPG/640px-Bisotun_Iran_Relief_Achamenid_Period.JPG",
        ],
        academic_sources=[
            "Schmitt, R. The Bisitun Inscriptions of Darius the Great. SOAS, 1991.",
            "Briant, P. From Cyrus to Alexander: A History of the Persian Empire. Eisenbrauns, 2002.",
        ],
        confidence_level="Definitive",
        icon="🏔️",
        title_en="Behistun Inscription — Darius I's Trilingual Royal Edict",
        title_zh_hans="贝希斯敦铭文——大流士一世的三语王诏",
        title_zh_hant="貝希斯敦銘文——大流士一世的三語王詔",
        summary_en="Massive trilingual cliff inscription (Old Persian, Elamite, Babylonian) commissioned by Darius the Great around 520 BCE. The Rosetta-like trilingual key to Akkadian decipherment, it confirms Persian imperial structure presupposed by Daniel, Ezra, and Esther.",
        summary_zh_hans="大流士一世约公元前520年所立的三语崖刻巨型铭文（古波斯语、埃兰语、巴比伦语）。其作用如同罗塞塔石之于亚述楔形文字之解读，并印证但以理书、以斯拉记与以斯帖记所预设的波斯帝国体制。",
        summary_zh_hant="大流士一世約公元前520年所立的三語崖刻巨型銘文（古波斯語、埃蘭語、巴比倫語）。其作用如同羅塞塔石之於亞述楔形文字之解讀，並印證但以理書、以斯拉記與以斯帖記所預設的波斯帝國體制。",
        description_en="Carved 100 metres up a cliff face on Mount Behistun in western Iran, the inscription is approximately 15 metres high and 25 metres wide. Darius the Great commissioned it to legitimize his accession after the murder of Bardiya. The text recounts his conquest of nineteen rebel kings and lists the satrapies of his empire.\n\nIts trilingual nature (Old Persian, Elamite, Akkadian/Babylonian) made it the foundational text for Henry Rawlinson's 1835-1847 decipherment of cuneiform — itself the breakthrough that opened up Mesopotamian and biblical archaeology. Without Behistun, no Sennacherib annals, no Cyrus Cylinder, no Babylonian Chronicles would be readable today.",
        description_zh_hans="铭文位于伊朗西部贝希斯敦山，刻于距地面约百米的悬崖之上，幅面高约15米、宽约25米。大流士一世在巴尔狄亚遇害后即位，立此以彰其王位的合法性。文本记述他平定十九位反叛之王，并列举帝国各行省。\n\n该铭文同时以古波斯语、埃兰语、巴比伦楔形文字（阿卡德语）刻成，正是这种三语对照，使罗林森（Henry Rawlinson）于1835—1847年破译楔形文字成为可能——这一突破开启了整个美索不达米亚及圣经考古学。若无贝希斯敦，西拿基立年代记、居鲁士圆柱、巴比伦编年史皆无从释读。",
        description_zh_hant="銘文位於伊朗西部貝希斯敦山，刻於距地面約百米的懸崖之上，幅面高約15米、寬約25米。大流士一世在巴爾狄亞遇害後即位，立此以彰其王位的合法性。文本記述他平定十九位反叛之王，並列舉帝國各行省。\n\n該銘文同時以古波斯語、埃蘭語、巴比倫楔形文字（阿卡德語）刻成，正是這種三語對照，使羅林森（Henry Rawlinson）於1835—1847年破譯楔形文字成為可能——這一突破開啟了整個美索不達米亞及聖經考古學。若無貝希斯敦，西拿基立年代記、居魯士圓柱、巴比倫編年史皆無從釋讀。",
        correlation_en="Behistun lists the Persian satrapies and royal protocol that the books of Ezra, Nehemiah, Esther and Daniel describe in everyday detail. Ezra 6:1-12 quotes a Persian royal decree authorizing the rebuilding of the Jerusalem temple, written in the formal style and bureaucratic structure that Behistun confirms as authentically Achaemenid. Critics had once doubted these biblical decrees as later inventions; the trilingual text shows the bureaucratic genre is exactly what an Achaemenid king would issue.",
        correlation_zh_hans="贝希斯敦所记的波斯行省制度与王室公文格式，正是以斯拉记、尼希米记、以斯帖记、但以理书所描绘的日常背景。以斯拉记6:1-12引用波斯王下令重建耶路撒冷圣殿的诏书，其正式公文体例与官僚架构，与贝希斯敦印证的阿契美尼德王朝形式完全一致。曾有学者怀疑圣经所载诏书出于后世杜撰；此三语铭文表明，这种公文风格正是该王朝所有的。",
        correlation_zh_hant="貝希斯敦所記的波斯行省制度與王室公文格式，正是以斯拉記、尼希米記、以斯帖記、但以理書所描繪的日常背景。以斯拉記6:1-12引用波斯王下令重建耶路撒冷聖殿的詔書，其正式公文體例與官僚架構，與貝希斯敦印證的阿契美尼德王朝形式完全一致。曾有學者懷疑聖經所載詔書出於後世杜撰；此三語銘文表明，這種公文風格正是該王朝所有的。",
    ),
    _make(
        id="bulla_gemariah_shaphan",
        category="Archaeology",
        bible_books=["Jeremiah"],
        timeline="late 7th century BCE",
        discovery_date="1982 (City of David)",
        location="Israel Museum, Jerusalem",
        scripture_reference="Jeremiah 36:10-12",
        images=[
            "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c2/Bulla_with_inscription_LeGemaryahu_ben_Shafan.jpg/420px-Bulla_with_inscription_LeGemaryahu_ben_Shafan.jpg",
        ],
        academic_sources=[
            "Shiloh, Y., and D. Tarler. 'Bullae from the City of David.' Biblical Archaeologist 49 (1986): 197-209.",
            "Avigad, N. Hebrew Bullae from the Time of Jeremiah. Israel Exploration Society, 1986.",
        ],
        confidence_level="Definitive",
        icon="🪧",
        title_en="Bulla of Gemariah son of Shaphan — Jeremiah's Royal Scribe",
        title_zh_hans="基玛利雅·沙番之子封泥——耶利米记中的王室文士",
        title_zh_hant="基瑪利雅·沙番之子封泥——耶利米記中的王室文士",
        summary_en="Clay bulla (seal impression) found in 1982 in the City of David, inscribed 'Belonging to Gemaryahu son of Shaphan' — naming a court scribe of Jehoiakim attested in Jeremiah 36 by the same patronymic.",
        summary_zh_hans="1982年在大卫城出土的陶土封泥，铭文「属基玛利雅·沙番之子」——正是耶利米书36章中约雅敬王朝的一位王室文士，父名相同。",
        summary_zh_hant="1982年在大衛城出土的陶土封泥，銘文「屬基瑪利雅·沙番之子」——正是耶利米書36章中約雅敬王朝的一位王室文士，父名相同。",
        description_en="Excavated by Yigal Shiloh in the City of David's 'House of the Bullae' — a chamber where the burned stratum preserved more than fifty seal impressions in fired clay. The Gemariah bulla measures about 1.5 cm across and bears clear paleo-Hebrew script: 'lgmryhw bn špn' ('Belonging to Gemaryahu son of Shaphan').\n\nGemariah son of Shaphan is named in Jeremiah 36:10-12 as one of the royal officials who heard Baruch read Jeremiah's scroll in the temple chamber and tried to dissuade King Jehoiakim from burning it. His brother Ahikam protected Jeremiah's life (Jeremiah 26:24); his father Shaphan had been Josiah's chief scribe (2 Kings 22:8-14). The dynasty's loyal-bureaucrat reputation in Jeremiah aligns precisely with the bullae record from this stratum.",
        description_zh_hans="此封泥由考古学家西洛（Yigal Shiloh）于大卫城「封泥之屋」出土。该室因被焚毁而保存了五十余件烘陶印迹。基玛利雅封泥直径约1.5厘米，刻有清晰的古希伯来文：「属基玛利雅·沙番之子」（lgmryhw bn špn）。\n\n基玛利雅·沙番之子见于耶利米书36:10-12，是约雅敬王朝的一位王室官员，他在圣殿厢房聆听巴录朗读耶利米的书卷，并劝阻王勿焚毁。其兄亚希甘曾保护耶利米性命（耶利米书26:24）；其父沙番乃约西亚王的首席文士（列王纪下22:8-14）。该家族在耶利米书中所表现的忠诚官僚形象，与此地层所出封泥群高度一致。",
        description_zh_hant="此封泥由考古學家西洛（Yigal Shiloh）於大衛城「封泥之屋」出土。該室因被焚毀而保存了五十餘件烘陶印跡。基瑪利雅封泥直徑約1.5厘米，刻有清晰的古希伯來文：「屬基瑪利雅·沙番之子」（lgmryhw bn špn）。\n\n基瑪利雅·沙番之子見於耶利米書36:10-12，是約雅敬王朝的一位王室官員，他在聖殿廂房聆聽巴錄朗讀耶利米的書卷，並勸阻王勿焚毀。其兄亞希甘曾保護耶利米性命（耶利米書26:24）；其父沙番乃約西亞王的首席文士（列王紀下22:8-14）。該家族在耶利米書中所表現的忠誠官僚形象，與此地層所出封泥群高度一致。",
        correlation_en="A seal impression of an obscure royal aide named only in Jeremiah, dug from the same Jerusalem destruction layer (586 BCE) the prophet predicted, with the exact patronymic given in Scripture, and preserved by the same fire that consumed the city — this is the kind of incidental, unforced confirmation that turns biblical narrative from literary tradition into documented history.",
        correlation_zh_hans="一位仅在耶利米书出现的不显赫王室官员的印迹，从他所预言的那次毁城（公元前586年）同一地层出土，父子名字与圣经完全一致，并因焚毁全城的同一场火而得以保存——这类非刻意、不可预设的证据，正是使圣经叙事从文学传统转为有据可查之历史的关键。",
        correlation_zh_hant="一位僅在耶利米書出現的不顯赫王室官員的印跡，從他所預言的那次毀城（公元前586年）同一地層出土，父子名字與聖經完全一致，並因焚毀全城的同一場火而得以保存——這類非刻意、不可預設的證據，正是使聖經敘事從文學傳統轉為有據可查之歷史的關鍵。",
    ),
    _make(
        id="ophel_inscription",
        category="Archaeology",
        bible_books=["1 Chronicles", "Nehemiah"],
        timeline="late 11th to mid-10th century BCE",
        discovery_date="2012 (Eilat Mazar)",
        location="Ophel, City of David, Jerusalem",
        scripture_reference="1 Chronicles 29:1; Nehemiah 3:26-27",
        images=[
            "https://upload.wikimedia.org/wikipedia/commons/thumb/9/96/Ophel_Pithos_Inscription.jpg/512px-Ophel_Pithos_Inscription.jpg",
        ],
        academic_sources=[
            "Mazar, E. The Ophel Excavations. Israel Exploration Society, 2015.",
            "Galil, G. 'A Concise Inscription from the Ophel Dating to the Tenth Century BCE.' Strata 31 (2013).",
        ],
        confidence_level="Strong",
        icon="🏺",
        title_en="Ophel Pithos Inscription — Earliest Hebrew at Jerusalem",
        title_zh_hans="俄斐勒陶罐铭文——耶路撒冷最早的希伯来文",
        title_zh_hant="俄斐勒陶罐銘文——耶路撒冷最早的希伯來文",
        summary_en="Fragmentary Hebrew inscription on a large storage jar, found in Eilat Mazar's 2012 excavation of the Ophel — the slope between the City of David and the Temple Mount. Dated to the time of David and Solomon, it is one of the earliest Hebrew inscriptions ever found in Jerusalem.",
        summary_zh_hans="2012年由考古学家伊拉特·马扎尔（Eilat Mazar）发掘的大型陶罐残片铭文，出自俄斐勒——大卫城与圣殿山之间的斜坡。年代约属大卫、所罗门时期，是耶路撒冷迄今所发现最早的希伯来文之一。",
        summary_zh_hant="2012年由考古學家伊拉特·馬扎爾（Eilat Mazar）發掘的大型陶罐殘片銘文，出自俄斐勒——大衛城與聖殿山之間的斜坡。年代約屬大衛、所羅門時期，是耶路撒冷迄今所發現最早的希伯來文之一。",
        description_en="The Ophel Pithos Inscription was incised into the shoulder of a large storage jar (pithos) before firing — meaning it was deliberately inscribed by the potter or a literate user at the moment of manufacture. Discovered in a sealed 10th-century BCE stratum, the surviving letters belong to the proto-Canaanite / early Hebrew script.\n\nThe reading is debated. Gershon Galil (Haifa) proposes 'יין חלק' ('cheap wine'), suggesting an administrative tax notation. Others read 'מ נחלק' ('belonging to the Negevite'). Whichever reading prevails, the existence of literate Hebrew administration in Jerusalem during the era of David and Solomon — once denied by minimalist scholars — is materially demonstrated.",
        description_zh_hans="俄斐勒陶罐铭文刻于一件大型储物陶罐（pithos）的肩部，且在烧制前刻写——表明陶工或识字使用者于制作时刻意所刻。出自封闭的公元前10世纪地层，残存字母属原迦南字母／早期希伯来文系统。\n\n释读尚有分歧：海法大学加里勒（Gershon Galil）主张读作「廉价酒」（יין חלק），可能是行政税务标记；另有学者读作「属南地人」（מ נחלק）。无论哪种释读，皆表明大卫、所罗门时代的耶路撒冷已存在可读写的希伯来文行政体系——这一点曾被极简派学者所否认，如今由实物明证支持。",
        description_zh_hant="俄斐勒陶罐銘文刻於一件大型儲物陶罐（pithos）的肩部，且在燒製前刻寫——表明陶工或識字使用者於製作時刻意所刻。出自封閉的公元前10世紀地層，殘存字母屬原迦南字母／早期希伯來文系統。\n\n釋讀尚有分歧：海法大學加里勒（Gershon Galil）主張讀作「廉價酒」（יין חלק），可能是行政稅務標記；另有學者讀作「屬南地人」（מ נחלק）。無論哪種釋讀，皆表明大衛、所羅門時代的耶路撒冷已存在可讀寫的希伯來文行政體系——這一點曾被極簡派學者所否認，如今由實物明證支持。",
        correlation_en="The Ophel is named in 1 Chronicles 29:1 (David's preparations for the Temple) and Nehemiah 3:26-27 (post-exilic wall repair), located between the City of David and the Temple Mount. The inscription's date and locale dovetail with the biblical picture of an organized Davidic-Solomonic administration in Jerusalem — exactly the period some scholars had argued left no archaeological trace.",
        correlation_zh_hans="俄斐勒一名见于历代志上29:1（大卫为圣殿所作准备）及尼希米记3:26-27（被掳归回后的修城工程），位置正介于大卫城与圣殿山之间。本铭文之时代与地点与圣经所记大卫—所罗门时期耶路撒冷已有规范行政体系的图景吻合——而这正是若干学者所质疑的「考古无迹」时代。",
        correlation_zh_hant="俄斐勒一名見於歷代志上29:1（大衛為聖殿所作準備）及尼希米記3:26-27（被擄歸回後的修城工程），位置正介於大衛城與聖殿山之間。本銘文之時代與地點與聖經所記大衛—所羅門時期耶路撒冷已有規範行政體系的圖景吻合——而這正是若干學者所質疑的「考古無跡」時代。",
    ),
    _make(
        id="stepped_stone_structure",
        category="Archaeology",
        bible_books=["2 Samuel", "1 Chronicles"],
        timeline="late Bronze / Iron I",
        discovery_date="1923-1925, 1978-1985",
        location="City of David, Jerusalem",
        scripture_reference="2 Samuel 5:9",
        images=[
            "https://upload.wikimedia.org/wikipedia/commons/thumb/8/82/StepStoneStructure_CityOfDavid_2010.jpg/640px-StepStoneStructure_CityOfDavid_2010.jpg",
        ],
        academic_sources=[
            "Mazar, E. Discovering the Solomonic Wall in Jerusalem. Shoham, 2011.",
            "Cahill, J. M. 'Jerusalem in the Time of the United Monarchy.' In Jerusalem in Bible and Archaeology, edited by Vaughn and Killebrew, 2003.",
        ],
        confidence_level="Strong",
        icon="🪨",
        title_en="Stepped Stone Structure — David's 'Millo' Foundation",
        title_zh_hans="阶梯石构——大卫的「米罗」基础",
        title_zh_hant="階梯石構——大衛的「米羅」基礎",
        summary_en="Massive stepped retaining wall on the eastern slope of the City of David, originally rising about 18 metres high. Identified by most archaeologists as the foundation of the royal acropolis David captured from the Jebusites and called the 'Millo' (terraced fill).",
        summary_zh_hans="大卫城东坡上一座规模宏大的阶梯式挡土墙，原高约18米。多数考古学家认定它即为大卫从耶布斯人手中夺取并称为「米罗」（夯填台基）之王城卫城的基础。",
        summary_zh_hant="大衛城東坡上一座規模宏大的階梯式擋土牆，原高約18米。多數考古學家認定它即為大衛從耶布斯人手中奪取並稱為「米羅」（夯填台基）之王城衛城的基礎。",
        description_en="First discovered by R. A. S. Macalister in the 1920s, then more thoroughly excavated by Kathleen Kenyon (1961-1967) and Yigal Shiloh (1978-1985), the Stepped Stone Structure consists of finely-fitted limestone blocks arranged in descending steps along the eastern slope of the original City of David. It rises from the Kidron Valley floor to support a flat platform above.\n\nThe structure is one of the largest single architectural features in pre-Herodian Jerusalem and required substantial centralized labour and planning — the kind of state-level infrastructure that minimalist critics had argued never existed in 10th-century BCE Israel. It directly supports the 'Large Stone Structure' identified by Eilat Mazar (2005) and is widely interpreted as the foundation of David's palace or the Jebusite citadel he captured.",
        description_zh_hans="此结构首次由麦卡利斯特（R. A. S. Macalister）于1920年代发现，后经凯瑟琳·凯尼恩（1961—1967）与西洛（1978—1985）系统发掘。它由精修的石灰石方块沿大卫城原址东坡阶梯下落排列，自汲沦谷底向上层平台支撑。\n\n该结构为前希律时期耶路撒冷最庞大的单体建筑遗存之一，所需的集中人力与统一规划，正是极简学派曾否认的「公元前10世纪以色列国家级基础设施」。它直接支撑伊拉特·马扎尔（2005年）所定义的「大石建筑」，被广泛解读为大卫王宫或被夺取的耶布斯卫城基础。",
        description_zh_hant="此結構首次由麥卡利斯特（R. A. S. Macalister）於1920年代發現，後經凱瑟琳·凱尼恩（1961—1967）與西洛（1978—1985）系統發掘。它由精修的石灰石方塊沿大衛城原址東坡階梯下落排列，自汲淪谷底向上層平台支撐。\n\n該結構為前希律時期耶路撒冷最龐大的單體建築遺存之一，所需的集中人力與統一規劃，正是極簡學派曾否認的「公元前10世紀以色列國家級基礎設施」。它直接支撐伊拉特·馬扎爾（2005年）所定義的「大石建築」，被廣泛解讀為大衛王宮或被奪取的耶布斯衛城基礎。",
        correlation_en="2 Samuel 5:9 says David captured the Jebusite stronghold and 'built the city around it, from the Millo (the supporting terraces) inward.' The Stepped Stone Structure, by its sheer scale and engineering, is exactly the kind of supporting terrace the Hebrew word 'millo' (literally 'fill') describes. Its dating to the very transition between the Jebusite and Davidic occupations is the strongest single piece of physical evidence for the historicity of David's capital.",
        correlation_zh_hans="撒母耳记下5:9记载大卫攻取耶布斯堡，并「从米罗（即支撑台基）以内修造城邑」。阶梯石构以其规模与工程方式，正是希伯来文「米罗」（直译「夯填」）一词所描述的支撑性夯土平台。该建筑年代恰处于耶布斯—大卫居住转折之间，是大卫王都历史性最坚实的实物证据之一。",
        correlation_zh_hant="撒母耳記下5:9記載大衛攻取耶布斯堡，並「從米羅（即支撐台基）以內修造城邑」。階梯石構以其規模與工程方式，正是希伯來文「米羅」（直譯「夯填」）一詞所描述的支撐性夯土平台。該建築年代恰處於耶布斯—大衛居住轉折之間，是大衛王都歷史性最堅實的實物證據之一。",
    ),
    _make(
        id="house_yhwh_arad_ostracon",
        category="Archaeology",
        bible_books=["1 Kings", "2 Kings"],
        timeline="early 6th century BCE",
        discovery_date="1967 (Aharoni)",
        location="Tel Arad, Negev, Israel",
        scripture_reference="1 Kings 8:13; 2 Kings 25:9",
        images=[
            "https://upload.wikimedia.org/wikipedia/commons/thumb/7/7b/Arad_ostracon_18.jpg/420px-Arad_ostracon_18.jpg",
        ],
        academic_sources=[
            "Aharoni, Y. Arad Inscriptions. Israel Exploration Society, 1981.",
            "Faigenbaum-Golovin, S. et al. 'Algorithmic Handwriting Analysis of Judah's Military Correspondence.' PNAS 113.17 (2016).",
        ],
        confidence_level="Definitive",
        icon="📜",
        title_en="Arad Ostracon No. 18 — 'House of YHWH' Reference",
        title_zh_hans="亚拉得陶片18号——「耶和华殿」字样",
        title_zh_hant="亞拉得陶片18號——「耶和華殿」字樣",
        summary_en="Hebrew ostracon from the late Judean fortress at Tel Arad explicitly mentioning the 'beth YHWH' (House of YHWH). One of the only pre-exilic inscriptions naming the Jerusalem temple by its biblical title.",
        summary_zh_hans="出自犹大王国晚期亚拉得军事要塞的希伯来文陶片，明确提及「耶和华殿」（בית יהוה）。这是少数在被掳前文献中以圣经名称提及耶路撒冷圣殿的铭文之一。",
        summary_zh_hant="出自猶大王國晚期亞拉得軍事要塞的希伯來文陶片，明確提及「耶和華殿」（בית יהוה）。這是少數在被擄前文獻中以聖經名稱提及耶路撒冷聖殿的銘文之一。",
        description_en="Discovered by Yohanan Aharoni in 1967 inside the priestly archive of Stratum VI at Tel Arad — a fortified Judean outpost in the Negev — Ostracon No. 18 is a brief military message addressed to a commander named Eliashib. The Hebrew phrase 'l'byt yhwh' ('to/for the House of YHWH') appears clearly in the surviving lines.\n\nMore than 100 ostraca were recovered from this destruction layer, dated by carbon-14 and ceramic typology to circa 600 BCE — the very years before Nebuchadnezzar's 586 BCE destruction of Jerusalem. Recent algorithmic handwriting analysis (PNAS 2016) demonstrated that at least six different scribes produced the corpus, indicating widespread literacy at this provincial garrison just before the exile.",
        description_zh_hans="1967年阿哈罗尼（Yohanan Aharoni）在亚拉得堡（位于内盖夫的犹大军事要塞）第VI地层的祭司档案中发现了陶片18号——一封致名叫以利亚实指挥官的简短军令。希伯来文「l'byt yhwh」（「给耶和华的殿」）字样在残存行中清晰可辨。\n\n该地层共出土逾百件陶片，碳14测年与陶器类型断代约为公元前600年——即尼布甲尼撒于公元前586年毁耶路撒冷前夕。2016年《美国科学院院刊》登载的算法笔迹分析表明，这批文献至少由六位不同书吏所写，显示被掳前夕该省级要塞已普及识字。",
        description_zh_hant="1967年阿哈羅尼（Yohanan Aharoni）在亞拉得堡（位於內蓋夫的猶大軍事要塞）第VI地層的祭司檔案中發現了陶片18號——一封致名叫以利亞實指揮官的簡短軍令。希伯來文「l'byt yhwh」（「給耶和華的殿」）字樣在殘存行中清晰可辨。\n\n該地層共出土逾百件陶片，碳14測年與陶器類型斷代約為公元前600年——即尼布甲尼撒於公元前586年毀耶路撒冷前夕。2016年《美國科學院院刊》登載的算法筆跡分析表明，這批文獻至少由六位不同書吏所寫，顯示被擄前夕該省級要塞已普及識字。",
        correlation_en="The phrase 'House of YHWH' for the Jerusalem temple is the standard biblical designation (1 Kings 8:13, repeatedly throughout 1-2 Kings). Critics had argued the temple's prominence was a post-exilic literary projection. The Arad ostracon shows the title was in everyday administrative use — including on military pay records routed through the temple — generations BEFORE the exile, exactly as the biblical narrative requires.",
        correlation_zh_hans="「耶和华殿」是圣经对耶路撒冷圣殿的标准称谓（列王纪上8:13，列王纪上下书反复出现）。曾有学者认为圣殿的中心地位乃被掳后的文学投影。亚拉得陶片证明，该称谓在被掳前数代已是日常行政用语——甚至出现在通过圣殿核算的军饷记录中——与圣经记载完全吻合。",
        correlation_zh_hant="「耶和華殿」是聖經對耶路撒冷聖殿的標準稱謂（列王紀上8:13，列王紀上下書反覆出現）。曾有學者認為聖殿的中心地位乃被擄後的文學投影。亞拉得陶片證明，該稱謂在被擄前數代已是日常行政用語——甚至出現在通過聖殿核算的軍餉記錄中——與聖經記載完全吻合。",
    ),
    _make(
        id="house_of_caiaphas",
        category="Archaeology",
        bible_books=["Matthew", "Luke", "John"],
        timeline="1st century CE",
        discovery_date="1990 (Akeldama)",
        location="Peace Forest, Jerusalem",
        scripture_reference="Matthew 26:57-68",
        images=[
            "https://upload.wikimedia.org/wikipedia/commons/thumb/4/4e/Caiaphas_Ossuary_Israel_Museum.jpg/512px-Caiaphas_Ossuary_Israel_Museum.jpg",
        ],
        academic_sources=[
            "Greenhut, Z. 'The Caiaphas Tomb in North Talpiyot, Jerusalem.' Atiqot 21 (1992).",
            "Reich, R. 'Ossuary Inscriptions of the Caiaphas Family from Jerusalem.' Jerusalem Perspective 4 (1992).",
        ],
        confidence_level="Definitive",
        icon="🪦",
        title_en="Caiaphas Family Tomb — High Priest of Jesus' Trial",
        title_zh_hans="该亚法家族墓——审判耶稣的大祭司",
        title_zh_hant="該亞法家族墓——審判耶穌的大祭司",
        summary_en="Family tomb accidentally exposed by road work in south Jerusalem in 1990, containing twelve ossuaries — two inscribed with variants of the name 'Joseph son of Caiaphas,' the high priest who presided over Jesus' trial.",
        summary_zh_hans="1990年耶路撒冷南部修路时意外发掘出的家族墓室，内有十二件骨匣——两件刻有「约瑟·该亚法之子」的不同写法，正是审判耶稣的大祭司之名。",
        summary_zh_hant="1990年耶路撒冷南部修路時意外發掘出的家族墓室，內有十二件骨匣——兩件刻有「約瑟·該亞法之子」的不同寫法，正是審判耶穌的大祭司之名。",
        description_en="Discovered when bulldozers cut into a hillside in the Peace Forest near Akeldama, the tomb consists of a single rock-cut chamber with four burial niches (kokhim). Twelve limestone ossuaries were recovered — among them an ornate one bearing the Aramaic inscription 'Yehosef bar Qayafa' ('Joseph son of Caiaphas') and a simpler one reading 'Qayafa' alone.\n\nThe ornate ossuary contained the bones of a man around 60 years old, consistent with the lifetime of Caiaphas, who served as high priest from 18-36 CE. While some scholars debate whether the ornate ossuary belongs to the same Joseph Caiaphas mentioned by Josephus and the Gospels (Caiaphas being a family name), the consensus identification has stood for thirty years.",
        description_zh_hans="此墓系1990年于耶路撒冷亚革大马附近的「和平之林」修建道路时由推土机切坡发现。墓室为单一岩凿厅堂，四壁凿有四个骨龛（kokhim）。共出土十二件石灰石骨匣，其中一件装饰华丽，刻有亚兰文铭文「约瑟·该亚法之子」（Yehosef bar Qayafa），另一件较为朴素，仅刻「该亚法」三字。\n\n华丽的骨匣盛装一名年约六十岁男性的骸骨，与公元18—36年间任大祭司的该亚法之生平相符。虽然部分学者质疑此即福音书与约瑟夫所记之约瑟·该亚法（因「该亚法」可能为家族名），但学界主流共识三十年来一致认同此鉴定。",
        description_zh_hant="此墓係1990年於耶路撒冷亞革大馬附近的「和平之林」修建道路時由推土機切坡發現。墓室為單一巖鑿廳堂，四壁鑿有四個骨龕（kokhim）。共出土十二件石灰石骨匣，其中一件裝飾華麗，刻有亞蘭文銘文「約瑟·該亞法之子」（Yehosef bar Qayafa），另一件較為樸素，僅刻「該亞法」三字。\n\n華麗的骨匣盛裝一名年約六十歲男性的骸骨，與公元18—36年間任大祭司的該亞法之生平相符。雖然部分學者質疑此即福音書與約瑟夫所記之約瑟·該亞法（因「該亞法」可能為家族名），但學界主流共識三十年來一致認同此鑑定。",
        correlation_en="Matthew 26:57 names Caiaphas as the high priest who interrogated Jesus the night of His arrest. Until 1990 no extra-biblical artifact named Caiaphas, fueling skeptical claims of New Testament historical embellishment. The ossuary inscription is the only physical artifact ever recovered that bears the name of an individual present at the trial of Jesus — alongside the Pilate Inscription discovered in 1961, it makes two of the principal figures in the Gospel passion narrative archaeologically attested.",
        correlation_zh_hans="马太福音26:57记载夜审耶稣的大祭司名为该亚法。在1990年之前，无任何圣经外文物提到该亚法之名，曾被怀疑论者引为「新约历史夸大」的论据。本骨匣铭文是迄今唯一一件出土文物，记载一位曾出席审判耶稣之人的姓名；连同1961年发现的彼拉多铭文，福音书受难叙事中的两位主要人物均已获考古佐证。",
        correlation_zh_hant="馬太福音26:57記載夜審耶穌的大祭司名為該亞法。在1990年之前，無任何聖經外文物提到該亞法之名，曾被懷疑論者引為「新約歷史誇大」的論據。本骨匣銘文是迄今唯一一件出土文物，記載一位曾出席審判耶穌之人的姓名；連同1961年發現的彼拉多銘文，福音書受難敘事中的兩位主要人物均已獲考古佐證。",
    ),
    _make(
        id="ekron_yahweh_dedication",
        category="Archaeology",
        bible_books=["Joshua", "Judges", "1 Samuel"],
        timeline="7th century BCE",
        discovery_date="1996",
        location="Tel Miqne (Ekron), Israel",
        scripture_reference="Joshua 13:3; 1 Samuel 5:10",
        images=[
            "https://upload.wikimedia.org/wikipedia/commons/thumb/2/2b/Ekron_inscription.jpg/512px-Ekron_inscription.jpg",
        ],
        academic_sources=[
            "Gitin, S., T. Dothan, and J. Naveh. 'A Royal Dedicatory Inscription from Ekron.' Israel Exploration Journal 47 (1997).",
        ],
        confidence_level="Definitive",
        icon="🏛️",
        title_en="Ekron Royal Dedication — Five Philistine Kings Named",
        title_zh_hans="以革伦王室献辞——非利士五王列名",
        title_zh_hant="以革倫王室獻辭——非利士五王列名",
        summary_en="A 7th-century BCE Phoenician-script inscription on a limestone block from the Ekron temple, naming five generations of Ekron's rulers — including 'Padi' and 'Akish,' Philistine king-names corroborated in Sennacherib's annals and 1 Samuel 21.",
        summary_zh_hans="出自以革伦神庙的腓尼基字体石灰石铭文，年代为公元前7世纪，列出以革伦五代王名——包括「帕底」与「亚吉」，与西拿基立年代记及撒母耳记上21章所记的非利士王名相互印证。",
        summary_zh_hant="出自以革倫神廟的腓尼基字體石灰石銘文，年代為公元前7世紀，列出以革倫五代王名——包括「帕底」與「亞吉」，與西拿基立年代記及撒母耳記上21章所記的非利士王名相互印證。",
        description_en="Recovered in situ in 1996 from the destruction layer of a temple at Tel Miqne (the biblical Ekron), the dedication inscription is incised on a 60-cm-wide limestone block that once served as part of the temple's architectural fabric. Excavators Trude Dothan and Seymour Gitin uncovered it during the joint Albright Institute / Hebrew University expedition.\n\nFive lines list the temple's builder Akish (Achish), son of Padi, son of Ysd, son of Ada, son of Ya'ir — five generations of Ekron's royal house dedicating the temple to the goddess Ptgyh. The script is Phoenician/Old Hebrew, and the language is Phoenician. Padi appears in Sennacherib's annals as the Ekron king allied with Hezekiah; Akish (Hebrew Achish) is also a known Philistine name from David's narrative.",
        description_zh_hans="1996年在原位（in situ）发掘，出自米格内丘（圣经以革伦）一座神庙的毁坏地层，刻于宽约60厘米的石灰石块，原属神庙建筑构件。本品由阿尔布赖特研究院与希伯来大学联合考察队的多坦（Trude Dothan）与吉廷（Seymour Gitin）所发掘。\n\n五行铭文列出神庙建造者亚吉（Akish），其父帕底，其祖伊塞德，其曾祖阿达，其高祖雅伊尔——以革伦王室五代献此神庙于女神普特吉雅（Ptgyh）。字体为腓尼基／古希伯来字母，文体为腓尼基语。帕底见于西拿基立年代记，是与希西家结盟的以革伦王；亚吉则在大卫故事中出现，亦为非利士王名。",
        description_zh_hant="1996年在原位（in situ）發掘，出自米格內丘（聖經以革倫）一座神廟的毀壞地層，刻於寬約60厘米的石灰石塊，原屬神廟建築構件。本品由阿爾布賴特研究院與希伯來大學聯合考察隊的多坦（Trude Dothan）與吉廷（Seymour Gitin）所發掘。\n\n五行銘文列出神廟建造者亞吉（Akish），其父帕底，其祖伊塞德，其曾祖阿達，其高祖雅伊爾——以革倫王室五代獻此神廟於女神普特吉雅（Ptgyh）。字體為腓尼基／古希伯來字母，文體為腓尼基語。帕底見於西拿基立年代記，是與希西家結盟的以革倫王；亞吉則在大衛故事中出現，亦為非利士王名。",
        correlation_en="Ekron is one of the five chief Philistine cities (Joshua 13:3; 1 Samuel 6:17) and the site to which the captured Ark of the Covenant was sent in 1 Samuel 5:10. The royal dedication corroborates: Ekron's existence as a Philistine royal city; its temple-based religion; and the use of West-Semitic personal names like Achish/Akish that the Bible places in the same era. It is the most extensive royal Philistine inscription ever recovered.",
        correlation_zh_hans="以革伦是非利士五大城之一（约书亚记13:3；撒母耳记上6:17），也是约柜被掳后送往的城邑之一（撒母耳记上5:10）。本王室献辞印证：以革伦作为非利士王城的存在；神庙宗教体系；以及与圣经同期所载亚吉等西闪族人名的使用习俗。这是迄今出土最完整的非利士王室铭文。",
        correlation_zh_hant="以革倫是非利士五大城之一（約書亞記13:3；撒母耳記上6:17），也是約櫃被擄後送往的城邑之一（撒母耳記上5:10）。本王室獻辭印證：以革倫作為非利士王城的存在；神廟宗教體系；以及與聖經同期所載亞吉等西閃族人名的使用習俗。這是迄今出土最完整的非利士王室銘文。",
    ),
    _make(
        id="bulla_isaiah_prophet",
        category="Archaeology",
        bible_books=["Isaiah", "2 Kings"],
        timeline="late 8th century BCE",
        discovery_date="2018 (Eilat Mazar)",
        location="Ophel, Jerusalem",
        scripture_reference="2 Kings 19-20; Isaiah 37-39",
        images=[
            "https://upload.wikimedia.org/wikipedia/commons/thumb/8/8a/Isaiah_bulla.jpg/420px-Isaiah_bulla.jpg",
        ],
        academic_sources=[
            "Mazar, E. 'Is This the Prophet Isaiah's Signature?' Biblical Archaeology Review 44.2/3 (2018).",
        ],
        confidence_level="Strong",
        icon="🪧",
        title_en="Possible Isaiah Bulla — Seal Impression Near the Hezekiah Bulla",
        title_zh_hans="疑似以赛亚封泥——与希西家封泥相邻出土",
        title_zh_hant="疑似以賽亞封泥——與希西家封泥相鄰出土",
        summary_en="Damaged clay bulla excavated by Eilat Mazar at the Ophel in 2018, reading 'Yesha'yahu [n]vy' — possibly 'Isaiah the prophet' — found just three metres from a confirmed bulla of King Hezekiah.",
        summary_zh_hans="2018年伊拉特·马扎尔在俄斐勒发掘的破损封泥，铭文为「Yesha'yahu [n]vy」——或可释作「先知以赛亚」——出土位置距已确认的希西家王封泥仅三米。",
        summary_zh_hant="2018年伊拉特·馬扎爾在俄斐勒發掘的破損封泥，銘文為「Yesha'yahu [n]vy」——或可釋作「先知以賽亞」——出土位置距已確認的希西家王封泥僅三米。",
        description_en="The bulla is fragmentary and the final letter of the second word is missing or unclear. Two readings compete: 'lyšʿyhw nvy' ('Belonging to Isaiah the prophet,' if the missing aleph is restored) or 'lyšʿyhw nvy[h]' (a personal name plus a placename or family name). Eilat Mazar (1956-2021), the Hebrew University archaeologist who led the Ophel excavation, argued strongly for the first reading.\n\nIts proximity to the bulla of King Hezekiah — discovered in the same closed locus, in 2009, by the same expedition — makes the case unusually compelling: King Hezekiah and the prophet Isaiah are paired throughout 2 Kings 19-20 and Isaiah 36-39, and to find their seal impressions in the same room of the same destruction stratum is, at minimum, a remarkable coincidence.",
        description_zh_hans="该封泥已残缺，第二个词末字母缺失或模糊。学界存在两种释读：「lyšʿyhw nvy」（若补回缺失的辅音א，可作「属先知以赛亚」）或「lyšʿyhw nvy[h]」（人名 + 地名／家族名）。希伯来大学的伊拉特·马扎尔（1956—2021）作为俄斐勒发掘领队，强烈主张前一释读。\n\n本品与已确认的希西家王封泥（同一封闭遗址，由同一考察队2009年发现）相距不足三米。希西家与先知以赛亚在列王纪下19—20章及以赛亚书36—39章中始终并列出现；二人封泥见于同一毁坏地层的同一房间，至少属高度引人注目的巧合。",
        description_zh_hant="該封泥已殘缺，第二個詞末字母缺失或模糊。學界存在兩種釋讀：「lyšʿyhw nvy」（若補回缺失的輔音א，可作「屬先知以賽亞」）或「lyšʿyhw nvy[h]」（人名 + 地名／家族名）。希伯來大學的伊拉特·馬扎爾（1956—2021）作為俄斐勒發掘領隊，強烈主張前一釋讀。\n\n本品與已確認的希西家王封泥（同一封閉遺址，由同一考察隊2009年發現）相距不足三米。希西家與先知以賽亞在列王紀下19—20章及以賽亞書36—39章中始終並列出現；二人封泥見於同一毀壞地層的同一房間，至少屬高度引人注目的巧合。",
        correlation_en="2 Kings 19:1-7 records King Hezekiah sending messengers to Isaiah the prophet during the Assyrian siege; the king and the prophet collaborate throughout chapters 19-20. If the 'prophet' reading of the bulla is accurate, this is the closest physical link to a named Hebrew prophet ever found — a 'signature' from the very prophetic ministry that produced the most-quoted prophetic book in the New Testament.",
        correlation_zh_hans="列王纪下19:1-7记载，亚述围城之际希西家王差人请先知以赛亚求问神；二人在第19—20章中通力协作。若「先知」之读法成立，本封泥即为迄今所发现与某位具名希伯来先知最直接的实物联系——来自圣经中被新约引用次数最多的那卷先知书的作者亲笔的「签名」。",
        correlation_zh_hant="列王紀下19:1-7記載，亞述圍城之際希西家王差人請先知以賽亞求問神；二人在第19—20章中通力協作。若「先知」之讀法成立，本封泥即為迄今所發現與某位具名希伯來先知最直接的實物聯繫——來自聖經中被新約引用次數最多的那卷先知書的作者親筆的「簽名」。",
    ),
    _make(
        id="house_of_peter_capernaum_octagonal",
        category="Archaeology",
        bible_books=["Matthew", "Mark", "Luke"],
        timeline="1st century CE (with later overlay)",
        discovery_date="1968 (Corbo & Loffreda)",
        location="Capernaum, Sea of Galilee",
        scripture_reference="Mark 1:29-31; Matthew 8:14-17",
        images=[
            "https://upload.wikimedia.org/wikipedia/commons/thumb/c/c5/Capernaum_BW_15.JPG/640px-Capernaum_BW_15.JPG",
        ],
        academic_sources=[
            "Loffreda, S. Recovering Capharnaum. Studium Biblicum Franciscanum, 1985.",
            "Strange, J. F., and H. Shanks. 'Has the House Where Jesus Stayed in Capernaum Been Found?' Biblical Archaeology Review 8.6 (1982).",
        ],
        confidence_level="Strong",
        icon="🏚️",
        title_en="Octagonal Memorial over Peter's House — Capernaum",
        title_zh_hans="迦百农彼得家上方的八角形纪念堂",
        title_zh_hant="迦百農彼得家上方的八角形紀念堂",
        summary_en="A 1st-century CE house at Capernaum, modified for early Christian veneration in the late 1st century and surmounted by a Byzantine octagonal church around 450 CE — the standard Byzantine architectural marker for sites memorializing key figures in Jesus' ministry.",
        summary_zh_hans="迦百农一栋公元1世纪民居，自1世纪末改建为早期基督徒纪念之处，约公元450年其上加建拜占庭八角形教堂——拜占庭时代专用以纪念耶稣事工核心场所的标志性建筑形式。",
        summary_zh_hant="迦百農一棟公元1世紀民居，自1世紀末改建為早期基督徒紀念之處，約公元450年其上加建拜占庭八角形教堂——拜占庭時代專用以紀念耶穌事工核心場所的標誌性建築形式。",
        description_en="The Italian Franciscan archaeologists Virgilio Corbo and Stanislao Loffreda excavated the site between 1968 and 1985. Beneath the 5th-century octagonal church and the 4th-century domus ecclesiae they uncovered a single-room basalt house from the early Roman period (1st century BCE - 1st century CE).\n\nThe walls of this room had been re-plastered repeatedly in early antiquity, and the plaster bears more than 130 graffiti inscriptions in Greek, Aramaic, Syriac and Latin — including invocations of Jesus and references to Peter. The graffiti and the otherwise abnormal architectural sequence (private house → modified house-church → octagonal memorial) are unique among 1st-century Capernaum dwellings, indicating early Christian veneration of this specific dwelling.",
        description_zh_hans="意大利方济各会考古学家科尔波（Virgilio Corbo）与洛弗雷达（Stanislao Loffreda）于1968—1985年间发掘此址。在公元5世纪八角教堂与4世纪「家庭教会」（domus ecclesiae）层位之下，发现一栋早期罗马时期（公元前1世纪至公元1世纪）的单室玄武岩民居。\n\n该室墙面在古代多次以灰泥重新粉刷，灰泥层中保存逾130条希腊文、亚兰文、叙利亚文与拉丁文涂写铭文——包括对耶稣的呼求与对彼得的提及。这些铭文及其异常的建筑沿革（民居→改建为家庭教会→八角纪念堂）在迦百农1世纪民居中独此一例，显示早期基督徒对此一具体住宅的特别敬仰。",
        description_zh_hant="意大利方濟各會考古學家科爾波（Virgilio Corbo）與洛弗雷達（Stanislao Loffreda）於1968—1985年間發掘此址。在公元5世紀八角教堂與4世紀「家庭教會」（domus ecclesiae）層位之下，發現一棟早期羅馬時期（公元前1世紀至公元1世紀）的單室玄武岩民居。\n\n該室牆面在古代多次以灰泥重新粉刷，灰泥層中保存逾130條希臘文、亞蘭文、敘利亞文與拉丁文塗寫銘文——包括對耶穌的呼求與對彼得的提及。這些銘文及其異常的建築沿革（民居→改建為家庭教會→八角紀念堂）在迦百農1世紀民居中獨此一例，顯示早期基督徒對此一具體住宅的特別敬仰。",
        correlation_en="Mark 1:29 places Peter and Andrew's house at Capernaum and records Jesus healing Peter's mother-in-law there. Matthew 8:14 confirms the location. The 4th-century pilgrim Egeria's diary mentions an existing 'House of the Prince of the Apostles' at Capernaum that had been turned into a church — matching the archaeological sequence exactly. Few Gospel sites have a comparable continuous chain of Christian veneration tracing back to the apostolic generation.",
        correlation_zh_hans="马可福音1:29记彼得与安得烈在迦百农的家，耶稣在此医治了彼得的岳母；马太福音8:14亦印证地点。公元4世纪朝圣者埃格里亚（Egeria）日记提及迦百农当时已存在一处由民居改建的「使徒之首宅」教堂——恰与考古所揭沿革吻合。福音故事中能上溯至使徒时代且具连续基督徒敬仰链的圣地寥寥无几，此址即其一。",
        correlation_zh_hant="馬可福音1:29記彼得與安得烈在迦百農的家，耶穌在此醫治了彼得的岳母；馬太福音8:14亦印證地點。公元4世紀朝聖者埃格里亞（Egeria）日記提及迦百農當時已存在一處由民居改建的「使徒之首宅」教堂——恰與考古所揭沿革吻合。福音故事中能上溯至使徒時代且具連續基督徒敬仰鏈的聖地寥寥無幾，此址即其一。",
    ),
    _make(
        id="khirbet_qeiyafa_fortress",
        category="Archaeology",
        bible_books=["1 Samuel", "2 Samuel"],
        timeline="early 10th century BCE",
        discovery_date="2007-2013 (Garfinkel)",
        location="Elah Valley, Israel",
        scripture_reference="1 Samuel 17:1-3, 52",
        images=[
            "https://upload.wikimedia.org/wikipedia/commons/thumb/0/05/Khirbet_Qeiyafa_western_gate.jpg/640px-Khirbet_Qeiyafa_western_gate.jpg",
        ],
        academic_sources=[
            "Garfinkel, Y., S. Ganor, and M. Hasel. In the Footsteps of King David. Thames & Hudson, 2018.",
            "Garfinkel, Y. 'The Iron Age Fortified City of Khirbet Qeiyafa.' Tel Aviv 36 (2009).",
        ],
        confidence_level="Strong",
        icon="🏰",
        title_en="Khirbet Qeiyafa — Fortified Judean Border City of David's Era",
        title_zh_hans="基爱法山丘——大卫时代的犹大设防边城",
        title_zh_hant="基愛法山丘——大衛時代的猶大設防邊城",
        summary_en="An early 10th-century BCE fortified town overlooking the Elah Valley — the location of the David-and-Goliath narrative — with a casemate wall, two gates, monumental urban planning, and the earliest known Hebrew ostracon yet found.",
        summary_zh_hans="俯瞰以拉谷（大卫与歌利亚故事发生地）的公元前10世纪初设防小城，城墙为双层套式（casemate）结构，设有两座城门，规划具纪念性，并出土迄今所知最早的希伯来文陶片。",
        summary_zh_hant="俯瞰以拉谷（大衛與歌利亞故事發生地）的公元前10世紀初設防小城，城牆為雙層套式（casemate）結構，設有兩座城門，規劃具紀念性，並出土迄今所知最早的希伯來文陶片。",
        description_en="Excavated 2007-2013 by Yosef Garfinkel of Hebrew University, Khirbet Qeiyafa sits on a hilltop above the Elah Valley directly opposite the Philistine border. Radiocarbon dating of olive pits places its single fortified phase squarely between 1020-980 BCE — the era of Saul and the young David.\n\nThe site features a 700-metre casemate wall, a two-gated layout (the only known Iron Age city with two gates besides those in the United Monarchy texts), an administrative quarter, and significant olive-oil and grain storage. No pig bones were recovered, contrasting with contemporary Philistine sites and consistent with a Judean ethnic profile. A pottery fragment bearing five lines of proto-Hebrew was found in 2008 — the earliest Hebrew text yet known.",
        description_zh_hans="2007—2013年由希伯来大学加芬克尔（Yosef Garfinkel）主持发掘，基爱法山丘位于以拉谷之上、正对非利士边境。橄榄核碳14测年将其唯一的设防期严格定于公元前1020—980年——正值扫罗与少年大卫时代。\n\n遗址包含长达700米的双层套式城墙、双门规划（除联合王国时期文献所载之城邑外，唯一已知的双门铁器时代城邑）、行政区，以及大量橄榄油与谷物储仓。未发现猪骨，与同期非利士遗址形成对比，符合犹大人的族群特征。2008年出土一块陶片，刻有五行原希伯来文，为迄今所知最早的希伯来文献。",
        description_zh_hant="2007—2013年由希伯來大學加芬克爾（Yosef Garfinkel）主持發掘，基愛法山丘位於以拉谷之上、正對非利士邊境。橄欖核碳14測年將其唯一的設防期嚴格定於公元前1020—980年——正值掃羅與少年大衛時代。\n\n遺址包含長達700米的雙層套式城牆、雙門規劃（除聯合王國時期文獻所載之城邑外，唯一已知的雙門鐵器時代城邑）、行政區，以及大量橄欖油與穀物儲倉。未發現豬骨，與同期非利士遺址形成對比，符合猶大人的族群特徵。2008年出土一塊陶片，刻有五行原希伯來文，為迄今所知最早的希伯來文獻。",
        correlation_en="1 Samuel 17:1-3 places the Israelite-Philistine standoff in the Elah Valley between Socoh and Azekah; Khirbet Qeiyafa sits on the strategic ridge above this valley. Its single short-lived fortified phase aligns precisely with the United Monarchy and demonstrates a centralized Judean state with the engineering capacity, written language, and ethno-religious markers (kosher diet, no Philistine cult objects) the biblical narrative requires for David's era — directly counter to skeptical claims that 10th-century Judah lacked statehood.",
        correlation_zh_hans="撒母耳记上17:1-3记载以色列与非利士两军在梭哥与亚西加之间的以拉谷对峙；基爱法山丘正位于此谷上方的战略山脊。其唯一一段短暂设防期与联合王国时期完全吻合，并展现出大卫时代圣经所要求的：集中化犹大国家政权、工程能力、文字传统、族群与宗教标记（守洁食条例、未见非利士偶像）——直接驳斥「公元前10世纪犹大尚未立国」的怀疑论观点。",
        correlation_zh_hant="撒母耳記上17:1-3記載以色列與非利士兩軍在梭哥與亞西加之間的以拉谷對峙；基愛法山丘正位於此谷上方的戰略山脊。其唯一一段短暫設防期與聯合王國時期完全吻合，並展現出大衛時代聖經所要求的：集中化猶大國家政權、工程能力、文字傳統、族群與宗教標記（守潔食條例、未見非利士偶像）——直接駁斥「公元前10世紀猶大尚未立國」的懷疑論觀點。",
    ),
    _make(
        id="ein_gedi_synagogue",
        category="Archaeology",
        bible_books=["Joshua", "1 Samuel", "Song of Solomon"],
        timeline="3rd-6th century CE (synagogue) over earlier Iron-Age settlement",
        discovery_date="1970 (Barag, Porat, Netzer)",
        location="Ein Gedi, Dead Sea coast, Israel",
        scripture_reference="Joshua 15:62; Song of Solomon 1:14",
        images=[
            "https://upload.wikimedia.org/wikipedia/commons/thumb/7/7d/Ein_Gedi_Mosaic_Floor.jpg/640px-Ein_Gedi_Mosaic_Floor.jpg",
        ],
        academic_sources=[
            "Levine, L. I. The Ancient Synagogue. Yale University Press, 2005.",
            "Barag, D., Y. Porat, and E. Netzer. 'The Synagogue at Ein Gedi.' In Ancient Synagogues Revealed, ed. L. I. Levine, 1981.",
        ],
        confidence_level="Definitive",
        icon="🕍",
        title_en="Ein Gedi Synagogue — Ancient Oasis Confirmed in Joshua's Town List",
        title_zh_hans="隐基底会堂——约书亚记城邑表中绿洲的实物印证",
        title_zh_hant="隱基底會堂——約書亞記城邑表中綠洲的實物印證",
        summary_en="Late-Roman / early-Byzantine synagogue with an exceptionally well-preserved mosaic floor and a Hebrew-Aramaic dedicatory inscription, situated at the oasis of Ein Gedi listed in Joshua 15:62 and praised in Song of Solomon 1:14.",
        summary_zh_hans="位于隐基底绿洲（约书亚记15:62所列、雅歌1:14所赞）的晚罗马—早拜占庭时期会堂，存有保存极佳的镶嵌地板与希伯来—亚兰双语献辞铭文。",
        summary_zh_hant="位於隱基底綠洲（約書亞記15:62所列、雅歌1:14所讚）的晚羅馬—早拜占庭時期會堂，存有保存極佳的鑲嵌地板與希伯來—亞蘭雙語獻辭銘文。",
        description_en="The synagogue was built around 250 CE and rebuilt twice before its destruction by fire around 530 CE. Its central mosaic depicts the four seasons and a stylized menorah, and its inscription warns 'whoever causes a controversy between a man and his fellow, or whoever slanders his fellow before the gentiles… the One whose eyes range through the whole earth and who sees what is concealed will uproot this person.'\n\nIron-Age strata beneath the synagogue confirm continuous occupation from biblical times. Ein Gedi (Hebrew 'spring of the kid') is the freshwater spring on the western shore of the Dead Sea where David hid from Saul (1 Samuel 24:1) and which Solomon's poetry compares to a fragrant garden.",
        description_zh_hans="该会堂建于约公元250年，两度重建，约530年遭火毁。中央镶嵌图绘四季与样式化的灯台，献辞铭文警告：「凡使弟兄相争者，或在外邦人前毁谤弟兄者……那目遍察全地、洞悉隐情者，必将其铲除。」\n\n会堂下方铁器时代地层证明此地自圣经时代以来持续有人居住。隐基底（希伯来文意为「小山羊之泉」）位于死海西岸的淡水泉源——大卫躲避扫罗之处（撒母耳记上24:1），亦为所罗门以芬芳园圃为喻所赞美的地方。",
        description_zh_hant="該會堂建於約公元250年，兩度重建，約530年遭火毀。中央鑲嵌圖繪四季與樣式化的燈台，獻辭銘文警告：「凡使弟兄相爭者，或在外邦人前毀謗弟兄者……那目遍察全地、洞悉隱情者，必將其鏟除。」\n\n會堂下方鐵器時代地層證明此地自聖經時代以來持續有人居住。隱基底（希伯來文意為「小山羊之泉」）位於死海西岸的淡水泉源——大衛躲避掃羅之處（撒母耳記上24:1），亦為所羅門以芬芳園圃為喻所讚美的地方。",
        correlation_en="Ein Gedi appears in Joshua 15:62 as a town in Judah's tribal allotment and is referenced in 1 Samuel 24 (David's hideout cave), 2 Chronicles 20:2 (Jehoshaphat's enemies camped there), and Song of Solomon 1:14 ('cluster of henna blossoms in the vineyards of Ein Gedi'). The continuous archaeological record from Iron Age through Byzantine times confirms the place exists, was inhabited, and was named exactly as the biblical text says.",
        correlation_zh_hans="隐基底见于约书亚记15:62（犹大支派分地中的城邑）、撒母耳记上24章（大卫藏匿洞穴之处）、历代志下20:2（约沙法仇敌扎营之地）、雅歌1:14（「我以良人为隐基底园中的一束凤仙花」）。从铁器时代直至拜占庭时代连续不断的考古记录证实：此地实存，长期有人居住，并以圣经所记之名相承。",
        correlation_zh_hant="隱基底見於約書亞記15:62（猶大支派分地中的城邑）、撒母耳記上24章（大衛藏匿洞穴之處）、歷代志下20:2（約沙法仇敵紮營之地）、雅歌1:14（「我以良人為隱基底園中的一束鳳仙花」）。從鐵器時代直至拜占庭時代連續不斷的考古記錄證實：此地實存，長期有人居住，並以聖經所記之名相承。",
    ),
    _make(
        id="dura_europos_synagogue",
        category="History",
        bible_books=["Exodus", "1 Kings", "Esther"],
        timeline="2nd-3rd century CE",
        discovery_date="1932-1935",
        location="National Museum, Damascus (frescoes); site in Syria",
        scripture_reference="Exodus 14:21-22; 1 Kings 5-7",
        images=[
            "https://upload.wikimedia.org/wikipedia/commons/thumb/c/cd/Dura_Europos_synagogue_panel_1.jpg/640px-Dura_Europos_synagogue_panel_1.jpg",
        ],
        academic_sources=[
            "Goodenough, E. R. Jewish Symbols in the Greco-Roman Period. Princeton University Press, 1953-1968.",
            "Weitzmann, K., and H. Kessler. The Frescoes of the Dura Synagogue and Christian Art. Dumbarton Oaks, 1990.",
        ],
        confidence_level="Definitive",
        icon="🎨",
        title_en="Dura-Europos Synagogue — Earliest Biblical-Narrative Painting Cycle",
        title_zh_hans="杜拉欧罗普斯会堂——已知最早的圣经叙事壁画群",
        title_zh_hant="杜拉歐羅普斯會堂——已知最早的聖經敘事壁畫群",
        summary_en="A Roman-period synagogue at the Euphrates frontier, decorated wall-to-wall with figurative frescoes depicting Old Testament narratives — Moses, the Exodus, Solomon's Temple, Esther, Ezekiel — preserved by being walled in during a Sasanian siege in 256 CE.",
        summary_zh_hans="位于幼发拉底河边境的罗马时代会堂，墙面满绘旧约叙事壁画——摩西、出埃及、所罗门圣殿、以斯帖、以西结——因公元256年萨珊围城时被夯土封堵而得以完整保存。",
        summary_zh_hant="位於幼發拉底河邊境的羅馬時代會堂，牆面滿繪舊約敘事壁畫——摩西、出埃及、所羅門聖殿、以斯帖、以西結——因公元256年薩珊圍城時被夯土封堵而得以完整保存。",
        description_en="Dura-Europos was a Roman fortress town overlooking the Euphrates in modern eastern Syria. When the Sasanian Persians besieged the city in 256 CE, Roman defenders filled the houses along the western wall with rubble to create a thick anti-mining berm. One of those houses contained a synagogue, completed around 244 CE. The rubble fill preserved its frescoes intact for over 1,600 years.\n\nExcavated by Yale University and the French Academy in the 1930s, the surviving wall paintings cover three walls in 28 narrative panels: Moses being drawn from the Nile, the Exodus and parting of the Red Sea, the Ark of the Covenant, Samuel anointing David, the dedication of Solomon's Temple, the story of Esther, Ezekiel's vision of the dry bones, and many more. The frescoes are now on display in the National Museum of Damascus.",
        description_zh_hans="杜拉欧罗普斯是位于今叙利亚东部、幼发拉底河岸的一座罗马要塞城邑。公元256年萨珊波斯围城之际，罗马守军以瓦砾填实西墙下方民居以筑反掘进土堤。其中一栋民居内即建有约公元244年落成的会堂，遂因夯土封堵而保存其壁画达逾1600年之久。\n\n1930年代由耶鲁大学与法国学会联合发掘，存留壁画覆盖三面墙壁，共28幅叙事图：摩西自尼罗河被取出、出埃及与红海分开、约柜、撒母耳膏抹大卫、所罗门献圣殿、以斯帖故事、以西结枯骨复生异象等。壁画现陈列于大马士革国家博物馆。",
        description_zh_hant="杜拉歐羅普斯是位於今敘利亞東部、幼發拉底河岸的一座羅馬要塞城邑。公元256年薩珊波斯圍城之際，羅馬守軍以瓦礫填實西牆下方民居以築反掘進土堤。其中一棟民居內即建有約公元244年落成的會堂，遂因夯土封堵而保存其壁畫達逾1600年之久。\n\n1930年代由耶魯大學與法國學會聯合發掘，存留壁畫覆蓋三面牆壁，共28幅敘事圖：摩西自尼羅河被取出、出埃及與紅海分開、約櫃、撒母耳膏抹大衛、所羅門獻聖殿、以斯帖故事、以西結枯骨復生異象等。壁畫現陳列於大馬士革國家博物館。",
        correlation_en="The Dura frescoes are the earliest known visual depictions of biblical narratives — predating any surviving Christian narrative cycle by more than a century. They demonstrate that Diaspora Jews of the 3rd century CE knew, illustrated, and worshipped using exactly the canonical Old Testament stories preserved in modern Bibles: Exodus, Solomon's Temple, Esther, Ezekiel. The visual specificity (e.g., Moses with twelve tribal banners, Ezekiel's bones reconstituting in stages) reflects close textual reading and provides invaluable evidence for the Hebrew Bible's status long before the Masoretic Text was finalized.",
        correlation_zh_hans="杜拉壁画是已知最早的圣经叙事视觉表达——比现存任何基督教叙事图像早一个多世纪。它们证明：公元3世纪散居各地的犹太人所识、所绘、所敬拜的，正是现代圣经中所传承的经典旧约——出埃及记、所罗门圣殿、以斯帖记、以西结书。其视觉细节（如摩西手持十二支派旗号、以西结所见骸骨分阶段复合）反映出对文本的细致阅读，为希伯来圣经在马所拉文本定型之前已具权威地位提供宝贵证据。",
        correlation_zh_hant="杜拉壁畫是已知最早的聖經敘事視覺表達——比現存任何基督教敘事圖像早一個多世紀。它們證明：公元3世紀散居各地的猶太人所識、所繪、所敬拜的，正是現代聖經中所傳承的經典舊約——出埃及記、所羅門聖殿、以斯帖記、以西結書。其視覺細節（如摩西手持十二支派旗號、以西結所見骸骨分階段復合）反映出對文本的細緻閱讀，為希伯來聖經在馬所拉文本定型之前已具權威地位提供寶貴證據。",
    ),
    _make(
        id="meggido_solomonic_stables",
        category="Archaeology",
        bible_books=["1 Kings", "1 Chronicles"],
        timeline="10th-9th century BCE",
        discovery_date="1928-1939, 1992-present",
        location="Tel Megiddo, Jezreel Valley, Israel",
        scripture_reference="1 Kings 9:15; 1 Kings 10:26",
        images=[
            "https://upload.wikimedia.org/wikipedia/commons/thumb/d/d3/Megiddo_Stables.jpg/640px-Megiddo_Stables.jpg",
        ],
        academic_sources=[
            "Yadin, Y. Hazor: The Rediscovery of a Great Citadel of the Bible. Random House, 1975.",
            "Finkelstein, I., D. Ussishkin, and B. Halpern, eds. Megiddo IV: The 1998-2002 Seasons. Tel Aviv University, 2006.",
        ],
        confidence_level="Strong",
        icon="🐎",
        title_en="Megiddo's Pillared Buildings — Likely Solomonic Stables",
        title_zh_hans="米吉多柱厅建筑群——可能的所罗门马厩",
        title_zh_hant="米吉多柱廳建築群——可能的所羅門馬廄",
        summary_en="Two large rectangular complexes of pillared structures at Tel Megiddo, dated to the 10th-9th century BCE, totaling space for roughly 450 horses. Long identified as 'Solomon's stables' on the basis of 1 Kings 9:15-19 and 10:26.",
        summary_zh_hans="米吉多丘上两组大型柱厅建筑群，年代约公元前10—9世纪，可容约450匹马。长期被根据列王纪上9:15-19与10:26定为「所罗门的马厩」。",
        summary_zh_hant="米吉多丘上兩組大型柱廳建築群，年代約公元前10—9世紀，可容約450匹馬。長期被根據列王紀上9:15-19與10:26定為「所羅門的馬廄」。",
        description_en="The pillared buildings were first excavated by P. L. O. Guy of the Oriental Institute (Chicago) in 1928 and re-investigated extensively by Yigael Yadin (1960s) and the ongoing Tel Aviv University expedition (Finkelstein, Ussishkin, Halpern from 1992). Each building contains rows of stone pillars with mangers between them, drainage troughs, and tethering holes — features consistent with horse stables, though some scholars propose alternative uses (storehouses, barracks).\n\nDating is contested: Yadin attributed them to Solomon (10th century BCE); Finkelstein's 'Low Chronology' shifts them to Ahab (9th century BCE). Even on the late dating, they remain royal monumental architecture from the divided-kingdom era. Megiddo, Hazor, and Gezer share the same six-chamber gate plan, suggesting a unified building program.",
        description_zh_hans="此柱厅建筑群最初由芝加哥东方研究所盖伊（P. L. O. Guy）于1928年发掘，后经亚丁（1960年代）与特拉维夫大学考察队（自1992年由芬克尔斯坦、乌西什金、哈尔彭主持）反复研究。每栋建筑由若干列石柱构成，柱间有食槽、排水沟与系马孔，结构与马厩相符；部分学者另提仓库或兵营之说。\n\n断代尚存争议：亚丁断为所罗门时代（公元前10世纪）；芬克尔斯坦「低代记年」则归于亚哈王时代（公元前9世纪）。即便采纳较晚断代，本建筑仍属分裂王国时期王室纪念性建筑。米吉多、夏琐、基色三地皆有相同的六厢房城门规划，显示属同一建造方案。",
        description_zh_hant="此柱廳建築群最初由芝加哥東方研究所蓋伊（P. L. O. Guy）於1928年發掘，後經亞丁（1960年代）與特拉維夫大學考察隊（自1992年由芬克爾斯坦、烏西什金、哈爾彭主持）反覆研究。每棟建築由若干列石柱構成，柱間有食槽、排水溝與繫馬孔，結構與馬廄相符；部分學者另提倉庫或兵營之說。\n\n斷代尚存爭議：亞丁斷為所羅門時代（公元前10世紀）；芬克爾斯坦「低代記年」則歸於亞哈王時代（公元前9世紀）。即便採納較晚斷代，本建築仍屬分裂王國時期王室紀念性建築。米吉多、夏瑣、基色三地皆有相同的六廂房城門規劃，顯示屬同一建造方案。",
        correlation_en="1 Kings 9:15 names Megiddo, Hazor, and Gezer as Solomon's three royal building projects (alongside Jerusalem). 1 Kings 10:26 records Solomon's chariot and cavalry: 'He had 1,400 chariots and 12,000 horses, which he kept in the chariot cities and with the king in Jerusalem.' Megiddo's pillared structures and the matching gate-plans at all three sites provide a material correlate that is hard to explain except by central royal direction — the very kind the biblical text describes.",
        correlation_zh_hans="列王纪上9:15明列所罗门所建的三大王城：米吉多、夏琐、基色（以及耶路撒冷）。列王纪上10:26载所罗门拥有「车一千四百辆，马兵一万二千名，分驻在屯车的城邑和王驻耶路撒冷处」。米吉多柱厅以及三地共有的城门规划，正是不易以非中央王权解释的实物对应——而这正是圣经所描述的体制。",
        correlation_zh_hant="列王紀上9:15明列所羅門所建的三大王城：米吉多、夏瑣、基色（以及耶路撒冷）。列王紀上10:26載所羅門擁有「車一千四百輛，馬兵一萬二千名，分駐在屯車的城邑和王駐耶路撒冷處」。米吉多柱廳以及三地共有的城門規劃，正是不易以非中央王權解釋的實物對應——而這正是聖經所描述的體制。",
    ),
    _make(
        id="ketef_hinnom_priestly_blessing",
        category="Manuscripts",
        bible_books=["Numbers"],
        timeline="late 7th to early 6th century BCE",
        discovery_date="1979 (Barkay)",
        location="Israel Museum, Jerusalem",
        scripture_reference="Numbers 6:24-26",
        images=[
            "https://upload.wikimedia.org/wikipedia/commons/thumb/5/52/Ketef_Hinnom_silver_amulet.jpg/420px-Ketef_Hinnom_silver_amulet.jpg",
        ],
        academic_sources=[
            "Barkay, G., et al. 'The Amulets from Ketef Hinnom: A New Edition and Evaluation.' BASOR 334 (2004).",
            "Berlejung, A. 'Ein Programm fürs Leben.' ZAW 120 (2008).",
        ],
        confidence_level="Definitive",
        icon="🪬",
        title_en="Ketef Hinnom Silver Scrolls — Bible's Oldest Surviving Text",
        title_zh_hans="希农谷银卷——现存最古老的圣经经文",
        title_zh_hant="希農谷銀卷——現存最古老的聖經經文",
        summary_en="Two minuscule silver amulets unrolled to reveal the Aaronic priestly blessing of Numbers 6:24-26 — the oldest known biblical text by approximately four centuries, predating the Dead Sea Scrolls.",
        summary_zh_hans="两件极小的银质护身卷轴，展开后显出民数记6:24-26亚伦祭司祝福文——比死海古卷早约四百年的现存最古老圣经文本。",
        summary_zh_hant="兩件極小的銀質護身卷軸，展開後顯出民數記6:24-26亞倫祭司祝福文——比死海古卷早約四百年的現存最古老聖經文本。",
        description_en="Discovered by Tel Aviv University archaeologist Gabriel Barkay in 1979 in a Late Iron Age burial cave at Ketef Hinnom (the 'Shoulder of Hinnom') near Jerusalem's Old City. The two scrolls, when carefully unrolled by Israel Museum conservators, measured roughly 4 cm and 1.5 cm in length but contained between them the priestly benediction in nearly identical wording to the Masoretic Text:\n\n'May YHWH bless you and keep you. May YHWH cause his face to shine upon you and grant you peace.' (Numbers 6:24-26)\n\nPaleographic and ceramic dating place the burial in the late 7th or early 6th century BCE — predating the Babylonian destruction of Jerusalem (586 BCE) and predating the oldest Dead Sea Scrolls by some four centuries.",
        description_zh_hans="1979年由特拉维夫大学考古学家加百列·巴尔凯（Gabriel Barkay）于耶路撒冷古城附近的希农谷晚铁器时代墓穴中发现。两枚卷轴经以色列博物馆文物修复人员小心展开后，约长4厘米与1.5厘米，载有几乎与马所拉文本一字不差的祭司祝福文：\n\n「愿耶和华赐福给你，保护你；愿耶和华使祂的脸光照你，赐你平安。」（民数记6:24-26）\n\n古文字与陶器断代将墓葬定于公元前7世纪末至6世纪初——早于公元前586年巴比伦毁城，亦比已知最古老的死海古卷早约四百年。",
        description_zh_hant="1979年由特拉維夫大學考古學家加百列·巴爾凱（Gabriel Barkay）於耶路撒冷古城附近的希農谷晚鐵器時代墓穴中發現。兩枚卷軸經以色列博物館文物修復人員小心展開後，約長4厘米與1.5厘米，載有幾乎與馬所拉文本一字不差的祭司祝福文：\n\n「願耶和華賜福給你，保護你；願耶和華使祂的臉光照你，賜你平安。」（民數記6:24-26）\n\n古文字與陶器斷代將墓葬定於公元前7世紀末至6世紀初——早於公元前586年巴比倫毀城，亦比已知最古老的死海古卷早約四百年。",
        correlation_en="The text engraved on the silver matches Numbers 6:24-26 word-for-word. Critics had argued that Numbers (part of the Pentateuch) was redacted into its final form only after the Babylonian Exile — so finding the priestly blessing already in formal liturgical use BEFORE the exile is a direct rebuttal. It also demonstrates that the divine name YHWH was actively used in Judean religious practice in the same generation Jeremiah lived through, exactly as the Hebrew Bible records.",
        correlation_zh_hans="银卷所刻文字与民数记6:24-26逐字相符。曾有学者主张五经（包括民数记）系被掳之后才定型；本卷却显示祭司祝福文在被掳之前已作为正式礼仪文本广泛使用，是对该说法的直接反驳。它同时证明：在耶利米所生活的同一世代，耶和华之圣名仍在犹大宗教礼仪中被实际使用——正如希伯来圣经所记。",
        correlation_zh_hant="銀卷所刻文字與民數記6:24-26逐字相符。曾有學者主張五經（包括民數記）係被擄之後才定型；本卷卻顯示祭司祝福文在被擄之前已作為正式禮儀文本廣泛使用，是對該說法的直接反駁。它同時證明：在耶利米所生活的同一世代，耶和華之聖名仍在猶大宗教禮儀中被實際使用——正如希伯來聖經所記。",
    ),
    _make(
        id="tomb_of_cyrus",
        category="History",
        bible_books=["Isaiah", "Ezra", "Daniel"],
        timeline="6th century BCE",
        discovery_date="recorded since antiquity; modern excavation 1949-",
        location="Pasargadae, Iran",
        scripture_reference="Isaiah 44:28; Ezra 1:1-4",
        images=[
            "https://upload.wikimedia.org/wikipedia/commons/thumb/3/35/Tomb_of_Cyrus_the_Great.jpg/640px-Tomb_of_Cyrus_the_Great.jpg",
        ],
        academic_sources=[
            "Stronach, D. Pasargadae. Oxford, 1978.",
            "Dandamayev, M. A. 'Cyrus II.' Encyclopædia Iranica VI/5 (1993).",
        ],
        confidence_level="Definitive",
        icon="🏛️",
        title_en="Tomb of Cyrus the Great — The Liberator Foretold by Name",
        title_zh_hans="居鲁士大帝陵——以赛亚预言指名的解放者",
        title_zh_hant="居魯士大帝陵——以賽亞預言指名的解放者",
        summary_en="The simple six-stepped limestone tomb of Cyrus II at Pasargadae — the founder of the Persian Empire who, in 539 BCE, allowed exiled Judeans to return to Jerusalem and rebuild the temple, exactly as Isaiah had named him 150 years earlier.",
        summary_zh_hans="位于波斯帕萨尔加德的居鲁士二世六阶石灰石陵墓——他是波斯帝国的奠基人，于公元前539年准许被掳的犹大人回归耶路撒冷重建圣殿，正如以赛亚书在此前约150年指名所预言。",
        summary_zh_hant="位於波斯帕薩爾加德的居魯士二世六階石灰石陵墓——他是波斯帝國的奠基人，於公元前539年准許被擄的猶大人回歸耶路撒冷重建聖殿，正如以賽亞書在此前約150年指名所預言。",
        description_en="The tomb stands on a six-stepped platform of dressed limestone in the central plain of Pasargadae, the ceremonial capital Cyrus founded north of Persepolis. It survives essentially intact thanks to local Muslim tradition that preserved it as the 'tomb of Solomon's mother,' protecting it from later destruction.\n\nGreek historians (Strabo, Arrian) record an inscription on the tomb that no longer survives: 'O man, whoever you are and from wherever you came (for I know you will come), I am Cyrus, who founded the empire of the Persians. Do not begrudge me this little earth that covers my body.' Modern archaeology, beginning with David Stronach's 1949-1963 excavations, has confirmed the dating and identification.",
        description_zh_hans="陵墓位于波斯波利斯以北、居鲁士所建的礼仪首都帕萨尔加德中央平原，由切割整齐的石灰石筑成六阶台基。其得以基本完整保存，得益于当地穆斯林传统将其奉为「所罗门母亲之墓」，免遭后世破坏。\n\n希腊历史学家（斯特拉波、阿里安）记载墓上原刻铭文（今已不存）：「过往之人，无论你是谁、自何处而来（因我知你必到来）：我是居鲁士，建立波斯帝国之人。请勿吝惜这覆盖我身的少许尘土。」现代考古始于斯特罗纳赫（David Stronach）1949—1963年的发掘，已确定其年代与归属。",
        description_zh_hant="陵墓位於波斯波利斯以北、居魯士所建的禮儀首都帕薩爾加德中央平原，由切割整齊的石灰石築成六階台基。其得以基本完整保存，得益於當地穆斯林傳統將其奉為「所羅門母親之墓」，免遭後世破壞。\n\n希臘歷史學家（斯特拉波、阿里安）記載墓上原刻銘文（今已不存）：「過往之人，無論你是誰、自何處而來（因我知你必到來）：我是居魯士，建立波斯帝國之人。請勿吝惜這覆蓋我身的少許塵土。」現代考古始於斯特羅納赫（David Stronach）1949—1963年的發掘，已確定其年代與歸屬。",
        correlation_en="Isaiah 44:28-45:1 names Cyrus as God's 'shepherd' and 'anointed' who would 'rebuild Jerusalem and lay the foundation of the temple,' written approximately 150 years before Cyrus's birth. Ezra 1:1-4 quotes Cyrus's actual decree of return (538 BCE), which the Cyrus Cylinder confirms in its general religious-tolerance policy. The Tomb of Cyrus stands as the physical resting place of the only Gentile ruler the Hebrew Bible explicitly calls God's anointed — a remarkable convergence of prophecy and post-conquest political reality.",
        correlation_zh_hans="以赛亚书44:28—45:1指名居鲁士为神的「牧人」与「受膏者」，预言他将「重建耶路撒冷，奠定殿基」——此预言写于居鲁士出生约150年前。以斯拉记1:1-4引述居鲁士公元前538年颁发的归回诏令，居鲁士圆柱以其宗教宽容政策的总体框架与之印证。居鲁士陵作为希伯来圣经所明指为「神受膏者」之唯一外邦君王的安息之处，构成预言与后世政治实况的非凡相合。",
        correlation_zh_hant="以賽亞書44:28—45:1指名居魯士為神的「牧人」與「受膏者」，預言他將「重建耶路撒冷，奠定殿基」——此預言寫於居魯士出生約150年前。以斯拉記1:1-4引述居魯士公元前538年頒發的歸回詔令，居魯士圓柱以其宗教寬容政策的總體框架與之印證。居魯士陵作為希伯來聖經所明指為「神受膏者」之唯一外邦君王的安息之處，構成預言與後世政治實況的非凡相合。",
    ),
]


def main() -> int:
    if not os.path.exists(DATA_PATH):
        print(f"FATAL: {DATA_PATH} not found", file=sys.stderr)
        return 1

    with open(DATA_PATH, "r", encoding="utf-8") as fh:
        data = json.load(fh)

    evidences: list[dict] = data.get("evidences", [])
    by_id = {e["id"]: e for e in evidences}

    # 1. Patch missing images.
    patched = 0
    for eid, urls in PATCHES.items():
        if eid in by_id and not by_id[eid].get("images"):
            by_id[eid]["images"] = list(urls)
            patched += 1

    # 2. Append new entries (skip if id already present).
    added: list[str] = []
    for entry in NEW_ENTRIES:
        if entry["id"] in by_id:
            print(f"SKIP existing id: {entry['id']}", file=sys.stderr)
            continue
        evidences.append(entry)
        by_id[entry["id"]] = entry
        added.append(entry["id"])

    # 3. Re-stamp meta.
    data.setdefault("_meta", {})
    data["_meta"]["count"] = len(evidences)
    data["_meta"]["generatedAt"] = (
        _dt.datetime.now(_dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    )

    with open(DATA_PATH, "w", encoding="utf-8") as fh:
        json.dump(data, fh, ensure_ascii=False, indent=2)
        fh.write("\n")

    print(
        f"Patched images on {patched} entries; added {len(added)} new entries: "
        + ", ".join(added)
    )
    print(f"New total: {len(evidences)} evidences.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
