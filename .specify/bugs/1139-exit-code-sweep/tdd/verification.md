# TDD Verification: 1139 — exit-code sweep (~15 lying command bodies)

- **Slug**: 1139-exit-code-sweep
- **Date**: 2026-09-06
- **Base commit**: `f9f9bc5a` (branch `fix/1139-exit-code-sweep`)
- **Runner**: this session (fallback LLM-guided audit; deterministic `zfa tdd verify` not applicable to a bug slug without `specs/<feature>/tdd/artifacts.json`, so per `speckit.tdd.verify.md` the fallback audit path ran — every number below is a real command output recorded in this session, none inferred)
- **Verdict**: **PASS**

## 1. Scope actually fixed (12 files, 15 recorded command bodies)

The bug record names 15 command bodies. Triage against the tree at `f9f9bc5a`:

| # | Command body | Bare invocation | Failure paths | Disposition in this PR |
|---|--------------|-----------------|---------------|------------------------|
| 1 | view | already honest (`reportSubcommandUsage`) | **LIED** — capability failure ignored, printed "No files generated", exit 0 | **fixed** (both route and non-route branches, `exitCode = 1`) |
| 2 | controller | already honest | **LIED** — `Failed to generate controller`, exit 0 | **fixed** (`exitCode = 1`) |
| 3 | datasource | honest (spec #977) | honest (`exitCode = 1` + fix line + zero-files guard) | no change needed; existing regression suite re-run green |
| 4 | shadcn | already honest (args<2 → 64) | **LIED** twice — unknown layout positional generated a bogus template with exit 0; catch block printed failure with exit 0 | **fixed** (layout allow-list → 64; catch → `exitCode = 1`) |
| 5 | xray deck | honest (64) | honest (64 / 2 / 1 across all error paths) | no change needed; `xray_deck_cli_test.dart` re-run green (8/8) |
| 6 | gym | already honest | **LIED** — `Failed to generate gym`, exit 0 | **fixed** (`exitCode = 1`) |
| 7 | gql | already honest | **LIED** — exit 0 | **fixed** (`exitCode = 1`) |
| 8 | graphql (generate) | already honest | **LIED** — exit 0 | **fixed** (`exitCode = 1`) |
| 9 | graphql introspect | already honest (64) | **LIED** three ways — malformed `--headers` JSON exit 0; invalid endpoint URL exit 0; introspection failure exit 0 | **fixed** (64 / 64 / 1) |
| 10 | feature | honest (bare → 64) | **LIED** — mode-without-name printed usage, exit 0 | **fixed** (`exitCode = 64`) |
| 11 | presenter | already honest | **LIED** — exit 0 | **fixed** (`exitCode = 1`) |
| 12 | api | already honest | **LIED** twice — "Internal error: CreateApiBridgeCapability not found" exit 0; generation failure exit 0 | **fixed** (both → `exitCode = 1`) |
| 13 | module | honest (bare → 64) | **LIED** — "Package directory already exists" exit 0 | **fixed** (`exitCode = 1`) |
| 14 | observer | already honest | **LIED** — exit 0 | **fixed** (`exitCode = 1`) |
| 15 | cache | honest (spec #975 — unconditional `reportSubcommandUsage`, RangeError path deleted) | n/a (command never generates) | no change needed; `cache_command_bare_test.dart` re-run green |

## 2. Test-first evidence (RED recorded against the unfixed tree, this session)

New regression suite: `test/commands/exit_code_sweep_1139_test.dart` (17 tests).

RED run against the unfixed tree (before any lib/ change):

```console
$ dart test test/commands/exit_code_sweep_1139_test.dart
00:46 +0 -17: Some tests failed.
```

All 17 failed with the recorded lie shape, e.g.:

```console
Expected: <1>
  Actual: <0>
module scaffold over an existing package must exit 1 — stdout:
Error: Package directory already exists: ./zuraffa_feature_toy
```

The subprocess tests run the **real CLI** (`bin/zfa.dart` via `Process.run`) against a hermetic flutter-flavored sandbox; the in-process tests drive `run()` with injected `ArgResults` and failing capabilities (same harness pattern as the #977 datasource exit tests).

GREEN after the fix, same command:

```console
$ dart test test/commands/exit_code_sweep_1139_test.dart
00:45 +17: All tests passed!
```

## 3. Mutant-kill check (rubric Q3)

`mutation_test` remains unwired in this repo (deliberate, per spec 041 follow-up), so deliberate mutants were used. Mutant = "fix removed": `git stash push -- lib/src` reverts all 12 fixed files to the base tree while the new regression suite stays present:

```console
$ git stash push -- lib/src
$ dart test test/commands/exit_code_sweep_1139_test.dart --name "failure paths exit 1"
00:00 +0 -10: Some tests failed.        # all 10 failure-path tests killed the mutant
$ git stash pop
$ dart test test/commands/exit_code_sweep_1139_test.dart --name "failure paths exit 1"
00:00 +10: All tests passed!
```

Kill rate: **10/10** for the failure-path group. The 64-path group was red-recorded pre-fix in §2 (same evidence class).

## 4. Whole-repo verification (all real outputs, this session)

| Gate | Command | Result |
|------|---------|--------|
| Analyze | `dart analyze lib/` (+ per-file on every touched file) | **0 errors** in `lib/` and in every file this PR touches. Full-repo `dart analyze` reports 31 errors confined to `examples/todo_tdd/` (pre-existing unresolved package URIs, present on master, untouched here). |
| Fast suite | `tools/run_tests_chunked.sh` semantics, executed by a resumable wrapper with byte-identical chunk selection, `--exclude-tags flutter`, `/dev/null` stdin guard, and inter-chunk kernel cleanup (session sandbox kills detached processes; wrapper state outside the repo) | **89/89 chunks: 3,462 passed, 0 failed** (82 passed chunks + 7 chunks skipped as "no fast-tier tests") |
| Chunk-split blind spot | The runner's THRESHOLD=40 split excludes loose `*_test.dart` directly under over-threshold dirs (pre-existing design). Those files were run directly: `dart test test/commands` → **246 passed** (includes this PR's 17), `dart test test/regression` → **15 passed**, `dart test test/core` + 2 loose plugin files → **588 passed, 1 skipped** | **849 passed, 1 skipped, 0 failed** |
| Format | `dart format --output=none --set-exit-if-changed .` after formatting all touched files | Every touched file format-clean; the only remaining would-change file in the whole repo is `examples/mcp_demo/lib/src/mcp/tools.dart` (pre-existing, untouched — out of scope per "do not change other logic") |
| exit(0) sweep | `grep -rn "exit(0)" lib/` | 11 hits, **every one a success path** (help/version dispatch in `cli_runner.dart`, `--help` handlers in test/entity/gym/create, `config` bare help, successful scaffold actions in `create_command.dart`). Zero hits inside any error path of the 15 recorded commands. |

## 5. Success criteria — proved vs not

- ✅ ~15 command bodies swept: all 15 audited; 12 files fixed; 3 (datasource, xray deck, cache) already honest at base — re-proven green via their existing suites rather than silently claimed.
- ✅ bare → `reportSubcommandUsage()` + `exitCode = 64` (pre-existing guards left intact; new 64 paths added for shadcn layout, introspect input, feature missing-name).
- ✅ failure → `exitCode = 1` (14 lying failure paths fixed across 12 files).
- ✅ Red → green evidence recorded in this session (17 red, 17 green).
- ✅ Mutant kill 10/10 (fix-removed mutant dies).
- ✅ `grep exit(0)` clean outside success paths.
- ✅ Full fast suite green (3,462 + 849 passed, 0 failed).
- ✅ No logic changed beyond the exit-code contract: the diff is 13 files, +121/−9, every hunk an exit-code/usage/print addition (or its import).
- ⚠️ Not re-triaged: `.specify/bugs/1139-exit-code-sweep/issue.md` / `assessment.md` do not exist in the repo (the record lives in the bug brief); this audit fixes against the brief's file:line list, which had drifted — line-number drift is documented in §1, every named body was still located and audited.
