#!/bin/bash

# Publish script for zuraffa - updates version, CHANGELOG, commits, and publishes to pub.dev
# Usage: ./publish.sh <version> [description]
# Example: ./publish.sh 1.2.0 "Add new features and bug fixes"

set -e

VERSION="$1"
PROMOTE_MODE=false
SKIP_CHANGELOG_UPDATE=false

# Check if version already exists in CHANGELOG
if grep -q "^## \[$VERSION\]" CHANGELOG.md; then
    echo "📋 Version $VERSION already exists in CHANGELOG.md, skipping changelog update..."
    SKIP_CHANGELOG_UPDATE=true
    DESCRIPTION="Release $VERSION"
elif [ $# -eq 1 ]; then
    if grep -q "^## \[Unreleased\]" CHANGELOG.md; then
        echo "✨ Detected [Unreleased] section. Promoting to version $VERSION..."
        PROMOTE_MODE=true
    else
        echo "❌ No description provided and no [Unreleased] section found in CHANGELOG.md."
        echo "Usage: $0 <version> [description] [--type]"
        exit 1
    fi
else
    # Parse description and optional type argument
    DESCRIPTION="${2:-Release $VERSION}"
    TYPE="change"
    
    shift 2 2>/dev/null || true
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --feat|--fix|--docs|--style|--refactor|--perf|--test|--build|--ci|--chore|--revert|--change)
                TYPE="${1#--}"
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
    
    # Capitalize the type for CHANGELOG
    TYPE_CAPITALIZED=$(echo "$TYPE" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')
fi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PACKAGE_DIR"

# Validate version format (simple check for X.Y.Z pattern)
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "❌ Invalid version format. Expected format: X.Y.Z (e.g., 1.2.0)"
    exit 1
fi

# Get current date
DATE=$(date +%Y-%m-%d)

echo "🚀 Publishing zuraffa version $VERSION..."
echo ""

# Step 1: Update version in pubspec.yaml
echo "📝 Updating version in pubspec.yaml..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s/^version: .*/version: $VERSION/" pubspec.yaml
else
    sed -i "s/^version: .*/version: $VERSION/" pubspec.yaml
fi
echo "  ✓ Version updated to $VERSION"

# Update version in lib/src/zfa_cli.dart
echo "📝 Updating version in lib/src/zfa_cli.dart..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s/^const version = '.*'/const version = '$VERSION'/" lib/src/zfa_cli.dart
else
    sed -i "s/^const version = '.*'/const version = '$VERSION'/" lib/src/zfa_cli.dart
fi
echo "  ✓ CLI version updated"

# Update version in example/pubspec.yaml
echo "📝 Updating version in example/pubspec.yaml..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s/^version: .*/version: $VERSION/" example/pubspec.yaml
else
    sed -i "s/^version: .*/version: $VERSION/" example/pubspec.yaml
fi
echo "  ✓ Example version updated"

# Step 2: Update CHANGELOG.md
if [ "$SKIP_CHANGELOG_UPDATE" = true ]; then
    echo "📝 Skipping CHANGELOG.md update (version already exists)..."
else
    echo "📝 Updating CHANGELOG.md..."

    # Check if [Unreleased] section exists for promote mode
    if [ "$PROMOTE_MODE" = true ]; then
        if ! grep -q "^## \[Unreleased\]" CHANGELOG.md; then
            echo "❌ [Unreleased] section not found in CHANGELOG.md for promote mode."
            exit 1
        fi
        # Replace [Unreleased] with version and date
        awk -v version="$VERSION" -v date="$DATE" '
        /^## \[Unreleased\]/ { print "## [" version "] - " date; next }
        { print }
        ' CHANGELOG.md > CHANGELOG.md.tmp && mv CHANGELOG.md.tmp CHANGELOG.md
        DESCRIPTION="Release $VERSION"
    else
        # Insert new version at the top of the file
        awk -v version="$VERSION" -v date="$DATE" -v type="$TYPE_CAPITALIZED" -v desc="$DESCRIPTION" '
        BEGIN {
            print "## [" version "] - " date
            print ""
            print "### " type
            print "- " desc
            print ""
        }
        { print }
        ' CHANGELOG.md > CHANGELOG.md.tmp && mv CHANGELOG.md.tmp CHANGELOG.md
    fi
    echo "  ✓ CHANGELOG.md updated"
fi

# Step 3: Commit changes
echo "🔨 Committing changes..."
if [ "$SKIP_CHANGELOG_UPDATE" = true ]; then
    git add pubspec.yaml lib/src/zfa_cli.dart example/pubspec.yaml
else
    git add pubspec.yaml CHANGELOG.md lib/src/zfa_cli.dart example/pubspec.yaml
fi
git commit -m "chore: release $VERSION"
echo "  ✓ Changes committed"

# Step 4: Create PR to master
if command -v gh &> /dev/null; then
    echo "🔄 Creating pull request to master..."
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    CHANGES_LIST="- Bump version to $VERSION"
    if [ "$SKIP_CHANGELOG_UPDATE" = false ]; then
        CHANGES_LIST="$CHANGES_LIST\n- Update CHANGELOG.md"
    fi
    PR_BODY="Release $VERSION

**Description:** $DESCRIPTION

**Date:** $DATE

**Changes:**
$CHANGES_LIST

Please review and merge this PR to master before proceeding with the release tag and publication."

    if gh pr list --head "$CURRENT_BRANCH" --json number | grep -q "\"number\""; then
        echo "  ⚠️  PR already exists for branch $CURRENT_BRANCH"
    else
        gh pr create --base master --head "$CURRENT_BRANCH" --title "chore: release $VERSION" --body "$PR_BODY"
        echo "  ✓ PR created from $CURRENT_BRANCH to master"
    fi
else
    echo "⚠️  GitHub CLI (gh) not found. Skipping PR creation."
    echo "   Please create a PR to master manually:"
    echo "   https://github.com/$(git config --get remote.origin.url | sed 's/.*github.com[:/]\(.*\)\.git/\1/')/compare/master...$CURRENT_BRANCH"
fi

# Step 5: Create and push git tag
echo "🏷️  Creating git tag..."
git tag -a "v$VERSION" -m "Release $VERSION"
git push origin "$(git rev-parse --abbrev-ref HEAD)"
git push origin "v$VERSION"
echo "  ✓ Tag v$VERSION pushed"

# Step 6: Run tests
echo "🧪 Running tests..."
flutter test
echo "  ✓ Tests passed"

# Step 7: Build MCP server and CLI binaries
echo "🔧 Building MCP server and CLI binaries..."
OUTPUT_DIR="build/mcp_binaries"
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

# Step 8: Upload binaries to GitHub release
if command -v gh &> /dev/null; then
    echo "📤 Uploading binaries to GitHub release..."
    
    RELEASE_EXISTS=$(gh release view "v$VERSION" 2>/dev/null && echo "true" || echo "false")
    
    if [ "$RELEASE_EXISTS" = "false" ]; then
        echo "  Creating release v$VERSION..."
        gh release create "v$VERSION" \
            --title "v$VERSION" \
            --notes "$DESCRIPTION" \
            "$OUTPUT_DIR/zuraffa_mcp_server-macos-arm64" \
            "$OUTPUT_DIR/zuraffa_mcp_server-macos-x64" \
            "$OUTPUT_DIR/zuraffa_mcp_server-linux-x64" \
            "$OUTPUT_DIR/zuraffa_mcp_server-windows-x64.exe" \
            "$OUTPUT_DIR/zfa-macos-arm64" \
            "$OUTPUT_DIR/zfa-macos-x64" \
            "$OUTPUT_DIR/zfa-linux-x64" \
            "$OUTPUT_DIR/zfa-windows-x64.exe"
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
            --clobber
    fi
    echo "  ✓ Binaries uploaded to GitHub release"
    
    # Step 9: Update zuraffa-zed extension version
    echo "📝 Updating zuraffa-zed extension version..."
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
        git commit -m "chore: update version to $VERSION"
        git push
        echo "  ✓ zuraffa-zed version updated and pushed"
        cd "$PACKAGE_DIR"
    else
        echo "  ⚠️  zuraffa-zed directory not found at $ZED_EXTENSION_DIR"
    fi
else
    echo "⚠️  GitHub CLI (gh) not found. Skipping release upload."
    echo "   Please upload binaries manually to: https://github.com/arrrrny/zuraffa/releases/tag/v$VERSION"
fi

# Step 9: Publish to pub.dev
echo "📦 Publishing to pub.dev..."
dart pub publish --force

echo ""
echo "✅ Successfully published zuraffa version $VERSION!"
echo ""
echo "Tag: v$VERSION"
echo "Date: $DATE"
echo "Description: $DESCRIPTION"
echo ""
echo "View on pub.dev: https://pub.dev/packages/zuraffa/$VERSION"
echo "Download binaries: https://github.com/arrrrny/zuraffa/releases/tag/v$VERSION"
