#!/usr/bin/env node
// 2026-05-23 (v1.2.89): free-tier-aware audio generator. Wraps
// the core generator and STOPS at the monthly free-tier ceiling
// (1 M Neural2/Wavenet chars/month per Google Cloud TTS billing
// account), so this can be scheduled monthly (launchd, GitHub
// Actions cron, etc.) without burning the user's wallet.
//
// State is kept at /Users/pliu0036/.config/yswords/state/audio_free_tier.json
// — { month: 'YYYY-MM', charsUsed: number, lastVersion, lastBook,
// lastChapter, lastVerse } — so a re-run within the same calendar
// month resumes from the last stopping point. New month → counter
// resets to 0 automatically.
//
// Default ceiling: 950 000 chars (50 K safety margin under the
// 1 M quota — Google subtracts characters for prosody / SSML tags
// and we'd rather under-shoot than hit 429).
//
// Usage:
//   GOOGLE_TTS_API_KEY=AIza... node tools/generate_audio_free_tier.mjs
//   # or with a specific version preference (default cycles
//   # through versions in priority order):
//   GOOGLE_TTS_API_KEY=AIza... node tools/generate_audio_free_tier.mjs --version cuv

import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { pipeline } from 'node:stream/promises';
import { Readable } from 'node:stream';

const ROOT = '/Users/pliu0036/Documents/yswords';
const YDATA = '/Users/pliu0036/Documents/CodingProject/yswords-data';
const AUDIO_BASE = `${YDATA}/audio`;
const STATE_DIR = path.join(os.homedir(), '.config/yswords/state');
const STATE_FILE = path.join(STATE_DIR, 'audio_free_tier.json');

const apiKey = process.env.GOOGLE_TTS_API_KEY;
if (!apiKey) {
  console.error('ERROR: set GOOGLE_TTS_API_KEY env var.');
  process.exit(1);
}

const args = parseArgs(process.argv.slice(2));
const MONTHLY_LIMIT = Number(args.limit) || 950_000;

// Priority order. The script works through this list (each pair
// = version + gender) and skips entries that are fully on disk.
// Female-first per version because most users prefer it; we'll
// run male next month / next cycle.
const QUEUE = [
  ['cuv', 'female'], ['cuv', 'male'],
  ['cnv', 'female'], ['cnv', 'male'],
  ['cuvs-yhwh', 'female'], ['cuvs-yhwh', 'male'],
  ['cuv-tr', 'female'], ['cuv-tr', 'male'],
  ['cnv-tr', 'female'], ['cnv-tr', 'male'],
  ['cuvs-yhwh-tr', 'female'], ['cuvs-yhwh-tr', 'male'],
  ['kjv', 'female'], ['kjv', 'male'],
  ['nasb', 'female'], ['nasb', 'male'],
  ['leb', 'female'], ['leb', 'male'],
];

function thisMonth() {
  const d = new Date();
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}`;
}

function loadState() {
  if (!fs.existsSync(STATE_FILE)) return { month: thisMonth(), charsUsed: 0 };
  try {
    const s = JSON.parse(fs.readFileSync(STATE_FILE, 'utf-8'));
    if (s.month !== thisMonth()) {
      console.error(`New month (${thisMonth()}) — resetting char counter (was ${s.charsUsed} for ${s.month}).`);
      return { month: thisMonth(), charsUsed: 0 };
    }
    return s;
  } catch (_) {
    return { month: thisMonth(), charsUsed: 0 };
  }
}

function saveState(s) {
  fs.mkdirSync(STATE_DIR, { recursive: true });
  fs.writeFileSync(STATE_FILE, JSON.stringify(s, null, 2));
}

const VOICES = {
  'en_female': { langCode: 'en-US', name: 'en-US-Neural2-F' },
  'en_male':   { langCode: 'en-US', name: 'en-US-Neural2-D' },
  'zh-Hans_female': { langCode: 'cmn-CN', name: 'cmn-CN-Wavenet-A' },
  'zh-Hans_male':   { langCode: 'cmn-CN', name: 'cmn-CN-Wavenet-B' },
  'zh-Hant_female': { langCode: 'cmn-TW', name: 'cmn-TW-Wavenet-A' },
  'zh-Hant_male':   { langCode: 'cmn-TW', name: 'cmn-TW-Wavenet-B' },
};

function localeFor(slug) {
  if (/-tr$/.test(slug)) return 'zh-Hant';
  if (/^(cuv|cnv|cuvs-yhwh)$/.test(slug)) return 'zh-Hans';
  return 'en';
}

function sanitize(s) {
  return String(s)
    .replace(/<note:[^>]*>/g, '')
    .replace(/<[^>]+>/g, '')
    .replace(/\{[^}]+\}/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

function safeBook(b) { return String(b).replace(/[^A-Za-z0-9]+/g, '_'); }

async function synth(text, voice, retry = 0) {
  const url = `https://texttospeech.googleapis.com/v1/text:synthesize?key=${apiKey}`;
  const body = {
    input: { text },
    voice: { languageCode: voice.langCode, name: voice.name },
    audioConfig: { audioEncoding: 'MP3', sampleRateHertz: 24000 },
  };
  const r = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(30_000),
  });
  if (!r.ok) {
    const t = await r.text();
    // 429 = monthly quota hit. Bail entirely.
    if (r.status === 429) return { quotaHit: true, error: t.substring(0, 200) };
    if (r.status >= 500 && retry < 3) {
      await new Promise((r) => setTimeout(r, 4000 * (retry + 1)));
      return synth(text, voice, retry + 1);
    }
    return { error: `HTTP ${r.status}: ${t.substring(0, 200)}` };
  }
  const j = await r.json();
  if (!j.audioContent) return { error: 'empty audioContent' };
  return { bytes: Buffer.from(j.audioContent, 'base64') };
}

async function run() {
  const state = loadState();
  console.error(`=== Free-tier audio drip ===`);
  console.error(`Month: ${state.month}, used so far: ${state.charsUsed} / ${MONTHLY_LIMIT} chars`);

  if (state.charsUsed >= MONTHLY_LIMIT) {
    console.error(`Already at monthly ceiling. Nothing to do.`);
    return;
  }

  const preferredVersion = args.version;
  let charsThisRun = 0;
  const startCount = state.charsUsed;

  for (const [version, gender] of QUEUE) {
    if (preferredVersion && version !== preferredVersion) continue;
    if (state.charsUsed >= MONTHLY_LIMIT) break;

    const versionPath = `${ROOT}/assets/${version}.json`;
    if (!fs.existsSync(versionPath)) {
      console.error(`  skip ${version} (file missing)`);
      continue;
    }
    const locale = localeFor(version);
    const voice = VOICES[`${locale}_${gender}`];
    const verses = JSON.parse(fs.readFileSync(versionPath, 'utf-8'));
    const g = gender === 'male' ? 'M' : 'F';
    console.error(`\nWorking on ${version} × ${gender} (locale ${locale})`);

    for (const v of verses) {
      if (state.charsUsed >= MONTHLY_LIMIT) {
        console.error(`  hit monthly ceiling at ${state.charsUsed} chars — stopping.`);
        break;
      }
      if (!v.book || !v.chapter || !v.verse || !v.text) continue;
      const englishBook = v.book;
      const text = sanitize(v.text);
      if (!text) continue;

      const dir = path.join(AUDIO_BASE, version, safeBook(englishBook));
      fs.mkdirSync(dir, { recursive: true });
      const filename = `${v.chapter}_${v.verse}_${g}.mp3`;
      const dst = path.join(dir, filename);
      if (fs.existsSync(dst) && fs.statSync(dst).size > 256) continue;

      if (state.charsUsed + text.length > MONTHLY_LIMIT) {
        console.error(`  next verse (${text.length} chars) would exceed ceiling — stopping cleanly.`);
        break;
      }

      const r = await synth(text, voice);
      if (r.quotaHit) {
        console.error(`  Google returned 429 (monthly quota hit). Saving state and exiting.`);
        state.charsUsed = MONTHLY_LIMIT;
        saveState(state);
        return;
      }
      if (r.bytes) {
        fs.writeFileSync(dst, r.bytes);
        state.charsUsed += text.length;
        charsThisRun += text.length;
        saveState(state);
      } else {
        console.error(`  FAIL ${version}/${englishBook}/${v.chapter}:${v.verse}: ${r.error}`);
      }
      // Gentle pacing: 200ms between requests stays well under
      // Google's 1000 req/min default.
      await new Promise((r) => setTimeout(r, 200));
    }
  }

  console.error(`\nRun complete. Synthesized ${charsThisRun} chars this run; ${state.charsUsed} cumulative for ${state.month}.`);

  // Auto-commit+push if anything new was added.
  if (charsThisRun > 0) {
    console.error(`\nCommitting to yswords-data...`);
    const { execSync } = await import('node:child_process');
    try {
      execSync('git add audio/', { cwd: YDATA, stdio: 'inherit' });
      execSync(`git commit -m "audio: free-tier drip — ${charsThisRun} chars, ${state.month}"`, { cwd: YDATA, stdio: 'inherit' });
      execSync('git push origin main', { cwd: YDATA, stdio: 'inherit' });
      execSync('/opt/homebrew/bin/gh workflow run refresh.yml --ref main', { cwd: YDATA, stdio: 'inherit' });
      console.error(`yswords-data deploy triggered.`);
    } catch (e) {
      console.error(`Git/push step failed: ${e.message}`);
    }
  }
}

function parseArgs(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith('--')) {
      const key = a.slice(2);
      const val = (i + 1 < argv.length && !argv[i + 1].startsWith('--')) ? argv[++i] : 'true';
      out[key] = val;
    }
  }
  return out;
}

run().catch((e) => { console.error(e); process.exit(1); });
