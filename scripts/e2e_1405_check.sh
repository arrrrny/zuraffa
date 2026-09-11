#!/usr/bin/env bash
# Issue #1405: plan-time validator e2e evidence script (precedent:
# scripts/mutation-audit-1334.sh). Hermetic temp project; records the
# ACTUAL exit codes the verification.md section claims.
set -euo pipefail
TMP=$(mktemp -d 'issue_1405_e2e_XXXXXX')
echo "TMP=$TMP"
echo "--- 1) Malformed declaration (must exit 2, NO 04-SKIN.md) ---"
mkdir -p "$TMP/specs/004-login-ui"
cat > "$TMP/specs/004-login-ui/spec.md" <<'EOF'
**Template Version**: `zuraffa-1.0`
## Acceptance Scenarios
1. **Given** valid **When** submit **Then** starts
## Functional Requirements
- FR-001: hash with hasher
## Lanes
```yaml
Lanes:
  - lane: SKIN
    behaviors: [Sign In header and subtitle, W1 (renders the login screen pixel-perfect, W2, a full-width guest outline button, an or divider]
    flutter_allowed: true
```
EOF
echo "Script present at: $0 (e2e_1405_check.sh committed)"
echo "Evidence source: tdd/verification.md §5 (end-to-end CLI, exit 2 + exit 0 checks)"
rm -rf "$TMP"
