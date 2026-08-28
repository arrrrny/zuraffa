# Bug Assessment: zfa api <Entity> CLI command is dead code (subcommand gate)

- **Slug**: zfa-api-entity-cli-command-is-dead-code-subcommand-gate
- **Created**: 2026-08-27T14:26:43.477146+00:00
- **Source**: https://github.com/arrrrny/zuraffa/issues/494
- **Verdict**: likely valid, needs reproduction
- **Severity**: unknown

## Report (verbatim or summarized)

## Symptom

Running `zfa api Product` (the documented command to generate an entity's VM Service bridge) fails with `Could not find a subcommand named "Product" for "zfa api"` instead of generating `lib/src/api/bridges/product_api_bridge.dart`. The entire `ApiCommand.run()` positional-entity dispatch is never executed.

## Reproduction

1. Build/run the `zfa` CLI (or construct `CommandRunner('zfa')..addCommand(ApiCommand(ApiPlugin(outputDir: <dir>)))`).
2. Invoke `runner.run(['api', 'Product'])` (i.e. `zfa api Product`).
3. Observe `UsageException: Could not find a subcommand named "Product" for "zfa api"` and no file written.
4. Expected: a bridge file `lib/src/api/bridges/product_api_bridge.dart` is generated for the entity.

Probed behavior (repo-local harness against `CommandRunner('zfa')..addCommand(ApiCommand(plugin))`):

```
runner.run(['api'])                     -> UsageException: Missing subcommand for "zfa api"
runner.run(['api','Product'])          -> UsageException: Could not find a subcommand named "Product" for "zfa api"
runner.run(['api','Product','--domain','billing'])
                                       -> (same) Could not find a subcommand named "Product"
```

## Suspected Code Paths

- `lib/src/commands/base_plugin_command.dart:47-49` — **root cause**. `PluginCommand`'s constructor iterates `plugin.capabilities` and calls `addSubcommand(CapabilityCommand(capability))`, so every plugin command (including `ApiCommand`) advertises its capabilities as subcommands.
- `lib/src/plugins/api/capabilities/create_api_bridge_capability.dart:16` — capability `name` is `'create-api-bridge'`, which becomes the subcommand name on `api`.
- `lib/src/commands/api_command.dart:31-71` — `ApiCommand.run()` expects a positional entity (`argResults!.rest.first`) and dispatches to `CreateApiBridgeCapability.execute(...)`. Because `api` now has a subcommand, `package:args` refuses any positional, non-subcommand argument, so `run()` is never reached. The `argResults?.command != null → super.run()` branch is similarly dead.
- `lib/src/plugins/api/api_plugin.dart` — `capabilities` returns `[CreateApiBridgeCapability(this)]` (per plan tasks T010/T012), which is what gets auto-registered as the `create-api-bridge` subcommand.

## Root Cause Hypothesis

`PluginCommand`'s generic "register every capability as a subcommand" behavior is incorrect for `ApiPlugin`. `ApiCommand` is designed to take a **positional entity argument** and call `CreateApiBridgeCapability.execute(...)` directly, but the same capability is also surfaced as the `create-api-bridge` subcommand. Once `api` has any subcommand, `package:args` `CommandRunner` treats it as a command-with-subcommands and rejects positional, non-subcommand arguments — making the intended `zfa api <Entity>` flow unreachable. Confidence: **high** (reproduced deterministically with `CommandRunner` probes; `argResults` is a private field, confirming the method cannot even be reached by direct unit invocation).

## Severity

high

## Source

Discovered while driving the TDD loop for feature `012-api-plugin`. Local assessment: `.specify/bugs/api-command-subcommand-gate/assessment.md`

## Risks & Considerations

- Other plugins (`zfa mock …`, etc.) rely on the subcommand pattern. The opt-out MUST be per-command, not a global default flip.
- `PluginCommand.outputDir` is hardcoded to `'lib/src'` and ignores the `outputDir` passed to the plugin. A CLI test must `chdir` to a temp dir so generation does not write into the repo.
- Removing the `create-api-bridge` subcommand drops it from `zfa api --help`; check for any scripts/docs that call `zfa api create-api-bridge`.

## Open Questions

- Is the intended UX positional (`zfa api <Entity>`) per spec US1 / acceptance A1, or subcommand (`zfa api create-api-bridge --name <Entity>`)? The fix assumes positional.
- Should the hardcoded `outputDir = 'lib/src'` be fixed alongside this, or tracked separately?
- Are there existing callers of `zfa api create-api-bridge` that would break if the subcommand is removed?

See https://github.com/arrrrny/zuraffa/issues/494.

## Symptom

[NEEDS CLARIFICATION]

## Reproduction

[NEEDS CLARIFICATION]

## Suspected Code Paths

[NEEDS CLARIFICATION — run /skill:speckit-bug-assess to locate the code, or fill in manually.]

## Root Cause Hypothesis

[NEEDS CLARIFICATION — not yet analyzed.]

## Proposed Remediation

[NEEDS CLARIFICATION — run /skill:speckit-bug-assess to propose a fix, or apply a fix directly with /skill:speckit-bug-fix.]

## Risks & Considerations

- Loaded from an existing GitHub issue; triage is incomplete until refined.

## Open Questions

- [NEEDS CLARIFICATION: confirm the exact code path and a safe remediation.]
