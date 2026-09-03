# Test List: CI Referee + Provenance Dashboards

---
feature: 070-ci-referee-provenance
loop: outside-in
profile: .specify/memory/tdd-profile.md
spec_criteria: 15
planned_at: 5c0add52
updated_at: pending-commit
suite_baseline: green
---

## Outer loop: acceptance behaviors

One per acceptance criterion in `spec.md`. Each stays red until the feature works
end to end through its real entry point (`zfa tdd referee run|gate|rollup`).

| id  | behavior                                                                                          | traces       | kind    | state   | test                                                       |
| --- | ------------------------------------------------------------------------------------------------ | ------------ | ------- | ------- | ---------------------------------------------------------- |
| A1  | A PR touching 3 features (mocked, real, hand-delta) gets a verdict comment with the feature × state table + legend | US1.AC1, FR-002 | example | DONE | `test/plugins/tdd/services/ci_referee/verdict_comment_test.dart` |
| A2  | A reviewer can read the table and see which features are releasable vs simulation-only at a glance | US1.AC2      | example | DONE | `test/plugins/tdd/services/ci_referee/verdict_comment_test.dart` |
| A3  | A doc-only PR gets a minimal verdict (no feature table), never a failure or empty table            | US1.AC3, FR-008 | example | DONE | `test/plugins/tdd/services/ci_referee/verdict_comment_test.dart` |
| A4  | A corpus with mixed features reports correct generated/hand-delta/hand-written ratios + per-feature breakdowns | US2.AC1, FR-003 | example | DONE | `test/plugins/tdd/services/ci_referee/provenance_rollup_test.dart` |
| A5  | Every ratio traces to receipt IDs with verification status (100% receipt-verified)                | US2.AC2, SC-002 | example | DONE | `test/plugins/tdd/services/ci_referee/provenance_rollup_test.dart` |
| A6  | Regenerating the rollup updates ratios and archives the previous ones                              | US2.AC3, FR-012 | example | DONE | `test/plugins/tdd/services/ci_referee/provenance_rollup_test.dart` |
| A7  | All-real corpus passes the production publishing gate                                             | US3.AC1, FR-004 | example | DONE | `test/plugins/tdd/services/ci_referee/publishing_gate_test.dart` |
| A8  | A mocked feature blocks production and offers a labeled simulation build                            | US3.AC2, FR-005 | example | DONE | `test/plugins/tdd/services/ci_referee/publishing_gate_test.dart` |
| A9  | A published simulation build carries an explicit simulation label                                   | US3.AC3, FR-005 | example | DONE | `test/plugins/tdd/services/ci_referee/publishing_gate_test.dart` |
| A10 | A feature realized via state transition flips the gate outcome on the next run                       | US3.AC4, FR-015 | example | DONE | `test/plugins/tdd/services/ci_referee/publishing_gate_test.dart` |
| A11 | A failing test produces a failure artifact: name, ≤20-line excerpt, failing line, fix direction     | US4.AC1, FR-006 | example | DONE | `test/plugins/tdd/services/ci_referee/failure_artifacts_test.dart` |
| A12 | Multiple failures group by feature with a summary count at the top, not a concatenated wall         | US4.AC2, FR-007 | example | DONE | `test/plugins/tdd/services/ci_referee/failure_artifacts_test.dart` |
| A13 | An over-limit failure report truncates gracefully and links to the full report, never drops failures | FR-011       | example | DONE | `test/plugins/tdd/services/ci_referee/failure_artifacts_test.dart` |

## Inner loop: unit behaviors

Grouped by the component that owns them.

### `lib/src/plugins/tdd/services/ci_referee/feature_provenance_reader.dart`

| id  | behavior                                                          | traces            | kind    | state   | test                                                                     |
| --- | ----------------------------------------------------------------- | ----------------- | ------- | ------- | ------------------------------------------------------------------------ |
| U1  | Derives complete(real) for a fully realized feature with receipts | US3, FR-004       | example | DONE | `test/plugins/tdd/services/ci_referee/feature_provenance_reader_test.dart` |
| U2  | Derives complete(mocked) for a feature with a committed simulation fixture manifest | FR-005, #832 | example | DONE | `test/plugins/tdd/services/ci_referee/feature_provenance_reader_test.dart` |
| U3  | Derives realizing for an in-flight corpus feature                  | FR-015           | example | DONE | `test/plugins/tdd/services/ci_referee/feature_provenance_reader_test.dart` |
| U4  | Marks receipt-unknown when receipts are missing or corrupt          | FR-009           | example | DONE | `test/plugins/tdd/services/ci_referee/feature_provenance_reader_test.dart` |
| U5  | Counts receipt file drift as hand-delta (digest mismatch)          | US1, FR-003      | example | DONE | `test/plugins/tdd/services/ci_referee/feature_provenance_reader_test.dart` |
| U6  | Attributes non-feature code to the shared/infrastructure row        | Edge (shared)    | example | DONE | `test/plugins/tdd/services/ci_referee/feature_provenance_reader_test.dart` |

### `lib/src/plugins/tdd/services/ci_referee/golden_workflow.dart`

| id  | behavior                                                            | traces            | kind    | state   | test                                                                |
| --- | ------------------------------------------------------------------- | ----------------- | ------- | ------- | -------------------------------------------------------------------- |
| U7  | Executes setup → corpus verify → per-feature gates → outputs, idempotently | FR-001, SC-005 | example | DONE | `test/plugins/tdd/services/ci_referee/golden_workflow_test.dart`   |
| U8  | Preserves partial results on interruption; the next run resumes, not restarts | FR-010, SC-006 | example | DONE | `test/plugins/tdd/services/ci_referee/golden_workflow_test.dart`   |
| U9  | Emits the gap ledger summary listing features not at target state   | FR-013           | example | DONE | `test/plugins/tdd/services/ci_referee/golden_workflow_test.dart`   |
| U10 | Emits the coverage matrix (features × test tiers) from recorded evidence | FR-014       | example | DONE | `test/plugins/tdd/services/ci_referee/golden_workflow_test.dart`   |
| U11 | An empty corpus with no receipts shows the empty state, never crashes | Edge (empty)  | example | DONE | `test/plugins/tdd/services/ci_referee/golden_workflow_test.dart`   |

### `lib/src/plugins/tdd/services/ci_referee/pr_comment_poster.dart`

| id  | behavior                                                    | traces       | kind    | state   | test                                                                  |
| --- | ----------------------------------------------------------- | ------------ | ------- | ------- | ---------------------------------------------------------------------- |
| U12 | Posts the verdict comment to the PR via the GitHub API sink | US1, SC-001  | example | DONE | `test/plugins/tdd/services/ci_referee/pr_comment_poster_test.dart`   |
| U13 | Dry-run mode renders the comment without any network access | US1          | example | DONE | `test/plugins/tdd/services/ci_referee/pr_comment_poster_test.dart`   |

### `lib/src/plugins/tdd/commands/referee_command.dart`

| id  | behavior                                                      | traces       | kind    | state   | test                                                            |
| --- | ------------------------------------------------------------- | ------------ | ------- | ------- | ---------------------------------------------------------------- |
| U14 | `zfa tdd referee run` prints the machine verdict line + markdown | FR-001     | example | DONE | `test/plugins/tdd/commands/referee_command_test.dart`           |
| U15 | `zfa tdd referee gate --intent production` exits 0/1 by state  | FR-004/005   | example | DONE | `test/plugins/tdd/commands/referee_command_test.dart`           |
| U16 | `zfa tdd referee rollup` writes + archives the rollup          | FR-003/012   | example | DONE | `test/plugins/tdd/commands/referee_command_test.dart`           |

## Invariants and edge cases still to place

- Concurrent receipt writes (two PRs merged in quick succession): the reader
  re-reads the ledger per run and the latest-wins ordering of `ReceiptStore`
  keeps the verdict reflecting the latest state (covered via loadAll ordering
  in U5's fixture).
- Comment character limit: FR-011 truncation is covered by A13.

## Out of scope

- The GitHub Actions workflow YAML (CI platform wiring lives outside this
  repo's Dart core; the referee CLI is the contract it calls).
- Mutating the receipt ledger (the referee is read-only over #807 by design).
- Realizing features (`zfa tdd realize` is referenced by the spec but owned by
  the state-tracking infrastructure, not the referee).

## Verification commands

Copied verbatim from `.specify/memory/tdd-profile.md` at planning time:

- Single test: `dart test <file> --plain-name "<name>"`
- Whole file: `dart test <file>`
- Full suite (feature scope): `dart test test/plugins/tdd/`
- Static analysis (feature scope): `dart analyze lib/src/plugins/tdd/ test/plugins/tdd/`
