// YsWords error reporter — Netlify Function.
//
// Captures runtime errors from any platform (web / iOS / macOS /
// Android) and forwards them to the developer's inbox via Resend.
// Same Resend account + key as the feedback form
// (`submitFeedback.mjs`); no new env-var or service needed.
//
// 2026-05-24 (v1.3.21): added in response to the
// docs/priorities.md item #2 "Error monitoring on prod —
// today a crash on yswords.netlify.app is invisible to the
// developer."
//
// Endpoint after deploy:  POST /api/errorReport
//
// Required env vars (shared with submitFeedback.mjs):
//   RESEND_API_KEY    — Resend account
// Optional:
//   FEEDBACK_TO       — destination email (default lsy95112@gmail.com)
//   ERROR_REPORT_RATE — per-IP rate cap in errors-per-minute (default 6)
//
// Request shape (every field optional except `error`):
//   {
//     error:       "ReferenceError: foo is not defined",
//     stack:       "  at bar (main.dart.js:1234)\n  at ...",
//     source:      "FlutterError" | "PlatformDispatcher" | "Zone" | "manual",
//     version:     "1.3.21",
//     platform:    "web" | "ios" | "android" | "macos" | "linux" | "windows",
//     locale:      "en" | "zh-Hans" | "zh-Hant",
//     route:       "/HomePage",
//     breadcrumbs: [{ t, action, data }, …],   ← last ~10 user actions
//     device:      { screen: "390x844", os: "iOS 17.4", ua: "Mozilla/..." },
//     sessionId:   "uuid-or-random"
//   }
//
// Returns 204 (best-effort fire-and-forget; never blocks client UI).
// Rate-limited per (IP, error message) so a runaway loop doesn't
// flood the inbox. Dedupe-window: 60 s.

import { corsHeaders, isAllowedOrigin } from './_cors.mjs';

const TO_DEFAULT = 'lsy95112@gmail.com';
const FROM_DEFAULT = 'YsWords <onboarding@resend.dev>';

// Per-instance rate-limit map. Resets when Netlify recycles the
// function instance — that's fine; the goal is to stop a runaway
// loop, not to maintain a global ledger.
const _recentSeen = new Map(); // key → timestamp
const _DEDUPE_WINDOW_MS = 60_000;

function clampStr(s, max) {
	if (typeof s !== 'string') return '';
	return s.length > max ? s.slice(0, max) : s;
}

function jsonResponse(req, obj, status = 200) {
	return new Response(JSON.stringify(obj), {
		status,
		headers: {
			'Content-Type': 'application/json',
			...corsHeaders(req),
		},
	});
}

function noContent(req) {
	return new Response(null, {
		status: 204,
		headers: corsHeaders(req),
	});
}

export default async (req) => {
	if (req.method === 'OPTIONS') return noContent(req);
	if (req.method !== 'POST') {
		return jsonResponse(req, { error: 'POST only' }, 405);
	}

	// 2026-05-24 (v1.3.24): hard-reject off-allowlist browser
	// POSTs BEFORE we waste a Resend send. The CORS headers
	// already prevent the attacker's page from reading the
	// response, but without this check the function still runs
	// to completion (Netlify can't enforce CORS preflight).
	// Native apps (no Origin header) bypass this check.
	if (!isAllowedOrigin(req)) {
		return jsonResponse(req, { error: 'forbidden' }, 403);
	}

	let body;
	try {
		body = await req.json();
	} catch (_) {
		return jsonResponse(req, { error: 'invalid JSON' }, 400);
	}

	// Mandatory: error message. Everything else is best-effort context.
	const error = clampStr(body?.error || '', 2000);
	if (!error) {
		return jsonResponse(req, { error: 'error field required' }, 400);
	}
	const stack = clampStr(body?.stack || '', 8000);
	const source = clampStr(body?.source || 'manual', 64);
	const version = clampStr(body?.version || 'unknown', 32);
	const _rawPlatform = clampStr(body?.platform || 'unknown', 16);
	const platform = ['web', 'ios', 'android', 'macos', 'linux', 'windows', 'fuchsia']
		.includes(_rawPlatform)
		? _rawPlatform
		: 'unknown';
	const _rawLocale = clampStr(body?.locale || 'en', 16);
	const locale = ['en', 'zh-Hans', 'zh-Hant'].includes(_rawLocale)
		? _rawLocale
		: 'en';
	const route = clampStr(body?.route || '', 256);
	const sessionId = clampStr(body?.sessionId || '', 64);

	const device = body?.device && typeof body.device === 'object'
		? {
				screen: clampStr(body.device.screen || '', 32),
				os: clampStr(body.device.os || '', 64),
				ua: clampStr(body.device.ua || '', 400),
				dpr: typeof body.device.dpr === 'number' ? body.device.dpr : null,
			}
		: {};

	// Breadcrumbs: array of {t, action, data}. Cap at 20 entries +
	// per-field length caps so a malformed client can't flood the
	// email body.
	const breadcrumbs = Array.isArray(body?.breadcrumbs)
		? body.breadcrumbs.slice(-20).map((b) => ({
				t: clampStr(b?.t || '', 32),
				action: clampStr(b?.action || '', 80),
				data: clampStr(b?.data || '', 200),
			}))
		: [];

	// De-dupe: (sessionId or IP) + first 200 chars of stack/error
	// within 60 s. Stops a render loop from emailing 100 times.
	const clientIp =
		(req.headers.get('x-nf-client-connection-ip') ||
			req.headers.get('x-forwarded-for') ||
			'unknown').split(',')[0].trim();
	const dedupeKey = `${sessionId || clientIp}|${(stack || error).slice(0, 200)}`;
	const now = Date.now();
	const prev = _recentSeen.get(dedupeKey);
	if (prev && now - prev < _DEDUPE_WINDOW_MS) {
		// Silent drop. Still return 204 — client doesn't need to know.
		return noContent(req);
	}
	_recentSeen.set(dedupeKey, now);
	// Sweep old entries so the Map doesn't grow unbounded.
	if (_recentSeen.size > 500) {
		for (const [k, v] of _recentSeen) {
			if (now - v > _DEDUPE_WINDOW_MS) _recentSeen.delete(k);
		}
	}

	// Build the email. Plain-text first so it shows up cleanly in
	// terminal-style mail clients; HTML mirrors with a <pre> block
	// for stack readability.
	const subjectShort = error.split('\n')[0].slice(0, 80);
	const subject = `[YsWords ${version} ${platform}] ${subjectShort}`;

	const text = [
		`Error:      ${error}`,
		`Source:     ${source}`,
		`Version:    ${version}`,
		`Platform:   ${platform}`,
		`Locale:     ${locale}`,
		`Route:      ${route || '(none)'}`,
		`Session:    ${sessionId || '(none)'}`,
		`Client IP:  ${clientIp}`,
		'',
		'Device:',
		`  Screen:  ${device.screen || '(unknown)'}`,
		`  OS:      ${device.os || '(unknown)'}`,
		`  DPR:     ${device.dpr ?? '(unknown)'}`,
		`  UA:      ${device.ua || '(unknown)'}`,
		'',
		'Breadcrumbs (most recent last):',
		...(breadcrumbs.length === 0
			? ['  (none)']
			: breadcrumbs.map((b) =>
					`  [${b.t}] ${b.action}${b.data ? ` — ${b.data}` : ''}`,
				)),
		'',
		'Stack trace:',
		stack || '(none)',
	].join('\n');

	const html = `
<!DOCTYPE html>
<html><body style="font:14px/1.5 -apple-system,'Segoe UI',sans-serif;color:#222;">
  <h2 style="margin:0 0 12px;font-size:16px;color:#b91c1c;">${escapeHtml(subjectShort)}</h2>
  <table style="border-collapse:collapse;font-size:13px;">
    <tr><td style="padding:2px 12px 2px 0;color:#666;">Source</td><td>${escapeHtml(source)}</td></tr>
    <tr><td style="padding:2px 12px 2px 0;color:#666;">Version</td><td>${escapeHtml(version)}</td></tr>
    <tr><td style="padding:2px 12px 2px 0;color:#666;">Platform</td><td>${escapeHtml(platform)}</td></tr>
    <tr><td style="padding:2px 12px 2px 0;color:#666;">Locale</td><td>${escapeHtml(locale)}</td></tr>
    <tr><td style="padding:2px 12px 2px 0;color:#666;">Route</td><td>${escapeHtml(route || '—')}</td></tr>
    <tr><td style="padding:2px 12px 2px 0;color:#666;">Session</td><td>${escapeHtml(sessionId || '—')}</td></tr>
    <tr><td style="padding:2px 12px 2px 0;color:#666;">Client IP</td><td>${escapeHtml(clientIp)}</td></tr>
    <tr><td style="padding:2px 12px 2px 0;color:#666;">Screen</td><td>${escapeHtml(device.screen || '—')}</td></tr>
    <tr><td style="padding:2px 12px 2px 0;color:#666;">OS</td><td>${escapeHtml(device.os || '—')}</td></tr>
    <tr><td style="padding:2px 12px 2px 0;color:#666;">DPR</td><td>${device.dpr ?? '—'}</td></tr>
  </table>
  <h3 style="margin:18px 0 6px;font-size:13px;color:#444;">Breadcrumbs</h3>
  ${
		breadcrumbs.length === 0
			? '<p style="color:#999;font-style:italic;">(none captured)</p>'
			: `<ol style="margin:0;padding-left:20px;font-size:12px;color:#444;">
        ${breadcrumbs
					.map(
						(b) => `<li><code style="color:#666;">${escapeHtml(b.t)}</code> ${escapeHtml(b.action)}${b.data ? ` — <span style="color:#888;">${escapeHtml(b.data)}</span>` : ''}</li>`,
					)
					.join('')}
      </ol>`
	}
  <h3 style="margin:18px 0 6px;font-size:13px;color:#444;">Stack</h3>
  <pre style="background:#f5f5f5;padding:10px;border-radius:4px;font:11px/1.4 'SF Mono',Menlo,monospace;white-space:pre-wrap;word-break:break-all;color:#222;">${escapeHtml(stack || '(none)')}</pre>
  <h3 style="margin:18px 0 6px;font-size:13px;color:#444;">User agent</h3>
  <pre style="background:#f5f5f5;padding:10px;border-radius:4px;font:11px/1.4 'SF Mono',Menlo,monospace;white-space:pre-wrap;word-break:break-all;color:#222;">${escapeHtml(device.ua || '(none)')}</pre>
</body></html>`.trim();

	const apiKey = (process.env.RESEND_API_KEY || '').trim();
	const to = (process.env.FEEDBACK_TO || TO_DEFAULT).trim() || TO_DEFAULT;
	const from = (process.env.FEEDBACK_FROM || FROM_DEFAULT).trim() || FROM_DEFAULT;

	if (!apiKey) {
		// Without an API key the function still ACK's the client
		// (don't surface infra problems in production UI) but logs
		// the report so Netlify Function Logs has the trace.
		console.error('[errorReport] no RESEND_API_KEY — logging only');
		console.error('[errorReport] ' + text);
		return noContent(req);
	}

	try {
		const resp = await fetch('https://api.resend.com/emails', {
			method: 'POST',
			headers: {
				'Authorization': `Bearer ${apiKey}`,
				'Content-Type': 'application/json',
			},
			body: JSON.stringify({ from, to, subject, text, html }),
		});
		if (!resp.ok) {
			const detail = await resp.text().catch(() => `HTTP ${resp.status}`);
			console.error('[errorReport] Resend',
				resp.status, detail.slice(0, 1200));
		}
	} catch (e) {
		console.error('[errorReport] fetch threw', String(e?.message || e).slice(0, 400));
	}

	// Always 204 — error reporter must never propagate failure
	// back to the (already-erroring) client.
	return noContent(req);
};

function escapeHtml(s) {
	return String(s)
		.replace(/&/g, '&amp;')
		.replace(/</g, '&lt;')
		.replace(/>/g, '&gt;')
		.replace(/"/g, '&quot;')
		.replace(/'/g, '&#39;');
}

export const config = { path: '/api/errorReport' };
