#!/usr/bin/env bash
# publish_fleet.sh — publish the whole zuraffa fleet to pub.dev at the mono
# version, in dependency order, with resolvability gates.
#
#   ./scripts/publish_fleet.sh [version] [--dry-run-only]
#
# For every publishable fleet package (skip publish_to:none, skip
# zuraffa_browser — a standalone product, not a fleet package):
#   1. skip when pub.dev already has <pkg> <version>,
#   2. wait until every fleet dependency is resolvable at <version>
#      (pub.dev API + a throwaway `dart pub get` probe — the zikzak
#      publish.sh gate),
#   3. `dart pub publish --dry-run` — validation ERRORS abort the fleet
#      run, warnings are tolerated (#19 lesson),
#   4. `dart pub publish --force`,
#   5. wait until the freshly published version resolves (step 2's gate
#      for the dependents).
# New packages (first publish) can hit pub.dev's per-account rate limit —
# the publish step retries with backoff.
set -euo pipefail

if [ "${BASH_VERSINFO[0]:-0}" -lt 4 ]; then
  echo "publish_fleet.sh needs bash >= 4." >&2; exit 1
fi

GREEN='\033[0;32m'; BLUE='\033[0;34m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
DEV_ROOT="${ZURAFFA_DEV_ROOT:-$HOME/Developer}"
VERSION="${1:-7.3.0}"
DRY_ONLY=0
[ "${2:-}" == "--dry-run-only" ] && DRY_ONLY=1

# name|repo|pubspec-path — publishable fleet packages (publish_to:none and
# examples excluded). Order is recomputed topologically below.
INVENTORY=$(cat <<'EOF'
zuraffa|zuraffa|pubspec.yaml
zuraffa_agent|zuraffa_agent|pubspec.yaml
zuraffa_agent_platform_interface|zuraffa_agent|packages/zuraffa_agent_platform_interface/pubspec.yaml
zuraffa_agent_android|zuraffa_agent|packages/zuraffa_agent_android/pubspec.yaml
zuraffa_agent_ios|zuraffa_agent|packages/zuraffa_agent_ios/pubspec.yaml
zuraffa_agent_macos|zuraffa_agent|packages/zuraffa_agent_macos/pubspec.yaml
zuraffa_auth|zuraffa_auth|packages/zuraffa_auth/pubspec.yaml
zuraffa_auth_platform|zuraffa_auth|packages/zuraffa_auth_platform/pubspec.yaml
zuraffa_auth_android|zuraffa_auth|packages/zuraffa_auth_android/pubspec.yaml
zuraffa_auth_ios|zuraffa_auth|packages/zuraffa_auth_ios/pubspec.yaml
zuraffa_auth_macos|zuraffa_auth|packages/zuraffa_auth_macos/pubspec.yaml
zuraffa_code_editor|zuraffa_code_editor|pubspec.yaml
zuraffa_dashboard|zuraffa_dashboard|packages/zuraffa_dashboard/pubspec.yaml
zuraffa_dashboard_platform_interface|zuraffa_dashboard|packages/zuraffa_dashboard_platform_interface/pubspec.yaml
zuraffa_dashboard_android|zuraffa_dashboard|packages/zuraffa_dashboard_android/pubspec.yaml
zuraffa_dashboard_ios|zuraffa_dashboard|packages/zuraffa_dashboard_ios/pubspec.yaml
zuraffa_dashboard_macos|zuraffa_dashboard|packages/zuraffa_dashboard_macos/pubspec.yaml
zuraffa_ffi|zuraffa_ffi|packages/zuraffa_ffi/pubspec.yaml
zuraffa_ffi_platform|zuraffa_ffi|packages/zuraffa_ffi_platform/pubspec.yaml
zuraffa_ffi_android|zuraffa_ffi|packages/zuraffa_ffi_android/pubspec.yaml
zuraffa_ffi_ios|zuraffa_ffi|packages/zuraffa_ffi_ios/pubspec.yaml
zuraffa_ffi_macos|zuraffa_ffi|packages/zuraffa_ffi_macos/pubspec.yaml
zuraffa_file_picker|zuraffa_file_picker|packages/zuraffa_file_picker/pubspec.yaml
zuraffa_file_picker_platform_interface|zuraffa_file_picker|packages/zuraffa_file_picker_platform_interface/pubspec.yaml
zuraffa_file_picker_android|zuraffa_file_picker|packages/zuraffa_file_picker_android/pubspec.yaml
zuraffa_file_picker_ios|zuraffa_file_picker|packages/zuraffa_file_picker_ios/pubspec.yaml
zuraffa_file_picker_macos|zuraffa_file_picker|packages/zuraffa_file_picker_macos/pubspec.yaml
zuraffa_flutter|zuraffa_flutter|pubspec.yaml
zuraffa_graphql|zuraffa_graphql|pubspec.yaml
zuraffa_inappwebview|zuraffa_inappwebview|packages/zuraffa_inappwebview/pubspec.yaml
zuraffa_inappwebview_platform|zuraffa_inappwebview|packages/zuraffa_inappwebview_platform/pubspec.yaml
zuraffa_inappwebview_android|zuraffa_inappwebview|packages/zuraffa_inappwebview_android/pubspec.yaml
zuraffa_inappwebview_ios|zuraffa_inappwebview|packages/zuraffa_inappwebview_ios/pubspec.yaml
zuraffa_inappwebview_macos|zuraffa_inappwebview|packages/zuraffa_inappwebview_macos/pubspec.yaml
zuraffa_intents|zuraffa_intents|pubspec.yaml
zuraffa_minio|zuraffa_minio|pubspec.yaml
zuraffa_observability|zuraffa_observability|pubspec.yaml
zuraffa_ocr|zuraffa_ocr|packages/zuraffa_ocr/pubspec.yaml
zuraffa_ocr_platform|zuraffa_ocr|packages/zuraffa_ocr_platform/pubspec.yaml
zuraffa_ocr_android|zuraffa_ocr|packages/zuraffa_ocr_android/pubspec.yaml
zuraffa_ocr_ios|zuraffa_ocr|packages/zuraffa_ocr_ios/pubspec.yaml
zuraffa_ocr_macos|zuraffa_ocr|packages/zuraffa_ocr_macos/pubspec.yaml
zuraffa_permissions|zuraffa_permissions|packages/zuraffa_permissions/pubspec.yaml
zuraffa_permissions_platform_interface|zuraffa_permissions|packages/zuraffa_permissions_platform_interface/pubspec.yaml
zuraffa_permissions_android|zuraffa_permissions|packages/zuraffa_permissions_android/pubspec.yaml
zuraffa_permissions_ios|zuraffa_permissions|packages/zuraffa_permissions_ios/pubspec.yaml
zuraffa_permissions_macos|zuraffa_permissions|packages/zuraffa_permissions_macos/pubspec.yaml
zuraffa_purchase|zuraffa_purchase|packages/zuraffa_purchase/pubspec.yaml
zuraffa_purchase_platform|zuraffa_purchase|packages/zuraffa_purchase_platform/pubspec.yaml
zuraffa_purchase_android|zuraffa_purchase|packages/zuraffa_purchase_android/pubspec.yaml
zuraffa_purchase_ios|zuraffa_purchase|packages/zuraffa_purchase_ios/pubspec.yaml
zuraffa_purchase_macos|zuraffa_purchase|packages/zuraffa_purchase_macos/pubspec.yaml
zuraffa_session|zuraffa_session|pubspec.yaml
zuraffa_storage|zuraffa_storage|pubspec.yaml
zuraffa_subscriptions|zuraffa_subscriptions|packages/zuraffa_subscriptions/pubspec.yaml
zuraffa_tui|zuraffa_tui|pubspec.yaml
zuraffa_ui|zuraffa_ui|pubspec.yaml
EOF
)

# dependency edges: pkg|dep (fleet deps only, from the inventory pubspecs)
EDGES=$(cat <<'EOF'
zuraffa_agent|zuraffa
zuraffa_agent_platform_interface|zuraffa_agent
zuraffa_agent_android|zuraffa_agent
zuraffa_agent_android|zuraffa_agent_platform_interface
zuraffa_agent_ios|zuraffa_agent
zuraffa_agent_ios|zuraffa_agent_platform_interface
zuraffa_agent_macos|zuraffa_agent
zuraffa_agent_macos|zuraffa_agent_platform_interface
zuraffa_auth|zuraffa
zuraffa_auth|zuraffa_session
zuraffa_auth_platform|zuraffa_auth
zuraffa_auth_android|zuraffa_auth
zuraffa_auth_android|zuraffa_auth_platform
zuraffa_auth_ios|zuraffa_auth
zuraffa_auth_ios|zuraffa_auth_platform
zuraffa_auth_macos|zuraffa_auth
zuraffa_auth_macos|zuraffa_auth_platform
zuraffa_dashboard|zuraffa
zuraffa_dashboard_platform_interface|zuraffa_dashboard
zuraffa_dashboard_android|zuraffa_dashboard
zuraffa_dashboard_android|zuraffa_dashboard_platform_interface
zuraffa_dashboard_ios|zuraffa_dashboard
zuraffa_dashboard_ios|zuraffa_dashboard_platform_interface
zuraffa_dashboard_macos|zuraffa_dashboard
zuraffa_dashboard_macos|zuraffa_dashboard_platform_interface
zuraffa_ffi|zuraffa
zuraffa_ffi|zuraffa_ffi_platform
zuraffa_ffi|zuraffa_ffi_android
zuraffa_ffi|zuraffa_ffi_ios
zuraffa_ffi|zuraffa_ffi_macos
zuraffa_ffi_platform|zuraffa_ffi
zuraffa_ffi_android|zuraffa_ffi
zuraffa_ffi_android|zuraffa_ffi_platform
zuraffa_ffi_ios|zuraffa_ffi
zuraffa_ffi_ios|zuraffa_ffi_platform
zuraffa_ffi_macos|zuraffa_ffi
zuraffa_ffi_macos|zuraffa_ffi_platform
zuraffa_file_picker|zuraffa
zuraffa_file_picker_platform_interface|zuraffa_file_picker
zuraffa_file_picker_android|zuraffa_file_picker
zuraffa_file_picker_android|zuraffa_file_picker_platform_interface
zuraffa_file_picker_ios|zuraffa_file_picker
zuraffa_file_picker_ios|zuraffa_file_picker_platform_interface
zuraffa_file_picker_macos|zuraffa_file_picker
zuraffa_file_picker_macos|zuraffa_file_picker_platform_interface
zuraffa_flutter|zuraffa
zuraffa_flutter|zuraffa_ui
zuraffa_graphql|zuraffa
zuraffa_inappwebview|zuraffa
zuraffa_inappwebview_platform|zuraffa_inappwebview
zuraffa_inappwebview_android|zuraffa_inappwebview
zuraffa_inappwebview_android|zuraffa_inappwebview_platform
zuraffa_inappwebview_ios|zuraffa_inappwebview
zuraffa_inappwebview_ios|zuraffa_inappwebview_platform
zuraffa_inappwebview_macos|zuraffa_inappwebview
zuraffa_inappwebview_macos|zuraffa_inappwebview_platform
zuraffa_intents|zuraffa
zuraffa_observability|zuraffa
zuraffa_ocr|zuraffa
zuraffa_ocr_platform|zuraffa_ocr
zuraffa_ocr_android|zuraffa_ocr
zuraffa_ocr_android|zuraffa_ocr_platform
zuraffa_ocr_ios|zuraffa_ocr
zuraffa_ocr_ios|zuraffa_ocr_platform
zuraffa_ocr_macos|zuraffa_ocr
zuraffa_ocr_macos|zuraffa_ocr_platform
zuraffa_permissions|zuraffa
zuraffa_permissions_platform_interface|zuraffa_permissions
zuraffa_permissions_android|zuraffa_permissions
zuraffa_permissions_android|zuraffa_permissions_platform_interface
zuraffa_permissions_ios|zuraffa_permissions
zuraffa_permissions_ios|zuraffa_permissions_platform_interface
zuraffa_permissions_macos|zuraffa_permissions
zuraffa_permissions_macos|zuraffa_permissions_platform_interface
zuraffa_purchase|zuraffa
zuraffa_purchase|zuraffa_subscriptions
zuraffa_purchase_platform|zuraffa_purchase
zuraffa_purchase_android|zuraffa_purchase
zuraffa_purchase_android|zuraffa_purchase_platform
zuraffa_purchase_ios|zuraffa_purchase
zuraffa_purchase_ios|zuraffa_purchase_platform
zuraffa_purchase_macos|zuraffa_purchase
zuraffa_purchase_macos|zuraffa_purchase_platform
zuraffa_session|zuraffa
zuraffa_storage|zuraffa
zuraffa_storage|zuraffa_minio
zuraffa_subscriptions|zuraffa
zuraffa_tui|zuraffa
EOF
)

# topological order (Kahn) via python
ORDER=$(python3 - "$INVENTORY" "$EDGES" <<'PY'
import sys, os, tempfile
inv = [l.split('|') for l in sys.argv[1].strip().split('\n') if l.strip()]
edges = [tuple(l.split('|')) for l in sys.argv[2].strip().split('\n') if l.strip()]
names = [i[0] for i in inv]
deps = {n: set() for n in names}
# The zuraffa_ffi family is a dependency CYCLE (app <-> platform, app ->
# adapters): ordering drops every intra-family edge — the family publishes
# in inventory order (app, platform, android, ios, macos) and its
# resolvability gates run deferred, after every member is up.
FFI_FAMILY = {'zuraffa_ffi', 'zuraffa_ffi_platform', 'zuraffa_ffi_android',
              'zuraffa_ffi_ios', 'zuraffa_ffi_macos'}
for a, b in edges:
    if a in FFI_FAMILY and b in FFI_FAMILY:
        continue
    if a in deps:
        deps[a].add(b)
order, done = [], set()
while len(order) < len(names):
    progressed = False
    for n in names:
        if n in done:
            continue
        if deps[n] <= done:
            order.append(n); done.add(n); progressed = True
    if not progressed:
        raise SystemExit(f"cycle among: {set(names) - done}")
print('\n'.join(order))
PY
)

pub_has_version() {
  curl -s --max-time 15 "https://pub.dev/api/packages/$1" | grep -q "\"$VERSION\""
}

# The REAL gate: a throwaway consumer resolves pkg ^version from pub.dev.
pub_resolvable() {
  local pkg="$1" tmp
  tmp=$(mktemp -d)
  cat > "$tmp/pubspec.yaml" <<EOF2
name: probe_${pkg}_${VERSION//./_}
environment:
  sdk: ^3.11.0
dependencies:
  $pkg: ^$VERSION
EOF2
  ( cd "$tmp" && dart pub get >/dev/null 2>&1 )
  local rc=$?
  rm -rf "$tmp"
  return $rc
}

wait_resolvable() {
  local pkg="$1" i
  for i in $(seq 1 60); do
    if pub_has_version "$pkg" && pub_resolvable "$pkg"; then
      return 0
    fi
    sleep 15
  done
  echo -e "${RED}TIMEOUT waiting for $pkg $VERSION to be resolvable on pub.dev${NC}"
  return 1
}

echo -e "${BLUE}=== publishing the zuraffa fleet at $VERSION ===${NC}"
declare -A PUBSPEC_OF
while IFS='|' read -r name repo path; do
  [ -n "$name" ] || continue
  PUBSPEC_OF["$name"]="$DEV_ROOT/$repo/$path"
done <<< "$INVENTORY"

FAILED=0
PUBLISHED=0
SKIPPED=0
# Packages whose published form participates in a dependency CYCLE (the
# zuraffa_ffi app <-> platform <-> adapters family): pub.dev can only
# resolve them once every member is up, so their resolvability gates run
# after the whole family is published.
DEFER_GATES="${ZURAFFA_DEFER_GATES:-zuraffa_ffi zuraffa_ffi_platform zuraffa_ffi_android zuraffa_ffi_ios zuraffa_ffi_macos}"
DEFERRED_PUBLISHED=()
for pkg in $ORDER; do
  spec="${PUBSPEC_OF[$pkg]}"
  dir=$(dirname "$spec")
  echo -e "${BLUE}--- $pkg ($dir)${NC}"

  if pub_has_version "$pkg"; then
    echo -e "  ${GREEN}$pkg $VERSION already on pub.dev — skip${NC}"
    SKIPPED=$((SKIPPED+1))
    continue
  fi

  # wait for this package's fleet deps to be resolvable at the target
  local_deps=$(python3 - "$EDGES" "$pkg" <<'PY'
import sys
edges, pkg = sys.argv[1], sys.argv[2]
print('\n'.join(sorted({b for a, b in (l.split('|') for l in edges.strip().split('\n') if l.strip()) if a == pkg})))
PY
)
  if [ -n "$local_deps" ]; then
    if [ "$DRY_ONLY" == "1" ]; then
      # Nothing publishes in dry-run-only mode, so the resolvability gate
      # cannot pass for unpublished deps — note it and move on.
      echo -e "  ${YELLOW}deps not yet live (dry-run mode): $(echo $local_deps | tr '\n' ' ')${NC}"
    else
      echo -e "  ${YELLOW}waiting for deps: $(echo $local_deps | tr '\n' ' ')${NC}"
      for d in $local_deps; do
        wait_resolvable "$d" || { FAILED=1; break 2; }
      done
    fi
  fi

  ( cd "$dir"
    if [ "$DRY_ONLY" == "1" ]; then
      OUT=$(dart pub publish --dry-run 2>&1) || true
      echo "$OUT" | tail -3 | sed 's/^/    /'
      if echo "$OUT" | grep -qE "Package validation found the following error|Sorry, your package is missing a requirement"; then
        echo -e "${RED}DRY-RUN ERRORS in $pkg${NC}"
        echo "$OUT" | grep -B2 -A6 "error" | head -20
        exit 1
      fi
      echo -e "  ${GREEN}dry-run ok${NC}"
      exit 0
    fi
    DRY_OUT=$(dart pub publish --dry-run 2>&1) || true
    if echo "$DRY_OUT" | grep -qE "Package validation found the following error|Sorry, your package is missing a requirement"; then
      echo -e "${RED}dry-run failed for $pkg (errors)${NC}"
      echo "$DRY_OUT" | grep -B2 -A6 "error" | head -20
      exit 1
    fi
    # publish with retry — new packages can trip pub.dev's per-account
    # rate limit (zuraffa_inappwebview#12)
    attempt=1
    rc=1
    while [ $attempt -le 3 ]; do
      if dart pub publish --force > "/tmp/pubpush_$pkg.log" 2>&1; then
        rc=0; break
      fi
      echo -e "  ${YELLOW}publish attempt $attempt failed for $pkg — retrying after backoff${NC}"
      tail -3 "/tmp/pubpush_$pkg.log" | sed 's/^/    /'
      sleep $((attempt * 60))
      attempt=$((attempt + 1))
    done
    if [ $rc -ne 0 ]; then
      echo -e "${RED}publish FAILED for $pkg${NC}"
      tail -10 /tmp/pubpush_$pkg.log | sed 's/^/    /'
      exit 1
    fi
    echo -e "  ${GREEN}published${NC}"
  ) || { FAILED=1; break; }

  if [ "$DRY_ONLY" != "1" ]; then
    if [ -n "$DEFER_GATES" ] && grep -qxF "$pkg" <<< "$DEFER_GATES"; then
      echo -e "  ${YELLOW}gate deferred (cyclic family) for $pkg${NC}"
      DEFERRED_PUBLISHED+=("$pkg")
    else
      echo -e "  ${YELLOW}waiting for $pkg $VERSION to be resolvable...${NC}"
      wait_resolvable "$pkg" || { FAILED=1; break; }
      echo -e "  ${GREEN}resolvable${NC}"
    fi
  fi
  PUBLISHED=$((PUBLISHED+1))
done

# Drain deferred gates: the cyclic family is fully published by now.
if [ "$DRY_ONLY" != "1" ] && [ ${#DEFERRED_PUBLISHED[@]} -gt 0 ]; then
  echo -e "${BLUE}=== draining deferred gates ===${NC}"
  for pkg in "${DEFERRED_PUBLISHED[@]}"; do
    echo -e "  ${YELLOW}waiting for $pkg $VERSION (deferred)...${NC}"
    wait_resolvable "$pkg" || { FAILED=1; break; }
    echo -e "  ${GREEN}resolvable: $pkg${NC}"
  done
fi

if [ "$FAILED" == "1" ]; then
  echo -e "${RED}=== fleet publish INCOMPLETE — rerun publish_fleet.sh to resume (published so far: $PUBLISHED) ===${NC}"
  exit 1
fi
echo -e "${GREEN}=== fleet publish complete: $PUBLISHED published, $SKIPPED already live ===${NC}"
