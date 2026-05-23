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

// --books "Matthew,Mark,Luke" filter (case-insensitive). Compared
// against the English book name (translated via ZH_TO_EN for
// Chinese versions). If unset, all books are generated. Useful for
// spot-testing one book before running the whole bible.
const bookFilter = args.books
  ? new Set(args.books.split(',').map((s) => s.trim().toLowerCase()).filter(Boolean))
  : null;
if (bookFilter) {
  console.error(`Book filter: ${[...bookFilter].join(', ')}`);
}

const PROGRESS_FILE = `/tmp/audio_gen_piper.${versionSlug}.json`;
let progress = {};
if (fs.existsSync(PROGRESS_FILE)) {
  try { progress = JSON.parse(fs.readFileSync(PROGRESS_FILE, 'utf-8')); } catch {}
}

// Resolve piper binary. Try a known set of locations + PATH. Many
// people install via `pipx install piper-tts` which lands in
// ~/.local/bin/piper rather than the brew prefixes.
function piperBin() {
  const candidates = [
    `${os.homedir()}/.local/bin/piper`,
    '/opt/homebrew/bin/piper',
    '/usr/local/bin/piper',
  ];
  for (const p of candidates) {
    try {
      if (fs.existsSync(p)) return p;
    } catch {}
  }
  return 'piper';  // last-ditch PATH fallback
}
const PIPER = piperBin();
console.error(`Using piper binary: ${PIPER}`);

function localeFor(slug) {
  // Traditional Chinese: any slug ending in -tr.
  if (/-tr$/.test(slug)) return 'zh-Hant';
  // Simplified Chinese: cuv / cnv / cuvs-yhwh / biblexg (LJK Lü
  // Zhenzhong) / biblexg-v2 (LJK V2). Anything else is English.
  if (/^(cuv|cnv|cuvs-yhwh|biblexg(-v2)?)$/.test(slug)) return 'zh-Hans';
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

// 2026-05-23: CUV / CNV / Chinese versions store book names in
// Chinese ("创世记"). The app builds CDN URLs using the English
// book name via `toEnglish()`, so the file system must match —
// otherwise the app fetches /audio/cuv/Genesis/1_1_F.mp3 but we
// wrote /audio/cuv/__/1_1_F.mp3. This map mirrors the canonical
// one in lib/constants/book_name_mapping.dart (`_zhAliasToEn`).
const ZH_TO_EN = {
  // Old Testament
  '创世纪': 'Genesis', '創世紀': 'Genesis', '创世记': 'Genesis', '創世記': 'Genesis',
  '出埃及记': 'Exodus', '出埃及記': 'Exodus',
  '利未记': 'Leviticus', '利未記': 'Leviticus',
  '民数记': 'Numbers', '民數記': 'Numbers',
  '申命记': 'Deuteronomy', '申命記': 'Deuteronomy',
  '约书亚记': 'Joshua', '約書亞記': 'Joshua',
  '士师记': 'Judges', '士師記': 'Judges',
  '路得记': 'Ruth', '路得記': 'Ruth',
  '撒母耳记上': '1 Samuel', '撒母耳記上': '1 Samuel',
  '撒母耳记下': '2 Samuel', '撒母耳記下': '2 Samuel',
  '列王纪上': '1 Kings', '列王紀上': '1 Kings',
  '列王纪下': '2 Kings', '列王紀下': '2 Kings',
  '历代志上': '1 Chronicles', '歷代志上': '1 Chronicles',
  '历代志下': '2 Chronicles', '歷代志下': '2 Chronicles',
  '以斯拉记': 'Ezra', '以斯拉記': 'Ezra',
  '尼希米记': 'Nehemiah', '尼希米記': 'Nehemiah',
  '以斯帖记': 'Esther', '以斯帖記': 'Esther',
  '约伯记': 'Job', '約伯記': 'Job',
  '诗篇': 'Psalms', '詩篇': 'Psalms',
  '箴言': 'Proverbs',
  '传道书': 'Ecclesiastes', '傳道書': 'Ecclesiastes',
  '雅歌': 'Song of Solomon',
  '以赛亚书': 'Isaiah', '以賽亞書': 'Isaiah',
  '耶利米书': 'Jeremiah', '耶利米書': 'Jeremiah',
  '耶利米哀歌': 'Lamentations',
  '以西结书': 'Ezekiel', '以西結書': 'Ezekiel',
  '但以理书': 'Daniel', '但以理書': 'Daniel',
  '何西阿书': 'Hosea', '何西阿書': 'Hosea',
  '约珥书': 'Joel', '約珥書': 'Joel',
  '阿摩司书': 'Amos', '阿摩司書': 'Amos',
  '俄巴底亚书': 'Obadiah', '俄巴底亞書': 'Obadiah',
  '约拿书': 'Jonah', '約拿書': 'Jonah',
  '弥迦书': 'Micah', '彌迦書': 'Micah',
  '那鸿书': 'Nahum', '那鴻書': 'Nahum',
  '哈巴谷书': 'Habakkuk', '哈巴谷書': 'Habakkuk',
  '西番雅书': 'Zephaniah', '西番雅書': 'Zephaniah',
  '哈该书': 'Haggai', '哈該書': 'Haggai',
  '撒迦利亚书': 'Zechariah', '撒迦利亞書': 'Zechariah',
  '玛拉基书': 'Malachi', '瑪拉基書': 'Malachi',
  // New Testament
  '马太福音': 'Matthew', '馬太福音': 'Matthew',
  '马可福音': 'Mark', '馬可福音': 'Mark',
  '路加福音': 'Luke',
  '约翰福音': 'John', '約翰福音': 'John',
  '使徒行传': 'Acts', '使徒行傳': 'Acts',
  '罗马书': 'Romans', '羅馬書': 'Romans',
  '哥林多前书': '1 Corinthians', '哥林多前書': '1 Corinthians',
  '哥林多后书': '2 Corinthians', '哥林多後書': '2 Corinthians',
  '加拉太书': 'Galatians', '加拉太書': 'Galatians',
  '以弗所书': 'Ephesians', '以弗所書': 'Ephesians',
  '腓立比书': 'Philippians', '腓立比書': 'Philippians',
  '歌罗西书': 'Colossians', '歌羅西書': 'Colossians',
  '帖撒罗尼迦前书': '1 Thessalonians', '帖撒羅尼迦前書': '1 Thessalonians',
  '帖撒罗尼迦后书': '2 Thessalonians', '帖撒羅尼迦後書': '2 Thessalonians',
  '提摩太前书': '1 Timothy', '提摩太前書': '1 Timothy',
  '提摩太后书': '2 Timothy', '提摩太後書': '2 Timothy',
  '提多书': 'Titus', '提多書': 'Titus',
  '腓利门书': 'Philemon', '腓利門書': 'Philemon',
  '希伯来书': 'Hebrews', '希伯來書': 'Hebrews',
  '雅各书': 'James', '雅各書': 'James',
  '彼得前书': '1 Peter', '彼得前書': '1 Peter',
  '彼得后书': '2 Peter', '彼得後書': '2 Peter',
  '约翰一书': '1 John', '約翰一書': '1 John',
  '约翰二书': '2 John', '約翰二書': '2 John',
  '约翰三书': '3 John', '約翰三書': '3 John',
  '犹大书': 'Jude', '猶大書': 'Jude',
  '启示录': 'Revelation', '啟示錄': 'Revelation',
};

function safeBook(b) {
  const en = ZH_TO_EN[b] || b;
  const result = String(en).replace(/[^A-Za-z0-9]+/g, '_');
  if (result === '_' && process.env.DEBUG_SAFEBOOK === '1') {
    console.error(`  safeBook miss: in="${b}" codepoints=${[...b].map(c=>c.codePointAt(0).toString(16)).join(',')} en="${en}"`);
  }
  return result;
}

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
  const safeBookMisses = new Set();
  for (const v of verses) {
    if (!v.book || !v.chapter || !v.verse || !v.text) continue;
    const text = sanitize(v.text);
    if (!text) continue;
    const safe = safeBook(v.book);
    if (!ZH_TO_EN[v.book] && /^[一-鿿]/.test(v.book)) {
      // Chinese book but no match → log it so we can patch the map.
      safeBookMisses.add(v.book);
    }
    // Skip books outside the --books filter (compare to English name).
    if (bookFilter) {
      const en = (ZH_TO_EN[v.book] || v.book).toLowerCase();
      if (!bookFilter.has(en)) continue;
    }
    for (const gender of genders) {
      const voiceFile = VOICES[`${locale}_${gender}`];
      if (!voiceFile) continue;
      const g = gender === 'male' ? 'M' : 'F';
      const dir = path.join(AUDIO_BASE, versionSlug, safe);
      const dst = path.join(dir, `${v.chapter}_${v.verse}_${g}.mp3`);
      if (fs.existsSync(dst) && fs.statSync(dst).size > 256) continue;
      tasks.push({ text, voiceFile, dst, dir, gender });
    }
  }
  if (safeBookMisses.size > 0) {
    console.error(`\n⚠️  Chinese book names NOT in ZH_TO_EN map (will land in _/):`);
    for (const b of safeBookMisses) {
      console.error(`   "${b}" codepoints: ${[...b].map(c=>c.codePointAt(0).toString(16)).join(',')}`);
    }
    console.error('');
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
