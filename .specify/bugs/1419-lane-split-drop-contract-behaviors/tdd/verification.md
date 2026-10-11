# tdd.verify — Bug #1419 lane-split contract rows

- **Verified**: 2026-09-11, this session, on
  `fix/1419-lane-split-drop-contract-behaviors` @ the fix commit
  (working tree, pre-push)
- **Toolchain**: Dart 3.13.2 (stable) on linux_x64
- **Scope**: cloud-agent discipline — tests for the changed file
  (`plan_command.dart`) and the new suite ONLY; the full suite was NOT
  run (the ~6.5 GB kernel-cache baseline is out of scope for this
  machine, per dart_test.yaml's own cloud-agent warning)

## Verdict: PASS

## 1. Static analysis

```
dart analyze lib/src/plugins/tdd/commands/plan_command.dart \
             test/plugins/tdd/commands/bug_1419_lane_split_contract_rows_test.dart
→ No issues found!
```

## 2. The bug suite (red → green, REAL run in this session)

```
dart test test/plugins/tdd/commands/bug_1419_lane_split_contract_rows_test.dart
```

- RED (pre-fix): `00:00 +0 -6: Some tests failed.` — every failure the
  bug itself (contract rows absent from the engine plan while the route
  log claims them; anonymous hand-row clobber; SKIN declaration exiting 0)
- GREEN (post-fix): `00:00 +7: All tests passed!`

REQUIRED check — contract behaviors appear in the lane-split engine
plan: PROVED by A-1419-1 (engine plan contract-loop section with the
derived description/trace/PENDING rows), A-1419-2 (reader resolves them
contract-kind from the split artifacts), A-1419-3 (meta-index CORE row
resolves the ids and equals the artifact's rows).

REQUIRED check — contract behaviors keep BLOCKED semantics: PROVED by
A-1419-6 (a recorded BLOCKED `contract:A1` re-plans BLOCKED into the
engine plan through the same reconcile the legacy path uses) and
A-1419-2 (kind stays `BehaviorKind.contract` — the BLOCKED-not-RED
cycle semantics ride the kind).

## 3. Targeted regression sweep (files the fix can reach)

```
dart test test/plugins/tdd/commands/plan_lanes_1000_test.dart \
          test/plugins/tdd/commands/contract_kind_1007_test.dart \
          test/plugins/tdd/commands/contract_blocked_e2e_1007_test.dart \
          test/plugins/tdd/commands/bug_1432_platform_lane_rows_test.dart \
          test/plugins/tdd/services/lane_split_platform_rows_test.dart \
          test/plugins/tdd/commands/issue_1309_stale_lane_plans_test.dart \
          test/plugins/tdd/commands/bug_1366_plan_writes_split_receipt_test.dart \
          test/plugins/tdd/commands/bug_1365_split_skin_contract_parity_test.dart
→ 00:08 +50: All tests passed!

dart test test/plugins/tdd/commands/plan_traces_cell_1310_test.dart \
          test/plugins/tdd/commands/bug_1320_declared_assertion_reachable_test.dart \
          test/plugins/tdd/commands/split_command_1000_test.dart \
          test/plugins/tdd/commands/plan_skin_contract_1004_test.dart \
          test/plugins/tdd/commands/bug_1141_login_ui_regeneration_test.dart \
          test/plugins/tdd/spec_template_lanes_1000_test.dart \
          test/plugins/tdd/commands/plan_unbound_traces_1319_test.dart
→ 00:28 +41: All tests passed!

dart test test/plugins/tdd/bug_1261_visual_contract_surface_test.dart \
          test/plugins/tdd/bug_1318_noflutter_event_prose_test.dart
→ 00:01 +34: All tests passed!

dart test test/plugins/tdd/commands/plan_command_pipe_escape_1401_test.dart
→ 00:00 +2: All tests passed!

dart test test/plugins/tdd/commands/plan_lanes_1000_test.dart \
          test/plugins/tdd/commands/contract_kind_1007_test.dart \
          test/plugins/tdd/commands/bug_1432_platform_lane_rows_test.dart \
          test/plugins/tdd/commands/issue_1309_stale_lane_plans_test.dart \
          test/plugins/tdd/commands/bug_1366_plan_writes_split_receipt_test.dart
→ 00:05 +42: All tests passed!   (final confirmation run)
```

Total: 7 (bug suite) + 127 (regression sweep) + 42 (final confirmation,
overlapping files) assertions green; 0 failed; 0 skipped-by-tag surprises
(the `slow`-tagged suites `two_cycle_run_commands_test` /
`run_skin_command_test` / `spec_corpus_fuzz_1196_test` are excluded by
the repo's default fast tier per `dart_test.yaml` — cloud agents run the
fast tier by design; they were not run and are not claimed).

## 4. Format gate

```
dart format .    (full repo)
→ my changed files re-verified clean:
  dart format --output=none --set-exit-if-changed \
    lib/src/plugins/tdd/commands/plan_command.dart \
    test/plugins/tdd/commands/bug_1419_lane_split_contract_rows_test.dart
→ Formatted 2 files (0 changed) — exit 0
```

NOTE: `dart format .` also surfaced PRE-EXISTING formatting drift on
master in `tool/generate_openwiki_cli_docs.dart` and
`example/test/tdd/004-login-ui/u1_test.dart` (verified by running the
formatter against the stashed master copies). Those two were REVERTED
out of this branch — the fix is plan_command.dart only, and the drift
belongs to master, not to this PR.

## 5. Honest scope statement

- PROVED: the three remediation points (engine rows, lane-coverage
  counting + refusals, hand-row consult), the BLOCKED-semantics
  preservation, the noFlutter guard for contract rows, the shared
  renderer closing the `zfa tdd split` path, and no regression in the
  targeted suites.
- NOT RUN (and not claimed): the full test suite (heavy baseline,
  out of scope for cloud disks) and the `slow`/`integration`/`property`
  tiers.
- Unrelated pre-existing failures observed: none in the targeted
  suites. The only load failures during the sweep were this operator's
  wrong test paths (files live in `test/plugins/tdd/`, not
  `test/plugins/tdd/commands/`), corrected above.

## 6. Review-fix round (follow-up commit)

Re-verification after the review findings (the contract-loop section
hoisted into the shared `lane_split.dart` renderer, the unreachable
`skinRows` spread dropped, and A-1419-8/A-1419-9 added).

- **Toolchain**: Dart 3.13.2 (stable) on macos_x64

```
dart analyze lib/src/plugins/tdd/commands/plan_command.dart \
             lib/src/plugins/tdd/services/lane_split.dart \
             test/plugins/tdd/commands/bug_1419_lane_split_contract_rows_test.dart
→ No issues found!

dart test test/plugins/tdd/commands/bug_1419_lane_split_contract_rows_test.dart
→ 00:01 +9: All tests passed!
```

RED evidence for the new split-path behavior (A-1419-9 run with `lib/`
reverted to the previous commit — the reviewer's finding 1 reproduced):

```
Expected: contains '| contract:A1 | ... | BLOCKED |'
  Actual: '# Engine Plan: 004-login-ui (CORE + BOTH)\n'
→ 00:00 +0 -1: Some tests failed.
```

Regression re-run on the review-fix commit (two batches, `-j 2`):

```
dart test -j 2 plan_lanes_1000 contract_kind_1007 contract_blocked_e2e_1007 \
  bug_1432_platform_lane_rows lane_split_platform_rows issue_1309_stale_lane_plans \
  bug_1366_plan_writes_split_receipt bug_1365_split_skin_contract_parity \
  split_command_1000 plan_skin_contract_1004 plan_skin_contract
→ +71 -1, the one failure `issue_1309 … the receipt records spec_hash and
  spec_mtime at split time` (split exited 1 under batch load). REPRODUCED
  identically with `lib/` reverted to the previous commit — pre-existing
  batch-load flakiness in that suite, not a regression from this change;
  it passes standalone and in a serial batch.

dart test -j 2 plan_traces_cell_1310 bug_1141_{ledger_wiring,view_audit} \
  spec_template_lanes_1000 plan_unbound_traces_1319 bug_1261 bug_1318 \
  plan_command_pipe_escape_1401 bug_937_reader_sections bug_919_reader \
  behavior_kind_trace bug_1381_entity_table_2col
→ 00:35 +90: All tests passed!

dart test test/plugins/tdd/commands/bug_1320_declared_assertion_reachable_test.dart
→ 00:25 +8: All tests passed!   (standalone, per the review's timeout note)
```
