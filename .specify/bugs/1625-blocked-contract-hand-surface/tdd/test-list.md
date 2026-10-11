# TDD Test List — bug 1625 (blocked-contract hand surface names the subject seam + entity-gated wire hint)

- **Slug**: 1625-blocked-contract-hand-surface
- **Source**: https://github.com/arrrrny/zuraffa/issues/1625
- **Test file**: `test/plugins/tdd/commands/bug_1625_blocked_hand_surface_subject_test.dart`
- **Tier**: fast (fake-zfa fixture, no `dart test` spawn — kernel-cache-safe rule)

## Behaviors

| # | Behavior (from the acceptance criteria) | Pinning test(s) | Status |
|---|------------------------------------------|------------------|--------|
| B1 | `seamPathFor` names an existing SUBJECT seam over an existing generated test | `an existing subject is named over an existing test` | RED→GREEN |
| B2 | `seamPathFor` falls back to the existing #827 test when no subject exists | `a test-only project still names the existing test (fallback)` | pre-existing (guard) |
| B3 | `seamPathFor` with nothing on disk: canonical display fallback is the SUBJECT path | `nothing on disk: the canonical display fallback is the SUBJECT path…` | RED→GREEN |
| B4 | `hintLine` prints the with-entity wire example ONLY when the entity exists | `entity exists: the with-entity wire example is printed` | pre-existing (guard) |
| B5 | `hintLine` with entity MISSING prints the hand-implement instruction + `zfa entity create` prerequisite, never a failing wire command | `entity MISSING: the hand-implement instruction is printed instead…` | RED→GREEN |
| B6 | `hintLine` with an undotted contract keeps the bare wire example (#1589 degradation unchanged) | `undotted contract: no entity to check, the bare wire example stands…` | pre-existing (guard) |
| B7 | AC-1/AC-4 — a fresh spec's first blocked behavior: run park note names the subject seam, not the generated test | `the park note names the SUBJECT, not the generated test` | RED→GREEN |
| B8 | AC-2/AC-3 — the run blocked hint carries the hand-implement instruction when no entity exists (and the #1007/#1544 stop contract is untouched) | `with no entity on disk the hint carries the hand-implement instruction…` | RED→GREEN |
| B9 | AC-2 — with the entity on disk the with-entity wire example prints again | `with the entity on disk the with-entity wire example is printed` | RED→GREEN |
| B10 | the terminal `result=blocked` block names the subject seam too | `the terminal result=blocked block names the subject seam too` | RED→GREEN |
| B11 | AC-3 — `make` on a parked contract names the SUBJECT seam + the entity-create prerequisite | `make on a parked contract names the SUBJECT seam + the entity-create prerequisite…` | RED→GREEN |

## Regression guards (pre-existing suites re-run against the fix)

- `bug_1589_contract_blocked_resume_test.dart` — the #1589 hand-surface pins
  (fixtures now seed the `User` entity so the with-entity pins exercise the
  entity-present shape; the seam-path pins keep the test-fallback shape).
- `verify_red_command_test.dart`, `verify_red_subdirectory_test.dart`,
  `contract_blocked_e2e_1007_test.dart`, `bug_1544_run_continue_after_blocked_test.dart`
  — the #1007 block gate, receipt contract and park semantics are untouched.
- `wire_command_test.dart` — the wire mechanics are untouched.
- `contract_kind_1007_test.dart`, `contract_satisfied_with_rejection_e2e_1541_test.dart`
  — the contract lane is untouched.
