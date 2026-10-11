# Tasks 1327 — terminal cycle-log receipt at run end

Dependency-ordered (MVP first: the red test pins the invariant before any
production code changes). One PR per issue (#1327).

## 1. Spec artifacts

- [x] T1 `specs/1327-cycle-log-append-after-receipt/spec.md` — measurable
      success criteria SC-1..SC-5 mapped to the issue's acceptance
      criteria 1–4 and the locked either/or decision.
- [x] T2 `specs/1327-cycle-log-append-after-receipt/plan.md` — technical
      context (run driver phases, log append timing, latest-wins
      resolution), approach, non-goals.

## 2. Behaviors first (red → green)

- [x] T3 `tdd/test-list.md` — one behavior per line, traced to FRs/SCs.
- [x] T4 `test/plugins/tdd/bug_1327_cycle_log_terminal_receipt_test.dart`
      — B1/B2/B3/B4 RED (B5 pins backward compat, green pre-fix), run
      per-file, record red evidence verbatim.

## 3. Implementation (after the red run is recorded)

- [x] T5 `lib/src/plugins/tdd/services/cycle_log_terminal_receipt.dart` —
      `CycleLogTerminalReceipt.refreshBestEffort` (terminal receipt over
      `specs/<f>/tdd/cycle-log.md`, re-hashed final bytes, sanctioned +
      terminal markers, best-effort warning on failure).
- [x] T6 Wire the meta run: `run_command.dart` calls the service after the
      unified journal entry + meta journal entry, before the summary line
      (command `tdd run`).
- [x] T7 Wire the standalone lanes: `run_engine_command.dart` /
      `run_skin_command.dart` call the service when `outcome.result ==
      'complete'` (commands `tdd run-engine` / `tdd run-skin`).
- [x] T8 GREEN: the behavior file passes; record green evidence.

## 4. Verify + hygiene

- [x] T9 `tdd/verification.md` — red/green evidence, mutation evidence,
      acceptance scorecard, scope compliance.
- [x] T10 `dart analyze` over every changed file — zero issues.
- [x] T11 Adjacent-suite regression (touched surfaces only, per-file):
      bug_1311_refactor_receipt_refresh_test, run_command_test,
      bug_969_proof_receipts_test, bug_924_verify_preflight_test.
- [x] T12 `dart format .` — zero remaining formatting diffs (CI gate).
- [ ] T13 Fixture/build-artifact cleanup + `df -h .` health check.
- [ ] T14 Commit (Conventional Commits, `fix(1327):`), push, open the PR
      closing #1327 with the complete-run proof-check-pass demo.
