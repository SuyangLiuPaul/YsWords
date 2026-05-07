// YsWords AI Bible search — Netlify Function. Same Gemini wiring as
// aiSearch.mjs but a different prompt: instead of returning Bible-
// evidence citations, the model returns a list of Bible references
// most relevant to the user's query. The Flutter client then resolves
// those references against the user's currently-loaded Bible version
// and renders the actual verse text.
//
// Why this exists: regular keyword search is exact-match. A user
// might type "the love chapter" or "雅各信仰" or "Sermon on the
// Mount" and get zero hits — but those have obvious answers (1 Cor
// 13, James 2, Matt 5–7) that an LLM can intuit.
//
// Endpoint after deploy:
//   https://yswords.netlify.app/api/aiBibleSearch
//
// Required Netlify env vars:
//   GEMINI_API_KEY  — generate at https://aistudio.google.com/app/apikey
//                     (free, no billing). Same key the existing
//                     aiSearch / aiExplainWord functions use.
// Optional Netlify env vars:
//   GEMINI_MODEL     — default 'gemini-2.5-flash-lite'
//   GEMINI_BASE_URL  — default OpenAI-compatible Gemini endpoint
//
// Body:  { query: string, locale?: 'en' | 'zh-Hans' | 'zh-Hant', userApiKey?: string }
// Reply: { answer: string, refs: [{book, chapter, verseStart, verseEnd, reason}] }

const MODEL = process.env.GEMINI_MODEL || 'gemini-2.5-flash-lite';
const BASE_URL = (process.env.GEMINI_BASE_URL ||
	'https://generativelanguage.googleapis.com/v1beta/openai').replace(/\/$/, '');

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

function buildSystemMessage(locale) {
	const lang = locale === 'zh-Hans'
		? '简体中文'
		: locale === 'zh-Hant'
			? '繁體中文'
			: 'English';
	const langPrefix = locale === 'zh-Hans'
		? '【请用简体中文回答】'
		: locale === 'zh-Hant'
			? '【請用繁體中文回答】'
			: '[Reply in English]';
	return (
		langPrefix +
		' You are a Bible reference assistant. Given a user query (which ' +
		'may be a topic, a paraphrase, a half-remembered phrase, or a ' +
		'theme), return the up-to-10 most relevant Bible passages. ' +
		'Output STRICT JSON only, with this shape:\n' +
		'{"refs":[{"book":"<English book name like Matthew, 1 Corinthians>",' +
		'"chapter":<int>,"verseStart":<int>,"verseEnd":<int>,' +
		'"reason":"<one short sentence in ' + lang + '>"}]}\n\n' +
		'RULES:\n' +
		'- Use canonical English book names (Matthew, Mark, Luke, John, ' +
		'1 Corinthians, 2 Corinthians, Song of Solomon, Revelation, etc).\n' +
		'- "verseStart" and "verseEnd" are integers; for a single verse ' +
		'they are equal. NEVER use 0 — use 1 for "whole chapter" cases.\n' +
		'- "reason" is one short sentence in ' + lang + ' explaining why ' +
		'the passage matches.\n' +
		'- Return at most 10 entries; less is fine if there are fewer ' +
		'really relevant passages.\n' +
		'- DO NOT invent passages. Only return real Bible references.\n' +
		'- If the query is not Bible-related, return {"refs":[]}.\n' +
		'- Output PURE JSON. No markdown fences, no commentary, no ' +
		'preamble. Start with { and end with }.'
	);
}

async function callGeminiWithKey(apiKey, query, locale) {
	const url = `${BASE_URL}/chat/completions`;
	return fetch(url, {
		method: 'POST',
		headers: {
			Authorization: `Bearer ${apiKey}`,
			'Content-Type': 'application/json',
		},
		body: JSON.stringify({
			model: MODEL,
			messages: [
				{ role: 'system', content: buildSystemMessage(locale) },
				{ role: 'user', content: `Query: ${query}` },
			],
			temperature: 0.2,
			// max_tokens 4096: 2.5-flash-lite uses thinking tokens that
			// share the max_tokens budget. We want headroom for the model
			// to think + still produce a 10-ref JSON response (~600
			// tokens output). 4096 is safe.
			max_tokens: 4096,
			response_format: { type: 'json_object' },
		}),
		signal: AbortSignal.timeout(20_000),
	});
}

async function callGemini(query, locale, overrideKey = null) {
	const keys = overrideKey ? [overrideKey] : geminiKeys();
	if (keys.length === 0) {
		const err = new Error(
			'AI Bible search is not configured yet. Set GEMINI_API_KEY in ' +
			'the Netlify dashboard.');
		err.publicReason = err.message;
		err.statusCode = 503;
		throw err;
	}
	let lastError;
	for (const key of keys) {
		try {
			const r = await callGeminiWithKey(key, query, locale);
			if (!r.ok) {
				const text = await r.text().catch(() => '');
				lastError = `Gemini ${r.status}: ${text.slice(0, 300)}`;
				// On 429 (rate limit) or 5xx, try the next key.
				if (r.status === 429 || r.status >= 500) continue;
				const err = new Error(lastError);
				err.statusCode = r.status;
				throw err;
			}
			return r.json();
		} catch (e) {
			lastError = e?.message || String(e);
			// Network / timeout — try next key.
			continue;
		}
	}
	const err = new Error(`All Gemini keys exhausted. Last error: ${lastError}`);
	err.statusCode = 503;
	throw err;
}

function parseRefs(rawJson) {
	// Tolerate occasional model wandering — strip ```json fences if
	// the model added them despite the system prompt asking not to.
	let s = String(rawJson).trim();
	if (s.startsWith('```')) {
		s = s.replace(/^```(?:json)?\s*/, '').replace(/```\s*$/, '');
	}
	let obj;
	try {
		obj = JSON.parse(s);
	} catch (_) {
		return [];
	}
	if (!obj || !Array.isArray(obj.refs)) return [];
	const out = [];
	for (const r of obj.refs) {
		if (!r || typeof r !== 'object') continue;
		const book = String(r.book || '').trim();
		const chapter = Number(r.chapter);
		const verseStart = Number(r.verseStart);
		const verseEnd = Number(r.verseEnd ?? r.verseStart);
		const reason = String(r.reason || '').trim();
		if (!book || !Number.isFinite(chapter) || chapter < 1) continue;
		if (!Number.isFinite(verseStart) || verseStart < 1) continue;
		out.push({
			book,
			chapter,
			verseStart,
			verseEnd: Number.isFinite(verseEnd) && verseEnd >= verseStart
				? verseEnd
				: verseStart,
			reason,
		});
		if (out.length >= 10) break;
	}
	return out;
}

export default async (req) => {
	if (req.method !== 'POST') {
		return new Response('Method Not Allowed', { status: 405 });
	}
	let body;
	try {
		body = await req.json();
	} catch (_) {
		return new Response(
			JSON.stringify({ error: 'Invalid JSON body.' }),
			{ status: 400, headers: { 'Content-Type': 'application/json' } });
	}
	const query = (body.query || '').trim();
	const locale = body.locale || 'en';
	const userApiKey = (body.userApiKey || '').trim();
	if (query.length < 2) {
		return new Response(
			JSON.stringify({ error: 'Query is required (≥2 chars).' }),
			{ status: 400, headers: { 'Content-Type': 'application/json' } });
	}
	// 2026-05-07 (v18 audit): cap the upper bound. Without this, a
	// 100 KB+ query would overflow Gemini's context window (resulting
	// in slow failures + wasted RPD quota for everyone) and could be
	// abused to amplify cost. 2000 chars is well above any realistic
	// thematic search ("the verse where Paul talks about love" etc.)
	// while bounding the worst case.
	if (query.length > 2000) {
		return new Response(
			JSON.stringify({ error: 'Query too long (max 2000 chars).' }),
			{ status: 400, headers: { 'Content-Type': 'application/json' } });
	}
	try {
		const completion = await callGemini(
			query, locale, userApiKey || null);
		const text = completion?.choices?.[0]?.message?.content || '';
		const refs = parseRefs(text);
		return new Response(
			JSON.stringify({ refs, hits: refs.length }),
			{ status: 200, headers: { 'Content-Type': 'application/json' } });
	} catch (e) {
		const status = e?.statusCode || 500;
		const reason = e?.publicReason || e?.message ||
			'AI Bible search failed.';
		return new Response(
			JSON.stringify({ error: reason }),
			{ status, headers: { 'Content-Type': 'application/json' } });
	}
};

export const config = {
	path: '/api/aiBibleSearch',
};
