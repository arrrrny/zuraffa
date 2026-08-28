# Bug Assessment: Missing generate-commands command

- **Slug**: speckit-missing-generate-commands
- **Created**: 2026-08-28
- **Source**: https://github.com/arrrrny/zuraffa/issues/500
- **Verdict**: valid
- **Severity**: high

## Report (verbatim or summarized)

The `generate-commands` command specified in `005-speckit-extension-enhancements` is not implemented. The spec requires parsing `zfa manifest` JSON, generating `.md` files per plugin command, organizing by category, creating `command_registry.json`, and supporting `--dry-run`. Running `zfa generate-commands` returns "Unknown command". The extension directory `.specify/extensions/zuraffa/` does not exist.

## Symptom

Running `zfa generate-commands` produces "Unknown command: generate-commands". The command does not exist in the CLI. The `.specify/extensions/zuraffa/commands/` directory does not exist, so no command documentation is generated.

## Reproduction

1. Run `zfa generate-commands`
2. Observe error: "Unknown command: generate-commands"
3. Check `.specify/extensions/zuraffa/commands/` — directory does not exist

## Suspected Code Paths

- `lib/src/cli/cli_runner.dart:95-117` — `_addCoreCommands()` does not register a `generate-commands` command
- `lib/src/commands/` — no `generate_commands_command.dart` file exists
- `specs/005-speckit-extension-enhancements/spec.md:42-47` — FR-005 through FR-010 define the missing functionality
- `lib/src/commands/manifest_command.dart` — existing `ManifestCommand` outputs plugin capabilities as JSON (the data source for generate-commands)

## Root Cause Hypothesis

The `generate-commands` command was specified in feature `005-speckit-extension-enhancements` (commit 12fd296, 2026-04-26) but never implemented. The `init` command was implemented as part of earlier issues (#275/#393), but `generate-commands` was left as a future enhancement. The implementation requires creating a new command class, registering it in the CLI runner, and generating markdown files from plugin capabilities. Confidence: high.

## Proposed Remediation

**Preferred**: Create `lib/src/commands/generate_commands_command.dart` that:
1. Extends `Command<void>` with name `generate-commands`
2. Accepts `--output` (default: `.specify/extensions/zuraffa/commands/`) and `--dry-run` flags
3. Uses `PluginRegistry.instance` to get plugin capabilities (same pattern as `ManifestCommand`)
4. For each capability, generates a `.md` file with YAML frontmatter, usage, flags table, and examples
5. Organizes files into category subdirectories (data, domain, presentation, scaffolding, testing, utilities)
6. Generates `command_registry.json` mapping commands to files
7. Registers in `cli_runner.dart` via `_runner.addCommand(GenerateCommandsCommand(registry))`

**Alternatives**:
- Implement as a script/CLI tool outside the main `zfa` command (trade-off: less integrated)
- Use code generation to create the command from spec metadata (trade-off: adds complexity)

**Files likely to change**:
- `lib/src/commands/generate_commands_command.dart` (new)
- `lib/src/cli/cli_runner.dart` (register command)
- `.specify/extensions/zuraffa/` (generated output directory)

**Tests to add or update**:
- `test/commands/generate_commands_test.dart` — test dry-run mode, output structure, idempotency
- Verify SC-002: `zfa manifest` count == generated .md files
- Verify SC-005: all .md files have valid frontmatter

## Risks & Considerations

- The extension directory `.specify/extensions/zuraffa/` must be created first
- Generated files must match the existing format from other extensions (bug, chore, tdd, gym)
- The command should be idempotent — running twice should not create duplicate files
- Performance: with 43+ commands, file generation should be efficient

## Open Questions

- Should the command also update `extension.yml` or is that a separate concern?
- What is the exact category mapping for each plugin capability?
- Should generated files include example commands from plugin metadata or static examples?
