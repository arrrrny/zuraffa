**Template Version**: `zuraffa-1.0`

# Tasks: 1645-pipeline-running-binary-tier

**Input**: Design documents from `specs/1645-pipeline-running-binary-tier/` (spec.md, plan.md, research.md, quickstart.md)

**Prerequisites**: plan.md, spec.md; research.md records the #1643 mirror
decision, the VM-name mirror decision, and the U16/U17 re-shape precedent.

## 1. Behavioural (TDD red → green first) — MANDATORY, driven by the loop before T101

- [ ] **T001** (P1) [US1] [behavior: A1] `test/plugins/tdd/services/bug_1645_pipeline_running_binary_tier_test.dart`
  — B1, the issue's repro at the tier level: cache-exe driver (the #864
  native-AOT shape, `scriptPathOverride == resolvedExecutableOverride`,
  real executable fixture) with a fake `zfa` on PATH →
  `result.entrypoint` is the RUNNING binary, never the PATH install;
  the argv log shows the driving binary spawned the plan's step alone.
  RED pre-fix (PATH install wins). [FR-001, SC-001; spec A1]
- [ ] **T002** [behavior: A2] (P1) [US1] same file — B2: cache-exe driver with an
  UNUSABLE script path (stale-snapshot shape) and a `zfa` on PATH →
  the running binary still wins. RED pre-fix. [FR-001; spec A2]
- [ ] **T003** [behavior: U2] (P2) [US2] same file — B3: `dart run` driver (VM basename
  `dart`) with a `zfa` on PATH → the PATH install still wins
  (backward compatible; GREEN pre- and post-fix). [FR-002; spec U2.1]
- [ ] **T004** [behavior: U3] (P2) [US2] same file — B4: `dartaotruntime` snapshot
  driver with a `zfa` on PATH → the PATH install still wins
  (backward compatible). [FR-002; spec U2.1]
- [ ] **T005** [behavior: U1] (P2) [US1] same file — B5: cache-exe driver with a
  NON-executable PATH candidate → the running binary wins; the
  non-executable PATH candidate never does. [FR-001; spec A3]
- [ ] **T006** [behavior: U4] (P2) [US2] `test/plugins/tdd/services/pipeline_runner_test.dart`
  — re-shape U16 ("tier 3 — zfa on PATH wins over the snapshot
  fallback"): the fake VM stand-in is renamed `dart-vm` → `dart` (a REAL
  VM name); intent and assertions unchanged. GREEN throughout — this is
  a shape-honesty fix, not a loosening (#1643 precedent). [FR-002, SC-002]
- [ ] **T007** [behavior: U5] (P2) [US2] same file — re-shape U17 ("tier 4 — compiled
  snapshot keeps the dart <snapshot> shape"): same rename to a real VM
  name; the `<vm> <snapshot>` spawn shape in the argv log is preserved.
  GREEN throughout. [FR-006, SC-002; spec U2.2]

## 2. Non-behavioural (implement to green)

- [ ] **T101** (P1) `lib/src/plugins/tdd/services/pipeline_runner.dart`
  — in `_resolveEntrypoint`, insert the promoted tier between tier 2
  (running from source) and the PATH tier: when
  `!_isDartVmName(basename(resolvedExecutable))` AND the file exists,
  resolve the running binary through the `compile` seam (non-`.dart`
  passes through unchanged — FR-005 holds by construction). Add the
  private static `_isDartVmName` mirroring `StepRunner._isDartVmName`
  (`dart`, `dartvm`, `dartaotruntime` + `.exe`), doc comment
  cross-referencing the step-runner twin. Renumber the library + method
  doc tiers (PATH → 4, fallback → 5) and record the #1645 rationale
  (the #1643 mirror; the same-version/different-code hazard the #1472
  pin cannot see). No signature changes; tiers 1–2 untouched.
  [FR-001/FR-002/FR-003/FR-004/FR-005]

## 3. Verification

- [ ] **T201** (P1) Regression + static scope green: `dart test
  test/plugins/tdd/services/bug_1645_pipeline_running_binary_tier_test.dart`
  (B1/B2 red→green evidence logged in `tdd/cycle-log.md`; B3–B5 green
  throughout); `dart test test/plugins/tdd/services/` (includes the
  re-shaped bug-#864 tier group); `dart test
  test/plugins/tdd/bug_1472_refactor_gate_acceptance_test.dart
  test/plugins/tdd/bug_1472_refactor_gate_errors_only_test.dart` (FR-007:
  the pin untouched); `dart test test/core/no_jit_zfa_spawn_scan_test.dart`;
  `dart analyze` on the changed files → zero findings; `dart format`
  clean. [SC-002/SC-003; spec U2.3/U3.1/U3.2]

## Dependencies & Execution Order

- T001–T007 are test-only and independent of T101; T001–T005 are written
  FIRST and proven red (T001/T002) before T101 touches the resolver.
- T006/T007 (re-shapes) are green before AND after T101 — they may land
  with the test commit.
- T101 depends on the red evidence existing (never write the fix before
  the failing test is proven red).
- T201 runs last, after T101 turns the suite green.

## MVP Scope

US1 (T001 + T002 + T005 + T101) alone delivers the fix: a compiled
driver resolves and spawns the running binary. US2 (T003/T004/T006/T007)
pins backward compatibility; the verification pass (T201) closes the loop.
