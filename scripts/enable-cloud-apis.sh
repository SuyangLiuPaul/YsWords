#!/usr/bin/env bash
# Enable the Google Cloud APIs that YsWords needs.
#
# Usage (in your local terminal, with gcloud already installed):
#   ./scripts/enable-cloud-apis.sh                 # uses default project
#   ./scripts/enable-cloud-apis.sh other-project   # override project id
#
# Usage (in Google Cloud Shell — recommended; no install needed):
#   1. Open https://shell.cloud.google.com
#   2. Run: bash <(curl -s https://raw.githubusercontent.com/SuyangLiuPaul/YsWords/main/scripts/enable-cloud-apis.sh)
#
# What this enables:
#   • generativelanguage.googleapis.com → Gemini AI (word study + AI search)
#
# Note: As of 2026-05-06 sync moved off Google Drive onto Firebase
# Realtime Database, so the Drive API enable command was dropped from
# this script. Realtime Database is enabled inside the Firebase Console
# (one click — no CLI). Use the in-app diagnostic at Settings → Account
# → "Run check" to see whether RTDB is reachable; on failure it gives
# a deep-link to the right Firebase Console page.
#
# Doesn't do:
#   • Firebase Realtime Database enablement — UI-only in Firebase
#     Console. Click "Create Database" on the RTDB tab.
#   • Realtime Database security rules — UI-only. The in-app
#     diagnostic + walkthrough have the recommended rules JSON.
#   • Firebase Authorized domain (yswords.netlify.app) — UI-only.
#   • Netlify env vars (GEMINI_API_KEY) — Netlify dashboard, not GCP.
#
# Idempotent — re-running this on an already-enabled project is a no-op.

set -euo pipefail

PROJECT_ID="${1:-ysword}"

if ! command -v gcloud >/dev/null 2>&1; then
  cat >&2 <<MSG
gcloud CLI not found.

Easiest path — use Google Cloud Shell instead (no install needed):
  1. Open: https://shell.cloud.google.com
  2. Paste:  bash <(curl -s https://raw.githubusercontent.com/SuyangLiuPaul/YsWords/main/scripts/enable-cloud-apis.sh)

Or install the CLI locally:
  https://cloud.google.com/sdk/docs/install
MSG
  exit 1
fi

echo "==> Enabling Gemini API in project: $PROJECT_ID"
echo "    (re-running on an already-enabled project is a no-op)"
echo

gcloud services enable \
  generativelanguage.googleapis.com \
  --project="$PROJECT_ID"

echo
echo "✅ Done. Now finish these steps in the Firebase / Netlify consoles:"
echo "    • Realtime Database — click 'Create Database'"
echo "      https://console.firebase.google.com/project/$PROJECT_ID/database"
echo "    • RTDB security rules — paste the recommended ruleset"
echo "      https://console.firebase.google.com/project/$PROJECT_ID/database/$PROJECT_ID-default-rtdb/rules"
echo "    • Firebase authorized domains — add yswords.netlify.app"
echo "      https://console.firebase.google.com/project/$PROJECT_ID/authentication/settings"
echo "    • Netlify env vars — set GEMINI_API_KEY"
echo "      https://app.netlify.com/projects/yswords/configuration/env"
echo
echo "Then run the in-app diagnostic at Settings → Account → 'Run check'"
echo "to verify everything is green."
