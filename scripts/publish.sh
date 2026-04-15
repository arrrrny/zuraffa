#!/bin/bash
# Optimized publish script for zuraffa - compatible with Zed extensions
set -e

VERSION="$1"
DESCRIPTION="${2:-Release $VERSION}"
TYPE="change"

if [ -z "$VERSION" ]; then echo "❌ Version required"; exit 1; fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PACKAGE_DIR"

DATE=$(date +%Y-%m-%d)

echo "🚀 Publishing zuraffa version $VERSION..."

# Update versions
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s/^version: .*/version: $VERSION/" pubspec.yaml
    sed -i '' "s/^const version = '.*'/const version = '$VERSION'/" lib/src/zfa_cli.dart
    sed -i '' "s/^version: .*/version: $VERSION/" example/pubspec.yaml
else
    sed -i "s/^version: .*/version: $VERSION/" pubspec.yaml
    sed -i "s/^const version = '.*'/const version = '$VERSION'/" lib/src/zfa_cli.dart
    sed -i "s/^version: .*/version: $VERSION/" example/pubspec.yaml
fi

# Update CHANGELOG
awk -v version="$VERSION" -v date="$DATE" -v desc="$DESCRIPTION" '
BEGIN { print "## [" version "] - " date "\n\n### Change\n- " desc "\n" }
{ print }
' CHANGELOG.md > CHANGELOG.md.tmp && mv CHANGELOG.md.tmp CHANGELOG.md

# Commit and Tag
git add pubspec.yaml CHANGELOG.md lib/src/zfa_cli.dart example/pubspec.yaml
git commit -m "chore: release $VERSION" || true
git tag -a "v$VERSION" -m "Release $VERSION" || true
git push origin main --tags || git push origin master --tags || true

# Build and Upload Binaries
OUTPUT_DIR="build/mcp_binaries"
mkdir -p "$OUTPUT_DIR"

OS_NAME=$(uname -s | tr '[:upper:]' '[:lower:]')
if [ "$OS_NAME" = "darwin" ]; then OS_NAME="macos"; fi
ARCH_NAME=$(uname -m)
if [ "$ARCH_NAME" = "x86_64" ]; then ARCH_NAME="x64"; fi
PLATFORM_TAG="${OS_NAME}-${ARCH_NAME}"

echo "🔧 Building MCP server and CLI..."
dart build cli --target=bin/zuraffa_mcp_server.dart -o "$OUTPUT_DIR/mcp_server_raw"
dart build cli --target=bin/zfa.dart -o "$OUTPUT_DIR/zfa_raw"

echo "📦 Creating compressed binaries (.gz)..."
MCP_GZ="$OUTPUT_DIR/zuraffa_mcp_server-$PLATFORM_TAG-v$VERSION.gz"
ZFA_GZ="$OUTPUT_DIR/zfa-$PLATFORM_TAG-v$VERSION.gz"

gzip -c "$OUTPUT_DIR/mcp_server_raw/bundle" > "$MCP_GZ"
gzip -c "$OUTPUT_DIR/zfa_raw/bundle" > "$ZFA_GZ"

if command -v gh &> /dev/null; then
    gh release create "v$VERSION" --title "v$VERSION" --notes "$DESCRIPTION" "$MCP_GZ" "$ZFA_GZ" || \
    gh release upload "v$VERSION" "$MCP_GZ" "$ZFA_GZ" --clobber
fi

# Update zuraffa-zed extension version
ZED_EXTENSION_DIR="$HOME/Developer/zuraffa-zed"
if [ -d "$ZED_EXTENSION_DIR" ]; then
    cd "$ZED_EXTENSION_DIR"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/^version = \".*\"/version = \"$VERSION\"/" extension.toml
        sed -i '' "s/^version = \".*\"/version = \"$VERSION\"/" Cargo.toml
    else
        sed -i "s/^version = \".*\"/version = \"$VERSION\"/" extension.toml
        sed -i "s/^version = \".*\"/version = \"$VERSION\"/" Cargo.toml
    fi
    git add extension.toml Cargo.toml
    git commit -m "chore: update version to $VERSION" || true
    git push || true
    cd "$PACKAGE_DIR"
fi

# Publish to pub.dev
dart pub publish --force

echo "✅ Published $VERSION"
