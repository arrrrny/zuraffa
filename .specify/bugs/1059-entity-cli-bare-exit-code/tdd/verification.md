# TDD Verification: 1059 — entity cli bare invocation exits 0 (lying success)

- **Slug**: 1059-entity-cli-bare-exit-code
- **Date**: 2026-09-05
- **Runner**: this session (fallback LLM-guided audit; deterministic `zfa tdd verify` unavailable — no `.zfa.json` at repo root and no `specs/<feature>/tdd/artifacts.json` for a bug slug, so per `speckit.tdd.verify.md` the audit ran the fallback path)
- **Verdict**: **PASS** (with one pre-existing-failure caveat, see §4)

## 1. Test-first evidence

**RED (reproduced before the fix, subprocess against unfixed tree at commit 77e69f24):**

```console
$ dart bin/zfa.dart entity cli
Usage: zfa entity cli <EntityName>      # stdout — wrong stream
$ echo $?
0                                       # the lie (issue #1059)
```

Sibling sweep reproduction (same session, pre-fix):

| Invocation                | Pre-fix exit | Honest exit |
| ------------------------- | ------------ | ----------- |
| `zfa entity cli` (bare)   | 0            | 64          |
| `zfa entity` (bare)       | 0            | 64          |
| `zfa entity bogus`        | 1 (CLI mode) | 1 (propagated to in-process via `exitCode = 1`) |
| `zfa entity --help`       | 0            | 0 (legitimate help — unchanged by design) |

**Mutant-kill check (deliberate mutants; recorded in this audit):**

```console
$ git stash push lib/src/commands/entity_command.dart   # mutant: fix removed
$ dart test test/regression/issue_1059_entity_cli_bare_exit_code_test.dart
00:27 +0 -1: ... bare `zfa entity cli` exits 64 with usage on stderr [E]
            Expected: <64> Actual: <0>
00:27 +0 -2: ... bare `zfa entity` exits 64 (same lie, entity family sweep) [E]
            Expected: <64> Actual: <0>
$ git stash pop                                         # fix restored
$ dart test test/regression/issue_1059_entity_cli_bare_exit_code_test.dart
00:00 +4: All tests passed!
```

Classification per `tdd-test-quality-rubric.md`: **PROVEN** — the red output above was recorded against the unfixed tree in this session, and the regression test lands in the same commit as the fix (rubric: "test file changing in the same commit as ... the source change" qualifies, provided the red is recorded — it is, above). Git history alone cannot show ordering because fix + test share one commit, matching the repo's established bug-fix convention (PR #1039 landed `lying_success_test.dart` with its fixes in one commit).

## 2. Behavior assertions (rubric Q2)

`test/regression/issue_1059_entity_cli_bare_exit_code_test.dart` drives the **real CLI as a subprocess** (`runZfaSource`, AOT-cached) inside a hermetic temp workspace. Assertions target the observable contract only: process exit code, stderr stream routing, and stdout absence-of-usage. No doubles, no internals, no output-format coupling beyond the single usage string that IS the contract.

## 3. Mutation results (rubric Q3)

The `mutation_test` dev-dependency is deliberately not installed in this repo (commented out in `pubspec.yaml` per spec 041 follow-up; wired by a future task), so tool-driven mutation is **NOT_ASSESSED** — stated rather than inferred. Deliberate mutants instead:

| Mutant                                                             | Killed by                                                    |
| ------------------------------------------------------------------ | ------------------------------------------------------------ |
| `_handleCli` bare branch: remove `exitCode = 64` (the #1059 mutant) | test 1 (`bare zfa entity cli exits 64`) — [E] under stash    |
| `execute` bare branch: `exit(64)` → `exit(0)` (the swept sibling mutant) | test 2 (`bare zfa entity exits 64`) — [E] under stash   |
| `default` branch: remove in-process `exitCode = 1`                 | not separately killed in-process (subprocess test exercises CLI mode, which already `exit(1)`s) — residual risk accepted: in-process propagation is source-reviewed and mirrors the #1039 `exitCode` convention |

## 4. Acceptance-criteria coverage (rubric Q4) + suite status

| Acceptance criterion (task orders)                      | Evidence                                                                                                                                 |
| ------------------------------------------------------- | ------------------------------------------------------------------------ |
| `zfa entity cli` bare → exit 64, usage on stderr        | test 1 green post-fix; pre-fix RED recorded in §1                          |
| `zfa entity` bare + sibling subcommands audited; same-pattern lies fixed | audit: bare → 64 (test 2), unknown → non-zero propagated in-process (test 3), `--help` stays 0 (test 4); `list` bare is a legitimate empty listing (no usage printed — not a usage lie, untouched); `enum`/`add-field`/`from-json` missing-arg paths hard-`exit(1)` (non-zero, honest, different pattern — untouched per "no refactors beyond the fix") |
| Regression test added and green                         | 4/4 passed post-fix, re-verified after `dart format`                        |
| Scoped tests pass                                       | fast scoped set: **21/21** (`entity_convergent`, `entity_receipt`, `entity_help`, `property/lying_success`, new regression test); slow-tier entity regression (14 files, `--preset=regression`): **54 passed / 5 failed** |

**Caveat (proved pre-existing):** the 5 slow-tier failures (`issue_321` Part B, `issue_323` Parts A/B/C/F) are `zfa make` generation-transaction failures (`[conflict] Multiple operations for lib/src/di/index.dart ... Transaction failed` under a pure-Dart sandbox — presenter/controller/view skips). Clean-tree baseline with the fix stashed: same two files fail **7** tests — the failures reproduce **without** this change and are environmental, not caused by it. Full fast suite via `tools/run_tests_chunked.sh` (75 chunks, resumable batches): **0 failures**.

**Analyzer/format:** `dart analyze` on touched files: `No issues found!` (repo-wide 346 pre-existing infos/warnings, none in touched files). `dart format .`: idempotent after this branch's files; `git diff --stat` shows only `entity_command.dart` (+14/-2) and the new test.

## 5. Test-smell rubric (rubric Q5)

- Deterministic: subprocess harness with lock-guarded AOT cache; temp workspace per test with best-effort teardown.
- Fast: AOT fast path makes post-build spawns millisecond-scale; whole file ~1s warm (26s cold AOT build amortized suite-wide).
- Tier-consistent: tagged `['regression']` only — no `slow` tag, because it spawns no `pub get`/`build_runner`; it therefore runs in the default CI tier (per `dart_test.yaml` header), which is where an exit-code contract belongs.
- Refactor-insensitive: asserts the process boundary (exit code + stream), not method internals.

## 6. Remediation

None for this fix. Out-of-scope observations (not blockers, do not fix here):

1. `zfa entity` bare/`--help`/error paths hard-`exit()` even when `EntityCommand().execute()` is called from `cli_runner`'s `runCapturing` context — a pre-existing embedding hazard for MCP capture mode (issue-worthy, untouched per task constraints).
2. `enum`/`add-field`/`from-json` missing-arg paths use hard `exit(1)` instead of `exitCode = 64` + return — non-zero (honest) but off the #1039 convention; candidate for a follow-up sweep.
