# Fix — Missing `generate-commands` command

- **Slug**: speckit-missing-generate-commands
- **Status**: resolved
- **Date**: 2026-08-28
- **Verdict**: valid
- **Triage**: issue #500 / feature `005-speckit-extension-enhancements`

## Root cause

`zfa generate-commands` returned `Unknown command: generate-commands`. The
command was specified in feature `005-speckit-extension-enhancements` (FR-005
through FR-010, SC-002, SC-005) but never implemented: there was no
`GenerateCommandsCommand` class and nothing registered it in `cli_runner.dart`.
The extension `.md` documentation existed, but the generator that produces it
did not.

## Remediation

1. Added `lib/src/commands/generate_commands_command.dart` — a `Command<void>`
   named `generate-commands` that walks every `PluginRegistry` plugin
   capability and emits a `.md` file (YAML frontmatter + Usage / When to Use /
   Required Parameters / Flags / Output sections) into a per-category
   subdirectory, plus a `command_registry.json`. Supports `--output` (default
   `.specify/extensions/zuraffa/commands/`) and `--dry-run`, and is idempotent
   (overwrites the same paths).
2. Category is derived from the plugin id via a static map that mirrors the
   on-disk layout (`data`, `domain`, `presentation`, `graphql`, `testing`,
   `scaffolding`, `utilities`, `integration`, `tooling`, `entity`); unknown
   plugins fall back to `utilities`.
3. Registered `GenerateCommandsCommand(registry)` in `CliRunner._addCoreCommands`
   (mirrors `ManifestCommand`, which shares the same registry + capability data
   source).
4. Added `test/commands/generate_commands_test.dart` covering: command is
   registered (no "Unknown command"), `--dry-run` previews without writing,
   one `.md` per capability + registry (SC-002), consistent frontmatter
   (SC-005), and idempotency.

## Files changed

- `lib/src/commands/generate_commands_command.dart` — new command.
- `lib/src/cli/cli_runner.dart` — register the command.
- `test/commands/generate_commands_test.dart` — new tests.
- `.specify/bugs/speckit-missing-generate-commands/fix.md` — this note.

## Verification

- `dart analyze` clean on the new command, runner, and test.
- `dart test test/commands/generate_commands_test.dart` — 5/5 pass.
- `dart run bin/zfa.dart generate-commands --dry-run` returns exit 0 and lists
  capability `.md` files grouped by category (no "Unknown command").
- Duplicate bug `speckit-extension-enhancements-missing-generate-commands-com`
  is resolved by the same implementation.
