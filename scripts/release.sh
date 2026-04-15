#!/bin/bash

# Release script for zuraffa - creates a release with source, CLI binary, and MCP binary
# Uploads both tar.gz archives AND raw uncompressed binaries (for Zed extension).
# Usage: ./release.sh <version>
# Example: ./release.sh 4.0.2

set -e

VERSION="$1"

if [ -z "$VERSION" ]; then
    echo "❌ Version number is required"
    echo "Usage: $0 <version>"
    exit 1
fi

# Validate version format (simple check for X.Y.Z pattern)
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "❌ Invalid version format. Expected format: X.Y.Z (e.g., 4.0.2)"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PACKAGE_DIR"

echo "🚀 Creating release $VERSION for zuraffa..."
echo ""

# Step 1: Build MCP server and CLI binaries
echo "🔧 Building MCP server and CLI binaries..."
OUTPUT_DIR="build/release_$VERSION"
mkdir -p "$OUTPUT_DIR"

# Detect current platform — use "macos" not "darwin" to match Zed extension expectations
UNAME_OS=$(uname -s)
case "$UNAME_OS" in
    Darwin) OS_NAME="macos" ;;
    Linux)  OS_NAME="linux" ;;
    MINGW*|MSYS*|CYGWIN*) OS_NAME="windows" ;;
    *)      OS_NAME=$(echo "$UNAME_OS" | tr '[:upper:]' '[:lower:]') ;;
esac

ARCH_NAME=$(uname -m)
case "$ARCH_NAME" in
    x86_64|amd64) ARCH_NAME="x64" ;;
    arm64|aarch64) ARCH_NAME="arm64" ;;
esac

PLATFORM_TAG="${OS_NAME}-${ARCH_NAME}"
IS_WINDOWS=false
if [ "$OS_NAME" = "windows" ]; then IS_WINDOWS=true; fi

EXT=""
if [ "$IS_WINDOWS" = true ]; then EXT=".exe"; fi

echo "  Building for current platform: $PLATFORM_TAG..."

echo "  Building MCP server..."
dart build cli --target=bin/zuraffa_mcp_server.dart -o "$OUTPUT_DIR/mcp_server_bundle"

echo "  Building CLI..."
dart build cli --target=bin/zfa.dart -o "$OUTPUT_DIR/zfa_bundle"

echo "  ✓ MCP and CLI binaries built"

# Step 2: Extract raw binaries from bundles (for Zed extension — uncompressed)
echo "📋 Extracting raw binaries for Zed extension..."
MCP_RAW="$OUTPUT_DIR/zuraffa_mcp_server-${PLATFORM_TAG}${EXT}"
ZFA_RAW="$OUTPUT_DIR/zfa-${PLATFORM_TAG}${EXT}"

cp "$OUTPUT_DIR/mcp_server_bundle/bundle/bin/zuraffa_mcp_server${EXT}" "$MCP_RAW"
cp "$OUTPUT_DIR/zfa_bundle/bundle/bin/zfa${EXT}" "$ZFA_RAW"
chmod +x "$MCP_RAW" "$ZFA_RAW"

echo "  ✓ Raw binaries: $(basename "$MCP_RAW"), $(basename "$ZFA_RAW")"

# Step 3: Create source archive
echo "📦 Creating source archive..."
SOURCE_ARCHIVE="$OUTPUT_DIR/zuraffa-$VERSION-source.tar.gz"
tar -czf "$SOURCE_ARCHIVE" --exclude="build" --exclude=".git" --exclude="node_modules" .

echo "  ✓ Source archive created: $SOURCE_ARCHIVE"

# Step 4: Create platform-specific tar.gz archives (for manual download)
echo "📦 Creating platform-specific archives..."
MCP_ARCHIVE="$OUTPUT_DIR/zuraffa_mcp_server-${PLATFORM_TAG}-v${VERSION}.tar.gz"
ZFA_ARCHIVE="$OUTPUT_DIR/zfa-${PLATFORM_TAG}-v${VERSION}.tar.gz"

tar -czf "$MCP_ARCHIVE" -C "$OUTPUT_DIR/mcp_server_bundle" bundle
tar -czf "$ZFA_ARCHIVE" -C "$OUTPUT_DIR/zfa_bundle" bundle

echo "  ✓ Archives: $(basename "$MCP_ARCHIVE"), $(basename "$ZFA_ARCHIVE")"

# Step 5: Create GitHub release with ALL assets
if command -v gh &> /dev/null; then
    echo "📤 Creating GitHub release..."

    RELEASE_EXISTS=$(gh release view "v$VERSION" 2>/dev/null && echo "true" || echo "false")

    # Assets to upload:
    #   1. Raw uncompressed binaries  (for Zed extension — must match exact names)
    #   2. tar.gz archives            (for manual download / CI)
    #   3. Source archive
    UPLOAD_FILES=(
        "$MCP_RAW"
        "$ZFA_RAW"
        "$MCP_ARCHIVE"
        "$ZFA_ARCHIVE"
        "$SOURCE_ARCHIVE"
    )

    if [ "$RELEASE_EXISTS" = "false" ]; then
        echo "  Creating release v$VERSION..."
        gh release create "v$VERSION" \
            --title "v$VERSION" \
            --notes "Release $VERSION (built for $PLATFORM_TAG)" \
            "${UPLOAD_FILES[@]}"
    else
        echo "  Uploading to existing release v$VERSION..."
        gh release upload "v$VERSION" \
            "${UPLOAD_FILES[@]}" \
            --clobber
    fi
    echo "  ✓ GitHub release created/updated"
else
    echo "⚠️  GitHub CLI (gh) not found. Skipping GitHub release creation."
    echo "   Please create release manually and upload files from: $OUTPUT_DIR"
fi

echo ""
echo "✅ Successfully created release $VERSION for zuraffa!"
echo ""
echo "Release assets:"
echo "  Raw binaries (Zed):"
echo "    $(basename "$MCP_RAW")"
echo "    $(basename "$ZFA_RAW")"
echo "  Archives:"
echo "    $(basename "$MCP_ARCHIVE")"
echo "    $(basename "$ZFA_ARCHIVE")"
echo "    $(basename "$SOURCE_ARCHIVE")"
echo ""
echo "GitHub release: https://github.com/arrrrny/zuraffa/releases/tag/v$VERSION"
