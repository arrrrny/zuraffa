#!/usr/bin/env bash
# EPIC 3 / issue #1134: exit-criteria e2e evidence script (precedent:
# scripts/e2e_1405_check.sh). Hermetic temp project; drives the REAL
# CLI (`dart run bin/zfa.dart`) and records the ACTUAL outputs the
# verification.md section claims.
#
# Exit criteria (epic #1134):
#   1. 004-login-ui: view supports mobile and macOS layout slots in
#      the same generated output.
#   2. XRay overlay shows a per-layout kind-coverage heatmap.
#   3. No view generator emits unchecked grid/table layout code.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d /tmp/issue_1134_e2e_XXXXXX)
# The helper probes below are written to a mktemp-UNIQUE dir and removed
# on exit: fixed shared names under .dart_tool/ collide when two runs of
# this script share a checkout (this repo runs several agents per
# machine), overwriting each other's helpers mid-run.
mkdir -p "${REPO_ROOT}/.dart_tool"
HELPERS=$(mktemp -d "${REPO_ROOT}/.dart_tool/e2e_1134_helpers_XXXXXX")
cleanup() { rm -rf "$TMP" "$HELPERS"; }
trap cleanup EXIT
ZFA="dart run ${REPO_ROOT}/bin/zfa.dart"
PASS=0
FAIL=0

check() { # check <label> <condition-exit-code>
  if [ "$2" -eq 0 ]; then echo "PASS: $1"; PASS=$((PASS+1)); else echo "FAIL: $1"; FAIL=$((FAIL+1)); fi
}

echo "TMP=$TMP"
echo "repo: ${REPO_ROOT}"
echo ""

# ---------------------------------------------------------------------
# EC-1 — 004-login-ui: mobile + macOS layout slots in the SAME
# generated output (the example corpus's Presentation contract
# declares adaptive_layouts: mobile, macos).
# ---------------------------------------------------------------------
echo "=== EC-1: zfa tdd view emits mobile + macOS slots in one output ==="
mkdir -p "$TMP/specs/004-login-ui/tdd" "$TMP/lib/tdd/004-login-ui"
cat > "$TMP/specs/004-login-ui/spec.md" <<'EOF'
**Template Version**: `zuraffa-1.0`

# Feature Specification: 004-login-ui — the adaptive login skin

## Layer Contracts

**Presentation**:
- `LoginForm`: `ShadInput` for email and password
- `adaptive_layouts`: `mobile`, `macos`
EOF
cat > "$TMP/specs/004-login-ui/tdd/test-list.md" <<'EOF'
# Test List: 004-login-ui

## Layer contracts

### Presentation

- `LoginForm`: `ShadInput` for email and password
- `adaptive_layouts`: `mobile`, `macos`
EOF
cat > "$TMP/specs/004-login-ui/tdd/artifacts.json" <<'EOF'
{
  "feature": "004-login-ui",
  "records": [
    {
      "behavior_id": "W9",
      "feature": "004-login-ui",
      "source_criterion": "FR-001",
      "test_path": "test/tdd/004-login-ui/w9_test.dart",
      "subject_path": "lib/tdd/004-login-ui/w9_subject.dart",
      "runnable_test_name": "test/tdd/004-login-ui/w9_test.dart::W9::the adaptive login view",
      "test_ownership": "created",
      "subject_ownership": "created",
      "created_at": "2026-09-18T00:00:00.000000Z"
    }
  ]
}
EOF
cat > "$TMP/lib/tdd/004-login-ui/w9_subject.dart" <<'EOF'
// GENERATED STUB — `zfa tdd gen W9` (spec 044-test-tdd-generation).
library;

import 'package:flutter/material.dart';

/// View-builder subject for behavior W9.
///
/// Throws [UnimplementedError] until the real implementation lands.
Widget subject_w9() => throw UnimplementedError('subject_w9 not implemented');
EOF
cat > "$TMP/pubspec.yaml" <<'EOF'
name: login_e2e_host
environment:
  sdk: ^3.11.0
EOF

OUT=$($ZFA tdd view W9 --project "$TMP" 2>&1)
echo "$OUT" | grep -E "layouts:|scaffolded:|view: behavior=" | sed 's/^/  /'
SUBJECT="$TMP/lib/tdd/004-login-ui/w9_subject.dart"
echo "$SUBJECT" | grep -q x # noop to keep the var used
grep -q "class W9ViewMobileLayout" "$SUBJECT"; check "EC-1a: the generated output carries the mobile layout stub" $?
grep -q "class W9ViewMacosLayout" "$SUBJECT"; check "EC-1b: the generated output carries the macOS layout stub (same output)" $?
grep -q "Key('w9-slot-mobile')" "$SUBJECT"; check "EC-1c: the mobile slot key (login-slot-<slot> shape)" $?
grep -q "Key('w9-slot-macos')" "$SUBJECT"; check "EC-1d: the macOS slot key" $?
grep -q "_resolveSlot" "$SUBJECT"; check "EC-1e: the AdaptiveViewState slot resolution" $?
echo ""

# ---------------------------------------------------------------------
# EC-2 — the XRay overlay shows a per-layout kind-coverage heatmap:
# plan writes typed-ledger.{md,json} with the per-layout heatmap; the
# overlay binding renders kind coverage per layout.
# ---------------------------------------------------------------------
echo "=== EC-2: plan writes the per-layout heatmap; the overlay renders it ==="
mkdir -p "$TMP/specs/005-kind-matrix/tdd"
cat > "$TMP/specs/005-kind-matrix/spec.md" <<'EOF'
**Template Version**: `zuraffa-1.0`

# Feature Specification: 005-kind-matrix — the typed kind matrix

## Acceptance Scenarios

1. **Given** valid credentials **When** the user submits the login form **Then** the session starts with the authenticated user
   **Type**: acceptance

2. **Given** invalid credentials **When** the login attempt fails **Then** the error is reported to the caller
   **Type**: acceptance

3. **Given** the login view **When** it renders **Then** the app shows 'Sign in'
   **Type**: widget

4. **Given** a completed sign-in **When** the user signs in **Then** the app navigates to the route 'deal_list'
   **Type**: widget

5. **Given** a fresh login view **When** no sign-in attempt has failed **Then** the 'Sign in failed' banner is not shown
   **Type**: widget

6. **Given** an empty form **When** validation runs **Then** the 'Sign in' button is disabled
   **Type**: widget

7. **Given** a submitted form **Then** while the sign-in request is in flight the app shows 'Signing in…' and then the app navigates to the route 'deal_list'
   **Type**: widget

## Functional Requirements

- **FR-001**: The system shall present the adaptive login view with the declared platform slots (mobile, macos).
      traces: adaptive_layouts

## Lanes

```yaml
Lanes:
  - lane: CORE
    behaviors: [A1, A2]
    flutter_allowed: false
  - lane: SKIN
    behaviors: [U1, A3, A4, A5, A6, A7]
    flutter_allowed: true
    adaptive_slots: [mobile, macos]
```

## Layer Contracts

**Presentation**:

- `LoginForm`: `ShadInput` for email and password, `ShadButton` for Sign In
- `adaptive_layouts`: `mobile`, `macos`

**Domain**:

- `LoginValidation`: `isSubmittable(String email, String password) -> bool`
EOF

OUT=$($ZFA tdd plan --project "$TMP" 005-kind-matrix 2>&1)
echo "$OUT" | grep -E "typed-ledger|ui-ledger" | sed 's/^/  /'
TYPED_MD="$TMP/specs/005-kind-matrix/tdd/typed-ledger.md"
TYPED_JSON="$TMP/specs/005-kind-matrix/tdd/typed-ledger.json"
grep -q "## Per-layout kind coverage heatmap" "$TYPED_MD"; check "EC-2a: typed-ledger.md carries the per-layout heatmap section" $?
grep -qE '\| kind \| mobile \| macos \|' "$TYPED_MD"; check "EC-2b: the heatmap is the kind x slot grid" $?
grep -q '| presence |' "$TYPED_MD" && grep -q '| absence |' "$TYPED_MD" && grep -q '| navigation |' "$TYPED_MD" && grep -q '| state |' "$TYPED_MD" && grep -q '| sequence |' "$TYPED_MD"; check "EC-2c: every declared kind renders a heatmap row" $?
grep -q '"status":"untraced"' "$TYPED_JSON"; check "EC-2d: the typed JSON carries the traced|untraced status vocabulary (plan-time untraced)" $?

# The overlay binding renders the per-layout kind coverage from the
# plan's own typed rows (real invocation, no fixtures).
mkdir -p "${HELPERS}"
cat > "${HELPERS}/e2e_1134_render_heatmap.dart" <<'EOF'
import 'dart:convert';
import 'dart:io';
import 'package:zuraffa/src/tdd/services/typed_ledger_row.dart';
import 'package:zuraffa/src/tdd/services/typed_platform_ledger.dart';
import 'package:zuraffa/src/tdd/services/xray_ledger_binding.dart';

void main(List<String> args) {
  final rows = (jsonDecode(File(args[0]).readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();
  final platformRows = rows
      .where((r) => r.containsKey('slot'))
      .map(
        (r) => TypedPlatformRow(
          slot: r['slot'] as String,
          surface: r['surface'] as String,
          kind: LedgerRowKind.tryParse(r['kind'] as String?)!,
          provers: ((r['provenBy'] ?? const []) as List).cast<String>(),
          status: r['status'] as String,
        ),
      )
      .toList();
  final slots = platformRows.map((r) => r.slot).toSet().toList()..sort();
  for (final line in XrayLedgerOverlay.renderPlatformHeatmap(
    platformRows,
    slots,
  )) {
    print(line);
  }
  for (final entry in XrayLedgerDeck.platformEntries(platformRows, slots)) {
    print('deck: ${entry.label} [${entry.state}]');
  }
}
EOF
OVERLAY_OUT=$(cd "$REPO_ROOT" && dart run "${HELPERS}/e2e_1134_render_heatmap.dart" "$TYPED_JSON" 2>&1)
echo "$OVERLAY_OUT" | sed 's/^/  /'
echo "$OVERLAY_OUT" | grep -q "per-layout kind coverage"; check "EC-2e: the overlay renders per-layout kind coverage" $?
echo "$OVERLAY_OUT" | grep -qE "mobile presence [0-9]+/[0-9]+"; check "EC-2f: kind x slot cells render with traced/total counts" $?
echo "$OVERLAY_OUT" | grep -q "HIGHLIGHT"; check "EC-2g: zero-traced cells are HIGHLIGHTED (never painted as proof)" $?
echo "$OVERLAY_OUT" | grep -q "deck: mobile presence"; check "EC-2h: the deck lists (slot, kind) entries with badges" $?
echo ""

# ---------------------------------------------------------------------
# EC-3 — no view generator emits unchecked grid/table layout code:
# the plan gate refuses, the view gate refuses before any write, the
# skin builder refuses BY NAME. grid and table are probed INDEPENDENTLY
# (a shared refusal could otherwise mask one token regressing while the
# other still fails the check).
# ---------------------------------------------------------------------
echo "=== EC-3: grid/table refuse everywhere (no unchecked emission) ==="
for PAIR in "ShadGrid:G1" "table:G2"; do
  TOKEN="${PAIR%%:*}"
  BID="${PAIR##*:}"
  BIDL=$(printf '%s' "$BID" | tr '[:upper:]' '[:lower:]')
  FEATURE="006-gate-$BIDL"
  mkdir -p "$TMP/specs/$FEATURE/tdd" "$TMP/lib/tdd/$FEATURE"
  cat > "$TMP/specs/$FEATURE/spec.md" <<'EOF'
**Template Version**: `zuraffa-1.0`

# Feature Specification: 006-grid-gate — the vocabulary gate

## Acceptance Scenarios

1. **Given** the deal board **When** it renders **Then** the app shows 'Deals'
   **Type**: widget

## Functional Requirements

- **FR-001**: The system shall present the deal board.
      traces: DealBoard

## Layer Contracts

**Presentation**:

- `DealBoard`: `__TOKEN__`

**Domain**:

- `DealValidation`: `validate(String id) -> bool`
EOF
  sed "s/__TOKEN__/$TOKEN/" "$TMP/specs/$FEATURE/spec.md" \
    > "$TMP/specs/$FEATURE/spec.md.tmp"
  mv "$TMP/specs/$FEATURE/spec.md.tmp" "$TMP/specs/$FEATURE/spec.md"

  # The PLAN gate refuses the SINGLE token and writes nothing.
  OUT=$($ZFA tdd plan --project "$TMP" "$FEATURE" 2>&1)
  PLAN_EXIT=$?
  echo "$OUT" | grep -E "vocabulary gate|$TOKEN" | head -4 | sed 's/^/  /'
  [ "$PLAN_EXIT" -eq 2 ]; check "EC-3a($TOKEN): zfa tdd plan refuses $TOKEN alone (exit 2)" $?
  [ ! -f "$TMP/specs/$FEATURE/tdd/test-list.md" ]; check "EC-3b($TOKEN): the refused plan wrote no artifacts" $?

  # The VIEW gate (defense in depth): the same single token, view
  # refuses BEFORE any write.
  cat > "$TMP/specs/$FEATURE/tdd/test-list.md" <<'EOF'
# Test List: 006-grid-gate

## Layer contracts

### Presentation

- `DealBoard`: `__TOKEN__`
EOF
  sed "s/__TOKEN__/$TOKEN/" "$TMP/specs/$FEATURE/tdd/test-list.md" \
    > "$TMP/specs/$FEATURE/tdd/test-list.md.tmp"
  mv "$TMP/specs/$FEATURE/tdd/test-list.md.tmp" \
    "$TMP/specs/$FEATURE/tdd/test-list.md"
  cat > "$TMP/specs/$FEATURE/tdd/artifacts.json" <<EOF
{
  "feature": "$FEATURE",
  "records": [
    {
      "behavior_id": "$BID",
      "feature": "$FEATURE",
      "source_criterion": "FR-001",
      "test_path": "test/tdd/$FEATURE/${BIDL}_test.dart",
      "subject_path": "lib/tdd/$FEATURE/${BIDL}_subject.dart",
      "runnable_test_name": "test/tdd/$FEATURE/${BIDL}_test.dart::$BID::the deal board",
      "test_ownership": "created",
      "subject_ownership": "created",
      "created_at": "2026-09-18T00:00:00.000000Z"
    }
  ]
}
EOF
  cat > "$TMP/lib/tdd/$FEATURE/${BIDL}_subject.dart" <<EOF
library;

import 'package:flutter/material.dart';

/// View-builder subject for behavior $BID.
///
/// Throws [UnimplementedError] until the real implementation lands.
Widget subject_${BIDL}() => throw UnimplementedError('subject_${BIDL} not implemented');
EOF
  SUBJECT_G="$TMP/lib/tdd/$FEATURE/${BIDL}_subject.dart"
  BEFORE=$(cat "$SUBJECT_G")
  OUT=$($ZFA tdd view "$BID" --project "$TMP" 2>&1)
  VIEW_EXIT=$?
  echo "$OUT" | grep -E "vocabulary gate|$TOKEN" | head -3 | sed 's/^/  /'
  [ "$VIEW_EXIT" -eq 1 ]; check "EC-3c($TOKEN): zfa tdd view refuses $TOKEN alone before any write (exit 1)" $?
  [ "$BEFORE" = "$(cat "$SUBJECT_G")" ]; check "EC-3d($TOKEN): the subject is untouched (no unchecked layout code landed)" $?
done

# The skin builder: EACH layout token refuses BY NAME and writes nothing.
cat > "${HELPERS}/e2e_1134_skin_layout_probe.dart" <<'EOF'
import 'dart:io';
import 'package:zuraffa/src/core/generator_options.dart';
import 'package:zuraffa/src/models/generator_config.dart';
import 'package:zuraffa/src/plugins/skin/builders/skin_builder.dart';

Future<void> main(List<String> args) async {
  final builder = SkinBuilder(
    outputDir: args[0],
    options: const GeneratorOptions(force: true),
  );
  final files = await builder.generate(
    GeneratorConfig(name: 'Deal', outputDir: args[0]),
    {'layout': args[1]},
  );
  print('generated=${files.length}');
}
EOF
# A Flutter-flavored pubspec so the builder does not skip on flavor.
cat > "$TMP/pubspec.yaml" <<'EOF'
name: login_e2e_host
environment:
  sdk: ^3.11.0
dependencies:
  flutter:
    sdk: flutter
EOF
for LAYOUT in grid table; do
  OUT=$(cd "$REPO_ROOT" && dart run "${HELPERS}/e2e_1134_skin_layout_probe.dart" "$TMP" "$LAYOUT" 2>&1)
  echo "$OUT" | sed 's/^/  /'
  echo "$OUT" | grep -q "not implemented"; check "EC-3e($LAYOUT): the skin builder refuses layout $LAYOUT BY NAME" $?
  echo "$OUT" | grep -q "generated=0"; check "EC-3f($LAYOUT): the refusal writes no file (no silent list fall-through)" $?
  echo "$OUT" | grep -q "zfa ui schema"; check "EC-3g($LAYOUT): the refusal names the vocabulary fix" $?
done
echo ""

echo "=================================================="
echo "PASS=$PASS FAIL=$FAIL"
echo "=================================================="
# $TMP and $HELPERS are removed by the EXIT trap.
[ "$FAIL" -eq 0 ]
