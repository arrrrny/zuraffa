# Verification 1327 — terminal cycle-log receipt at run end (result=complete implies proof check OK)

GitHub issue: arrrrny/zuraffa#1327
Branch: `feat/1327-cycle-log-append-after-receipt`

## Test-first evidence (red → green)

Test file:
`test/plugins/tdd/bug_1327_cycle_log_terminal_receipt_test.dart`
(test-list B1–B5; `--preset=all` because the suite is tagged `slow` per
dart_test.yaml tiering).

### RED (pre-fix, before `cycle_log_terminal_receipt.dart` existed and
before the three run-driver wiring points)

Command: `dart test --preset=all test/plugins/tdd/bug_1327_cycle_log_terminal_receipt_test.dart`
Result: `+1 -4` — B1, B2, B3, B4 FAILED; B5 passed (backward-compat pin,
expected green pre-fix).

Recorded failure output (the issue's repro, verbatim):

- B2 — `Expected: <0> / Actual: <1> / post-run proof check:
  {"schema":"proof.v1","ok":false,"valid":false,"receipts":1,
  "filesChecked":1,"findings":[{"kind":"modified",
  "path":"specs/1327-cycle-log-receipt/tdd/cycle-log.md",
  "receipt":"2026-09-08T18-09-54.547567Z-tdd_make-1327-cycle-log-receipt.json",
  "detail":"digest mismatch: receipt says b635839605c3, disk has
  02de79efe29a (action: update); reproduce with: zfa tdd make"}]}`
  — `zfa proof check` fails with exactly the issue's finding shape after
  a sanctioned complete run appended its unified journal entry to the
  log past the last covering receipt.
- B3 — same drift through `ProofChecker.check()` (one `modified`
  finding on the cycle log).
- B1/B4 — `Expected: an object with length of <1> / Actual: []` — no
  terminal receipt exists after the complete run / completed engine lane.

### GREEN (post-fix)

Command: `dart test --preset=all test/plugins/tdd/bug_1327_cycle_log_terminal_receipt_test.dart`
Result: `00:28 +5: All tests passed!`

- B1 — a sanctioned complete meta run appends exactly ONE terminal
  receipt per complete run: command `tdd run`, `input.feature` set,
  `input.sanctioned = true`, `input.terminal = true`, one `files[]`
  entry for `specs/<f>/tdd/cycle-log.md` with action `update` and the
  digest of the log's FINAL bytes (re-derived, never copied); the make
  receipt stays (append-only provenance); the drift precondition (the
  unified journal entry grew the log after the receipt) is asserted.
- B2 — `zfa proof check --format json` exits 0 with `ok: true`,
  `valid: true`, zero findings after the sanctioned complete run
  (pre-run sanity check also clean).
- B3 — `ProofChecker.check()` reports zero `modified` findings
  (latest-wins resolves the terminal receipt's fresh digest).
- B4 — a standalone `zfa tdd run-engine` completing from a receipted
  pre-run log state closes with the terminal receipt (command
  `tdd run-engine`), digest == final disk bytes, proof check passes.
- B5 — a run that stops early (pending behavior stops at its make step
  after the red evidence landed) writes NO terminal receipt and the
  `modified` finding on the log REMAINS — criterion 4, expected and
  correct.

## Mutation evidence (test strength)

Two hand-applied mutants of the fix, suite re-run per mutant (restored
afterwards — the shipped tree contains neither mutant):

- Mutant A (meta wiring disabled: the `tdd run` terminal-receipt call in
  `run_command.dart` removed) → `+1 -4`: B1, B2, B3 FAIL (the meta run's
  post-receipt append is again uncovered), B4 survives (its lane wiring
  is a separate call site), B5 survives (it pins absence). Killed by
  B1/B2/B3.
- Mutant B (engine-lane wiring disabled: the `tdd run-engine`
  terminal-receipt call in `run_engine_command.dart` removed) → `+4 -1`:
  B4 FAIL (`Expected: an object with length of <1> / Actual: []` — no
  terminal receipt after the completed lane). Killed by B4.

The skin lane (`run_skin_command.dart`) shares B4's call-site shape
(same service, same `result == 'complete'` gate); its terminal receipt
is exercised structurally by B4's harness rather than a dedicated
end-to-end skin fixture (the legacy skin lane is vacuous — no SKIN rows
— and adds no log appends to test against).

## Regression evidence (adjacent suites, touched surfaces only per cloud disk ceiling)

- `dart test --preset=all test/plugins/tdd/run_command_test.dart` →
  `+49: All tests passed!` (the full meta-driver contract: step order,
  state, evidence reconciliation, summary-line-last, phase 0).
- `dart test --preset=all test/plugins/tdd/commands/run_engine_command_test.dart`
  → `+12: All tests passed!` (engine gate + lane contract).
- `dart test --preset=all test/plugins/tdd/bug_1311_refactor_receipt_refresh_test.dart`
  → `+9: All tests passed!` (the #1311 sanctioned-refactor provenance
  contract is unchanged and composes with the terminal receipt).
- `dart test test/plugins/tdd/bug_969_proof_receipts_test.dart
  test/plugins/tdd/bug_924_verify_preflight_test.dart
  test/plugins/tdd/run_command_path_format_test.dart
  test/plugins/tdd/json_flag_test.dart test/plugins/tdd/explain_flag_test.dart`
  → `+41: All tests passed!` (proof receipts, verify preflight scoping,
  run path format, JSON/explain verdict surfaces unchanged).

## Static analysis + format gate

- `dart analyze lib/src/plugins/tdd/services/cycle_log_terminal_receipt.dart
  lib/src/plugins/tdd/commands/run_command.dart
  lib/src/plugins/tdd/commands/run_engine_command.dart
  lib/src/plugins/tdd/commands/run_skin_command.dart
  test/plugins/tdd/bug_1327_cycle_log_terminal_receipt_test.dart` →
  `No issues found!`
- `dart format --set-exit-if-changed lib test` → `Formatted 2420 files
  (0 changed)`, exit 0 — the CI format gate (ci.yaml `format` job runs
  exactly `dart format --set-exit-if-changed lib test`) passes.

## Acceptance criteria scorecard

| # | Criterion | Status |
|---|-----------|--------|
| 1 | Terminal receipt at run end covering cycle-log.md; proof check passes with zero findings on a sanctioned complete run | PROVED (B1, B4, B2 end-to-end) |
| 2 | Append-only log semantics — ALTERNATIVE branch: the terminal-receipt approach was selected (see spec.md Locked decision 2: prefix verification would erase the incomplete-run drift findings criterion 4 pins) | SATISFIED via the terminal-receipt branch (B1/B4) |
| 3 | result=complete implies proof check OK (zero digest-drift findings) | PROVED (B2 end-to-end CLI, B3 checker level) |
| 4 | Backward compatibility — non-complete runs keep their receipt drift | PROVED (B5: no terminal receipt on a stopped run; the modified finding remains) |

## Scope compliance

- Changed surfaces: `RunCommand._run` (meta close-out after the unified
  journal entry), `RunEngineCommand._run` / `RunSkinCommand._run`
  (post-drive complete-only close-out), and the new
  `CycleLogTerminalReceipt` service. The core engine cycle, the
  make/compose/view artifact generation, the refactor pass, the verify
  gate, and the `ProofChecker` algorithm are UNTOUCHED (no diffs outside
  the three commands + the new service + tests + spec artifacts).
- The terminal receipt fires ONLY on `result=complete`; stopped,
  runner-error, and preflight-refused runs write nothing.
- Best-effort discipline: a terminal-receipt write failure warns on
  stderr and never flips the run's exit code (the loss stays
  fail-visible via `zfa proof check`).

## Environment notes

- Toolchain: Dart SDK 3.13.3 (stable) on linux_x64; `dart pub get`
  resolved from pub.dev with no dependency_overrides (the repo's pubspec
  already removes them; the `example/` package needs the Flutter SDK and
  was not resolved — out of scope for this CLI fix).
- Cloud disk ceiling respected: per-file/per-suite test invocations only,
  never the full suite; `.dart_tool/test` kernel cache cleaned between
  suite runs.
