#!/bin/bash
# Are the church media hosts reachable from THIS machine right now?
#
# Exists so the work that depends on them is picked up automatically the
# moment it becomes possible, instead of waiting for someone to remember
# to try. Costs a few seconds; run it before any queue item that needs
# one of these hosts.
#
# 2026-08-11: two of the four are unreachable from the maintainer's Mac
# — it is a managed device (GlobalProtect + CrowdStrike Falcon + Jamf)
# and a macOS Network Extension filters at the socket layer, so DNS and
# routing look perfectly clean while no SYN is ever answered. That is
# the employer's policy on their own hardware; it is NOT to be worked
# around. This script only reports, so the answer can change by itself
# when the work is run somewhere else.
#
# Exit 0 if every host answers, 1 otherwise. Names the failures either
# way, so a caller can decide per host rather than all-or-nothing.

set -uo pipefail

HOSTS=(
  "fydt.org"                          # 578 songs
  "www.christiandiscipleschurch.org"  # 402 songs + the 124 Matthew sermons
  "cgdc.hk"                           # 63 songs
  "cahayapengharapan.org"             # 25 songs
)

TIMEOUT="${MEDIA_HOST_TIMEOUT:-12}"
failed=0

for h in "${HOSTS[@]}"; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time "$TIMEOUT" \
    "https://$h/" 2>/dev/null)
  # 000 means no HTTP response at all — usually no TCP connection.
  # Any real status counts as reachable: a 403 or 404 still proves the
  # packets arrive, which is what the queue items actually need.
  if [ "$code" = "000" ]; then
    echo "UNREACHABLE  $h"
    failed=1
  else
    echo "ok ($code)     $h"
  fi
done

exit "$failed"
