#!/usr/bin/env bash
# ==============================================================
# r.sh — Remote shell executor for Zuzu sandbox via MCP
# Usage:
#   r.sh <command>                 Run command, print stdout+stderr
#   r.sh -d <dir> <command>        Run command in <dir> (cwd)
#   r.sh -t <secs> <command>       Run command with timeout (default 120)
#   r.sh -s <file>                 Read remote file
#   r.sh -w <file> <content>       Write remote file
#   r.sh -l <dir>                  List remote directory
#   r.sh --tools                   List all MCP tools + their args
#   r.sh --check                   Health check
#   r.sh --ship [--dry-run] <repo-dir> <branch> "title" [issue] [body]
#                                  ONE-COMMAND commit+push+PR (inside sandbox)
# Exit: 0=ok, 1=remote fail, 2=net/auth error, 254=CF block
# ==============================================================
set -euo pipefail

SID="a2674551-b576-4a82-bd86-5c28a844ee2e"
AK="dtn_87a079877a3a9d6e172eb0bf531c3e76ec73f54767c8df7d9894668b5cf0f8e4"
URL="https://proxy.zuzu.dev/toolbox/${SID}/mcp"
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.0"

die() { echo "r.sh: $*" >&2; exit 255; }

cf_check() {
  [[ "$1" == "<!doctype html"* || "$1" == "<!DOCTYPE html"* || "$1" == "<html"* ]] \
    && { echo "r.sh: Cloudflare block detected" >&2; exit 254; } || true
}

auth_check() {
  if echo "$1" | grep -q '^data: {'; then
    if echo "$1" | python3 -c '
import json, sys, re
raw = sys.stdin.read()
m = re.search(r"^data: (\{.*\})$", raw, re.M)
if m:
    obj = json.loads(m.group(1))
    if "error" in obj:
        sys.exit(0)
    sys.exit(1)
' 2>/dev/null; then
      echo "r.sh: Auth failed (401). Key expired." >&2
      exit 2
    fi
  fi
  return 0
}

parse_sse() {
  local raw="$1"
  cf_check "$raw"
  auth_check "$raw"
  local data_line
  data_line=$(echo "$raw" | grep -E '^data: \{' | head -1 | sed 's/^data: //')
  [[ -z "$data_line" ]] && { echo "r.sh: No JSON in MCP response" >&2; exit 2; }
  echo "$data_line"
}

extract_output() {
  python3 -c '
import json, sys
try:
    obj = json.loads(sys.stdin.read())
    content = obj.get("result", {}).get("content", [])
    if not content:
        print("r.sh: empty content", file=sys.stderr)
        sys.exit(2)
    text = content[0].get("text", "")
    lines = text.rstrip("\n").split("\n")
    if lines and lines[-1].startswith("exitCode:"):
        code = int(lines[-1].split(":")[1].strip())
        lines = lines[:-1]
    else:
        code = 0
    output = "\n".join(lines)
    if output:
        print(output)
    sys.exit(code if code != 0 else 0)
except Exception as e:
    print(f"r.sh: {e}", file=sys.stderr)
    sys.exit(2)
' <<< "$1"
}

mcp_exec() {
  local cmd="$1" cwd="$2" timeout="$3"
  # Auto-load PATH/dart/flutter/GITHUB_TOKEN for the non-interactive MCP shell
  # and ensure /workspace tools (sgh, gitpatch, ship.sh, upload.sh) are on PATH
  cmd="source ~/.bash_env 2>/dev/null; export PATH=/workspace:\$PATH; $cmd"
  local args_json
  if [[ -n "$cwd" ]]; then
    args_json=$(python3 -c 'import json,sys; c=sys.argv[1]; d=sys.argv[2]; t=int(sys.argv[3]); print(json.dumps({"command":c,"cwd":d,"timeout":t}))' "$cmd" "$cwd" "$timeout")
  else
    args_json=$(python3 -c 'import json,sys; c=sys.argv[1]; t=int(sys.argv[2]); print(json.dumps({"command":c,"timeout":t}))' "$cmd" "$timeout")
  fi
  local response
  response=$(curl -s --max-time $((timeout + 15)) -X POST "$URL" \
    -A "$UA" \
    -H "Authorization: Bearer $AK" \
    -H "Content-Type: application/json" \
    -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"exec_command\",\"arguments\":$args_json}}")
  local data
  data=$(parse_sse "$response")
  extract_output "$data"
}

mcp_read() {
  local filepath="$1"
  local response
  response=$(curl -s --max-time 30 -X POST "$URL" \
    -A "$UA" \
    -H "Authorization: Bearer $AK" \
    -H "Content-Type: application/json" \
    -d "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"fs_read_file\",\"arguments\":{\"path\":$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$filepath")}}}")
  local data
  data=$(parse_sse "$response")
  python3 -c '
import json, sys
obj = json.loads(sys.stdin.read())
content = obj.get("result", {}).get("content", [])
if content:
    print(content[0].get("text", ""), end="")
else:
    sys.exit(2)
' <<< "$data"
}

mcp_write() {
  local filepath="$1"
  local content="$2"
  local response
  response=$(curl -s --max-time 30 -X POST "$URL" \
    -A "$UA" \
    -H "Authorization: Bearer $AK" \
    -H "Content-Type: application/json" \
    -d "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/call\",\"params\":{\"name\":\"fs_write_file\",\"arguments\":{\"path\":$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$filepath"),\"content\":$(python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' <<< "$content")}}}")
  local data
  data=$(parse_sse "$response")
  echo "Written to $filepath"
}

mcp_list() {
  local dirpath="$1"
  local response
  response=$(curl -s --max-time 30 -X POST "$URL" \
    -A "$UA" \
    -H "Authorization: Bearer $AK" \
    -H "Content-Type: application/json" \
    -d "{\"jsonrpc\":\"2.0\",\"id\":4,\"method\":\"tools/call\",\"params\":{\"name\":\"fs_list_files\",\"arguments\":{\"path\":$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$dirpath")}}}")
  local data
  data=$(parse_sse "$response")
  python3 -c '
import json, sys
obj = json.loads(sys.stdin.read())
content = obj.get("result", {}).get("content", [])
if content:
    print(content[0].get("text", ""))
' <<< "$data"
}

if [[ $# -eq 0 ]]; then
  die "Usage: r.sh <cmd> | r.sh -s <file> | r.sh -w <file> <content> | r.sh -l <dir> | r.sh --check"
fi

case "$1" in
  --check)
    echo -n "MCP: "
    resp=$(curl -s --max-time 10 -X POST "$URL" \
      -A "$UA" -H "Authorization: Bearer $AK" -H "Content-Type: application/json" \
      -d '{"jsonrpc":"2.0","id":0,"method":"tools/list"}')
    cf_check "$resp"
    auth_check "$resp"
    echo "$resp" | grep -q '"tools"' && echo "OK" || { echo "FAIL"; exit 2; }
    ;;
  --tools)
    resp=$(curl -s --max-time 10 -X POST "$URL" \
      -A "$UA" -H "Authorization: Bearer $AK" -H "Content-Type: application/json" \
      -d '{"jsonrpc":"2.0","id":0,"method":"tools/list"}')
    cf_check "$resp"
    auth_check "$resp"
    data=$(parse_sse "$resp")
    python3 -c '
import json, sys
obj = json.loads(sys.stdin.read())
tools = obj.get("result", {}).get("tools", [])
print(str(len(tools)) + " MCP tools available:")
for t in tools:
    props = t.get("inputSchema", {}).get("properties", {})
    req = t.get("inputSchema", {}).get("required", [])
    parts = []
    for k in props:
        marker = "*" if k in req else ""
        parts.append(k + marker)
    print("  " + t["name"] + "(" + ", ".join(parts) + ")")
    print("      " + t.get("description", "")[:100])
' <<< "$data"
    ;;
  -d)
    [[ $# -lt 3 ]] && die "-d requires <dir> <command>"
    mcp_exec "${*:3}" "$2" "120"
    ;;
  -t)
    [[ $# -lt 3 ]] && die "-t requires <secs> <command>"
    mcp_exec "${*:3}" "" "$2"
    ;;
  -s)
    [[ $# -lt 2 ]] && die "-s requires file path"
    mcp_read "$2"
    ;;
  -w)
    [[ $# -lt 3 ]] && die "-w requires <file> <content>"
    mcp_write "$2" "$3"
    ;;
  -l)
    [[ $# -lt 2 ]] && die "-l requires dir path"
    mcp_list "$2"
    ;;
  --ship)
    # ONE command: git add/commit/push + gh pr create, run inside the sandbox
    # r.sh --ship [--dry-run] <repo-dir> <branch> "title" [issue] [body]
    [[ $# -lt 4 ]] && die "--ship requires [--dry-run] <repo-dir> <branch> \"title\" [issue] [body]"
    shift  # drop --ship
    remote_cmd=$(python3 -c '
import shlex, sys
args = sys.argv[1:]
print("bash /workspace/ship.sh " + " ".join(shlex.quote(a) for a in args))
' "$@")
    mcp_exec "$remote_cmd" "" "300"
    ;;
  -h|--help)
    sed -n '3,12p' "$0" | sed 's/^# //' | sed 's/^#//'
    ;;
  *)
    mcp_exec "$*" "" "120"
    ;;
esac
