---
feature: 1277-plan-traces-cell-contract-names
loop: inside-out
profile: .specify/memory/tdd-profile.md
spec_criteria: 4
planned_at: 37c38f2
updated_at: post-fix
suite_baseline: green
---

# Test List: 1277-plan-traces-cell-contract-names

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`.

| id | behavior | traces | state | test |
| -- | -------- | ------ | ----- | ---- |
| A1 | Planning a traced FR then generating emits the declared subject signature + a real outcome assertion, and make completes without vacuous-green | AC-1 | DONE | `test/plugins/tdd/commands/plan_traces_cell_1310_test.dart::declared path end to end` |
| A2 | The legacy single-file plan's traces cells carry the full trace set (criterion + contract references) | AC-2 | DONE | `test/plugins/tdd/commands/plan_traces_cell_1310_test.dart::legacy cells carry the full trace set` |
| A3 | The lane plan (04-ENGINE.md) traces cells carry the full trace set matching the test-list shape | AC-3 | DONE | `test/plugins/tdd/commands/plan_traces_cell_1310_test.dart::lane cells carry the full trace set` |
| A4 | FRs without a traces continuation keep the criterion-only cell and re-plans keep ids stable | AC-4 | DONE | `test/plugins/tdd/commands/plan_traces_cell_1310_test.dart::criterion-only fallback + reconciliation` |

## Inner loop: unit behaviors

### `lib/src/plugins/tdd/commands/plan_command.dart`

| id | behavior | traces | kind | state | test |
| -- | -------- | ------ | ---- | ----- | ---- |
| U1 | A spec FR with a traces continuation names its resolved contract rows in the emitted unit row cell (criterion first, comma-separated) | FR-001 | example | DONE | `plan_traces_cell_1310_test.dart::legacy unit cell` |
| U2 | The derived lane row for the same behavior carries the identical full trace set into 04-ENGINE.md | FR-002 | example | DONE | `plan_traces_cell_1310_test.dart::lane unit cell` |
| U3 | An FR with no traces continuation emits the criterion-only cell in both plan shapes (pre-fix byte shape) | FR-001 | example | DONE | `plan_traces_cell_1310_test.dart::fallback cells` |
| U4 | The prior-list reconciliation read resolves the criterion key from a full-trace-set cell and keeps the row id on re-plan (no renumbering) | FR-003 | example | DONE | `plan_traces_cell_1310_test.dart::replan with full cells` |
| U5 | gen for a planned traced behavior derives the declared signature (bool return, declared param) and a typed outcome assertion, no vacuous-guard marker | AC-1 | example | DONE | `plan_traces_cell_1310_test.dart::gen derives declared signature` |
| U6 | make on a dummy-bool subject certifies green for the planned behavior (no vacuous-green refusal) | AC-1 | example | DONE | `plan_traces_cell_1310_test.dart::make certifies the real assertion` |
| U7 | Re-planning a legacy criterion-only prior list still reconciles ids (compat path unchanged) | FR-003 | example | DONE | `plan_traces_cell_1310_test.dart::replan legacy cells` |

## Invariants and edge cases still to place

- A traces token equal to the criterion id is never duplicated in the
  cell.
- Multiple trace tokens keep their spec order after the criterion id.

## Out of scope

- RoutingResolver / DeclaredRouting / gen / make / contract scanner /
  verify-gate semantics: FR-004 forbids touching them (their existing
  suites are the regression fence).
- Preserved ffi rows and hand lane rows: verbatim cells by design.
- Contract-lane rows: criterion cells already method-qualified.

## Verification commands

Copied verbatim from the repo toolchain (Dart 3.13):

- Single suite: `dart test test/plugins/tdd/commands/plan_traces_cell_1310_test.dart`
- Changed-file analyze: `dart analyze lib/src/plugins/tdd/commands/plan_command.dart test/plugins/tdd/commands/plan_traces_cell_1310_test.dart`
- Format gate: `dart format .` (zero remaining diffs)
