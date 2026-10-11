# TDD Test List — Spec 1327 terminal cycle-log receipt at run end

One behavior per line, traced to the FRs / success criteria in spec.md.
Every behavior is written as a failing test FIRST (RED), then made to pass
(GREEN). Red for B1–B4 is the issue's own repro shape: a sanctioned
complete run leaves ONE `modified` finding on
`specs/<f>/tdd/cycle-log.md` ("digest mismatch: receipt says …, disk has
… (action: update)") and no terminal receipt exists; B5 is green pre-fix
and pins the backward-compat line (criterion 4).

## Behaviors

| # | Behavior | Trace | Test file |
|---|--------|--------|-----------|
| B1 | A sanctioned complete meta run (`zfa tdd run`, result=complete, exit 0) whose post-receipt appends to the cycle log end with a terminal receipt: command `tdd run`, `input.feature` = the feature, `input.sanctioned = true`, `input.terminal = true`, one `files[]` entry for `specs/<f>/tdd/cycle-log.md` with action `update` and the digest of the log's FINAL bytes; the make receipt that stands for the last pre-run coverage stays on disk (append-only provenance) | FR-1, FR-5 / SC-2 | test/plugins/tdd/bug_1327_cycle_log_terminal_receipt_test.dart |
| B2 | After that complete run, `zfa proof check --format json` exits 0 with `ok: true`, `valid: true` and zero findings (pre-fix: exit 1 with exactly one `modified` finding on the cycle log) | FR-2 / SC-1 | test/plugins/tdd/bug_1327_cycle_log_terminal_receipt_test.dart |
| B3 | After that complete run, `ProofChecker.check()` reports zero `modified` findings (latest-wins resolves the terminal receipt's fresh digest) | FR-1, FR-2 | test/plugins/tdd/bug_1327_cycle_log_terminal_receipt_test.dart |
| B4 | A standalone `zfa tdd run-engine` that completes from a receipted pre-run log state ends with the same terminal coverage (command `tdd run-engine`) and `zfa proof check` passes (pre-fix: the lane's own red/green evidence appends leave the `modified` finding) | FR-1 / SC-3 | test/plugins/tdd/bug_1327_cycle_log_terminal_receipt_test.dart |
| B5 | A run that is NOT complete (a pending behavior stops at its make step after the red evidence landed) writes NO terminal receipt and the `modified` finding on the cycle log REMAINS — expected and correct (criterion 4; green pre-fix, backward-compat pin) | FR-3 / SC-4 | test/plugins/tdd/bug_1327_cycle_log_terminal_receipt_test.dart |

## Red protocol

Run per file, never the full suite (disk ceiling):

```
dart test --preset=all test/plugins/tdd/bug_1327_cycle_log_terminal_receipt_test.dart
```

Expected RED evidence (pre-fix): B1 (no `tdd run` terminal receipt), B2
(proof check exit 1, one `modified` finding), B3 (checker reports the
`modified` finding), B4 (same for the standalone lane) FAIL; B5 PASSES
(the stopped-run drift is today's behavior and must stay).
