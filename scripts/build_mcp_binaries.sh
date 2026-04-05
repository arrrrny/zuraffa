#!/bin/bash
# Build MCP server binaries for all platforms

set -e

VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}')
OUTPUT_DIR="build/mcp_binaries"

echo "Building Zuraffa MCP Server v$VERSION"
echo "======================================="

mkdir -p "$OUTPUT_DIR"

# Current platform build
echo "Building for current platform..."
dart build cli --target=bin/zuraffa_mcp_server.dart -o "$OUTPUT_DIR/current"

echo ""
echo "✅ Binaries built successfully in $OUTPUT_DIR/current/bundle"
echo ""
echo "Note: Cross-compilation is not supported with native assets."
echo "Each platform must be built on its native OS using 'dart build cli'."
