# Fix — Speckit Extension Enhancements: Missing generate-commands command (duplicate)

- **Slug**: speckit-extension-enhancements-missing-generate-commands-com
- **Status**: resolved (duplicate of `speckit-missing-generate-commands`)
- **Date**: 2026-08-28
- **Verdict**: valid
- **Triage**: issue #500

## Root cause

This bug is a duplicate of `speckit-missing-generate-commands` — both track
issue #500 (the `generate-commands` command from feature
`005-speckit-extension-enhancements` was never implemented).

## Remediation

No separate change required. The command was implemented in
`lib/src/commands/generate_commands_command.dart` and registered in
`CliRunner._addCoreCommands` as part of PR #562, which closes issue #500.
Running `zfa generate-commands` (and `--dry-run`) now works and regenerates the
speckit extension command `.md` files.

## Verification

- `dart run bin/zfa.dart generate-commands --dry-run` exits 0 and lists
  capability `.md` files by category.
- `test/commands/generate_commands_test.dart` — 5/5 pass (PR #562).

Resolved by PR #562 (commit `2a274599`).
