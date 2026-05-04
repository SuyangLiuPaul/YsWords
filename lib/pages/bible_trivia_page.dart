import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'package:yswords/constants/ui_strings.dart';
import 'package:yswords/models/app_settings.dart';
import 'package:yswords/providers/main_provider.dart';
import 'package:yswords/utils/jump_to_reference.dart' as jumper;
import 'package:yswords/utils/reference_parser.dart';
import 'package:yswords/utils/responsive.dart';
import 'package:yswords/pages/home_page.dart';
import 'package:yswords/widgets/home_icon_button.dart';
import 'package:yswords/widgets/localized_back_button.dart';

/// Curated catalogue of "Bible trivia" / 冷知识 — patterns and
/// hidden structures most readers don't notice unless someone
/// points them out. Round 56 starter set; expanded over time.
///
/// Each entry has a localized title + body + an optional
/// reference (`Psalm 119`, `Ruth 2:4`) that the page will
/// resolve and link to so the user can jump straight to the
/// passage and read it themselves.
///
/// Phase 1 (this round): hand-curated entries focused on
/// well-known acrostics, hidden Tetragrammaton patterns, and
/// numerical structures.
///
/// To add a new entry: append to `_triviaEntries` below with
/// the same shape. No code changes required elsewhere.
class BibleTriviaPage extends StatelessWidget {
  const BibleTriviaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final locale = settings.locale;
    final scheme = Theme.of(context).colorScheme;
    final dc = ResponsiveBreakpoints.classOf(
        MediaQuery.of(context).size.width);
    final maxW = ResponsiveBreakpoints.settingsMaxWidth(dc);

    return Scaffold(
      appBar: AppBar(
        leading: const LocalizedBackButton(),
        title: Text(uiStrings['bibleTrivia']?[locale] ?? 'Bible Trivia'),
        actions: const [HomeIconButton()],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: _triviaEntries.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              if (i == 0) {
                return _IntroCard(settings: settings, scheme: scheme);
              }
              return _TriviaTile(
                entry: _triviaEntries[i - 1],
                settings: settings,
                scheme: scheme,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  final AppSettings settings;
  final ColorScheme scheme;
  const _IntroCard({required this.settings, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final locale = settings.locale;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.primary.withValues(alpha: 0.3),
          width: 0.6,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_rounded, color: scheme.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              uiStrings['bibleTriviaIntro']?[locale] ??
                  'Hidden patterns, acrostics, and numerical structures '
                      'most readers miss. Tap any entry to read the '
                      'related passage in the reader.',
              style: TextStyle(
                fontFamily: settings.fontFamily,
                fontSize: (settings.fontSize - 2).clamp(12.0, 16.0),
                color: scheme.onSurface.withValues(alpha: 0.85),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TriviaTile extends StatefulWidget {
  final _TriviaEntry entry;
  final AppSettings settings;
  final ColorScheme scheme;
  const _TriviaTile({
    required this.entry,
    required this.settings,
    required this.scheme,
  });

  @override
  State<_TriviaTile> createState() => _TriviaTileState();
}

class _TriviaTileState extends State<_TriviaTile> {
  bool _expanded = false;

  Future<void> _openReference(BuildContext context) async {
    final ref = widget.entry.reference;
    if (ref == null || ref.isEmpty) return;
    final parsed = parseReference(ref);
    if (parsed == null) return;
    final mp = context.read<MainProvider>();
    final result = await jumper.resolveAndPrepareJump(
      reference: parsed,
      mp: mp,
    );
    if (!context.mounted) return;
    final ok = await jumper.showJumpResultSnackBar(context, result);
    if (!ok || !context.mounted) return;
    Get.to(() => const HomePage(), transition: Transition.rightToLeft);
  }

  @override
  Widget build(BuildContext context) {
    final locale = widget.settings.locale;
    final entry = widget.entry;
    final scheme = widget.scheme;
    final settings = widget.settings;
    final title = entry.title[locale] ?? entry.title['en'] ?? '';
    final body = entry.body[locale] ?? entry.body['en'] ?? '';
    final tag = entry.tag[locale] ?? entry.tag['en'] ?? '';
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(12),
      elevation: 0,
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        fontFamily: settings.fontFamily,
                        fontSize:
                            (settings.fontSize - 5).clamp(10.0, 12.0),
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (entry.reference != null)
                    Text(
                      entry.reference!,
                      style: TextStyle(
                        fontFamily: settings.fontFamily,
                        fontSize:
                            (settings.fontSize - 5).clamp(10.0, 12.0),
                        color: scheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: Icon(
                      Icons.expand_more_rounded,
                      color: scheme.onSurface.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  fontFamily: settings.fontFamily,
                  fontSize: (settings.fontSize + 1).clamp(14.0, 19.0),
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 220),
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        body,
                        style: TextStyle(
                          fontFamily: settings.fontFamily,
                          fontSize:
                              (settings.fontSize - 1).clamp(12.0, 17.0),
                          color: scheme.onSurface.withValues(alpha: 0.85),
                          height: 1.55,
                        ),
                      ),
                      if (entry.reference != null) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.menu_book_rounded, size: 18),
                          label: Text(
                            uiStrings['bibleTriviaOpenRef']?[locale] ??
                                'Read in Bible',
                          ),
                          onPressed: () => _openReference(context),
                        ),
                      ],
                    ],
                  ),
                ),
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One Bible-trivia entry. Localized in 3 languages.
class _TriviaEntry {
  final Map<String, String> tag;
  final Map<String, String> title;
  final Map<String, String> body;
  final String? reference;
  const _TriviaEntry({
    required this.tag,
    required this.title,
    required this.body,
    this.reference,
  });
}

/// Phase-1 starter set. Add more entries here over time — they
/// auto-render in the page in declaration order.
const List<_TriviaEntry> _triviaEntries = [
  // ── Acrostics ────────────────────────────────────────────────
  _TriviaEntry(
    tag: {
      'en': 'ACROSTIC',
      'zh-Hans': '离合体',
      'zh-Hant': '離合體',
    },
    title: {
      'en': 'Psalm 119: A Hebrew alphabet acrostic',
      'zh-Hans': '诗篇 119：希伯来字母离合体',
      'zh-Hant': '詩篇 119：希伯來字母離合體',
    },
    body: {
      'en':
          'The longest chapter in the Bible (176 verses) is built around '
              'the 22 letters of the Hebrew alphabet. The 176 verses are '
              'organized into 22 sections of 8 verses each. Every verse in '
              'a section begins with the same Hebrew letter — section 1 '
              'all start with Aleph (א), section 2 all with Beth (ב), and '
              'so on through Tav (ת). The structure is impossible to see '
              'in translation, but the original Hebrew form is a tightly '
              'engineered praise of God\'s word — the entire chapter is '
              'about Scripture itself.',
      'zh-Hans': '圣经最长的一章（176 节）是按希伯来字母 22 个字母编排的离合体。'
          '176 节经文分成 22 段，每段 8 节，每段经文的第一个希伯来字母完全相同——'
          '第 1 段全部以 Aleph（א）开头，第 2 段全部以 Beth（ב）开头，'
          '一直到最后的 Tav（ת）。译文中完全看不出这个结构，'
          '但原文形式上是一部精密构思的颂赞，主题贯穿始终都是神的话语——整章都在讲"圣经"本身。',
      'zh-Hant': '聖經最長的一章（176 節）是按希伯來字母 22 個字母編排的離合體。'
          '176 節經文分成 22 段，每段 8 節，每段經文的第一個希伯來字母完全相同——'
          '第 1 段全部以 Aleph（א）開頭，第 2 段全部以 Beth（ב）開頭，'
          '一直到最後的 Tav（ת）。譯文中完全看不出這個結構，'
          '但原文形式上是一部精密構思的頌讚，主題貫穿始終都是神的話語——整章都在講「聖經」本身。',
    },
    reference: 'Psalm 119',
  ),
  _TriviaEntry(
    tag: {
      'en': 'ACROSTIC',
      'zh-Hans': '离合体',
      'zh-Hant': '離合體',
    },
    title: {
      'en': 'Lamentations: Five poems, four are alphabetic acrostics',
      'zh-Hans': '耶利米哀歌：五首哀歌，前四首都是字母离合体',
      'zh-Hant': '耶利米哀歌：五首哀歌，前四首都是字母離合體',
    },
    body: {
      'en':
          'Lamentations 1, 2, and 4 each have 22 verses — one per Hebrew '
              'letter. Chapter 3 has 66 verses (22 × 3): three verses for '
              'each letter in turn. Chapter 5, the final one, has 22 '
              'verses but BREAKS the acrostic — the structure has '
              'collapsed, mirroring the destruction the prophet is '
              'lamenting. Form following content.',
      'zh-Hans': '哀歌第 1、2、4 章各有 22 节——每节对应希伯来字母表的一个字母。'
          '第 3 章有 66 节（22 × 3），每个字母对应连续三节。'
          '最后的第 5 章虽然也有 22 节，却**打破了**离合体结构——形式本身崩塌，'
          '与先知所哀叹的"耶路撒冷的毁灭"相呼应。这是一种"形式呼应内容"的修辞。',
      'zh-Hant': '哀歌第 1、2、4 章各有 22 節——每節對應希伯來字母表的一個字母。'
          '第 3 章有 66 節（22 × 3），每個字母對應連續三節。'
          '最後的第 5 章雖然也有 22 節，卻**打破了**離合體結構——形式本身崩塌，'
          '與先知所哀嘆的「耶路撒冷的毀滅」相呼應。這是一種「形式呼應內容」的修辭。',
    },
    reference: 'Lamentations 3',
  ),
  _TriviaEntry(
    tag: {
      'en': 'ACROSTIC',
      'zh-Hans': '离合体',
      'zh-Hant': '離合體',
    },
    title: {
      'en': 'Proverbs 31: The wife of noble character is alphabetic',
      'zh-Hans': '箴言 31 章：才德的妇人是字母离合体',
      'zh-Hant': '箴言 31 章：才德的婦人是字母離合體',
    },
    body: {
      'en':
          'The famous "wife of noble character" passage (Proverbs '
              '31:10–31) has exactly 22 verses, and each begins with the '
              'next letter of the Hebrew alphabet in order — a complete '
              'A-to-Z portrait of a virtuous woman. The acrostic structure '
              'signals "this is the comprehensive description, the full '
              'spectrum of virtue."',
      'zh-Hans': '著名的"才德的妇人"段落（箴言 31:10–31）正好 22 节，'
          '每一节按希伯来字母表的顺序开头——一份"从 A 到 Z"全面描绘贤德女子的画像。'
          '这个离合体结构的修辞意义是："这是完整的、囊括方方面面的描述"。',
      'zh-Hant': '著名的「才德的婦人」段落（箴言 31:10–31）正好 22 節，'
          '每一節按希伯來字母表的順序開頭——一份「從 A 到 Z」全面描繪賢德女子的畫像。'
          '這個離合體結構的修辭意義是：「這是完整的、囊括方方面面的描述」。',
    },
    reference: 'Proverbs 31:10',
  ),

  // ── YHWH name patterns ───────────────────────────────────────
  _TriviaEntry(
    tag: {
      'en': 'YHWH PATTERN',
      'zh-Hans': '神名暗藏',
      'zh-Hant': '神名暗藏',
    },
    title: {
      'en': 'Esther: God\'s name hidden 4 times in acrostic',
      'zh-Hans': '以斯帖记：神的名（YHWH）以离合形式暗藏 4 次',
      'zh-Hant': '以斯帖記：神的名（YHWH）以離合形式暗藏 4 次',
    },
    body: {
      'en':
          'The book of Esther never explicitly mentions God by name — '
              'striking for a Hebrew Scripture. But ancient scribes noted '
              'that the Tetragrammaton (YHWH, יהוה) appears 4 times as an '
              'ACROSTIC, formed by the first or last letters of '
              'consecutive words in 4 carefully-positioned verses '
              '(1:20, 5:4, 5:13, 7:7). The pattern alternates forward and '
              'reversed direction, marking moments where God\'s hidden '
              'providence breaks through the narrative.',
      'zh-Hans': '以斯帖记从头到尾**没有一次明确出现"神"或"耶和华"这个词**——'
          '这在整本希伯来圣经里非常罕见。但古代抄经士指出，'
          '神的四字圣名（YHWH，יהוה）以**离合形式暗藏 4 次**：'
          '在 1:20、5:4、5:13、7:7 这四节经文的连续词语首字母或末字母处依次出现，'
          '方向交替正读 / 倒读。这四处被认为是神隐藏护理在叙事中悄悄"显现"的关键时刻。',
      'zh-Hant': '以斯帖記從頭到尾**沒有一次明確出現「神」或「耶和華」這個詞**——'
          '這在整本希伯來聖經裡非常罕見。但古代抄經士指出，'
          '神的四字聖名（YHWH，יהוה）以**離合形式暗藏 4 次**：'
          '在 1:20、5:4、5:13、7:7 這四節經文的連續詞語首字母或末字母處依次出現，'
          '方向交替正讀 / 倒讀。這四處被認為是神隱藏護理在敘事中悄悄「顯現」的關鍵時刻。',
    },
    reference: 'Esther 5:4',
  ),
  _TriviaEntry(
    tag: {
      'en': 'YHWH PATTERN',
      'zh-Hans': '神名暗藏',
      'zh-Hant': '神名暗藏',
    },
    title: {
      'en': 'Ruth: Boaz greets the workers with the LORD\'s name',
      'zh-Hans': '路得记：波阿斯一句问安，连读神名两次',
      'zh-Hant': '路得記：波阿斯一句問安，連讀神名兩次',
    },
    body: {
      'en':
          'Ruth 2:4 — "Boaz arrived from Bethlehem and said to the '
              'harvesters, \'The LORD be with you!\' \'The LORD bless '
              'you!\' they answered." In Hebrew, the Tetragrammaton '
              '(YHWH, יהוה) appears TWICE in the same verse — Boaz\'s '
              'greeting and the workers\' response. In ancient Near East '
              'employer-worker relationships this was extraordinary: a '
              'wealthy landowner invoking God\'s name on his hired '
              'harvesters, who reply in kind. A small textual moment, a '
              'huge theological statement about godly leadership.',
      'zh-Hans': '路得记 2:4 ——"波阿斯从伯利恒来，对收割的人说：『愿耶和华与你们同在！』'
          '他们回答说：『愿耶和华赐福与你！』"原文希伯来文里，**神的圣名（YHWH，יהוה）'
          '在同一节经文里出现两次**——波阿斯打的招呼，以及工人的回应。'
          '古代近东主仆关系中这极为罕见：富有的地主直接以神的名向雇工问安，'
          '雇工也以神的名回应。一节经文中的小细节，'
          '却**蕴含整个旧约对"敬虔领导力"的神学**。',
      'zh-Hant': '路得記 2:4 ——「波阿斯從伯利恆來，對收割的人說：『願耶和華與你們同在！』'
          '他們回答說：『願耶和華賜福與你！』」原文希伯來文裡，**神的聖名（YHWH，יהוה）'
          '在同一節經文裡出現兩次**——波阿斯打的招呼，以及工人的回應。'
          '古代近東主僕關係中這極為罕見：富有的地主直接以神的名向雇工問安，'
          '雇工也以神的名回應。一節經文中的小細節，'
          '卻**蘊含整個舊約對「敬虔領導力」的神學**。',
    },
    reference: 'Ruth 2:4',
  ),

  // ── Numerical structures ─────────────────────────────────────
  _TriviaEntry(
    tag: {
      'en': 'STRUCTURE',
      'zh-Hans': '数字结构',
      'zh-Hant': '數字結構',
    },
    title: {
      'en': 'Genesis 1: Seven appears in Hebrew as a structural code',
      'zh-Hans': '创世记 1 章：希伯来原文中"七"是结构密码',
      'zh-Hant': '創世記 1 章：希伯來原文中「七」是結構密碼',
    },
    body: {
      'en':
          'In the Hebrew text of Genesis 1:1, there are exactly 7 words '
              'and 28 (= 7×4) Hebrew letters. The opening verse alone '
              'contains: 7 words, 28 letters, 14 letters in the divine '
              'subject phrase, 14 in the cosmic-object phrase. The number '
              '7 (completion / divine perfection in Hebrew thought) '
              'recurs throughout: "and God said" appears 7 times, "good" '
              'appears 7 times, the seventh day is set apart. The whole '
              'chapter is a literary tabernacle built on sevens.',
      'zh-Hans': '创世记 1:1 在希伯来原文中**正好 7 个单词、28（= 7×4）个字母**。'
          '仅这一节经文里就有：7 个词、28 个字母，主词短语 14 个字母，'
          '宾语短语也是 14 个字母。"七"（在希伯来思想中代表完整 / 神圣的完美）'
          '贯穿整章——"神说"出现 7 次，"好"出现 7 次，第七日被分别为圣。'
          '整章经文就是以"七"为支柱搭建起来的文学会幕。',
      'zh-Hant': '創世記 1:1 在希伯來原文中**正好 7 個單詞、28（= 7×4）個字母**。'
          '僅這一節經文裡就有：7 個詞、28 個字母，主詞短語 14 個字母，'
          '賓語短語也是 14 個字母。「七」（在希伯來思想中代表完整 / 神聖的完美）'
          '貫穿整章——「神說」出現 7 次，「好」出現 7 次，第七日被分別為聖。'
          '整章經文就是以「七」為支柱搭建起來的文學會幕。',
    },
    reference: 'Genesis 1:1',
  ),
  _TriviaEntry(
    tag: {
      'en': 'STRUCTURE',
      'zh-Hans': '数字结构',
      'zh-Hant': '數字結構',
    },
    title: {
      'en': 'Matthew 1: Jesus\'s genealogy is built around 14 (= David)',
      'zh-Hans': '马太福音 1 章：耶稣家谱以 14（= 大卫之名数值）为单位编排',
      'zh-Hant': '馬太福音 1 章：耶穌家譜以 14（= 大衛之名數值）為單位編排',
    },
    body: {
      'en':
          'Matthew explicitly lays out Jesus\'s genealogy in three '
              'sections of 14 generations each: Abraham → David, David → '
              'exile, exile → Christ (Matt 1:17). Why 14? In Hebrew '
              'numerology, the letters of "David" (דוד) sum to 14 '
              '(D=4, V=6, D=4). The whole genealogy is structured around '
              'David\'s name, hammering home Matthew\'s central claim: '
              'Jesus is the long-promised Davidic king.',
      'zh-Hans': '马太福音明确把耶稣家谱分成三段，每段 14 代：'
          '亚伯拉罕→大卫，大卫→被掳，被掳→基督（马太福音 1:17）。'
          '为什么是 14？希伯来字母数值学中，"大卫"（דוד）三个字母之和是 14'
          '（D=4，V=6，D=4）。整个家谱以**大卫的名字**为编排单位，'
          '反复强调马太福音的核心主张：**耶稣就是应许已久的大卫王**。',
      'zh-Hant': '馬太福音明確把耶穌家譜分成三段，每段 14 代：'
          '亞伯拉罕→大衛，大衛→被擄，被擄→基督（馬太福音 1:17）。'
          '為什麼是 14？希伯來字母數值學中，「大衛」（דוד）三個字母之和是 14'
          '（D=4，V=6，D=4）。整個家譜以**大衛的名字**為編排單位，'
          '反覆強調馬太福音的核心主張：**耶穌就是應許已久的大衛王**。',
    },
    reference: 'Matthew 1:17',
  ),

  // ── Linguistic curiosities ───────────────────────────────────
  _TriviaEntry(
    tag: {
      'en': 'WORDPLAY',
      'zh-Hans': '原文双关',
      'zh-Hant': '原文雙關',
    },
    title: {
      'en': 'Jeremiah\'s almond branch: a Hebrew pun for "watching"',
      'zh-Hans': '耶利米的杏树枝：希伯来文中"杏树"与"留意"是同根字',
      'zh-Hant': '耶利米的杏樹枝：希伯來文中「杏樹」與「留意」是同根字',
    },
    body: {
      'en':
          'In Jeremiah 1:11–12, God shows the prophet "an almond branch" '
              '(Hebrew: שָׁקֵד / shaqed). God then says, "I am watching '
              '(שֹׁקֵד / shoqed) over my word to perform it." The two '
              'words sound nearly identical — a wordplay impossible to '
              'render in translation. The vision is a memorable mnemonic: '
              'every almond branch reminds the prophet that God is '
              'shaqed/shoqed — alert, attentive, ready to act on his '
              'word.',
      'zh-Hans': '耶利米书 1:11–12 中，神让先知看见"一根杏树枝"'
          '（希伯来文：שָׁקֵד，shaqed），随后说："我留意（שֹׁקֵד，shoqed）保守我的话，'
          '使得成就。"两个词**发音几乎一致**——这种双关在翻译中不可能呈现。'
          '这个异象是一份可记可念的备忘录：先知每看见一棵杏树，'
          '就提醒自己神是 shaqed/shoqed——警醒、专注，必要成全祂的话。',
      'zh-Hant': '耶利米書 1:11–12 中，神讓先知看見「一根杏樹枝」'
          '（希伯來文：שָׁקֵד，shaqed），隨後說：「我留意（שֹׁקֵד，shoqed）保守我的話，'
          '使得成就。」兩個詞**發音幾乎一致**——這種雙關在翻譯中不可能呈現。'
          '這個異象是一份可記可念的備忘錄：先知每看見一棵杏樹，'
          '就提醒自己神是 shaqed/shoqed——警醒、專注，必要成全祂的話。',
    },
    reference: 'Jeremiah 1:11',
  ),
  _TriviaEntry(
    tag: {
      'en': 'WORDPLAY',
      'zh-Hans': '原文双关',
      'zh-Hant': '原文雙關',
    },
    title: {
      'en': 'Adam and adamah: man and ground share one root',
      'zh-Hans': '亚当与土地：希伯来原文中"人"和"地"是同一字根',
      'zh-Hant': '亞當與土地：希伯來原文中「人」和「地」是同一字根',
    },
    body: {
      'en':
          'In Genesis 2:7, God forms "the man" (אָדָם / adam) from "the '
              'ground" (אֲדָמָה / adamah). The two words share the same '
              'root — they\'re a built-in pun. The English equivalent '
              'might be "human from humus." Genesis 3 then deepens the '
              'pun when the curse sends Adam back to adamah: "for you are '
              'dust, and to dust you shall return." Body, ground, and '
              'mortality are bound by a single Hebrew root.',
      'zh-Hans': '创世记 2:7：神用"地上的尘土"（אֲדָמָה，adamah）造"人"（אָדָם，adam）。'
          '这两个词在希伯来原文中**同根**——是一个内建的双关。'
          '中文里勉强可以说"人取自土"。到创世记 3 章，咒诅把亚当送回 adamah："'
          '你本是尘土，仍要归于尘土。"**身体、土地、必死性**在希伯来原文中由同一字根串起。',
      'zh-Hant': '創世記 2:7：神用「地上的塵土」（אֲדָמָה，adamah）造「人」（אָדָם，adam）。'
          '這兩個詞在希伯來原文中**同根**——是一個內建的雙關。'
          '中文裡勉強可以說「人取自土」。到創世記 3 章，咒詛把亞當送回 adamah：「'
          '你本是塵土，仍要歸於塵土。」**身體、土地、必死性**在希伯來原文中由同一字根串起。',
    },
    reference: 'Genesis 2:7',
  ),
];
