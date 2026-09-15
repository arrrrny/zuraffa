**Template Version**: `zuraffa-1.0`

# Tasks: 1652-refactor-digest-gate

**Input**: Design documents from `specs/1652-refactor-digest-gate/` (spec.md, plan.md, research.md, quickstart.md)

**Prerequisites**: plan.md, spec.md; research.md records the proposal
choice (digest gate, full-inherit variant), the driver-side writer, and
the shared-helpers decision.

## 1. Behavioural (TDD red → green first) — MANDATORY, driven by the loop before T101

- [x] **T001** [behavior: A1] (P1) [US1] `test/plugins/tdd/commands/bug_1652_refactor_make_post_state_test.dart`
  — the inheritance hit: a recorded make post-state matching the current
  tree + context + a `--pass-batch` refactor spawn → ZERO suite spawns
  (logging-wrapper count unchanged), exit 0, `outcome=clean`, the
  `issue #1652` + `make-post-state` inheritance lines in stdout, a no-op
  cycle-log entry naming the behavior + capture time + green verdict,
  and `pass-batch.json` NOT rewritten. RED pre-fix (the pipeline runs:
  suite spawns happen). [FR-002/FR-004, SC-001; spec A1]
- [x] **T002** [behavior: A2] (P1) [US1] same file — tree drift: touch a file under
  `lib/` after the record → the full pipeline runs (suite spawns
  increase; no inheritance line). GREEN pre-fix (today's behavior).
  [FR-003, SC-002; spec A2]
- [x] **T003** [behavior: U1] (P2) [US2] same file — context mismatches each re-run the
  full pipeline: (a) baseline-file rewrite, (b) `dart_test.yaml`
  rewrite, (c) exempt-set difference (`--exempt-behaviors` at the
  spawn). [FR-003; spec U2.1–U2.3]
- [x] **T004** [behavior: U2] (P2) [US2] same file — corrupt/mistyped record
  (`{"lib_digest": 42}`, `{ not json}`) → full pipeline (safe failure).
  [FR-003; spec U2.4]
- [x] **T005** [behavior: U3] (P2) [US2] same file — a flag-less standalone refactor
  never reads the record (full pipeline runs), and `--full-reproof`
  never inherits. [FR-003/FR-005; spec U2.5–U2.6]
- [x] **T006** [behavior: U4] (P2) [US3] same file — ledger precedence: an existing
  `pass-batch.json` matching the tree still inherits via the #1588 path
  (its evidence line, not the record's) when both would match.
  [FR-007]
- [x] **T007** [behavior: U5] (P1) [US3] [behavior: A3] `test/plugins/tdd/run_driver_1652_make_post_state_test.dart`
  — driver level (scripted fake zfa, fast tier): a phase-1 make that
  green-applies writes `<featureDir>/tdd/make-post-state.json` whose
  `lib`/`test` digests match the on-disk trees and whose verdict names
  the behavior + outcome; the #741 already-green skip writes nothing new;
  a forced write failure prints a warning and the run proceeds. RED
  pre-fix (no record exists). [FR-001/FR-006; spec U3.1]
- [x] **T008** [behavior: U6] (P2) [US3] same file — a stale record (tree changed by a
  later step) does not affect any outcome: the next refactor spawn (run
  again on the drifted tree) runs the pipeline. [FR-006; spec U3.2]

## 2. Non-behavioural (implement to green)

- [x] **T101** (P1) `lib/src/plugins/tdd/services/make_post_state.dart`
  (NEW) — `MakePostState`: fields (capturedAt, behaviorId, suite,
  baselineKey, configKey, exemptBehaviors, libDigest, testDigest,
  greenVerdict), `matches()` mirroring `PassBatchLedger.matches`
  (order-insensitive exempt list), `read` (corrupt → null) / `write`,
  `pathFor`, reusing `PassBatchLedger`'s static key helpers. [FR-001/
  FR-002/FR-003/FR-006]
- [x] **T102** (P1) `lib/src/plugins/tdd/commands/run_driver_core.dart` —
  the `_recordMakePostState` helper + the make-green hook in
  `_driveBehavior` (gated on a new `recordMakePostState` flag, default
  false; phase-1 and phase-2a call sites pass true; warning-only
  failure). [FR-001/FR-006]
- [x] **T103** (P1) `lib/src/plugins/tdd/commands/refactor_command.dart` —
  the fast path: inside `passBatch && !fullReproof`, after the ledger
  miss, the `MakePostState` hit inherits with the honest evidence lines
  + no-op cycle-log entry (ledger keeps precedence). [FR-002/FR-004/
  FR-005/FR-007]
- [x] **T104** (P3) doc touch: the record's role noted beside the
  ledger's doc comment in `pass_batch_ledger.dart` (one paragraph, the
  frequency-engineering line updated to name the make-post-state rung).
  [FR-004]

## 3. Verification

- [x] **T201** (P1) Regression + static scope green: both new suites;
  `bug_1588_phase2_refactor_batch_and_parked_exempt_test.dart` (the
  ledger contract untouched); `run_command_test.dart` +
  `refactor_command_test.dart` (driver + command neighbors);
  `dart analyze` on changed files → zero findings; `dart format` clean.
  [SC-002/SC-003]

## Dependencies & Execution Order

- T001–T006 are command-level and independent of T101–T103; T001 is
  written FIRST and proven red (the pipeline runs today) before T103.
- T007/T008 are driver-level; T007 red (no record written) before T102.
- T101 lands with the tests that need the type to compile? NO — the red
  suites drive the CLI/fake-zfa surfaces only; T101 is needed by T102/
  T103 and lands in the green step.
- T201 runs last, after T102/T103 turn both suites green.

## MVP Scope

US1 (T001 + T002 + T101 + T102 + T103) delivers the perf fix end to end:
make-green records the post-state, the next spawn inherits it, drift
falls back. US2 pins the safety envelope; US3 the record's honesty.
