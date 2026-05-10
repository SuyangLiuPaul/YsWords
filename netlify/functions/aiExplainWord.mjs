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

// Map a (length, scope) selection to a target word range and the
// scope-specific framing the prompt builder should use. The defaults
// (length='default', scope='verse') reproduce the round-53 behaviour
// — a focused 150-260 word explanation grounded in the cited verse.
function styleProfile(length, scope) {
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

function buildPrompt({ strongs, lemma, translit, gloss, book, chapter, verse, verseText, locale, length, scope }) {
	const lang = langName(locale);
	const langDirective = languageDirective(locale);
	const ref = `${book} ${chapter}:${verse}`;
	const profile = styleProfile(length, scope);
	const focus = profile.focus
		.replaceAll('{book}', book)
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
	// Repeat the language directive at the very end so the last
	// thing the model sees before generating is "answer in X".
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
function buildSystemMessage(locale) {
	const langPrefix = locale === 'zh-Hans'
		? '【请用简体中文回答】所有回答必须用简体中文。'
		: locale === 'zh-Hant'
			? '【請用繁體中文回答】所有回答必須用繁體中文。'
			: '[Reply in English]';
	return langPrefix + ' ' +
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
		signal: AbortSignal.timeout(20_000),
	});
	return resp;
}

async function callGemini(prompt, locale, overrideKey = null, model = MODEL) {
	// BYOK: when the client provided a valid-shape user key, use ONLY
	// that key — don't fall back to the developer's shared key, since
	// the user explicitly chose to spend their own quota. If their
	// key fails (quota / invalid), surface the error directly so they
	// can fix it on their side.
	const keys = overrideKey ? [overrideKey] : geminiKeys();
	if (keys.length === 0) {
		const err = new Error(
			'AI explanations are not configured yet. Set GEMINI_API_KEY in '
			+ 'the Netlify dashboard (free tier; generate at '
			+ 'https://aistudio.google.com/app/apikey).');
		err.publicReason = err.message;
		err.statusCode = 503;
		throw err;
	}
	let lastQuotaError = null;
	let lastError = null;
	for (let i = 0; i < keys.length; i++) {
		const apiKey = keys[i];
		const isLast = i === keys.length - 1;
		// 2026-05-10 (v1.2.30): wrap fetch in try/catch so a synchronous
		// throw (DNS hiccup, network error pre-response, malformed key
		// header) on key #i doesn't abort the whole rotation chain — fall
		// through to key #i+1 like the 429 / 401 paths already do.
		let resp;
		try {
			resp = await callGeminiWithKey(apiKey, prompt, locale, model);
		} catch (e) {
			console.error(`[aiExplainWord] Gemini key #${i + 1} fetch threw:`,
				String(e?.message || e).slice(0, 400));
			lastError = new Error('AI service network error.');
			continue;
		}
		if (resp.ok) {
			const json = await resp.json();
			const choice = json.choices?.[0];
			const content = choice?.message?.content;
			if (typeof content === 'string') return content;
			if (Array.isArray(content)) {
				return content.map((p) =>
					(typeof p === 'string' ? p : (p?.text || ''))).join('');
			}
			return '';
		}
		const txt = await resp.text();
		if (resp.status === 429) {
			// This key is rate-limited — try the next one.
			lastQuotaError = new Error(
				'All Gemini API keys are rate-limited (20 RPM / 250 RPD '
				+ 'free tier each). Please wait a moment and try again.');
			lastQuotaError.publicReason = lastQuotaError.message;
			lastQuotaError.statusCode = 429;
			continue;
		}
		if (resp.status === 401 || resp.status === 403) {
			// Bad key. Skip and try the next one in case it's just one
			// key that got revoked / expired.
			// 2026-05-10 (v1.2.30): keep the key index in the SERVER log
			// (useful for diagnosis) but never let it land on the public
			// `publicReason` — line 407 used to copy `.message` straight
			// into the response body, leaking "Gemini key #3 rejected"
			// + the total key count.
			console.error(`[aiExplainWord] Gemini key #${i + 1} rejected`,
				resp.status, isLast ? '(no keys remaining)' : '(trying next)');
			lastError = new Error('AI service authentication failed.');
			continue;
		}
		// Non-quota, non-auth error — abort the chain (likely the prompt
		// is malformed or the upstream is down).
		// 2026-05-09 (v1.2.6 audit): same upstream-leak fix as
		// aiSearch.mjs — log internally, return a generic public
		// message instead of forwarding Gemini's raw response body.
		console.error(`[aiExplainWord] Gemini ${resp.status} body:`,
			txt.slice(0, 1200));
		const upstreamErr = new Error(
			`Upstream AI service error (HTTP ${resp.status}). Please try again shortly.`);
		upstreamErr.publicReason = upstreamErr.message;
		upstreamErr.statusCode = 502;
		throw upstreamErr;
	}
	if (lastQuotaError) throw lastQuotaError;
	if (lastError) {
		lastError.publicReason = lastError.message;
		lastError.statusCode = 503;
		throw lastError;
	}
	throw new Error('Gemini call failed without a status code.');
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
		// 2026-05-11 (v1.2.40): see aiBibleSearch.mjs — Deep now
		// uses `gemini-3-flash-preview` so the v1.2.37 pre-emptive
		// Pro→Flash fallback is no longer required.
		const fellBackToFlash = false;
		// 2026-05-10 (v1.2.26): tier picker → real model name.
		const model = resolveModel(body?.aiModel);
		if (!strongs || !lemma || !book || !chapter || !verse) {
			return new Response(
				JSON.stringify({ error: 'strongs, lemma, book, chapter, verse required' }),
				{ status: 400, headers: cors });
		}
		const explanation = await callGemini(
			buildPrompt({
				strongs, lemma, translit, gloss, book, chapter, verse, verseText, locale,
				length, scope,
			}),
			locale,
			_useUserKey ? _userKey : null,
			model,
		);
		return new Response(
			JSON.stringify({
				explanation,
				...(fellBackToFlash ? { fellBackToFlash: true } : {}),
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
