# YsWords — release policy

**Effective 2026-05-11 (after v1.2.43 hit prod). Read this BEFORE any deploy.**

## Rule

| Tier | Permission |
|---|---|
| **dev** (`yswords-dev`, `yswords-cn-dev`) | ✅ Push freely as part of any change. |
| **qat** (`yswords-qat`, `yswords-cn-qat`) | ✅ Push freely once dev is verified. |
| **prod** (`yswords`, `yswords-cn`) | ❌ **NEVER push without explicit user instruction in the current turn.** |

## What "explicit instruction" means for prod

The user must say something unambiguous like:
- "push to prod"
- "ship to prod"
- "deploy to production"
- "ok prod"
- "go all the way" / "roll out everywhere"

Phrases that do **NOT** count as prod permission:
- "fix it" / "ship the fix" — assume **dev + qat only** unless prod is named
- "deploy" / "ship it" — assume **dev + qat only**
- "release" — does not imply prod unless the user names prod
- Prior turns' "push to prod" — permission does NOT carry over
- Implication from context (e.g. "users on prod are seeing X") — still requires explicit confirmation

If unsure, stop and ask: "Want me to push this to prod too, or hold at qat?"

## Standard workflow

**Preferred (post-v1.3.9):** the `tools/release_web.sh` wrapper
auto-bumps the patch version, stamps `APP_RELEASE_TIME` as UTC,
builds web, and deploys to all 4 dev/qat sites in parallel.

```bash
# 1. Make changes locally
flutter analyze && flutter test

# 2. Bump + build + deploy to dev + qat (one command)
NETLIFY_AUTH_TOKEN=nfp_xxx... bash tools/release_web.sh

# 3. Smoke test on https://yswords-dev.netlify.app +
#    https://yswords-qat.netlify.app

# 4. STOP. Ask user: "Push to prod?"
#    Only proceed to prod after explicit yes IN THE CURRENT TURN.
#    Use --no-bump so prod gets the SAME version dev/qat just verified.
NETLIFY_AUTH_TOKEN=nfp_xxx... bash tools/release_web.sh --no-bump --include-prod

# 5. Install on native devices (iOS / Android / macOS):
zsh tools/yswords-ios-reinstall.sh
```

**Legacy (still works):**

```bash
python3 tools/build_web.py
python3 tools/deploy_site.py --tier dev
python3 tools/deploy_site.py --tier qat
python3 tools/deploy_site.py --tier prod   # ← gated on explicit user instruction
```

## Rationale

Prod is `yswords.netlify.app` + `yswords-cn.netlify.app` — the URLs real users have bookmarked / installed as PWAs. Bad pushes here:
- Affect users immediately (no review window)
- Can break their device install / saved state
- Erode trust if the user's friends/family hit issues

dev and qat exist precisely so changes can be tested under real conditions before prod sees them. Using them is free; skipping them risks user-facing regressions.

## Exceptions

The only time prod can be pushed without prior asking IN THE SAME TURN is when the user has just issued a clear prod instruction in the current conversation turn (see "What 'explicit instruction' means" above).

A truly critical hotfix (security, data corruption, total breakage on prod) still requires the user to greenlight it — the answer to "what about emergencies" is "tell me, then I'll do it."

## Where this lives

- This file: `docs/release-policy.md` (canonical).
- HANDOFF.md banner: short pointer to this file.
- `~/.claude/projects/.../memory/MEMORY.md`: suggest adding a one-liner reminder so the policy survives session resets — see "Suggested MEMORY.md entry" below.

## Suggested MEMORY.md entry

```
- [Release policy](release_policy.md) — dev + qat fine to push as
  part of any change; **prod requires explicit user instruction
  in the current turn**, never carry-over. Workflow: build_web.py
  → deploy_site.py --tier dev → --tier qat → STOP + ask.
```
