**Template Version**: `zuraffa-1.0`

# Tasks: 1391-realize-mock-skip-foreign-fixtures

Dependency-ordered, MVP-first. Every behavior task carries a
`[behavior: <id>]` marker and is MANDATORY (never skippable) — the test
must be written and certified red BEFORE its implementation task.

## Phase 1 — Behavior: the gate skips #832 artifacts (US1, the repro)

- [x] T001 [behavior: A1] RED first: in
      `test/plugins/tdd/commands/bug_1391_realize_mock_skip_foreign_fixtures_test.dart`,
      build the issue #1391 repro — a TddFixture whose fixtures dir holds
      the three committed realize-diff.v1 cases (the certified Login
      surface) PLUS `manifest.json` (`{"schema": 1, "bug": 832, ...}`, the
      `fixture_registry.dart` shape) and `mock-cert.Login.json`
      (`{"schema": 1, "spec": 1001, ...}`, the
      `mock_cert_receipt.dart` shape) — run realize-mock with the
      injected green suite runner, and assert: exit 0, verdict
      `certified`, exactly 3 method records in the receipt, output
      contains `skipped manifest.json (schema 1)` and
      `skipped mock-cert.Login.json (schema 1)`, and output does NOT
      contain `runner-error`. Traces AC-1 / SC-1.
- [x] T002 [behavior: U1] [behavior: U2] [behavior: U3] [behavior: U4]
      Implement the schema-aware scan in
      `lib/src/plugins/tdd/commands/realize_mock_command.dart`: classify
      each decoded document by its `schema` field (contract case iff
      exactly `"realize-diff.v1"`); skip every other document with the
      `skipped <name> (schema <x>)` log line (basename with extension,
      schema rendered verbatim, `unknown` when absent/unparseable); keep
      the existing fail-closed validation for own-schema documents
      (FR-001, FR-002, FR-003, FR-004).

## Phase 2 — Behavior: skip visibility + empty-after-skip honesty

- [x] T003 [behavior: A2] RED first: same test file — a foreign document
      with a string schema (`"schema": "world-v2"`) beside one valid
      realize-diff.v1 case → assert output contains
      `skipped foreign.json (schema world-v2)`, exit 0, and the valid
      case still certifies; plus a schema-less document (no `schema`
      field, valid `input.op`) → assert
      `skipped schemaless.json (schema unknown)` and no method record
      for it; plus an unparseable `.json` file (broken JSON) → assert
      `skipped broken.json (schema unknown)` and no failure. Traces
      AC-2 / SC-2.
- [x] T004 [behavior: A3] RED first: a fixtures dir whose every `.json`
      document is foreign (manifest + mock-cert shapes only) → assert
      exit 1, the summary line carries `result=blocked` (never
      `result=runner-error`, never verdict `certified`), and the failure
      message names that no realize-diff.v1 contract cases remain after
      skipping. Traces AC-3 / SC-3.
- [x] T005 [behavior: U5] Implement the post-scan zero-cases guard in
      `realize_mock_command.dart`: when every scanned document was
      skipped, fail `RealizeMockOutcome.blocked` with the
      no-contract-cases-remain message (FR-005).

## Phase 3 — Behavior: backward compatibility + fail-closed pin

- [x] T006 [behavior: A4] [behavior: U6] RED-then-green pin: a pure realize-diff.v1
      fixtures directory (the pre-change SC-1 shape) → assert exit 0,
      verdict `certified`, zero `skipped` lines in the output, receipt
      byte-shape unchanged (3 method records, same verdict field).
      Traces AC-4 / SC-4.
- [x] T007 [behavior: A5] [behavior: U7] RED-then-green pin: a realize-diff.v1-stamped
      document missing `input.op` beside a valid case → assert the
      existing hard validation fires ("carries no input.op" /
      "fix the fixture before certifying", `result=runner-error`) — the
      skip path never absorbs a broken own-schema case. Traces AC-5 /
      SC-5.

## Phase 4 — Verification

- [x] T008 Run the scoped suite (`dart test
      test/plugins/tdd/commands/bug_1391_realize_mock_skip_foreign_fixtures_test.dart`
      + the pre-existing `realize_mock_command_test.dart` +
      `bug_1367_realize_mock_cert_fallback_test.dart`), `dart analyze` on
      the changed file, `dart format` clean; record the red evidence and
      the green run in `tdd/cycle-log.md`; run the deliberate-mutant
      sampling for the skip condition; write `tdd/verification.md`.
- [x] T009 End-to-end demo: drive the real CLI (`dart run bin/zfa.dart
      mock certify` shape artifacts + `dart run bin/zfa.dart tdd
      realize-mock`) against a scratch project holding the #1391
      collision, capture the transcript into the PR body
      (certify + realize-mock e2e demo).

## Phase 5 — Fail-closed completeness (review fix round)

- [x] T010 [behavior: A5a] [behavior: A5b] [behavior: A5c] RED first:
      close the three remaining fail-closed holes. An unparseable
      document whose raw bytes carry the `realize-diff.v1` stamp is a
      corrupt contract case, not a foreign file, and MUST fail closed
      (`result=runner-error`, no receipt) instead of being skipped —
      otherwise a truncated case silently shrinks the certified surface.
      RED-then-green pins: A5a (no `input` key), A5b (`input` is not an
      object) assert the reworded "carries no input map" message; A5c (a
      truncated stamped document) asserts the corrupt-case message and
      that no `skipped … (schema unknown)` line is printed. Traces AC-5 /
      SC-6.

## Dependencies

- T002 depends on T001 (red first).
- T005 depends on T003's fixtures (skip path proven) and T004's red.
- T006/T007 are independent pins (can run any time after T002).
- T008 aggregates; T009 is the final acceptance demo.
- T010 depends on T002 (the schema scan it hardens).
