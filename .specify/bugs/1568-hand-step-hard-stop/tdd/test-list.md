# TDD test list — #1568 hand-step hard stop (park, not stop)

| id | suite | kind | description | traces | state |
| -- | ----- | ---- | ----------- | ------ | ----- |
| U-1568-1 | test/plugins/tdd/commands/bug_1568_hand_step_park_not_stop_test.dart | driver (fast tier, fake zfa) | a seam behavior's make failure (forecast + still-failing red) parks U1 at `U1:hand`, the run drives U2 behind it, summary carries `hand_steps=1` | issue #1568 criterion 1+3, SPEC 1489 forecast, #1544 family | GREEN (RED pre-fix: run stopped at U1, U2 unreachable) |
| U-1568-2 | test/plugins/tdd/commands/bug_1568_hand_step_park_not_stop_test.dart | driver | a REAL generation failure on a seam behavior (no still-failing marker) keeps the honest generic stop (`stopped_at=U1:make`, no `hand_steps`) | two-signal gate (FR-001) | GREEN |
| U-1568-3 | test/plugins/tdd/commands/bug_1568_hand_step_park_not_stop_test.dart | driver | the still-failing marker on a NON-seam behavior never parks — the generic stop stands | forecast gates the park | GREEN |
