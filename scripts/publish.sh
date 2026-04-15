#!/bin/bash
# Optimized publish script for zuraffa - compatible with Zed extensions
set -e

VERSION="$1"
DESCRIPTION="${2:-Release $VERSION}"

if [ -z "$VERSION" ]; then echo "❌ Version required"; exit 1; fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PACKAGE_DIR"

DATE=$(date +%Y-%m-%d)
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

echo "🚀 Publishing zuraffa version $VERSION on branch $CURRENT_BRANCH..."

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
echo "🔨 Committing and tagging..."
git add pubspec.yaml CHANGELOG.md lib/src/zfa_cli.dart example/pubspec.yaml
git commit -m "chore: release $VERSION" || true

# Only create tag if it doesn't exist
if ! git rev-parse "v$VERSION" >/dev/null 2>&1; then
    git tag -a "v$VERSION" -m "Release $VERSION"
fi

# Push current branch and ONLY the specific tag
echo "📤 Pushing to remote..."
git push origin "$CURRENT_BRANCH"
git push origin "v$VERSION"

# NOTE: GitHub Actions will now handle the binary builds and uploads automatically
echo "⚙️  GitHub Actions will now build and upload binaries for all platforms."

# Update zuraffa-zed extension version locally if it exists
ZED_EXTENSION_DIR="$HOME/Developer/zuraffa-zed"
if [ -d "$ZED_EXTENSION_DIR" ]; then
    echo "📝 Updating local zuraffa-zed extension..."
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

# Finally, publish to pub.dev
echo "📦 Publishing to pub.dev..."
dart pub publish --force

echo "✅ Published $VERSION successfully!"
