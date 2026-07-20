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

# ============================================================
# Step 1: Update versions in main repo files
# ============================================================
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

# ============================================================
# Step 2: Update zuraffa-zed submodule FIRST
# (must happen before main repo commit so the submodule pointer is correct)
# ============================================================
ZED_SUBMODULE_DIR="$PACKAGE_DIR/extensions/zed"
if [ -e "$ZED_SUBMODULE_DIR/.git" ]; then
    echo "📝 Updating zuraffa-zed extension submodule..."
    cd "$ZED_SUBMODULE_DIR"

    # Ensure submodule is on master with the latest remote commits
    git checkout master 2>/dev/null || git checkout -b master origin/master 2>/dev/null || true

    # Use fetch + reset instead of pull --rebase to guarantee clean state
    git fetch origin master
    CURRENT_REMOTE=$(git rev-parse origin/master)
    CURRENT_LOCAL=$(git rev-parse HEAD)
    if [ "$CURRENT_REMOTE" != "$CURRENT_LOCAL" ]; then
        echo "⚠️  Submodule is behind origin/master, resetting to remote..."
        git reset --hard origin/master
    fi

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

    # Capture the new submodule commit SHA for logging
    SUBMOD_NEW_SHA=$(git rev-parse HEAD)

    # Push submodule branch
    git push origin HEAD:refs/heads/master

    # Create and push tag for the zuraffa-zed repo (triggers CI release + extension PR)
    echo "📤 Pushing zuraffa-zed tag v$VERSION..."
    git tag -f -a "v$VERSION" -m "Release $VERSION"
    git push origin "v$VERSION" --force

    cd "$PACKAGE_DIR"

    # Stage the updated submodule pointer so it goes into the main release commit
    git add extensions/zed
    echo "   zuraffa-zed submodule pinned to: $SUBMOD_NEW_SHA"
fi

# ============================================================
# Step 3: Commit and push main repo (now includes correct submodule pointer)
# ============================================================
echo "🔨 Committing and tagging main repo..."
git add pubspec.yaml CHANGELOG.md lib/src/zfa_cli.dart example/pubspec.yaml
git commit -m "chore: release $VERSION" || true

# Create and push tag for the main repo
if ! git rev-parse "v$VERSION" >/dev/null 2>&1; then
    git tag -a "v$VERSION" -m "Release $VERSION"
fi

echo "📤 Pushing main repo to remote..."
git push origin "$CURRENT_BRANCH"
git push origin "v$VERSION"

echo "⚙️  GitHub Actions will now build and upload binaries for all platforms."

# Finally, publish to pub.dev
echo "📦 Publishing to pub.dev..."
dart pub publish --force

echo "✅ Published $VERSION successfully!"
