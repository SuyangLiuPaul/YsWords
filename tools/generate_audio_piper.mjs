#!/usr/bin/env node
// 2026-05-23 (v1.2.89): local Piper TTS generator. Free, offline,
// no API quota — runs entirely on the user's Mac via the open-
// source `piper` neural TTS engine. Quality is below Google
// Neural2 but well above the browser SpeechSynthesis baseline, and
// it can complete all 14 versions × 2 genders in ~48-72 hours on
// an M-series Mac at zero cost.
//
// Prerequisites:
//   brew install piper   # Or: pip install piper-tts
//   # download voice models (~80-120 MB each):
//   mkdir -p ~/.local/share/piper/voices && cd ~/.local/share/piper/voices
//   # English female (high quality):
//   curl -LO https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/amy/medium/en_US-amy-medium.onnx
//   curl -LO https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/amy/medium/en_US-amy-medium.onnx.json
//   # English male:
//   curl -LO https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/ryan/high/en_US-ryan-high.onnx
//   curl -LO https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/ryan/high/en_US-ryan-high.onnx.json
//   # Chinese female (simplified):
//   curl -LO https://huggingface.co/rhasspy/piper-voices/resolve/main/zh/zh_CN/huayan/medium/zh_CN-huayan-medium.onnx
//   curl -LO https://huggingface.co/rhasspy/piper-voices/resolve/main/zh/zh_CN/huayan/medium/zh_CN-huayan-medium.onnx.json
//
// Usage:
//   node tools/generate_audio_piper.mjs --version cuv --gender female
//   node tools/generate_audio_piper.mjs --version cuv --gender both --concurrency 4
//
// Output goes to the same yswords-data/audio/<version>/<book>/
// directory as the Google Cloud version — so the iOS / web app
// picks up Piper-generated MP3s with no client-side changes.

import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { spawn } from 'node:child_process';

const ROOT = '/Users/pliu0036/Documents/yswords';
const YDATA = '/Users/pliu0036/Documents/CodingProject/yswords-data';
const AUDIO_BASE = `${YDATA}/audio`;
const VOICES_DIR = path.join(os.homedir(), '.local/share/piper/voices');

// Voice model files. Edit if you downloaded different ones.
const VOICES = {
  'en_female':       'en_US-amy-medium.onnx',
  'en_male':         'en_US-ryan-high.onnx',
  'zh-Hans_female':  'zh_CN-huayan-medium.onnx',
  'zh-Hans_male':    'zh_CN-huayan-medium.onnx',  // Piper has no zh male; use female + speakerId
  'zh-Hant_female':  'zh_CN-huayan-medium.onnx',  // Reuse zh-Hans voice for Hant
  'zh-Hant_male':    'zh_CN-huayan-medium.onnx',
};

const args = parseArgs(process.argv.slice(2));
const versionSlug = args.version || 'cuv';
const genderArg = (args.gender || 'female').toLowerCase();
const genders = genderArg === 'both' ? ['female', 'male'] : [genderArg];
const concurrency = Number(args.concurrency) || 2;

const PROGRESS_FILE = `/tmp/audio_gen_piper.${versionSlug}.json`;
let progress = {};
if (fs.existsSync(PROGRESS_FILE)) {
  try { progress = JSON.parse(fs.readFileSync(PROGRESS_FILE, 'utf-8')); } catch {}
}

// Resolve piper binary. Try brew (Apple Silicon + Intel) then PATH.
function piperBin() {
  for (const p of [
    '/opt/homebrew/bin/piper',
    '/usr/local/bin/piper',
    'piper',  // PATH fallback
  ]) {
    try {
      const r = require('node:child_process').spawnSync(p, ['--help'], { stdio: 'ignore' });
      if (r.status === 0 || r.status === null) return p;
    } catch {}
  }
  return 'piper';
}
const PIPER = piperBin();

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

// Synthesize one verse via Piper. Pipes text -> piper -> wav -> ffmpeg -> mp3.
async function synthOne(text, voiceFile, dstMp3) {
  return new Promise((resolve, reject) => {
    const voicePath = path.join(VOICES_DIR, voiceFile);
    if (!fs.existsSync(voicePath)) {
      reject(new Error(`Voice model missing: ${voicePath}`));
      return;
    }
    // Pipe: echo text | piper --model X --output-raw | ffmpeg -i - dst.mp3
    // Using --output-raw + ffmpeg gives us MP3 directly without a wav
    // intermediate file. Piper's stdout is signed 16-bit PCM @ the
    // model's sample rate (most are 22050 Hz).
    const sampleRate = 22050;  // Piper default for most voices
    const piper = spawn(PIPER, [
      '--model', voicePath,
      '--output-raw',
    ], { stdio: ['pipe', 'pipe', 'pipe'] });
    const ffmpeg = spawn('/opt/homebrew/bin/ffmpeg', [
      '-y',
      '-f', 's16le', '-ar', String(sampleRate), '-ac', '1', '-i', '-',
      '-codec:a', 'libmp3lame', '-b:a', '64k',
      dstMp3,
    ], { stdio: ['pipe', 'pipe', 'pipe'] });

    piper.stdout.pipe(ffmpeg.stdin);
    piper.stdin.write(text);
    piper.stdin.end();

    let stderr = '';
    piper.stderr.on('data', (d) => { stderr += d.toString(); });
    ffmpeg.stderr.on('data', (d) => { stderr += d.toString(); });

    ffmpeg.on('close', (code) => {
      if (code === 0 && fs.existsSync(dstMp3) && fs.statSync(dstMp3).size > 256) {
        resolve({ ok: true });
      } else {
        if (fs.existsSync(dstMp3)) try { fs.unlinkSync(dstMp3); } catch {}
        resolve({ ok: false, error: stderr.substring(stderr.length - 200) });
      }
    });
    ffmpeg.on('error', (e) => resolve({ ok: false, error: e.message }));
    piper.on('error', (e) => resolve({ ok: false, error: e.message }));
  });
}

async function run() {
  console.error(`Piper TTS — version=${versionSlug} gender=${genders.join('/')} concurrency=${concurrency}`);
  console.error(`Output: ${AUDIO_BASE}/${versionSlug}/`);

  const versionPath = `${ROOT}/assets/${versionSlug}.json`;
  if (!fs.existsSync(versionPath)) {
    console.error(`ERROR: ${versionPath} not found`);
    process.exit(1);
  }
  const locale = localeFor(versionSlug);
  const verses = JSON.parse(fs.readFileSync(versionPath, 'utf-8'));
  console.error(`Total verses: ${verses.length}`);

  // Build flat task list (skipping already-done).
  const tasks = [];
  for (const v of verses) {
    if (!v.book || !v.chapter || !v.verse || !v.text) continue;
    const text = sanitize(v.text);
    if (!text) continue;
    for (const gender of genders) {
      const voiceFile = VOICES[`${locale}_${gender}`];
      if (!voiceFile) continue;
      const g = gender === 'male' ? 'M' : 'F';
      const dir = path.join(AUDIO_BASE, versionSlug, safeBook(v.book));
      const dst = path.join(dir, `${v.chapter}_${v.verse}_${g}.mp3`);
      if (fs.existsSync(dst) && fs.statSync(dst).size > 256) continue;
      tasks.push({ text, voiceFile, dst, dir, gender });
    }
  }
  console.error(`Tasks to run: ${tasks.length}`);

  // Concurrent worker pool.
  let cursor = 0;
  let ok = 0, fail = 0;
  const startTime = Date.now();
  async function worker(id) {
    while (cursor < tasks.length) {
      const i = cursor++;
      const t = tasks[i];
      fs.mkdirSync(t.dir, { recursive: true });
      const r = await synthOne(t.text, t.voiceFile, t.dst);
      if (r.ok) ok++;
      else { fail++; console.error(`  fail [${t.voiceFile}]: ${r.error?.substring(0, 80)}`); }
      if ((ok + fail) % 100 === 0) {
        const elapsedMin = (Date.now() - startTime) / 60_000;
        const rate = (ok + fail) / elapsedMin;
        const remaining = (tasks.length - (ok + fail)) / rate;
        console.error(`  worker${id}: ${ok + fail}/${tasks.length} ok=${ok} fail=${fail} ` +
          `(${rate.toFixed(0)}/min, ~${remaining.toFixed(0)} min remaining)`);
      }
    }
  }

  const workers = [];
  for (let w = 0; w < concurrency; w++) workers.push(worker(w));
  await Promise.all(workers);

  const elapsed = ((Date.now() - startTime) / 60_000).toFixed(1);
  console.error(`\nDONE. ${ok} synthesized, ${fail} failed in ${elapsed} min.`);
  console.error(`Next: cd ${YDATA} && git add audio/ && git commit -m 'audio piper ${versionSlug}' && git push`);
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
