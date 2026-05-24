// 2026-05-23 (v1.2.86): Google Cloud Text-to-Speech proxy. Mirrors
// the same shape as aiSearch / aiBibleSearch / aiExplainWord —
// Netlify function reading shared API keys from env (with BYOK
// override), with a generous timeout because audio generation
// runs longer than text-only completions.
//
// Env vars (set on the Netlify site):
//   GOOGLE_TTS_API_KEY          — primary Google Cloud key with the
//                                  Cloud Text-to-Speech API enabled.
//   GOOGLE_TTS_API_KEY_BACKUP   — optional secondary key for rotation
//                                  on quota errors.
//   GOOGLE_TTS_API_KEY_BACKUP_2 — and so on.
//
// Path: /api/aiSpeak (Netlify rewrites to /.netlify/functions/aiSpeak)

// Voice map. Keys are <locale>_<gender>. Tier maps further inside.
//
// 2026-05-24 (v1.3.10): upgraded en-US + zh-Hans defaults to Google
// Cloud TTS **Chirp 3 HD** voices — released late 2024, Gemini-based
// generative TTS, currently the highest-quality cloud TTS Google
// offers. Same 1 M chars/month free quota as the Wavenet voices
// these replaced.
//
// Voice selection rationale (Chirp 3 HD uses astronomical names):
//   - Aoede:  calm female, ideal for verse narration (Bible reading
//             benefits from a measured pace + clear emotional reading)
//   - Charon: clear male, neutral cadence, doesn't dramatise
//
// Why not zh-Hant on Chirp 3: Google's initial Chirp 3 HD rollout
// (https://cloud.google.com/text-to-speech/docs/chirp3-hd) supports
// en-US + cmn-CN + a dozen others, but does NOT yet include cmn-TW.
// Traditional Chinese users continue to use Wavenet cmn-TW until
// Google adds Chirp 3 cmn-TW. Mandarin pronunciation is the same;
// only orthography differs, so the script handles that anyway.
const VOICE_MAP = {
  'en_female':       { langCode: 'en-US',  name: 'en-US-Chirp3-HD-Aoede' },
  'en_male':         { langCode: 'en-US',  name: 'en-US-Chirp3-HD-Charon' },
  'zh-Hans_female':  { langCode: 'cmn-CN', name: 'cmn-CN-Chirp3-HD-Aoede' },
  'zh-Hans_male':    { langCode: 'cmn-CN', name: 'cmn-CN-Chirp3-HD-Charon' },
  // zh-Hant: Chirp 3 doesn't ship cmn-TW yet — keep Wavenet here.
  'zh-Hant_female':  { langCode: 'cmn-TW', name: 'cmn-TW-Wavenet-A' },
  'zh-Hant_male':    { langCode: 'cmn-TW', name: 'cmn-TW-Wavenet-B' },
};

// 2026-05-24 (v1.3.10): legacy Wavenet voices, accessible via
// `tier: 'wavenet'` from the client. Kept as a fallback in case
// Chirp 3 misbehaves on any specific verse / phoneme; the client
// can opt back into Wavenet without code change.
const VOICE_MAP_WAVENET = {
  'en_female':       { langCode: 'en-US',  name: 'en-US-Neural2-F' },
  'en_male':         { langCode: 'en-US',  name: 'en-US-Neural2-D' },
  'zh-Hans_female':  { langCode: 'cmn-CN', name: 'cmn-CN-Wavenet-A' },
  'zh-Hans_male':    { langCode: 'cmn-CN', name: 'cmn-CN-Wavenet-B' },
  'zh-Hant_female':  { langCode: 'cmn-TW', name: 'cmn-TW-Wavenet-A' },
  'zh-Hant_male':    { langCode: 'cmn-TW', name: 'cmn-TW-Wavenet-B' },
};

// Standard-tier fallback voices (4× cheaper, used when client requests
// `tier: 'standard'` for high-volume scenarios).
const VOICE_MAP_STANDARD = {
  'en_female':       { langCode: 'en-US',  name: 'en-US-Standard-F' },
  'en_male':         { langCode: 'en-US',  name: 'en-US-Standard-D' },
  'zh-Hans_female':  { langCode: 'cmn-CN', name: 'cmn-CN-Standard-A' },
  'zh-Hans_male':    { langCode: 'cmn-CN', name: 'cmn-CN-Standard-B' },
  'zh-Hant_female':  { langCode: 'cmn-TW', name: 'cmn-TW-Standard-A' },
  'zh-Hant_male':    { langCode: 'cmn-TW', name: 'cmn-TW-Standard-B' },
};

function pickVoice(locale, gender, tier) {
  // Normalise locale to one of the keys we support.
  const loc = locale.startsWith('zh-Hans') || locale === 'zh'
    ? 'zh-Hans'
    : locale.startsWith('zh-Hant') || locale.startsWith('zh-TW')
      ? 'zh-Hant'
      : 'en';
  const g = gender === 'male' ? 'male' : 'female';
  let table;
  if (tier === 'standard')       table = VOICE_MAP_STANDARD;
  else if (tier === 'wavenet')   table = VOICE_MAP_WAVENET;
  else                            table = VOICE_MAP; // default (Chirp 3 HD)
  return table[`${loc}_${g}`] || table['en_female'];
}

function ttsKeys() {
  const seen = new Set();
  const out = [];
  const push = (s) => {
    const k = (s || '').trim();
    if (k && !seen.has(k)) { seen.add(k); out.push(k); }
  };
  if (process.env.GOOGLE_TTS_API_KEYS) {
    for (const part of process.env.GOOGLE_TTS_API_KEYS.split(',')) push(part);
  }
  push(process.env.GOOGLE_TTS_API_KEY);
  push(process.env.GOOGLE_TTS_API_KEY_BACKUP);
  for (let i = 2; i <= 9; i++) push(process.env[`GOOGLE_TTS_API_KEY_BACKUP_${i}`]);
  return out;
}

async function synthesize(apiKey, text, voice, speakingRate) {
  const url = `https://texttospeech.googleapis.com/v1/text:synthesize?key=${apiKey}`;
  const body = {
    input: { text },
    voice: { languageCode: voice.langCode, name: voice.name },
    audioConfig: {
      audioEncoding: 'MP3',
      speakingRate: speakingRate || 1.0,
      sampleRateHertz: 24000,
    },
  };
  // 25s timeout — Google synthesis is usually 1-3s, but a 5000-char
  // payload can spike to 10-15s. 25s leaves a buffer below Netlify's
  // 26s function cap.
  const r = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(25_000),
  });
  return r;
}

export default async (req) => {
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'POST only' }), {
      status: 405, headers: { 'Content-Type': 'application/json' },
    });
  }

  let body;
  try { body = await req.json(); }
  catch { return new Response(JSON.stringify({ error: 'invalid JSON' }), { status: 400, headers: { 'Content-Type': 'application/json' } }); }

  const text = String(body.text || '').trim();
  if (!text) return new Response(JSON.stringify({ error: 'text required' }), { status: 400, headers: { 'Content-Type': 'application/json' } });
  // Google Cloud TTS hard limit is 5000 chars (text input). Reject
  // larger payloads with a clear error — the client should chunk.
  if (text.length > 5000) {
    return new Response(JSON.stringify({ error: 'text exceeds 5000 chars; chunk before requesting' }),
      { status: 400, headers: { 'Content-Type': 'application/json' } });
  }

  const locale = String(body.locale || 'en');
  const gender = String(body.gender || 'female');
  const tier = String(body.tier || 'neural');
  const speakingRate = Number(body.speakingRate) || 1.0;
  const voice = pickVoice(locale, gender, tier);

  // Key rotation: try shared keys, with BYOK as a first-priority
  // override if the client passed one.
  const userKey = String(body.userApiKey || '').trim();
  const keys = [];
  if (userKey) keys.push(userKey);
  keys.push(...ttsKeys());

  if (keys.length === 0) {
    return new Response(JSON.stringify({ error: 'TTS is not configured; set GOOGLE_TTS_API_KEY on the server or pass userApiKey in the request body.' }),
      { status: 503, headers: { 'Content-Type': 'application/json' } });
  }

  let lastError = null;
  for (const key of keys) {
    try {
      const r = await synthesize(key, text, voice, speakingRate);
      if (r.ok) {
        const j = await r.json();
        if (!j.audioContent) {
          lastError = 'empty audioContent';
          continue;
        }
        return new Response(JSON.stringify({
          audio: j.audioContent,  // base64-encoded MP3
          voice: voice.name,
          locale: voice.langCode,
          chars: text.length,
        }), {
          status: 200,
          headers: {
            'Content-Type': 'application/json',
            // Encourage edge cache of identical synthesis requests by
            // client/CDN. 1 day is plenty — content rarely changes.
            'Cache-Control': 'public, max-age=86400',
            'Access-Control-Allow-Origin': '*',
          },
        });
      }
      // 429 (quota) and 5xx → step to next key.
      const errText = await r.text();
      lastError = `HTTP ${r.status}: ${errText.substring(0, 200)}`;
      if (r.status !== 429 && r.status < 500) {
        // 4xx-other (400 / 401 / 403) is a caller error — bail
        // immediately rather than burning more keys.
        return new Response(JSON.stringify({ error: lastError }),
          { status: r.status, headers: { 'Content-Type': 'application/json' } });
      }
    } catch (e) {
      lastError = e.message?.substring(0, 200) || 'unknown';
    }
  }

  return new Response(JSON.stringify({
    error: `All TTS keys failed. Last error: ${lastError}`,
  }), {
    status: 502,
    headers: { 'Content-Type': 'application/json' },
  });
};

export const config = { path: '/api/aiSpeak' };
