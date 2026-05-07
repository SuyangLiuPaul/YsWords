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
//   FEEDBACK_TO       — destination email (default 'paulsyliu@gmail.com')
//   FEEDBACK_FROM     — sender email used by Resend. Default is
//                       'YsWords Feedback <onboarding@resend.dev>',
//                       which works without verifying a custom domain
//                       but limits replies. To allow `Reply` to work
//                       from your inbox, verify a domain at Resend
//                       and set this to e.g.
//                       'YsWords Feedback <feedback@yourdomain.com>'.
//
// If RESEND_API_KEY is not set, the function returns 503 and the
// Flutter client falls back to opening the user's mail client via
// mailto:. Feedback is never silently lost.
//
// Body:  { category, message, name?, replyTo?, locale?, version?, position? }
// Reply: { ok: true } on success
//        { error: '...' }  + 4xx/5xx on failure

const TO_DEFAULT = 'paulsyliu@gmail.com';
const FROM_DEFAULT = 'YsWords Feedback <onboarding@resend.dev>';

export const config = {
	path: '/api/submitFeedback',
};

export default async (req) => {
	if (req.method !== 'POST') {
		return new Response('Method Not Allowed', { status: 405 });
	}
	const apiKey = (process.env.RESEND_API_KEY || '').trim();
	if (!apiKey) {
		// Not configured. Tell the client; they will fall back to mailto.
		return jsonResponse(
			{ error: 'Feedback service not configured (RESEND_API_KEY missing).' },
			503,
		);
	}
	const to = (process.env.FEEDBACK_TO || TO_DEFAULT).trim() || TO_DEFAULT;
	const from = (process.env.FEEDBACK_FROM || FROM_DEFAULT).trim() || FROM_DEFAULT;

	let payload;
	try {
		payload = await req.json();
	} catch (_) {
		return jsonResponse({ error: 'Invalid JSON body.' }, 400);
	}

	const category = String(payload.category || 'General').slice(0, 64);
	const message = String(payload.message || '').trim();
	const name = String(payload.name || '').trim().slice(0, 200);
	const replyTo = String(payload.replyTo || '').trim().slice(0, 320);
	const locale = String(payload.locale || '').slice(0, 32);
	const version = String(payload.version || '').slice(0, 64);
	const position = String(payload.position || '').slice(0, 200);

	if (!message) {
		return jsonResponse({ error: 'Message is required.' }, 400);
	}
	if (message.length > 8000) {
		return jsonResponse({ error: 'Message too long.' }, 400);
	}
	// Cheap reply-to email sanity check; let Resend reject if it
	// disagrees. Empty replyTo is fine — Resend just won't set it.
	if (replyTo && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(replyTo)) {
		return jsonResponse({ error: 'Invalid reply-to email.' }, 400);
	}

	const subject = `YsWords feedback [${category}]${name ? ` — ${name}` : ''}`;

	const lines = [
		message,
		'',
		'---',
		`Category: ${category}`,
	];
	if (name) lines.push(`Name: ${name}`);
	if (replyTo) lines.push(`Reply-to: ${replyTo}`);
	if (locale) lines.push(`Locale: ${locale}`);
	if (version) lines.push(`Bible version: ${version}`);
	if (position) lines.push(`Last position: ${position}`);
	lines.push('App: YsWords (web)');
	lines.push(
		`Submitted: ${new Date().toISOString()} UTC`,
	);
	const text = lines.join('\n');
	// HTML mirror of the same content with hardlinks newlines so
	// Gmail / Apple Mail render readable paragraphs.
	const html = `<pre style="font-family:system-ui,sans-serif;white-space:pre-wrap;line-height:1.5;">${escapeHtml(text)}</pre>`;

	const body = {
		from,
		to: [to],
		subject,
		text,
		html,
	};
	if (replyTo) body.reply_to = replyTo;

	let resp;
	try {
		resp = await fetch('https://api.resend.com/emails', {
			method: 'POST',
			headers: {
				'Authorization': `Bearer ${apiKey}`,
				'Content-Type': 'application/json',
			},
			body: JSON.stringify(body),
		});
	} catch (e) {
		return jsonResponse({ error: `Network error: ${e.message || e}` }, 502);
	}
	if (!resp.ok) {
		let detail = '';
		try {
			detail = await resp.text();
		} catch (_) {
			detail = `HTTP ${resp.status}`;
		}
		return jsonResponse(
			{ error: `Resend error ${resp.status}: ${detail.slice(0, 300)}` },
			502,
		);
	}
	return jsonResponse({ ok: true });
};

function jsonResponse(obj, status = 200) {
	return new Response(JSON.stringify(obj), {
		status,
		headers: {
			'Content-Type': 'application/json',
			// Allow the Flutter web app on the same origin to call us;
			// no cross-origin needed for production but keeping a
			// permissive default avoids surprises during local dev.
			'Access-Control-Allow-Origin': '*',
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
