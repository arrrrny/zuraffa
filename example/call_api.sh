#!/bin/bash
# Quick helper: call a Zuraffa API extension on a running app.
#
# Usage:
#   ./call_api.sh <vm-service-http-uri> <method> [args-json]
#
# Example:
#   ./call_api.sh http://127.0.0.1:12345/XXX=/ ext.zuraffa.todo.getTodoList
#   ./call_api.sh http://127.0.0.1:12345/XXX=/ ext.zuraffa.todo.createTodo '{"title":"hello","isCompleted":false}'
#
# Requires: python3, websockets (pip3 install --break-system-packages websockets)

set -euo pipefail

HTTP_URI="${1:-}"
METHOD="${2:-ext.zuraffa._list}"
ARGS="${3:-}"

if [ -z "$HTTP_URI" ]; then
  echo "Usage: $0 <http-uri> [method] [args-json]"
  echo "Example: $0 http://127.0.0.1:12345/XXX=/ ext.zuraffa.todo.getTodoList"
  exit 1
fi

# Convert http://... to ws://...
WS_URI=$(echo "$HTTP_URI" | sed 's|^http|ws|')ws
echo "→ WebSocket: $WS_URI"
echo "→ Method:    $METHOD"
echo "→ Args:      ${ARGS:-none}"
echo ""

# Extract isolate ID
ISOLATE_ID=$(curl -s "${HTTP_URI}getVM" | python3 -c "
import json,sys
d=json.load(sys.stdin)
for i in d['result']['isolates']:
    if not i['isSystemIsolate']:
        print(i['id'])
        break
" 2>/dev/null)

if [ -z "$ISOLATE_ID" ]; then
  echo "❌ Could not find main isolate. Is the app running?"
  exit 1
fi

echo "→ Isolate:   $ISOLATE_ID"

# Build the Python call snippet
python3 << PYEOF
import json, asyncio, websockets

async def main():
    uri = '${WS_URI}'
    iso = '${ISOLATE_ID}'
    method = '${METHOD}'
    args_val = '${ARGS}'

    params = {'isolateId': iso}
    if args_val:
        params['args'] = args_val

    msg = {
        'jsonrpc': '2.0',
        'method': method,
        'params': params,
        'id': '1'
    }

    async with websockets.connect(uri) as ws:
        await ws.send(json.dumps(msg))
        resp = await asyncio.wait_for(ws.recv(), timeout=10)
        parsed = json.loads(resp)
        print("")
        print("┌" + "─" * 58 + "┐")
        print("│ " + method.ljust(56) + " │")
        print("├" + "─" * 58 + "┤")
        formatted = json.dumps(parsed.get('result', parsed), indent=2)
        for line in formatted.split('\n'):
            print("│ " + line[:56].ljust(56) + " │")
        print("└" + "─" * 58 + "┘")

asyncio.run(main())
PYEOF
