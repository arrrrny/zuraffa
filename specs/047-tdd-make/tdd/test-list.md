---
feature: 047-tdd-make
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 14
planned_at: d7155cf6
updated_at: d7155cf6
suite_baseline: green
---

# Test List: `zfa tdd make`

Baseline: `dart test test/plugins/tdd/` at `d7155cf6` → 116 passed, 0 failed
(fast tier; command/scenario suites for this feature run in the `slow` tier,
mirroring 046). One known pre-existing flake outside this scope:
`test/dda/route_perf_test.dart` (timing threshold) — motivates the
regression guard's NEW-failure semantics.

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`. Each drives the real CLI entry
point against a `TddFixture` project with a scripted fake pipeline, in
`test/plugins/tdd/scenarios/` (slow tier).

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| A1 | Certified-red behavior: implementation generated via pipeline, target test green, exit 0 | US1.AC1 | example | PENDING | |
| A2 | Green entry carries all contract fields including the recorded generation commands | US1.AC2 | example | PENDING | |
| A3 | The behavior's test file is byte-identical after a certified run | US1.AC3 | example | PENDING | |
| A4 | No red evidence → refused before any generation, verify-red remediation named | US2.AC1 | example | PENDING | |
| A5 | Unknown behavior id → refused naming the id, gen remediation, nothing generated | US2.AC2 | example | PENDING | |
| A6 | Already-green target test → drift reported, exit non-zero, no vacuous green | US2.AC3 | example | PENDING | |
| A7 | Clean guard → green entry records both target-test pass and full-suite pass | US3.AC1 | example | PENDING | |
| A8 | Sibling regression → exit non-zero naming the regressed test, no green entry, source left in place | US3.AC2 | example | PENDING | |
| A9 | Pre-existing suite failures tolerated; only NEW failures fail the guard | US3.AC3 | example | PENDING | |
| A10 | Pipeline-inexpressible behavior → exit non-zero naming the unmet capability, no evidence | US4.AC1 | example | PENDING | |
| A11 | Failing generation step → exit non-zero naming the step, no test-suite run against broken code | US4.AC2 | example | PENDING | |
| A12 | Any misfire leaves the behavior's test file and the cycle log unchanged | US4.AC3 | example | PENDING | |
| A13 | Every invocation ends with the summary line `make: behavior=<id> outcome=<outcome> feature=<feature>` | US5.AC1 | example | PENDING | |
| A14 | Exit code 0 occurs exactly on `green`; every rejection/misfire is non-zero | US5.AC2 | example | PENDING | |

## Inner loop: unit behaviors

### `lib/src/plugins/tdd/models/generation_plan.dart`

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U1 | A plan is either expressible with non-empty steps ending in `build`, or carries an unexpressibleReason — never both | FR-005 | example | PENDING | |
| U2 | An executed step captures the full resolved command, exit code, and output verbatim | FR-006 | example | PENDING | |

### `lib/src/plugins/tdd/services/generation_planner.dart`

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U3 | An entity-bearing behavior maps to a plan whose first step is `entity create` | FR-005 | example | PENDING | |
| U4 | A CRUD/use-case behavior maps to a `make` step with the minimal preset/methods | FR-005 | example | PENDING | |
| U5 | Every expressible plan terminates in a `build` step | FR-005 | example | PENDING | |
| U6 | A plan contains no steps beyond what the behavior requires (minimal generation) | FR-005 | example | PENDING | |
| U7 | An unmappable behavior yields an unexpressibleReason naming the unmet capability in behavior terms | FR-005 | example | PENDING | |

### `lib/src/plugins/tdd/services/pipeline_runner.dart`

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U8 | Steps execute in plan order | FR-006 | example | PENDING | |
| U9 | Every executed step is captured with command, exit code, output | FR-006 | example | PENDING | |
| U10 | The first failing step stops the plan; later steps never execute | FR-011 | example | PENDING | |
| U11 | `--zfa-bin` overrides entrypoint auto-resolution | FR-004 | example | PENDING | |
| U12 | An unresolvable entrypoint stops before any step executes | FR-011 | example | PENDING | |
| U13 | Steps execute in the target project's working directory | FR-004 | example | PENDING | |

### `lib/src/plugins/tdd/services/suite_guard.dart`

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U14 | Failing test identifiers are parsed from runner output | FR-007 | example | PENDING | |
| U15 | NEW failures are the guard set minus the baseline set | FR-007 | example | PENDING | |
| U16 | A failure present in both baseline and guard is tolerated | FR-007 | example | PENDING | |
| U17 | One fixed + one newly broken test nets a named failure | FR-007 | example | PENDING | |
| U18 | Unparseable guard output is a safe failure, never a silent pass | FR-011 | example | PENDING | |

### `lib/src/plugins/tdd/services/runner.dart` (extension)

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U19 | Loads the `suite` template from `tdd-profile.md` | FR-007 | example | PENDING | |
| U20 | `runSuite` captures exit code and combined output | FR-007 | example | PENDING | |

### `lib/src/plugins/tdd/models/cycle_entry.dart` (extension)

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U21 | A green entry renders the `generation:` block listing each step's command and exit code in execution order | FR-006, FR-008 | example | PENDING | |
| U22 | A green entry renders the `suite:` line with baseline and guard counts | FR-008 | example | PENDING | |

### `lib/src/plugins/tdd/commands/make_command.dart`

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U23 | Missing red evidence refuses with `not-certified-red` before any pipeline invocation | FR-001 | example | PENDING | |
| U24 | Unknown behavior id refuses before any pipeline invocation | FR-001, FR-002 | example | PENDING | |
| U25 | The drift check re-runs the target test before generating; a pass stops with `drift` | FR-003 | example | PENDING | |
| U26 | Happy path order: precondition → drift check → plan → execute → target test → guard → evidence | FR-001, FR-007 | example | PENDING | |
| U27 | Any rejection or misfire writes no cycle-log entry and leaves the test file byte-identical | FR-009 | example | PENDING | |
| U28 | The green entry contains every contract field including generation steps | FR-008 | example | PENDING | |
| U29 | The summary line is the final stdout line on every path; exit 0 exactly on `green` | FR-010 | example | PENDING | |
| U30 | A missing/unreadable tdd-profile stops with `runner-error` before any step | FR-011 | example | PENDING | |

## Invariants and edge cases still to place

None — spec edge cases all mapped: partial `zfa build` failure → U10/A11;
re-run on green-certified behavior → covered by U25's drift check (already
green ⇒ `drift`). A valid registry record whose test file is missing has the
dedicated `make_command_test.dart` test “a valid registry record with a missing
test file is a hard runner-error before any pipeline invocation”; it asserts
the `runner-error` summary, `zfa tdd gen` remediation, and zero pipeline calls.
U24 remains exclusively the unknown behavior-id case.

## Out of scope

- General behavior→generation planning beyond the minimal fixture mappings
  (epic 045 gap protocol grows it).
- `zfa tdd refactor`, `zfa tdd run` — separate precondition specs.
- Reverting generated source after a failed run.
- Vacuous-green detection via mutation (`zfa tdd verify`'s job).
- The `route_perf_test.dart` flake — recorded baseline noise, not this
  feature's to fix.

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
