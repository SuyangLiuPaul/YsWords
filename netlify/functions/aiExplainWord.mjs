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

// Map a (length, scope) selection to a target word range and the
// scope-specific framing the prompt builder should use. The defaults
// (length='default', scope='verse') reproduce the round-53 behaviour
// — a focused 150-260 word explanation grounded in the cited verse.
function styleProfile(length, scope) {
	let words;
	switch (length) {
		case 'concise': words = '60-110 words'; break;
		case 'longer':  words = '300-450 words'; break;
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
	const ref = `${book} ${chapter}:${verse}`;
	const profile = styleProfile(length, scope);
	const focus = profile.focus
		.replaceAll('{book}', book)
		.replaceAll('{chapter}', String(chapter))
		.replaceAll('{ref}', ref);
	const parts = [];
	parts.push(`You are a careful biblical-language exegete.`);
	parts.push(`The reader is studying ${ref} and has already seen the ` +
		`lexicon entry for **${lemma}**` +
		(translit ? ` (${translit})` : '') +
		` (Strong's ${strongs})${gloss ? ` whose core meaning is "${gloss}"` : ''}.`);
	parts.push(focus);
	if (verseText) parts.push(`The verse reads: "${verseText}"`);
	parts.push('');
	parts.push(`Reply in ${lang}. Target length: **${profile.words}**. ` +
		`Plain prose, no headings, no bullets, no markdown. Always ` +
		`finish your final sentence — never trail off mid-thought.`);
	parts.push('');
	parts.push(`Stay rigorous. Don't invent etymology. Don't moralize. ` +
		`Don't hedge with "scholars debate" unless there's a real exegetical ` +
		`split. If the word is a proper name, focus on the name's ` +
		`significance in the relevant narrative(s) rather than its ` +
		`etymological gloss.`);
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

async function callGeminiWithKey(apiKey, prompt) {
	const url = `${BASE_URL}/chat/completions`;
	const resp = await fetch(url, {
		method: 'POST',
		headers: {
			Authorization: `Bearer ${apiKey}`,
			'Content-Type': 'application/json',
		},
		body: JSON.stringify({
			model: MODEL,
			messages: [
				{
					role: 'system',
					content:
						'You are a precise biblical-language exegete. You ' +
						'reply with concise, accurate explanations grounded ' +
						'in the cited verse. You do not invent details or ' +
						'cite sources you have not seen. ' +
						'Think briefly (a few seconds at most), then ' +
						'produce the full answer in one go. Always finish ' +
						'every sentence — never trail off mid-thought, ' +
						'never end with a comma or with text like "the " ' +
						'or "之"; if the response is being truncated, ' +
						'wrap up with a complete final sentence.',
				},
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

async function callGemini(prompt) {
	const keys = geminiKeys();
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
		const resp = await callGeminiWithKey(apiKey, prompt);
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
			lastError = new Error(
				`Gemini key #${i + 1} rejected (${resp.status}). `
				+ (isLast
					? 'No working keys remaining; re-issue or rotate.'
					: 'Trying next key…'));
			continue;
		}
		// Non-quota, non-auth error — abort the chain (likely the prompt
		// is malformed or the upstream is down).
		throw new Error(`Gemini ${resp.status}: ${txt.slice(0, 400)}`);
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
		return new Response('', { status: 204, headers: cors });
	}
	if (req.method !== 'POST') {
		return new Response(JSON.stringify({ error: 'POST only' }),
			{ status: 405, headers: cors });
	}
	try {
		const body = await req.json();
		const strongs = (body?.strongs || '').toString();
		const lemma = (body?.lemma || '').toString();
		const translit = (body?.translit || '').toString();
		const gloss = (body?.gloss || '').toString();
		const book = (body?.book || '').toString();
		const chapter = Number(body?.chapter || 0);
		const verse = Number(body?.verse || 0);
		const verseText = (body?.verseText || '').toString();
		const locale = (body?.locale || 'en').toString();
		// Round 54: optional length + scope tuning. Defaults preserve
		// the round-53 behaviour ('default' length / 'verse' scope).
		const length = (body?.length || 'default').toString();
		const scope = (body?.scope || 'verse').toString();
		if (!strongs || !lemma || !book || !chapter || !verse) {
			return new Response(
				JSON.stringify({ error: 'strongs, lemma, book, chapter, verse required' }),
				{ status: 400, headers: cors });
		}
		const explanation = await callGemini(buildPrompt({
			strongs, lemma, translit, gloss, book, chapter, verse, verseText, locale,
			length, scope,
		}));
		return new Response(
			JSON.stringify({ explanation }),
			{ status: 200, headers: cors });
	} catch (err) {
		console.error('aiExplainWord error:', err);
		const status = err?.statusCode || 500;
		return new Response(
			JSON.stringify({ error: err?.publicReason || String(err?.message || err) }),
			{ status, headers: cors });
	}
};

export const config = { path: '/api/aiExplainWord' };
