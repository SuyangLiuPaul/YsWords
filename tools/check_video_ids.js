#!/usr/bin/env node
// Does every video in assets/videos.json still play?
//
//     node tools/check_video_ids.js            # check all ids
//     node tools/check_video_ids.js --json     # machine-readable report
//
// Nothing checked this before. On 2026-09-05 the English track of the
// `onegod` episode (QmTEkPquvcQ) was found to be "This video is private"
// on YouTube — a dead button in the shipped app, on a file that had been
// edited and reviewed repeatedly without anyone noticing. 65 of the 66
// ids answered 200 that day; one did not, and one is all it takes for a
// user to conclude the app is broken.
//
// One HTTP request per distinct id against YouTube's oEmbed endpoint,
// which is the same source assets/videos.json's own _meta says every
// title was verified against — so this check and that file agree about
// what "the video exists" means.
//
// WHERE THIS RUNS, and why not in Flutter CI
// ------------------------------------------
// Whether a third party's video is still public is not a property of a
// commit. Gating every push and PR on 66 unauthenticated requests from a
// datacenter IP would put YouTube's mood in the merge path, and this
// repo has already paid for that once: `flutter pub get` needed a
// three-attempt retry loop because pub.dev's advisory endpoint 403s at
// random. So this is:
//
//   * a script the owner can run on demand, on a residential
//     connection, where a 403 is unambiguous; and
//   * a WEEKLY scheduled workflow (.github/workflows/check-videos.yml),
//     which is the backstop for a Mac that was asleep — never on push
//     or pull_request.
//
// 403 IS NOT 404
// --------------
// A 404 means the id does not exist: definitive, fail immediately.
// A 403 is ambiguous — private, removed, blocked, or *us* being rate
// limited. So a 403 is retried with backoff, and then judged against
// the health of the whole batch: if nearly everything else came back
// 200, a persistent 403 is that video's own problem. If several ids
// 403 at once, we are the problem, and the run reports INCONCLUSIVE
// and exits 0 rather than crying wolf.
//
// A known-bad id is NEVER removed from assets/videos.json — a private
// video is usually an accident and the id is the only thing that can
// restore it. To stop a known outage from shouting every week while the
// owner chases it up, list the id in tools/known-unavailable-videos.json
// (see that file). The check still reports it, and tells you when it
// comes back to life so the entry can be deleted.
'use strict';

const fs = require('fs');
const path = require('path');

const REPO = path.join(__dirname, '..');
const VIDEOS = path.join(REPO, 'assets', 'videos.json');
const KNOWN = path.join(__dirname, 'known-unavailable-videos.json');

// A 403 is only believed after this many tries. The delays are long
// enough to outlast a short rate-limit window and short enough that a
// whole run stays inside a CI job's patience.
const RETRY_DELAYS_MS = [5000, 30000, 120000];
// Below this share of 200s the batch itself is suspect and no
// individual verdict is trustworthy.
const HEALTHY_BATCH_RATIO = 0.9;
const PAUSE_BETWEEN_MS = 120;

const jsonFlag = process.argv.includes('--json');

function log(...args) {
  if (!jsonFlag) console.log(...args);
}

/**
 * Every distinct youtubeId in the file, mapped to a readable location.
 *
 * A generic walk, not a series→episodes→tracks path, and that is
 * deliberate: the first version of this function walked the shape it
 * expected and quietly checked 64 of the 66 ids, because the two
 * whole-series compilations live in `series[].compilations[]` rather
 * than under an episode. A checker that silently skips part of the
 * file is worse than no checker, since it reports "all clear".
 * Anything the file calls a youtubeId gets checked, wherever it sits.
 */
function collectIds(doc) {
  const out = new Map();
  const join = (...parts) =>
    parts.filter((p) => p !== null && p !== undefined && p !== '').join('/');

  const walk = (node, where, fallbackName) => {
    if (Array.isArray(node)) {
      node.forEach((v, i) =>
        walk(v, where, `${fallbackName}[${i}]`));
      return;
    }
    if (!node || typeof node !== 'object') return;
    // Prefer the node's own identity over its position, so a failure
    // reads `onegod/01/en` rather than `series[1].episodes[0].tracks[0]`.
    const own = node.id ?? node.number ?? node.lang ?? null;
    const label = join(where, own === null ? fallbackName : own);
    for (const [key, value] of Object.entries(node)) {
      if (key === 'youtubeId' && typeof value === 'string') {
        if (!out.has(value)) out.set(value, label);
      } else if (value && typeof value === 'object') {
        walk(value, label, key);
      }
    }
  };
  for (const series of doc.series || []) {
    walk(series, '', 'series');
  }
  return out;
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function oembed(id) {
  const url =
    'https://www.youtube.com/oembed?url=' +
    encodeURIComponent(`https://www.youtube.com/watch?v=${id}`) +
    '&format=json';
  try {
    const res = await fetch(url, {
      headers: { 'User-Agent': 'YsWordsVideoCheck/1.0 (+https://yswords.netlify.app)' },
      redirect: 'follow',
    });
    let title = null;
    if (res.status === 200) {
      try {
        title = (await res.json()).title;
      } catch {
        // A 200 that is not JSON is not a working video.
        return { status: 'badjson' };
      }
    }
    return { status: res.status, title };
  } catch (err) {
    return { status: 'network', error: String(err.message || err) };
  }
}

/** oEmbed, with backoff on the statuses that might be about us. */
async function check(id) {
  let last = await oembed(id);
  for (const delay of RETRY_DELAYS_MS) {
    const retryable =
      last.status === 403 ||
      last.status === 429 ||
      last.status === 'network' ||
      (typeof last.status === 'number' && last.status >= 500);
    if (!retryable) break;
    await sleep(delay);
    last = await oembed(id);
  }
  return last;
}

/**
 * Turn a batch of probe results into a verdict. Pure — no network, no
 * clock, no filesystem — so `tools/check_video_ids.test.js` can drive
 * every branch offline, including the ones that only ever happen when
 * YouTube is rate-limiting a runner.
 */
function judge(results, known = {}, knownIdsInFile = null) {
  const total = results.length;
  const ok = results.filter((r) => r.status === 200);
  const gone = results.filter((r) => r.status === 404);
  const forbidden = results.filter((r) => r.status === 403);
  const unclear = results.filter(
    (r) => r.status !== 200 && r.status !== 404 && r.status !== 403,
  );

  // The run is its own canary. If the batch is unhealthy, no single
  // verdict in it is worth acting on.
  const batchHealthy = ok.length >= Math.floor(total * HEALTHY_BATCH_RATIO);

  const failures = [];
  const notes = [];

  for (const r of gone) {
    failures.push(`${r.id} (${r.where}) — 404, the video does not exist`);
  }
  if (batchHealthy) {
    for (const r of forbidden) {
      const ack = known[r.id];
      if (ack) {
        notes.push(
          `${r.id} (${r.where}) — still unavailable, known since ${ack.since}: ${ack.note || ''}`,
        );
      } else {
        failures.push(
          `${r.id} (${r.where}) — 403 after ${RETRY_DELAYS_MS.length} retries ` +
            `while ${ok.length}/${total} others returned 200: private, ` +
            `removed, or blocked. Do NOT delete the id from videos.json.`,
        );
      }
    }
    for (const r of unclear) {
      notes.push(
        `${r.id} (${r.where}) — ${r.status}${r.error ? ': ' + r.error : ''} (inconclusive)`,
      );
    }
  } else if (forbidden.length || unclear.length) {
    notes.push(
      `INCONCLUSIVE: only ${ok.length}/${total} ids returned 200, so the ` +
        `${forbidden.length + unclear.length} non-200 result(s) are more likely ` +
        `to be about this machine's IP than about the videos. Re-run from ` +
        `somewhere else before believing them.`,
    );
  }

  // A previously-acknowledged id that answers 200 again is news too:
  // the entry should be deleted so the check can protect it once more.
  const present = knownIdsInFile || new Set(results.map((r) => r.id));
  for (const [id, ack] of Object.entries(known)) {
    if (!present.has(id)) {
      notes.push(
        `${id} is acknowledged in known-unavailable-videos.json but is no ` +
          `longer in videos.json — delete the entry.`,
      );
    } else if (ok.some((r) => r.id === id)) {
      notes.push(
        `${id} plays again (acknowledged unavailable since ${ack.since}) — ` +
          `delete its entry from known-unavailable-videos.json.`,
      );
    }
  }

  return { ok, gone, forbidden, unclear, batchHealthy, failures, notes, total };
}

async function main() {
  const doc = JSON.parse(fs.readFileSync(VIDEOS, 'utf8'));
  const ids = collectIds(doc);
  if (ids.size === 0) {
    console.error('FATAL: found no youtubeId values in assets/videos.json.');
    console.error('The file shape changed; this check is not reading it.');
    process.exit(2);
  }

  let known = {};
  if (fs.existsSync(KNOWN)) {
    known = JSON.parse(fs.readFileSync(KNOWN, 'utf8')).unavailable || {};
  }

  log(`Checking ${ids.size} distinct YouTube ids from assets/videos.json…\n`);

  const results = [];
  for (const [id, where] of ids) {
    const r = await check(id);
    results.push({ id, where, ...r });
    const mark = r.status === 200 ? 'ok  ' : `${r.status}`.padEnd(4);
    log(`  ${mark} ${id}  ${where}${r.title ? '  ' + r.title.slice(0, 48) : ''}`);
    await sleep(PAUSE_BETWEEN_MS);
  }

  const { ok, gone, forbidden, unclear, batchHealthy, failures, notes } =
    judge(results, known, new Set(ids.keys()));

  if (jsonFlag) {
    console.log(JSON.stringify({ results, failures, notes, batchHealthy }, null, 2));
  } else {
    console.log(
      `\n${ok.length}/${results.length} playable · ${gone.length} missing · ` +
        `${forbidden.length} forbidden · ${unclear.length} inconclusive`,
    );
    for (const n of notes) console.log(`  note: ${n}`);
    for (const f of failures) console.error(`  FAIL: ${f}`);
  }

  if (process.env.GITHUB_STEP_SUMMARY) {
    const lines = [
      '## Video liveness',
      '',
      `${ok.length}/${results.length} playable, ${failures.length} failing.`,
      ...notes.map((n) => `- note: ${n}`),
      ...failures.map((f) => `- **FAIL** ${f}`),
      '',
    ];
    fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, lines.join('\n'));
  }
  for (const f of failures) {
    console.log(`::error title=Dead video::${f}`);
  }

  process.exit(failures.length ? 1 : 0);
}

if (require.main === module) {
  main().catch((err) => {
    console.error('FATAL:', err);
    process.exit(2);
  });
}

module.exports = { judge, collectIds, HEALTHY_BATCH_RATIO };
