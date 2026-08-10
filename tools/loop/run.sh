#!/bin/bash
# YsWords autonomous iteration loop, driven by launchd.
#
# Modelled on the SeekSparks parity loop, which learned all of the
# following the hard way. Read the comments before changing anything —
# each one is a failure that already happened on this machine.
#
# WHY launchd AND NOT AN IN-SESSION SCHEDULER: a Claude cron job created
# inside a conversation lives in the app's memory and needs a running
# REPL. It never fired once the conversation went quiet. launchd
# survives the app closing and restarts at login, which is what
# "run every hour for two weeks" actually requires.
#
# Files, all in this directory:
#   prompt.md   the brief handed to `claude -p` each tick
#   TODO.md     the work queue the brief tells it to consume
#   run.log     appended transcript of every run
#   .lock       single-flight guard (a directory: mkdir is atomic)

set -uo pipefail

# launchd hands over a near-empty environment; PATH must be pinned or the
# tools silently vanish. Flutter in particular is NOT on the default PATH
# on this machine.
export PATH="$HOME/.local/bin:$HOME/flutter/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

DIR="$HOME/Library/Application Support/yswords-loop"
REPO="$HOME/Documents/yswords"
LOG="$DIR/run.log"
LOCK="$DIR/.lock"
LABEL="com.yswords.accuracyloop"

# Dead-man switch, not a deadline. Two weeks, at the user's instruction
# ("run两周的时间"). Read fresh every invocation, so changing it takes
# effect on the next tick with no reload and no risk of killing a run
# mid-commit. The job unloads ITSELF rather than idling forever.
#
# Stop early at any time with:
#   launchctl bootout gui/$(id -u)/com.yswords.accuracyloop
STOP_AT="2026-08-24 23:00"

log() { echo "$(date '+%F %T') $*" >> "$LOG"; }

now=$(date +%s)
stop=$(date -j -f "%Y-%m-%d %H:%M" "$STOP_AT" +%s 2>/dev/null)
if [ -n "${stop:-}" ] && [ "$now" -ge "$stop" ]; then
  log "STOP: past $STOP_AT — unloading $LABEL"
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null
  exit 0
fi

# Single-flight. A full iteration (analyze + 565 tests + two web builds +
# four deploys) can run past the hour, and overlapping runs would fight
# over the same git index.
if ! mkdir "$LOCK" 2>/dev/null; then
  log "SKIP: previous iteration still running"
  exit 0
fi
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

cd "$REPO" || { log "FATAL: cannot cd to $REPO"; exit 1; }

log "=== iteration start (repo $(git rev-parse --short HEAD 2>/dev/null)) ==="

# AUTH: a long-lived token from `claude setup-token`, valid a year.
#
# The interactive OAuth SESSION is the wrong credential for an
# unattended job: it expired overnight on the other loop and cost 5.5
# hours of ticks. Worse, `claude auth status` still reported
# loggedIn:true afterwards — it confirms a stored record exists, not
# that the token inside is valid. Do not trust it as a health check.
#
# The token bills against the Max subscription; an ANTHROPIC_API_KEY
# would be metered on top of it.
TOKEN_FILE="$HOME/.config/yswords/secrets/claude-oauth-token"
if [ ! -r "$TOKEN_FILE" ]; then
  log "FATAL: no token at $TOKEN_FILE — run: claude setup-token"
  exit 1
fi

# MODEL: ~/.claude/settings.json points ANTHROPIC_BASE_URL at api.z.ai
# and pins haiku/sonnet/opus to GLM, so `--model opus` alone still
# resolves to GLM. The environment has to be replaced at the process
# level and the model named in full.
env -u ANTHROPIC_AUTH_TOKEN \
  CLAUDE_CODE_OAUTH_TOKEN="$(cat "$TOKEN_FILE")" \
  ANTHROPIC_BASE_URL="https://api.anthropic.com" \
  ANTHROPIC_DEFAULT_OPUS_MODEL="claude-opus-5" \
  API_TIMEOUT_MS="3000000" \
  claude -p "$(cat "$DIR/prompt.md")" \
  --model claude-opus-5 \
  --permission-mode bypassPermissions \
  --add-dir "$REPO" \
  >> "$LOG" 2>&1 &
cpid=$!

# WATCHDOG. A run on the other loop wedged for 2h07 with its claude
# child already dead — the shell sat in `wait` forever. launchd's
# StartInterval does NOT stack: while one instance is "running" every
# tick is silently skipped, so a single hang costs the whole night
# rather than one cycle. There is no `timeout`/`gtimeout` on this
# machine (no coreutils), so poll instead.
#
# 45 minutes on an hourly interval: long enough for analyze + the full
# suite + two web builds + four deploys, short enough that a hang costs
# one cycle and not the next one too. Killing honest work mid-commit is
# worse than waiting, which is why this is not tighter.
MAX_RUN=2700
waited=0
while kill -0 "$cpid" 2>/dev/null && [ "$waited" -lt "$MAX_RUN" ]; do
  sleep 10
  waited=$((waited + 10))
done
if kill -0 "$cpid" 2>/dev/null; then
  log "WATCHDOG: run exceeded ${MAX_RUN}s — killing $cpid"
  kill -TERM "$cpid" 2>/dev/null; sleep 5
  kill -KILL "$cpid" 2>/dev/null
  wait "$cpid" 2>/dev/null
  log "=== iteration KILLED after ${MAX_RUN}s ==="
  exit 0
fi
wait "$cpid" 2>/dev/null
rc=$?

log "=== iteration end rc=$rc (repo $(git rev-parse --short HEAD 2>/dev/null)) ==="

# Keep the log from growing without bound over two weeks of hourly runs.
if [ -f "$LOG" ] && [ "$(wc -c < "$LOG")" -gt 20000000 ]; then
  tail -c 5000000 "$LOG" > "$LOG.trim" && mv "$LOG.trim" "$LOG"
  log "(log trimmed)"
fi
