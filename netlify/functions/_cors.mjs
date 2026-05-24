// Shared CORS allowlist for write-side Netlify Functions
// (`errorReport`, `submitFeedback`).
//
// 2026-05-24 (v1.3.24): tightened from `Access-Control-Allow-Origin: *`
// which let any website on the internet POST to these endpoints from
// a user's browser. With the wide-open CORS, a malicious page could:
//   * spam the developer's lsy95112@gmail.com inbox by sending fake
//     error reports / feedback submissions
//   * exhaust the Resend free quota
//
// Strategy:
//   1. If the request has NO Origin header → native iOS / Android /
//      macOS app (or curl from the developer). Allow.
//   2. If the request has Origin AND it's on the allowlist → echo
//      that exact Origin back. (The spec disallows `Allow-Origin: *`
//      when `Allow-Credentials: true`, plus echoing is more precise.)
//   3. Origin present but not on the allowlist → silently set
//      Allow-Origin to the first allowlist entry. The browser will
//      reject the response, the function still runs (Netlify can't
//      reject pre-CORS), but the malicious page won't be able to
//      read the result. We also include a console.warn so abuse
//      shows up in Netlify Function Logs.
//
// Read endpoints (aiSearch, aiBibleSearch, aiExplainWord) are kept
// at `*` because:
//   * they have per-IP quota via Gemini's free tier
//   * they're embedable by design (the YsWords AI proxy is intended
//     to be a public-facing API for read queries)
//   * a malicious site spamming reads only burns AI quota, doesn't
//     hit the developer inbox

const _ALLOWLIST = [
	'https://yswords.netlify.app',
	'https://yswords-cn.netlify.app',
	'https://yswords-dev.netlify.app',
	'https://yswords-cn-dev.netlify.app',
	'https://yswords-qat.netlify.app',
	'https://yswords-cn-qat.netlify.app',
];

const _ALLOWLIST_SET = new Set(_ALLOWLIST);

/// Returns the CORS headers to apply to a response for the given
/// request. Always safe to spread into a Response's headers.
export function corsHeaders(req) {
	// Defensive: if a caller forgets to pass req, fall back to a
	// wildcard so the response still works. Logged so the bug is
	// visible in Function Logs. v1.3.24 hotfix added after a stray
	// `noContent()` call in errorReport's success path returned 502.
	if (!req || typeof req.headers?.get !== 'function') {
		console.warn('[cors] corsHeaders called without a Request');
		return {
			'Access-Control-Allow-Origin': '*',
			'Access-Control-Allow-Methods': 'POST, OPTIONS',
			'Access-Control-Allow-Headers': 'Content-Type',
		};
	}
	const origin = req.headers.get('origin') || '';
	let allowOrigin;
	if (!origin) {
		// No Origin → native app or non-browser caller. Allow.
		// Echo a wildcard so caches don't fragment per-request.
		allowOrigin = '*';
	} else if (_ALLOWLIST_SET.has(origin)) {
		allowOrigin = origin;
	} else {
		// Off-allowlist Origin. Browser will reject the response
		// regardless of what we send, so set to the canonical prod
		// origin (won't match the requester's actual origin → CORS
		// failure in the browser). Log so abuse surfaces in
		// Function Logs.
		console.warn(
			`[cors] off-allowlist origin rejected: ${origin}`,
		);
		allowOrigin = 'https://yswords.netlify.app';
	}
	return {
		'Access-Control-Allow-Origin': allowOrigin,
		'Access-Control-Allow-Methods': 'POST, OPTIONS',
		'Access-Control-Allow-Headers': 'Content-Type',
		// Per the spec — when Allow-Origin is an exact origin (not '*'),
		// preflights should also include this so the cache key matches.
		'Vary': 'Origin',
	};
}

/// True when the request's Origin is one we explicitly allow OR
/// absent (native app). Callers can use this for soft-rejecting
/// off-allowlist browser POSTs (return 403 before the side effect).
export function isAllowedOrigin(req) {
	const origin = req.headers.get('origin') || '';
	return origin === '' || _ALLOWLIST_SET.has(origin);
}
