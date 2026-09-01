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
echo "📥 Getting dependencies..."
dart pub get --no-example > /dev/null 2>&1
echo "  ✅ Dependencies resolved"
mkdir -p "$INSTALL_DIR"

# Compile zfa CLI — use dart build cli for build hooks support, suppress intermediate output
echo "🔨 Compiling zfa..."
rm -rf build/zfa_bundle
dart build cli --target=bin/zfa.dart -o build/zfa_bundle > /dev/null 2>&1
cp build/zfa_bundle/bundle/bin/zfa "$INSTALL_DIR/zfa"
chmod +x "$INSTALL_DIR/zfa" 2>/dev/null || true
echo "  ✅ $INSTALL_DIR/zfa"

# Compile zuraffa_mcp_server
echo "🔨 Compiling zuraffa_mcp_server..."
rm -rf build/mcp_server_bundle
dart build cli --target=bin/zuraffa_mcp_server.dart -o build/mcp_server_bundle > /dev/null 2>&1
cp build/mcp_server_bundle/bundle/bin/zuraffa_mcp_server "$INSTALL_DIR/zuraffa_mcp_server"
chmod +x "$INSTALL_DIR/zuraffa_mcp_server" 2>/dev/null || true
echo "  ✅ $INSTALL_DIR/zuraffa_mcp_server"

echo ""
echo "✅ Rebuild complete — installed to $INSTALL_DIR"
echo ""
echo "To verify:"
echo "  zfa --version"
