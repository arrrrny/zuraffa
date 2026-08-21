#!/usr/bin/env bash
# ==============================================================
# gen_token.sh — Generate a fresh 24h SSH/WSS token on demand
#
# The SSH token for WSS (r2.sh) is time-limited (default 24h).
# Instead of guessing or asking the delegator mid-session, run this
# tool — it uses the non-expiring API key to mint a fresh token
# and saves it to ~/.r2_token so r2.sh picks it up automatically.
#
# Usage:
#   bash /workspace/gen_token.sh            # generate + print + save
#   bash /workspace/gen_token.sh --quiet    # save only, print nothing
#   bash /workspace/gen_token.sh --minutes 360   # custom expiry
#
# Call it via MCP exec_command or r.sh:
#   ./r.sh "bash /workspace/gen_token.sh"
#   ./r2.sh "bash /workspace/gen_token.sh"
# ==============================================================
set -euo pipefail

SID="a2674551-b576-4a82-bd86-5c28a844ee2e"
API_KEY="dtn_87a079877a3a9d6e172eb0bf531c3e76ec73f54767c8df7d9894668b5cf0f8e4"
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.0"

MINUTES=1440   # default 24h
QUIET=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --quiet) QUIET=1; shift ;;
    --minutes) MINUTES="${2:-1440}"; shift 2 ;;
    -h|--help)
      sed -n '4,20p' "$0" | sed 's/^# //'; exit 0 ;;
    *) echo "gen_token: unknown arg: $1" >&2; exit 2 ;;
  esac
done

# Mint a fresh token via the Daytona API
RESP=$(curl -s -X POST "https://daytona.zuzu.dev/api/sandbox/$SID/ssh-access?expiresInMinutes=$MINUTES" \
  -A "$UA" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" 2>&1)

TOKEN=$(echo "$RESP" | python3 -c 'import json,sys
try:
    d=json.load(sys.stdin)
    print(d.get("token",""))
except: print("")' 2>/dev/null || echo "")

if [[ -z "$TOKEN" ]]; then
  echo "gen_token: FAILED to generate token. Response: $(echo "$RESP" | head -c 200)" >&2
  exit 1
fi

# Save it so r2.sh auto-picks it up
echo "$TOKEN" > ~/.r2_token
chmod 600 ~/.r2_token

if [[ "$QUIET" -eq 0 ]]; then
  echo "FRESH_TOKEN=$TOKEN"
  echo "SAVED_TO=~/.r2_token"
  echo "EXPIRES_MINUTES=$MINUTES"
  echo "USAGE: r2.sh now works — run: ./r2.sh \"echo hello\""
fi

exit 0
