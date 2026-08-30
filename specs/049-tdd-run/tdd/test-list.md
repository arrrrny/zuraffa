---
feature: 049-tdd-run
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 12
planned_at: 43841d0c
updated_at: 43841d0c
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
| A1 | 3-behavior feature drives to all-DONE in list order, one red + one green log entry per behavior, exit 0 | US1.AC1 | example | PENDING | |
| A2 | Re-run on a completed feature changes nothing and exits 0 | US1.AC2 | example | PENDING | |
| A3 | A behavior appended mid-project is driven while DONE behaviors stay untouched | US1.AC3 | example | PENDING | |
| A4 | Resume with B-002 RED skips DONE B-001 and re-enters at `make` | US2.AC1 | example | PENDING | |
| A5 | A kill mid-step resumes at the in-flight step, safe via step idempotency | US2.AC2 | example | PENDING | |
| A6 | Corrupted run-state.json → non-zero, corruption and recovery path named | US2.AC3 | example | PENDING | |
| A7 | `make` unexpressible at B-002 → run stops non-zero, B-002 stays RED, B-003 never started | US3.AC1 | example | PENDING | |
| A8 | Any step failure report names behavior, step, outcome, and the resume command | US3.AC2 | example | PENDING | |
| A9 | A behavior with red but no green evidence is never marked DONE, whatever the state file says | US3.AC3 | example | PENDING | |
| A10 | Each completed step prints a progress line `[run] <behavior> <step> -> <outcome>` immediately | US4.AC1 | example | PENDING | |
| A11 | Every run ends with the summary line carrying feature, result, per-state counts, and stopped_at when stopped | US4.AC2 | example | PENDING | |
| A12 | Exit code 0 occurs exactly on all-DONE-with-evidence; everything else non-zero | US4.AC3 | example | PENDING | |

## Inner loop: unit behaviors

### `lib/src/plugins/tdd/services/test_list_reader.dart`

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U1 | Parses 4-column rows (`id/behavior/traces/state`) in list order | FR-001 | example | PENDING | |
| U2 | Kind is inferred from the section header (outer=acceptance, inner=unit) | FR-001 | example | PENDING | |
| U3 | A malformed row stops with an error naming the line | FR-011 | example | PENDING | |

### `lib/src/plugins/tdd/services/cycle_evidence.dart`

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U4 | Red evidence set = behaviors with a `kind: red` cycle-log section | FR-003 | example | PENDING | |
| U5 | Green evidence set = behaviors with a `kind: green` section | FR-003 | example | PENDING | |
| U6 | A missing cycle log yields empty sets (not an error) | FR-003 | example | PENDING | |

### `lib/src/plugins/tdd/services/run_state_store.dart`

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U7 | save→load round-trips RunState (states + in-flight markers) | FR-004 | example | PENDING | |
| U8 | Saves are atomic: a crash mid-write leaves the previous file intact | FR-004 | example | PENDING | |
| U9 | Corrupted JSON stops with the corruption and recovery path named | FR-006 | example | PENDING | |
| U10 | A held in-flight marker at start refuses the second run | FR-006 | example | PENDING | |
| U11 | Behaviors removed from the test list are retained with a dropped marker | edge case | example | PENDING | |

### `lib/src/plugins/tdd/services/step_runner.dart`

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U12 | Steps spawn with argv `tdd <step> <id> --feature <f> --project <dir>` | FR-002 | example | PENDING | |
| U13 | verify-red succeeds only on exit 0 AND `certified=true` | FR-002 | example | PENDING | |
| U14 | make succeeds only on exit 0 AND `outcome=green` | FR-002 | example | PENDING | |
| U15 | refactor succeeds only on exit 0 AND `outcome=clean\|refactored` | FR-002 | example | PENDING | |
| U16 | gen succeeds on exit 0 | FR-002 | example | PENDING | |
| U17 | A spawn failure yields a runner-error StepResult, not a crash | FR-011 | example | PENDING | |
| U18 | `--zfa-bin` overrides entrypoint resolution | FR-002 | example | PENDING | |

### `lib/src/plugins/tdd/commands/run_command.dart`

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U19 | Per-behavior step order is gen → verify-red → make → refactor | FR-001 | example | PENDING | |
| U20 | State is persisted after every completed step | FR-004 | example | PENDING | |
| U21 | A done claim without red+green evidence demotes to the evidence-backed state | FR-003 | example | PENDING | |
| U22 | Resume skips DONE and re-enters at the state-implied step (RED→make, GREEN→refactor) | FR-005 | example | PENDING | |
| U23 | An in-flight step at load re-executes that step | FR-005 | example | PENDING | |
| U24 | A step failure stops the run: residual state correct, later behaviors untouched | FR-007, FR-008 | example | PENDING | |
| U25 | Each step completion prints its progress line | FR-009 | example | PENDING | |
| U26 | The summary line carries feature, result, per-state counts, stopped_at | FR-010 | example | PENDING | |
| U27 | Exit 0 exactly on complete-with-evidence | FR-010 | example | PENDING | |
| U28 | An all-DONE run performs zero step invocations and exits 0 | FR-005 | example | PENDING | |
| U29 | New test-list rows enter as PENDING without disturbing DONE behaviors | FR-001 | example | PENDING | |

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
