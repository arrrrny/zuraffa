# TDD Verification — 1107-lock-master-green (#1107)

- **Bug**: https://github.com/arrrrny/zuraffa/issues/1107 (closes #1078)
- **Branch**: fix/1107-lock-master-green
- **Date**: 2026-09-05
- **Verdict**: PASS — all 7 fast-tier failures observed on master are classified and fixed with red→green evidence; the full fast suite is green twice on the fix HEAD; `dart analyze lib test` reports 0 errors; `dart format` reports 0 drifts.
- **Provenance note**: `.specify/bugs/1107-lock-master-green/issue.md` and `assessment.md` were NOT present on this branch (the task brief stated they might be; they are not). The task brief plus GitHub issues #1107/#1078 (fetched live) were used as the sole issue input. Note: the issue titles attribute the 7 failures to "bug 760/859/679 regression suites" — the issue author's own run was never captured ("result not yet captured"), and the actual red suites on master HEAD differ; the count (7) matches exactly. `zfa tdd verify` was not dispatchable (no global `zfa` binary and no `.zfa.json` in the repo root → `ZFA_MISSING`), so per the speckit.tdd.verify fallback path this audit was produced by the LLM-guided process with real red/green evidence below.

## Environment (honest constraints)

- Toolchain: Dart SDK 3.13.3 stable on linux-x64 (task requires Dart 3.13+). Flutter not installed — flutter test out of scope per the issue constraints (correct: the Dart-only fast suite is the mission).
- The environment's disk cannot hold one whole-tree `dart test` kernel cache (~6.5 GB, documented in `dart_test.yaml`'s header and `tools/run_tests_chunked.sh`). The repo prescribes exactly this mitigation for cloud agents: the fast suite run **chunked per folder with kernel-cache cleanup between chunks**. Every run below uses that runner (`tools/run_tests_chunked.sh` semantics: `dart test <dir> --exclude-tags flutter` + cache cleanup). This is the repo's own definition of the fast suite on a small agent, not a workaround invented for this audit.

## Counts

| Fact | Value |
|------|-------|
| Failures observed on master (baseline run) | 7 — matches #1078's "7 fast-tier failures" |
| Classification: pre-existing bug regression, spec-1008 refactor damage | 4 tests / 2 root causes (#1007 contract-blocked stop; #969 --json envelope + verdicts verb) |
| Classification: pre-existing bug regression, partial #1059 fix | 2 tests / 1 root cause (exit 64 landed, ❌ banner convention did not) |
| Classification: cross-suite race (#1096 family) | 1 test (bug_919 A10 — process-global `exitCode` clobbered by a sibling suite) |
| Single-commit fixes, one per root cause, each naming its regression tests | 4 commits (02fc6bf8, c2aa0534, b61ba7fa, 5f02ac03) + 1 gate-repair commit (orphaned generated stub breaking `dart analyze`) |
| Red phase proven | Yes — baseline logs show each failing test with its assertion text (excerpts below) |
| Green phase proven | Yes — every fixed suite re-run green immediately after its fix |
| Full fast suite post-fix | 40 chunks with tests, all passed — 4518 tests, 0 failed (chunks without fast-tier tests: test/benchmark, test/integration, test/plugins/tdd/scenarios — "No tests ran" by design) |
| Second run (no flakes) | test/plugins/tdd 1358/1358 green on run 2; test/commands 196/196 green on run 2; bug 760/859/679 regression suites 10/10 green again |
| dart analyze | `dart analyze lib test` → 0 errors (300 infos/warnings, all pre-existing, non-fatal under CI's `--no-fatal-warnings`) |
| dart format | `dart format lib test` → "Formatted 2062 files (0 changed)"; `git diff --stat` empty after formatting |
| Mutation gate | not_assessed (mutation_test is not wired on master; no mutant sampling was performed — not claimed) |

## CI gate (order 4)

`dart test` on every push, failing builds blocking merge — **already satisfied**; verified rather than added:

- `.github/workflows/ci.yaml` job `dart_core` runs `dart analyze lib test` + `dart test test --exclude-tags flutter`, triggered `on: pull_request` (all branches) + `push: branches: [master, main]` + `workflow_dispatch`; a `format` job runs `dart format --set-exit-if-changed lib test`.
- Verified byte-level (`git show HEAD:.github/workflows/ci.yaml`): the push filter is exactly `branches: [master, main]` — the default branch IS gated.
- Why master still went red: today's master CI runs failed in `dart_core` at the **Dart Analyze step** (`Dart Test` was skipped — it never ran), caused by a pre-existing `dart analyze` error unrelated to the 7 test failures: `lib/src/domain/services/barcode_service.dart` (committed by spec 1001, d4061d21) imports `../entities/barcode/barcode.dart`, a path that never existed in any commit. Fixed on this branch by removing the orphaned generated stub (nothing imports it; tests reference the path only as string fixtures). Post-fix: 0 analyzer errors, so the gate now reaches the suite.

## Red phase (baseline evidence, master @ 512a8189)

Full fast suite run on master, captured live. The 7 failures, with file:line and assertion text:

**1. `test/plugins/tdd/commands/contract_kind_1007_test.dart:594` — run: a blocked contract stops the cycle before GREEN (issue #1007) — 'verify-red reporting blocked parks the behavior at BLOCKED, stops the run with result=blocked, and never spawns make'** — deterministic (fails in isolation):

```
Expected: contains 'result=blocked'
  Actual: 'zfa tdd run: feature 004-login-ui — 1 behavior(s)\n'
          '[run] contract:A1 gen -> ok\n'
          '[run] contract:A1 verify-red -> blocked\n'
          ...
          'run: feature=004-login-ui result=stopped pending=1 red=0 green=0 done=0 stopped_at=contract:A1:verify-red\n'
Which: does not contain 'result=blocked'
```

**2. `test/plugins/tdd/bug_969_json_verdict_envelope_test.dart:248` — 'run emits the envelope on the error path (exact schema)'** — deterministic:

```
FormatException: Unexpected character (at character 1)
run: feature=090-tdd-fixture result=runner-error pending=0 red=0 green=0 do...
```

**3. `test/plugins/tdd/bug_969_json_verdict_envelope_test.dart:277` — 'verdicts emits the envelope; --schema is diff-stable'** — deterministic:

```
FormatException: Unexpected character (at character 1)
Run "zfa help" to see global options.
```

**4. `test/plugins/tdd/bug_969_json_verdict_envelope_test.dart` — T005 'every verb emits the SAME required key set under --json' (run probe)** — deterministic (same envelope-missing root cause as 2):

```
FormatException: Unexpected character (at character 1)
```

**5. `test/plugins/tdd/bug_919_template_structures_test.dart:279` — A10 'a spec with no Key Entities section plans cleanly (no entity section rendered, exit 0)'** — cross-suite race (passes in isolation; failed only in the concurrent full-chunk run):

```
Expected: <0>
  Actual: <3>
   route: A1 -> acceptance lane [fallback: legacy description classifier matched — add `**Type**: acceptance` to the scenario]
```

**6+7. `test/commands/entity_cli_exit_code_test.dart:85` and :143 — '#1059 — `zfa entity cli` with no entity name exits 64' and '#1059 — bare `zfa entity` exits 64'** — deterministic (exit-64 assertions passed; the banner assertions failed):

```
Expected: contains '❌'
  Actual: 'Usage: zfa entity cli <EntityName>\n'
Which: does not contain '❌'
```

Suites the issue NAMED but which are green on master HEAD (run twice, in isolation and in-chunk): `test/plugins/tdd/services/runner_plain_name_regression_test.dart` (bug 859), `test/plugins/tdd/services/runner_regex_escape_test.dart` (bug 760), `test/plugins/tdd/verify_red_subdirectory_test.dart` (bug 679) — 10/10 tests pass. The #1096 CWD-race fix (512a8189, already at HEAD) plus `dart_test.yaml`'s `concurrency: 2` cap hold those suites green in this environment.

## Classification and fix (green phase)

- **fix(1007)** (02fc6bf8, production): the spec-1008 two-cycle driver refactor (df418c6d, issue #1092) rewrote `RunCommand` into `RunDriverCore` and dropped the #1007 arm mapping a contract behavior's verify-red `blocked` verdict to the BLOCKED stop. Restored verbatim in `run_driver_core.dart` (advance to `BehaviorState.blocked`, stop `result=blocked`/`stopped_at=<behavior>:verify-red`/exit 1) and `summaryLine()` re-emits `blocked=<n>` on its own token. Green: `dart test test/plugins/tdd/commands/contract_kind_1007_test.dart` → 13/13.
- **fix(969)** (c2aa0534, production): the same refactor dropped the #969 envelope wiring — no `VerdictContext`, no `runWithVerdictEnvelope` wrapper, no verdict population — so under `--json` the run verb ended on the plain summary line; and `VerdictsCommand` (file present since b6bc0f49) was never registered in the `TddCommand` dispatcher. Restored both. Green: `dart test test/plugins/tdd/bug_969_json_verdict_envelope_test.dart` → 28/28.
- **fix(1059)** (b61ba7fa, production): the exit-64 half of #1059 had landed but both bare paths printed usage without the ❌ banner (the #1039 fleet convention via `reportSubcommandUsage()`). Both now print `❌ Usage: ...` + hint to stderr before exit 64; `_printHelp()` stays ❌-free so `zfa entity --help` keeps exit 0 (the #764 contract the same test file pins). Green: `dart test test/commands/entity_cli_exit_code_test.dart` → 3/3.
- **fix(919)** (5f02ac03, production + test): A10's exit-0 assertion read the process-global `dart:io exitCode` while the bug_969 suite's T005 probe (a deliberately marker-less plan → contract-drift exit 3) ran concurrently — `exitCode` is process-global across `dart test` suite isolates (documented in `runCapturing`'s spec-1008 comment and `takeExitCode()`'s doc; log timestamps pin the interleaving). Fix mirrors the #1096 shared-state discipline: `CliRunner.lastDispatchedExitCode` — a Dart static, i.e. per-isolate storage immune to sibling writes — snapshotted on every `runCapturing` exit path; bug_919's 14 assertions read the snapshot via `takeDispatchedExitCode()` (no expected value changed); bug_969's tearDown resets the global so its non-zero dispatched codes stop leaking to concurrent readers. No assertion weakened. Green: 919+969+1007 files together → 56/56.
- **gate repair** (orphaned stub removal, production): unblocks `dart analyze` so CI's `dart_core` reaches `dart test` (see CI gate section).

## Acceptance criteria — proved vs not

| Criterion | Status |
|-----------|--------|
| `dart test` exits 0 on master HEAD after the fixes | **PROVED** — full fast suite (the repo-prescribed chunked runner, `--exclude-tags flutter`) green: 40/40 chunks with tests, 4518 passed, 0 failed; per-chunk exit codes 0 |
| Each of the 7 failures has a single-commit fix with a regression-test-name breadcrumb | **PROVED** — commits 02fc6bf8 / c2aa0534 / b61ba7fa / 5f02ac03 each name the failing regression tests verbatim in the message; the 5th root cause (gate blocker) is its own labeled commit |
| The bug_760_* / bug_859_* / bug_679_* regression tests all pass | **PROVED** — 10/10 on master HEAD (they were already green there; re-verified twice), and still 10/10 on the fix HEAD |
| No new tests skipped or weakened | **PROVED** — zero `.skip`/`skip:` additions (all test-file diffs inspected); the only test-side changes re-point 14 exit-code reads at the per-isolate snapshot with identical expected values |
| `dart test` green on a second run (no flakes) | **PROVED** for every previously-red/floatest chunk (test/plugins/tdd 1358/1358 ×2, test/commands 196/196 ×2, the 760/859/679 suites 10/10 ×2) and consistent across two full sweeps of every chunk; a machine with a ≥7 GB disk can additionally run the single-invocation `dart test` this disk cannot hold |
| Constraint: no `.skip`, no weakened assertions, no bundled fixes, flutter test out of scope | **PROVED** — 5 commits, one root cause each; flutter-tagged suites excluded everywhere |
