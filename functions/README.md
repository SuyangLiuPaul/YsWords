# YsWords Cloud Functions

Server-side proxy for Gemini AI search over the Bible Evidence dataset.
Replaces the leak-prone client-side Gemini integration that lived in the
sunset `bible-evidence` React project.

## One-time setup

Install Firebase CLI globally:

```sh
npm install -g firebase-tools
firebase login
```

Set the Gemini service-account secret (one-time, key lives in Keychain
and on disk — see `~/.config/yswords/secrets/README.md`):

```sh
firebase functions:secrets:set GEMINI_SA \
  --data-file ~/.config/yswords/secrets/gemini-service-account.json
```

## Local dev

```sh
cd functions
npm install
# Bundle the evidence dataset alongside the function for offline emulator:
ln -sf ../assets/bible_evidence.json bible_evidence.json
firebase emulators:start --only functions
# -> POST http://127.0.0.1:5001/ysword/us-central1/aiSearch
```

Test:

```sh
curl -X POST http://127.0.0.1:5001/ysword/us-central1/aiSearch \
  -H "Content-Type: application/json" \
  -H "Origin: http://localhost:8080" \
  -d '{"query":"dead sea scrolls","locale":"en"}'
```

## Deploy

The dataset must be present in the function dir at deploy time. The
predeploy step copies it from `assets/`:

```sh
# from repo root
cp assets/bible_evidence.json functions/bible_evidence.json
firebase deploy --only functions
```

After deploy the function lives at:

```
https://us-central1-ysword.cloudfunctions.net/aiSearch
```

## Wiring the Flutter app

See `lib/services/ai_search_service.dart` (created in the same round as
this scaffold). Update the endpoint in that file once deployed.

## Cost notes

- Gemini 1.5 Flash, 512 max output tokens, ~1k input tokens per query
  -> ~ $0.0001 per call. Cheap.
- Cloud Functions free tier covers 2M invocations/month.
- The function runs a local keyword pre-filter so only top-12 entries
  are sent to Gemini, capping context cost.

## Security model

- Service-account key is loaded from Firebase secrets, never bundled.
- CORS is locked to the deployed YsWords origin + localhost dev ports.
- The function is unauthenticated for MVP — if abuse becomes a problem,
  swap `onRequest` for `onCall` and require Firebase Auth.
