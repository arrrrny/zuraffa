#!/bin/bash

# Rebuild and reinstall ZFA MCP server
# Compiles executables to ~/.local/bin/
# Never touches ~/.pub-cache/ — native binaries there crash pub.

set -e

INSTALL_DIR="${ZURAFFA_BIN:-$HOME/.local/bin}"

echo "🔄 Rebuilding ZFA..."

# Clear .dart_tool build artifacts
rm -rf .dart_tool/pub/bin
rm -rf .dart_tool/build_cache
rm -rf .dart_tool/hooks_runner
find .dart_tool -type f \( -name "*.dill" -o -name "*.snap" \) -delete 2>/dev/null || true

# Get dependencies
echo "📥 Getting dependencies..."
dart pub get > /dev/null 2>&1
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
