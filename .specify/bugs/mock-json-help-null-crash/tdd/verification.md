# Verification: Issue #761 — `zfa mock json --help` null-check crash

Cycle: SDD spec → RED → GREEN → verify (all runs in this session, branch
`fix/761-mock-json-help-null-crash`, base master `6921c730`, Dart 3.13.3).

## Evidence

| # | Check | Command | Result |
|---|-------|---------|--------|
| B1 | Crash reproduces (real CLI) | `dart bin/zfa.dart mock json --help` | `❌ Error: Null check operator used on a null value`, exit 1 (pre-fix) |
| B2 | Crash class + site | `--verbose` stack trace | `Command.invocation` (args 2.7.0:288) ← `CommandRunner.runCommand` per-command help path |
| R1 | RED black-box | `dart test test/commands/mock_command_help_test.dart` | 1 failed: output == `❌ Error: Null check operator used on a null value` |
| R2 | RED structural | same run | 1 failed: `subcommands['json'].parent` == `<null>` |
| R3 | Regression guard (pre-fix) | same run | sibling help tests passed (matches issue report) |
| G1 | GREEN black-box | same file, post-fix | PASS — usage printed, no `Null check operator`, no `❌ Error:` |
| G2 | GREEN structural | same file, post-fix | PASS — `JsonMockCommand.parent` non-null, `.runner` resolves to attached runner |
| G3 | Real CLI post-fix | `dart bin/zfa.dart mock json --help` | usage text, exit 0 |
| G4 | Dispatch preserved | `dart bin/zfa.dart mock json Todo --dry-run` | `✅ JSON mock data generated for: Todo`, exit 0 (still `JsonMockCommand`) |
| S1 | Surrounding suites | `dart test test/commands/ test/cli/ test/plugins/mock/` | **275/275 pass** |
| S2 | Static analysis | `dart analyze` | 46 infos, all pre-existing on pristine master (verified via `git stash` round-trip); 0 in touched files |
| S3 | Format | `dart format --output=none --set-exit-if-changed` (3 touched files) | 0 changed |

## Fix summary

- `PluginCommand` (base_plugin_command.dart): new overridable
  `manualSubcommandNames` hook; capability auto-registration skips any
  capability whose derived subcommand name the concrete class registers
  itself. Default `const {}` → zero behavior change for all other plugins.
- `MockCommand` (mock_command.dart): overrides it with `{'json'}` and the
  failure-masking `try { addSubcommand(...) } catch (_) {}` is removed —
  future registration conflicts now surface instead of half-registering.
- No registration-order refactor needed; dispatch of `mock json <Entity>`
  stays on `JsonMockCommand` (FR-2).

## What was not audited

- Other plugins' `CapabilityCommand` name collisions beyond mock (out of
  scope; the hook is available if similar duplicates surface).
- The repo-wide chunked suite (scoped verification via surrounding suites
  S1; repo-wide suites covered in CI).
