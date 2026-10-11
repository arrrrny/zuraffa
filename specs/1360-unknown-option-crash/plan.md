# Plan — Spec 1360 unknown-option crash

**Branch**: `1360-unknown-option-crash` | **Date**: 2026-09-09 | **Spec**: [spec.md](./spec.md)

## Approach

`_CrashSafeCommandRunner extends CommandRunner<void>` in cli_runner.dart
(`_buildRunner` returns it). Override `parse()`: on TypeError from
`super.parse`, re-parse to recover the original ArgParserException, walk
the command chain defensively (runner `commands` → Command `subcommands`,
break at the first unresolvable name), and throw the deepest command's
`usageException`. Everything else verbatim.

## Test strategy

`test/cli/bug_1360_undeclared_option_crash_test.dart` (B1 crash → clean
usage error; B2 parent-level guard; B3 valid-invocation guard; B4 fix
line). Scoped pin: cli suite files + analyze.
