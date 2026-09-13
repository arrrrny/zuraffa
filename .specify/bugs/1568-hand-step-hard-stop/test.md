# Test: #1568 hand-step hard stop

- **Slug**: 1568-hand-step-hard-stop
- **Result**: verified
- **Date**: 2026-09-13

## Runs

| Suite | Command | Result |
| ----- | ------- | ------ |
| New bug suite (RED pre-fix: U-1568-1 failed — run stopped at U1, U2 never driven) | `dart test test/plugins/tdd/commands/bug_1568_hand_step_park_not_stop_test.dart` | 3/3 pass |
| #1544 parking contract | `dart test test/plugins/tdd/commands/bug_1544_run_continue_after_blocked_test.dart` | pass |
| SPEC 1489 forecast | `dart test test/plugins/tdd/services/unit_contract_shape_1489_test.dart` | pass |
| Driver fast-tier neighbors (corpus run, #1471, timeout receipts, path format) | `dart test <4 suites>` | 34/34 pass |
| Static analysis | `dart analyze lib/src/plugins/tdd lib/src/commands` | No issues |

Note: `run_command_test.dart`, `issue_1308_*`, `issue_1323_*` and
`bug_1329_*` are `slow`-tagged (real `dart test` spawns) and excluded
from the fast tier by repo policy; the fast-tier suites above cover the
modified arm chain.

## Verdict

The planner's hand-step verdict now has its run-level state: the
hand-stepped behavior keeps its honest red with `stopped_at=<id>:hand`
and `hand_steps=N` in the summary, the mechanical behaviors behind it
are driven in the same pass, and both failure-shape guards (real
generation bug; marker without forecast) keep the honest generic stop.
