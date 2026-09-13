# TDD Cycle Log — 1472-refactor-build-gate-warnings

Loop driver: manual red-green-refactor per `tdd/test-list.md` (spec-kit TDD
extension contract; evidence recorded per behavior). Suite baseline of the
zuraffa repo itself: green on the touched suites pre-change.

## Cycle: U-1472-1 (registry decision table — the deadlock)

- kind: red
- behavior: U-1472-1
- verdict: failed for the right reason
- command: `dart test test/plugins/tdd/bug_1472_refactor_gate_errors_only_test.dart`
- exit: 1
- timestamp: 2026-09-13T09:20:00Z
- evidence: `00:00 +0 -1: ... U-1472-1: a warnings-only build-gate refusal
  does NOT misfire-stop — format and fix still run [E]` — the registry
  misfire-stopped on the warnings-only refusal (pre-fix FR-010 semantics),
  so `format`/`fix` never ran and `result.stopped` was true. Companion reds
  in the same run: U-1472-3 (no accurate-counts log) and U-1472-11 (no
  version pin — the stale PATH zfa was used verbatim).

- kind: green
- behavior: U-1472-1
- verdict: passed
- command: `dart test test/plugins/tdd/bug_1472_refactor_gate_errors_only_test.dart`
- exit: 0
- timestamp: 2026-09-13T09:34:00Z
- evidence: `00:00 +13: All tests passed!` — build refusal tolerated,
  invocations `[build, format, fix]`, `result.completed` true. The minimal
  change: `RefactorPasses.run()` re-grades a failed `build` pass through
  `_isWarningsOnlyBuildGateRefusal` (gate verdict line + shared
  `BuildCommand.analyzeReportsError` cross-check, spawn/timeout guards)
  before the misfire-stop.

## Cycle: U-1472-2..U-1472-10 (decision table guards + SC-3/SC-4/SC-5)

- kind: green
- behavior: U-1472-2, U-1472-3, U-1472-4, U-1472-5, U-1472-6, U-1472-7,
  U-1472-8, U-1472-9, U-1472-10
- verdict: passed
- command: `dart test test/plugins/tdd/bug_1472_refactor_gate_errors_only_test.dart`
- exit: 0
- timestamp: 2026-09-13T09:34:00Z
- evidence: same run, `+13: All tests passed!`. U-1472-2 (honest exit 1 in
  the recorded action), U-1472-4 (errors keep the misfire-stop), U-1472-5
  (non-gate failure class), U-1472-6 (message/parser disagreement keeps the
  honest stop), U-1472-7 (`warningsBlocking` opt-in), U-1472-8 (timeout),
  U-1472-9 (spawn failure), U-1472-10 (arm is build-only) — the guards were
  green in the red run too (they pin behavior that must not change) and
  stayed green after the fix. U-1472-3 flipped red→green with the
  accurate-counts log line (`0 error(s), 2 warning(s) ... non-blocking`).

## Cycle: U-1472-11..U-1472-13 (binary pinning)

- kind: red
- behavior: U-1472-11
- verdict: failed for the right reason
- command: `dart test test/plugins/tdd/bug_1472_refactor_gate_errors_only_test.dart`
- exit: 1
- timestamp: 2026-09-13T09:20:00Z
- evidence: `00:00 +8 -3: ... U-1472-11: a PATH zfa whose version differs
  from the driving CLI is NOT used — the build pass pins to the driving
  entrypoint [E]` — pre-fix, the #717 chain used the stale PATH zfa
  verbatim (`expect(build.command, isNot(contains(zfaPath)))` failed).

- kind: green
- behavior: U-1472-11, U-1472-12, U-1472-13
- verdict: passed
- command: `dart test test/plugins/tdd/bug_1472_refactor_gate_errors_only_test.dart`
- exit: 0
- timestamp: 2026-09-13T09:34:00Z
- evidence: `+13: All tests passed!` — with the probe/pin in
  `zfaBuildCommand` the transcript carries `build pass: system zfa on PATH
  is v0.0.9 — pinned to the driving CLI v6.2.2 (issue #1472).`; the
  equal-version and unprovable-version cases keep the #717 candidate
  byte-identically.

## Cycle: A-1472-1..A-1472-3 (acceptance — the issue's reproduction shape)

- kind: red
- behavior: A-1472-1
- verdict: failed for the right reason (pre-fix, inferred from the registry
  red: the command grades a stopped registry `outcome=runner-error`,
  refactor_command.dart `if (passResult.stopped)`)
- command: `dart test --preset=integration test/plugins/tdd/bug_1472_refactor_gate_acceptance_test.dart`
- evidence: A-1472-1 asserts `outcome=(clean|refactored)` + exit 0; with the
  pre-fix registry the only reachable grading for a failed build pass is
  `pass "build" failed — misfire-stop.` + `outcome=runner-error` + exit 1
  (the issue's transcript), so the assertion cannot hold pre-fix.

- kind: green
- behavior: A-1472-1, A-1472-2, A-1472-3
- verdict: passed
- command: `dart test --preset=integration test/plugins/tdd/bug_1472_refactor_gate_acceptance_test.dart`
- exit: 0
- timestamp: 2026-09-13T09:52:00Z
- evidence: `00:24 +3: All tests passed!` — A-1472-1 (warnings-only refusal
  → clean/refactored, exit 0, accurate counts on the transcript), A-1472-2
  (errors refusal → `pass "build" failed — misfire-stop.` +
  `outcome=runner-error`, exit != 0), A-1472-3 (`analyze-gate:
  warnings-blocking` in the fixture profile restores the legacy refusal).
