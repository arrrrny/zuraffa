# Verification: Issue #764 — `entity --help` unreachable outside a project

Cycle: SDD spec → RED → GREEN → verify (all runs this session, branch
`fix/764-entity-help-outside-project`, base master `6921c730`, Dart 3.13.3).

## Evidence

| # | Check | Command | Result |
|---|-------|---------|--------|
| B1 | Bug mechanism | code trace `EntityCommand.execute` | `_checkDependencies()` runs before the subcommand switch; no `--help` special-case → guard `exit(1)` fires outside a project before usage prints |
| R1 | RED `--help` outside project | `runZfaSource(['entity','--help'], workingDirectory: <empty temp dir>)` | FAIL: output = `No pubspec.yaml found` + dependency advice, exit 1 |
| R2 | RED `-h` outside project | same, `-h` | FAIL: same guard output, exit 1 |
| R3 | RED `--help` inside project | same, repo root | FAIL: "Unknown subcommand: --help" path exits 1 (help printed but exit code wrong) |
| R4 | Guard regression (pre-fix) | `['entity','list']` in empty dir | PASS: pubspec error + non-zero exit (guard intact) |
| G1 | GREEN all four | `dart test test/commands/entity_help_test.dart` | **4/4 pass** (usage + exit 0 for `--help`/`-h` outside; usage + exit 0 inside; guard preserved) |
| G2 | Real CLI | `zfa entity --help` from pubspec-less cwd | usage text (`zfa entity <subcommand> [options]` + subcommands), exit 0 |
| S1 | Regression | `dart test test/commands/` + `dart test test/cli/` | **71/71** and **168/168** pass |
| S2 | Static analysis | `dart analyze` | No issues found |
| S3 | Format | `dart format` touched files | clean |

## Fix summary

- `EntityCommand.execute`: `--help`/`-h` handled immediately after
  `subCommand` extraction, *before* `ZfaConfig.load()` / `runBuild` parsing /
  `_checkDependencies()` — mirrors the existing empty-args help path
  (`exit(0)` when `exitOnCompletion`, else return).
- No other exit sites touched; entity operations keep the pubspec guard and
  all existing exit semantics (FR-2). The test uses the subprocess harness
  (`runZfaSource`) so the command's `exit(N)` behavior is asserted end-to-end
  without killing the test isolate.

## What was not audited

- Per-subcommand help (`entity create --help`) — out of scope (separate UX
  work; falls to the default branch today as before).
