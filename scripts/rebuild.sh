#!/bin/bash

# Rebuild and reinstall ZFA MCP server
# Compiles executables to ~/.local/bin/
# Never touches ~/.pub-cache/ — native binaries there crash pub.

set -e

INSTALL_DIR="${ZURAFFA_BIN:-$HOME/.local/bin}"

echo "🔄 Rebuilding ZFA..."

# Clear ALL build caches so the installed binary always reflects current source.
# A partial cleanup (only .dart_tool/build_cache, hooks_runner, pub/bin) left a stale
# dart build cli artifact in place, causing zfa to run pre-fix code after a source
# change — see .specify/bugs/rebuild-stale-binary.
rm -rf build .dart_tool

# Get dependencies.
# --no-example skips the nested `example/` Flutter app so `dart pub get`
# doesn't fail with "the Flutter SDK is not available" when only the Dart
# SDK is on PATH. The example app is a sibling demo, not a build dep.
# stderr is captured and only printed on failure — the previous `> /dev/null
# 2>&1` swallowed the real error and made the script silently hang.
echo "📥 Getting dependencies..."
PUB_STDERR=$(mktemp)
if ! dart pub get --no-example > /dev/null 2> "$PUB_STDERR"; then
  echo "  ❌ dart pub get failed:" >&2
  cat "$PUB_STDERR" >&2
  rm -f "$PUB_STDERR"
  exit 1
fi
rm -f "$PUB_STDERR"
echo "  ✅ Dependencies resolved"
mkdir -p "$INSTALL_DIR"

# Compile zfa CLI — use dart build cli for build hooks support. stderr is
# captured and only printed on failure so the success path stays terse.
echo "🔨 Compiling zfa..."
rm -rf build/zfa_bundle
ZFA_STDERR=$(mktemp)
if ! dart build cli --target=bin/zfa.dart -o build/zfa_bundle > /dev/null 2> "$ZFA_STDERR"; then
  echo "  ❌ zfa compile failed:" >&2
  cat "$ZFA_STDERR" >&2
  rm -f "$ZFA_STDERR"
  exit 1
fi
rm -f "$ZFA_STDERR"
cp build/zfa_bundle/bundle/bin/zfa "$INSTALL_DIR/zfa"
chmod +x "$INSTALL_DIR/zfa" 2>/dev/null || true
echo "  ✅ $INSTALL_DIR/zfa"

# Record the source commit this binary was built from (issue #1184). The
# installed CLI reads $INSTALL_DIR/zfa.build_commit at startup and warns —
# "⚠️ installed zfa (<commit>) is older than this checkout (<commit>) — run
# scripts/rebuild.sh" — when run inside a zuraffa worktree whose HEAD
# differs from the recorded commit. No marker (pre-#1184 install) means the
# CLI stays silent: staleness is unprovable without it.
if BUILD_COMMIT=$(git rev-parse HEAD 2>/dev/null); then
  printf '%s\n' "$BUILD_COMMIT" > "$INSTALL_DIR/zfa.build_commit"
  printf '%s\n' "$BUILD_COMMIT" > build/zfa_bundle/bundle/bin/zfa.build_commit
  echo "  ✅ recorded build commit ${BUILD_COMMIT:0:12} (zfa.build_commit)"
else
  rm -f "$INSTALL_DIR/zfa.build_commit"
  echo "  ⚠️ not a git checkout — no build commit recorded (staleness warning disabled)"
fi

# Compile zuraffa_mcp_server — same error-surfacing pattern.
echo "🔨 Compiling zuraffa_mcp_server..."
rm -rf build/mcp_server_bundle
MCP_STDERR=$(mktemp)
if ! dart build cli --target=bin/zuraffa_mcp_server.dart -o build/mcp_server_bundle > /dev/null 2> "$MCP_STDERR"; then
  echo "  ❌ mcp compile failed:" >&2
  cat "$MCP_STDERR" >&2
  rm -f "$MCP_STDERR"
  exit 1
fi
rm -f "$MCP_STDERR"
cp build/mcp_server_bundle/bundle/bin/zuraffa_mcp_server "$INSTALL_DIR/zuraffa_mcp_server"
chmod +x "$INSTALL_DIR/zuraffa_mcp_server" 2>/dev/null || true
echo "  ✅ $INSTALL_DIR/zuraffa_mcp_server"

echo ""
echo "✅ Rebuild complete — installed to $INSTALL_DIR"
echo ""
echo "To verify:"
echo "  zfa --version"
