# Cycle Log

Append only. Newest last. Every entry's `red` block is the evidence that the test existed and failed before the implementation.

## Cycle: U1-U15 (red)

- behavior: 1008-two-cycle-driver
- kind: red
- classification: usageError
- criterion: issue #1008 deliverable
- test: test/plugins/tdd/two_cycle_run_commands_test.dart
- command: `dart test test/plugins/tdd/two_cycle_run_commands_test.dart --preset=all -t slow`
- exit: 1
- at: 2026-09-05T00:00:00.000Z
- output:
```
❌ Could not find a subcommand named "run-engine" for "zfa tdd".
❌ Could not find a subcommand named "run-skin" for "zfa tdd".
❌ Could not find a subcommand named "status" for "zfa tdd".
```

Direct CLI reproduction (spec step 2 — command not found):

```
$ dart bin/zfa.dart tdd run-engine 004-login-ui
❌ Could not find a subcommand named "run-engine" for "zfa tdd".
Usage: zfa tdd <subcommand> [options]

$ dart bin/zfa.dart tdd run-skin 004-login-ui
❌ Could not find a subcommand named "run-skin" for "zfa tdd".

$ dart bin/zfa.dart tdd status 004-login-ui
❌ Could not find a subcommand named "status" for "zfa tdd".
```

Test run: 21 tests, +0 passed / -21 failed — every behavior red for the
right reason (the commands do not exist; the `zfa tdd` usage listing shows
no run-engine / run-skin / status subcommands).

## Cycle: U1-U15 (green)

- behavior: 1008-two-cycle-driver
- kind: green
- criterion: issue #1008 deliverable
- test: test/plugins/tdd/two_cycle_run_commands_test.dart
- command: `dart test test/plugins/tdd/two_cycle_run_commands_test.dart --preset=all -t slow`
- exit: 0
- at: 2026-09-05T01:45:00.000Z
- output:
```
01:36 +21: All tests passed!
```

Regression gates (same machine, same session):

- `dart analyze lib test --no-fatal-warnings` — 0 errors (315 issues vs
  the 316 pre-existing at HEAD; all warnings/infos, none introduced).
- `dart test test/plugins/tdd/run_command_test.dart --preset=all -t slow`
  — +39 -1: the single failure (bug #691 unexpected-green skip) fails
  identically at HEAD (verified by stashing the change: baseline is also
  +39 -1) — pre-existing, not a regression.
- `dart test test/plugins/tdd/services/` — +562 All tests passed.
- `dart test test/plugins/tdd/commands/` — +157 All tests passed.
- `dart test test/plugins/tdd/run_command_path_format_test.dart` — +5.
- `dart test test/plugins/tdd/run_baseline_cache_test.dart` — +7.
- `dart test test/plugins/tdd/bug_828_cycle_log_evidence_integrity_test.dart`
  — +7 -4, identical to the baseline's +7 -4 (doctor-tier, pre-existing).
- `dart test test/plugins/tdd/scenarios/sc_019_legacy_dialect_migration_test.dart`
  — +3 All tests passed (after fixing the one real regression this spec's
  driver introduced: the gen-legacy deprecation note printed twice per
  `zfa tdd run` because the meta-driver reads the list once per lane; the
  note is now once per process per file).
- `dart test test/plugins/tdd/scenarios/sc_018_plan_run_loop_e2e_test.dart`
  — fails at the `zfa tdd plan` template-version drift gate identically at
  HEAD (open issue #1058) — pre-existing, not a regression.
- The chunked fast suite (`tools/run_tests_chunked.sh` chunk plan, all 76
  chunks, kernel caches cleared between chunks): every chunk with fast-tier
  tests reports "All tests passed!" (test/tdd/073-slice-isolation flaked
  once under load — "No package configuration found" in a temp sandbox —
  then passed 2/2 clean retries); the four no-test folders
  (test/benchmark, test/core/dependencies, test/integration,
  test/plugins/tdd/scenarios) report exit 79 "No tests ran" identically at
  HEAD (slow/integration-only folders under the fast selector).
- `dart format .` — idempotent: "Formatted 1985 files (0 changed)";
  `git diff --stat` shows only this spec's intended files.
- NOT completed in this environment: bug_801_run_multi_feature_ownership
  (integration tier, real CLI + `dart pub get` + real test runs) exceeds
  the 10-minute tool budget on this machine; not claimed as passed. The
  same driver path is covered green by the scripted-fake suites above and
  by the real-CLI exit-criteria demo below.

Exit-criteria demo (REAL CLI, feature 004-login-ui, scripted-fake step
binary — the TddFixture pattern):

```
$ dart bin/zfa.dart tdd run-skin 004-login-ui --project <demo> ...
zfa tdd run-skin: no engine receipt at tdd/04-engine-receipt.json — the
  engine lane must be green before the skin lane runs ...
run-skin: feature=004-login-ui lane=skin result=engine-required ...
EXIT=2                                    # exit criterion: engine gate

$ dart bin/zfa.dart tdd run-engine 004-login-ui ...
zfa tdd run-engine: feature 004-login-ui — 3 behavior(s)
run-engine: feature=004-login-ui lane=engine result=complete ... done=3
receipt: {"lane":"engine","verdict":"green","behaviors":["A1","U1","U2"]}
EXIT=0                                    # exit criterion: engine green

$ dart bin/zfa.dart tdd run-skin 004-login-ui ...
   1 already done — skipping              # A1 (BOTH) certified by engine
run-skin: feature=004-login-ui lane=skin result=complete ... done=3
receipt: {"lane":"skin","verdict":"green","behaviors":["A1","W1","W2"]}
EXIT=0                                    # exit criterion: skin green

$ dart bin/zfa.dart tdd run 004-login-ui ...   # fresh state
zfa tdd run: feature 004-login-ui — 3 behavior(s)   # engine lane first
run: feature=004-login-ui result=complete pending=0 red=0 green=0 done=5
receipts: engine green + skin green; cycle-log gains:
## Two-cycle run: 004-login-ui
- engine-receipt: 04-engine-receipt.json (verdict: green)
- skin-receipt: 04-skin-receipt.json (verdict: green)
EXIT=0                                    # exit criterion: meta run

$ dart bin/zfa.dart tdd status 004-login-ui --project <demo>
status: feature=004-login-ui engine=green skin=green
EXIT=0                                    # exit criterion: status verdicts
```


## Cycle: merge master (5159c68c) — post-merge re-verification

- behavior: 1008-two-cycle-driver
- kind: green
- criterion: PR must be mergeable against CURRENT master
- test: the full gate set re-run on the merged tree
- exit: 0
- at: 2026-09-05T02:30:00.000Z
- output:
```
dart analyze lib test --no-fatal-warnings   -> 0 errors
two_cycle_run_commands_test  --preset=all -t slow -> +21 All tests passed
run_command_test              --preset=all -t slow -> +49 All tests passed
  (master's #986 make=skipped and #992 --skip-widget tests included;
   the pre-existing bug #691 failure is now CURED by master's #986 fix)
test/plugins/tdd/services/                     -> +615 All tests passed
test/plugins/tdd/commands/ (concurrency=2)     -> +227 All tests passed*
test/plugins/tdd/run_command_path_format_test  -> +5 All tests passed
test/plugins/tdd/services/test_list_reader_test -> +23 All tests passed
sc_019_legacy_dialect_migration_test           -> +3 All tests passed
dart format . -> idempotent (0 changed)
```

Exit criteria RE-PROVED post-merge via the real CLI on a post-#1000 split
feature (split-receipt.json classification + 04-ENGINE.md/04-SKIN.md +
lane meta-index test-list):

```
run-skin without engine receipt -> EXIT=2 (engine-required)
run-engine -> EXIT=0, receipt green A1,U1,U2 (from split-receipt)
run-skin   -> EXIT=0, receipt green A1,W1,W2 (A1 skipped, engine-certified)
run        -> EXIT=0, done=5, both receipts green, unified journal entry
status     -> EXIT=0, "status: feature=004-login-ui engine=green skin=green"
```

Merge-resolution notes (recorded in the merge commit):
- master's #1000 lane split integrated: lane truth now prefers
  split-receipt.json's classification, then the plan pair, then row tags,
  then the legacy CORE default.
- master's #986/#992/#991 run-driver fixes ported into the shared
  RunDriverCore.
- lib/src/utils/stale_usecase_test_cleaner.dart restored (content at
  b6c26825): master HEAD 5159c68c (spec(1002)) imports it without
  shipping the file — the whole test tree failed to compile at master
  HEAD; verified with git cat-file / a master worktree.
- CliRunner.runCapturing exit-code snapshot: dart:io's exitCode is
  PROCESS-GLOBAL, and `dart test` runs files as concurrent isolates of
  one process — a sibling isolate's command could clobber a test's
  exitCode read (flaked 1-in-7 on PURE MASTER too, same signature:
  "plan succeeded", Expected 0 Actual 1). runCapturing now snapshots the
  dispatched code and re-applies it as its last operation, narrowing the
  window from the whole teardown to a few instructions.

Pre-existing master-HEAD failures surfaced by the chunked fast suite,
each verified IDENTICAL on a pure-master worktree (with the file
restore) — NOT caused by this branch:
- test/plugins/cache (cache_adapter_receipt_test, 2 tests)
- test/plugins/controller (controller_compile_test setUpAll)
- test/plugins/presenter (presenter_compile_test setUpAll)
- test/plugins/view (view_compile_test setUpAll)
- The four no-test folders (benchmark, core/dependencies, integration,
  tdd/scenarios) report exit 79 "No tests ran" identically at master.
