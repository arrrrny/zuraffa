#!/bin/bash
# Publish script for zuraffa — clones zuraffa-zed repo to update WASM extension
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
# Step 0: Guard — dev-mode path dependencies must never be published.
# `scripts/restore_dev.sh` adds them; they must be reverted first.
# ============================================================
if grep -qE '^[[:space:]]+path:[[:space:]]+\.\./zorphy' pubspec.yaml; then
    echo "❌ Root pubspec.yaml still has local zorphy path overrides (dev mode)."
    echo "   Revert them (git checkout -- pubspec.yaml) before publishing."
    exit 1
fi

# ---- pub.dev helpers (mirror the zikzak_inappwebview ordered-publish flow) ----

# True when <package>@<version> is listed by the pub.dev API.
pubdev_has_version() {
    local pkg="$1" ver="$2" body
    body=$(curl -sf "https://pub.dev/api/packages/$pkg" 2>/dev/null) || return 1
    printf '%s' "$body" | grep -q "\"version\":\"$ver\""
}

# True when pub can actually resolve <package>@^<version>. The API lists a
# version before the archive is resolvable, so this is the real gate.
pubdev_resolvable() {
    local pkg="$1" ver="$2" tmp code
    tmp=$(mktemp -d)
    cat > "$tmp/pubspec.yaml" <<EOF
name: zuraffa_resolution_probe
publish_to: none
environment:
  sdk: ^3.11.0
dependencies:
  $pkg: ^$ver
EOF
    ( cd "$tmp" && dart pub get --no-precompile >/dev/null 2>&1 )
    code=$?
    rm -rf "$tmp"
    return $code
}

# Block until <package>@<version> is both listed and resolvable.
wait_for_pubdev() {
    local pkg="$1" ver="$2" max_attempts="${3:-30}" interval="${4:-30}" attempt=0
    echo "⏳ Waiting for $pkg $ver to go live on pub.dev..."
    while [ "$attempt" -lt "$max_attempts" ]; do
        attempt=$((attempt + 1))
        if pubdev_has_version "$pkg" "$ver" && pubdev_resolvable "$pkg" "$ver"; then
            echo "✅ $pkg $ver is live and resolvable on pub.dev."
            return 0
        fi
        echo "   not ready yet ($attempt/$max_attempts) — retrying in ${interval}s..."
        sleep "$interval"
    done
    echo "❌ $pkg $ver never became resolvable after $((max_attempts * interval / 60)) minutes."
    return 1
}

# ============================================================
# Step 1: Update versions in main repo files
# ============================================================
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s/^version: .*/version: $VERSION/" pubspec.yaml
    sed -i '' "s/^version: .*/version: $VERSION/" zuraffa_flutter/pubspec.yaml
    # zfa_cli.dart may not carry a version const in every layout.
    sed -i '' "s/^const version = '.*'/const version = '$VERSION'/" lib/src/zfa_cli.dart 2>/dev/null || true
    # example/ is optional and may not exist in this repo layout.
    if [ -f example/pubspec.yaml ]; then
        sed -i '' "s/^version: .*/version: $VERSION/" example/pubspec.yaml
    fi
else
    sed -i "s/^version: .*/version: $VERSION/" pubspec.yaml
    sed -i "s/^version: .*/version: $VERSION/" zuraffa_flutter/pubspec.yaml
    sed -i "s/^const version = '.*'/const version = '$VERSION'/" lib/src/zfa_cli.dart 2>/dev/null || true
    if [ -f example/pubspec.yaml ]; then
        sed -i "s/^version: .*/version: $VERSION/" example/pubspec.yaml
    fi
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
# Step 2: Update zuraffa-zed extension (standalone clone)
# Must happen before main repo commit so we can reference the new SHA
# ============================================================
ZED_REPO="git@github.com:arrrrny/zuraffa-zed.git"
ZED_CLONE_DIR="$(mktemp -d)"

echo "📝 Cloning zuraffa-zed extension repo..."
git clone --depth=1 "$ZED_REPO" "$ZED_CLONE_DIR"
cd "$ZED_CLONE_DIR"

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

# Commit and push changes
git add extension.toml Cargo.toml extension.wasm CHANGELOG.md
if [ -n "$(git status --porcelain)" ]; then
    git commit -m "chore: update version to $VERSION"
else
    echo "ℹ️  No changes to commit in zuraffa-zed"
fi

# Capture the new SHA
ZED_NEW_SHA=$(git rev-parse HEAD)

# Push to master
git push origin HEAD:refs/heads/master

# Create and push tag
echo "📤 Pushing zuraffa-zed tag v$VERSION..."
git tag -f -a "v$VERSION" -m "Release $VERSION"
git push origin "v$VERSION" --force

cd "$PACKAGE_DIR"
rm -rf "$ZED_CLONE_DIR"
echo "   zuraffa-zed pinned to: $ZED_NEW_SHA"

# ============================================================
# Step 3: Commit and push main repo (now includes correct submodule pointer)
# ============================================================
echo "🔨 Committing and tagging main repo..."
git add pubspec.yaml CHANGELOG.md lib/src/zfa_cli.dart zuraffa_flutter/pubspec.yaml
# example/ is optional — only stage it if present (otherwise `git add` aborts under set -e).
if [ -f example/pubspec.yaml ]; then
    git add example/pubspec.yaml
fi
git commit -m "chore: release $VERSION" || true

# Create and push tag for the main repo
if ! git rev-parse "v$VERSION" >/dev/null 2>&1; then
    git tag -a "v$VERSION" -m "Release $VERSION"
fi

echo "📤 Pushing main repo to remote..."
git push origin "$CURRENT_BRANCH"
git push origin "v$VERSION"

echo "⚙️  GitHub Actions will now build and upload binaries for all platforms."

# ============================================================
# Step 4: Publish zuraffa (core, pure-Dart) to pub.dev — first in the
# dependency order, because zuraffa_flutter depends on `zuraffa: ^$VERSION`.
# ============================================================
if pubdev_has_version zuraffa "$VERSION"; then
    echo "ℹ️  zuraffa $VERSION already on pub.dev — skipping."
else
    echo "📦 Publishing zuraffa to pub.dev..."
    dart pub publish --force
    echo "✅ zuraffa $VERSION published to pub.dev!"
fi

# ============================================================
# Step 5: Publish zuraffa_flutter. Verify it locally first (the sibling path
# override still applies here), then wait for pub.dev to serve the new
# zuraffa, strip the local override, and publish against the hosted core.
# ============================================================
if pubdev_has_version zuraffa_flutter "$VERSION"; then
    echo "ℹ️  zuraffa_flutter $VERSION already on pub.dev — skipping."
else
    echo "📦 Verifying zuraffa_flutter locally (pub get + analyze)..."
    ( cd zuraffa_flutter && flutter pub get && flutter analyze )

    wait_for_pubdev zuraffa "$VERSION" || {
        echo "❌ zuraffa $VERSION is not resolvable yet — publish zuraffa_flutter manually once it is."
        exit 1
    }

    FLUTTER_PUBSPEC="zuraffa_flutter/pubspec.yaml"
    FLUTTER_PUBSPEC_BACKUP="$(mktemp)"
    cp "$FLUTTER_PUBSPEC" "$FLUTTER_PUBSPEC_BACKUP"
    restore_flutter_pubspec() {
        if [ -f "$FLUTTER_PUBSPEC_BACKUP" ]; then
            cp "$FLUTTER_PUBSPEC_BACKUP" "$FLUTTER_PUBSPEC"
            rm -f "$FLUTTER_PUBSPEC_BACKUP"
            echo "↩️  Restored local dev override in $FLUTTER_PUBSPEC"
        fi
    }
    trap restore_flutter_pubspec EXIT

    echo "🧹 Removing local 'zuraffa: path: ../' override for publishing..."
    python3 - "$FLUTTER_PUBSPEC" <<'PY'
import re, sys
path = sys.argv[1]
text = open(path).read()
# Drop the `zuraffa:` override block (and its leading comment lines) so the
# published archive resolves the hosted `zuraffa` constraint instead.
text = re.sub(r"\n(?:[ \t]*#[^\n]*\n)*[ \t]{2}zuraffa:\n[ \t]{4}path:[^\n]*\n", "\n", text)
open(path, "w").write(text)
PY
    grep -q "path: \.\./" "$FLUTTER_PUBSPEC" && {
        echo "❌ $FLUTTER_PUBSPEC still contains a path dependency — aborting."
        exit 1
    }

    echo "📦 Publishing zuraffa_flutter against hosted zuraffa $VERSION..."
    ( cd zuraffa_flutter && flutter pub get && dart pub publish --force )
    echo "✅ zuraffa_flutter $VERSION published to pub.dev!"

    restore_flutter_pubspec
    trap - EXIT
    ( cd zuraffa_flutter && flutter pub get >/dev/null )
fi

echo "✅ Published $VERSION (zuraffa + zuraffa_flutter) successfully!"
echo ""
echo "Next steps:"
echo "  ./scripts/release.sh $VERSION   # build binaries + GitHub release"
echo "  ./scripts/restore_dev.sh        # back to local path dependencies"
