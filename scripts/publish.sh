#!/bin/bash
# Publish script for zuraffa — clones zuraffa-zed repo to update WASM extension
set -e

VERSION="$1"
DESCRIPTION="${2:-Release $VERSION}"

if [ -z "$VERSION" ]; then echo "❌ Version required"; exit 1; fi

# Publish target registry: pub.dev (the public registry). pub.zuzu.dev was only a
# temporary development mirror and is no longer used. Requires pub.dev credentials
# on this machine (via `dart pub login`).
export PUB_HOSTED_URL="${PUB_HOSTED_URL:-https://pub.dev}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$(dirname "$SCRIPT_DIR")"
# zuraffa_flutter split into its own repo (6.1.0+). Default: sibling checkout.
ZURAFFA_FLUTTER_DIR="${ZURAFFA_FLUTTER_DIR:-$(cd "$PACKAGE_DIR/.." && pwd)/zuraffa_flutter}"
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

# ---- registry helpers (mirror the zikzak_inappwebview ordered-publish flow) ----
# All checks resolve against $PUB_HOSTED_URL (pub.zuzu.dev), which is where the
# packages are published and where the only configured pub token lives.

# True when pub can actually resolve <package>@^<version>. The registry lists a
# version before the archive is resolvable, so resolution (not the API) is the
# real gate — same conclusion the zikzak_inappwebview flow reached for pub.dev.
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

# Block until <package>@<version> is resolvable from $PUB_HOSTED_URL.
wait_for_pubdev() {
    local pkg="$1" ver="$2" max_attempts="${3:-30}" interval="${4:-30}" attempt=0
    echo "⏳ Waiting for $pkg $ver to become resolvable on $PUB_HOSTED_URL..."
    while [ "$attempt" -lt "$max_attempts" ]; do
        attempt=$((attempt + 1))
        if pubdev_resolvable "$pkg" "$ver"; then
            echo "✅ $pkg $ver is live and resolvable on $PUB_HOSTED_URL."
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
    # zfa_cli.dart may not carry a version const in every layout.
    sed -i '' "s/^const version = '.*'/const version = '$VERSION'/" lib/src/version.dart 2>/dev/null || true
    # example/ is optional and may not exist in this repo layout.
    if [ -f example/pubspec.yaml ]; then
        sed -i '' "s/^version: .*/version: $VERSION/" example/pubspec.yaml
    fi
else
    sed -i "s/^version: .*/version: $VERSION/" pubspec.yaml
    sed -i "s/^const version = '.*'/const version = '$VERSION'/" lib/src/version.dart 2>/dev/null || true
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
git add pubspec.yaml CHANGELOG.md lib/src/version.dart
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
# Step 4: Publish zuraffa (core, pure-Dart) to $PUB_HOSTED_URL — first in the
# dependency order, because zuraffa_flutter depends on `zuraffa: ^$VERSION`.
# ============================================================
if pubdev_resolvable zuraffa "$VERSION"; then
    echo "ℹ️  zuraffa $VERSION already resolvable on $PUB_HOSTED_URL — skipping."
else
    echo "📦 Publishing zuraffa to $PUB_HOSTED_URL..."
    dart pub publish --force
    echo "✅ zuraffa $VERSION published to $PUB_HOSTED_URL!"
fi

# ============================================================
# Step 5: Publish zuraffa_flutter from its OWN repo (split since 6.1.0).
# It depends on the freshly published `zuraffa: ^$VERSION`, so we await zuraffa
# being resolvable, bump zuraffa_flutter to $VERSION, pin the zuraffa dep to
# ^$VERSION, strip the dev-only dependency_overrides block, publish, then
# restore the dev pubspec.
# ============================================================
if pubdev_resolvable zuraffa_flutter "$VERSION"; then
    echo "ℹ️  zuraffa_flutter $VERSION already resolvable on $PUB_HOSTED_URL — skipping."
else
    if [ ! -d "$ZURAFFA_FLUTTER_DIR" ]; then
        echo "❌ zuraffa_flutter repo not found at $ZURAFFA_FLUTTER_DIR"
        echo "   Set ZURAFFA_FLUTTER_DIR to the checkout of arrrrny/zuraffa_flutter."
        exit 1
    fi

    cd "$ZURAFFA_FLUTTER_DIR"
    ZF_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    echo "📦 Preparing zuraffa_flutter $VERSION in $ZURAFFA_FLUTTER_DIR (branch $ZF_BRANCH)..."

    # Bump version + pin zuraffa dependency to the freshly published core.
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "s/^version: .*/version: $VERSION/" pubspec.yaml
        sed -i '' -E "s|^(  zuraffa: )\\^.*|\\1^$VERSION|" pubspec.yaml
    else
        sed -i "s/^version: .*/version: $VERSION/" pubspec.yaml
        sed -i -E "s|^(  zuraffa: )\\^.*|\\1^$VERSION|" pubspec.yaml
    fi

    # Backup full dev pubspec so we can restore it after publishing.
    ZF_PUBSPEC_BACKUP="$(mktemp)"
    cp pubspec.yaml "$ZF_PUBSPEC_BACKUP"
    restore_zf_pubspec() {
        if [ -f "$ZF_PUBSPEC_BACKUP" ]; then
            cp "$ZF_PUBSPEC_BACKUP" pubspec.yaml
            rm -f "$ZF_PUBSPEC_BACKUP"
            echo "↩️  Restored dev pubspec in zuraffa_flutter"
            flutter pub get >/dev/null 2>&1 || true
        fi
    }
    trap restore_zf_pubspec EXIT

    # Strip the dev-only dependency_overrides block (analyzer/meta) — pub.dev
    # rejects published packages that carry dependency_overrides.
    echo "🧹 Stripping dev dependency_overrides from zuraffa_flutter for publishing..."
    python3 - pubspec.yaml <<'PY'
import re, sys
path = sys.argv[1]
text = open(path).read()
text = re.sub(r"\ndependency_overrides:(?:\n[ \t]+[^:\n]+:[^\n]*)*\n?", "\n", text)
open(path, "w").write(text)
PY
    grep -q "^dependency_overrides:" pubspec.yaml && {
        echo "❌ zuraffa_flutter pubspec still contains dependency_overrides — aborting."
        exit 1
    }

    # CHANGELOG (create if missing)
    if [ ! -f CHANGELOG.md ]; then
        printf '## [%s] - %s\n\n### Change\n- %s\n' "$VERSION" "$DATE" "$DESCRIPTION" > CHANGELOG.md
    elif ! grep -q "^## \[$VERSION\]" CHANGELOG.md 2>/dev/null; then
        awk -v version="$VERSION" -v date="$DATE" -v desc="$DESCRIPTION" '
        BEGIN { print "## [" version "] - " date "\n\n### Change\n- " desc "\n" }
        { print }
        ' CHANGELOG.md > CHANGELOG.md.tmp && mv CHANGELOG.md.tmp CHANGELOG.md
    fi

    # Block until the new zuraffa is actually resolvable on $PUB_HOSTED_URL
    # (API-listed AND downloadable) BEFORE resolving it locally — mirrors the
    # zikzak_inappwebview ordered-publish gate. This must run before the local
    # `flutter pub get` so the freshly published core is resolvable here too.
    wait_for_pubdev zuraffa "$VERSION" || {
        echo "❌ zuraffa $VERSION is not resolvable on $PUB_HOSTED_URL — cannot verify zuraffa_flutter yet."
        exit 1
    }

    echo "📦 Verifying zuraffa_flutter locally (pub get + analyze)..."
    flutter pub get && flutter analyze --no-fatal-infos --no-fatal-warnings

    # Commit + tag + push the flutter package at the new version.
    git add pubspec.yaml CHANGELOG.md
    git commit -m "chore: release $VERSION" || true
    if ! git rev-parse "v$VERSION" >/dev/null 2>&1; then
        git tag -a "v$VERSION" -m "Release $VERSION"
    fi
    git push origin "$ZF_BRANCH"
    git push origin "v$VERSION"

    # (zuraffa await now runs above, before the local pub get, so resolution is
    # guaranteed before we publish.)

    echo "📦 Publishing zuraffa_flutter $VERSION against hosted zuraffa ^$VERSION..."
    flutter pub publish --force
    echo "✅ zuraffa_flutter $VERSION published to $PUB_HOSTED_URL!"

    restore_zf_pubspec
    trap - EXIT
    cd "$PACKAGE_DIR"
fi

echo "✅ Published $VERSION (zuraffa + zuraffa_flutter) successfully!"
echo ""
echo "Next steps:"
echo "  ./scripts/release.sh $VERSION   # build binaries + GitHub release"
echo "  ./scripts/restore_dev.sh        # back to local path dependencies"
