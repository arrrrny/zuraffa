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

# Update CHANGELOG (only if entry doesn't already exist)
if ! grep -q "^## \[$VERSION\]" CHANGELOG.md 2>/dev/null; then
    awk -v version="$VERSION" -v date="$DATE" -v desc="$DESCRIPTION" '
    BEGIN { print "## [" version "] - " date "\n\n### Change\n- " desc "\n" }
    { print }
    ' CHANGELOG.md > CHANGELOG.md.tmp && mv CHANGELOG.md.tmp CHANGELOG.md
else
    echo "ℹ️  CHANGELOG entry for $VERSION already exists, skipping auto-write."
fi

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

# Update zuraffa-zed extension version via submodule
ZED_SUBMODULE_DIR="$PACKAGE_DIR/extensions/zed"
if [ -e "$ZED_SUBMODULE_DIR/.git" ]; then
    echo "📝 Updating zuraffa-zed extension submodule..."
    cd "$ZED_SUBMODULE_DIR"

    # Ensure submodule is on master with the latest remote commits
    # (this includes .github/workflows/release.yml which is needed for CI release)
    git checkout master 2>/dev/null || git checkout -b master origin/master 2>/dev/null || true
    git pull --rebase origin master 2>/dev/null || echo "⚠️  Could not rebase, committing on top of current HEAD"

    # Update version in extension.toml and Cargo.toml
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/^version = \".*\"/version = \"$VERSION\"/" extension.toml
        sed -i '' "s/^version = \".*\"/version = \"$VERSION\"/" Cargo.toml
    else
        sed -i "s/^version = \".*\"/version = \"$VERSION\"/" extension.toml
        sed -i "s/^version = \".*\"/version = \"$VERSION\"/" Cargo.toml
    fi

    # Update CHANGELOG if exists
    if [ -f CHANGELOG.md ]; then
        if ! grep -q "^## \[$VERSION\]" CHANGELOG.md 2>/dev/null; then
            awk -v version="$VERSION" -v date="$DATE" '
            BEGIN { print "## [" version "] - " date "\n\n### Changed\n- Updated to version " version "\n" }
            { print }
            ' CHANGELOG.md > CHANGELOG.md.tmp && mv CHANGELOG.md.tmp CHANGELOG.md
            git add CHANGELOG.md
        fi
    fi

    # Rebuild WASM binary
    echo "🔨 Rebuilding Zed extension WASM binary..."
    cargo build --target wasm32-wasip1 --release
    cp target/wasm32-wasip1/release/mcp_server_zuraffa.wasm extension.wasm

    # Commit and push submodule changes
    git add extension.toml Cargo.toml extension.wasm CHANGELOG.md
    if [ -n "$(git status --porcelain)" ]; then
        git commit -m "chore: update version to $VERSION"
    else
        echo "ℹ️  No changes to commit in zuraffa-zed"
    fi
    git push origin HEAD:refs/heads/master

    # Create and push tag for the zuraffa-zed repo so CI builds a release
    # (GitHub Actions triggers on tags matching v*)
    # Use --force to update the tag if it already exists from a previous run
    git tag -f -a "v$VERSION" -m "Release $VERSION"
    git push origin "v$VERSION" --force

    cd "$PACKAGE_DIR"
    git add extensions/zed
fi

# Finally, publish to pub.dev
echo "📦 Publishing to pub.dev..."
dart pub publish --force

echo "✅ Published $VERSION successfully!"
