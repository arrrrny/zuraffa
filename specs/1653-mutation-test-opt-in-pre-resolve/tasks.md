# Tasks: 1653-mutation-test-opt-in-pre-resolve

Dependency-ordered, MVP-first. MVP = FR-001..003 (opt-in default-off) —
that alone removes the fresh-project cold cost (SC-4). The pre-resolve
(FR-004/005) and receipt timing (FR-006..008) build on it.

- [x] T001 Write the feature spec (spec.md, zuraffa-1.0 grammar, #1186
      Type markers + traces) and run `zfa tdd plan` for real — the test
      list is tool-generated, not hand-copied. (depends: —)
- [x] T002 Write plan.md (technical context, design decisions, hazard
      check, verification strategy). (depends: T001)
- [ ] T003 RED: `test/plugins/tdd/bug_1653_init_opt_in_and_preresolve_test.dart`
      — patcher default excludes `mutation_test`; `includeMutationTest:
      true` injects `^1.8.0`; static maps keep the #755 pin;
      `TddBaselineInit(mutation: true|false)` threading; pre-resolve
      fires on newly-added deps, skips on idempotent pass, misfires on
      non-zero resolver exit, warns (no misfire) on missing binary;
      `zfa tdd init --mutation` CLI wiring. Record the real red output.
      (depends: T002)
- [ ] T004 RED: `test/plugins/tdd/bug_1653_refactor_phase_timings_test.dart`
      — `RefactorAction.duration` recorded per pass (null when skipped);
      `CycleLogEntry` renders `- phases:` + `  duration:` additively;
      legacy entry (no duration lines) still parses + chain hash
      unchanged; refactor green path prints the phase-timings line and
      the FR-009 summary line format is byte-unchanged. Record red.
      (depends: T002)
- [ ] T005 GREEN (MVP): patcher `includeMutationTest` switch (default
      false) + `TddBaselineInit(mutation:)` threading + `InitCommand
      --mutation`. Make T003's opt-in tests green. (depends: T003)
- [ ] T006 GREEN: `PubPreResolver` service + `TddBaselineInit` fire/
      skip/misfire/warn wiring. Make T003's pre-resolve tests green.
      (depends: T005)
- [ ] T007 GREEN: `RefactorAction.duration` + per-pass timing in
      `RefactorPasses.run()` + phase stopwatches + green-path
      phase-timings print in `RefactorCommand`. (depends: T004)
- [ ] T008 GREEN: `CycleLogEntry.phaseDurations` additive rendering +
      duration formatting helper. (depends: T007)
- [ ] T009 Targeted regression: run the pre-existing suites touching the
      changed surface (patcher, #1349, #1370, cycle-log integrity,
      terminal receipt, refactor command subset); fix any drift the new
      default exposes (the patcher suite's "adds all six" expectations
      MUST be re-pinned to the new default honestly, with the #1653
      rationale). (depends: T005–T008)
- [ ] T010 Non-behavioral: docs (`docs/zfa-tdd-guide.md` dependency block
      note re opt-in mutation_test; the init idempotence paragraph),
      verification.md from the REAL runs. (depends: T009)
- [ ] T011 Real mutation evidence: scoped mutation config over the eight
      changed lib files + covering tests; `dart run mutation_test` real
      run; counts into verification.md. (depends: T009)
- [ ] T011 `dart analyze` (changed files) + `dart format .` + commit +
      PR. (depends: T009–T011)
