# Cycle Log: 1623-integration-timeout-budget

Append-only. One entry per TDD cycle (spec 046 / TDD extension v1.1.2).

## Cycle: T001 (red)

- behavior: R1, R2, R3, R4
- kind: red
- classification: compileError (the API under test does not exist yet)
- criterion: SC-3 (spec.md) — first cold source spawn budget
- test: `test/helpers/zfa_test_timeout_scale_test.dart` — group
  `cold source spawn budget` (R1 scale+clamp, R2 first-spawn matrix,
  R3 default-guard matrix, R4 explicit-wins matrix)
- command: `dart test test/helpers/zfa_test_timeout_scale_test.dart`
- exit: 1
- at: 2026-09-15T11:40:00Z
- output:
```
error - zfa_test_timeout_scale_test.dart:106:11 - Undefined name
'zfaColdSourceChildTimeout'.
error - zfa_test_timeout_scale_test.dart:116:22 - The function
'resolveChildTimeout' isn't defined.
... (8 issues found: 2x undefined identifier, 6x undefined function)
00:00 +0 -1: Some tests failed.
Failing tests:
  test/helpers/zfa_test_timeout_scale_test.dart: loading
  test/helpers/zfa_test_timeout_scale_test.dart
```
- reading: the budget decision surface does not exist at HEAD (26a6fc0) —
  `runZfaSource` computes `timeout ?? zfaDefaultChildTimeout` with no
  spawn-shape awareness, so the first cold source spawn is budgeted by the
  flat 75s guard (the exact #1623 shape under `ZFA_ALLOW_JIT=1`). A
  syntax slip in the first edit (the `scaled budgets` group's closing
  brace was consumed) was caught by analyze and fixed BEFORE recording
  this entry — the 8 remaining errors are precisely the intended
  undefined-API reds, no parser noise.

## Cycle: T001-pin (R5 — green-before-write by design)

- behavior: R5 (U11)
- kind: pin (NOT a red — declared, per the 1505 honesty convention)
- classification: pass
- criterion: SC-2 (spec.md) — loud compile-timeout diagnostic
- test: `test/cli/zfa_executable_test.dart` — `U11: a compile that misses
  its budget deadline raises a loud diagnostic naming the scale remedy`
- command: `dart test test/cli/zfa_executable_test.dart`
- exit: 0
- at: 2026-09-15T11:41:00Z
- output:
```
00:00 +19: All tests passed!
```
- reading: the deadline-kill diagnostic (`ZfaCompilationException`, exit
  −1, reason naming the budget + `ZFA_TEST_TIMEOUT_SCALE`) was shipped by
  the no-JIT spawn policy (commit 06ecc54, two days AFTER #1623 was
  filed). The behavior is correct at HEAD; U11 pins it so the #1623
  slow-host scenario cannot regress to a silent fallback unnoticed.

## Cycle: T002 (green)

- behavior: R1, R2, R3, R4
- kind: green
- classification: pass
- criterion: SC-3 (spec.md)
- change: `test/helpers/run_zfa_source.dart` ONLY —
  `kZfaColdSourceBaseTimeout` (240s) + `zfaColdSourceChildTimeout`
  (scaled getter) + pure `resolveChildTimeout` + `_zfaColdSourceBudgetSpent`
  wiring in `runZfaSource` (first no-explicit source spawn spends the cold
  budget). In-cycle honesty note: two mechanical slips caught by analyze
  before the green run — the call site passed the timeout positionally
  (extra_positional_arguments) and the earlier `exe!` made a later `exe!`
  redundant (unnecessary_non_null_assertion); both fixed within the cycle,
  no test edited.
- command: `dart test test/helpers/zfa_test_timeout_scale_test.dart test/cli/zfa_executable_test.dart`
- exit: 0
- at: 2026-09-15T11:52:00Z
- output:
```
Analyzing run_zfa_source.dart, zfa_test_timeout_scale_test.dart,
zfa_executable_test.dart...
No issues found!
00:00 +31: All tests passed!
```
- reading: R1-R4 flipped red→green against the new API (240s x scale,
  first-spawn matrix, default-guard matrix, explicit-wins matrix); R5 and
  the pre-existing #1187 pins stayed green — no regression in the scaled
  75s/100s budgets.
