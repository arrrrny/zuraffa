# TDD verification — #1568 hand-step hard stop

**Date**: 2026-09-13
**Verdict**: GREEN — the bug test flips red → green; all fast-tier
driver neighbors stay green.

## Red evidence (pre-fix)

```
dart test test/plugins/tdd/commands/bug_1568_hand_step_park_not_stop_test.dart
→ U-1568-1 FAILED: 'gen U2' never invoked — the run stopped AT U1's
  make (the dogfood shape: stopped_at=U1:make, mechanical behaviors
  unreachable). U-1568-2/3 passed (the guards pin master's honest stop).
```

## Green run (post-fix)

```
dart test test/plugins/tdd/commands/bug_1568_hand_step_park_not_stop_test.dart
→ 00:42 +3: All tests passed!
```

## Mutation checks

| id | mutant | kills it |
| -- | ------ | -------- |
| M1 | drop the forecast conjunct from the park arm (marker alone parks) | U-1568-3 (non-seam + marker must stop) |
| M2 | drop the marker conjunct (forecast alone parks) | U-1568-2 (seam + crash-no-marker must stop) |
| M3 | park arm keeps the generic stop (never parks) | U-1568-1 (U2 driven, `hand_steps=1`, `stopped_at=U1:hand`) |
| M4 | phase-2a skips nothing (hand-stepped make re-driven) | U-1568-1 invocation order (`make U1` re-spawns before `gen U2`) |

## Regression run

```
bug_1544 + unit_contract_shape_1489 → 27 pass
corpus_run_command + run_command_bug_1471 + run_driver_timeout_receipt → 29 pass
run_command_path_format → 5 pass
```

The #1544 blocked-parking contract and the SPEC 1489 forecast line are
untouched.
