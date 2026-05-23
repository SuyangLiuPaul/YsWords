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

// Chinese book name → English. Mirrors lib/constants/book_name_mapping.dart.
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
function safeBook(b) {
  const en = ZH_TO_EN[b] || b;
  return String(en).replace(/[^A-Za-z0-9]+/g, '_');
}

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
