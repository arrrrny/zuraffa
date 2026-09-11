# Bug Test: the vacuous-green remedy names the seam that exists for the feature shape

- **Slug**: 1483-vacuous-green-remedy-wrong-file
- **Tested**: 2026-09-10
- **Assessment**: ./assessment.md
- **Fix**: ./fix.md
- **Result**: verified (red → green, real driver runs)
- **TDD artifacts**: `tdd/test-list.md` (the behavior list) and
  `tdd/verification.md` (fresh evidence from the actual run), both in this
  directory.

## Red-green evidence

RED (before the fix, commit 94048e31 + the new tests only) —
`dart test -P all -j 1 test/plugins/tdd/bug_1483_vacuous_green_remedy_driver_test.dart`:

```
00:08 +0 -1: ... U-1483-2: LEGACY single-file feature — the stop names the test-list
             traces cell (full path), NOT the nonexistent 04-ENGINE.md [E]
  Expected: contains 'hand-edit the test list (specs/1483-single-file-seam/tdd/test-list.md) traces cell'
    Actual: '   --> fix: add traces: <ContractRow> to the FR, re-run zfa tdd plan, re-run zfa tdd gen, re-run zfa tdd run — or hand-edit the lane plan (04-ENGINE.md) traces cell to FR-00N, Row.method and re-run zfa tdd gen (the designed hand-delta seam)'
  run: feature=1483-single-file-seam result=stopped pending=0 red=1 green=0 done=0 stopped_at=U1:make

00:15 +0 -2: ... U-1483-3: LANE-SPLIT feature — the stop still names the lane plan
             traces cell (full path) [E]
  Expected: contains 'hand-edit the lane plan (specs/1483-lane-split-seam/tdd/04-ENGINE.md) traces cell'
    Actual: '   --> fix: ... hand-edit the lane plan (04-ENGINE.md) traces cell ...'
```

Both failed for the RIGHT reason: the stop message named the bare
nonexistent/wrong-path file while the stop machine contract
(`stopped_at=U1:make`) held — exactly the issue's defect. The fast-tier
suite failed to compile pre-fix (`vacuousGuardFallbackRemedyFor` undefined)
— the vocabulary red.

GREEN (after the fix) — same commands:

```
00:00 +3: All tests passed!        (bug_1483_vacuous_green_remedy_shape_test.dart)
00:14 +2: All tests passed!        (bug_1483_vacuous_green_remedy_driver_test.dart)
```

## Checks performed

| Check | Command / Action | Result | Notes |
|-------|------------------|--------|-------|
| Analyzer (changed files) | `dart analyze lib/src/plugins/tdd/services/vacuous_guard.dart lib/src/plugins/tdd/commands/run_driver_core.dart test/plugins/tdd/bug_1483_*.dart` | pass | 0 issues. |
| New suites (fast + slow) | `dart test test/plugins/tdd/bug_1483_vacuous_green_remedy_shape_test.dart` and `dart test -P all -j 1 test/plugins/tdd/bug_1483_vacuous_green_remedy_driver_test.dart` | pass | 3/3 and 2/2. |
| Regression — #1320 vocabulary pin | `dart test test/plugins/tdd/commands/bug_1320_declared_assertion_reachable_test.dart` | pass | The #1320 suite pins `vacuousGuardFallbackRemedy` byte-exactly; the constant is unchanged. |
| Regression — #1308 remedy surfaces (fast) | `dart test test/plugins/tdd/issue_1308_vacuous_guard_remedy_test.dart` | pass | Writer warning + vocabulary intact. |
| Regression — #1308 driver arm (slow) | `dart test -P all -j 1 test/plugins/tdd/issue_1308_vacuous_guard_remedy_driver_test.dart` | pass | 4/4 — the fallback-remedy arm, the hand seam, the fail-open, and the forwarding scan all still green over the REAL driver. |
| Regression — #1259 / run semantics (slow) | `dart test -P all -j 1 test/plugins/tdd/bug_1259_vacuous_green_test.dart test/plugins/tdd/run_command_test.dart test/plugins/tdd/two_cycle_run_commands_test.dart` | 3 fail (pre-existing) | bug_1259 U4/U5/U6 — **identical with the entire change set stashed** (A/B against pristine HEAD). Unrelated: gen's Layer-Contracts signature derivation. run_command + two_cycle: all green. |
| Regression — plan/split lane suites (fast) | `dart test test/plugins/tdd/commands/plan_traces_cell_1310_test.dart test/plugins/tdd/commands/bug_1377_fixture_traces_pin_test.dart test/plugins/tdd/bug_1261_visual_contract_surface_test.dart test/plugins/tdd/commands/plan_lanes_1000_test.dart test/plugins/tdd/commands/split_command_1000_test.dart test/plugins/tdd/commands/issue_1309_stale_lane_plans_test.dart test/plugins/tdd/commands/bug_1432_platform_lane_rows_test.dart test/plugins/tdd/bug_1318_noflutter_event_prose_test.dart` | pass | 75/75 — the plan/split surfaces that own the lane-plan wording. |
| Regression — placeholder re-drive (slow) | `dart test -P all -j 1 test/plugins/tdd/bug_1345_placeholder_re_drive_test.dart` | 1 fail (pre-existing) | B1+B2 — fails identically on pristine HEAD (stashed A/B). |
| Full chunked fast suite | `tools/run_tests_chunked.sh` chunk list (105 chunks), resumable per-chunk runner, kernel caches cleared between chunks | pass | 94/105 chunks PASS. The 11 non-passing chunks are ALL environmental, none related to this change: 5 chunks contain only `slow`-tagged tests (`test/benchmark`, `test/core/proof`, `test/integration`, `test/plugins/tdd/scenarios`, `test/tdd/077-make-engine-preset` — "No tests match the requested tag selectors", exit 1) and 4 need the Flutter SDK (`test/plugins/controller`, `test/plugins/presenter`, `test/plugins/view`, `test/templates` — `flutter pub get`: No such file or directory; no Flutter SDK on this agent). `test/commands` passes on a full window (280s). |
| Formatting | `dart format` on the four touched files, then `--output=none --set-exit-if-changed` | pass | 0 changed. Repo-wide check flags two PRE-EXISTING unformatted files (`example/test/tdd/004-login-ui/u1_test.dart`, `tool/generate_openwiki_cli_docs.dart`) — not touched by this fix (minimal-diff constraint). |

## Before / after (the stop message)

Legacy single-file feature (the issue's repro shape):

```text
# BEFORE
   --> fix: add traces: <ContractRow> to the FR, re-run zfa tdd plan, re-run zfa tdd gen, re-run zfa tdd run — or hand-edit the lane plan (04-ENGINE.md) traces cell to FR-00N, Row.method and re-run zfa tdd gen (the designed hand-delta seam)

# AFTER
   --> fix: add traces: <ContractRow> to the FR, re-run zfa tdd plan, re-run zfa tdd gen, re-run zfa tdd run — or hand-edit the test list (specs/001-todo-app/tdd/test-list.md) traces cell to FR-00N, Row.method and re-run zfa tdd gen (the designed hand-delta seam)
```

Lane-split feature (remedy preserved, now with the full path):

```text
# BEFORE
   --> fix: ... — or hand-edit the lane plan (04-ENGINE.md) traces cell ...

# AFTER
   --> fix: ... — or hand-edit the lane plan (specs/1008-two-cycle-driver/tdd/04-ENGINE.md) traces cell ...
```

## Residual risks

- The gen-time writer warning (`zfa tdd gen`, `behavior_test_writer.dart`)
  still prints the pre-#1483 lane-plan wording for single-file features.
  The issue scopes the fix to `vacuous_guard.dart` / run driver; the
  writer is a different surface and the #1320 suite pins the shared
  constant it prints. Flagged for a follow-up if the lane-split wording
  should branch there too.
- The chunked-suite Flutter-SDK chunks and all-slow chunks fail for
  environment reasons unrelated to this fix; they pass on CI machines
  with the Flutter SDK installed (dart_test.yaml documents the tiers).
