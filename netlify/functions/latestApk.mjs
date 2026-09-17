// /dl/<app> — hand back the newest Android package, not a web page.
//
// 2026-09-17 「apk no need to go to github but get download apk latest
// packages because this will get latest no anyway and also link to
// github」. The /about cards used to send every visitor to
// `releases/latest`, which is a GitHub page listing five files; on a
// phone that is two more taps and a choice between artifacts whose
// names mean nothing to the person making it.
//
// A STATIC url would have been better than a function, and for exactly
// one of the four apps it exists:
//
//   https://github.com/<repo>/releases/latest/download/<asset>
//
// resolves against whatever release is newest — but only if the asset's
// NAME never changes. Measured 2026-09-17:
//
//   NewsInsight-Android.apk              ← stable, would work
//   YsWords-Android-v1.6.12.apk          ← carries the version
//   SeekSparks-Android-v1.6.311.apk      ← carries the version
//   YahwehsWorld-0.1.3.apk               ← carries the version
//
// Renaming three repos' release assets would make the static form work,
// but only from each app's NEXT release onwards — `latest/download`
// resolves against the newest release's assets, and the three newest
// ones are already published under the old names. So: ask the API which
// file it is.
//
// EVERY failure path ends at `releases/latest`, i.e. exactly where the
// buttons pointed before this existed. Rate limit hit, API down, no apk
// in the release, unreadable JSON — the visitor lands on the page they
// used to land on and can still get the file. This function can only
// improve on the old behaviour or match it; it cannot break it.

const REPOS = {
	words: 'SuyangLiuPaul/Yahwehs-Words',
	sword: 'SuyangLiuPaul/Yahwehs-Sword',
	world: 'SuyangLiuPaul/yahwehs-globe',
	news: 'SuyangLiuPaul/News-Insight',
};

// Unauthenticated api.github.com allows 60 requests an hour per IP, and
// a Netlify function's egress IP is shared. One cached answer per warm
// container plus the browser cache below keeps a normal day's traffic
// to a handful of calls; if it is ever exceeded anyway, the fallback
// above is what the visitor gets.
const TTL_MS = 10 * 60_000;
const _cache = new Map(); // slug → { url, at }

function releasesPage(repo) {
	return `https://github.com/${repo}/releases/latest`;
}

// GitHub lists assets in upload order, which is not meaningful here.
// Prefer a name that says Android over one that merely ends in .apk, so
// that a repo which someday ships two .apk files (a flavour split, say)
// cannot silently start serving the wrong one.
function pickApk(assets) {
	const apks = (assets || []).filter(
		(a) => typeof a?.name === 'string' && a.name.toLowerCase().endsWith('.apk'),
	);
	if (apks.length === 0) return null;
	const android = apks.find((a) => /android/i.test(a.name));
	return (android || apks[0]).browser_download_url || null;
}

async function latestApkUrl(slug, repo) {
	const hit = _cache.get(slug);
	if (hit && Date.now() - hit.at < TTL_MS) return hit.url;

	const res = await fetch(`https://api.github.com/repos/${repo}/releases/latest`, {
		headers: {
			// GitHub rejects unidentified clients, and the version header
			// pins the response shape this function parses.
			'User-Agent': 'yahwehword.com-download-redirect',
			Accept: 'application/vnd.github+json',
			'X-GitHub-Api-Version': '2022-11-28',
		},
	});
	if (!res.ok) throw new Error(`github ${res.status}`);

	const url = pickApk((await res.json())?.assets);
	if (!url) throw new Error('no apk in latest release');

	_cache.set(slug, { url, at: Date.now() });
	return url;
}

export default async (req) => {
	const slug = new URL(req.url).pathname.split('/').filter(Boolean).pop();
	const repo = REPOS[slug];

	// An unknown slug is a broken link somewhere in our own pages, not a
	// visitor's mistake to absorb silently — but there is nothing useful
	// to redirect to, so say so plainly.
	if (!repo) {
		return new Response(`Unknown app: ${slug}\n`, {
			status: 404,
			headers: { 'Content-Type': 'text/plain; charset=utf-8' },
		});
	}

	let target;
	try {
		target = await latestApkUrl(slug, repo);
	} catch (e) {
		console.error('[latestApk]', slug, String(e?.message || e).slice(0, 200));
		// Not cached: the next visitor should get a fresh attempt at the
		// real thing rather than inherit this one's bad minute.
		return Response.redirect(releasesPage(repo), 302);
	}

	return new Response(null, {
		status: 302,
		headers: {
			Location: target,
			// Short on purpose. Long enough that a reload or a second tap
			// costs no API call; short enough that a release published a
			// few minutes ago is the one people get.
			'Cache-Control': 'public, max-age=300',
		},
	});
};

export const config = { path: '/dl/:app' };
