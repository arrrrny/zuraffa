#!/bin/bash

# Rebuild and reinstall ZFA MCP server
# This script compiles executables directly to ~/.local/bin/
# Never touches ~/.pub-cache/ — native binaries there crash pub.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(dirname "$SCRIPT_DIR")"
INSTALL_DIR="${ZURAFFA_BIN:-$HOME/.local/bin}"

echo "🔄 Rebuilding ZFA..."

# Clear the .dart_tool snapshots (this is where JIT snapshots are cached)
SNAPSHOT_DIR="$PACKAGE_DIR/.dart_tool/pub/bin/zuraffa"
if [ -d "$SNAPSHOT_DIR" ]; then
    echo "🗑️  Clearing JIT snapshots..."
    rm -rf "$SNAPSHOT_DIR"
fi

# Also clear any other cached bin snapshots
DART_TOOL_BIN="$PACKAGE_DIR/.dart_tool/pub/bin"
if [ -d "$DART_TOOL_BIN" ]; then
    echo "🗑️  Clearing all bin snapshots..."
    rm -rf "$DART_TOOL_BIN"
fi

# Clear build cache and hooks runner
BUILD_CACHE="$PACKAGE_DIR/.dart_tool/build_cache"
HOOKS_RUNNER="$PACKAGE_DIR/.dart_tool/hooks_runner"
if [ -d "$BUILD_CACHE" ]; then
    echo "🗑️  Clearing build cache..."
    rm -rf "$BUILD_CACHE"
fi
if [ -d "$HOOKS_RUNNER" ]; then
    echo "🗑️  Clearing hooks runner..."
    rm -rf "$HOOKS_RUNNER"
fi

# Clear any .dill and .snap files in .dart_tool
find "$PACKAGE_DIR/.dart_tool" -type f \( -name "*.dill" -o -name "*.snap" \) -delete 2>/dev/null || true

# Get dependencies
echo "📥 Getting dependencies..."
cd "$PACKAGE_DIR"
dart pub get

# Ensure install directory exists
mkdir -p "$INSTALL_DIR"

# Remove existing binaries to prevent stale versions
rm -f "$INSTALL_DIR/zfa" "$INSTALL_DIR/zuraffa_mcp_server" 2>/dev/null || true

# Compile binaries to AOT executables directly into ~/.local/bin/
# We attempt dart build cli first as it's the official way to handle projects with build hooks.
# If it fails, we fall back to dart compile exe which is more direct.
# NOTE: We skip dart pub global activate entirely — everything is loaded from ~/.local/bin/.
echo "🔨 Compiling zfa CLI to executable..."
mkdir -p "$PACKAGE_DIR/build"

if dart build cli --target=bin/zfa.dart -o "$PACKAGE_DIR/build/zfa_bundle"; then
    cp "$PACKAGE_DIR/build/zfa_bundle/bundle/bin/zfa" "$INSTALL_DIR/zfa"
else
    echo "  ⚠️  dart build cli failed, attempting dart compile exe..."
    dart compile exe bin/zfa.dart -o "$INSTALL_DIR/zfa"
fi

echo "🔨 Compiling zuraffa_mcp_server to executable..."
if dart build cli --target=bin/zuraffa_mcp_server.dart -o "$PACKAGE_DIR/build/mcp_server_bundle"; then
    cp "$PACKAGE_DIR/build/mcp_server_bundle/bundle/bin/zuraffa_mcp_server" "$INSTALL_DIR/zuraffa_mcp_server"
else
    echo "  ⚠️  dart build cli failed, attempting dart compile exe..."
    dart compile exe bin/zuraffa_mcp_server.dart -o "$INSTALL_DIR/zuraffa_mcp_server"
fi

echo "📝 Ensuring permissions for binaries..."
chmod +x "$INSTALL_DIR/zfa" 2>/dev/null || true
chmod +x "$INSTALL_DIR/zuraffa_mcp_server" 2>/dev/null || true

echo ""
echo "✅ Rebuild complete!"
echo ""
echo "Installed executables (run directly from PATH via ~/.local/bin/):"
echo "  • zfa"
echo "  • zuraffa_mcp_server"
echo ""
echo "To verify:"
echo "  zfa --version"
echo "  zfa generate --help"
echo "  zfa schema"
