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

// Default to gemini-2.5-flash-lite (round 55) — see aiExplainWord.mjs
// for the rationale: 4× daily free quota, no thinking-token budget
// to fight, fast enough for the brief 1-3 sentence search answers.
const MODEL = process.env.GEMINI_MODEL || 'gemini-2.5-flash-lite';

// 2026-05-10 (v1.2.26): per-request AI tier override, identical
// shape to aiBibleSearch.mjs / aiExplainWord.mjs. Allowlist-clamped.
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

// Build the ordered list of API keys to try. See aiExplainWord.mjs
// for the env-var convention; the same chain is used here so both
// functions share quota across keys: GEMINI_API_KEY (primary),
// GEMINI_API_KEY_BACKUP (secondary), GEMINI_API_KEY_BACKUP_2..9, and
// optional comma-separated GEMINI_API_KEYS that takes precedence.
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

// Round 56 (continued — locale fix): system message prefixed with
// the language directive in the target language so the model
// locks in the response language before encountering any English
// context. Same fix as aiExplainWord.mjs.
function buildSystemMessage(locale) {
	const langPrefix = locale === 'zh-Hans'
		? '【请用简体中文回答】所有回答必须用简体中文。'
		: locale === 'zh-Hant'
			? '【請用繁體中文回答】所有回答必須用繁體中文。'
			: '[Reply in English]';
	return langPrefix + ' ' +
		'You are a Bible-evidence research assistant. Stay '
		+ 'factual, concise, and avoid partisan rhetoric or '
		+ 'invented details.';
}

async function callGeminiWithKey(apiKey, prompt, locale, model) {
	const url = `${BASE_URL}/chat/completions`;
	return fetch(url, {
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
			// 4096 — gemini-2.5-flash uses "thinking" tokens that
			// share max_tokens with the output. Round 54 fix
			// (originally 512); see aiExplainWord.mjs for the full
			// rationale. AI-search answers themselves stay short
			// (1-3 sentences) so the model just gets headroom to
			// think rather than producing more text.
			max_tokens: 4096,
		}),
		signal: AbortSignal.timeout(modelTimeoutMs(model)),
	});
}

// 2026-05-11 (v1.2.43): per-model abort timeout. v1.2.42's flat
// 8s was too tight for `gemini-3-flash-preview` (thinking model,
// often 8-15s). See aiBibleSearch.mjs for the full comment.
function modelTimeoutMs(model) {
	switch (model) {
		case 'gemini-3-flash-preview': return 18_000;
		case 'gemini-2.5-flash':       return 10_000;
		case 'gemini-2.5-flash-lite':  return 6_000;
		default: return 10_000;
	}
}

// 2026-05-11 (v1.2.41): model step-down chain — same pattern as
// aiBibleSearch.mjs. When the chosen model 429s on all available
// keys, drop one tier and retry with a lighter model that has
// more free-tier quota. See aiBibleSearch's comment for details.
function modelStepDown(model) {
	switch (model) {
		case 'gemini-3-flash-preview': return 'gemini-2.5-flash';
		case 'gemini-2.5-flash':        return 'gemini-2.5-flash-lite';
		default: return null;
	}
}

// Inner key-rotation: try every key with a specific model.
// Returns `{ ok: true, text }` / `{ ok: false, status, lastError, isAuth }`.
async function _callGeminiInner(prompt, locale, keys, model) {
	let lastError = '';
	let lastStatus = 0;
	let allAuth = true;
	for (let i = 0; i < keys.length; i++) {
		const apiKey = keys[i];
		let resp;
		try {
			resp = await callGeminiWithKey(apiKey, prompt, locale, model);
		} catch (e) {
			console.error(`[aiSearch] ${model} key #${i + 1} fetch threw:`,
				String(e?.message || e).slice(0, 400));
			lastError = e?.message || String(e);
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
			lastError = 'rate-limited';
			allAuth = false;
			continue;
		}
		if (resp.status === 401 || resp.status === 403) {
			// Bad key — try the next.
			lastError = `auth ${resp.status}`;
			continue;
		}
		console.error(`[aiSearch] ${model} HTTP ${resp.status}:`,
			txt.slice(0, 1200));
		lastError = `HTTP ${resp.status}`;
		allAuth = false;
		// 4xx/5xx other-than-quota — break out, model-fallback won't help.
		break;
	}
	return { ok: false, status: lastStatus, lastError, isAuth: allAuth };
}

async function callGemini(prompt, locale, overrideKey = null, model = MODEL) {
	// BYOK: same pattern as aiExplainWord — when the client passes a
	// validated user API key, use only that key.
	const keys = overrideKey ? [overrideKey] : geminiKeys();
	if (keys.length === 0) {
		const err = new Error(
			'AI search is not configured yet. Set GEMINI_API_KEY in '
			+ 'the Netlify dashboard (free tier; generate at '
			+ 'https://aistudio.google.com/app/apikey).');
		err.publicReason = err.message;
		err.statusCode = 503;
		throw err;
	}
	// 2026-05-11 (v1.2.42): step-down chain with BYOK bypass +
	// deadline budget. See aiBibleSearch.mjs's longer comment.
	const isByok = !!overrideKey;
	// v1.2.43: bumped deadline 22s → 24s; bail buffer 1s → 1.5s.
	const deadline = Date.now() + 24_000;
	let currentModel = model;
	let lastResult = null;
	while (currentModel) {
		if (Date.now() >= deadline - 1500) {
			console.warn(`[aiSearch] deadline reached at ${currentModel}; bailing.`);
			break;
		}
		const result = await _callGeminiInner(prompt, locale, keys, currentModel);
		if (result.ok) return result.text;
		lastResult = result;
		// BYOK never steps down — user picked this tier on their own key.
		if (isByok) break;
		// Only step down on 429 (true quota exhaustion). Auth or
		// 4xx/5xx-other won't be fixed by a different model.
		if (result.status !== 429) break;
		const next = modelStepDown(currentModel);
		if (!next) break;
		console.warn(`[aiSearch] ${currentModel} 429; falling back to ${next}.`);
		currentModel = next;
	}
	// v1.2.43: branch the public error on terminal failure shape.
	const status = lastResult?.status ?? 0;
	if (lastResult?.isAuth && status !== 429) {
		const err = new Error('All Gemini keys failed authentication.');
		err.publicReason = err.message;
		err.statusCode = 503;
		throw err;
	}
	if (status === 0) {
		// Fetch threw / AbortSignal timeout — model was busy, not
		// out-of-quota. Different user message.
		const err = new Error(
			`AI call timed out. Last error: ${lastResult?.lastError}`);
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
	if (status === 429) {
		const err = new Error(
			'Gemini models exhausted across step-down chain. ' +
			`Last error: ${lastResult.lastError}`);
		err.publicReason = isByok
			? 'Your Gemini key\'s quota is exhausted for the selected tier. ' +
				'Try again later or pick a lighter tier in Settings → AI.'
			: 'AI quota for the developer\'s shared key is exhausted across ' +
				'all free-tier models. Try again later, or paste your own ' +
				'Gemini API key in Settings → AI to use your own quota.';
		err.statusCode = 429;
		throw err;
	}
	const upstreamErr = new Error(
		`Upstream AI service error (HTTP ${status}).`);
	upstreamErr.publicReason = upstreamErr.message;
	upstreamErr.statusCode = 502;
	throw upstreamErr;
}

function buildPrompt(query, locale, hits) {
	// Round 56 (continued — locale fix): the language directive now
	// leads the prompt AND repeats at the tail, in the target
	// language. With the directive only at line 216 of an
	// otherwise-English prompt the model defaulted to English; this
	// configuration makes Gemini reliably honour zh-Hans / zh-Hant.
	const langDirective = locale === 'zh-Hans'
		? '你必须用简体中文回答，不要用英文（除了书卷名、Strong\'s 编号、人名地名等不可避免的部分）。'
		: locale === 'zh-Hant'
			? '你必須用繁體中文回答，不要用英文（除了書卷名、Strong\'s 編號、人名地名等不可避免的部分）。'
			: 'Reply ONLY in English.';
	const ctx = hits
		.map((e, i) =>
			`[${i + 1}] id=${e.id}\n` +
			`  title: ${flat(pickLocalized(e.title, locale))}\n` +
			`  reference: ${e.scriptureReference}\n` +
			`  summary: ${flat(pickLocalized(e.summary, locale))}`,
		)
		.join('\n');
	return `${langDirective}

Answer the user's question using ONLY the numbered context entries below.
Be concise (1-3 sentences). End with bracketed citations like [1] [3]
matching the entry numbers you used. If the context doesn't answer the
question, say so plainly.

USER QUESTION: ${query}

CONTEXT:
${ctx}

${langDirective}`;
}

export default async (req) => {
	const cors = {
		'Access-Control-Allow-Origin': '*',
		'Access-Control-Allow-Methods': 'POST, OPTIONS',
		'Access-Control-Allow-Headers': 'Content-Type',
		'Content-Type': 'application/json',
	};
	if (req.method === 'OPTIONS') {
		// 2026-05-09 (v1.1.12): MUST pass `null` body for 204; '' is
		// invalid per WHATWG and Node throws → Netlify 502. See
		// aiBibleSearch.mjs for the full note.
		return new Response(null, { status: 204, headers: cors });
	}
	if (req.method !== 'POST') {
		return new Response(JSON.stringify({ error: 'POST only' }),
			{ status: 405, headers: cors });
	}
	try {
		const body = await req.json();
		const query = (body?.query || '').toString();
		// 2026-05-09 (v1.2.2): clamp `locale` to the three the app
		// actually localises. Without this, a malformed/malicious
		// `locale` from the client (e.g. a 100 KB string, or one with
		// shell-escape chars) would land in `buildPrompt`'s template
		// literal — wasted tokens at best, prompt-injection risk at
		// worst. Same allowlist as aiBibleSearch.mjs.
		const _rawLocale = (body?.locale || 'en').toString();
		const locale = ['en', 'zh-Hans', 'zh-Hant'].includes(_rawLocale)
			? _rawLocale
			: 'en';
		// BYOK (2026-05): client may pass `userApiKey` — validate
		// shape against Google's key format before forwarding.
		const _userKey = (body?.userApiKey || '').toString().trim();
		const _useUserKey = /^AIza[A-Za-z0-9_-]{20,80}$/.test(_userKey);
		// 2026-05-10 (v1.2.26): tier picker → real model name.
		// 2026-05-11 (v1.2.40): see aiBibleSearch.mjs's note — Deep
		// now uses `gemini-3-flash-preview` so the v1.2.37
		// pre-emptive fallback is no longer needed.
		// 2026-05-11 (v1.2.42): `fellBackToFlash` constant + spread
		// dropped (always-false dead code).
		const model = resolveModel(body?.aiModel);
		// v1.2.43: lowered from `< 2` to `< 1` so 1-char CJK queries
		// (e.g. `爱`, `信`, `光` — each a full concept) pass.
		if (query.trim().length < 1) {
			return new Response(JSON.stringify({ error: 'query required' }),
				{ status: 400, headers: cors });
		}
		// 2026-05-07 (v18 audit): cap the upper bound. Without this an
		// arbitrary-length query overflows the Gemini context window,
		// burns RPD quota, and amplifies cost for an attacker. Same
		// 2000-char ceiling as aiBibleSearch — well above any
		// legitimate thematic question.
		if (query.length > 2000) {
			return new Response(
				JSON.stringify({ error: 'query too long (max 2000 chars)' }),
				{ status: 400, headers: cors });
		}
		const dataset = await loadDataset();
		const hits = localPrefilter(query, locale, dataset, 12);
		if (hits.length === 0) {
			return new Response(
				JSON.stringify({ answer: '', citations: [], hits: 0 }),
				{ status: 200, headers: cors });
		}
		const answer = await callGemini(
			buildPrompt(query, locale, hits),
			locale,
			_useUserKey ? _userKey : null,
			model,
		);
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
		// 2026-05-10 (v1.2.30): scrub `err.message` from public body —
		// uncaught errors from `loadDataset` / `JSON.parse` / fetch
		// throws can leak server paths or dependency state. Server log
		// retains the full err for debugging.
		console.error('[aiSearch] uncaught',
			String(err?.message || err).slice(0, 600));
		const status = err?.statusCode || 500;
		return new Response(
			JSON.stringify({ error: err?.publicReason || 'AI search failed.' }),
			{ status, headers: cors });
	}
};

export const config = { path: '/api/aiSearch' };
