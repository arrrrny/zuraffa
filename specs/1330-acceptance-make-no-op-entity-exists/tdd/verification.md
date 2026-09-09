# Verification: 1330-acceptance-make-no-op-entity-exists

## Test-first evidence (red → green)

| behavior | red evidence | green evidence |
| -------- | ------------ | -------------- |
| U-1330-1 (FR-001, FR-003, SC-1) | RED: `dart test --preset=all test/plugins/tdd/issue_1330_make_subject_edit_fallback_test.dart` — the make reproduced the issue dead-end verbatim on the acceptance CRUD shape with the entity pre-seeded: `entity DispatchService already exists — reuse` → `plan: 3 step(s)` → `plan: `zfa make DispatchService` resolves to no active plugins — nothing to generate (bug #826).` → `verdict: no-op` → `no subprocess was attempted`; assertion `Expected: contains 'issue #1330'` failed | GREEN: fallback lines printed (`issue #1330` + `falling back to the subject edit`), `verdict: no-op` ABSENT, `no subprocess was attempted` ABSENT, hand-tuned entity byte-identical, real post-pipeline outcome graded (`+2: All tests passed!`) |
| U-1330-2 (FR-004, SC-4) | — (backward-compat guard: passes pre-fix by design) | GREEN pre- AND post-fix: the subject-edit-less shape (`[make <slug> --no-entity, build]`) keeps `verdict: no-op` + the enable-plugins remedy + exit 1 |
| A-1330-1 / SC-024a (FR-001, FR-002, SC-2) | RED by construction pre-fix (the pre-flight aborted the real make at `verdict: no-op` before any subprocess — the same abort U-1330-1's red captured in-process) | GREEN: real `bin/zfa.dart tdd make A1` with NO `--zfa-bin` reaching the make child → `make: behavior=A1 outcome=green`, `issue #1330` fallback lines present, hand-tuned entity byte-identical, subject wired (no `UnimplementedError`, references `DispatchService`), green evidence records `tdd wire` (3:28 runtime) |
| A-1330-2 / SC-024b (FR-002, SC-3) | RED by construction pre-fix (phase 2 re-plans the identical gated plan → identical no-op → `result=stopped stopped_at=A2:make` — the driver's honest stop the issue reports) | GREEN: real `zfa tdd run` over TWO acceptance behaviors on the SAME contract row → `[run] A1 make -> green` (normal scaffold, entity absent) + `[run] A2 make -> green` (fallback, entity present), NO `make -> deferred`, NO `no-op`, NO `stopped_at`, `run: feature=002-dispatch-wedge result=complete pending=0 red=0 green=0 done=2`, exit 0, both subjects wired (6:56 runtime) |

## Mutation evidence (test strength)

| mutant | change | result |
| ------ | ------ | ------ |
| M1 | `_subjectEditFallbackPlan` returns null always (fallback killed) | KILLED — U-1330-1 RED (`verdict: no-op` returns, `issue #1330` line absent): `+1 -1: Some tests failed.` |
| M2 | fallback engaged silently (both greppable fallback lines removed) | KILLED — U-1330-1 RED (`Expected: contains 'issue #1330'`): `+1 -1: Some tests failed.` |

## Test runs (cloud-agent scope: changed files only — no full suite)

```text
dart analyze lib/src/plugins/tdd/commands/make_command.dart
             test/plugins/tdd/issue_1330_make_subject_edit_fallback_test.dart
             test/plugins/tdd/scenarios/sc_024_acceptance_entity_reuse_fallback_e2e_test.dart
                                                          → No issues found!
dart format --set-exit-if-changed <the three files above> → 0 changed (exit 0)
dart test --preset=all test/plugins/tdd/issue_1330_make_subject_edit_fallback_test.dart
                                                          → 2/2 pass
dart test --preset=all test/plugins/tdd/scenarios/sc_024_acceptance_entity_reuse_fallback_e2e_test.dart
                                                          → 2/2 pass (SC-024a 3:28, SC-024b 6:56)
dart test --preset=all test/plugins/tdd/run_command_test.dart
                                                          → 49/49 pass (driver #826 deferral contract intact)
dart test test/plugins/tdd/wire_command_test.dart
        test test/plugins/tdd/services/generation_planner_test.dart
                                                          → 46/46 pass
dart test test/plugins/tdd/commands/func_command_test.dart
        test test/plugins/tdd/bug_1259_vacuous_green_test.dart
                                                          → 9/9 + 7/7 pass
dart test --preset=all test/plugins/tdd/make_command_test.dart
                                                          → 33 pass / 5 fail — see below
```

Pre-existing, unrelated failures (PROVEN on pristine HEAD: `git stash` of the
lib change reproduced the IDENTICAL 5-failure list — NOT introduced by this
feature; the spec-1308 verification recorded the same 33/5 environment-dependent
counts):

- `make_command_test.dart` bug 657 unexpressible-make naming; U-829g; U-829h
  (the traced-unit plan now emits `mock create`, the tests still assert
  `make <Entity>` — planner drift predating this feature); spec 052 A11/U17;
  spec 052 A15.

## Acceptance-criteria coverage

| criterion | proof |
| --------- | ----- |
| 1. Subject-edit fallback on no-op | U-1330-1 + SC-024a: the gated one-shot make proceeds to the `tdd wire` subject edit; the no-op is not a hard stop |
| 2. Phase 2 does not re-attempt identical no-op | SC-024b: with the fallback applied the make reports `green` (never `no-op`), so the driver's deferral arm (`unexpressible|no-op`) never engages — `result=complete done=2`, no `make -> deferred`, no `stopped_at`. The pure no-op shape keeps the designed #826 deferral (U-1330-2, run_command_test bug-826 suite 49/49) |
| 3. Entity reuse preserves hand-tuned fields | U-1330-1 + SC-024a: the hand-tuned entity file is byte-identical after the fallback (the fallback only REMOVES a plan step; `entity create` was already gated by #829) |
| 4. Backward compatibility | U-1330-2: the subject-edit-less shape keeps `verdict: no-op` verbatim; entity-absent scaffolds never reach the pre-flight (plan starts with `entity create` — SC-024b's A1 green through the normal path); run_command_test 49/49, wire/planner/func/1259 suites unchanged |

## End-to-end proof (real CLI, not the fake binary)

`sc_024_acceptance_entity_reuse_fallback_e2e_test.dart` (real `bin/zfa.dart`,
real pub get + build_runner, pure-exec forwarder, SC-017/021 provisioning):

- **SC-024a**: gen → verify-red (certified red) → hand-tuned `DispatchService`
  entity pre-seeded → `zfa tdd make A1` (no `--zfa-bin`):
  ```text
  entity DispatchService already exists — reuse (never overwrite hand-tuned fields)
  plan: `zfa make DispatchService` resolves to no active plugins — nothing to
        generate on the already-generated entity (issue #1330).
  falling back to the subject edit (issue #1330): the entity is reused as-is
        (hand-tuned fields preserved) — dropping the no-op make step.
  make: behavior=A1 outcome=green feature=001-dispatch-reuse
  ```
  The subject file carries the wired implementation (`wiredEntityAnchor`
  referencing `DispatchService`); the green cycle-log entry records the
  `tdd wire` step; the entity file is byte-identical.
- **SC-024b**: `zfa tdd run 002-dispatch-wedge` with A1+A2 on the same row:
  A1 greens via the normal scaffold (entity absent → `entity create` runs,
  the one-shot `make` child no-ops exit-0 as a successful step, wire greens),
  A2 greens via the fallback (entity present → gated bare make → dropped →
  wire greens) — the exact wedge from the issue repro, now completing
  `result=complete ... done=2`.
