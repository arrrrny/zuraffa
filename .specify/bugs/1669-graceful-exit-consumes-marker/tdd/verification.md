# TDD Verification: 1669-graceful-exit-consumes-marker

- **Slug**: 1669-graceful-exit-consumes-marker
- **Verified**: 2026-09-16
- **Method**: real red → green over the REAL in-process make pipeline
  (CliRunner + TddFixture — the issue #1308 driver-suite convention the
  spec-1398 recovery file uses), plus deliberate-mutant sampling per the
  TDD profile's rubric (no mutation tool is wired), plus the shipped
  spec-1398 regression pins.
- **Deterministic-engine note**: `zfa tdd plan` drove the test-list
  derivation (5 acceptance behaviors, TUPEC-routed); `zfa tdd run` /
  `zfa tdd verify` were not dispatched because this bug directory has no
  `tdd/artifacts.json` scope for the step-spawning pipeline — the subject
  under fix is this repository itself, so the loop evidence is the
  driver-level run below (the established bug-dir pattern, cf.
  1483-vacuous-green-remedy-wrong-file).
- **Result**: verified — every check below is from an ACTUAL run in this
  session on the fix branch; nothing is copied or back-dated.

## Checks

| # | Check | Command | Result | Evidence |
|---|-------|---------|--------|----------|
| 1 | Analyzer, touched files | `dart analyze lib/src/plugins/tdd/commands/make_command.dart lib/src/plugins/tdd/services/make_interrupt.dart lib/src/plugins/tdd/models/generation_plan.dart test/plugins/tdd/bug_1669_refusal_keeps_crash_marker_test.dart` | PASS | `No issues found!` |
| 2 | RED (pre-fix) — the wedge | `dart test test/plugins/tdd/bug_1669_refusal_keeps_crash_marker_test.dart -j 1` on the tests alone | FAIL × 2 — the RIGHT failures | A1 + A4: `Expected: not null / Actual: <null>` — the not-certified-red refusal consumed the live crash record (the issue's defect, byte-for-byte) |
| 3 | Pins green pre-fix | same run | PASS × 2 | A2 (drift-free consumes) + A3 (clean-begin consumes) — unchanged contracts held before the fix |
| 4 | GREEN (post-fix) | same command, fix applied | PASS | `00:03:48 +4: All tests passed!` — A1 marker SURVIVES the refusal with the `issue #1669` note; A4 wedge → refusal keeps marker → certified red restored → `adopted-interrupted` exit 0, current-hash green evidence, marker consumed |
| 5 | Mutation sample M1 — drop the crash-provenance clause | funnel condition `if (_interruptCrashDriftLive())` (no `_interruptInherited`) | KILLED by A3 | `Expected: null / Actual: {…marker…}` — the clean-begin hand-edit refusal kept a forged crash record |
| 6 | Mutation sample M3 — drop the born-green-placeholder carve-out | `if (false) return false; // MUTANT` over the placeholder check | KILLED by spec-1398 A3 | `Expected: null / Actual: {…}` — the vacuous-class refusal kept the marker (the shipped SC-4 hygiene pin fires) |
| 7 | Regression — spec-1398 unit contract | `dart test test/plugins/tdd/bug_1398_marker_contract_test.dart -j 1` | PASS | `+4: All tests passed!` (U1–U4) |
| 8 | Regression — spec-1398 recovery e2e (incl. SIGKILL harness) | `dart test test/plugins/tdd/bug_1398_make_interrupt_recovery_test.dart -j 1` | PASS | `08:36 +6: All tests passed!` — A1 (SIGKILL → adoption), A2 (hand-edit refuses), A3 (placeholder consumes — the A5 carve-out), U5 (drift-free consumes), U6/U7 (driver tokens) |
| 9 | Format gate | `dart format` on the 4 touched files (repo-wide `dart format lib test` at commit time: 2715 files, 0 changed) | PASS | clean |
| 10 | Analyzer, repo lib/ | `dart analyze lib` | PASS (no new issues) | 106 pre-existing info-level lints, 0 errors/warnings, none in touched files |

## Red evidence (check #2, verbatim from the run)

```
00:10 +0 -1: ... A1: inherited marker + implemented crash mutation +
not-certified-red refusal → the marker SURVIVES the graceful exit [E]
  Expected: not null
    Actual: <null>
  the refusal must not consume a live crash record: zfa tdd make: behavior A1
     interrupt marker: the previous make of "A1" died mid-flight (issue #1398) ...
  zfa tdd make: behavior "A1" has no certified-red evidence in cycle-log.md. ...
  make: behavior=A1 outcome=not-certified-red feature=090-bug-1669-marker-wedge
```

The refusal transcript shows the full wedge: inherited-marker note →
unrelated refusal → marker consumed → next resume would read
byte-identical to the dishonest hand-edit class.

## Mutation coverage rationale

Sampled the two clauses whose loss re-opens a distinct honesty hole
(M1: forged crash records for the #1036 hand-edit class; M3: marker
legitimizing the vacuous class). The remaining clauses are pinned by the
scenario matrix: drift-comparison inversion → A1; fail-open on
hashless/missing I/O → U5 (spec-1398); adopting-exit consumption → A4 +
spec-1398 A1/U6/U7.

## Acceptance-criteria coverage (tdd/test-list.md)

| Behavior | Scenario | Evidence |
|----------|----------|----------|
| A1 | wedge refusal keeps the marker | check #2 → #4 (RED → GREEN) |
| A2 | drift-free refusal consumes | check #3/#4 (pin, green both sides) |
| A3 | clean-begin refusal consumes (no forged record) | check #3/#4 + mutant M1 kill |
| A4 | the kept marker un-wedges the resume | check #2 → #4 (RED → GREEN) |
| A5 | placeholder class keeps consuming | check #8 (spec-1398 A3 pin, regression-run) |

## Not covered / residual

- The heavyweight `zfa tdd run`-driven end-to-end sweep and the full repo
  fast tier were not re-run to completion in this session: the local
  shared-TMPDIR was contended by a concurrent session on the sibling
  checkout (kernel-cache and lock-file crossfire), which poisons any
  long lane regardless of this change. The fix touches only the marker
  clear/keep branch inside `_printSummary`; the parallelism hazard that
  pollutes long local lanes is tracked and fixed separately (serial
  dart_core lane, PR #1682).
- CI (pristine runner) is the authoritative gate for the broader suite.
