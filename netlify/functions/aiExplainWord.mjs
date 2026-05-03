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

const MODEL = process.env.GEMINI_MODEL || 'gemini-2.5-flash';
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

function buildPrompt({ strongs, lemma, translit, gloss, book, chapter, verse, verseText, locale }) {
	const lang = langName(locale);
	const ref = `${book} ${chapter}:${verse}`;
	const parts = [];
	parts.push(`You are a careful biblical-language exegete.`);
	parts.push(`Explain the original-language word **${lemma}**` +
		(translit ? ` (${translit})` : '') +
		` (Strong's ${strongs}) as it is used in ${ref}.`);
	if (gloss) parts.push(`Lexicon gloss for context: ${gloss}.`);
	if (verseText) parts.push(`Verse text: "${verseText}"`);
	parts.push('');
	parts.push(`Reply in ${lang}. 80-180 words. Plain prose, no headings, no bullets.`);
	parts.push(`Cover, in this order:`);
	parts.push(`  1. The word's core lexical meaning (1-2 sentences).`);
	parts.push(`  2. How it specifically functions in this verse — what nuance, ` +
		`grammatical aspect, or theological weight it carries here.`);
	parts.push(`  3. One related observation that helps the reader understand ` +
		`the verse better (e.g. a near-synonym distinction, a frequent NT ` +
		`pairing, a pattern across the same book).`);
	parts.push('');
	parts.push(`Stay rigorous. Don't invent etymology. Don't moralize. Don't ` +
		`hedge with "scholars debate" unless there's a real exegetical split. ` +
		`If the word is a proper name, focus on the name's significance in ` +
		`THIS narrative rather than its etymological gloss.`);
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
						'cite sources you have not seen.',
				},
				{ role: 'user', content: prompt },
			],
			temperature: 0.2,
			max_tokens: 480,
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
		if (!strongs || !lemma || !book || !chapter || !verse) {
			return new Response(
				JSON.stringify({ error: 'strongs, lemma, book, chapter, verse required' }),
				{ status: 400, headers: cors });
		}
		const explanation = await callGemini(buildPrompt({
			strongs, lemma, translit, gloss, book, chapter, verse, verseText, locale,
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
