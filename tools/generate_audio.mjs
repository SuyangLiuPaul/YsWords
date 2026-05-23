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

// CUV / CNV / Chinese versions store book names in Chinese. The app
// builds CDN URLs from the English book name, so the file system
// path must match. Map mirrors lib/constants/book_name_mapping.dart.
const ZH_TO_EN = {
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

function safeBookFs(book) {
  const en = ZH_TO_EN[book] || book;
  return String(en).replace(/[^A-Za-z0-9]+/g, '_');
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
