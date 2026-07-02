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

// 2026-06-30: kept as default — flash-lite's 503 is a TRANSIENT high-demand
// spike, not deprecation. This function's step-down already fires on 5xx; the
// only gap was the chain lacking a flash-lite fallback (added below). An earlier
// same-day patch wrongly switched to gemini-2.5-flash (~20 req/day free) —
// reverted. See aiExplainWord.mjs.
const MODEL = process.env.GEMINI_MODEL || 'gemini-2.5-flash-lite';

// 2026-05-10 (v1.2.26): per-request AI tier override. Client passes
// `aiModel` body field with one of the keys below; we map it to the
// real Gemini model name. Allowlist-clamped — anything else falls
// back to the env-default. Doc-level intent: keep server-side
// control of which exact model versions we trust, while letting
// the user pick speed vs depth.
//
// 2026-05-11 (v1.2.40): user reported Deep didn't work even with
// their own free-tier Gemini key. Root cause: as of April 1 2026,
// Google moved `gemini-2.5-pro` behind a paywall — the free tier
// no longer includes Pro at all (search confirmed the pricing
// page now shows "Not available" for Pro on free tier; the dev's
// shared keys + every user's BYOK free key both 429 instantly).
// Switched the Deep tier to `gemini-3-flash-preview` — the new
// free-tier thinking model that delivers near-Pro reasoning with
// configurable reasoning levels (minimal / low / medium / high)
// AND a 1M-token context. Free input + output, separate from the
// flash quota pool, so Deep is now actually usable on free tier
// without BYOK.
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

// 2026-05-11 (v1.2.43): per-model abort timeout. v1.2.42 used a
// flat 8s for every tier — too tight for `gemini-3-flash-preview`,
// which is a thinking model and routinely needs 8-15s on heavy
// prompts (especially exegesis). User reported "Upstream AI service
// error (HTTP ?)" with explanation_len=0 across multiple tries on
// Acts 19:14 + Deep; curl timing showed all 3 step-down tiers hit
// their 8s ceiling sequentially (~24s total, then "HTTP ?").
//
// 2026-05-22 (v1.2.79): Deep budget cut 18→14s. With the 24s outer
// deadline, an 18s Deep timeout left only 6s of remaining budget —
// not enough to even start Standard (10s timeout), so the function
// bailed with "AI response took too long" 80%+ of the time when
// Gemini's free thinking model was slow (live audit: 4/5 probes hit
// the ceiling). At 14s Deep, a failure leaves 10s — exactly enough
// to step down to Standard (which my audit hit in ~4s). Net effect:
// Deep that succeeds within 14s still works; Deep that would have
// timed out at 18s now falls back to Standard and the user gets an
// answer instead of an error.
//
// Per-model budgets:
//   gemini-3-flash-preview  14s  (thinking model — was 18s)
//   gemini-2.5-flash        10s  (standard)
//   gemini-2.5-flash-lite    6s  (fastest)
//
// Worst-case sum: 14 + 10 + 6 = 30s. The outer deadline (24s
// wall-clock) in callGemini bails before starting a step-down call
// that wouldn't finish — in practice the Deep→Standard chain
// completes in ~18-24s.
function modelTimeoutMs(model) {
	switch (model) {
		case 'gemini-3-flash-preview': return 14_000;
		case 'gemini-2.5-flash':       return 10_000;
		case 'gemini-2.5-flash-lite':  return 6_000;
		default: return 10_000;
	}
}

async function callGeminiWithKey(apiKey, query, locale, model) {
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
				{ role: 'user', content: `Query: ${query}` },
			],
			temperature: 0.2,
			// max_tokens 4096: 2.5-flash-lite uses thinking tokens that
			// share the max_tokens budget. We want headroom for the model
			// to think + still produce a 10-ref JSON response (~600
			// tokens output). 4096 is safe across all three tiers
			// (flash-lite / flash / pro).
			max_tokens: 4096,
			response_format: { type: 'json_object' },
		}),
		signal: AbortSignal.timeout(modelTimeoutMs(model)),
	});
}

// 2026-05-11 (v1.2.41): model-level fallback chain. Every site has
// only 1 Gemini key (no key rotation possible), so when the user-
// chosen model 429s, we step DOWN to a lighter model with a larger
// free-tier daily quota and retry. Free-tier RPD (approx):
//   gemini-3-flash-preview  ~250
//   gemini-2.5-flash         250
//   gemini-2.5-flash-lite   1000
// Stepping down on 429 keeps the experience working ~6× longer per
// day at the cost of one tier's response quality (still useful for
// the user's question; better than a hard error).
function modelStepDown(model) {
	switch (model) {
		// 2026-06-30: flash-lite → flash → 3-flash-preview → stop (see aiExplainWord).
		case 'gemini-2.5-flash-lite':  return 'gemini-2.5-flash';
		case 'gemini-2.5-flash':        return 'gemini-3-flash-preview';
		default: return null;
	}
}

// Inner key-rotation: try every available key with a specific
// model. Returns `{ ok: true, data }` on first success, or
// `{ ok: false, status, lastError }` when every key exhausted.
async function _callGeminiInner(query, locale, keys, model) {
	let lastError = '';
	let lastStatus = 0;
	for (const key of keys) {
		try {
			const r = await callGeminiWithKey(key, query, locale, model);
			if (r.ok) {
				return { ok: true, data: await r.json() };
			}
			const text = await r.text().catch(() => '');
			console.error(`[aiBibleSearch] ${model} HTTP ${r.status}:`,
				text.slice(0, 1200));
			lastError = `HTTP ${r.status}`;
			lastStatus = r.status;
			// On 429 / 5xx, try next key. On 4xx (other), abort.
			if (r.status === 429 || r.status >= 500) continue;
			break;
		} catch (e) {
			lastError = e?.message || String(e);
			lastStatus = 0;
			// Network / timeout — try next key.
			continue;
		}
	}
	return { ok: false, status: lastStatus, lastError };
}

async function callGemini(query, locale, overrideKey = null, model = MODEL, ctx = null) {
	// v1.3.30 (2026-05-24): BYOK auth/quota → auto-fall back to the
	// developer's shared key. Same pattern as aiExplainWord +
	// aiSearch. The previous behaviour was to error out with an
	// opaque upstream message; the user explicitly asked for the
	// silent fallback. `byokFallback` is surfaced via the optional
	// `ctx` arg so the client can show a one-time notice.
	let keys = overrideKey ? [overrideKey] : geminiKeys();
	if (keys.length === 0) {
		const err = new Error(
			'AI Bible search is not configured yet. Set GEMINI_API_KEY in ' +
			'the Netlify dashboard.');
		err.publicReason = err.message;
		err.statusCode = 503;
		throw err;
	}
	// 2026-05-11 (v1.2.41): step-down chain. Each key rotation
	// already covers transient single-key blips at one tier; this
	// outer loop handles "all keys exhausted at this tier" by
	// falling through to a lighter model with more quota.
	//
	// 2026-05-11 (v1.2.42): two guards added on top:
	//   (a) BYOK requests skip the step-down chain entirely. A
	//       user who explicitly chose Deep on their own key
	//       deserves either the Pro response or an error — NOT a
	//       silent downgrade to Standard on their own quota.
	//   (b) Total wall-clock deadline of 22s (Netlify's function
	//       cap is 26s, client timeout is 25s; 22s leaves 4s
	//       headroom for response serialisation + network).
	//       Before each `_callGeminiInner` we check the remaining
	//       budget; if < 8s we bail rather than start a call that
	//       would be killed mid-flight by Netlify.
	let isByok = !!overrideKey;
	let falledBackFromByok = false;
	// 2026-05-11 (v1.2.43): bumped deadline from 22s → 24s.
	// Combined with per-model timeouts, worst typical case is
	// Deep 18s + Flash 4s remaining budget; bail with > 1.5s
	// buffer so the response can still serialise inside Netlify's
	// 26s function cap.
	const deadline = Date.now() + 24_000;
	let currentModel = model;
	let lastResult = null;
	while (currentModel) {
		if (Date.now() >= deadline - 1500) {
			console.warn(`[aiBibleSearch] deadline reached at ${currentModel}; bailing.`);
			break;
		}
		const result = await _callGeminiInner(query, locale, keys, currentModel);
		if (result.ok) {
			if (ctx) ctx.byokFallback = falledBackFromByok;
			return result.data;
		}
		lastResult = result;
		// v1.3.30: BYOK failed → fall back to shared developer key.
		// Trigger on any 4xx from the BYOK key (Gemini returns 400
		// INVALID_ARGUMENT for malformed/wrong keys, 401/403 for
		// permission, 429 for quota). 5xx + timeout (status=0) skip
		// the fallback because the shared key would hit the same
		// Gemini-side issue.
		if (isByok && !falledBackFromByok &&
			result.status >= 400 && result.status < 500) {
			const sharedKeys = geminiKeys();
			if (sharedKeys.length > 0) {
				console.warn(`[aiBibleSearch] BYOK HTTP ${result.status}; ` +
					`falling back to shared developer key`);
				keys = sharedKeys;
				isByok = false;
				falledBackFromByok = true;
				currentModel = model;
				continue;
			}
		}
		// BYOK never steps down — user chose this tier on their own key.
		if (isByok) break;
		// Only step down on quota (429) or upstream 5xx. 4xx-other
		// (400 / 401 / 403) are caller-side problems — won't be fixed
		// by another model. Bail.
		if (result.status !== 429 && result.status < 500) break;
		const next = modelStepDown(currentModel);
		if (!next) break; // already at lightest tier
		console.warn(`[aiBibleSearch] ${currentModel} ${result.status}; ` +
			`falling back to ${next}.`);
		currentModel = next;
	}
	// v1.3.30: surface BYOK fallback even on terminal failure.
	if (ctx) ctx.byokFallback = falledBackFromByok;
	// 2026-05-11 (v1.2.43): branch the public error message on the
	// terminal failure shape, not just "quota".
	//   status === 0 → fetch threw / AbortSignal timeout. Show a
	//     timeout-specific message — the model was busy, not
	//     out-of-quota.
	//   status >= 500 → real upstream error.
	//   otherwise → quota (or terminal cap reached after step-down).
	const status = lastResult?.status ?? 0;
	const isTimeout = status === 0;
	const isUpstream5xx = status >= 500;
	const err = new Error(
		`Gemini call failed. Last status: ${status}, ` +
		`error: ${lastResult?.lastError}`);
	if (isTimeout) {
		err.statusCode = 504;
		err.publicReason = isByok
			? 'AI response took too long on your Gemini key. The selected ' +
				'tier may be under heavy use right now — try again, or pick ' +
				'a lighter tier in Settings → AI.'
			: 'AI response took too long. The selected tier may be under ' +
				'heavy use right now — try again, or pick a lighter tier in ' +
				'Settings → AI.';
	} else if (isUpstream5xx) {
		err.statusCode = 502;
		err.publicReason = `Upstream AI service error (HTTP ${status}). Please try again shortly.`;
	} else {
		err.statusCode = 429;
		err.publicReason = isByok
			? 'Your Gemini key\'s quota is exhausted for the selected tier. ' +
				'Try again later or pick a lighter tier in Settings → AI.'
			: 'AI quota for the developer\'s shared key is exhausted across ' +
				'all free-tier models. Try again later, or paste your own ' +
				'Gemini API key in Settings → AI to use your own quota.';
	}
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
	// 2026-05-09 (v1.1.12 final-audit fix): CORS preflight + response
	// headers. Both `aiSearch.mjs` and `aiExplainWord.mjs` already
	// returned `Access-Control-Allow-Origin: *` on every response and
	// answered OPTIONS preflights with 204; this function (the
	// fuzzy/thematic verse search backing the YsWords AI button)
	// previously returned 405 for OPTIONS and omitted CORS headers
	// from the POST response. Same-origin from yswords.netlify.app
	// works without them, but cross-origin (devtools probes,
	// future embedded surfaces) and any browser running a strict
	// preflight check would fail. This brings parity.
	const cors = {
		'Access-Control-Allow-Origin': '*',
		'Access-Control-Allow-Methods': 'POST, OPTIONS',
		'Access-Control-Allow-Headers': 'Content-Type',
		'Content-Type': 'application/json',
	};
	if (req.method === 'OPTIONS') {
		// 2026-05-09 (v1.1.12): MUST pass `null` body for HTTP 204
		// "No Content" — `''` (empty string) is a 0-length body but
		// the WHATWG Fetch spec says status 204 disallows ANY body,
		// so the Response constructor throws `Invalid response
		// status code 204` and Netlify returns 502. Same trap on
		// the other 3 functions; all four fixed in v1.1.12.
		return new Response(null, { status: 204, headers: cors });
	}
	if (req.method !== 'POST') {
		return new Response('Method Not Allowed',
			{ status: 405, headers: cors });
	}
	let body;
	try {
		body = await req.json();
	} catch (_) {
		return new Response(
			JSON.stringify({ error: 'Invalid JSON body.' }),
			{ status: 400, headers: cors });
	}
	const query = (body.query || '').trim();
	// 2026-05-09 (v1.2.2): clamp `locale` to the three the app
	// actually localises (en / zh-Hans / zh-Hant). Without an
	// allowlist a malformed or oversized `locale` string lands in
	// the prompt template — wasted tokens at best, prompt-injection
	// risk at worst.
	const _rawLocale = (body.locale || 'en').toString();
	const locale = ['en', 'zh-Hans', 'zh-Hant'].includes(_rawLocale)
		? _rawLocale
		: 'en';
	// 2026-05-09 (v1.1.12): validate userApiKey shape before
	// forwarding. Mirrors aiSearch.mjs / aiExplainWord.mjs — only
	// accepts a Gemini AI Studio key matching `AIza[20-80 chars]`.
	// Garbage input is dropped on the floor (treated as if no
	// userApiKey was provided) so we don't waste a Gemini call
	// trying to authenticate with junk.
	const _userKey = (body.userApiKey || '').trim();
	const _useUserKey = /^AIza[A-Za-z0-9_-]{20,80}$/.test(_userKey);
	const userApiKey = _useUserKey ? _userKey : '';
	// 2026-05-10 (v1.2.26): pick Gemini model tier from request,
	// allowlist-clamped via resolveModel.
	// 2026-05-11 (v1.2.40): Deep maps to `gemini-3-flash-preview`
	// instead of paywalled `gemini-2.5-pro`. Pre-emptive Pro→Flash
	// downgrade removed (no longer needed).
	// 2026-05-11 (v1.2.42): `fellBackToFlash` constant + spread are
	// dropped (always-false dead code; older clients reading the
	// field just see undefined → false via `== true`, unchanged).
	const model = resolveModel(body.aiModel);
	// 2026-05-11 (v1.2.43): lowered from `< 2` to `< 1`. The ≥ 2 chars
	// threshold dropped legitimate 1-character CJK queries (e.g.
	// `爱` / `信` / `光`) where a single ideograph carries a full
	// semantic concept. Empty queries still rejected. Upper bound
	// (2000 chars) unchanged.
	if (query.length < 1) {
		return new Response(
			JSON.stringify({ error: 'Query is required.' }),
			{ status: 400, headers: cors });
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
			{ status: 400, headers: cors });
	}
	try {
		const ctx = { byokFallback: false };
		const completion = await callGemini(
			query, locale, userApiKey || null, model, ctx);
		let text = completion?.choices?.[0]?.message?.content || '';
		let refs = parseRefs(text);
		// 2026-05-11 (v1.2.43): empty-hits content fallback. LLM
		// nondeterminism means the same model + prompt can return
		// `{"refs":[]}` on one call and 10 refs on the next (we
		// observed `救恩` returning 0 on dev/qat and 10 on prod
		// within the same minute, same key, same model). When the
		// requested tier returns ZERO refs AND we have a lighter
		// model in the step-down chain AND the user isn't on BYOK,
		// retry ONCE on the lighter tier — the user almost
		// certainly prefers a slightly-weaker answer over none.
		// Capped at one extra call to keep the cost bounded; total
		// upstream calls stay ≤ 2 per request which fits the 22s
		// deadline budget set in callGemini.
		//
		// v1.3.30: also kick in the empty-hits content fallback when
		// the original BYOK call fell back to the shared key (ctx.
		// byokFallback === true). The shared key is now in play, so
		// it's safe to spend one more shared-key call.
		if (refs.length === 0 && (!userApiKey || ctx.byokFallback)) {
			const fallback = modelStepDown(model);
			if (fallback) {
				console.warn(`[aiBibleSearch] ${model} returned 0 refs; ` +
					`retrying on ${fallback} for content quality.`);
				try {
					const c2 = await callGemini(
						query, locale, null, fallback);
					const t2 = c2?.choices?.[0]?.message?.content || '';
					const r2 = parseRefs(t2);
					if (r2.length > 0) {
						text = t2;
						refs = r2;
					}
				} catch (_) {/* keep original empty result */}
			}
		}
		return new Response(
			JSON.stringify({
				refs,
				hits: refs.length,
				// v1.3.30: surface BYOK→shared-key fallback so the client
				// can show a subtle notice ("Your Gemini key failed; used
				// the shared key. Check Settings → AI.").
				...(ctx.byokFallback && { byokFallback: true }),
			}),
			{ status: 200, headers: cors });
	} catch (e) {
		// 2026-05-10 (v1.2.30): never fall through to `e.message` for
		// the public response body — any thrown error from `loadDataset`,
		// `JSON.parse`, or upstream fetch can leak server paths /
		// dependency state. Only `publicReason` (set deliberately on
		// thrown errors) is allowed; everything else collapses to a
		// generic message. Server-side log keeps the full detail.
		const status = e?.statusCode || 500;
		const reason = e?.publicReason || 'AI Bible search failed.';
		if (!e?.publicReason) {
			console.error('[aiBibleSearch] uncaught',
				String(e?.message || e).slice(0, 600));
		}
		return new Response(
			JSON.stringify({ error: reason }),
			{ status, headers: cors });
	}
};

export const config = {
	path: '/api/aiBibleSearch',
};
