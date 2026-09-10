**Template Version**: `zuraffa-1.0`

# Spec: 1380-reset-namespace-guard

GitHub issue: arrrrny/zuraffa#1380 (verify-misfire / missing-integration,
EPIC #1136 Phase C / #967 — `zfa tdd reset 004-login-ui` deleted 98
tracked foreign files)

## Summary

The drift-recovery scan in `reset` walked the shared `test/tdd` +
`lib/tdd` lanes and matched files by BARE behavior id (A1, U1 — ids
shared across features) plus the generated shape. The foreign check only
consulted LIVE registries, so files whose registry rows were gone (or
never existed) fell through and were deleted: 98 tracked files across
072-079 features. The scan's header check alone is not global ownership.

## Locked decisions

1. Namespace guard in the drift-recovery scan: a recovered candidate must
   live in THIS feature's namespace — the directory segment after the
   lane root (`test/tdd/<feature>/…`, `lib/tdd/<feature>/…`) must equal
   the feature being reset. A candidate under another feature's namespace
   is foreign: kept and reported by name (the existing
   foreign-owned-looking channel).
2. Flat (pre-namespaced) candidates directly under the lane root keep the
   header-match behavior — the original #1331 recovery intent.
3. The bug #874 registry-based foreign check is retained unchanged
   (defense in depth behind the namespace guard).
4. No changes to reset's own-namespace deletion, run-state reset, or
   journal tombstones.

## Functional requirements

- **FR-1**: another feature's generated file (same bare id) survives a
  reset of this feature.
- **FR-2**: this feature's own drifted file is still recovered and
  deleted (#1331 unchanged).

## Acceptance scenarios

1. reset 004-login-ui with foreign files test/tdd/072-crypto/a1_test.dart,
   test/tdd/073-offline/u1_test.dart, lib/tdd/077-reader/a1_subject.dart
   (headers naming A1/U1, no registries) → all three survive; the own
   pair is deleted (B1).
2. A drifted own-namespace file → recovered and deleted (B2).

## Success criteria

- **SC-001**: A reset can never again sweep files outside its feature
  namespace — the issue's 98-file data-loss shape is impossible.
- **SC-002**: The tdd command suites stay green.

## Assumptions

- Feature namespaces are the directory segment after the lane root — the
  layout every gen/write path uses (test/tdd/<feature>/…).
