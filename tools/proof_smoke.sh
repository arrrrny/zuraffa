#!/usr/bin/env bash
# Issue #807 — proof-carrying generation CI smoke.
#
# Drives the v0 slice end-to-end in a throwaway sandbox project:
#   1. `entity create` + `make` ship receipts into `.zfa/receipts/`
#   2. a fresh generation verifies green under a coverage audit
#   3. an unprovenanced generated-code path fails the gate (the CI recipe)
#   4. tampering with a receipted artifact flips the check red
#
# Usage: bash tools/proof_smoke.sh   (run from a `dart pub get`-ed repo)

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
sandbox="$(mktemp -d /tmp/zfa_proof_smoke_XXXXXX)"
trap 'rm -rf "$sandbox"' EXIT

zfa() { (cd "$repo_root" && dart run bin/zfa.dart -C "$sandbox" "$@"); }

mkdir -p "$sandbox/lib/src"
cat > "$sandbox/pubspec.yaml" <<'EOF'
name: proof_smoke
environment:
  sdk: ^3.11.0
dependencies:
  zorphy_annotation: any
dev_dependencies:
  build_runner: any
EOF

# 1. Generate: entity + one make run — each ships its own receipt.
zfa entity create -n Product --fields id:String,name:String >/dev/null
zfa make Product usecase --output lib/src >/dev/null

receipts="$(ls "$sandbox/.zfa/receipts" | wc -l)"
if [ "$receipts" -lt 2 ]; then
  echo "✗ expected receipts for entity create + make, found $receipts" >&2
  exit 1
fi
echo "✓ entity create + make shipped $receipts receipt(s)"

# 2. Fresh generation must prove itself: green under the coverage audit.
zfa proof check lib/src >/dev/null
echo "✓ proof check green on fresh generation"

# 3. CI recipe: fail on unprovenanced generated-code paths.
echo 'final class Rogue {}' > "$sandbox/lib/src/rogue.dart"
if zfa proof check lib/src >/dev/null 2>&1; then
  echo "✗ unprovenanced file was not flagged" >&2
  exit 1
fi
rm "$sandbox/lib/src/rogue.dart"
echo "✓ unprovenanced generated-code path fails the gate"

# 4. Tampering with a receipted artifact flips the check red.
printf '\n// hand edit\n' >> \
  "$sandbox/lib/src/domain/entities/product/product.dart"
if zfa proof check >/dev/null 2>&1; then
  echo "✗ tampered artifact was not flagged" >&2
  exit 1
fi
echo "✓ tampered artifact flips proof check red"

echo "PROOF SMOKE PASSED"
