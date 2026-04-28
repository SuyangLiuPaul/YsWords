// YsWords Cloud Functions — server-side Gemini proxy for AI search.
//
// Why server-side: the previous bible-evidence Vite app inlined Gemini
// API keys into the public bundle, leaking 5 keys. We never repeat that.
// All Gemini calls go through this function; the service-account key is
// loaded from Firebase secrets and never reaches the browser.
//
// Endpoint: POST /aiSearch
//   { query: string, locale?: "en"|"zh-Hans"|"zh-Hant" }
//   -> { answer: string, citations: [{ id, title, scriptureReference }] }
//
// Secret setup (one-time):
//   firebase functions:secrets:set GEMINI_SA \
//     --data-file ~/.config/yswords/secrets/gemini-service-account.json
//
// Deploy:
//   cd functions && npm install
//   firebase deploy --only functions

import { onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { GoogleAuth } from "google-auth-library";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const GEMINI_SA = defineSecret("GEMINI_SA");

// Allowed origins — production + local dev only. Lock down further if
// the app ever gets a custom domain.
const ALLOWED_ORIGINS = new Set([
  "https://yswords.netlify.app",
  "http://localhost:8080",
  "http://localhost:5173",
  "http://127.0.0.1:8080",
]);

// Vertex AI / Gemini endpoint. We use Gemini 1.5 Flash for cost; the
// dataset is small enough that summarization quality is fine.
const PROJECT_ID = "corded-cortex-493500-d8";
const LOCATION = "us-central1";
const MODEL = "gemini-1.5-flash";

// Lazily-loaded evidence dataset (bundled with the function).
let _dataset = null;
function loadDataset() {
  if (_dataset) return _dataset;
  const here = dirname(fileURLToPath(import.meta.url));
  // Symlinked at deploy time — see deploy script. For dev fallback, look
  // up the repo root.
  const candidates = [
    join(here, "bible_evidence.json"),
    join(here, "..", "assets", "bible_evidence.json"),
  ];
  for (const p of candidates) {
    try {
      _dataset = JSON.parse(readFileSync(p, "utf-8"));
      return _dataset;
    } catch (_) { /* try next */ }
  }
  throw new Error("bible_evidence.json not found in functions/ or assets/");
}

// Cheap keyword pre-filter so we only send the most relevant entries to
// Gemini. The full dataset is ~1.5 MB which would blow context windows
// and rack up token cost on every query.
function localPrefilter(query, locale, limit = 12) {
  const ds = loadDataset();
  const q = query.toLowerCase();
  const tokens = q.split(/\s+/).filter((t) => t.length >= 2);
  if (tokens.length === 0) return [];

  const scored = [];
  for (const e of ds.evidences) {
    const hay = [
      (e.title?.[locale] || e.title?.en || "").toLowerCase(),
      (e.summary?.[locale] || e.summary?.en || "").toLowerCase(),
      (e.description?.[locale] || e.description?.en || "").toLowerCase(),
      (e.scriptureReference || "").toLowerCase(),
      (e.bibleBooks || []).join(" ").toLowerCase(),
      (e.category || "").toLowerCase(),
    ].join(" ");
    let score = 0;
    for (const t of tokens) if (hay.includes(t)) score += 1;
    if (score > 0) scored.push({ e, score });
  }
  scored.sort((a, b) => b.score - a.score);
  return scored.slice(0, limit).map((x) => x.e);
}

async function getAccessToken() {
  const saJson = GEMINI_SA.value();
  if (!saJson) throw new Error("GEMINI_SA secret not set");
  const credentials = JSON.parse(saJson);
  const auth = new GoogleAuth({
    credentials,
    scopes: ["https://www.googleapis.com/auth/cloud-platform"],
  });
  const client = await auth.getClient();
  const { token } = await client.getAccessToken();
  return token;
}

async function callGemini(prompt) {
  const token = await getAccessToken();
  const url =
    `https://${LOCATION}-aiplatform.googleapis.com/v1/projects/` +
    `${PROJECT_ID}/locations/${LOCATION}/publishers/google/models/` +
    `${MODEL}:generateContent`;
  const resp = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      contents: [{ role: "user", parts: [{ text: prompt }] }],
      generationConfig: {
        temperature: 0.2,
        maxOutputTokens: 512,
      },
    }),
  });
  if (!resp.ok) {
    const txt = await resp.text();
    throw new Error(`Gemini ${resp.status}: ${txt.slice(0, 400)}`);
  }
  const json = await resp.json();
  const text =
    json?.candidates?.[0]?.content?.parts
      ?.map((p) => p.text || "")
      ?.join("") || "";
  return text;
}

function buildPrompt(query, locale, hits) {
  const langName = locale === "zh-Hans"
    ? "Simplified Chinese"
    : locale === "zh-Hant"
    ? "Traditional Chinese"
    : "English";

  const ctx = hits
    .map(
      (e, i) =>
        `[${i + 1}] id=${e.id}\n` +
        `  title: ${e.title?.[locale] || e.title?.en || ""}\n` +
        `  reference: ${e.scriptureReference}\n` +
        `  summary: ${e.summary?.[locale] || e.summary?.en || ""}`,
    )
    .join("\n");

  return `You are a Bible-evidence research assistant. Answer the user's
question using ONLY the numbered context entries below. Reply in ${langName}.
Be concise (1-3 sentences). End with bracketed citations like [1] [3]
matching the entry numbers you used. If the context doesn't answer the
question, say so plainly.

USER QUESTION: ${query}

CONTEXT:
${ctx}`;
}

function corsHeaders(origin) {
  const allow = ALLOWED_ORIGINS.has(origin) ? origin : "https://yswords.netlify.app";
  return {
    "Access-Control-Allow-Origin": allow,
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
    Vary: "Origin",
  };
}

export const aiSearch = onRequest(
  { secrets: [GEMINI_SA], cors: false, region: "us-central1", timeoutSeconds: 30 },
  async (req, res) => {
    const headers = corsHeaders(req.headers.origin || "");
    Object.entries(headers).forEach(([k, v]) => res.setHeader(k, v));

    if (req.method === "OPTIONS") return res.status(204).send("");
    if (req.method !== "POST") return res.status(405).json({ error: "POST only" });

    try {
      const { query, locale = "en" } = req.body || {};
      if (typeof query !== "string" || query.trim().length < 2) {
        return res.status(400).json({ error: "query required" });
      }

      const hits = localPrefilter(query, locale, 12);
      if (hits.length === 0) {
        return res.json({ answer: "", citations: [], hits: 0 });
      }

      const answer = await callGemini(buildPrompt(query, locale, hits));

      const citations = hits.map((e) => ({
        id: e.id,
        title: e.title?.[locale] || e.title?.en || "",
        scriptureReference: e.scriptureReference,
      }));

      return res.json({ answer, citations, hits: hits.length });
    } catch (err) {
      console.error("aiSearch error:", err);
      return res.status(500).json({ error: String(err?.message || err) });
    }
  },
);
