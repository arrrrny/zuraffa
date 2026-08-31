---
feature: 050-tdd-test-list-format
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 8
planned_at: 12577b69
updated_at: 12577b69
suite_baseline: green
---

# Test List: TDD plan↔gen test-list format contract

Baseline: `dart test test/plugins/tdd/` at `b31a48a7` (master, pre-feature
HEAD) → 220 passed, 0 failed (fast tier). The #617 core fix (master
`74c132db`) is credited as DONE below where its landed tests already pin a
behavior; the open work is the migration completion for the hand-written
6-column extension dialect (FR-007) and its guards.

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`, observable through the real CLI
entry point (`bin/zfa.dart` via `CliRunner` / real subprocess; slow-tier
scenarios where the real pipeline is required).

| id  | behavior                                                                                                                          | traces    | kind    | state   | test |
| --- | --------------------------------------------------------------------------------------------------------------------------------- | --------- | ------- | ------- | ---- |
| A1  | plan → run on a real temp project with the real pipeline drives every plan-written behavior to DONE, exit 0, no `unknown behavior id`, no `stopped_at=A1:gen` | US1.AC1   | example | DONE    | `test/plugins/tdd/scenarios/sc_018_plan_run_loop_e2e_test.dart::SC-018: plan → run drives a plan-written list to all-DONE with the real pipeline (bug #617 loop e2e)` |
| A2  | `zfa tdd gen <id>` resolves a plan-written 4-column row in either loop section: kind from the section header, target defaulted, six result fields printed | US1.AC2   | example | DONE    | `test/plugins/tdd/commands/plan_gen_contract_test.dart` (plan→gen round trip, both sections, target defaulting; landed 74c132db) |
| A3  | `zfa tdd gen <unknown-id>` exits non-zero with `unknown behavior id` before any file is written | US1.AC3   | example | DONE    | `test/plugins/tdd/commands/gen_command_test.dart:178` (unknown behavior id guard) |
| A4  | Loop commands read a hand-written 6-column extension-dialect list (kind cell `example`, test-ref last cell) and resolve its rows: gen resolves the id, run gets past list-reading, and a one-time deprecation note naming the canonical format is printed | US2.AC1   | example | DONE   | `plan_gen_contract_test.dart::A4/050` (gen half) + `run_command_test.dart::U8/050` (run half) + `sc_019_legacy_dialect_migration_test.dart::SC-019/U3` (note half) |
| A5  | A hand-written 6-column row with `acceptance`/`unit` in the kind cell is accepted with the cell winning over the section header | US2.AC2   | example | DONE    | `test/plugins/tdd/services/test_list_reader_test.dart::617-shim: deprecated 6-column rows parse with kind from the cell` |
| A6  | `zfa tdd run <feature>` re-reads the repo's own hand-written 6-column list (e.g. specs/049-tdd-run) without a malformed-list `result=runner-error` | US2.AC3   | example | DONE | `sc_019_legacy_dialect_migration_test.dart::SC-019/A6` |
| A7  | A row matching no accepted shape stops the reading command non-zero with the file, line number, and raw line named | US3.AC1   | example | DONE    | `test/plugins/tdd/services/test_list_reader_test.dart` (unknown-state, 4-col-outside-section, missing-list guards) |
| A8  | The slow-tier loop e2e pins the plan→run format contract so consumer drift fails CI at the loop's front door | US3.AC2   | example | DONE    | `test/plugins/tdd/scenarios/sc_018_plan_run_loop_e2e_test.dart` (the front-door e2e itself) |

## Inner loop: unit behaviors

### `lib/src/plugins/tdd/services/test_list_reader.dart`

| id  | behavior                                                                                          | traces     | kind    | state   | test |
| --- | ------------------------------------------------------------------------------------------------- | ---------- | ------- | ------- | ---- |
| U1  | A 6-column row with an extension test-shape kind cell (`example`) in the outer section parses as acceptance kind with the default `subject_<snake-id>` target and is flagged deprecated | FR-007     | example | DONE | `test_list_reader_test.dart::050: an extension-dialect row in the outer section resolves acceptance kind and the default target` |
| U2  | The same extension-shape row in the inner section parses as unit kind with the default target | FR-007     | example | DONE | `test_list_reader_test.dart::050: an extension-dialect row in the inner section resolves unit kind and the default target` |
| U3  | On a mixed-dialect list the deprecation note prints exactly once per file (never per row) and the list file's bytes are unchanged after the read | FR-009, FR-010 | example | DONE | `sc_019_legacy_dialect_migration_test.dart::SC-019/U3` |
| U4  | An extension-shape 6-column row outside any outer/inner loop section stays malformed with the line named | FR-005     | example | DONE | `test_list_reader_test.dart::050: an extension-dialect row outside any section stays malformed` |
| U5  | A 6-column row whose kind cell is neither acceptance/unit nor an extension test shape (e.g. `banana`) stays malformed with the line named | FR-005     | example | PENDING | |
| U6  | Every extension test shape (`example`, `property`, `contract`, `approval`, `characterization`) is accepted in the shim | FR-007     | example | DONE | `test_list_reader_test.dart::050: every extension test shape is accepted` |
| U10 | A 6-column row whose behavior text contains a markdown-escaped pipe (`\|`, as in specs/049's U15) still splits into exactly 6 cells — the escaped pipe is cell content, not a delimiter | US2.AC3    | example | DONE |
| U11 | A 6-column row carrying the extension's verification state `PROVEN` (specs/044 B-003) maps to the driver's `done` state — the extension's own meaning: the audit proved the cycle | SC-002     | example | DONE | `test_list_reader_test.dart::050: the repo's real specs/044-049 test lists resolve through the reader (regression guard)` (044 read) | `test_list_reader_test.dart::050: markdown-escaped pipes in cells stay cell content (specs/049 U15 shape)` |

### `lib/src/plugins/tdd/commands/gen_command.dart` (adapter through the reader)

| id  | behavior                                                          | traces   | kind      | state   | test |
| --- | ----------------------------------------------------------------- | -------- | --------- | ------- | ---- |
| U7  | `zfa tdd gen <id> --feature <f>` resolves a behavior id from a hand-written 6-column extension-dialect list (the 046/049 shape) and reports the row's traces as the source criterion | FR-001, FR-004 | contract | DONE | `plan_gen_contract_test.dart::A4/050: gen resolves an id from a hand-written 6-column extension-dialect list (the 046/049 shape)` (same test as A4 — the adapter IS the acceptance path here; asserted `source_criterion: US1.AC1` from the 6-col row) |

### `lib/src/plugins/tdd/commands/run_command.dart` (driver list-reading)

| id  | behavior                                                                | traces  | kind    | state   | test |
| --- | ----------------------------------------------------------------------- | ------- | ------- | ------- | ---- |
| U8  | `zfa tdd run <feature>` on a feature whose list is the hand-written 6-column extension dialect gets past list-reading (a row resolves; any stop is a real step outcome, not `result=runner-error` from the dialect) | FR-001   | example | DONE | `run_command_test.dart::U8/050: run drives a hand-written 6-column extension-dialect list past list-reading to all-DONE` |
| U9  | The repo's real specs/044–049 test lists resolve through `TestListReader` with at least one row each and no malformed stop (regression guard against re-bricking the repo's own completed features) | SC-002   | example | DONE | `test_list_reader_test.dart::050: the repo's real specs/044-049 test lists resolve through the reader (regression guard)` |

## Invariants and edge cases still to place

None — all edge cases from spec.md map to behaviors above (orphaned rows →
U4, unknown kind → U5, once-per-file note + read-only → U3, unknown state
stays covered by the landed A7 guards).

## Out of scope

- Pre-extension legacy lists with column counts other than 4 or 6 (e.g. the
  7-column rows in early specs like 002/008): not 6-column fixtures; they
  keep stopping scans with the named-line error (spec Assumptions).
- Removing the compatibility shim: a future, separately-specced change
  (one-release time-box, spec Assumptions).
- Rewriting/migrating the legacy list files themselves: the reader is
  read-only (FR-010); migration is re-running `zfa tdd plan`, prompted by
  the deprecation note.
- Extension-only list states (`BASELINE`, `BLOCKED`, `DROPPED`) as drivable
  driver states: list bookkeeping only (spec Assumptions).

## Verification commands

Copied verbatim from `.specify/memory/tdd-profile.md` at planning time, so
this file is readable on its own:

- Single test: `dart test <file> --plain-name "<name>"`
- Whole file: `dart test <file>`
- Full suite (feature scope): `dart test test/plugins/tdd/`
- Full suite (repo): `dart test` — slow; do not run for feature work, run the
  scoped subset instead.
- Static analysis (feature scope): `dart analyze lib/src/plugins/tdd/ test/plugins/tdd/`
- Static analysis (full repo): `dart analyze`
