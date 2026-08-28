#!/bin/bash
# Restore local development mode for the zuraffa monorepo.
#
# Rewrites `dependency_overrides` so every in-house package resolves from a
# local checkout instead of pub.dev:
#
#   zuraffa            -> zorphy, zorphy_annotation  (../zorphy/*)
#   zuraffa_flutter    -> zuraffa (../), plus the zorphy packages
#   apps/*, examples/* -> zuraffa (relative), zuraffa_flutter, zorphy packages
#
# Overrides are only written when the target directory actually exists, so a
# machine without a sibling `zorphy` checkout keeps the hosted versions.
#
# IMPORTANT: these overrides are dev-only and must never be committed or
# published — `scripts/publish.sh` aborts if it finds them. Revert with
#   git checkout -- pubspec.yaml zuraffa_flutter/pubspec.yaml
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$ROOT_DIR"

ZORPHY_ROOT="${ZORPHY_ROOT:-$(cd "$ROOT_DIR/.." && pwd)/zorphy}"

echo "🔧 Restoring zuraffa development mode"
echo "   repo root : $ROOT_DIR"
echo "   zorphy    : $ZORPHY_ROOT"

if [ ! -d "$ZORPHY_ROOT/zorphy" ]; then
    echo "⚠️  No zorphy checkout at $ZORPHY_ROOT — zorphy overrides will be skipped."
fi

# apply_overrides <pubspec.yaml> <name=relative-path> ...
# Inserts/updates a `path:` override per package inside dependency_overrides,
# skipping any whose target directory does not exist.
apply_overrides() {
    local pubspec="$1"; shift
    if [ ! -f "$pubspec" ]; then
        echo "⚠️  Skipping missing $pubspec"
        return 0
    fi
    python3 - "$pubspec" "$@" <<'PY'
import os, re, sys

pubspec = sys.argv[1]
base = os.path.dirname(os.path.abspath(pubspec)) or "."
pairs = []
for arg in sys.argv[2:]:
    name, rel = arg.split("=", 1)
    target = os.path.normpath(os.path.join(base, rel))
    if os.path.isdir(target):
        # Always store a relative path so pubspecs stay machine-independent.
        pairs.append((name, os.path.relpath(target, base)))
    else:
        print(f"   - {name}: no checkout at {target} (skipped)")

if not pairs:
    sys.exit(0)

text = open(pubspec).read()
if not text.endswith("\n"):
    text += "\n"

if not re.search(r"^dependency_overrides:\s*$", text, re.M):
    text += "\ndependency_overrides:\n"

lines = text.split("\n")
start = next(i for i, l in enumerate(lines) if l.strip() == "dependency_overrides:")
end = start + 1
while end < len(lines) and (lines[end].startswith((" ", "\t")) or lines[end].strip() == ""):
    end += 1
# trim trailing blank lines back into the tail
while end > start + 1 and lines[end - 1].strip() == "":
    end -= 1

block = lines[start + 1:end]

def drop(block, name):
    out, i = [], 0
    while i < len(block):
        line = block[i]
        if re.match(rf"^  {re.escape(name)}:\s*(#.*)?$", line):
            i += 1
            while i < len(block) and re.match(r"^ {4,}\S", block[i]):
                i += 1
            continue
        if re.match(rf"^  {re.escape(name)}:\s*\S", line):
            i += 1
            continue
        out.append(line)
        i += 1
    return out

for name, rel in pairs:
    block = drop(block, name)
    block.append(f"  {name}:")
    block.append(f"    path: {rel}")
    print(f"   + {name} -> {rel}")

lines[start + 1:end] = block
open(pubspec, "w").write("\n".join(lines))
PY
}

echo ""
echo "📦 zuraffa (core)"
apply_overrides pubspec.yaml \
    "zorphy=$ZORPHY_ROOT/zorphy" \
    "zorphy_annotation=$ZORPHY_ROOT/zorphy_annotation"

echo ""
# zuraffa_flutter split into its own repo (6.1.0+); its dev overrides are
# managed there, not here.
if [ -f zuraffa_flutter/pubspec.yaml ]; then
    echo "📦 zuraffa_flutter"
    apply_overrides zuraffa_flutter/pubspec.yaml \
        "zuraffa=.." \
        "zorphy=$ZORPHY_ROOT/zorphy" \
        "zorphy_annotation=$ZORPHY_ROOT/zorphy_annotation"
else
    echo "ℹ️  zuraffa_flutter is a separate repo now — skipping its dev overrides here."
fi

# Local consumers (demo apps, examples) — only those that depend on zuraffa.
for pubspec in apps/*/pubspec.yaml examples/*/pubspec.yaml; do
    [ -f "$pubspec" ] || continue
    grep -qE "^\s+zuraffa(_flutter)?:" "$pubspec" || continue
    dir="$(dirname "$pubspec")"
    rel_root="$(python3 -c "import os,sys;print(os.path.relpath('$ROOT_DIR', '$dir'))")"
    echo ""
    echo "📦 $dir"
    apply_overrides "$pubspec" \
        "zuraffa=$rel_root" \
        "zuraffa_flutter=$rel_root/zuraffa_flutter" \
        "zorphy=$ZORPHY_ROOT/zorphy" \
        "zorphy_annotation=$ZORPHY_ROOT/zorphy_annotation"
done

echo ""
echo "⬇️  Resolving dependencies..."
dart pub get
if [ -d zuraffa_flutter ]; then
    ( cd zuraffa_flutter && flutter pub get )
else
    echo "ℹ️  zuraffa_flutter is a separate repo now — skipping its pub get here."
fi

echo ""
echo "🔬 Verifying path overrides"
issues=0
for pubspec in pubspec.yaml zuraffa_flutter/pubspec.yaml; do
    [ -f "$pubspec" ] || continue
    count=$(grep -cE "^\s+path: " "$pubspec" || true)
    if [ "$count" -eq 0 ]; then
        echo "⚠️  $pubspec has no path overrides"
        issues=$((issues + 1))
    else
        echo "✅ $pubspec: $count path override(s)"
    fi
done

echo ""
if [ "$issues" -eq 0 ]; then
    echo "✅ Development mode restored."
else
    echo "⚠️  Development mode restored with $issues warning(s)."
fi
echo "   Remember: do NOT commit these overrides. Revert with"
echo "   git checkout -- pubspec.yaml zuraffa_flutter/pubspec.yaml"
