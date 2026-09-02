# Bug Assessment: generator plugins exit 0 (success) when required arguments are missing

- **Slug**: generator-plugins-exit-zero-on-missing-args
- **Created**: 2026-09-02
- **Source**: https://github.com/arrrrny/zuraffa/issues/767
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

Generator plugins invoked without their required arguments print an error to stdout but exit with code 0. The issue is systemic across the manifest-driven plugin family: `zfa repository create`, `zfa provider inject`, `zfa usecase create`, `zfa presenter create`, `zfa controller create`, `zfa view create` all demonstrate the bug. Reporter hypothesizes a single fix in the shared capability-invocation path. Source: https://github.com/arrrrny/zuraffa/issues/767

## Symptom

A user invokes one of the per-entity generator commands (e.g. `zfa repository create`) without supplying the required positional entity name. The command prints `❌ Usage: zfa repository <EntityName> [options]` to stdout and exits with code 0. CI/script/MCP clients cannot distinguish a missing-arg failure from a successful run.

## Reproduction

```bash
zfa repository create    # ❌ Usage: ... -> RC=0  (expected: 64)
echo $?                  # 0
zfa provider inject      # ❌ Usage: ... -> RC=0  (expected: 64)
echo $?                  # 0
zfa usecase create       # ❌ Usage: ... -> RC=0  (expected: 64)
echo $?                  # 0
zfa presenter create     # ❌ Usage: ... -> RC=0  (expected: 64)
zfa controller create    # ❌ Usage: ... -> RC=0  (expected: 64)
zfa view create          # ❌ Usage: ... -> RC=0  (expected: 64)
```

Each of these six commands demonstrates the same failure mode.

## Suspected Code Paths

- `lib/src/commands/repository_command.dart:45-48` — `argResults?.rest.isEmpty` check prints the usage and `return`s without setting `exitCode`.
- `lib/src/commands/presenter_command.dart:46-49` — same pattern.
- `lib/src/commands/controller_command.dart:46-49` — same pattern.
- `lib/src/commands/view_command.dart:50-58` — same pattern, with an additional subcommand-help block.
- `lib/src/commands/provider_command.dart:50-54` — guards on `argResults?.command != null` and delegates to `super.run()`; the underlying `provider create` subcommand path is the one that exhibits the bug (subcommand file likely has the same shape — to be confirmed during fix).
- `lib/src/commands/usecase_command.dart` — same anti-pattern is plausible; same anti-pattern should be assumed until confirmed.
- `lib/src/commands/capability_command.dart:212-213` — this is **not** the bug site for the six listed commands. It correctly sets `exitCode = 64`, but the six per-entity commands do not flow through `CapabilityCommand`; they have their own `run()` overrides that bypass the shared validation path.
- `lib/src/cli/cli_runner.dart:251-266` — `_runDispatched` correctly honors `exitCode` set by commands via `_exit(exitCode)`. Not the bug site; included for completeness so the fix isn't blamed on the runner.

## Root Cause Hypothesis

Each of the six per-entity command classes (`RepositoryCommand`, `PresenterCommand`, `ControllerCommand`, `ViewCommand`, `ProviderCommand`, `UseCaseCommand`) implements its own `run()`. They guard on `argResults?.rest.isEmpty`, print a `❌ Usage:` line, and `return` — without ever assigning `exitCode = 64` (or any non-zero value). Because `dart:io` `exitCode` starts at 0 and is only set non-zero when a command explicitly writes to it, the runner's `_exit(exitCode)` at `cli_runner.dart:254` then exits 0.

The reporter's "single fix in the shared runner" hypothesis is wrong: the runner is already correct. The fix has to live in each per-command `run()` method, or — better — be hoisted into a shared base-class hook (e.g. `PluginCommand.run()`) so future commands inherit the contract for free. **Confidence: high** for the six confirmed sites; **medium** for the remaining `provider` / `usecase` variants until their subcommand dispatch is traced.

## Proposed Remediation

**Preferred (single-point fix, prevents recurrence):** centralize the missing-required-arg check in `PluginCommand` (the common base of these six classes) so every subclass gets the contract. Two viable shapes:

1. **Template-method style.** `PluginCommand.run()` becomes the validator: it iterates `argParser.options` for `mandatory: true` and positional requirements, prints the same `❌ Usage:` line, sets `exitCode = 64`, and returns. Subclasses override a new `Future<void> executeValidated()` instead of `run()`. Existing six classes become pure execution; no further changes needed for the bug.
2. **Mixin / extension on `Future<void> Function()`.** Provide a `Future<void> withUsageOnEmpty(this.run, {required String usage})` helper. Less invasive but more error-prone (every new command must remember to use it).

**Alternative (smaller blast radius, more code):** add `exitCode = 64;` (and `return;`) at each of the six confirmed sites. Quick, surgical, but leaves a foot-gun for the next command author.

**Files likely to change:**

- `lib/src/commands/base_plugin_command.dart` — add the centralized check (preferred path).
- `lib/src/commands/repository_command.dart`, `presenter_command.dart`, `controller_command.dart`, `view_command.dart`, `provider_command.dart`, `usecase_command.dart` — refactor `run()` to delegate; remove the per-class `argResults?.rest.isEmpty` blocks.
- (Alternative path) the six command files only — add `exitCode = 64` before each `return`.

**Tests to add or update:**

- `test/commands/repository_command_test.dart` (or extend `test/commands/capability_command_test.dart` with a parametrized variant) — assert `exitCode == 64` after invoking each of the six commands with no positional argument and reading the runner's `runCapturing` output.
- `test/regression/issue_767_exit_code_test.dart` — a focused regression test that runs `zfa repository create`, `zfa presenter create`, `zfa controller create`, `zfa view create`, `zfa provider inject`, `zfa usecase create` (no args) and asserts each returns non-zero via the process exit contract (not just the captured stdout).

## Risks & Considerations

- The `runCapturing` path (`lib/src/cli/cli_runner.dart:326-397`) resets `exitCode = 0` at the top and only returns the captured `output` string. Tests that use `runCapturing` cannot observe `exitCode` changes made inside the dispatched command's zone. New tests must use `CliRunner.run(args)` directly (or read `exitCode` from the global before any reset) to assert the contract. This is a pre-existing testability gap worth flagging separately.
- Setting `exitCode = 64` on the missing-arg path is a behavior change observable to CI and MCP consumers that currently treat the command as success. CHANGELOG / migration note recommended.
- The `provider` and `usecase` commands were not fully traced in this assessment (their `run()` methods delegate to subcommands; the bug is in the per-subcommand `run()`). The fix should sweep both top-level and subcommand entry points, not just the top-level ones.

## Open Questions

- Does the same anti-pattern live in subcommand files for `provider create` and `usecase create`, or only at the top level? (Trivial to confirm during fix.)
- Should exit code 64 (EX_USAGE) be used uniformly, or a plugin-specific code? 64 is the conventional choice; matches the `_isRemovedGenerateCommand` site at `cli_runner.dart:237`.
- Should the centralized fix also cover `--help` printing a non-zero exit when the user passes `-h` and nothing else? Out of scope for this issue but a common follow-up.
