---
feature: 1623-integration-timeout-budget
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 4
planned_at: 26a6fc0
updated_at: 26a6fc0
suite_baseline: green
---

# Test List: Integration timeout budget (bug #1623)

The behavior under test is the helper's budget DECISION surface — which
budget a `runZfaSource` spawn spends, derived from the spawn shape and
`ZFA_TEST_TIMEOUT_SCALE` — plus the loud compile-timeout diagnostic the
no-JIT policy raises when the AOT budget is missed. The loop is
outside-in at the helper's seams: every unit behavior is fast-tier and
subprocess-free (house rule for `test/helpers` tests), and the end-to-end
proof is the real B9b integration run recorded in the verification
artifact.

## Outer loop: helper budget decisions

### The cold-source spawn budget (SC-3)

| id | behavior                                                                                                                                         | traces | kind    | state | test                                                                                                                                                                              |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------ | ------ | ------- | ----- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| R1  | `zfaColdSourceChildTimeout` is 240s stretched by the process scale and is `>= 240s` at every valid scale (the scale relaxes, never tightens)       | SC-3   | example | DONE  | `test/helpers/zfa_test_timeout_scale_test.dart::cold source spawn budget: first cold source spawn budget is 240s stretched by the process scale`                                    |
| R2  | `resolveChildTimeout` spends the COLD budget on the first source spawn (sourceSpawn + coldBudgetAvailable + no explicit timeout) — not the 75s guard | SC-3   | example | DONE  | `...zfa_test_timeout_scale_test.dart::cold source spawn budget: the FIRST source spawn spends the cold budget instead of the 75s guard`                                             |
| R3  | `resolveChildTimeout` spends the default 75s guard on later source spawns (budget already spent) and on every compiled-binary spawn                  | SC-3   | example | DONE  | `...zfa_test_timeout_scale_test.dart::cold source spawn budget: later source spawns and compiled-binary spawns spend the default 75s guard`                                         |
| R4  | `resolveChildTimeout` returns an explicit caller timeout verbatim on every path (explicit budgets are never auto-scaled — documented semantics)      | SC-3   | example | DONE  | `...zfa_test_timeout_scale_test.dart::cold source spawn budget: an explicit caller timeout wins verbatim on every path`                                                             |

## Regression pins (green-before-write by design — 06ecc54 shipped them)

| id | behavior                                                                                                                                               | traces | kind             | state | test                                                                                                                                     |
| --- | ------------------------------------------------------------------------------------------------------------------------------------------------------ | ------ | ---------------- | ----- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| R5  | A compile that misses its DEADLINE (runner fails with `TimeoutException`) raises `ZfaCompilationException` (exit −1) whose reason names the budget AND the `ZFA_TEST_TIMEOUT_SCALE` remedy — the loud #1623 diagnostic, never silent | SC-2   | characterization | DONE  | `test/cli/zfa_executable_test.dart::U11: a compile that misses its budget deadline raises a loud diagnostic naming the scale remedy`       |
| P1  | Pre-existing #1187 pins stay green: 75s child guard × scale, 100s compile budget × scale, `scaleDuration` proportionality, parse/clamp matrix                          | SC-3   | characterization | DONE  | `test/helpers/zfa_test_timeout_scale_test.dart` (existing groups, unchanged)                                                              |
| P2  | `commandFor` still refuses a `.dart` entrypoint without the hatch (a source spawn exists ONLY under `ZFA_ALLOW_JIT=1`) — the cold budget is unreachable without it      | SC-2   | characterization | DONE  | `test/cli/zfa_executable_test.dart` U10 (existing, unchanged)                                                                             |

## End-to-end proof (recorded, not unit-hosted)

| id | behavior                                                                                                                                             | traces | kind    | state | test                                                                                                |
| --- | ---------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | ------- | ----- | ---------------------------------------------------------------------------------------------------- |
| E1  | B9b runs green on this host WITHOUT the manual `timeout: 240s` override — the helper's scaled default governs the scaffold spawn (assertion flow unchanged) | SC-1   | example | DONE  | `dart test --preset=integration test/package_sdk/plugin_scaffold_e2e_test.dart -n B9b` (verification.md) |

## Invariants and edge cases still to place

- The 240s base must sit below B9b's 6-minute and B9's 8-minute const
  ceilings at scale 1.0 (the guard fires before the ceiling): asserted by
  R1's `>= 240s` clamp direction plus the constant's documented value —
  a suite-level ceiling is not unit-hostable without the integration run.
- The spent-once semantics of `_zfaColdSourceBudgetSpent` are exercised
  through `resolveChildTimeout`'s `coldBudgetAvailable` parameter (pure);
  the mutable flag itself is 3 lines of wiring inside `runZfaSource`,
  covered by E1 end-to-end and `dart analyze`.
- Explicit-timeout call sites (B9's per-package pub get/analyze/test
  budgets live on a LOCAL `_runSupervised`, not `runZfaSource`) are
  untouched by the matrix — R4 pins the resolver's verbatim passthrough.
