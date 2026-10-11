**Template Version**: `zuraffa-1.0`

# Spec: 1372-certified-red-scan-pin

GitHub issue: arrrrny/zuraffa#1372 (verify-misfire / missing-integration,
EPIC #1012 Phase A step 6, #1008)

## Summary

`zfa tdd make A1` refused with `has no certified-red evidence` immediately
after `zfa tdd verify-red A1` certified red: `_hasCertifiedRed`
early-returned on the FIRST behavior-matching cycle-log section, so a
stale `kind: error` section shadowed the later certified red. Root cause
already fixed on master by 583d711d (issue #1353: scan every section,
return true when any matching section is kind: red) — committed 05:41
UTC, before the issue was filed at 06:34 UTC; the verify branch was cut
from a stale tree. What the fix shipped WITHOUT is a regression test for
the exact [error, red] shape the issue names.

## Locked decisions

1. This cycle delivers the MISSING REGRESSION PIN only: a cycle-log with
   [error, red] ordering for one behavior must let make proceed past the
   certified-red gate (the issue's own suggested test).
2. Honest refusals pinned alongside: [error] alone still refuses
   (exit 1) — the scan is not a blanket pass.
3. No production code changes: the scan behavior on master is correct.

## Functional requirements

- **FR-1**: [error, red] cycle-log → make proceeds (no
  `has no certified-red evidence`).
- **FR-2**: [red] alone → make proceeds (shape unchanged).
- **FR-3**: [error] alone → make refuses with the certified-red message
  (exit 1).

## Acceptance scenarios

1. make over [error, red] → no certified-red refusal (B1).
2. make over [red] → no certified-red refusal (B2).
3. make over [error] → the refusal + exit 1 (B3).

## Success criteria

- **SC-001**: The verify-red → make evidence handoff can never silently
  regress to first-section early-return.
- **SC-002**: The make suites stay green.

## Assumptions

- The stale-branch misfire is closed by commenting this evidence on the
  issue; the pin is the durable artifact.
