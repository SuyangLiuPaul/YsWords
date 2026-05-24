// YsWords feedback submission — Netlify Function. Receives a
// structured feedback payload from the in-app FeedbackPage and
// emails it directly to the developer via Resend.
//
// Endpoint after deploy:
//   https://yswords.netlify.app/api/submitFeedback
//
// Required Netlify env var:
//   RESEND_API_KEY    — sign up free at https://resend.com (3000 emails/month
//                       free tier), Verify > API Keys > Create API Key, copy
//                       the `re_...` value into Netlify Site settings
//                       → Environment variables.
//
// Optional Netlify env vars:
//   FEEDBACK_TO       — destination email (default 'paulsyliu@gmail.com').
//                       Note: Resend's free tier without a verified domain
//                       only allows sending TO the email tied to the API
//                       key. Set FEEDBACK_TO to that address until you
//                       verify a custom domain.
//   FEEDBACK_FROM     — sender email used by Resend. Default is
//                       'YsWords Feedback <onboarding@resend.dev>',
//                       which works without verifying a custom domain.
//                       To allow `Reply` to work from your inbox, verify
//                       a domain at Resend and set this to e.g.
//                       'YsWords Feedback <feedback@yourdomain.com>'.
//
// If RESEND_API_KEY is not set, the function returns 503 and the
// Flutter client falls back to opening the user's mail client via
// mailto:. Feedback is never silently lost.
//
// Body JSON: see fields list below; all are optional except `message`.
// Reply: { ok: true } on success
//        { error: '...' }  + 4xx/5xx on failure

import { corsHeaders, isAllowedOrigin } from './_cors.mjs';

const TO_DEFAULT = 'paulsyliu@gmail.com';
const FROM_DEFAULT = 'YsWords Feedback <onboarding@resend.dev>';

export const config = {
	path: '/api/submitFeedback',
};

export default async (req) => {
	// 2026-05-09 (v1.2.6 audit): hoisted CORS headers into a shared
	// const so EVERY response (success / error / 405 method-not-allowed
	// / 503 not-configured) carries CORS — without this the 405 path
	// emitted a bare 405 with no CORS, which would 405 cross-origin
	// probes from extensions / embedded surfaces / strict browser
	// configs even though the happy path was reachable.
	//
	// 2026-05-24 (v1.3.24): replaced wildcard `*` with `_cors.mjs`'s
	// origin-allowlist helper. Same allowlist as `errorReport.mjs`.
	// Any browser POST from an off-allowlist origin (an attacker's
	// page, a copy of the JS bundle on a clone domain, etc.) now
	// hits a hard 403 before we waste a Resend send.
	const cors = corsHeaders(req);
	if (req.method === 'OPTIONS') {
		// 2026-05-09 (v1.1.12): null body for 204 — '' triggers
		// Netlify 502. See aiBibleSearch.mjs for the full note.
		return new Response(null, { status: 204, headers: cors });
	}
	if (req.method !== 'POST') {
		return new Response(
			JSON.stringify({ error: 'Method Not Allowed' }),
			{
				status: 405,
				headers: { ...cors, 'Content-Type': 'application/json' },
			},
		);
	}
	if (!isAllowedOrigin(req)) {
		// v1.3.24: drop off-allowlist browser POSTs before the
		// Resend send. Native apps (no Origin header) pass through.
		return new Response(
			JSON.stringify({ error: 'forbidden' }),
			{
				status: 403,
				headers: { ...cors, 'Content-Type': 'application/json' },
			},
		);
	}
	const apiKey = (process.env.RESEND_API_KEY || '').trim();
	if (!apiKey) {
		// Not configured. Tell the client; they will fall back to mailto.
		return jsonResponse(
			{ error: 'Feedback service not configured (RESEND_API_KEY missing).' },
			503,
			req,
		);
	}
	const to = (process.env.FEEDBACK_TO || TO_DEFAULT).trim() || TO_DEFAULT;
	const from = (process.env.FEEDBACK_FROM || FROM_DEFAULT).trim() || FROM_DEFAULT;

	let payload;
	try {
		payload = await req.json();
	} catch (_) {
		return jsonResponse({ error: 'Invalid JSON body.' }, 400, req);
	}

	// User-typed fields
	// 2026-05-10 (v1.2.30): strip CR/LF from `category`, `name`, and
	// `subject` before they can land in the email Subject header. The
	// Subject is built at line ~157 as `YsWords feedback [${category}]
	// — ${name}`. A `\n` injected via `category` would split into a
	// second header (CRLF injection) — Resend likely filters it but
	// defense in depth.
	const category = String(payload.category || 'General')
		.replace(/[\r\n]+/g, ' ')
		.slice(0, 64);
	const message = String(payload.message || '').trim();
	const name = String(payload.name || '')
		.trim()
		.replace(/[\r\n]+/g, ' ')
		.slice(0, 200);
	const replyTo = String(payload.replyTo || '').trim().slice(0, 320);

	// `authEmail`: the user's signed-in (Firebase / Google) email,
	// always present in the email body when the user is signed in.
	// v16: the copy-to-user CC was removed end-to-end (the free-tier
	// Resend sandbox refuses non-owner recipients without a verified
	// domain). The form no longer offers it.
	const authEmail = String(payload.authEmail || '').trim().slice(0, 320);

	// App context (sent by the client)
	const locale = String(payload.locale || '').slice(0, 32);
	const version = String(payload.version || '').slice(0, 64);
	const position = String(payload.position || '').slice(0, 200);

	// Client-side diagnostics
	const screenW = numOrNull(payload.screenWidth);
	const screenH = numOrNull(payload.screenHeight);
	const dpr = String(payload.devicePixelRatio || '').slice(0, 16);
	const theme = String(payload.theme || '').slice(0, 16);
	const timezone = String(payload.timezone || '').slice(0, 16);
	const clientLocalTime =
		String(payload.clientLocalTime || '').slice(0, 32);
	const browserLocale = String(payload.browserLocale || '').slice(0, 32);
	const userAgent = String(payload.userAgent || '').slice(0, 600);

	// Server-side diagnostics (from Netlify request headers).
	// IP: Netlify exposes the edge connection IP and a chained
	// x-forwarded-for. Take the first hop of x-forwarded-for as the
	// real client; fall back to the connection IP.
	const xff = req.headers.get('x-forwarded-for') || '';
	const xffFirst = xff.split(',')[0]?.trim() || '';
	const ip = xffFirst ||
		req.headers.get('x-nf-client-connection-ip') ||
		req.headers.get('client-ip') ||
		'';
	// Country / geo: Netlify exposes x-country and x-nf-country
	// (with subdivision). x-nf-geo is JSON on edge functions only;
	// we keep the simpler header for compatibility.
	const country = req.headers.get('x-country') ||
		req.headers.get('x-nf-country') ||
		'';
	const referer = req.headers.get('referer') || '';
	const origin = req.headers.get('origin') || '';
	const ua = userAgent || req.headers.get('user-agent') || '';

	if (!message) {
		return jsonResponse({ error: 'Message is required.' }, 400, req);
	}
	if (message.length > 8000) {
		return jsonResponse({ error: 'Message too long.' }, 400, req);
	}
	// 2026-05-09 (v1.2.6 audit): tighter regex — require ≥2-char TLD
	// + ban whitespace and angle brackets so an attacker can't
	// inject newline-prefixed email-headers via the reply-to field.
	const emailRe = /^[^\s@<>]+@[^\s@<>]+\.[a-zA-Z]{2,}$/;
	if (replyTo && !emailRe.test(replyTo)) {
		return jsonResponse({ error: 'Invalid reply-to email.' }, 400, req);
	}
	// v1.2.30: code now matches its comment intent. An invalid
	// `authEmail` previously fell through verbatim into the email
	// body — comment said "blank it" but the implementation didn't.
	// Bad signed-in email = blanked locally; the rest of the
	// submission still goes through (it's the dev's problem if
	// Firebase exposed garbage, not the user's).
	let authEmailClean = authEmail;
	if (authEmailClean && !emailRe.test(authEmailClean)) {
		authEmailClean = '';
	}

	const subject = `YsWords feedback [${category}]${name ? ` — ${name}` : ''}`;

	// Server timestamp formatted human-readable: "2026-05-07 13:35:08 UTC".
	// Easier to read at a glance than raw ISO 8601 with milliseconds.
	const serverTime = formatUtcTimestamp(new Date());

	// Build the email body. Two clearly delimited blocks: the user's
	// message, then a structured diagnostics section. Order chosen so
	// the human-meaningful info is at the top of the diagnostics
	// (category / time) and the technical bits at the bottom.
	const lines = [];
	lines.push(message);
	lines.push('');
	lines.push('─── Feedback details ────────────────────');
	lines.push(`Category    : ${category}`);
	if (name) lines.push(`Name        : ${name}`);
	if (authEmailClean) lines.push(`Signed-in   : ${authEmailClean}`);
	if (replyTo) lines.push(`Reply-to    : ${replyTo}`);
	lines.push(`Submitted   : ${serverTime}`);
	if (clientLocalTime) {
		lines.push(`User local  : ${clientLocalTime} (UTC${timezone || '?'})`);
	}
	lines.push('');
	lines.push('─── App context ─────────────────────────');
	if (locale) lines.push(`App locale   : ${locale}`);
	if (version) lines.push(`Bible version: ${version}`);
	if (position) lines.push(`Last position: ${position}`);
	if (theme) lines.push(`Theme        : ${theme}`);
	lines.push('');
	lines.push('─── Client environment ──────────────────');
	if (screenW != null && screenH != null) {
		lines.push(`Screen       : ${screenW}×${screenH} px${dpr ? ` @ ${dpr}× DPR` : ''}`);
	}
	if (browserLocale) lines.push(`Browser lang : ${browserLocale}`);
	if (ua) {
		const brief = parseBrowserBrief(ua);
		if (brief) lines.push(`Browser      : ${brief}`);
		lines.push(`User-Agent   : ${ua}`);
	}
	lines.push('');
	lines.push('─── Server-side ─────────────────────────');
	if (ip) lines.push(`IP           : ${ip}`);
	if (country) lines.push(`Country      : ${country}`);
	if (referer) lines.push(`Referer      : ${referer}`);
	if (origin) lines.push(`Origin       : ${origin}`);
	lines.push(`Endpoint     : POST /api/submitFeedback`);

	const text = lines.join('\n');
	const html = `<pre style="font-family:ui-monospace,SFMono-Regular,Menlo,monospace;white-space:pre-wrap;line-height:1.45;font-size:13px;">${escapeHtml(text)}</pre>`;

	const baseBody = {
		from,
		to: [to],
		subject,
		text,
		html,
	};
	if (replyTo) baseBody.reply_to = replyTo;

	let resp;
	try {
		resp = await sendViaResend(apiKey, baseBody);
	} catch (e) {
		return jsonResponse({ error: `Network error: ${e.message || e}` }, 502, req);
	}
	if (!resp.ok) {
		// 2026-05-10 (v1.2.30): same class as the v1.2.6 sanitisation
		// pass on the AI functions — log the upstream body server-side
		// (Resend errors can leak account state, domain-verification,
		// quota hints) and return a generic message to the client.
		let detail = '';
		try {
			detail = await resp.text();
		} catch (_) {
			detail = `HTTP ${resp.status}`;
		}
		console.error('[submitFeedback] Resend',
			resp.status, detail.slice(0, 1200));
		return jsonResponse(
			{ error: `Upstream email service error (HTTP ${resp.status}).` },
			502,
			req,
		);
	}
	return jsonResponse({ ok: true }, 200, req);
};

async function sendViaResend(apiKey, body) {
	return await fetch('https://api.resend.com/emails', {
		method: 'POST',
		headers: {
			'Authorization': `Bearer ${apiKey}`,
			'Content-Type': 'application/json',
		},
		body: JSON.stringify(body),
	});
}

function jsonResponse(obj, status = 200, req = null) {
	// v1.3.24: prefer the origin-allowlist headers when we have a
	// req (every caller inside the default handler now passes it).
	// The fallback (req==null) stays at `*` for any out-of-band
	// caller that hasn't been updated — but every active caller
	// passes req.
	const corsHdrs = req
		? corsHeaders(req)
		: {
				'Access-Control-Allow-Origin': '*',
				'Access-Control-Allow-Methods': 'POST, OPTIONS',
				'Access-Control-Allow-Headers': 'Content-Type',
			};
	return new Response(JSON.stringify(obj), {
		status,
		headers: {
			'Content-Type': 'application/json',
			...corsHdrs,
			'Cache-Control': 'no-store',
		},
	});
}

function escapeHtml(s) {
	return String(s)
		.replace(/&/g, '&amp;')
		.replace(/</g, '&lt;')
		.replace(/>/g, '&gt;')
		.replace(/"/g, '&quot;')
		.replace(/'/g, '&#39;');
}

function numOrNull(v) {
	const n = Number(v);
	return Number.isFinite(n) ? Math.round(n) : null;
}

// "2026-05-07 13:35:08 UTC" -- much more readable in an email
// than ISO 8601 with milliseconds and a Z suffix.
function formatUtcTimestamp(d) {
	const pad = (n) => String(n).padStart(2, '0');
	return `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())}` +
		` ${pad(d.getUTCHours())}:${pad(d.getUTCMinutes())}:${pad(d.getUTCSeconds())} UTC`;
}

// Cheap browser-name extractor for the email's first line.
// Falls back to '' if nothing recognised; the full UA stays
// in the email for forensic detail.
function parseBrowserBrief(ua) {
	const u = String(ua);
	let browser = '';
	if (/Edg\//i.test(u)) browser = 'Edge';
	else if (/Chrome\//i.test(u) && !/Chromium\//i.test(u)) browser = 'Chrome';
	else if (/Firefox\//i.test(u)) browser = 'Firefox';
	else if (/Safari\//i.test(u) && !/Chrome\//i.test(u)) browser = 'Safari';
	else if (/Opera|OPR\//i.test(u)) browser = 'Opera';
	let os = '';
	if (/Mac OS X/i.test(u)) os = 'macOS';
	else if (/Windows NT/i.test(u)) os = 'Windows';
	else if (/Android/i.test(u)) os = 'Android';
	else if (/iPhone|iPad|iPod/i.test(u)) os = 'iOS';
	else if (/Linux/i.test(u)) os = 'Linux';
	if (!browser && !os) return '';
	if (browser && os) return `${browser} on ${os}`;
	return browser || os;
}
