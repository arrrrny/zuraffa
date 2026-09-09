**Template Version**: `zuraffa-1.0`

# Spec: 1375-adopt-preserves-refined

GitHub issue: arrrrny/zuraffa#1375 (verify-misfire, EPIC #1136 Phase C /
spec-mutation arena #967 — blocked the 004-login-ui spec-fuzz preflight)

## Summary

The issue reports `zfa tdd gen <id> --adopt` on an OWNED but hand-refined
test file silently REGENERATING the guard test (destroying the hand-delta,
leaving the suite red). On current master the repro DOES NOT reproduce:
both `gen --adopt` and plain `gen` preserve a progressed (hand-refined)
test — the #1320-era progression guard refuses to clobber a test whose
subject no longer matches the bare stub shape, and the reused-ownership
path keeps the file verbatim. What master ALSO lacked is a regression pin
for exactly this preservation contract — the issue's own scenario.

## Locked decisions

1. Test-only cycle: pin the preservation contract (with AND without
   `--adopt`, plus idempotence). No production change — the observed
   master behavior is already the desired one.
2. The pin uses the issue's own shape: an owned test file, hand-refined
   with the provenance header + behavior id preserved and an authored
   assertion set, then `gen --adopt` / plain `gen` must keep the
   authored bytes.

## Functional requirements

- **FR-1**: `gen --adopt` over a hand-refined owned test preserves the
  authored bytes (B1).
- **FR-2**: plain `gen` over a hand-refined owned test preserves them too
  (the #1320 progression guard) (B2).
- **FR-3**: repeated `gen --adopt` keeps the refinement (idempotence)
  (B3).

## Acceptance scenarios

1. Refine → `gen --adopt` → authored assertion survives (B1).
2. Refine → plain `gen` → authored assertion survives (B2).
3. Refine → two consecutive `gen --adopt` runs → authored assertion
   survives (B3).

## Success criteria

- **SC-001**: The spec-fuzz preflight for 004-login-ui stays green across
  gen re-invocations (the refinement is never destroyed).
- **SC-002**: The tdd command suites stay green.

## Assumptions

- The issue's regeneration could not be reproduced on current master —
  recorded in the PR; if a regeneration path reappears, this pin fails
  by construction.
