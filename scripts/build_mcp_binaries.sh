#!/bin/bash
# Build MCP server binaries for all platforms

set -e

VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}')
OUTPUT_DIR="build/mcp_binaries"

echo "Building Zuraffa MCP Server v$VERSION"
echo "======================================="

mkdir -p "$OUTPUT_DIR"

# macOS (ARM64)
echo "Building for macOS ARM64..."
dart compile exe bin/zuraffa_mcp_server.dart -o "$OUTPUT_DIR/zuraffa_mcp_server-macos-arm64"

# macOS (x64)
echo "Building for macOS x64..."
dart compile exe bin/zuraffa_mcp_server.dart -o "$OUTPUT_DIR/zuraffa_mcp_server-macos-x64"

# Linux (x64)
echo "Building for Linux x64..."
dart compile exe bin/zuraffa_mcp_server.dart -o "$OUTPUT_DIR/zuraffa_mcp_server-linux-x64"

# Windows (x64)
echo "Building for Windows x64..."
dart compile exe bin/zuraffa_mcp_server.dart -o "$OUTPUT_DIR/zuraffa_mcp_server-windows-x64.exe"

echo ""
echo "✅ Binaries built successfully in $OUTPUT_DIR/"
echo ""
echo "To create release archives:"
echo "  cd $OUTPUT_DIR"
echo "  tar -czf zuraffa_mcp_server-macos-arm64-v$VERSION.tar.gz zuraffa_mcp_server-macos-arm64"
echo "  tar -czf zuraffa_mcp_server-macos-x64-v$VERSION.tar.gz zuraffa_mcp_server-macos-x64"
echo "  tar -czf zuraffa_mcp_server-linux-x64-v$VERSION.tar.gz zuraffa_mcp_server-linux-x64"
echo "  zip zuraffa_mcp_server-windows-x64-v$VERSION.zip zuraffa_mcp_server-windows-x64.exe"
