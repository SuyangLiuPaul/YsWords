# The autonomous iteration loop

An hourly `launchd` job that works through `docs/autonomous-queue.md`,
one item per tick, for two weeks.

## Why launchd and not an in-session scheduler

A Claude cron job created inside a conversation lives in the app's
memory and needs a running REPL — it never fires once the conversation
goes quiet. That is the failure this replaces. `launchd` survives the
app closing and restarts at login, which is what "run every hour"
actually requires.

## Live locations

The files here are the versioned copy. The ones launchd actually runs:

| | |
|---|---|
| runner | `~/Library/Application Support/yswords-loop/run.sh` |
| brief | `~/Library/Application Support/yswords-loop/prompt.md` |
| transcript | `~/Library/Application Support/yswords-loop/run.log` |
| job | `~/Library/LaunchAgents/com.yswords.accuracyloop.plist` |
| **queue** | **`docs/autonomous-queue.md` — in this repo, so progress is in `git log`** |

Copy a change here back to the live path, or it does nothing.

## Controls

```bash
# stop it now
launchctl bootout gui/$(id -u)/com.yswords.accuracyloop

# start it again
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.yswords.accuracyloop.plist

# is it registered, and has it run?
launchctl print gui/$(id -u)/com.yswords.accuracyloop | grep -E 'state|runs'

# what has it been doing
tail -100 ~/Library/"Application Support"/yswords-loop/run.log
```

It also stops itself: `STOP_AT` in `run.sh` is a dead-man switch, read
fresh each tick, and the job unloads itself once past it. Set it to a
past date to end the loop at the next tick without touching launchctl.

## Things that already went wrong once

* **The interactive OAuth session is the wrong credential.** It expired
  overnight and cost 5.5 hours of ticks, and `claude auth status` still
  said `loggedIn:true` afterwards — it confirms a stored record exists,
  not that the token works. Use a `claude setup-token` token and probe
  with a real call before trusting it.
* **launchd hands over a near-empty environment.** PATH is pinned in
  `run.sh`; Flutter in particular is not on the default PATH here.
* **`StartInterval` does not stack.** While one instance runs, every
  tick is skipped — so one hung run costs the whole night, not one
  cycle. Hence the watchdog: there is no `timeout` on this machine, so
  it polls and kills at 45 minutes.
* **The model alias resolves to GLM.** `~/.claude/settings.json` points
  `ANTHROPIC_BASE_URL` at api.z.ai and pins every alias, so `--model
  opus` alone is not enough; the environment is replaced per process
  and the model named in full.
