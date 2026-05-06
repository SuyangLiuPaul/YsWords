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
#   • drive.googleapis.com           → Drive sync (YsWords.json in user My Drive)
#   • generativelanguage.googleapis.com → Gemini AI (word study + AI search)
#
# Doesn't do:
#   • OAuth consent-screen scope (drive.file) — that's a UI-only action
#     in Cloud Console, no CLI for it. Run the in-app diagnostic at
#     Settings → Account → "Run check" for the deep-link.
#   • Firebase Authorized domain (yswords.netlify.app) — same reason.
#   • Netlify env vars (GEMINI_API_KEY) — that's a Netlify dashboard
#     setting, not a Google Cloud one.
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

echo "==> Enabling Drive + Gemini APIs in project: $PROJECT_ID"
echo "    (re-running on an already-enabled project is a no-op)"
echo

gcloud services enable \
  drive.googleapis.com \
  generativelanguage.googleapis.com \
  --project="$PROJECT_ID"

echo
echo "✅ Done. Now finish these steps in the Cloud Console (no CLI):"
echo "    • OAuth consent screen → add 'drive.file' scope"
echo "      https://console.cloud.google.com/apis/credentials/consent?project=$PROJECT_ID"
echo "    • Firebase authorized domains → add yswords.netlify.app"
echo "      https://console.firebase.google.com/project/$PROJECT_ID/authentication/settings"
echo "    • Netlify env vars → set GEMINI_API_KEY"
echo "      https://app.netlify.com/projects/yswords/configuration/env"
echo
echo "Then run the in-app diagnostic at Settings → Account → 'Run check'"
echo "to verify everything is green."
