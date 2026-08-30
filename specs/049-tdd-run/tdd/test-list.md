---
feature: 049-tdd-run
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 12
planned_at: 43841d0c
updated_at: 9986bfec
suite_baseline: green
---

# Test List: `zfa tdd run`

Baseline: `dart test test/plugins/tdd/` at `43841d0c` → 116 passed, 0 failed
(fast tier). Driver/scenario suites run in the `slow` tier with scripted fake
step binaries (steps 047/048 may be unmerged; the driver consumes contracts).

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`, driving the real CLI entry point
in `test/plugins/tdd/scenarios/` (slow tier).

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| A1 | 3-behavior feature drives to all-DONE in list order, one red + one green log entry per behavior, exit 0 | US1.AC1 | example | DONE | `test/plugins/tdd/scenarios/sc_013_run_drives_feature_test.dart::A1: drives a 3-behavior feature to all-DONE, exit 0, evidence` |
| A2 | Re-run on a completed feature changes nothing and exits 0 | US1.AC2 | example | DONE | `test/plugins/tdd/scenarios/sc_013_run_drives_feature_test.dart::A2: re-run on a completed feature changes nothing and exits 0` |
| A3 | A behavior appended mid-project is driven while DONE behaviors stay untouched | US1.AC3 | example | DONE | `test/plugins/tdd/scenarios/sc_013_run_drives_feature_test.dart::A3: a behavior appended mid-project is driven, DONE ones untouched` |
| A4 | Resume with B-002 RED skips DONE B-001 and re-enters at `make` | US2.AC1 | example | DONE | `test/plugins/tdd/scenarios/sc_014_run_resumes_test.dart::A4: resume with B-002 RED skips DONE B-001 and re-enters at make` |
| A5 | A kill mid-step resumes at the in-flight step, safe via step idempotency | US2.AC2 | example | DONE | `test/plugins/tdd/scenarios/sc_014_run_resumes_test.dart::A5: a kill mid-step resumes at the in-flight step` |
| A6 | Corrupted run-state.json → non-zero, corruption and recovery path named | US2.AC3 | example | DONE | `test/plugins/tdd/scenarios/sc_014_run_resumes_test.dart::A6: corrupted run-state.json stops non-zero with recovery path` |
| A7 | `make` unexpressible at B-002 → run stops non-zero, B-002 stays RED, B-003 never started | US3.AC1 | example | DONE | `test/plugins/tdd/scenarios/sc_015_run_stops_on_failure_test.dart::A7: make unexpressible at B-002 stops, B-002 stays RED, B-003 never started` |
| A8 | Any step failure report names behavior, step, outcome, and the resume command | US3.AC2 | example | DONE | `test/plugins/tdd/scenarios/sc_015_run_stops_on_failure_test.dart::A8: the failure report names behavior, step, outcome, resume command` |
| A9 | A behavior with red but no green evidence is never marked DONE, whatever the state file says | US3.AC3 | example | DONE | `test/plugins/tdd/scenarios/sc_015_run_stops_on_failure_test.dart::A9: red without green evidence is never DONE, whatever the state says` |
| A10 | Each completed step prints a progress line `[run] <behavior> <step> -> <outcome>` immediately | US4.AC1 | example | DONE | `test/plugins/tdd/scenarios/sc_016_run_summary_contract_test.dart::A10: each completed step prints its progress line immediately` |
| A11 | Every run ends with the summary line carrying feature, result, per-state counts, and stopped_at when stopped | US4.AC2 | example | DONE | `test/plugins/tdd/scenarios/sc_016_run_summary_contract_test.dart::A11: the summary line carries feature, result, counts, stopped_at` |
| A12 | Exit code 0 occurs exactly on all-DONE-with-evidence; everything else non-zero | US4.AC3 | example | DONE | `test/plugins/tdd/scenarios/sc_016_run_summary_contract_test.dart::A12: exit 0 occurs exactly on all-DONE-with-evidence` |

## Inner loop: unit behaviors

### `lib/src/plugins/tdd/services/test_list_reader.dart`

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U1 | Parses 4-column rows (`id/behavior/traces/state`) in list order | FR-001 | example | DONE | `test/plugins/tdd/services/test_list_reader_test.dart::U1: parses 4-column rows in list order` |
| U2 | Kind is inferred from the section header (outer=acceptance, inner=unit) | FR-001 | example | DONE | `test/plugins/tdd/services/test_list_reader_test.dart::U2: kind is inferred from the section header` |
| U3 | A malformed row stops with an error naming the line | FR-011 | example | DONE | `test/plugins/tdd/services/test_list_reader_test.dart::U3: a malformed row stops with an error naming the line` |

### `lib/src/plugins/tdd/services/cycle_evidence.dart`

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U4 | Red evidence set = behaviors with a `kind: red` cycle-log section | FR-003 | example | DONE | `test/plugins/tdd/services/cycle_evidence_test.dart::U4: red evidence = behaviors with a kind: red section` |
| U5 | Green evidence set = behaviors with a `kind: green` section | FR-003 | example | DONE | `test/plugins/tdd/services/cycle_evidence_test.dart::U5: green evidence = behaviors with a kind: green section` |
| U6 | A missing cycle log yields empty sets (not an error) | FR-003 | example | DONE | `test/plugins/tdd/services/cycle_evidence_test.dart::U6: a missing cycle log yields empty sets, not an error` |

### `lib/src/plugins/tdd/services/run_state_store.dart`

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U7 | save→load round-trips RunState (states + in-flight markers) | FR-004 | example | DONE | `test/plugins/tdd/services/run_state_store_test.dart::U7: save -> load round-trips states and in-flight markers` |
| U8 | Saves are atomic: a crash mid-write leaves the previous file intact | FR-004 | example | DONE | `test/plugins/tdd/services/run_state_store_test.dart::U8: saves are atomic — no tmp residue, previous intact on failure` |
| U9 | Corrupted JSON stops with the corruption and recovery path named | FR-006 | example | DONE | `test/plugins/tdd/services/run_state_store_test.dart::U9: corrupted JSON stops with the corruption and recovery path` |
| U10 | A held in-flight marker at start refuses the second run | FR-006 | example | DONE | `test/plugins/tdd/services/run_state_store_test.dart::U10: a held in-flight marker refuses the second run` |
| U11 | Behaviors removed from the test list are retained with a dropped marker | edge case | example | DONE | `test/plugins/tdd/services/run_state_store_test.dart::U11: behaviors removed from the test list are retained as dropped` |

### `lib/src/plugins/tdd/services/step_runner.dart`

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U12 | Steps spawn with argv `tdd <step> <id> --feature <f> --project <dir>` | FR-002 | example | DONE | `test/plugins/tdd/services/step_runner_test.dart::U12: steps spawn with argv tdd <step> <id> --feature --project` |
| U13 | verify-red succeeds only on exit 0 AND `certified=true` | FR-002 | example | DONE | `test/plugins/tdd/services/step_runner_test.dart::U13: verify-red succeeds only on exit 0 AND certified=true` |
| U14 | make succeeds only on exit 0 AND `outcome=green` | FR-002 | example | DONE | `test/plugins/tdd/services/step_runner_test.dart::U14: make succeeds only on exit 0 AND outcome=green` |
| U15 | refactor succeeds only on exit 0 AND `outcome=clean\|refactored` | FR-002 | example | DONE | `test/plugins/tdd/services/step_runner_test.dart::U15: refactor succeeds on outcome=clean or outcome=refactored` |
| U16 | gen succeeds on exit 0 | FR-002 | example | DONE | `test/plugins/tdd/services/step_runner_test.dart::U16: gen succeeds on exit 0 and fails on exit != 0` |
| U17 | A spawn failure yields a runner-error StepResult, not a crash | FR-011 | example | DONE | `test/plugins/tdd/services/step_runner_test.dart::U17: a spawn failure yields a runner-error StepResult, not a crash` |
| U18 | `--zfa-bin` overrides entrypoint resolution | FR-002 | example | DONE | `test/plugins/tdd/services/step_runner_test.dart::U18: --zfa-bin overrides entrypoint resolution` |

### `lib/src/plugins/tdd/commands/run_command.dart`

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U19 | Per-behavior step order is gen → verify-red → make → refactor | FR-001 | example | DONE | `test/plugins/tdd/run_command_test.dart::U19: per-behavior step order is gen -> verify-red -> make -> refactor` |
| U20 | State is persisted after every completed step | FR-004 | example | DONE | `test/plugins/tdd/run_command_test.dart::U20: state is persisted after every completed step` |
| U21 | A done claim without red+green evidence demotes to the evidence-backed state | FR-003 | example | DONE | `test/plugins/tdd/run_command_test.dart::U21: a done claim without red+green evidence demotes to the evidence-backed state` |
| U22 | Resume skips DONE and re-enters at the state-implied step (RED→make, GREEN→refactor) | FR-005 | example | DONE | `test/plugins/tdd/run_command_test.dart::U22: resume skips DONE and re-enters at the state-implied step` |
| U23 | An in-flight step at load re-executes that step | FR-005 | example | DONE | `test/plugins/tdd/run_command_test.dart::U23: an in-flight step at load re-executes that step` |
| U24 | A step failure stops the run: residual state correct, later behaviors untouched | FR-007, FR-008 | example | DONE | `test/plugins/tdd/run_command_test.dart::U24: the failure matrix stops the run with correct residual state` |
| U25 | Each step completion prints its progress line | FR-009 | example | DONE | `test/plugins/tdd/run_command_test.dart::U25: each step completion prints its progress line` |
| U26 | The summary line carries feature, result, per-state counts, stopped_at | FR-010 | example | DONE | `test/plugins/tdd/run_command_test.dart::U26: the summary line carries feature, result, counts, stopped_at` |
| U27 | Exit 0 exactly on complete-with-evidence | FR-010 | example | DONE | `test/plugins/tdd/run_command_test.dart::U27: exit 0 exactly on complete-with-evidence` |
| U28 | An all-DONE run performs zero step invocations and exits 0 | FR-005 | example | DONE | `test/plugins/tdd/run_command_test.dart::U28: an all-DONE run performs zero step invocations and exits 0` |
| U29 | New test-list rows enter as PENDING without disturbing DONE behaviors | FR-001 | example | DONE | `test/plugins/tdd/run_command_test.dart::U29: new test-list rows enter as PENDING, DONE behaviors untouched` |

### `lib/src/plugins/tdd/models/run_state.dart` (existing)

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U30 | advance/markInFlight/toJson/fromJson semantics (existing) | FR-004 | example | DONE | `test/plugins/tdd/models/run_state_test.dart` |

## Invariants and edge cases still to place

None — spec edge cases mapped: shared subjects → make's guard (not the
driver's concern); stubbed step command → U24/A7; mid-run spec edit → U11
(dropped retention) + U29 (new rows PENDING).

## Out of scope

- Parallel behavior execution within a run.
- Cross-feature orchestration (the epic scripts multiple `run` invocations).
- Implementing the step commands (044/046/047/048 own them).
- Fixing the plan↔gen test-list column mismatch — filed as a gap (task T025).
- Interactive prompting mid-run.

## Verification commands

Copied from `.specify/memory/tdd-profile.md` at planning time (feature scope
adapted to this feature's test tree):

- Single test: `dart test test/<path>.dart -P "<name>"`
- Full suite (feature scope, fast): `dart test test/plugins/tdd/`
- Full suite (feature scope, incl. subprocess): `dart test --tags slow test/plugins/tdd/`
- Full suite (repo): `dart test` — slow; not for loop use
- Static analysis (feature scope): `dart analyze lib/src/plugins/tdd/ test/plugins/tdd/`
- Coverage: `dart test --coverage=<dir>` then `dart run coverage:format_coverage`
- Mutation: none wired; `/speckit.tdd.verify` falls back to deliberate-mutant
  sampling
