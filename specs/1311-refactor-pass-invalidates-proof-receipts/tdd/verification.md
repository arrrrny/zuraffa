# Verification 1311 — post-refactor receipt refresh (sanctioned refactor provenance event)

GitHub issue: arrrrny/zuraffa#1311
Branch: `feat/1311-refactor-pass-invalidates-proof-receipts`

## Test-first evidence (red → green)

Test file: `test/plugins/tdd/bug_1311_refactor_receipt_refresh_test.dart`
(test-list B1–B9; runs with `dart test --preset=all <file>` because the
suite is tagged `slow` per the repo's dart_test.yaml tiering).

### RED (pre-fix, before `refactor_receipt_refresh.dart` existed and before
the `RefactorCommand` wiring)

Command: `dart test --preset=all test/plugins/tdd/bug_1311_refactor_receipt_refresh_test.dart`
Result: `+3 -3` — B1/B2, B3, B4 FAILED; B5, B6, B9 passed (backward-compat
pins, expected green pre-fix).

Recorded failure output (the issue's repro, verbatim):

- B1/B2 — `Expected: an object with length of <1> / Actual: [] / Which: has
  length of <0>` — no `tdd refactor` receipt was appended after the
  sanctioned pass mutated the receipted artifact.
- B3 — `Expected: <0> / Actual: <1> / post-refactor proof check:
  {"schema":"proof.v1","ok":false,"valid":false,"receipts":1,
  "filesChecked":1,"findings":[{"kind":"modified","path":"lib/malformed.dart",
  "receipt":"2026-09-08T12-53-49.216855Z-tdd_make-090-tdd-fixture.json",
  "detail":"digest mismatch: receipt says e99b965ae679, disk has
  e6df544e63f8 (action: create); reproduce with: zfa tdd make"}]}`
  — `zfa proof check` fails with digest drift on the run's own generated
  subject after the sanctioned refactor.
- B4 — verify output: `zfa tdd verify: NOT_ASSESSED — the feature's
  artifacts failed the proof preflight (digest drift before the audit).`
  — the audit is blocked by the same drift.

### GREEN (post-fix)

Command: `dart test --preset=all test/plugins/tdd/bug_1311_refactor_receipt_refresh_test.dart`
Result: `00:45 +9: All tests passed!`

- B1/B2 — exactly one `tdd refactor` proof.v1 event appended;
  `input.feature` set, `input.sanctioned = true`, `input.refactor = true`,
  pass names recorded; the mutated path re-hashed to the FORMATTED bytes
  (digest re-derived from disk, never copied); the original make receipt
  stays (append-only); `ProofChecker.check()` reports zero `modified`
  findings.
- B3 — `zfa proof check --format json` exits 0 with `ok: true`,
  `valid: true`, zero findings after the sanctioned refactor (pre-refactor
  sanity: also clean — the pass itself creates the drift, the refresh
  resolves it).
- B4 — `zfa tdd verify --feature <f>` no longer refuses with the
  proof-preflight drift NOT_ASSESSED; the output reaches
  `running mutation audit` (audit verdict semantics unchanged — the empty
  scope NOT_ASSESSED in the fixture is the audit's own unrelated verdict).
- B5 — clean lib (no mutation): receipts tree byte-identical, no refactor
  receipt.
- B6 — only unreceipted files mutated: no refactor receipt.
- B9 — red preflight refusal: no refactor receipt (only a completed
  sanctioned pass refreshes).
- B7/B8/B8b — service units: no-overlap no-op; honest re-derived digests;
  append-only second event with latest-wins resolving to the newest
  digest; deleted receipted path skipped honestly (still surfaces as
  `deleted` to the checker — never a fabricated digest).

## Regression evidence (adjacent suites, touched areas only per cloud disk ceiling)

- `dart test --preset=all test/plugins/tdd/refactor_command_test.dart` →
  `+14: All tests passed!` (spec-048 contract intact incl. the FR-009
  summary-line-last rule and the A9 clean no-op).
- `dart test test/plugins/tdd/bug_969_proof_receipts_test.dart
  test/plugins/tdd/bug_924_verify_preflight_test.dart
  test/plugins/tdd/bug_922_refactor_preflight_baseline_test.dart` →
  `+12: All tests passed!` (proof receipts + verify preflight contracts
  unchanged).

## Static analysis + format gate

- `dart analyze lib/src/plugins/tdd/services/refactor_receipt_refresh.dart
  lib/src/plugins/tdd/commands/refactor_command.dart
  test/plugins/tdd/bug_1311_refactor_receipt_refresh_test.dart` →
  `No issues found!`
- `dart format --set-exit-if-changed lib test` → `Formatted 2409 files
  (0 changed)`, exit 0 — the CI format gate (ci.yaml `format` job runs
  exactly `dart format --set-exit-if-changed lib test`) passes.

## Acceptance criteria scorecard

| # | Criterion | Status |
|---|-----------|--------|
| 1 | Post-refactor receipt refresh (sanctioned provenance event re-hashing every touched artifact) | PROVED (B1, B2, B8, B8b) |
| 2 | `zfa proof check` passes after a sanctioned run (zero digest drift) | PROVED (B3, end-to-end CLI) |
| 3 | `zfa tdd verify` not blocked by proof preflight drift | PROVED (B4, end-to-end CLI) |
| 4 | Backward compatibility — refresh fires only when receipted files mutated | PROVED (B5, B6, B9, B7) |

## Scope compliance

- Changed surfaces: `RefactorCommand._run` (post-re-proof sanctioned point
  — the run driver's refactor phase implementation, covering both
  run-driven phase-1/2b refactor steps and standalone `zfa tdd refactor`)
  + the new `RefactorReceiptRefresh` service. The core engine cycle,
  make/compose/view artifact generation, the `ProofChecker` algorithm, and
  the verify gate semantics are untouched (no diffs outside the two
  surfaces + tests + spec artifacts).
- The refactor pass remains mandatory; the fix never skips or weakens it.
- Known boundary (honest limitation, unchanged by this fix): test.v1
  receipts (`TestReceiptStore`, the `zfa test` plugin family) bind usecase
  digests separately; `dart format` does not touch `test/`, and the issue's
  repro exercises the proof.v1 family only. Refreshing test.v1 usecase
  bindings would change that receipt family's semantics (forbidden
  surface) and is out of scope.

## Environment notes

- Toolchain: Dart SDK 3.13.3 (stable) on linux_x64; `dart pub get`
  resolved from pub.dev with no dependency_overrides (the repo's pubspec
  already removes them).
- Cloud disk ceiling respected: per-file test invocations only, never the
  full suite; `.dart_tool/test` kernel cache cleaned after runs.
