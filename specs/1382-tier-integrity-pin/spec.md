**Template Version**: `zuraffa-1.0`

# Spec: 1382-tier-integrity-pin

GitHub issue: arrrrny/zuraffa#1382 (verify-misfire / spec-drift, EPIC #1132
Phase A/B — exit criterion 1, honesty-sweep regression gate integrity)

## Summary

The epic regression exit criterion as written (`dart test
test/regression/`) was a FALSE GREEN: dart_test.yaml excludes `slow` by
default, so the literal invocation loaded ~12 of the tier's 64 files and
exited 0 while 81% of the tier never executed. Any future exit-0-on-error
regression tagged `slow` would be invisible to this gate.

## Locked decisions

1. Test-only cycle (the issue's remedy 3, implementable form): a
   fast-tier integrity pin (`test/tier_integrity_test.dart`) asserting
   (a) every `test/regression/*_test.dart` carries the `regression` tag —
   so `dart test --preset=regression` covers 100% of the tier — and (b)
   dart_test.yaml defines the regression preset.
2. The three untagged regression files (issue_1173, issue_1188,
   issue_891) are tagged `regression` — previously they ran only in the
   literal invocation and were invisible to the preset.
3. Remedy 1 (updating the epic's exit criterion to
   `--preset=regression`) is recorded on the issue — an epic-side edit.
4. The spawn-based mismatch guard was REJECTED: inside the targeted tier
   it cannot distinguish the invocation shape (and would recurse);
   documented in the cycle log.
5. No production code changes; the fast tier gains one hermetic pin.

## Functional requirements

- **FR-1**: every regression-tier test file carries the `regression` tag.
- **FR-2**: dart_test.yaml defines the regression preset.

## Acceptance scenarios

1. The tier exists and is non-trivial (>10 files).
2. Every tier file is preset-covered (B1).
3. The preset exists in dart_test.yaml (B2).

## Success criteria

- **SC-001**: `dart test --preset=regression` covers 100% of the tier —
  the false-green shape can not recur silently.
- **SC-002**: The package-level suites stay green.

## Assumptions

- The epic exit criterion text is updated epic-side to the honest
  invocation (recorded in the issue comment).
