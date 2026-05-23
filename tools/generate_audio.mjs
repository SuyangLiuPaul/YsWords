#!/usr/bin/env node
// 2026-05-23 (v1.2.87): scheduled bulk TTS audio generator.
//
// Reads a Bible version JSON, generates per-verse MP3 for both genders
// via Google Cloud TTS, writes to yswords-data/audio/<version>/<book>/
// <chapter>_<verse>_<gender>.mp3. Resumable: skips files already on
// disk; writes progress to /tmp/audio_gen_progress.<version>.json.
//
// Usage:
//   GOOGLE_TTS_API_KEY=AIza... \
//     node tools/generate_audio.mjs --version cuv --gender female
//   GOOGLE_TTS_API_KEY=AIza... \
//     node tools/generate_audio.mjs --version cuv --gender both --tier neural
//
// Flags:
//   --version <name>   bible version slug (e.g. cuv, nasb, kjv)
//   --gender  <m|f|both>  default 'female'
//   --tier    <neural|standard>  default 'neural'
//   --books   <Genesis,Matthew>  comma list; default all
//   --delay   <ms>  default 200
//   --max     <n>   stop after N synthesis calls (testing)
//
// Schedule strategy: 200 ms base delay (well within 1000 req/min limit
// per Google docs). On any non-200, exponential backoff up to 60s.
// On hard fail after 3 retries, log and move on.

import fs from 'node:fs';
import path from 'node:path';
import { pipeline } from 'node:stream/promises';
import { Readable } from 'node:stream';

const ROOT = '/Users/pliu0036/Documents/yswords';
const YDATA = '/Users/pliu0036/Documents/CodingProject/yswords-data';
const AUDIO_BASE = `${YDATA}/audio`;

const args = parseArgs(process.argv.slice(2));
const apiKey = process.env.GOOGLE_TTS_API_KEY;
if (!apiKey) {
  console.error('ERROR: set GOOGLE_TTS_API_KEY env var.');
  process.exit(1);
}
const versionSlug = args.version || 'cuv';
const tier = args.tier || 'neural';
const genderArg = (args.gender || 'female').toLowerCase();
const genders = genderArg === 'both' ? ['female', 'male'] : [genderArg];
const delayMs = Number(args.delay) || 200;
const max = Number(args.max) || 0;
const onlyBooks = args.books ? args.books.split(',').map((s) => s.trim()) : null;

// Voice map (mirrors aiSpeak.mjs).
const VOICE_NEURAL = {
  en_female: { langCode: 'en-US', name: 'en-US-Neural2-F' },
  en_male:   { langCode: 'en-US', name: 'en-US-Neural2-D' },
  'zh-Hans_female': { langCode: 'cmn-CN', name: 'cmn-CN-Wavenet-A' },
  'zh-Hans_male':   { langCode: 'cmn-CN', name: 'cmn-CN-Wavenet-B' },
  'zh-Hant_female': { langCode: 'cmn-TW', name: 'cmn-TW-Wavenet-A' },
  'zh-Hant_male':   { langCode: 'cmn-TW', name: 'cmn-TW-Wavenet-B' },
};
const VOICE_STANDARD = {
  en_female: { langCode: 'en-US', name: 'en-US-Standard-F' },
  en_male:   { langCode: 'en-US', name: 'en-US-Standard-D' },
  'zh-Hans_female': { langCode: 'cmn-CN', name: 'cmn-CN-Standard-A' },
  'zh-Hans_male':   { langCode: 'cmn-CN', name: 'cmn-CN-Standard-B' },
  'zh-Hant_female': { langCode: 'cmn-TW', name: 'cmn-TW-Standard-A' },
  'zh-Hant_male':   { langCode: 'cmn-TW', name: 'cmn-TW-Standard-B' },
};

// Heuristic: detect the language of the version slug.
function localeFor(slug) {
  if (/^(cuv-tr|biblexg-tr|biblexg-v2-tr|cnv-tr|cuvs-yhwh-tr)$/.test(slug)) return 'zh-Hant';
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

function safeBookFs(book) {
  return String(book).replace(/[^A-Za-z0-9]+/g, '_');
}

const PROGRESS_FILE = `/tmp/audio_gen_progress.${versionSlug}.json`;
let progress = {};
if (fs.existsSync(PROGRESS_FILE)) {
  try { progress = JSON.parse(fs.readFileSync(PROGRESS_FILE, 'utf-8')); } catch {}
}

async function synthesize(text, voice, retry = 0) {
  const url = `https://texttospeech.googleapis.com/v1/text:synthesize?key=${apiKey}`;
  const body = {
    input: { text },
    voice: { languageCode: voice.langCode, name: voice.name },
    audioConfig: { audioEncoding: 'MP3', speakingRate: 1.0, sampleRateHertz: 24000 },
  };
  try {
    const r = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(30_000),
    });
    if (!r.ok) {
      if ((r.status === 429 || r.status >= 500) && retry < 4) {
        const wait = Math.min(60_000, 2_000 * Math.pow(2, retry));
        process.stderr.write(`  HTTP ${r.status}; backoff ${wait/1000}s\n`);
        await new Promise((r) => setTimeout(r, wait));
        return synthesize(text, voice, retry + 1);
      }
      const t = await r.text();
      return { error: `HTTP ${r.status}: ${t.substring(0, 200)}` };
    }
    const j = await r.json();
    if (!j.audioContent) return { error: 'empty audioContent' };
    return { bytes: Buffer.from(j.audioContent, 'base64') };
  } catch (e) {
    return { error: e.message };
  }
}

function bookEnglish(book) {
  // The verse data uses canonical English book names already in most
  // versions; if a translation file uses Chinese names, we'd need a
  // translation table. For now, assume English (works for kjv/nasb).
  // For cuv/cnv with Chinese book names, we'd add a map here.
  return book;
}

async function run() {
  const versionPath = `${ROOT}/assets/${versionSlug}.json`;
  if (!fs.existsSync(versionPath)) {
    console.error(`ERROR: ${versionPath} not found`);
    process.exit(1);
  }
  const verses = JSON.parse(fs.readFileSync(versionPath, 'utf-8'));
  const locale = localeFor(versionSlug);
  const table = tier === 'standard' ? VOICE_STANDARD : VOICE_NEURAL;
  console.error(`Generating ${versionSlug} (${locale}) × ${genders.join(', ')} × ${tier}`);
  console.error(`Total verses: ${verses.length}`);

  let synthCount = 0;
  let okCount = 0;
  let failCount = 0;
  const startTime = Date.now();

  for (const v of verses) {
    if (!v.book || !v.chapter || !v.verse || !v.text) continue;
    const englishBook = bookEnglish(v.book);
    if (onlyBooks && !onlyBooks.includes(englishBook)) continue;
    const text = sanitize(v.text);
    if (!text) continue;
    const safe = safeBookFs(englishBook);

    for (const gender of genders) {
      const g = gender === 'male' ? 'M' : 'F';
      const dir = path.join(AUDIO_BASE, versionSlug, safe);
      fs.mkdirSync(dir, { recursive: true });
      const filename = `${v.chapter}_${v.verse}_${g}.mp3`;
      const dst = path.join(dir, filename);
      const key = `${versionSlug}|${safe}|${v.chapter}|${v.verse}|${g}|${tier}`;
      if (fs.existsSync(dst) && fs.statSync(dst).size > 256) {
        progress[key] = { file: filename, size: fs.statSync(dst).size };
        continue;
      }

      const voiceKey = `${locale}_${gender}`;
      const voice = table[voiceKey] || table.en_female;
      const r = await synthesize(text, voice);
      synthCount++;
      if (r.bytes) {
        fs.writeFileSync(dst, r.bytes);
        progress[key] = { file: filename, size: r.bytes.length };
        okCount++;
      } else {
        progress[key] = { error: r.error };
        failCount++;
        process.stderr.write(`  FAIL ${key}: ${r.error}\n`);
      }
      fs.writeFileSync(PROGRESS_FILE, JSON.stringify(progress, null, 2));

      if ((synthCount % 50) === 0) {
        const elapsed = (Date.now() - startTime) / 60_000;
        process.stderr.write(
          `  synth=${synthCount} ok=${okCount} fail=${failCount} elapsed=${elapsed.toFixed(1)}min\n`
        );
      }
      if (max > 0 && synthCount >= max) {
        console.error(`Hit --max ${max}; stopping.`);
        return;
      }
      await new Promise((r) => setTimeout(r, delayMs));
    }
  }
  console.error(`\nDONE. synth=${synthCount} ok=${okCount} fail=${failCount}`);
  console.error(`Audio at ${AUDIO_BASE}/${versionSlug}/`);
  console.error(`Next: cd ${YDATA} && git add audio/ && git commit -m 'audio: ${versionSlug}' && git push`);
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

run().catch((e) => {
  console.error(e);
  process.exit(1);
});
