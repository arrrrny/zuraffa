---
feature: 048-tdd-refactor
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 11
planned_at: 43841d0c
updated_at: 43841d0c
suite_baseline: green
---

# Test List: `zfa tdd refactor`

Baseline: `dart test test/plugins/tdd/` at `43841d0c` → 116 passed, 0 failed
(fast tier). Command/scenario suites for this feature run in the `slow` tier,
mirroring 046.

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`, driving the real CLI entry point
against `TddFixture` projects in `test/plugins/tdd/scenarios/` (slow tier).

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| A1 | Green preflight → the command proceeds to its refactor passes | US1.AC1 | example | PENDING | |
| A2 | Red suite → non-zero, every failing test named, make remediation, zero files modified | US1.AC2 | example | PENDING | |
| A3 | Unrunnable suite (runner/profile broken) → non-zero `runner-error`, zero files modified | US1.AC3 | example | PENDING | |
| A4 | Generator/output drift is normalized by recorded tool invocations, each with its exact command | US2.AC1 | example | PENDING | |
| A5 | Every file under `test/` is byte-identical after the run | US2.AC2 | example | PENDING | |
| A6 | Every changed `lib/` file is attributable to a recorded action; unattributed edits hard-fail | US2.AC3 | example | PENDING | |
| A7 | Green re-proof after applied actions → exit 0 and a refactor evidence entry listing every action + command | US3.AC1 | example | PENDING | |
| A8 | Post-refactor regression → non-zero, regressed tests named, no success evidence | US3.AC2 | example | PENDING | |
| A9 | Nothing to change → honest `clean` no-op, exit 0, no fabricated actions | US3.AC3 | example | PENDING | |
| A10 | Every invocation ends with `refactor: feature=<f> outcome=<o> applied=<n>` | US4.AC1 | example | PENDING | |
| A11 | Exit code 0 occurs exactly on `clean`/`refactored`; all else non-zero | US4.AC2 | example | PENDING | |

## Inner loop: unit behaviors

### `lib/src/plugins/tdd/services/refactor_passes.dart`

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U1 | Passes execute in fixed registry order: build → format → fix | FR-003 | example | PENDING | |
| U2 | Each pass is captured as a RefactorAction with command, exit code, filesChanged, output | FR-005 | example | PENDING | |
| U3 | The first failing pass stops the remaining passes | FR-010 | example | PENDING | |
| U4 | A pass that changes nothing records `filesChanged: []` (not an error) | FR-008 | example | PENDING | |
| U5 | filesChanged is computed from a per-pass before/after tree-snapshot diff | FR-005 | example | PENDING | |

### `lib/src/plugins/tdd/services/tree_snapshot.dart`

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U6 | Files hash as `file:<sha256>`; directories and links are recorded distinctly | FR-004, FR-005 | example | PENDING | |
| U7 | changedPaths reports added, removed, and content-changed paths symmetrically | FR-004, FR-005 | example | PENDING | |

### `lib/src/plugins/tdd/models/cycle_entry.dart` (extension)

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U8 | A refactor entry renders the `refactor` label and the `actions:` block per contract | FR-007 | example | PENDING | |
| U9 | The classification assert requires FailureClass for red entries only; refactor/green entries may omit it | FR-007 | example | PENDING | |
| U10 | Existing red/green entry rendering stays byte-compatible | invariant (046 contract) | example | DONE | `test/plugins/tdd/models/cycle_entry_test.dart` |

### `lib/src/plugins/tdd/services/runner.dart` (extension)

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U11 | Loads the `suite` template from `tdd-profile.md` | FR-001 | example | PENDING | |
| U12 | `runSuite` captures exit code and combined output | FR-001 | example | PENDING | |

### `lib/src/plugins/tdd/commands/refactor_command.dart`

| id  | behavior | traces | kind | state | test |
| --- | -------- | ------ | ---- | ----- | ---- |
| U13 | Preflight runs the profile `suite` command before any pass; green proceeds | FR-001 | example | PENDING | |
| U14 | Red preflight names every failing test and modifies zero files | FR-001, FR-002 | example | PENDING | |
| U15 | Unrunnable suite classifies `runner-error` and modifies zero files | FR-001 | example | PENDING | |
| U16 | `test/` snapshot must be identical after the run, else hard failure | FR-004 | example | PENDING | |
| U17 | Every `lib/` change must appear in a recorded action's filesChanged, else hard failure | FR-005 | example | PENDING | |
| U18 | Regression at re-proof → non-zero, regressed tests named, no evidence written | FR-006 | example | PENDING | |
| U19 | Green re-proof with applied actions → refactor evidence entry appended | FR-007 | example | PENDING | |
| U20 | Zero changed files → `clean` outcome, no fabricated actions | FR-008 | example | PENDING | |
| U21 | Summary line is the final stdout line on every path; exit 0 exactly on clean/refactored | FR-009 | example | PENDING | |
| U22 | Missing/unreadable tdd-profile → `runner-error` misfire before any pass | FR-010 | example | PENDING | |

## Invariants and edge cases still to place

None — spec edge cases mapped: partial pass failure → U3; no-op → U4/U20/A9;
no skip-preflight flag → absence asserted by A2/U14 (no such code path);
generator-owned test files → covered by A5's absolute test-dir immutability.

## Out of scope

- Semantic/architecture refactors (new behaviors → full red-green cycle).
- Refactoring zuraffa's own codebase from within (target project only).
- Undo/rollback after regression.
- Drift prediction / regenerate-and-diff (research Decision 2: idempotent
  passes + snapshot diff instead).
- `zfa tdd run` — separate precondition spec.

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
