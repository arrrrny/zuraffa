#!/bin/bash

# Publish script for zuraffa - updates version, CHANGELOG, commits, and publishes to pub.dev
# Usage: ./publish.sh <version> [description]
# Example: ./publish.sh 1.2.0 "Add new features and bug fixes"

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 <version> [description]"
    echo "Example: $0 1.2.0 \"Add new features and bug fixes\""
    exit 1
fi

VERSION="$1"
DESCRIPTION="${2:-Release $VERSION}"

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
echo "📝 Updating CHANGELOG.md..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS sed syntax
    sed -i '' "/^## \[Unreleased\]/a\\
\\
## [$VERSION] - $DATE\\
\\
### Changed\\
- $DESCRIPTION
" CHANGELOG.md
else
    # Linux sed syntax
    sed -i "/^## \[Unreleased\]/a\\
\\
## [$VERSION] - $DATE\\
\\
### Changed\\
- $DESCRIPTION
" CHANGELOG.md
fi
echo "  ✓ CHANGELOG.md updated"

# Step 3: Commit changes
echo "🔨 Committing changes..."
git add pubspec.yaml CHANGELOG.md lib/src/zfa_cli.dart example/pubspec.yaml
git commit -m "chore: release $VERSION"
echo "  ✓ Changes committed"

# Step 4: Create and push git tag
echo "🏷️  Creating git tag..."
git tag -a "v$VERSION" -m "Release $VERSION"
git push origin "$(git rev-parse --abbrev-ref HEAD)"
git push origin "v$VERSION"
echo "  ✓ Tag v$VERSION pushed"

# Step 5: Run tests
echo "🧪 Running tests..."
flutter test
echo "  ✓ Tests passed"

# Step 6: Publish to pub.dev
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
