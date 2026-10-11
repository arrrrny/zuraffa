# Cycle Log: 1432-platform-lane-skin-plan

Deterministic fixtures: the CLI rows drive the real CLI in-process
(`CliRunner.runCapturing`) over a hermetic temp project with a Lanes-declaring
spec (mirroring `plan_lanes_1000_test.dart`); the renderer rows drive
`renderSkinPlan`/`renderEnginePlan` directly.

## Baseline

- Behaviors derived: 4 acceptance (A-1432-1..4) + 4 unit (U-1432-1..4).
- Suite entry points: `test/plugins/tdd/commands/bug_1432_platform_lane_rows_test.dart`
  (new) + the lane-split service tests.
- RED evidence lands here per cycle as behaviors are driven.

## Cycle 1 — A-1432-1..4 + U-1432-1..4 (the bug)

**RED (pre-fix tree, all six behaviors failing for the right reasons):**

```console
$ dart test test/plugins/tdd/services/lane_split_platform_rows_test.dart
00:01 +0 -2: Some tests failed.
  renderSkinPlan places a platform row in the acceptance section [E]
  renderEnginePlan places a platform row in the acceptance section [E]
  # the platform LaneRow matched no section filter — dropped

$ dart test --preset=all test/plugins/tdd/commands/bug_1432_platform_lane_rows_test.dart
00:05 +0 -4: Some tests failed.
  A-1432-1 [E]  Expected: contains '| A1 |'  (the acceptance section of
                04-SKIN.md — A1 absent while the log routed it)
  A-1432-2 [E]  Expected: contains 'A1'  Actual: Set:['id', 'A2', 'U1']
                (route log says platform lane; the artifact omits the row)
  A-1432-4 [E]  (the summary/meta-index declared count over dropped rows)
  A-1432-3 [E]  Expected: <2> Actual: <0>
                (theme-typed row silently dropped, plan exited 0)
```

In-session reproduction of the issue's exact symptom (same fixture, real
CLI): `route: A1 -> platform lane [declared: type marker, spec line 6]`
printed while `04-SKIN.md` carried only A2/U1 — and the summary claimed
"3 SKIN behaviors" over 2 rendered rows.

**GREEN:**

- `lane_split.dart`: the acceptance outer-loop filter includes
  `BehaviorKind.platform` in BOTH renderers (same columns, same positional
  contract the loop's reader already resolves — the shape the issue's
  hand-edit workaround proved end-to-end).
- `plan_command.dart`: kind-without-home guard in the split refusal loop —
  a routed behavior whose kind no section of its destination lane plan
  renders refuses (exit 2, no artifacts) naming id/kind/criterion with the
  Type-marker remedy. Home sets mirror the renderers; contract rows
  excluded (open #1419).

```console
$ dart test test/plugins/tdd/services/lane_split_platform_rows_test.dart
00:00 +2: All tests passed!

$ dart test --preset=all test/plugins/tdd/commands/bug_1432_platform_lane_rows_test.dart
00:01 +4: All tests passed!
```

## Regression sweep (targeted — no whole-suite runs)

```console
$ dart test test/plugins/tdd/commands/plan_lanes_1000_test.dart \
    test/plugins/tdd/commands/issue_1309_stale_lane_plans_test.dart \
    test/plugins/tdd/commands/bug_1365_split_skin_contract_parity_test.dart \
    test/plugins/tdd/commands/bug_1366_plan_writes_split_receipt_test.dart \
    test/plugins/tdd/bug_1318_noflutter_event_prose_test.dart
00:13 +42: All tests passed!

$ dart test test/plugins/tdd/commands/plan_command_ffi_835_test.dart \
    test/plugins/tdd/commands/plan_command_bug_1182_test.dart \
    test/plugins/tdd/commands/plan_command_pipe_escape_1401_test.dart \
    test/plugins/tdd/commands/contract_kind_1007_test.dart
00:16 +29: All tests passed!
```

No shape drift in acceptance/widget/unit/ffi rendering; single-file plan
path untouched (U-1432-4).
