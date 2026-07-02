// YsWords AI word explanation — Netlify Function. Asks Gemini to
// explain a Hebrew/Greek lemma as it functions in a specific verse.
// Modeled on the existing aiSearch function (same Gemini API +
// OpenAI-compatible endpoint, same env-var setup).
//
// Endpoint after deploy:
//   https://yswords.netlify.app/api/aiExplainWord
//
// Required Netlify env var:
//   GEMINI_API_KEY  — already set, shared with aiSearch.
// Optional:
//   GEMINI_MODEL    — default 'gemini-2.5-flash'
//   GEMINI_BASE_URL — default the OpenAI-compatible Gemini endpoint
//
// Body:
//   {
//     strongs:    'G25' | 'H430' | …                  (required)
//     lemma:      'ἀγαπάω' | 'אָב' | …                (required)
//     translit:   'agapao' | 'ab' | …                  (optional)
//     gloss:      'to love'                            (optional, lexicon gloss)
//     book:       'Genesis' (canonical English)         (required)
//     chapter:    1                                     (required)
//     verse:      1                                     (required)
//     verseText:  full verse text (any language)        (optional but helpful)
//     locale:     'en' | 'zh-Hans' | 'zh-Hant'          (default 'en')
//   }
// Reply:
//   { explanation: '<plain prose, 80-180 words>' }
// Error:
//   { error: 'human-readable reason' }

// Default to gemini-2.5-flash-lite (round 55):
//   - 4× daily free quota of 2.5-flash (1000 vs 250 per key)
//   - 1.5× per-minute (15 vs 10)
//   - No "thinking" tokens — the entire max_tokens budget goes to
//     the visible answer, eliminating round-54's truncation class
//   - Quality is plenty for "explain this Greek/Hebrew word in this
//     verse" — the model has seen extensive biblical-language data
//     in training and produces solid exegesis paragraphs.
//
// Override at the Netlify project level by setting GEMINI_MODEL —
// e.g. 'gemini-2.5-flash' for higher quality on chapters where
// reasoning helps more, or 'gemini-2.5-pro' (very limited quota,
// 5 RPM / 100 RPD).
// 2026-06-30: gemini-2.5-flash-lite stays the default — it's the FASTEST model
// (~1-2s) with the highest free-tier quota. Its occasional HTTP 503 is a
// TRANSIENT "high demand" spike (Google's own message), NOT deprecation, so the
// real fix is that the step-down chain below now falls back on 5xx (not just
// 429) → gemini-2.5-flash → gemini-3-flash-preview, recovering automatically.
// (An earlier same-day patch wrongly made gemini-2.5-flash the default; that
// model's free tier is only ~20 req/day and exhausted fast — reverted.)
const MODEL = process.env.GEMINI_MODEL || 'gemini-2.5-flash-lite';

// 2026-05-10 (v1.2.26): per-request AI tier override, identical
// shape to aiBibleSearch.mjs / aiSearch.mjs. Allowlist-clamped.
// 2026-05-11 (v1.2.40): see aiBibleSearch.mjs's note — `pro` now
// maps to `gemini-3-flash-preview` because Google moved
// `gemini-2.5-pro` behind a paywall on April 1 2026.
const _AI_MODEL_MAP = {
	'flash-lite': 'gemini-2.5-flash-lite',
	'flash':      'gemini-2.5-flash',
	'pro':        'gemini-3-flash-preview',
};
function resolveModel(tierRaw) {
	if (typeof tierRaw !== 'string') return MODEL;
	const tier = tierRaw.trim();
	return _AI_MODEL_MAP[tier] || MODEL;
}
const BASE_URL =
	(process.env.GEMINI_BASE_URL ||
		'https://generativelanguage.googleapis.com/v1beta/openai').replace(/\/$/, '');

function langName(locale) {
	switch (locale) {
		case 'zh-Hans': return 'Simplified Chinese (简体中文)';
		case 'zh-Hant': return 'Traditional Chinese (繁體中文)';
		default: return 'English';
	}
}

// Round 56 (continued — locale fix): a locale-targeted system
// preamble that the LLM reads BEFORE the user prompt. Putting the
// language instruction here (in addition to repeating it at the
// top of the user prompt) is what actually makes Gemini honour
// 'zh-Hans' / 'zh-Hant' — when the directive sits at line 142 of
// an otherwise-English prompt the model defaults to matching the
// dominant context language. A locale-aware system message sets
// the language frame *before* any English context arrives.
function languageDirective(locale) {
	switch (locale) {
		case 'zh-Hans':
			return '你必须用简体中文回答。整个回答都用简体中文，不要用英文（除了希伯来文 / 希腊文原文、Strong\'s 编号、地名人名等不可避免的部分）。';
		case 'zh-Hant':
			return '你必須用繁體中文回答。整個回答都用繁體中文，不要用英文（除了希伯來文 / 希臘文原文、Strong\'s 編號、地名人名等不可避免的部分）。';
		default:
			return 'Reply ONLY in English.';
	}
}

// 2026-05-24 (v1.3.13): on Chinese locales the model routinely
// leaked English into the response — not just unavoidable bits
// (Strong's numbers, Hebrew/Greek originals) but full English
// labels like "Lexical core", whole sentences, English book
// names ("Genesis" instead of "创世记").
//
// Root cause: the `focus` text + `parts.push(...)` body in
// buildPrompt were 100% English. Two-thirds of what the model
// read was English context. The "answer in Chinese" directive
// alone wasn't enough — Gemini defaults to matching the
// dominant context language. Round-56 added the directive at
// top + bottom, but the body remained English.
//
// Fix: ship a parallel Chinese focus/body. Both directive AND
// content are Chinese; the model has no English context to fall
// back to. We ship Simplified for both zh-Hans and zh-Hant
// callers — the response language directive (which is per-locale
// Traditional / Simplified) makes the model auto-convert its
// OUTPUT to the user's preferred variant; the model only reads
// the prompt and never echoes it back verbatim.
function styleProfile(length, scope, locale) {
  const isZh = locale === 'zh-Hans' || locale === 'zh-Hant';
  return isZh ? _styleProfileZh(length, scope)
              : _styleProfileEn(length, scope);
}

function _styleProfileEn(length, scope) {
	let words;
	switch (length) {
		case 'concise': words = '60-110 words'; break;
		case 'longer':  words = '300-450 words'; break;
		// 2026-05-07: BDAG-style deep exegesis — pushes the model to
		// give a comprehensive multi-paragraph analysis covering
		// etymology, lexical-semantic field, syntax, historical
		// background, and theological weight. Roughly the depth a
		// professional commentary entry would have. Uses the same
		// max_tokens=4096 budget but drives output toward the upper
		// end of it.
		case 'deep':    words = '500-750 words'; break;
		default:        words = '150-260 words';
	}
	let focus;
	switch (scope) {
		case 'chapter':
			focus = `Focus the explanation on how this word functions across ` +
				`the **whole chapter** of {book} {chapter} — its other ` +
				`occurrences (if any) in this chapter, the chapter's ` +
				`argument or narrative arc, and how this word advances it.`;
			break;
		case 'book':
			focus = `Focus the explanation on how this word functions across ` +
				`the **whole book** of {book} — major occurrences and the ` +
				`book's overall theology, narrative arc, or rhetorical ` +
				`structure. Connect them back to {ref}.`;
			break;
		case 'wholeBible':
			focus = `Trace this word across the **whole Bible** — its OT ` +
				`(Hebrew) and NT (Greek) usage, key passages, and how the ` +
				`canonical pattern illuminates {ref}. If the word is a ` +
				`Greek term, note any LXX use of the corresponding Hebrew. ` +
				`If Hebrew, note any NT echoes via the LXX.`;
			break;
		case 'otherChapters':
			focus = `List 2-4 other notable verses (in other chapters or ` +
				`other books) where this same lemma is used, briefly ` +
				`describing the nuance in each, then explain what those ` +
				`other usages teach the reader about its meaning in {ref}.`;
			break;
		case 'crossTestament':
			// The function decides direction based on the Strong's
			// prefix (G* = Greek/NT, H* = Hebrew/OT). For NT readers
			// we surface the OT concept the word inherits; for OT
			// readers we trace forward to NT usage via the LXX.
			focus = `Trace this word ACROSS THE TWO TESTAMENTS. ` +
				`If this is a NT (Greek) word, identify the Hebrew/OT ` +
				`word(s) it most often translates in the LXX, list 2-3 ` +
				`key OT passages where that concept appears, and explain ` +
				`how the OT background shapes the meaning in {ref}. ` +
				`If this is an OT (Hebrew) word, identify the Greek ` +
				`word(s) the LXX uses to render it, list 2-3 key NT ` +
				`passages where it carries the same idea, and explain ` +
				`how the NT picks up the OT theme in {ref}. ` +
				`Be specific with verse references.`;
			break;
		case 'deepExegesis':
			// 2026-05-07: BDAG-level deep exegesis. Combines word
			// analysis + verse context + chapter flow + historical /
			// cultural background + theological significance. Mirrors
			// what a serious commentary entry would offer. Pair with
			// length='deep' for ~500-750 words.
			focus = `Provide a **deep, BDAG-style exegetical analysis** ` +
				`grounded in {ref}. Structure your answer with these ` +
				`labelled sections (use bold headers in the user's ` +
				`language):\n\n` +
				`1. **Lexical core** — the word's primary meaning, ` +
				`semantic range, and key morphology (Greek tense / ` +
				`voice / mood / case, or Hebrew stem / binyan / ` +
				`gender / number). Mention the etymology where it ` +
				`illuminates the meaning.\n\n` +
				`2. **Usage in this verse** — exactly how the word ` +
				`functions in {ref}: syntactic role, what it modifies ` +
				`or is modified by, the nuance it contributes that a ` +
				`generic translation might lose.\n\n` +
				`3. **Cultural / historical context** — relevant ` +
				`first-century (NT) or ancient-Near-East (OT) ` +
				`background — social customs, legal frameworks, ` +
				`linguistic precedents, parallels in extra-biblical ` +
				`texts (LXX, DSS, Josephus, Philo, ANE inscriptions) ` +
				`that clarify the word's force here.\n\n` +
				`4. **Canonical pattern** — 2-3 other key biblical ` +
				`passages where the same lemma appears, briefly ` +
				`noting the nuance in each, and what those usages ` +
				`reveal when read alongside {ref}.\n\n` +
				`5. **Theological weight** — what doctrinal or ` +
				`pastoral significance this word carries in {ref}. ` +
				`Be substantive but avoid partisan / denominational ` +
				`positions.\n\n` +
				`Be precise with references (book chapter:verse). ` +
				`Avoid invented details. If a claim is debated among ` +
				`scholars, note that briefly. Quality over quantity ` +
				`within the target word range.`;
			break;
		default: // 'verse'
			focus = `Focus tightly on **this verse** ({ref}). Cover, in ` +
				`order: (1) one concise sentence on the word's core meaning ` +
				`framed for this verse; (2) the bulk: how the word ` +
				`actually functions in {ref} — nuance, tense/voice/mood ` +
				`(Greek) or stem/binyan (Hebrew), syntactic role, ` +
				`theological weight, what the verse would lose if a ` +
				`near-synonym were used; (3) one related observation that ` +
				`deepens understanding of the verse.`;
	}
	return { words, focus };
}

// Chinese-locale focus templates. Same semantic structure as the
// English versions above; written in Simplified Chinese (the
// directive at top + bottom of buildPrompt makes the model emit
// Traditional when locale === 'zh-Hant').
function _styleProfileZh(length, scope) {
	let words;
	switch (length) {
		case 'concise': words = '60-110 字'; break;
		case 'longer':  words = '300-450 字'; break;
		case 'deep':    words = '500-750 字'; break;
		default:        words = '150-260 字';
	}
	let focus;
	switch (scope) {
		case 'chapter':
			focus = `请围绕这个词在 {book} {chapter} 整章的功能 — ` +
				`它在本章其他经文中的出现（如果有），章节论证或叙事的展开，` +
				`以及这个词如何推进叙事 — 来展开说明。`;
			break;
		case 'book':
			focus = `请围绕这个词在 {book} 整卷书的功能 — 主要出现位置，` +
				`整卷的神学、叙事弧线或修辞结构 — 展开，并把这些` +
				`观察连回 {ref}。`;
			break;
		case 'wholeBible':
			focus = `请追溯这个词在整本圣经的用法 — 旧约（希伯来文）和` +
				`新约（希腊文）的使用，关键段落，以及这个正典脉络` +
				`如何照亮 {ref} 的意义。如果这是希腊词，请提及七十士` +
				`译本对应希伯来词的用法；如果是希伯来词，请提及新约` +
				`通过七十士译本的回响。`;
			break;
		case 'otherChapters':
			focus = `请列举 2-4 处同一词根（lemma）出现的其他显著经文（在` +
				`其他章节或其他书卷），简要说明每一处的语义差异，然后` +
				`说明这些其他用法对理解 {ref} 中该词的意义有何启发。`;
			break;
		case 'crossTestament':
			focus = `请跨越两约追溯这个词。如果这是新约（希腊文）词，` +
				`请指出它在七十士译本中最常翻译的希伯来/旧约词，` +
				`列举 2-3 处这个概念出现的关键旧约经文，并说明旧约` +
				`背景如何塑造 {ref} 中的意义。如果是旧约（希伯来文）词，` +
				`请指出七十士译本所用的希腊词，列举 2-3 处带有相同` +
				`概念的关键新约经文，并说明新约如何承接这个旧约主题` +
				`在 {ref} 中的展开。引用经文要具体到 书 章:节。`;
			break;
		case 'deepExegesis':
			focus = `请就 {ref} 提供一份 BDAG 风格的深度释经分析。` +
				`回答按以下标题分段（标题请用中文加粗，例如 **词义核心**）：\n\n` +
				`1. **词义核心** — 这个词的主要含义、语义范围，以及关键形态` +
				`（希腊文的时态/语态/语气/格，或希伯来文的字干/性别/数）。` +
				`如果词源对意义有启发，请提及。\n\n` +
				`2. **本节用法** — 这个词在 {ref} 中具体如何运作：句法角色、` +
				`修饰什么或被什么修饰、它带来的细微之处（普通翻译可能丢失）。\n\n` +
				`3. **文化 / 历史背景** — 相关的第一世纪（新约）或古近东（旧约）` +
				`背景 — 社会习俗、法律框架、语言学先例、圣经外文献的平行` +
				`（七十士译本、死海古卷、约瑟夫、斐洛、古近东碑文等）` +
				`能阐明该词在此处的力度。\n\n` +
				`4. **正典脉络** — 同一词根（lemma）在 2-3 处其他关键圣经经文` +
				`的用法，简述每处的细微差异，以及这些用法与 {ref} 对读时` +
				`所揭示的意义。\n\n` +
				`5. **神学分量** — 这个词在 {ref} 中承载的教义或牧养意义。` +
				`要有实质性，但避免宗派/立场性的论断。\n\n` +
				`引用经文要精确（书 章:节）。不要捏造细节。如果某个观点在` +
				`学者间有争议，简要指出。在目标字数范围内，宁可少而精。`;
			break;
		default: // 'verse'
			focus = `请紧扣本节（{ref}）展开。按顺序覆盖：` +
				`(1) 一句话概括该词围绕本节的核心意义；` +
				`(2) 主体部分：这个词在 {ref} 中如何运作 — 细微之处、` +
				`时态/语态/语气（希腊文）或字干（希伯来文）、句法角色、` +
				`神学分量，以及如果换用近义词会失去什么；` +
				`(3) 一个加深理解的相关观察。`;
	}
	return { words, focus };
}

// 2026-05-24 (v1.3.13): when the caller is on a Chinese locale,
// swap the canonical-English book name to its Simplified Chinese
// equivalent inside the prompt. Without this the model sees
// "Genesis 1:1" in the user prompt and routinely echoes "Genesis"
// (instead of "创世记") in its Chinese answer — even with the
// language directive top + bottom. Traditional readers also get
// Simplified in the PROMPT — the response-language directive
// flips the model's OUTPUT to Traditional, and the prompt itself
// is never echoed verbatim.
const _BOOK_ZH = {
	'Genesis': '创世记', 'Exodus': '出埃及记', 'Leviticus': '利未记',
	'Numbers': '民数记', 'Deuteronomy': '申命记', 'Joshua': '约书亚记',
	'Judges': '士师记', 'Ruth': '路得记',
	'1 Samuel': '撒母耳记上', '2 Samuel': '撒母耳记下',
	'1 Kings': '列王纪上', '2 Kings': '列王纪下',
	'1 Chronicles': '历代志上', '2 Chronicles': '历代志下',
	'Ezra': '以斯拉记', 'Nehemiah': '尼希米记', 'Esther': '以斯帖记',
	'Job': '约伯记', 'Psalms': '诗篇', 'Proverbs': '箴言',
	'Ecclesiastes': '传道书', 'Song of Solomon': '雅歌',
	'Song of Songs': '雅歌',
	'Isaiah': '以赛亚书', 'Jeremiah': '耶利米书',
	'Lamentations': '耶利米哀歌', 'Ezekiel': '以西结书',
	'Daniel': '但以理书', 'Hosea': '何西阿书', 'Joel': '约珥书',
	'Amos': '阿摩司书', 'Obadiah': '俄巴底亚书', 'Jonah': '约拿书',
	'Micah': '弥迦书', 'Nahum': '那鸿书', 'Habakkuk': '哈巴谷书',
	'Zephaniah': '西番雅书', 'Haggai': '哈该书',
	'Zechariah': '撒迦利亚书', 'Malachi': '玛拉基书',
	'Matthew': '马太福音', 'Mark': '马可福音', 'Luke': '路加福音',
	'John': '约翰福音', 'Acts': '使徒行传', 'Romans': '罗马书',
	'1 Corinthians': '哥林多前书', '2 Corinthians': '哥林多后书',
	'Galatians': '加拉太书', 'Ephesians': '以弗所书',
	'Philippians': '腓立比书', 'Colossians': '歌罗西书',
	'1 Thessalonians': '帖撒罗尼迦前书',
	'2 Thessalonians': '帖撒罗尼迦后书',
	'1 Timothy': '提摩太前书', '2 Timothy': '提摩太后书',
	'Titus': '提多书', 'Philemon': '腓利门书', 'Hebrews': '希伯来书',
	'James': '雅各书', '1 Peter': '彼得前书', '2 Peter': '彼得后书',
	'1 John': '约翰一书', '2 John': '约翰二书', '3 John': '约翰三书',
	'Jude': '犹大书', 'Revelation': '启示录',
};

function localizeBook(book, locale) {
	if (locale !== 'zh-Hans' && locale !== 'zh-Hant') return book;
	return _BOOK_ZH[book] || book;
}

function buildPrompt({ strongs, lemma, translit, gloss, book, chapter, verse, verseText, locale, length, scope }) {
	const lang = langName(locale);
	const langDirective = languageDirective(locale);
	const isZh = locale === 'zh-Hans' || locale === 'zh-Hant';
	const localBook = localizeBook(book, locale);
	const ref = `${localBook} ${chapter}:${verse}`;
	const profile = styleProfile(length, scope, locale);
	const focus = profile.focus
		.replaceAll('{book}', localBook)
		.replaceAll('{chapter}', String(chapter))
		.replaceAll('{ref}', ref);
	const parts = [];
	// Round 56 (continued — locale fix): the language directive is
	// now the FIRST line of the user prompt + repeated as the LAST
	// line + planted in the system message. This is the only
	// configuration that reliably gets Gemini to switch off the
	// English default for zh-Hans / zh-Hant — earlier we put it
	// only in the middle of the prompt and the model kept defaulting
	// to English because the surrounding context is overwhelmingly
	// English.
	parts.push(langDirective);
	parts.push('');
	if (isZh) {
		// 2026-05-24 (v1.3.13): full Chinese prompt body. With the
		// directive + body + focus all in Chinese and the book name
		// localized, the model has no English context to anchor on.
		parts.push(`你是一位严谨的圣经语言释经家。`);
		parts.push(`读者正在研读 ${ref}，已经看过 **${lemma}**` +
			(translit ? `（${translit}）` : '') +
			` 的辞典词条（Strong's ${strongs}）` +
			(gloss ? `，其核心意义为「${gloss}」` : '') + `。`);
		parts.push(focus);
		if (verseText) parts.push(`该经节内容:"${verseText}"`);
		parts.push('');
		parts.push(`目标字数:${profile.words}。仅使用普通散文。` +
			`不要使用 Markdown 格式 — 不要用星号(*、**、***)、` +
			`下划线(_、__)、井号标题(#、##、###)、` +
			`项目符号(- 或 *)、横线(---)。如需强调,请用文字` +
			`本身表达。务必把最后一句写完整 — 不要中途断开。`);
		parts.push('');
		parts.push(`保持严谨。不要编造词源。不要说教。` +
			`不要用"学者们争论"这类含糊措辞,除非真有释经分歧。` +
			`如果该词是专有名词,请聚焦于这个名字在相关叙事中` +
			`的意义,而不是字面词源。`);
		parts.push('');
		parts.push(`圣经书卷名一律使用中文(例如:创世记、诗篇、` +
			`马太福音),不要写成英文。`);
		parts.push('');
	} else {
		parts.push(`You are a careful biblical-language exegete.`);
		parts.push(`The reader is studying ${ref} and has already seen the ` +
			`lexicon entry for **${lemma}**` +
			(translit ? ` (${translit})` : '') +
			` (Strong's ${strongs})${gloss ? ` whose core meaning is "${gloss}"` : ''}.`);
		parts.push(focus);
		if (verseText) parts.push(`The verse reads: "${verseText}"`);
		parts.push('');
		parts.push(`Target length: ${profile.words}. ` +
			`Use plain prose only. NEVER use markdown formatting — no ` +
			`asterisks (*, **, ***), no underscores (_, __), no hash ` +
			`headings (#, ##, ###), no bullet points (- or *), no ` +
			`horizontal rules (---). If you want emphasis, use plain ` +
			`words. Always finish your final sentence — never trail off ` +
			`mid-thought.`);
		parts.push('');
		parts.push(`Stay rigorous. Don't invent etymology. Don't moralize. ` +
			`Don't hedge with "scholars debate" unless there's a real exegetical ` +
			`split. If the word is a proper name, focus on the name's ` +
			`significance in the relevant narrative(s) rather than its ` +
			`etymological gloss.`);
		parts.push('');
	}
	// Repeat the language directive at the very end so the last
	// thing the model sees before generating is "answer in X".
	parts.push(`【${lang}】 ${langDirective}`);
	return parts.join('\n');
}

// v1.3.x: plain-language explanation of a whole VERSE (or short verse
// range) for an ordinary reader — triggered by `task: 'versePlain'`
// (the reader taps a verse + the "AI explain" action in the reading
// pane's selection bar). Reuses all of this function's infra
// (key rotation, model step-down, BYOK, CORS); only the prompt differs
// from the word-study path. Always answers in the reader's locale.
function buildVersePrompt({ book, chapter, verseStart, verseEnd, verseText, locale, length, userQuestion, history }) {
	const lang = langName(locale);
	const langDirective = languageDirective(locale);
	const isZh = locale === 'zh-Hans' || locale === 'zh-Hant';
	const localBook = localizeBook(book, locale);
	const ref = (verseEnd && verseEnd > verseStart)
		? `${localBook} ${chapter}:${verseStart}-${verseEnd}`
		: `${localBook} ${chapter}:${verseStart}`;
	// v1.3.68: when the reader supplied a free-text question, answer THAT
	// question (grounded in the passage) instead of emitting the default
	// whole-passage explanation. Everything else — locale, no-markdown
	// prose format, faithfulness rules, length band — is shared.
	const q = (userQuestion || '').trim();
	const hasQ = q.length > 0;
	// v1.3.73: compact transcript of earlier turns (follow-up context).
	const hist = (history || '').trim();
	let words;
	switch (length) {
		case 'concise': words = isZh ? '60-110 字' : '60-110 words'; break;
		case 'longer':  words = isZh ? '300-450 字' : '300-450 words'; break;
		case 'deep':    words = isZh ? '500-750 字' : '500-750 words'; break;
		default:        words = isZh ? '150-260 字' : '150-260 words';
	}
	const parts = [];
	parts.push(langDirective);
	parts.push('');
	if (isZh) {
		parts.push('你是一位严谨而温暖的圣经教师，帮助普通读者理解经文。');
		if (hist) {
			parts.push(`以下是你们之前的对话（供参考，请保持连贯，不要重复已说过的内容）：\n${hist}`);
			parts.push('');
		}
		if (hasQ) {
			// Question mode: answer the reader's specific question, anchored
			// in the cited passage.
			parts.push(`读者正在阅读 ${ref}，并就这段经文提出了一个问题。` +
				`请紧扣这段经文、用连贯的散文段落回答这个问题。`);
			parts.push(`读者的问题是：「${q}」`);
			parts.push(`请直接回答这个问题：先正面回应读者所问，必要时简要` +
				`交代相关的上下文或关键词含义来支持你的回答；只在与问题相关` +
				`时才展开，不要泛泛重述整段经文。如果问题超出这段经文所能` +
				`回答的范围，或圣经没有明说，请诚实说明，不要臆测或编造。`);
		} else {
			parts.push(`读者正在阅读 ${ref}。请用连贯的散文段落解释这段经文的含义。`);
			// v1.3.x: phrase the coverage as prose to weave in — NOT a
			// numbered list. The old "(1)(2)(3)" structure made the model
			// emit a bullet/numbered outline with bold headers (+ a leaked
			// "快速思考：" preamble), which looked messy in the panel.
			parts.push(`请自然地融入以下几方面（连成通顺的段落，不要分点、` +
				`不要小标题）：先用一两句交代上下文背景（这段经文在书卷与` +
				`章节中的位置和处境），再说明经文在说什么、关键词或意象的` +
				`含义、作者要传达的要点，最后给出一个帮助今天的读者理解` +
				`或应用的观察。`);
		}
		if (verseText) parts.push(`经文内容:"${verseText}"`);
		parts.push('');
		parts.push(`目标字数:${words}。`);
		parts.push(`格式要求（务必严格遵守）：直接开始解释正文，不要任何` +
			`前言、问候或「好的」「我们来看」之类的开场白；绝对不要输出` +
			`「快速思考」「思考」等思考过程或步骤标记。全文用普通、连贯的` +
			`散文段落（段落之间可用空行分隔），不要使用任何 Markdown：` +
			`不要星号(*、**)、井号标题(#)、项目符号(-)、数字编号(1. 2. 3.)。` +
			`务必把最后一句写完整。`);
		parts.push('');
		parts.push('保持忠于经文，不要编造历史细节，不要说教，也不要加入' +
			'宗派立场。圣经书卷名一律使用中文(例如:创世记、诗篇、马太福音)。');
		parts.push('');
	} else {
		parts.push('You are a rigorous yet warm Bible teacher helping an ' +
			'ordinary reader understand a passage.');
		if (hist) {
			parts.push(`Here is the conversation so far (for context — stay ` +
				`coherent and do not repeat what was already said):\n${hist}`);
			parts.push('');
		}
		if (hasQ) {
			// Question mode: answer the reader's specific question, anchored
			// in the cited passage.
			parts.push(`The reader is reading ${ref} and has a question about ` +
				`this passage. Answer their question in flowing prose ` +
				`paragraphs, staying anchored to this passage.`);
			parts.push(`The reader's question is: "${q}"`);
			parts.push(`Answer the question directly: address what they asked ` +
				`first, bringing in only the context or key-word meaning needed ` +
				`to support your answer; do not simply restate the whole ` +
				`passage. If the question goes beyond what this passage can ` +
				`answer, or Scripture does not say, say so honestly rather than ` +
				`speculating or inventing details.`);
		} else {
			parts.push(`The reader is reading ${ref}. Explain what this passage ` +
				`means in flowing prose paragraphs.`);
			parts.push(`Weave in naturally (as connected prose — NOT a numbered ` +
				`list and NOT headed sections): first a sentence or two of ` +
				`context (where this sits in the book and chapter, and its ` +
				`situation), then what the passage says, the meaning of key ` +
				`words or images, and the point the author is making, and ` +
				`finally one observation that helps a reader today understand ` +
				`or apply it.`);
		}
		if (verseText) parts.push(`The passage reads: "${verseText}"`);
		parts.push('');
		parts.push(`Target length: ${words}.`);
		parts.push(`FORMAT (follow strictly): start directly with the ` +
			`explanation — no preamble, greeting, or "Okay/Sure/Let's look"; ` +
			`and NEVER output any "thinking", chain-of-thought, or step ` +
			`markers. Write plain, connected prose paragraphs (a blank line ` +
			`between paragraphs is fine). Use NO Markdown whatsoever: no ` +
			`asterisks (*, **), no hash headings (#), no bullets (-), no ` +
			`numbered lists (1. 2. 3.). Always finish your final sentence.`);
		parts.push('');
		parts.push('Stay faithful to the text. Do not invent historical ' +
			'details. Do not moralize or take denominational positions.');
		parts.push('');
	}
	parts.push(`【${lang}】 ${langDirective}`);
	return parts.join('\n');
}

// Build the ordered list of API keys to try. Each entry has its own
// per-minute and per-day quota in the free tier, so falling back to a
// secondary key when the primary hits 429 effectively doubles (or
// triples …) the throughput without needing a paid plan.
//
// Env vars (in priority order):
//   GEMINI_API_KEYS        — optional, comma-separated explicit list
//   GEMINI_API_KEY         — primary
//   GEMINI_API_KEY_BACKUP  — secondary
//   GEMINI_API_KEY_BACKUP_2 … _9 — tertiary onward, optional
//
// Returned list is de-duplicated and trimmed; falsy entries skipped.
function geminiKeys() {
	const seen = new Set();
	const out = [];
	const push = (s) => {
		const k = (s || '').trim();
		if (k && !seen.has(k)) {
			seen.add(k);
			out.push(k);
		}
	};
	if (process.env.GEMINI_API_KEYS) {
		for (const part of process.env.GEMINI_API_KEYS.split(',')) push(part);
	}
	push(process.env.GEMINI_API_KEY);
	push(process.env.GEMINI_API_KEY_BACKUP);
	for (let i = 2; i <= 9; i++) push(process.env[`GEMINI_API_KEY_BACKUP_${i}`]);
	return out;
}

// Round 56 (continued — locale fix): system message now starts with
// the language directive in the target language, so the model has
// already locked in the response language by the time it reaches
// any English context in the user prompt.
// 2026-05-24 (v1.3.13): system message body is also localized for
// Chinese locales — previously the directive was in Chinese but
// the rest of the system instructions were in English, which gave
// the model an English anchor before the user prompt even arrived.
function buildSystemMessage(locale) {
	if (locale === 'zh-Hans') {
		return '【请用简体中文回答】所有回答必须用简体中文。' +
			'你是一位精准的圣经语言释经家。你的回答简明、准确,紧扣' +
			'所引经文。不要捏造细节,不要引用你没看过的资料。' +
			'快速思考(最多几秒),然后一次性产出完整答案。务必把' +
			'每一句都写完整 — 绝不在中途断开,绝不以逗号或类似' +
			'"的"、"之"这样的悬空字结尾;如果回应即将被截断,' +
			'请用一句完整的话收尾。' +
			'圣经书卷名一律使用中文(例如:创世记、诗篇、马太福音),' +
			'不要写成英文。';
	}
	if (locale === 'zh-Hant') {
		return '【請用繁體中文回答】所有回答必須用繁體中文。' +
			'你是一位精準的聖經語言釋經家。你的回答簡明、準確,緊扣' +
			'所引經文。不要捏造細節,不要引用你沒看過的資料。' +
			'快速思考(最多幾秒),然後一次性產出完整答案。務必把' +
			'每一句都寫完整 — 絕不在中途斷開,絕不以逗號或類似' +
			'「的」、「之」這樣的懸空字結尾;如果回應即將被截斷,' +
			'請用一句完整的話收尾。' +
			'聖經書卷名一律使用中文(例如:創世記、詩篇、馬太福音),' +
			'不要寫成英文。';
	}
	return '[Reply in English] ' +
		'You are a precise biblical-language exegete. You ' +
		'reply with concise, accurate explanations grounded ' +
		'in the cited verse. You do not invent details or ' +
		'cite sources you have not seen. ' +
		'Think briefly (a few seconds at most), then ' +
		'produce the full answer in one go. Always finish ' +
		'every sentence — never trail off mid-thought, ' +
		'never end with a comma or with text like "the " ' +
		'or "之"; if the response is being truncated, ' +
		'wrap up with a complete final sentence.';
}

async function callGeminiWithKey(apiKey, prompt, locale, model) {
	const url = `${BASE_URL}/chat/completions`;
	const resp = await fetch(url, {
		method: 'POST',
		headers: {
			Authorization: `Bearer ${apiKey}`,
			'Content-Type': 'application/json',
		},
		body: JSON.stringify({
			model: model,
			messages: [
				{ role: 'system', content: buildSystemMessage(locale) },
				{ role: 'user', content: prompt },
			],
			temperature: 0.2,
			// 4096 tokens. Round 54 fix: gemini-2.5-flash uses
			// "thinking" tokens INTERNALLY before producing the visible
			// reply, and `max_tokens` is the COMBINED budget (thinking
			// + output), not just output. With 1024 the thinking phase
			// could eat 800+ tokens leaving the answer truncated to
			// 60-150 chars (user reported "got cuts off" with every
			// chunk ending mid-sentence). 4096 leaves >2500 tokens for
			// the actual answer even when thinking burns 1500.
			//
			// We also tell the model explicitly to keep thinking short
			// in the prompt; this header shaves another few hundred
			// tokens off the thinking phase.
			max_tokens: 4096,
		}),
		signal: AbortSignal.timeout(modelTimeoutMs(model)),
	});
	return resp;
}

// 2026-05-11 (v1.2.43): per-model abort timeout. v1.2.42's flat
// 8s killed `gemini-3-flash-preview` mid-thinking on heavy
// prompts (user reported on Acts 19:14 exegesis). See
// aiBibleSearch.mjs for the full rationale.
// 2026-05-22 (v1.2.79): Deep 18→14s so Standard fallback fits within
// the 24s deadline. Detailed rationale in aiBibleSearch.mjs.
function modelTimeoutMs(model) {
	switch (model) {
		case 'gemini-3-flash-preview': return 14_000;
		case 'gemini-2.5-flash':       return 10_000;
		case 'gemini-2.5-flash-lite':  return 6_000;
		default: return 10_000;
	}
}

// 2026-05-11 (v1.2.41): model step-down chain. See
// aiBibleSearch.mjs for the full rationale — each site has only
// 1 Gemini key, so model fallback on 429 is the only way to keep
// AI responses flowing past the per-tier daily quota.
function modelStepDown(model) {
	switch (model) {
		// 2026-06-30: linear escalation so any 503/429 on one model tries a
		// DIFFERENT model with its own quota: flash-lite (fast, high quota) →
		// flash (~20/day) → 3-flash-preview → stop. Terminates naturally.
		case 'gemini-2.5-flash-lite':  return 'gemini-2.5-flash';
		case 'gemini-2.5-flash':        return 'gemini-3-flash-preview';
		default: return null;
	}
}

// Inner key-rotation: try every key with one specific model.
async function _callGeminiInner(prompt, locale, keys, model) {
	let lastStatus = 0;
	let lastErrorKind = ''; // 'auth' | 'quota' | 'upstream' | ''
	let lastUpstreamBody = '';
	for (let i = 0; i < keys.length; i++) {
		const apiKey = keys[i];
		const isLast = i === keys.length - 1;
		let resp;
		try {
			resp = await callGeminiWithKey(apiKey, prompt, locale, model);
		} catch (e) {
			console.error(`[aiExplainWord] ${model} key #${i + 1} fetch threw:`,
				String(e?.message || e).slice(0, 400));
			lastErrorKind = 'upstream';
			continue;
		}
		if (resp.ok) {
			const json = await resp.json();
			const choice = json.choices?.[0];
			const content = choice?.message?.content;
			let text = '';
			if (typeof content === 'string') text = content;
			else if (Array.isArray(content)) {
				text = content
					.map((p) => (typeof p === 'string' ? p : (p?.text || '')))
					.join('');
			}
			return { ok: true, text };
		}
		const txt = await resp.text();
		lastStatus = resp.status;
		if (resp.status === 429) {
			lastErrorKind = 'quota';
			continue;
		}
		if (resp.status === 401 || resp.status === 403) {
			console.error(`[aiExplainWord] ${model} key #${i + 1} rejected`,
				resp.status, isLast ? '(no keys remaining)' : '(trying next)');
			lastErrorKind = 'auth';
			continue;
		}
		console.error(`[aiExplainWord] ${model} HTTP ${resp.status}:`,
			txt.slice(0, 1200));
		lastErrorKind = 'upstream';
		lastUpstreamBody = txt.slice(0, 400);
		break;
	}
	return { ok: false, status: lastStatus, errorKind: lastErrorKind, body: lastUpstreamBody };
}

async function callGemini(prompt, locale, overrideKey = null, model = MODEL, ctx = null) {
	// BYOK: when the client provided a valid-shape user key, try that
	// key FIRST. v1.3.30 (2026-05-24): if BYOK fails with auth or
	// quota, transparently fall back to the developer's shared key
	// instead of erroring out — previously the user saw the opaque
	// `"Upstream AI service error (HTTP 400)"` and had to manually
	// clear their key in Settings. User asked for auto-fallback; the
	// flow is now: (1) try BYOK key, (2) if 401/403 or 429, switch to
	// shared keys + restart the model chain, (3) report `byokFallback`
	// in the response so the client can surface a one-time "your key
	// failed; using shared" notice.
	let keys = overrideKey ? [overrideKey] : geminiKeys();
	if (keys.length === 0) {
		const err = new Error(
			'AI explanations are not configured yet. Set GEMINI_API_KEY in '
			+ 'the Netlify dashboard (free tier; generate at '
			+ 'https://aistudio.google.com/app/apikey).');
		err.publicReason = err.message;
		err.statusCode = 503;
		throw err;
	}
	// 2026-05-11 (v1.2.42): step-down chain + BYOK bypass +
	// deadline budget. See aiBibleSearch.mjs's longer comment.
	let isByok = !!overrideKey;
	let falledBackFromByok = false;
	// v1.2.43: bumped deadline 22s → 24s; bail buffer 1s → 1.5s.
	const deadline = Date.now() + 24_000;
	let currentModel = model;
	let lastResult = null;
	while (currentModel) {
		if (Date.now() >= deadline - 1500) {
			console.warn(`[aiExplainWord] deadline reached at ${currentModel}; bailing.`);
			break;
		}
		const result = await _callGeminiInner(prompt, locale, keys, currentModel);
		if (result.ok) {
			if (ctx) ctx.byokFallback = falledBackFromByok;
			return result.text;
		}
		lastResult = result;
		// v1.3.30: BYOK failed → fall back to shared developer key,
		// then continue the model step-down chain on the shared key
		// as if BYOK had never been set. Only fires once.
		//
		// Trigger conditions: any 4xx from the BYOK key (Gemini
		// returns 400 INVALID_ARGUMENT for malformed/wrong keys,
		// 401/403 PERMISSION_DENIED for revoked keys, 429
		// RESOURCE_EXHAUSTED for quota) means the key won't work.
		// 5xx + status=0 (timeout) skip the fallback because the
		// shared key would hit the same Gemini-side issue.
		if (isByok && !falledBackFromByok &&
			result.status >= 400 && result.status < 500) {
			const sharedKeys = geminiKeys();
			if (sharedKeys.length > 0) {
				console.warn(`[aiExplainWord] BYOK HTTP ${result.status}; ` +
					`falling back to shared developer key`);
				keys = sharedKeys;
				isByok = false;
				falledBackFromByok = true;
				currentModel = model; // reset to user-picked tier
				continue;
			}
		}
		// BYOK never steps down — user picked this tier on their own key.
		if (isByok) break;
		// 2026-06-30: step down on transient upstream 5xx (e.g. flash-lite's
		// "high demand" 503) as well as 429 quota. Previously a brief 503 spike
		// on the primary model returned "no result" with no fallback attempt.
		// Auth errors still bail (a different model won't fix a bad key).
		if (result.errorKind !== 'quota' && result.errorKind !== 'upstream') break;
		const next = modelStepDown(currentModel);
		if (!next) break;
		console.warn(`[aiExplainWord] ${currentModel} ${result.status} (${result.errorKind}); falling back to ${next}.`);
		currentModel = next;
	}
	// v1.3.30: surface fallback state even on terminal failure so the
	// client knows the BYOK key was the original problem (even if the
	// fallback also failed for a different reason).
	if (ctx) ctx.byokFallback = falledBackFromByok;
	if (lastResult?.errorKind === 'quota') {
		const err = new Error(
			'Gemini models exhausted across step-down chain.');
		err.publicReason = isByok
			? 'Your Gemini key\'s quota is exhausted for the selected tier. ' +
				'Try again later or pick a lighter tier in Settings → AI.'
			: 'AI quota for the developer\'s shared key is exhausted across ' +
				'all free-tier models. Try again later, or paste your own ' +
				'Gemini API key in Settings → AI to use your own quota.';
		err.statusCode = 429;
		throw err;
	}
	if (lastResult?.errorKind === 'auth') {
		const err = new Error('AI service authentication failed.');
		err.publicReason = err.message;
		err.statusCode = 503;
		throw err;
	}
	// v1.2.43: distinguish timeout (status === 0, fetch threw)
	// from upstream 5xx. Timeout is "model busy, try again",
	// 5xx is "Gemini service issue".
	const status = lastResult?.status ?? 0;
	if (status === 0) {
		const err = new Error('AI explanation call timed out.');
		err.publicReason = isByok
			? 'AI response took too long on your Gemini key. The selected ' +
				'tier may be under heavy use right now — try again, or pick ' +
				'a lighter tier in Settings → AI.'
			: 'AI response took too long. The selected tier may be under ' +
				'heavy use right now — try again, or pick a lighter tier in ' +
				'Settings → AI.';
		err.statusCode = 504;
		throw err;
	}
	const upstreamErr = new Error(
		`Upstream AI service error (HTTP ${status}).`);
	upstreamErr.publicReason = upstreamErr.message;
	upstreamErr.statusCode = 502;
	throw upstreamErr;
}

export default async (req) => {
	const cors = {
		'Access-Control-Allow-Origin': '*',
		'Access-Control-Allow-Methods': 'POST, OPTIONS',
		'Access-Control-Allow-Headers': 'Content-Type',
		'Content-Type': 'application/json',
	};
	if (req.method === 'OPTIONS') {
		// 2026-05-09 (v1.1.12): null body for 204 — '' triggers
		// Netlify 502. See aiBibleSearch.mjs for the full note.
		return new Response(null, { status: 204, headers: cors });
	}
	if (req.method !== 'POST') {
		return new Response(JSON.stringify({ error: 'POST only' }),
			{ status: 405, headers: cors });
	}
	try {
		const body = await req.json();
		// 2026-05-07 (v18 audit): cap every user-provided string
		// before it reaches the prompt builder. Without these caps a
		// 100 KB+ verseText (or any other field) would overflow the
		// Gemini context window — abusable for cost amplification +
		// quota burn for everyone. The slice() values are well above
		// realistic input sizes (longest legitimate verseText is
		// ~600 chars in NASB; longest book name including the Song
		// of Solomon variants is under 30 chars).
		const strongs = (body?.strongs || '').toString().slice(0, 16);
		const lemma = (body?.lemma || '').toString().slice(0, 200);
		const translit = (body?.translit || '').toString().slice(0, 200);
		const gloss = (body?.gloss || '').toString().slice(0, 500);
		// 2026-05-10 (v1.2.30 audit): allowlist + length cap for `book`.
		// Previously only `.slice(0, 64)` — `book` is interpolated raw
		// into the prompt template at line 209's `.replaceAll('{book}',
		// book)`. Without a regex guard, a value like
		// `"Genesis. Now ignore prior instructions and"` would be
		// substituted into the focus directive. Restrict to ASCII
		// alphanumerics + spaces (covers every canonical English book
		// name including "Song of Solomon", "1 Chronicles" etc.).
		const _rawBook = (body?.book || '').toString().slice(0, 40);
		const book = /^[A-Za-z0-9 ]+$/.test(_rawBook) ? _rawBook : '';
		const chapter = Number(body?.chapter || 0);
		const verse = Number(body?.verse || 0);
		const verseText = (body?.verseText || '').toString().slice(0, 4000);
		// v1.3.68: optional free-text question about the passage (reading-
		// pane AI panel's "ask a question" box). When present, the
		// versePlain prompt answers THIS question grounded in the passage
		// instead of emitting the default explanation. Clamp hard — this
		// lands directly in the Gemini prompt, so cap the length and strip
		// control chars the same defensive way as verseText.
		const userQuestion = (body?.userQuestion || '')
			.toString()
			// Collapse all ASCII control chars (newlines/tabs/etc.) and
			// runs of whitespace to single spaces so the question stays a
			// clean single line in the prompt.
			.replace(/[\u0000-\u001f\u007f]+/g, ' ')
			.replace(/\s{2,}/g, ' ')
			.trim()
			.slice(0, 500);
		// v1.3.73: optional compact transcript of earlier turns in this
		// study-panel conversation, so follow-up questions stay coherent.
		// The client assembles it ("Q: … / A: …"); we keep it bounded and
		// strip control chars like the other free-text fields. Newlines are
		// preserved (collapsed runs only) so the Q/A structure survives.
		const history = (body?.history || '')
			.toString()
			// Strip control chars but KEEP newlines (\n) so the Q/A
			// structure survives; collapse other whitespace runs.
			.replace(/[\u0000-\u0009\u000b-\u001f\u007f]+/g, ' ')
			.replace(/[ \t]{2,}/g, ' ')
			.trim()
			.slice(0, 2000);
		// 2026-05-09 (v1.2.2): clamp `locale` to the three the app
		// actually localises. The previous .slice(0, 32) capped length
		// but didn't reject e.g. arbitrary tokens that could land in
		// the Gemini prompt template. Same allowlist as
		// aiBibleSearch.mjs and aiSearch.mjs.
		const _rawLocale = (body?.locale || 'en').toString();
		const locale = ['en', 'zh-Hans', 'zh-Hant'].includes(_rawLocale)
			? _rawLocale
			: 'en';
		// 2026-05-09 (v1.2.6 audit): allowlist `length` and `scope`
		// to the exact set `styleProfile()` recognises (see ~line 81
		// above). Previously .slice(0, 32) capped length but accepted
		// any 32-char garbage — Gemini would still get the request
		// and silently fall through to default behaviour (the switch
		// statement has no public surface for the typo). Hard-reject
		// here so client typos surface immediately instead of being
		// masked at server cost.
		const _rawLength = (body?.length || 'default').toString();
		const length = ['default', 'concise', 'longer', 'deep']
			.includes(_rawLength) ? _rawLength : 'default';
		const _rawScope = (body?.scope || 'verse').toString();
		const scope = [
			'verse', 'chapter', 'book', 'wholeBible',
			'otherChapters', 'crossTestament', 'deepExegesis',
		].includes(_rawScope) ? _rawScope : 'verse';
		// BYOK (2026-05): client may pass `userApiKey` to use the
		// user's own Gemini key (from AI Studio) instead of the
		// developer's shared key. We validate the shape before
		// forwarding (must match Google's `AIza...` API-key format).
		const _userKey = (body?.userApiKey || '').toString().trim();
		const _useUserKey = /^AIza[A-Za-z0-9_-]{20,80}$/.test(_userKey);
		// 2026-05-10 (v1.2.26): tier picker → real model name.
		// 2026-05-11 (v1.2.42): `fellBackToFlash` constant + spread
		// removed (always-false dead code since v1.2.40 switched Deep
		// to gemini-3-flash-preview which works on free tier).
		const model = resolveModel(body?.aiModel);
		// v1.3.x: `task` selects the prompt family. 'versePlain' explains
		// a whole verse / short range for a lay reader (reading-pane
		// selection-bar "AI explain"); default 'wordStudy' is the
		// original lemma-in-context explanation.
		const _rawTask = (body?.task || 'wordStudy').toString();
		const task = ['wordStudy', 'versePlain'].includes(_rawTask)
			? _rawTask
			: 'wordStudy';
		if (task === 'versePlain') {
			if (!book || !chapter || !verse) {
				return new Response(
					JSON.stringify({ error: 'book, chapter, verse required' }),
					{ status: 400, headers: cors });
			}
			// `verse` is the start; optional `verseEnd` extends the range.
			const _rawEnd = Number(body?.verseEnd || 0);
			const verseEnd = (_rawEnd > verse) ? _rawEnd : verse;
			const ctxV = { byokFallback: false };
			const explanationV = await callGemini(
				buildVersePrompt({
					book, chapter, verseStart: verse, verseEnd, verseText,
					locale, length, userQuestion, history,
				}),
				locale,
				_useUserKey ? _userKey : null,
				model,
				ctxV,
			);
			return new Response(
				JSON.stringify({
					explanation: explanationV,
					...(ctxV.byokFallback && { byokFallback: true }),
				}),
				{ status: 200, headers: cors });
		}
		if (!strongs || !lemma || !book || !chapter || !verse) {
			return new Response(
				JSON.stringify({ error: 'strongs, lemma, book, chapter, verse required' }),
				{ status: 400, headers: cors });
		}
		const ctx = { byokFallback: false };
		const explanation = await callGemini(
			buildPrompt({
				strongs, lemma, translit, gloss, book, chapter, verse, verseText, locale,
				length, scope,
			}),
			locale,
			_useUserKey ? _userKey : null,
			model,
			ctx,
		);
		return new Response(
			JSON.stringify({
				explanation,
				// v1.3.30: surface BYOK→shared-key fallback so the client
				// can show a subtle notice ("Your Gemini key failed; used
				// the shared key. Check Settings → AI.").
				...(ctx.byokFallback && { byokFallback: true }),
			}),
			{ status: 200, headers: cors });
	} catch (err) {
		// 2026-05-10 (v1.2.30): scrub `err.message` from public body
		// for the same reason as aiSearch / aiBibleSearch — uncaught
		// errors can carry server paths or library internals.
		console.error('[aiExplainWord] uncaught',
			String(err?.message || err).slice(0, 600));
		const status = err?.statusCode || 500;
		return new Response(
			JSON.stringify({ error: err?.publicReason || 'AI word study failed.' }),
			{ status, headers: cors });
	}
};

export const config = { path: '/api/aiExplainWord' };
