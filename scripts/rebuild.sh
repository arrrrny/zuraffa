#!/bin/bash

# Rebuild and reinstall ZFA MCP server
# This script clears the cached snapshots, reactivates the package,
# and creates wrapper scripts that bypass the noisy pub global run

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(dirname "$SCRIPT_DIR")"
PUB_BIN="$HOME/.pub-cache/bin"

echo "🔄 Rebuilding ZFA..."

# Deactivate if currently active
echo "📦 Deactivating current installation..."
dart pub global deactivate zuraffa 2>/dev/null || true

# Clear the global package cache for this package
CACHE_DIR="$HOME/.pub-cache/global_packages/zuraffa"
if [ -d "$CACHE_DIR" ]; then
    echo "🗑️  Clearing global package cache..."
    rm -rf "$CACHE_DIR"
fi

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

# Create the pub bin directory if it doesn't exist
mkdir -p "$PUB_BIN"

# Remove existing binaries to prevent UTF-8 decode errors during activation
rm -f "$PUB_BIN/zfa" "$PUB_BIN/zuraffa_mcp_server" 2>/dev/null || true

# Activate the package globally
echo "🌍 Activating package globally..."
dart pub global activate --source=path .

# Compile binaries to AOT executables
# We attempt dart build cli first as it's the official way to handle projects with build hooks.
# If it fails, we fall back to dart compile exe which is more direct.
echo "🔨 Compiling zfa CLI to executable..."
mkdir -p "$PACKAGE_DIR/build"

if dart build cli --target=bin/zfa.dart -o "$PACKAGE_DIR/build/zfa_bundle"; then
    cp "$PACKAGE_DIR/build/zfa_bundle/bundle/bin/zfa" "$PUB_BIN/zfa"
else
    echo "  ⚠️  dart build cli failed, attempting dart compile exe..."
    dart compile exe bin/zfa.dart -o "$PUB_BIN/zfa"
fi

echo "🔨 Compiling zuraffa_mcp_server to executable..."
if dart build cli --target=bin/zuraffa_mcp_server.dart -o "$PACKAGE_DIR/build/mcp_server_bundle"; then
    cp "$PACKAGE_DIR/build/mcp_server_bundle/bundle/bin/zuraffa_mcp_server" "$PUB_BIN/zuraffa_mcp_server"
else
    echo "  ⚠️  dart build cli failed, attempting dart compile exe..."
    dart compile exe bin/zuraffa_mcp_server.dart -o "$PUB_BIN/zuraffa_mcp_server"
fi

echo "📝 Ensuring permissions for binaries..."
chmod +x "$PUB_BIN/zfa" 2>/dev/null || true
chmod +x "$PUB_BIN/zuraffa" 2>/dev/null || true
chmod +x "$PUB_BIN/zuraffa_mcp_server" 2>/dev/null || true

echo ""
echo "✅ Rebuild complete!"
echo ""
echo "Installed executables:"
echo "  • zfa"
echo "  • zuraffa_mcp_server"
echo ""
echo "To verify:"
echo "  zfa --version"
echo "  zfa generate --help"
echo "  zfa schema"
