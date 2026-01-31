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

# Clear build cache
BUILD_CACHE="$PACKAGE_DIR/.dart_tool/build_cache"
if [ -d "$BUILD_CACHE" ]; then
    echo "🗑️  Clearing build cache..."
    rm -rf "$BUILD_CACHE"
fi

# Clear any .dill and .snap files in .dart_tool
find "$PACKAGE_DIR/.dart_tool" -type f \( -name "*.dill" -o -name "*.snap" \) -delete 2>/dev/null || true

# Get dependencies
echo "📥 Getting dependencies..."
cd "$PACKAGE_DIR"
dart pub get

# Compile MCP server to executable
echo "🔨 Compiling zuraffa_mcp_server to executable..."
mkdir -p "$PACKAGE_DIR/build"
dart compile exe bin/zuraffa_mcp_server.dart -o "$PACKAGE_DIR/build/zuraffa_mcp_server"

# Create the pub bin directory if it doesn't exist
mkdir -p "$PUB_BIN"

# Activate the package globally so it persists across IDE restarts
echo "🌍 Activating package globally..."
cd "$PACKAGE_DIR"
dart pub global activate --source=path .

# Now create our custom wrappers (after activation to override pub's wrappers)
echo "📝 Creating custom wrapper scripts..."

# Create zfa wrapper (uses dart run for flexibility)
cat > "$PUB_BIN/zfa" << 'WRAPPER_EOF'
#!/usr/bin/env bash
# ZFA CLI wrapper - runs dart directly to avoid pub noise
exec dart run "PACKAGE_DIR_PLACEHOLDER/bin/zfa.dart" "$@"
WRAPPER_EOF

# Replace placeholder with actual path
sed -i.bak "s|PACKAGE_DIR_PLACEHOLDER|$PACKAGE_DIR|g" "$PUB_BIN/zfa"
rm -f "$PUB_BIN/zfa.bak"
chmod +x "$PUB_BIN/zfa"

# Create zuraffa_mcp_server wrapper (uses dart run for better compatibility)
cat > "$PUB_BIN/zuraffa_mcp_server" << 'WRAPPER_EOF'
#!/usr/bin/env bash
# ZFA MCP Server wrapper - uses dart run for compatibility
exec dart run "PACKAGE_DIR_PLACEHOLDER/bin/zuraffa_mcp_server.dart" "$@"
WRAPPER_EOF

# Replace placeholder with actual path
sed -i.bak "s|PACKAGE_DIR_PLACEHOLDER|$PACKAGE_DIR|g" "$PUB_BIN/zuraffa_mcp_server"
rm -f "$PUB_BIN/zuraffa_mcp_server.bak"
chmod +x "$PUB_BIN/zuraffa_mcp_server"

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
