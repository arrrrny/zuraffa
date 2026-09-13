# TDD test list — Bug #1544 run parks forever on first blocked contract

| id | suite | kind | description | traces | state |
| -- | ----- | ---- | ----------- | ------ | ----- |
| A-1544-a1 | test/plugins/tdd/commands/bug_1544_run_continue_after_blocked_test.dart | acceptance | a blocked contract parks and the run drives the remaining contracts to their own verdicts, then stops result=blocked | FR-1544 (continue past blocked), RunDriverCore._driveBehavior #1007 arm | GREEN |
| A-1544-a2 | test/plugins/tdd/commands/bug_1544_run_continue_after_blocked_test.dart | acceptance | resume skips an unchanged blocked behavior with receipt and still drives the rest | FR-1544 (skip unchanged blocked, `skipped: still blocked since <ts>`), RunDriverCore._unchangedBlockedSince | GREEN |
| A-1544-a3 | test/plugins/tdd/commands/bug_1544_run_continue_after_blocked_test.dart | acceptance | resume re-drives a blocked behavior when the seam file changed since the verdict (fail open) | FR-1544 (change signal: seam file), RunDriverCore._isNewerThan | GREEN |
| A-1544-a4 | test/plugins/tdd/commands/bug_1544_run_continue_after_blocked_test.dart | acceptance | resume re-drives a blocked behavior when the implementation changed since the verdict (lib/ newer than blocked_at) | FR-1544 (change signal: implementation), RunDriverCore._treeChangedAfter | GREEN |
| A-1544-a5 | test/plugins/tdd/commands/bug_1544_run_continue_after_blocked_test.dart | acceptance | a missing blocked receipt fails open — resume re-drives the blocked behavior honestly | FR-1544 (fail open — never fabricate `blocked since`), ContractBlockedReceipt.fromFile | GREEN |
| A-1544-b1 | test/plugins/tdd/commands/bug_1544_run_continue_after_blocked_test.dart | unit | a red behavior still resumes at make beside a skipped blocked contract (non-blocked resume untouched) | FR-1544 constraint (must not break non-blocked resume), RunDriverCore._stepsFor | GREEN |
| U-1544-c1 | test/plugins/tdd/commands/contract_kind_1007_test.dart | unit | the #1007 single-row pin survives: one blocked contract still stops result=blocked blocked=1 stopped_at=contract:A1:verify-red, never spawning make | #1007 compatibility, RunDriverCore end-of-pass blocked terminal | GREEN |
| U-1544-c2 | test/plugins/tdd/commands/run_engine_command_test.dart + run_skin_command_test.dart | unit | the engine/skin lane commands over the shared core keep their gate and receipt contracts | spec 1008 compatibility | GREEN |

## Red evidence (pre-fix, this session)

A-1544-a1: the run terminated at `contract:A1 verify-red -> blocked` —
`gen contract:A2` never spawned (A2..An unreachable; the reported symptom).

A-1544-a2 (and b1's skip half): the resume re-spawned
`verify-red contract:A1` — no skip receipt existed.

A-1544-a3/a4/a5 were written as pins for the fail-open directions and pass
in both worlds (pre-fix re-drive is the only behavior; post-fix it is the
change-signal path).
