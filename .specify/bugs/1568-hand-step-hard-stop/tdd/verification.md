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

## Review-fix round (PR #1619 review, 2026-09-13)

The five review findings are applied; the two review-fix assertions were
proven RED against the pre-fix driver before being made green.

**Red (pre-fix lib, review-fix assertions only)**

```
dart test test/plugins/tdd/commands/bug_1568_hand_step_park_not_stop_test.dart
→ U-1568-1 FAILED: the journal carried the #1308
  `hand-step=U1:hand — replace the … guard …` remedy for a park
→ U-1568-4 FAILED: summary read `stopped_at=U2:make` with NO
  `hand_steps=1` — the in-loop stop paths dropped the park record
  (the reviewer's own repro)
→ U-1568-2/3 passed (the guards pin master's honest stop, unchanged)
```

**Green (post-fix)**

```
dart test test/plugins/tdd/commands/bug_1568_hand_step_park_not_stop_test.dart
→ 03:02 +4: All tests passed!
```

**Neighbours** (1308 vacuous-guard ×2, 1323 hand-delta, 1373
scaffolded, 1411 born-green, 1544 parking, 1551, arg_placeholder, 1489
forecast — 10 suites):

```
50 pass / 1 fail
```

The single failure is `bug_1544 … a missing blocked receipt fails open`,
which passes **7/7** when that suite runs alone (`04:43 +7: All tests
passed!`) and is a `dart test` worker-contention timeout under parallel
suites — the #1544 suite never touches the park path and contains no
`hand-step`/`hand_steps` reference.

**Static**: `dart analyze` on the four touched files → `No issues
found!`; `dart format` on them → `0 changed`.
