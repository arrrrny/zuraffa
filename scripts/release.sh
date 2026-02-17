#!/bin/bash

# Release script for zuraffa - creates a release with source, CLI binary, and MCP binary
# Usage: ./release.sh <version>
# Example: ./release.sh 3.15.0

set -e

VERSION="$1"

if [ -z "$VERSION" ]; then
    echo "❌ Version number is required"
    echo "Usage: $0 <version>"
    exit 1
fi

# Validate version format (simple check for X.Y.Z pattern)
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "❌ Invalid version format. Expected format: X.Y.Z (e.g., 3.15.0)"
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

echo "  Building MCP server for macOS ARM64..."
dart compile exe bin/zuraffa_mcp_server.dart -o "$OUTPUT_DIR/zuraffa_mcp_server-macos-arm64"

echo "  Building MCP server for macOS x64..."
dart compile exe bin/zuraffa_mcp_server.dart -o "$OUTPUT_DIR/zuraffa_mcp_server-macos-x64"

echo "  Building MCP server for Linux x64..."
dart compile exe bin/zuraffa_mcp_server.dart -o "$OUTPUT_DIR/zuraffa_mcp_server-linux-x64"

echo "  Building MCP server for Windows x64..."
dart compile exe bin/zuraffa_mcp_server.dart -o "$OUTPUT_DIR/zuraffa_mcp_server-windows-x64.exe"

echo "  Building CLI for macOS ARM64..."
dart compile exe bin/zfa.dart -o "$OUTPUT_DIR/zfa-macos-arm64"

echo "  Building CLI for macOS x64..."
dart compile exe bin/zfa.dart -o "$OUTPUT_DIR/zfa-macos-x64"

echo "  Building CLI for Linux x64..."
dart compile exe bin/zfa.dart -o "$OUTPUT_DIR/zfa-linux-x64"

echo "  Building CLI for Windows x64..."
dart compile exe bin/zfa.dart -o "$OUTPUT_DIR/zfa-windows-x64.exe"

echo "  ✓ MCP and CLI binaries built"

# Step 2: Create source archive
echo "📦 Creating source archive..."
SOURCE_ARCHIVE="$OUTPUT_DIR/zuraffa-$VERSION-source.tar.gz"
tar -czf "$SOURCE_ARCHIVE" --exclude="build" --exclude=".git" --exclude="node_modules" .

echo "  ✓ Source archive created: $SOURCE_ARCHIVE"

# Step 3: Create GitHub release
if command -v gh &> /dev/null; then
    echo "📤 Creating GitHub release..."

    RELEASE_EXISTS=$(gh release view "v$VERSION" 2>/dev/null && echo "true" || echo "false")

    if [ "$RELEASE_EXISTS" = "false" ]; then
        echo "  Creating release v$VERSION..."
        gh release create "v$VERSION" \
            --title "v$VERSION" \
            --notes "Release $VERSION" \
            "$OUTPUT_DIR/zuraffa_mcp_server-macos-arm64" \
            "$OUTPUT_DIR/zuraffa_mcp_server-macos-x64" \
            "$OUTPUT_DIR/zuraffa_mcp_server-linux-x64" \
            "$OUTPUT_DIR/zuraffa_mcp_server-windows-x64.exe" \
            "$OUTPUT_DIR/zfa-macos-arm64" \
            "$OUTPUT_DIR/zfa-macos-x64" \
            "$OUTPUT_DIR/zfa-linux-x64" \
            "$OUTPUT_DIR/zfa-windows-x64.exe" \
            "$SOURCE_ARCHIVE"
    else
        echo "  Uploading to existing release v$VERSION..."
        gh release upload "v$VERSION" \
            "$OUTPUT_DIR/zuraffa_mcp_server-macos-arm64" \
            "$OUTPUT_DIR/zuraffa_mcp_server-macos-x64" \
            "$OUTPUT_DIR/zuraffa_mcp_server-linux-x64" \
            "$OUTPUT_DIR/zuraffa_mcp_server-windows-x64.exe" \
            "$OUTPUT_DIR/zfa-macos-arm64" \
            "$OUTPUT_DIR/zfa-macos-x64" \
            "$OUTPUT_DIR/zfa-linux-x64" \
            "$OUTPUT_DIR/zfa-windows-x64.exe" \
            "$SOURCE_ARCHIVE" \
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
echo "Release files are available in: $OUTPUT_DIR"
echo "GitHub release: https://github.com/arrrrny/zuraffa/releases/tag/v$VERSION"
