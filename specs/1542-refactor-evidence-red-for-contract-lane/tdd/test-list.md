# Test List: 1542-refactor-evidence-red-for-contract-lane

## Inner loop: unit behaviors

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| U-1542-1 | The run driver's refactor evidence check accepts green-only evidence for a CONTRACT-lane behavior (kind `contract`): a `blocked` state + green evidence drives refactor to `done`, `result=complete`, no `incomplete` misfire line. (SC-1) | FR-001, SC-1 | DONE |
| U-1542-2 | The refactor evidence check accepts green-only evidence for a behavior whose LAST green cycle-log entry carries the born-green journal marker in `- evidence:` — any lane. (SC-2) | FR-002, SC-2 | DONE |
| U-1542-3 | The twin WITHOUT the marker (plain green-only, non-contract) still misfires with the byte-identical pre-#1542 message `(red: false, green: true)` and stops `runner-error` at `<id>:refactor`. (FR-003) | FR-003, SC-2 | DONE |
| U-1542-4 | The full born-green contract flow: `blocked` state + born-green journal evidence reconciles to green and re-enters at REFACTOR ONLY (make never spawns) and completes — no manual run-state surgery. (SC-4) | FR-002, SC-4 | DONE |
| M-1542-1 | `zfa tdd make <id> --born-green` on a behavior whose seeded run-state is `blocked` flips the state file to `done` on disk and prints the advancement line. (SC-3) | FR-004, FR-006, SC-3 | DONE |
| M-1542-2 | `--born-green` with NO run-state.json still certifies green, exits 0, and writes no state file (make never fabricates a run). (FR-004) | FR-004, SC-3 | DONE |
| M-1542-3 | `--born-green` leaves a `pending` run-state untouched (the evidence reconciliation window owns pending; only `blocked` is advanced). (FR-004/D3) | FR-004, D3 | DONE |

## Regression guards (must stay green UNCHANGED)

| id | behavior | traces | state |
| -- | -------- | ------ | ----- |
| R-1542-1 | The pinned bug #682 green-only honesty suite (`run_command_test.dart`): green-only refactor misfires `(red: false, green: true)` for non-contract, non-born-green behaviors. | FR-003, SC-5 | DONE |
| R-1542-2 | The #1411 suites (make B1..B7, driver D1..D3): the born-green gate, refusals, offers, and hand-off stops are byte-unchanged. | Hard constraints | DONE |
| R-1542-3 | `dart analyze` on the changed files: zero new findings. | SC-5 | DONE |
