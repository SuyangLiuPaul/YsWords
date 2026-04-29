// YsWords AI search — Netlify Function. Talks to Google's
// Generative Language API (the OpenAI-compatible endpoint), which
// has a real free tier (no billing required) — same endpoint the
// sibling DailyNews refresh job uses.
//
// We previously tried Vertex AI via google-auth-library + a service
// account, but that path requires the Blaze billing plan even on
// projects that "have no billing linked". Free Gemini API + API key
// is the right path for this app.
//
// Endpoint after deploy:
//   https://yswords.netlify.app/api/aiSearch
//
// Required Netlify env var:
//   GEMINI_API_KEY  — generate at https://aistudio.google.com/app/apikey
//                     (free, no billing). The function returns a
//                     friendly "AI search is not configured yet"
//                     when this is unset.
// Optional Netlify env vars:
//   GEMINI_MODEL     — default 'gemini-2.5-flash'
//   GEMINI_BASE_URL  — default the OpenAI-compatible Gemini endpoint
//
// Body:  { query: string, locale?: 'en' | 'zh-Hans' | 'zh-Hant' }
// Reply: { answer: string, citations: [{id,title,scriptureReference}], hits }

import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const MODEL = process.env.GEMINI_MODEL || 'gemini-2.5-flash';
const BASE_URL =
	(process.env.GEMINI_BASE_URL ||
		'https://generativelanguage.googleapis.com/v1beta/openai').replace(/\/$/, '');

let _dataset = null;
async function loadDataset() {
	if (_dataset) return _dataset;
	const here = dirname(fileURLToPath(import.meta.url));
	const candidates = [
		join(here, 'bible_evidence.json'),
		join(here, '..', '..', 'assets', 'bible_evidence.json'),
		join(here, '..', '..', 'build', 'web', 'assets', 'assets',
			'bible_evidence.json'),
	];
	for (const p of candidates) {
		try {
			_dataset = JSON.parse(await readFile(p, 'utf-8'));
			return _dataset;
		} catch (_) {}
	}
	throw new Error('bible_evidence.json not bundled with function');
}

// Tolerant string coercion. Some entries store description /
// scripturalCorrelation as List<String> paragraphs rather than a
// single string — those would crash the prefilter without this.
function flat(v) {
	if (v == null) return '';
	if (typeof v === 'string') return v;
	if (Array.isArray(v)) {
		return v.map((x) => (typeof x === 'string' ? x : '')).join('\n\n');
	}
	return String(v);
}
function flatLower(v) { return flat(v).toLowerCase(); }
function pickLocalized(field, locale) {
	if (!field) return '';
	return field[locale] || field.en || '';
}

function localPrefilter(query, locale, dataset, limit = 12) {
	const q = query.toLowerCase();
	const tokens = q.split(/\s+/).filter((t) => t.length >= 2);
	if (tokens.length === 0) return [];
	const scored = [];
	for (const e of dataset.evidences) {
		const hay = [
			flatLower(pickLocalized(e.title, locale)),
			flatLower(pickLocalized(e.summary, locale)),
			flatLower(pickLocalized(e.description, locale)),
			flatLower(e.scriptureReference),
			flatLower((e.bibleBooks || []).join(' ')),
			flatLower(e.category),
		].join(' ');
		let score = 0;
		for (const t of tokens) if (hay.includes(t)) score += 1;
		if (score > 0) scored.push({ e, score });
	}
	scored.sort((a, b) => b.score - a.score);
	return scored.slice(0, limit).map((x) => x.e);
}

async function callGemini(prompt) {
	const apiKey = process.env.GEMINI_API_KEY;
	if (!apiKey) {
		const err = new Error(
			'AI search is not configured yet. Set GEMINI_API_KEY in '
			+ 'the Netlify dashboard (free tier; generate at '
			+ 'https://aistudio.google.com/app/apikey).');
		err.publicReason = err.message;
		err.statusCode = 503;
		throw err;
	}
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
						'You are a Bible-evidence research assistant. Stay '
						+ 'factual, concise, and avoid partisan rhetoric or '
						+ 'invented details.',
				},
				{ role: 'user', content: prompt },
			],
			temperature: 0.2,
			max_tokens: 512,
		}),
		signal: AbortSignal.timeout(20_000),
	});
	if (!resp.ok) {
		const txt = await resp.text();
		throw new Error(`Gemini ${resp.status}: ${txt.slice(0, 400)}`);
	}
	const json = await resp.json();
	const choice = json.choices?.[0];
	const content = choice?.message?.content;
	if (typeof content === 'string') return content;
	if (Array.isArray(content)) {
		return content.map((p) => (typeof p === 'string' ? p : (p?.text || ''))).join('');
	}
	return '';
}

function buildPrompt(query, locale, hits) {
	const langName = locale === 'zh-Hans'
		? 'Simplified Chinese'
		: locale === 'zh-Hant'
		? 'Traditional Chinese'
		: 'English';
	const ctx = hits
		.map((e, i) =>
			`[${i + 1}] id=${e.id}\n` +
			`  title: ${flat(pickLocalized(e.title, locale))}\n` +
			`  reference: ${e.scriptureReference}\n` +
			`  summary: ${flat(pickLocalized(e.summary, locale))}`,
		)
		.join('\n');
	return `Answer the user's question using ONLY the numbered context entries below.
Reply in ${langName}. Be concise (1-3 sentences). End with bracketed citations
like [1] [3] matching the entry numbers you used. If the context doesn't
answer the question, say so plainly.

USER QUESTION: ${query}

CONTEXT:
${ctx}`;
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
		const query = (body?.query || '').toString();
		const locale = (body?.locale || 'en').toString();
		if (query.trim().length < 2) {
			return new Response(JSON.stringify({ error: 'query required' }),
				{ status: 400, headers: cors });
		}
		const dataset = await loadDataset();
		const hits = localPrefilter(query, locale, dataset, 12);
		if (hits.length === 0) {
			return new Response(
				JSON.stringify({ answer: '', citations: [], hits: 0 }),
				{ status: 200, headers: cors });
		}
		const answer = await callGemini(buildPrompt(query, locale, hits));
		const citations = hits.map((e) => {
			const t = pickLocalized(e.title, locale);
			return {
				id: e.id,
				title: typeof t === 'string'
					? t
					: (Array.isArray(t) ? (t[0] || '') : String(t)),
				scriptureReference: e.scriptureReference,
			};
		});
		return new Response(
			JSON.stringify({ answer, citations, hits: hits.length }),
			{ status: 200, headers: cors });
	} catch (err) {
		console.error('aiSearch error:', err);
		const status = err?.statusCode || 500;
		return new Response(
			JSON.stringify({ error: err?.publicReason || String(err?.message || err) }),
			{ status, headers: cors });
	}
};

export const config = { path: '/api/aiSearch' };
