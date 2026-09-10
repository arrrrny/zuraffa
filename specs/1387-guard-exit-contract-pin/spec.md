**Template Version**: `zuraffa-1.0`

# Spec: 1387-guard-exit-contract-pin

GitHub issue: arrrrny/zuraffa#1387 (verify-misfire / spec-drift, EPIC #1132
Phase A steps 1-2 — exit-code sweep)

## Summary

The SAME guard condition (a Flutter-dependent plugin refuses to generate
on a pure-Dart package) exits differently by entry point: the
orchestrator (`zfa make <E> view --no-entity`) skips and exits 0 (other
lanes still drive), while the standalone verb
(`zfa controller create <E>`) refuses with exit 1. Both are defensible;
neither was pinned — fleet automation could not interpret the classes.

## Locked decisions

1. Test-only cycle: pin BOTH contract halves —
   B1 orchestrator: skipped plugin → exit 0 with the Done note;
   B2 standalone: guard-skip → exit 1 with the no-files note.
2. No production change: both behaviors are defensible by design
   (orchestrator continues past skipped plugins; standalone has nothing
   to show) — the drift was the ABSENCE of a contract, not a bug.
3. A future unification (a shared "nothing generated" exit class) would
   change one of these halves and fail the pin loudly — by intent.

## Functional requirements

- **FR-1**: the orchestrator's skipped-plugin contract (exit 0 + Done).
- **FR-2**: the standalone guard-skip contract (exit 1 + no-files note).

## Acceptance scenarios

1. `make User view --no-entity` on a pure-Dart package → exit 0 (B1).
2. `controller create Product` on a pure-Dart package → exit 1 (B2).

## Success criteria

- **SC-001**: The asymmetry is documented and pinned — drift in either
  direction fails a test.

## Assumptions

- Shell automation treats the two entry points as different contracts
  (orchestrator aggregation vs single-surface generation).
